// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";

import { RelayAdapter } from "../../../src/adapters/RelayAdapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/// @dev Executor stand-in that records calls and can be toggled to revert or returnbomb
contract MockDestinationExecutor {
    bool public shouldRevert;
    bool public shouldReturnbomb;
    uint256 public callCount;

    address public lastTokenSent;
    address public lastAccount;
    bytes public lastInitData;
    bytes public lastExecutorCalldata;
    bytes public lastSigData;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function setShouldReturnbomb(bool v) external {
        shouldReturnbomb = v;
    }

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external
    {
        if (shouldRevert) {
            if (shouldReturnbomb) {
                // large revert payload — the adapter's variable-less catch must not copy it
                revert(string(new bytes(100_000)));
            }
            revert("EXECUTOR_REVERT");
        }
        callCount++;
        lastTokenSent = tokenSent;
        lastAccount = account;
        lastInitData = initData;
        lastExecutorCalldata = executorCalldata;
        lastSigData = userSignatureData;
    }
}

/// @dev Recipient that rejects any native transfer
contract NonPayableAccount {
    // no receive/fallback — native transfers fail
}

/// @dev ERC20 that returns false on transfer
contract FalseReturningToken {
    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function balanceOf(address) external pure returns (uint256) {
        return type(uint256).max;
    }
}

