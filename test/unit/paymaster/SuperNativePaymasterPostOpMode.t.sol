// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IAccount } from "@ERC4337/account-abstraction/contracts/interfaces/IAccount.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { etchEntrypoint, ENTRYPOINT_ADDR } from "modulekit/deployment/predeploy/EntryPoint.sol";

import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";

/// @notice Minimal ERC-4337 v0.7 account: validation always succeeds, execution succeeds or reverts on demand.
/// @dev Stands in for a Nexus account running a SuperExecutor batch whose fee-charging hook reverts. Validation
///      must pass (the paymaster performs no balance check), so only the EXECUTION phase fails — the exact shape
///      of the production incident.
contract RevertingAccount is IAccount {
    error EXECUTION_FAILED();

    bool public shouldRevert;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function validateUserOp(PackedUserOperation calldata, bytes32, uint256) external pure returns (uint256) {
        return 0; // valid, no time range
    }

    /// @dev The call EntryPoint makes during the execution phase.
    function doWork() external view {
        if (shouldRevert) revert EXECUTION_FAILED();
    }

    receive() external payable { }
}

/// @notice End-to-end `postOp` coverage against the REAL ERC-4337 v0.7 EntryPoint (SUP-21683).
/// @dev The pre-existing unit suite drives `postOp` through a MockEntryPoint, which never exercises the
///      EntryPoint's own mode selection. This suite etches the real EntryPoint, so the mode is chosen by
///      EntryPoint from the actual outcome of the operation rather than passed in by the test.
contract SuperNativePaymasterPostOpModeTest is Test {
    IEntryPoint internal entryPoint;
    SuperNativePaymaster internal paymaster;
    RevertingAccount internal account;

    /// @dev The budget configured in production and used by the incident transaction.
    uint128 internal constant POST_OP_GAS_LIMIT = 25_000;
    uint128 internal constant VERIFICATION_GAS_LIMIT = 500_000;
    uint128 internal constant CALL_GAS_LIMIT = 200_000;
    uint256 internal constant MAX_FEE_PER_GAS = 10 gwei;
    uint256 internal constant MAX_PRIORITY_FEE_PER_GAS = 1 gwei;
    /// @dev Deliberately generous so a refund is always owed on the success path.
    uint256 internal constant MAX_GAS_LIMIT = 5_000_000;

    address internal bundler = address(0xB0);

    function setUp() public {
        entryPoint = etchEntrypoint();
        paymaster = new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR));
        account = new RevertingAccount();
        vm.deal(bundler, 100 ether);
        vm.fee(1 gwei);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _op(uint256 premium) internal view returns (PackedUserOperation[] memory ops) {
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster),
            POST_OP_GAS_LIMIT, // paymasterVerificationGasLimit
            POST_OP_GAS_LIMIT, // paymasterPostOpGasLimit — the budget under test
            abi.encode(MAX_GAS_LIMIT, premium, uint256(POST_OP_GAS_LIMIT))
        );

        ops = new PackedUserOperation[](1);
        ops[0] = PackedUserOperation({
            sender: address(account),
            nonce: entryPoint.getNonce(address(account), 0),
            initCode: "",
            callData: abi.encodeCall(RevertingAccount.doWork, ()),
            accountGasLimits: bytes32((uint256(VERIFICATION_GAS_LIMIT) << 128) | uint256(CALL_GAS_LIMIT)),
            preVerificationGas: 50_000,
            gasFees: bytes32((uint256(MAX_PRIORITY_FEE_PER_GAS) << 128) | uint256(MAX_FEE_PER_GAS)),
            paymasterAndData: paymasterAndData,
            signature: ""
        });
    }

    /// @dev Runs one op through the real EntryPoint via the paymaster wrapper and reports what the account got.
    function _run(bool revertDuringExecution) internal returns (uint256 accountGain, bool opSucceeded) {
        account.setShouldRevert(revertDuringExecution);
        PackedUserOperation[] memory ops = _op(0);

        uint256 before = address(account).balance;
        vm.recordLogs();
        vm.prank(bundler);
        paymaster.handleOps{ value: 1 ether }(ops);
        accountGain = address(account).balance - before;

        // UserOperationEvent(bytes32 userOpHash, address sender, address paymaster, uint256 nonce, bool success, ...)
        bytes32 topic = keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == topic) {
                // data = (nonce, success, actualGasCost, actualGasUsed); the first word is the NONCE.
                (, bool success,,) = abi.decode(logs[i].data, (uint256, bool, uint256, uint256));
                opSucceeded = success;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev THE REGRESSION. A userOp that passes validation and reverts in execution must receive NO native
    ///      refund, while the outer transaction still succeeds and the operation is recorded as failed.
    function test_RealEntryPoint_RevertedOp_ReceivesNoRefund() public {
        (uint256 gain, bool success) = _run(true);

        assertFalse(success, "EntryPoint must record the operation as failed");
        assertEq(gain, 0, "a reverted operation must not be refunded");
    }

    /// @dev The success path is untouched: the same operation, not reverting, is still refunded.
    function test_RealEntryPoint_SucceededOp_StillRefunded() public {
        (uint256 gain, bool success) = _run(false);

        assertTrue(success, "control: the operation must succeed");
        assertGt(gain, 0, "successful cashback must survive the guard");
    }

    /// @dev Both outcomes under one configured 25,000-gas postOp budget: neither path runs out of gas, and only
    ///      the successful one pays out. Pins the acceptance criterion about the production budget.
    function test_RealEntryPoint_PostOpBudget25k_BothPathsComplete() public {
        (uint256 revertedGain, bool revertedSuccess) = _run(true);
        (uint256 okGain, bool okSuccess) = _run(false);

        assertFalse(revertedSuccess);
        assertTrue(okSuccess, "postOp must not run out of gas within the 25k budget");
        assertEq(revertedGain, 0);
        assertGt(okGain, 0);
    }

    /// @dev No `SuperNativePaymasterRefund` is emitted for a failed operation, but the diagnostic PostOp event is.
    function test_RealEntryPoint_RevertedOp_EmitsPostOpButNotRefund() public {
        account.setShouldRevert(true);
        PackedUserOperation[] memory ops = _op(0);

        vm.recordLogs();
        vm.prank(bundler);
        paymaster.handleOps{ value: 1 ether }(ops);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 refundTopic = keccak256("SuperNativePaymasterRefund(address,uint256,uint256)");
        bytes32 postOpTopic = keccak256("SuperNativePaymasterPostOp(bytes)");
        bool sawRefund;
        bool sawPostOp;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(paymaster)) continue;
            if (logs[i].topics[0] == refundTopic) sawRefund = true;
            if (logs[i].topics[0] == postOpTopic) sawPostOp = true;
        }
        assertFalse(sawRefund, "no refund event may be emitted for a failed operation");
        assertTrue(sawPostOp, "the postOp diagnostic event must be retained");
    }

    /// @dev Mixed batch through one `handleOps`: the failed op is not refunded, the successful one is. Uses two
    ///      accounts so the per-op outcome is attributable.
    function test_RealEntryPoint_MixedBatch_OnlySuccessfulRefunded() public {
        RevertingAccount bad = new RevertingAccount();
        RevertingAccount good = new RevertingAccount();
        bad.setShouldRevert(true);
        good.setShouldRevert(false);

        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _op(0)[0];
        ops[0].sender = address(bad);
        ops[0].nonce = entryPoint.getNonce(address(bad), 0);
        ops[1] = _op(0)[0];
        ops[1].sender = address(good);
        ops[1].nonce = entryPoint.getNonce(address(good), 0);

        uint256 badBefore = address(bad).balance;
        uint256 goodBefore = address(good).balance;

        vm.prank(bundler);
        paymaster.handleOps{ value: 2 ether }(ops);

        assertEq(address(bad).balance - badBefore, 0, "failed op in a mixed batch must not be refunded");
        assertGt(address(good).balance - goodBefore, 0, "successful op in a mixed batch must still be refunded");
    }

    /// @dev `sponsorNativeAndHandleOps` behaves the same on the refund path, and the sponsorship deposit made
    ///      before execution is NOT rolled back by a failed operation — it stays reclaimable by the sponsor.
    function test_RealEntryPoint_SponsorWrapper_RevertedOp_NoRefund_DepositRetained() public {
        MockSponsorship sponsorship = new MockSponsorship();
        account.setShouldRevert(true);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits = new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: 0.1 ether });

        // Build the op BEFORE pranking: `_op` reads the nonce from EntryPoint, and that external call would
        // otherwise consume the prank, leaving the test contract as `msg.sender` (and as EntryPoint's beneficiary).
        PackedUserOperation[] memory ops = _op(0);

        uint256 before = address(account).balance;
        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1 ether }(ops, deposits, address(sponsorship));

        assertEq(address(account).balance - before, 0, "reverted op must not be refunded via the sponsor wrapper");
        assertEq(sponsorship.totalDeposited(), 0.1 ether, "sponsorship deposit must be retained, not rolled back");
        assertEq(sponsorship.sponsorOf(address(account)), bundler, "caller remains the sponsor of record");
    }
}

/// @notice Records `depositForAccount` calls so the wrapper's deposit behaviour can be asserted.
/// @dev Deliberately not inheriting `INativeFeeSponsorship`: the paymaster only ever calls `depositForAccount`,
///      and implementing the full interface would add surface this regression does not exercise.
contract MockSponsorship {
    uint256 public totalDeposited;

    mapping(address => address) public sponsorOf;

    function depositForAccount(address sponsor, address account) external payable {
        totalDeposited += msg.value;
        sponsorOf[account] = sponsor;
    }
}
