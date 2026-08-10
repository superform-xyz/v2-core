// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { RelayAdapter } from "../../../src/adapters/RelayAdapter.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { Vm } from "forge-std/Vm.sol";

/// @title RelayAdapterE2EFork
/// @notice E2E fork test for RelayAdapter: compact 2-field message format (initData, sigData)
/// @dev Tests the complete flow on a Base fork:
///      1. Deploy local RelayAdapter against the deployed SuperDestinationExecutor
///      2. Simulate the Relay solver delivering tokens to the adapter (atomic batch leg 1)
///      3. processRelayExecution with compact 2-field format (atomic batch leg 2)
///      4. Validates permissionless guards, transfer, failed transfers, claim flow
contract RelayAdapterE2EFork is MerkleTreeHelper {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Tokens
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Deployed Superform contracts on Base
    address public constant SUPER_DST_EXECUTOR_BASE = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public baseForkId;
    RelayAdapter public adapter;

    address public solver;
    address public dstAccount;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        baseForkId = vm.createFork(vm.envString(BASE_RPC_URL_KEY));
        vm.selectFork(baseForkId);

        solver = makeAddr("relaySolver");
        dstAccount = makeAddr("dstAccount");

        adapter = new RelayAdapter(SUPER_DST_EXECUTOR_BASE);
        vm.label(address(adapter), "RelayAdapter");
    }

    /*//////////////////////////////////////////////////////////////
                        E2E FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Solver delivers USDC then calls processRelayExecution — funds land at account
    function test_Fork_Relay_TransferSucceeds() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount); // leg 1: solver fill delivered to adapter

        bytes memory message = _buildMessage(dstAccount, hex"deadbeef");

        vm.prank(solver); // leg 2: permissionless — any caller works
        adapter.processRelayExecution(USDC_BASE, amount, message);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "dstAccount should have received USDC");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "Adapter should be empty");
    }

    /// @notice Execution fails (invalid signature vs real executor) but tokens still reach the account
    function test_Fork_Relay_ExecutionFails_TokensTransferred() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        bytes memory message = _buildMessage(dstAccount, hex"deadbeef");

        vm.recordLogs();

        vm.prank(solver);
        adapter.processRelayExecution(USDC_BASE, amount, message);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "dstAccount should have USDC");
        assertEq(adapter.failedTransfers(dstAccount, USDC_BASE), 0, "No failed transfers");

        // Real executor rejects the dummy proof — ExecutionFailed emitted, funds safe
        _assertEventEmitted(vm.getRecordedLogs(), "ExecutionFailed(address)");
    }

    /// @notice Native fill via msg.value — forwarded to account
    function test_Fork_Relay_NativeFill_MsgValue() public {
        uint256 amount = 1 ether;
        vm.deal(solver, amount);

        bytes memory message = _buildMessage(dstAccount, hex"deadbeef");

        vm.prank(solver);
        adapter.processRelayExecution{ value: amount }(address(0), amount, message);

        assertEq(dstAccount.balance, amount, "dstAccount should have received ETH");
        assertEq(address(adapter).balance, 0, "Adapter should be empty");
    }

    /// @notice Transfer fails → escrowed in failedTransfers → claim recovers
    function test_Fork_Relay_TransferFails_ClaimFailedTransfer() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        vm.mockCall(USDC_BASE, abi.encodeCall(IERC20.transfer, (dstAccount, amount)), abi.encode(false));

        bytes memory message = _buildMessage(dstAccount, hex"deadbeef");
        vm.prank(solver);
        adapter.processRelayExecution(USDC_BASE, amount, message);

        vm.clearMockedCalls();

        assertEq(adapter.failedTransfers(dstAccount, USDC_BASE), amount, "Should be in failedTransfers");
        assertEq(adapter.totalEscrowed(USDC_BASE), amount, "Escrow accounted");

        vm.prank(dstAccount);
        adapter.claimFailedTransfer(USDC_BASE, amount);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount, "dstAccount recovered");
        assertEq(adapter.failedTransfers(dstAccount, USDC_BASE), 0, "failedTransfers cleared");
        assertEq(adapter.totalEscrowed(USDC_BASE), 0, "Escrow cleared");
    }

    /*//////////////////////////////////////////////////////////////
                    PERMISSIONLESS GUARDS ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Phantom-credit attack: claim without delivery reverts
    function test_Fork_Relay_PhantomCredit_Reverts() public {
        bytes memory message = _buildMessage(dstAccount, hex"deadbeef");

        vm.prank(makeAddr("attacker"));
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(USDC_BASE, 1000e6, message);
    }

    /// @notice Escrow-sweep attack: escrowed failed-transfer funds cannot be redirected
    ///         by a caller presenting a message for a different account
    function test_Fork_Relay_EscrowSweep_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        // create escrow for victim
        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));
        vm.prank(solver);
        adapter.processRelayExecution(USDC_BASE, amount, _buildMessage(dstAccount, hex"deadbeef"));
        vm.clearMockedCalls();

        assertEq(adapter.totalEscrowed(USDC_BASE), amount);

        // attacker points own-account message at the escrowed balance
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(USDC_BASE, amount, _buildMessage(attacker, hex"deadbeef"));

        // victim's escrow untouched and claimable
        vm.prank(dstAccount);
        adapter.claimFailedTransfer(USDC_BASE, amount);
        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount);
    }

    /// @notice DOCUMENTED RESIDUAL (SECURITY.md #14): funds parked between two SEPARATE solver
    ///         txs are forwardable by any caller with a validly-shaped own-account message.
    ///         This test pins the accepted behavior so any future change is visible.
    function test_Fork_Relay_NonAtomicWindow_DocumentedResidual() public {
        uint256 amount = 1000e6;
        // leg 1 landed, leg 2 not yet executed (solver deviating from atomic batching)
        deal(USDC_BASE, address(adapter), amount);

        address opportunist = makeAddr("opportunist");
        vm.prank(opportunist);
        adapter.processRelayExecution(USDC_BASE, amount, _buildMessage(opportunist, hex"deadbeef"));

        // The opportunist CAN capture the un-escrowed in-flight balance — accepted trust
        // assumption; mitigation is procedural (bundler mandates one atomic txs[] batch).
        assertEq(IERC20(USDC_BASE).balanceOf(opportunist), amount, "documented residual: window exists");
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Relay_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert(RelayAdapter.ADDRESS_NOT_VALID.selector);
        new RelayAdapter(address(0));
    }

    function test_Fork_Relay_ZeroAccount_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        vm.prank(solver);
        vm.expectRevert(RelayAdapter.ACCOUNT_NOT_VALID.selector);
        adapter.processRelayExecution(USDC_BASE, amount, _buildMessage(address(0), hex"deadbeef"));
    }

    function test_Fork_Relay_NoDstProofForChain_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        bytes memory sigData = _encodeSigDataForChain(dstAccount, hex"deadbeef", 999);
        bytes memory message = abi.encode(bytes(""), sigData);

        vm.prank(solver);
        vm.expectRevert(RelayAdapter.NO_DST_PROOF_FOR_CHAIN.selector);
        adapter.processRelayExecution(USDC_BASE, amount, message);
    }

    function test_Fork_Relay_MultipleDstProofs_TakesFirstMatch() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        address firstAccount = makeAddr("first");
        address secondAccount = makeAddr("second");

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](3);
        proofDst[0] = _makeDstProof(makeAddr("ethAccount"), hex"aa", 1);
        proofDst[1] = _makeDstProof(firstAccount, hex"bb", uint64(block.chainid));
        proofDst[2] = _makeDstProof(secondAccount, hex"cc", uint64(block.chainid));

        bytes memory message = abi.encode(bytes(""), _encodeSigDataWithProofs(proofDst));

        vm.prank(solver);
        adapter.processRelayExecution(USDC_BASE, amount, message);

        assertEq(IERC20(USDC_BASE).balanceOf(firstAccount), amount, "First match should receive tokens");
        assertEq(IERC20(USDC_BASE).balanceOf(secondAccount), 0, "Second match should get nothing");
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM ISOLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Relay_ClaimByUnauthorizedUser_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));
        vm.prank(solver);
        adapter.processRelayExecution(USDC_BASE, amount, _buildMessage(dstAccount, hex"deadbeef"));
        vm.clearMockedCalls();

        vm.prank(makeAddr("random"));
        vm.expectRevert(RelayAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(USDC_BASE, amount);
    }

    function test_Fork_Relay_PartialClaim() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, address(adapter), amount);

        vm.mockCall(USDC_BASE, abi.encodeWithSelector(IERC20.transfer.selector, dstAccount), abi.encode(false));
        vm.prank(solver);
        adapter.processRelayExecution(USDC_BASE, amount, _buildMessage(dstAccount, hex"deadbeef"));
        vm.clearMockedCalls();

        vm.prank(dstAccount);
        adapter.claimFailedTransfer(USDC_BASE, amount / 2);

        assertEq(IERC20(USDC_BASE).balanceOf(dstAccount), amount / 2, "Half claimed");
        assertEq(adapter.failedTransfers(dstAccount, USDC_BASE), amount / 2, "Half remaining");
        assertEq(adapter.totalEscrowed(USDC_BASE), amount / 2, "Escrow tracks remaining");
    }

    /// @notice Immutable getters return correct values
    function test_Fork_Relay_ImmutableGetters() public view {
        assertEq(address(adapter.SUPER_DESTINATION_EXECUTOR()), SUPER_DST_EXECUTOR_BASE);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds the compact 2-field message: abi.encode(initData, sigData)
    function _buildMessage(address account, bytes memory executorCalldata) internal view returns (bytes memory) {
        bytes memory initData = bytes("");
        bytes memory sigData = _encodeSigDataForChain(account, executorCalldata, uint64(block.chainid));
        return abi.encode(initData, sigData);
    }

    /// @dev Encodes SignatureData with a single DstProof for the specified chain
    function _encodeSigDataForChain(
        address account,
        bytes memory executorCalldata,
        uint64 chainId
    )
        internal
        pure
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = _makeDstProof(account, executorCalldata, chainId);
        return _encodeSigDataWithProofs(proofDst);
    }

    /// @dev Creates a single DstProof for the given account, executorCalldata, and chain
    function _makeDstProof(
        address account,
        bytes memory executorCalldata,
        uint64 chainId
    )
        internal
        pure
        returns (ISuperValidator.DstProof memory)
    {
        return ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: address(0xCAFE),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0xFACE),
                data: executorCalldata
            })
        });
    }

    /// @dev Encodes a full SignatureData struct with custom DstProof array
    function _encodeSigDataWithProofs(ISuperValidator.DstProof[] memory proofDst)
        internal
        pure
        returns (bytes memory)
    {
        uint64[] memory chainsWithDstExecution = new uint64[](proofDst.length);
        for (uint256 i = 0; i < proofDst.length; i++) {
            chainsWithDstExecution[i] = proofDst[i].dstChainId;
        }

        return abi.encode(
            chainsWithDstExecution,
            uint48(type(uint48).max), // validUntil
            uint48(0), // validAfter
            keccak256("test_root"), // merkleRoot
            new bytes32[](0), // proofSrc
            proofDst,
            hex"abcdef" // signature (dummy)
        );
    }

    /// @dev Asserts that an event with the given signature was emitted in the recorded logs
    function _assertEventEmitted(Vm.Log[] memory logs, string memory eventSig) internal pure {
        bytes32 topic = keccak256(bytes(eventSig));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                return;
            }
        }
        revert(string.concat("Event not emitted: ", eventSig));
    }
}