contract RelayAdapterUnitTests is Helpers {
    RelayAdapter public adapter;
    MockDestinationExecutor public executor;
    MockERC20 public token;

    address public account;

    function setUp() public {
        account = makeAddr("account");
        executor = new MockDestinationExecutor();
        adapter = new RelayAdapter(address(executor));
        token = new MockERC20("Mock Token", "MOCK", 18);
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public {
        vm.expectRevert(RelayAdapter.ADDRESS_NOT_VALID.selector);
        new RelayAdapter(address(0));

        RelayAdapter adp = new RelayAdapter(address(0x2));
        assertEq(address(adp.SUPER_DESTINATION_EXECUTOR()), address(0x2));
    }

    /*//////////////////////////////////////////////////////////////
                             HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_ProcessRelayExecution_ERC20_Success() public {
        uint256 amount = 1000e18;
        token.mint(address(adapter), amount);

        bytes memory message = _buildMessage(account);

        vm.expectEmit(true, true, false, true);
        emit RelayAdapter.TransferSucceeded(account, address(token), amount);

        adapter.processRelayExecution(address(token), amount, message);

        assertEq(token.balanceOf(account), amount);
        assertEq(token.balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 1);
        assertEq(executor.lastAccount(), account);
        assertEq(executor.lastTokenSent(), address(token));
    }

    function test_ProcessRelayExecution_ERC20_ForwardsSigDataByteIdentical() public {
        uint256 amount = 100e18;
        token.mint(address(adapter), amount);

        bytes memory sigData = _buildSigData(account);
        bytes memory initData = hex"1234";
        bytes memory message = abi.encode(initData, sigData);

        adapter.processRelayExecution(address(token), amount, message);

        assertEq(executor.lastSigData(), sigData);
        assertEq(executor.lastInitData(), initData);
        assertEq(executor.lastExecutorCalldata(), hex"deadbeef");
    }

    function test_ProcessRelayExecution_Native_MsgValue() public {
        uint256 amount = 1 ether;
        bytes memory message = _buildMessage(account);

        vm.deal(address(this), amount);
        adapter.processRelayExecution{ value: amount }(address(0), amount, message);

        assertEq(account.balance, amount);
        assertEq(address(adapter).balance, 0);
        assertEq(executor.callCount(), 1);
    }

    function test_ProcessRelayExecution_Native_PreFunded() public {
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount); // solver pre-funded via receive() in a prior batch call

        bytes memory message = _buildMessage(account);
        adapter.processRelayExecution(address(0), amount, message);

        assertEq(account.balance, amount);
        assertEq(executor.callCount(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                             REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_ProcessRelayExecution_RevertIf_ZeroAmount() public {
        vm.expectRevert(RelayAdapter.ZERO_AMOUNT.selector);
        adapter.processRelayExecution(address(token), 0, _buildMessage(account));
    }

    function test_ProcessRelayExecution_RevertIf_MsgValueWithERC20() public {
        token.mint(address(adapter), 1e18);
        vm.deal(address(this), 1 ether);

        vm.expectRevert(RelayAdapter.MSG_VALUE_NOT_ALLOWED.selector);
        adapter.processRelayExecution{ value: 1 ether }(address(token), 1e18, _buildMessage(account));
    }

    function test_ProcessRelayExecution_RevertIf_MalformedMessage() public {
        token.mint(address(adapter), 1e18);

        vm.expectRevert();
        adapter.processRelayExecution(address(token), 1e18, hex"deadbeef");
    }

    function test_ProcessRelayExecution_RevertIf_NoDstProofForChain() public {
        uint256 amount = 1e18;
        token.mint(address(adapter), amount);

        // sigData with a DstProof for a different chain
        bytes memory sigData = _buildSigDataForChain(account, uint64(block.chainid) + 1);
        bytes memory message = abi.encode(bytes(""), sigData);

        vm.expectRevert(RelayAdapter.NO_DST_PROOF_FOR_CHAIN.selector);
        adapter.processRelayExecution(address(token), amount, message);
    }

    function test_ProcessRelayExecution_RevertIf_ZeroAccount() public {
        uint256 amount = 1e18;
        token.mint(address(adapter), amount);

        vm.expectRevert(RelayAdapter.ACCOUNT_NOT_VALID.selector);
        adapter.processRelayExecution(address(token), amount, _buildMessage(address(0)));
    }

    /*//////////////////////////////////////////////////////////////
                    PERMISSIONLESS GUARDS (ADVERSARIAL)
    //////////////////////////////////////////////////////////////*/

    /// @dev Phantom-credit attack: claim an amount the adapter does not hold.
    ///      Without the guard, a failed transfer would credit failedTransfers with
    ///      money that doesn't exist, later drained against other users' funds.
    function test_Adversarial_PhantomCredit_RevertIf_FundsNotReceived() public {
        // adapter holds nothing
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(token), 1000e18, _buildMessage(account));

        // adapter holds less than claimed
        token.mint(address(adapter), 500e18);
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(token), 1000e18, _buildMessage(account));

        // native: nothing held
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(0), 1 ether, _buildMessage(account));
    }

    /// @dev Escrow-sweep attack: an attacker signs a valid intent for their own account and
    ///      tries to point it at funds escrowed for another user's failed transfer.
    function test_Adversarial_EscrowSweep_RevertIf_TargetingEscrowedFunds() public {
        // 1. Legit flow fails delivery: victim is a non-payable account, native fill
        NonPayableAccount victim = new NonPayableAccount();
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);

        adapter.processRelayExecution(address(0), amount, _buildMessage(address(victim)));

        // escrow recorded
        assertEq(adapter.failedTransfers(address(victim), address(0)), amount);
        assertEq(adapter.totalEscrowed(address(0)), amount);
        assertEq(address(adapter).balance, amount); // funds still in adapter

        // 2. Attacker presents own valid message targeting that balance
        address attacker = makeAddr("attacker");
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(0), amount, _buildMessage(attacker));

        // 3. Victim can still claim
        vm.prank(address(victim));
        vm.expectRevert(RelayAdapter.ETH_TRANSFER_FAILED.selector); // victim is non-payable
        adapter.claimFailedTransfer(address(0), amount);
    }

    /// @dev Replaying a consumed message must fail on the funds guard, not double-forward
    function test_Adversarial_MessageReplay_RevertIf_FundsAlreadyForwarded() public {
        uint256 amount = 100e18;
        token.mint(address(adapter), amount);

        bytes memory message = _buildMessage(account);
        adapter.processRelayExecution(address(token), amount, message);
        assertEq(token.balanceOf(account), amount);

        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(token), amount, message);
    }

    /*//////////////////////////////////////////////////////////////
                        FAILED TRANSFER PATHS
    //////////////////////////////////////////////////////////////*/

    function test_FailedTransfer_ERC20_CreditsEscrowAndStillCallsExecutor() public {
        FalseReturningToken badToken = new FalseReturningToken();
        uint256 amount = 100e18;

        vm.expectEmit(true, true, false, true);
        emit RelayAdapter.TransferFailed(account, address(badToken), amount);

        adapter.processRelayExecution(address(badToken), amount, _buildMessage(account));

        assertEq(adapter.failedTransfers(account, address(badToken)), amount);
        assertEq(adapter.totalEscrowed(address(badToken)), amount);
        // executor is still attempted (best-effort)
        assertEq(executor.callCount(), 1);
    }

    function test_FailedTransfer_Native_NonPayableAccount() public {
        NonPayableAccount nonPayable = new NonPayableAccount();
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);

        adapter.processRelayExecution(address(0), amount, _buildMessage(address(nonPayable)));

        assertEq(adapter.failedTransfers(address(nonPayable), address(0)), amount);
        assertEq(adapter.totalEscrowed(address(0)), amount);
        assertEq(address(adapter).balance, amount);
    }

    /*//////////////////////////////////////////////////////////////
                             CLAIMS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimFailedTransfer_RevertingClaimPreservesBookkeeping() public {
        // ERC20 escrow whose claim transfer fails (FalseReturningToken → SafeERC20 revert)
        FalseReturningToken badToken = new FalseReturningToken();
        uint256 amount = 100e18;
        adapter.processRelayExecution(address(badToken), amount, _buildMessage(account));

        vm.prank(account);
        vm.expectRevert();
        adapter.claimFailedTransfer(address(badToken), amount);

        assertEq(adapter.failedTransfers(account, address(badToken)), amount);
        assertEq(adapter.totalEscrowed(address(badToken)), amount);
    }

    function test_ClaimFailedTransfer_Native_RevertIf_ClaimerNonPayable() public {
        NonPayableAccount nonPayable = new NonPayableAccount();
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);
        adapter.processRelayExecution(address(0), amount, _buildMessage(address(nonPayable)));

        vm.prank(address(nonPayable));
        vm.expectRevert(RelayAdapter.ETH_TRANSFER_FAILED.selector);
        adapter.claimFailedTransfer(address(0), amount);

        assertEq(adapter.failedTransfers(address(nonPayable), address(0)), amount);
        assertEq(adapter.totalEscrowed(address(0)), amount);
    }

    function test_ClaimFailedTransfer_Native_SuccessfulClaim_DecrementsEscrow() public {
        // use an EOA-style account that initially rejects via a mock, then use a payable claimer:
        // escrow against this test contract by making the adapter's transfer fail via gas-less path is
        // convoluted — instead escrow via FalseReturningToken pattern is ERC20-only. For native we
        // verify decrement through a payable claimer that had a failed transfer first:
        PayableToggleAccount claimer = new PayableToggleAccount();
        claimer.setAccept(false);

        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);
        adapter.processRelayExecution(address(0), amount, _buildMessage(address(claimer)));
        assertEq(adapter.failedTransfers(address(claimer), address(0)), amount);

        claimer.setAccept(true);
        vm.prank(address(claimer));
        adapter.claimFailedTransfer(address(0), amount);

        assertEq(address(claimer).balance, amount);
        assertEq(adapter.failedTransfers(address(claimer), address(0)), 0);
        assertEq(adapter.totalEscrowed(address(0)), 0);
    }

    function test_ClaimFailedTransfer_RevertIf_ZeroAmount() public {
        vm.expectRevert(RelayAdapter.ZERO_AMOUNT.selector);
        adapter.claimFailedTransfer(address(token), 0);
    }

    function test_ClaimFailedTransfer_RevertIf_NoBalance() public {
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(address(token), 1);
    }

    function test_ClaimFailedTransfer_RevertIf_OverClaim() public {
        PayableToggleAccount claimer = new PayableToggleAccount();
        claimer.setAccept(false);
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);
        adapter.processRelayExecution(address(0), amount, _buildMessage(address(claimer)));

        vm.prank(address(claimer));
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(address(0), amount + 1);
    }

    function test_ClaimFailedTransfer_IsolatedPerAccount() public {
        PayableToggleAccount claimerA = new PayableToggleAccount();
        claimerA.setAccept(false);
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);
        adapter.processRelayExecution(address(0), amount, _buildMessage(address(claimerA)));

        // another account cannot claim A's escrow
        address other = makeAddr("other");
        vm.prank(other);
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTOR FAILURE CONTAINMENT
    //////////////////////////////////////////////////////////////*/

    function test_ExecutorRevert_FundsStayWithAccount() public {
        executor.setShouldRevert(true);
        uint256 amount = 100e18;
        token.mint(address(adapter), amount);

        vm.expectEmit(true, false, false, false);
        emit RelayAdapter.ExecutionFailed(account);

        adapter.processRelayExecution(address(token), amount, _buildMessage(account));

        // funds forwarded despite executor failure
        assertEq(token.balanceOf(account), amount);
    }

    function test_ExecutorReturnbomb_DoesNotBreakAdapter() public {
        executor.setShouldRevert(true);
        executor.setShouldReturnbomb(true);
        uint256 amount = 100e18;
        token.mint(address(adapter), amount);

        adapter.processRelayExecution(address(token), amount, _buildMessage(account));

        assertEq(token.balanceOf(account), amount);
    }

    /*//////////////////////////////////////////////////////////////
                             FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_ProcessRelayExecution_ERC20(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        token.mint(address(adapter), amount);

        adapter.processRelayExecution(address(token), amount, _buildMessage(account));

        assertEq(token.balanceOf(account), amount);
        assertEq(adapter.totalEscrowed(address(token)), 0);
    }

    function testFuzz_ProcessRelayExecution_GarbageMessage(bytes calldata garbage) public {
        vm.assume(garbage.length < 500);
        token.mint(address(adapter), 1e18);

        // must never forward funds or corrupt state on undecodable input
        try adapter.processRelayExecution(address(token), 1e18, garbage) {
            // if it decoded by chance, funds either forwarded to a valid account or escrowed
        } catch {
            // decode revert — nothing moved
            assertEq(token.balanceOf(address(adapter)), 1e18);
        }
        assertEq(adapter.totalEscrowed(address(token)) <= 1e18, true);
    }

    /*//////////////////////////////////////////////////////////////
                             HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildMessage(address account_) internal view returns (bytes memory) {
        return abi.encode(bytes(""), _buildSigData(account_));
    }

    function _buildSigData(address account_) internal view returns (bytes memory) {
        return _buildSigDataForChain(account_, uint64(block.chainid));
    }

    function _buildSigDataForChain(address account_, uint64 chainId) internal view returns (bytes memory) {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account_,
                executor: address(0xCAFE),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0xFACE),
                data: hex"deadbeef"
            })
        });

        return abi.encode(
            new uint64[](0),
            uint48(block.timestamp + 3600),
            uint48(0),
            keccak256("test_merkle_root"),
            new bytes32[](0),
            proofDst,
            bytes(hex"abcdef")
        );
    }
}

/// @dev Account that can toggle whether it accepts native transfers
contract PayableToggleAccount {
    bool public accept;

    function setAccept(bool v) external {
        accept = v;
    }

    receive() external payable {
        require(accept, "REJECT");
    }
}
