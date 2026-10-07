// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { Execution, ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";
import { HelperBase } from "modulekit/test/helpers/HelperBase.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { SuperValidatorV2 } from "../../../src/validators/SuperValidatorV2.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";

import "forge-std/console2.sol";

/// @title SuperValidatorV2MigrationTxDataTest
/// @author Superform Labs
/// @notice Produces, and proves, the ONE-OFF migration transaction for an account moving from
///         `SuperValidator` to `SuperValidatorV2`: in a single user operation it installs V2, uninstalls V1,
///         and sweeps the account's ERC-20 and native balances to an EOA.
/// @dev THE OUTPUT IS THE POINT. `test_Migration_EmitThePayloadToSign` logs every field the signer needs —
///      run it with `-vv` and hand the payload over:
///
///        forge test --match-test test_Migration_EmitThePayloadToSign -vv
///
///      The addresses it prints are this test's, so the operator must regenerate against the real account,
///      the real validator deployments and the real Base Smart Wallet. The VALUE of emitting it here is that
///      the same bytes are then executed against a real ERC-7579 account in the test below, so the shape of
///      the payload is proven rather than hand-reasoned.
/// @dev WHY V1 SIGNS ITS OWN REMOVAL. The user operation is validated by the validator that is installed
///      when validation runs, which is still V1 — so the account's EXISTING signer authorises the switch.
///      That is also why the batch order is load-bearing (see
///      `test_Migration_RevertIf_V1UninstalledBeforeV2Installed`): an ERC-7579 account refuses to drop its
///      last validator, so install must precede uninstall or the whole batch reverts.
/// @dev The uninstall payload is built with the account helper's own
///      `getUninstallModuleData`, not hand-rolled: Nexus keeps validators in a linked list and the
///      de-init data carries the previous-node pointer. Hand-writing that is the easiest way to produce a
///      payload that looks right and bricks the account.
contract SuperValidatorV2MigrationTxDataTest is RhinestoneModuleKit, InternalHelpers, MerkleTreeHelper {
    using ModuleKitHelpers for *;

    SuperValidator internal v1;
    SuperValidatorV2 internal v2;
    MockERC20 internal token;

    AccountInstance internal instance;
    address internal account;

    address internal eoaOwner;
    uint256 internal eoaKey;
    address internal sweepTo;

    /// @dev The Base Smart Wallet that owns V2 after the migration. This literal is the wallet the real-flow
    ///      suite creates from the live Coinbase factory; swap it for the user's own before signing.
    address internal constant BASE_SMART_WALLET = 0x3d45Af71aE43bf288eAF5A49018f0032EDa08934;

    uint256 internal constant TOKEN_BALANCE = 1234e6;
    uint256 internal constant NATIVE_BALANCE = 3 ether;
    /// @dev A PARTIAL native sweep, deliberately. The account pays its own gas, so a batch that sends the
    ///      entire balance leaves nothing for the EntryPoint's prefund and the whole operation reverts with
    ///      no revert data — which is what the first version of this test did. Sweep an amount, never
    ///      `address(this).balance`.
    uint256 internal constant NATIVE_SWEEP = 1 ether;
    uint48 internal constant VALID_UNTIL = 2_000_000_000;

    function setUp() public {
        v1 = new SuperValidator();
        v2 = new SuperValidatorV2();
        token = new MockERC20("USD Coin", "USDC", 6);

        (eoaOwner, eoaKey) = makeAddrAndKey("migrating-account-owner");
        sweepTo = makeAddr("sweep-destination-eoa");

        instance = makeAccountInstance(keccak256("SUP-17924-migration-txdata"));
        account = instance.account;
        instance.installModule(MODULE_TYPE_VALIDATOR, address(v1), abi.encode(eoaOwner));

        token.mint(account, TOKEN_BALANCE);
        vm.deal(account, NATIVE_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                         THE MIGRATION BATCH
    //////////////////////////////////////////////////////////////*/

    /// @dev install V2 -> uninstall V1 -> sweep ERC-20 -> sweep native, in that order.
    /// @dev THE OPERATIONAL TRAP, and the reason this helper simulates before it encodes. Nexus keeps
    ///      validators in a SENTINEL LINKED LIST, and a validator's de-init payload carries the address of
    ///      its PREDECESSOR in that list. Installing V2 rewires the list, so V1's predecessor inside the
    ///      batch is NOT what a pre-batch read reports: encoding against the live account yields a payload
    ///      that reverts `LinkedList_InvalidEntry(prev)` partway through the batch. The first version of
    ///      this test did exactly that, which is why it is worth asserting rather than commenting.
    ///      So the pointer is computed against the POST-INSTALL list: install V2 on a state snapshot, read
    ///      the de-init data there, roll back, then build the batch. An operator preparing this for real
    ///      must simulate the same way rather than query the live account.
    function _migrationExecutions() internal returns (Execution[] memory executions) {
        uint256 snapshot = vm.snapshotState();
        vm.prank(account);
        IERC7579Account(account).installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(BASE_SMART_WALLET));
        bytes memory deInitV1 =
            HelperBase(instance.accountHelper).getUninstallModuleData(instance, MODULE_TYPE_VALIDATOR, address(v1), "");
        vm.revertToState(snapshot);

        executions = new Execution[](4);
        executions[0] = Execution({
            target: account,
            value: 0,
            callData: abi.encodeCall(
                IERC7579Account.installModule, (MODULE_TYPE_VALIDATOR, address(v2), abi.encode(BASE_SMART_WALLET))
            )
        });
        executions[1] = Execution({
            target: account,
            value: 0,
            callData: abi.encodeCall(IERC7579Account.uninstallModule, (MODULE_TYPE_VALIDATOR, address(v1), deInitV1))
        });
        executions[2] = Execution({
            target: address(token), value: 0, callData: abi.encodeCall(IERC20.transfer, (sweepTo, TOKEN_BALANCE))
        });
        executions[3] = Execution({ target: sweepTo, value: NATIVE_SWEEP, callData: "" });
    }

    /// @dev Signs the batch under V1's merkle scheme: a single-leaf tree whose leaf commits V1's address, and
    ///      a message hash namespaced `"SuperValidator"`. This is what the account's existing owner signs.
    function _signUnderV1(UserOpData memory userOpData) internal view returns (bytes memory sigData, bytes32 toSign) {
        bytes32 root = _createSourceValidatorLeaf(userOpData.userOpHash, VALID_UNTIL, 0, new uint64[](0), address(v1));
        toSign = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(v1.namespace(), root)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaKey, toSign);

        sigData = abi.encode(
            new uint64[](0),
            VALID_UNTIL,
            uint48(0),
            root,
            new bytes32[](0),
            new ISuperValidator.DstProof[](0),
            abi.encodePacked(r, s, v)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              THE DELIVERABLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Emits every field the signer needs for the one-off migration. Run with `-vv`.
    function test_Migration_EmitThePayloadToSign() public {
        UserOpData memory userOpData = instance.getExecOps(_migrationExecutions(), address(v1));
        (bytes memory sigData, bytes32 toSign) = _signUnderV1(userOpData);

        console2.log("=== SuperValidatorV2 migration: one-off payload ===");
        console2.log("account (userOp.sender) ", account);
        console2.log("validator that validates ", address(v1));
        console2.log("validator being installed", address(v2));
        console2.log("V2 owner after migration ", BASE_SMART_WALLET);
        console2.log("sweep destination (EOA)  ", sweepTo);
        console2.log("userOp.nonce");
        console2.log(userOpData.userOp.nonce);
        console2.log("txData  (userOp.callData) ->");
        console2.logBytes(userOpData.userOp.callData);
        console2.log("userOpHash ->");
        console2.logBytes32(userOpData.userOpHash);
        console2.log("hash the owner signs (already eth-signed-prefixed) ->");
        console2.logBytes32(toSign);
        console2.log("userOp.signature (merkle sigData) ->");
        console2.logBytes(sigData);

        // The payload is not just printed: it is the payload executed below.
        assertGt(userOpData.userOp.callData.length, 0, "no txData produced");
        assertGt(sigData.length, 0, "no signature produced");
    }

    /*//////////////////////////////////////////////////////////////
                         AND IT ACTUALLY WORKS
    //////////////////////////////////////////////////////////////*/

    /// @notice THE WHOLE MIGRATION, atomically, in one user operation signed by the account's EXISTING owner
    ///         under V1: V2 installed and owned by the Base Smart Wallet, V1 uninstalled and de-initialised,
    ///         and both balances swept to the EOA.
    function test_Migration_OneTransactionInstallsUninstallsAndSweeps() public {
        assertTrue(v1.isInitialized(account), "V1 should start installed");
        assertFalse(v2.isInitialized(account), "V2 should start absent");

        UserOpData memory userOpData = instance.getExecOps(_migrationExecutions(), address(v1));
        (bytes memory sigData,) = _signUnderV1(userOpData);
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        // --- the module swap ---
        assertTrue(v2.isInitialized(account), "V2 was not installed");
        assertEq(v2.getAccountOwner(account), BASE_SMART_WALLET, "V2 owner is not the Base Smart Wallet");
        assertTrue(instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, address(v2)), "account does not list V2");

        // `onUninstall` ran, so V1's own state is cleared — not merely unlisted by the account.
        assertFalse(v1.isInitialized(account), "V1 was not de-initialised");
        assertEq(v1.getAccountOwner(account), address(0), "V1 still remembers the owner");
        assertFalse(instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, address(v1)), "account still lists V1");

        // --- the sweep ---
        assertEq(token.balanceOf(account), 0, "ERC-20 not swept");
        assertEq(token.balanceOf(sweepTo), TOKEN_BALANCE, "EOA did not receive the ERC-20");
        assertEq(sweepTo.balance, NATIVE_SWEEP, "EOA did not receive the native sweep");
        assertLe(account.balance, NATIVE_BALANCE - NATIVE_SWEEP, "account native not debited");
    }

    /// @notice ORDER IS LOAD-BEARING, and getting it wrong is a bricked account rather than a failed
    ///         transaction — so it is asserted. An ERC-7579 account refuses to remove its last validator,
    ///         so a batch that uninstalls V1 before installing V2 reverts as a whole. Atomicity is what
    ///         makes the correct order safe: there is no instant in which the account has no validator.
    /// @dev Issued straight at the account rather than through `executeOp`. The EntryPoint does not bubble a
    ///      failed operation — it emits `UserOperationRevertReason` and ModuleKit turns that into a test
    ///      failure, so `vm.expectRevert` never sees it. Calling `execute` as the account (the self-call
    ///      path `installModule` and `uninstallModule` require anyway) puts the revert in this frame, where
    ///      it can be asserted.
    function test_Migration_RevertIf_V1UninstalledBeforeV2Installed() public {
        Execution[] memory ordered = _migrationExecutions();
        Execution[] memory swapped = new Execution[](4);
        swapped[0] = ordered[1]; // uninstall first
        swapped[1] = ordered[0]; // install second
        swapped[2] = ordered[2];
        swapped[3] = ordered[3];

        vm.prank(account);
        vm.expectRevert();
        IERC7579Account(account).execute(ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(swapped));

        // Nothing moved: the account is exactly as it was.
        assertTrue(v1.isInitialized(account), "V1 should survive a reverted batch");
        assertFalse(v2.isInitialized(account), "V2 should not be installed by a reverted batch");
        assertEq(token.balanceOf(account), TOKEN_BALANCE, "no funds should move on a reverted batch");
        assertEq(sweepTo.balance, 0, "no native should move on a reverted batch");
    }

    /// @notice And the correct order succeeds through the very same direct path, so the test above is about
    ///         ordering and not about the batch being malformed.
    function test_Migration_CorrectOrderSucceedsOnTheSamePath() public {
        Execution[] memory ordered = _migrationExecutions();

        vm.prank(account);
        IERC7579Account(account).execute(ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(ordered));

        assertTrue(v2.isInitialized(account), "V2 not installed");
        assertFalse(v1.isInitialized(account), "V1 not uninstalled");
        assertEq(token.balanceOf(sweepTo), TOKEN_BALANCE, "ERC-20 not swept");
        assertEq(sweepTo.balance, NATIVE_SWEEP, "native not swept");
    }

    /// @notice After migrating, V1 is dead for this account: its validator path reverts `NOT_INITIALIZED`,
    ///         so a leftover V1-signed intent cannot be replayed against the migrated account. Note this
    ///         builds a FRESH, trivial operation rather than reusing the migration batch — rebuilding that
    ///         batch would try to install V2 a second time and fail on the linked list instead, which would
    ///         prove nothing about V1.
    function test_Migration_V1CannotValidateAfterwards() public {
        UserOpData memory migration = instance.getExecOps(_migrationExecutions(), address(v1));
        (bytes memory sigData,) = _signUnderV1(migration);
        migration.userOp.signature = sigData;
        executeOp(migration);

        UserOpData memory stale =
            instance.getExecOps(address(token), 0, abi.encodeCall(IERC20.transfer, (sweepTo, 1)), address(v1));
        (bytes memory staleSig,) = _signUnderV1(stale);
        stale.userOp.signature = staleSig;

        vm.expectRevert(ISuperValidator.NOT_INITIALIZED.selector);
        v1.validateUserOp(stale.userOp, stale.userOpHash);
    }
}
