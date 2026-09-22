// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

import { RelayAdapterV2 } from "../../../src/adapters/RelayAdapterV2.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { SuperSenderCreator } from "../../../src/executors/helpers/SuperSenderCreator.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @notice Mock executor exposing the validator getter RelayAdapterV2 caches at construction.
contract MockExecutor {
    address public SUPER_DESTINATION_VALIDATOR;

    uint256 public callCount;
    address public lastAccount;

    constructor(address validator_) {
        SUPER_DESTINATION_VALIDATOR = validator_;
    }

    function processBridgedExecution(
        address,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    ) external {
        ++callCount;
        lastAccount = account;
    }
}

/// @notice Minimal code so `account.code.length > 0` passes the account existence check.
contract AccountStub {
    receive() external payable { }
}

/// @notice A token whose `transfer` returns a non-empty payload SHORTER than 32 bytes.
/// @dev V1's `_tryTransfer` would `abi.decode` this and PANIC, propagating an unhandled revert and
///      converting a recoverable escrow into a hard failure. V2's `returnData.length >= 32` guard
///      makes it return false instead, so the amount is escrowed.
contract ShortReturnToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function transfer(address, uint256) external pure returns (bool) {
        assembly {
            mstore(0, 1)
            return(0, 1) // 1 byte: non-empty but undecodable as bool
        }
    }
}

/// @notice Factory the real SuperSenderCreator forwards to; deploys an AccountStub and returns it.
contract AccountFactory {
    address public lastDeployed;

    function deploy() external returns (address) {
        lastDeployed = address(new AccountStub());
        return lastDeployed;
    }

    /// @dev Returns an address that is NOT what it deployed, to exercise INVALID_ACCOUNT.
    function deployMismatched() external returns (address) {
        lastDeployed = address(new AccountStub());
        return address(0xDEAD);
    }
}

/// @title RelayAdapterV2SecurityTests
/// @author Superform Labs
/// @notice Proves the V1 fund-theft gap is CLOSED in RelayAdapterV2, using REAL destination signatures
///         against the real `SuperDestinationValidator`.
/// @dev V1's hole: `processRelayExecution` transferred funds after only a pool-level balance check, with
///      the signature verified afterwards inside a swallowing `catch {}`. Any well-formed byte string
///      with an EMPTY signature could sweep resting balances. V2 authenticates the intent before the
///      transfer. Each `test_GapClosed_*` below is the direct counterpart of a passing V1 exploit test
///      in `test/integration/relay/RelayAdapterPigeonE2E.t.sol`.
contract RelayAdapterV2SecurityTests is MerkleTreeHelper {
    RelayAdapterV2 internal adapter;
    SuperDestinationValidator internal validator;
    MockExecutor internal executor;
    MockERC20 internal token;

    uint256 internal ownerPk = 0xA11CE;
    address internal owner;

    address internal account;
    address internal attacker;
    address internal attackerAccount;

    uint48 internal validUntil;

    function setUp() public {
        owner = vm.addr(ownerPk);
        attacker = makeAddr("attacker");

        validator = new SuperDestinationValidator();
        executor = new MockExecutor(address(validator));
        adapter = new RelayAdapterV2(address(executor));
        token = new MockERC20("Token", "TKN", 18);

        // Both accounts are real contracts that have installed the validator with `owner` as signer.
        account = address(new AccountStub());
        attackerAccount = address(new AccountStub());

        vm.prank(account);
        validator.onInstall(abi.encode(owner));
        vm.prank(attackerAccount);
        validator.onInstall(abi.encode(owner));

        validUntil = uint48(block.timestamp + 1 days);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function _sign(bytes32 root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        return abi.encodePacked(r, s, v);
    }

    /// @dev Builds a genuinely valid message for `acct` — real leaf, real merkle root, real signature.
    function _validMessage(address acct) internal view returns (bytes memory) {
        return _messageFor(acct, address(executor), address(validator), validUntil);
    }

    function _messageFor(
        address acct,
        address proofExecutor,
        address proofValidator,
        uint48 until
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory executorCalldata = bytes("");

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createDestinationValidatorLeaf(
            executorCalldata,
            uint64(block.chainid),
            acct,
            address(executor),
            dstTokens,
            intentAmounts,
            until,
            address(validator)
        );
        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: proof[0],
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: acct,
                executor: proofExecutor,
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: proofValidator,
                data: executorCalldata
            })
        });

        uint64[] memory chains = new uint64[](1);
        chains[0] = uint64(block.chainid);

        bytes memory sigData =
            abi.encode(chains, until, uint48(0), root, new bytes32[](0), proofDst, _sign(root));
        return abi.encode(bytes(""), sigData);
    }

    /// @dev A valid message whose signed intent is for `signedIntentAmount` of `token`.
    function _validMessageForAmount(address acct, uint256 signedIntentAmount)
        internal
        view
        returns (bytes memory)
    {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(token);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = signedIntentAmount;

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createDestinationValidatorLeaf(
            bytes(""),
            uint64(block.chainid),
            acct,
            address(executor),
            dstTokens,
            intentAmounts,
            validUntil,
            address(validator)
        );
        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: proof[0],
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: acct,
                executor: address(executor),
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: address(validator),
                data: bytes("")
            })
        });

        uint64[] memory chains = new uint64[](1);
        chains[0] = uint64(block.chainid);

        return abi.encode(
            bytes(""),
            abi.encode(chains, validUntil, uint48(0), root, new bytes32[](0), proofDst, _sign(root))
        );
    }

    /// @dev The V1-style forged message: fabricated proof, EMPTY signature.
    function _forgedMessage(address acct) internal view returns (bytes memory) {
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: acct,
                executor: address(executor),
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: address(validator),
                data: bytes("")
            })
        });

        uint64[] memory chains = new uint64[](1);
        chains[0] = uint64(block.chainid);

        bytes memory sigData =
            abi.encode(chains, validUntil, uint48(0), bytes32(0), new bytes32[](0), proofDst, bytes(""));
        return abi.encode(bytes(""), sigData);
    }

    /*//////////////////////////////////////////////////////////////
                      THE GAP — CLOSED IN V2
    //////////////////////////////////////////////////////////////*/

    /// @notice **The headline.** An unsigned, fabricated message can no longer move funds.
    /// @dev Counterpart to the passing V1 exploit `test_Adversarial_NoSignatureRequired_FundsStillMove`.
    function test_GapClosed_UnsignedMessageCannotMoveFunds() public {
        token.mint(address(adapter), 1000e18);

        bytes memory forged = _forgedMessage(attackerAccount);

        // The validator rejects the fabricated merkle proof outright (INVALID_PROOF), so the revert
        // originates there rather than from the adapter's own INVALID_SIGNATURE fallback. Either way
        // the transfer is never reached — which is the property under test.
        vm.prank(attacker);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 1000e18, forged);

        assertEq(token.balanceOf(attackerAccount), 0, "no funds moved");
        assertEq(token.balanceOf(address(adapter)), 1000e18, "resting funds untouched");
    }

    /// @notice Resting funds from another user's fill cannot be swept, even by a caller holding a
    ///         validly-signed intent for their OWN account — the signature does not cover this delivery.
    /// @dev In V2 the attacker CAN still present a valid message for their own account; what stops the
    ///      theft is that such a message only exists if someone signed it for them. Here the attacker
    ///      has no signature at all, which is the realistic case.
    function test_GapClosed_MultiVictimSweepBlocked() public {
        token.mint(address(adapter), 1000e18); // two victims' fills resting

        bytes memory forged = _forgedMessage(attackerAccount);

        vm.startPrank(attacker);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 500e18, forged);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 500e18, forged);
        vm.stopPrank();

        assertEq(token.balanceOf(address(adapter)), 1000e18, "both fills still intact");
    }

    /// @notice The burn/griefing variant is closed too: an attacker cannot escrow another user's funds
    ///         to an unclaimable address.
    function test_GapClosed_BurnVariantBlocked() public {
        vm.deal(address(adapter), 1 ether);
        address unclaimable = address(new AccountStub());

        bytes memory forged = _forgedMessage(unclaimable);

        // `unclaimable` never installed the validator, so this reverts NOT_INITIALIZED — still before
        // any funds move, which is the point.
        vm.prank(attacker);
        vm.expectRevert();
        adapter.processRelayExecution(address(0), 1 ether, forged);

        assertEq(adapter.totalEscrowed(address(0)), 0, "nothing stranded");
        assertEq(address(adapter).balance, 1 ether, "funds intact");
    }

    /*//////////////////////////////////////////////////////////////
                         LEGITIMATE FLOW
    //////////////////////////////////////////////////////////////*/

    /// @notice A genuinely signed intent still delivers funds and executes.
    function test_Legit_ValidSignatureDeliversAndExecutes() public {
        token.mint(address(adapter), 1000e18);

        adapter.processRelayExecution(address(token), 1000e18, _validMessage(account));

        assertEq(token.balanceOf(account), 1000e18, "funds delivered");
        assertEq(executor.callCount(), 1, "execution fired");
        assertEq(executor.lastAccount(), account, "correct account");
    }

    /// @notice Still permissionless: anyone may submit a validly-signed intent on the user's behalf.
    function test_Legit_AnyCallerMaySubmitASignedIntent() public {
        token.mint(address(adapter), 500e18);

        vm.prank(attacker); // a third-party relayer, not the beneficiary
        adapter.processRelayExecution(address(token), 500e18, _validMessage(account));

        assertEq(token.balanceOf(account), 500e18, "delivered to the signed account, not the caller");
    }

    /// @notice Native path with a real signature.
    function test_Legit_NativeDelivery() public {
        vm.deal(address(adapter), 1 ether);

        adapter.processRelayExecution(address(0), 1 ether, _validMessage(account));

        assertEq(account.balance, 1 ether, "native delivered");
    }

    /*//////////////////////////////////////////////////////////////
                    ACCOUNT CREATION (first-time users)
    //////////////////////////////////////////////////////////////*/

    /// @dev initData layout consumed by _validateOrCreateAccount:
    ///      [0:20] senderCreator, [20:40] factory, [40:] factory calldata
    function _initData(address senderCreator, address factory, bytes memory factoryCall)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(senderCreator, factory, factoryCall);
    }

    /// @dev Rebuilds a signed message carrying `initData`, for an account that does not exist yet.
    function _messageWithInitData(address acct, bytes memory initData) internal view returns (bytes memory) {
        (, bytes memory sigData) = abi.decode(_messageFor(acct, address(executor), address(validator), validUntil), (bytes, bytes));
        return abi.encode(initData, sigData);
    }

    /// @notice A first-time account is created by the adapter before the signature is verified,
    ///         mirroring SuperDestinationExecutor's own ordering.
    function test_Create_FirstTimeAccountIsDeployedThenValidated() public {
        SuperSenderCreator creator = new SuperSenderCreator();
        AccountFactory factory = new AccountFactory();

        // Predict the account the factory will deploy, then install the validator for it.
        address predicted = vm.computeCreateAddress(address(factory), 1);
        vm.prank(predicted);
        vm.etch(predicted, hex"00"); // temporary code so onInstall's msg.sender is a contract
        validator.onInstall(abi.encode(owner));
        vm.etch(predicted, hex""); // remove it again: the account must NOT exist yet

        bytes memory initData =
            _initData(address(creator), address(factory), abi.encodeCall(AccountFactory.deploy, ()));

        token.mint(address(adapter), 100e18);
        adapter.processRelayExecution(address(token), 100e18, _messageWithInitData(predicted, initData));

        assertGt(predicted.code.length, 0, "account was created");
        assertEq(token.balanceOf(predicted), 100e18, "funds delivered to the new account");
    }

    /// @notice A factory returning an address other than the signed account is rejected.
    function test_Create_RevertIf_CreatedAddressMismatch() public {
        SuperSenderCreator creator = new SuperSenderCreator();
        AccountFactory factory = new AccountFactory();
        address notYetDeployed = makeAddr("ghost");

        bytes memory initData =
            _initData(address(creator), address(factory), abi.encodeCall(AccountFactory.deployMismatched, ()));
        bytes memory message = _messageWithInitData(notYetDeployed, initData);

        token.mint(address(adapter), 100e18);
        vm.expectRevert(RelayAdapterV2.INVALID_ACCOUNT.selector);
        adapter.processRelayExecution(address(token), 100e18, message);
        assertEq(token.balanceOf(address(adapter)), 100e18, "no funds moved");
    }

    /// @notice A senderCreator with no code is rejected.
    function test_Create_RevertIf_SenderCreatorHasNoCode() public {
        address ghostAccount = makeAddr("ghostAccount");
        bytes memory initData = _initData(makeAddr("notAContract"), address(0), bytes(""));
        bytes memory message = _messageWithInitData(ghostAccount, initData);

        token.mint(address(adapter), 100e18);
        vm.expectRevert(RelayAdapterV2.SENDER_CREATOR_NOT_VALID.selector);
        adapter.processRelayExecution(address(token), 100e18, message);
    }

    /// @notice A zero senderCreator is rejected.
    function test_Create_RevertIf_SenderCreatorZero() public {
        address ghostAccount = makeAddr("ghostAccount2");
        bytes memory initData = _initData(address(0), address(0), bytes(""));
        bytes memory message = _messageWithInitData(ghostAccount, initData);

        token.mint(address(adapter), 100e18);
        vm.expectRevert(RelayAdapterV2.ADDRESS_NOT_VALID.selector);
        adapter.processRelayExecution(address(token), 100e18, message);
    }

    /// @notice With no initData and a non-existent account, creation cannot happen and the call fails
    ///         before any funds move.
    function test_Create_RevertIf_NoInitDataAndAccountMissing() public {
        address ghostAccount = makeAddr("ghostAccount3");
        bytes memory message = _messageWithInitData(ghostAccount, bytes(""));

        token.mint(address(adapter), 100e18);
        vm.expectRevert(RelayAdapterV2.ACCOUNT_NOT_CREATED.selector);
        adapter.processRelayExecution(address(token), 100e18, message);
        assertEq(token.balanceOf(address(adapter)), 100e18, "no funds moved");
    }

    /*//////////////////////////////////////////////////////////////
                     REGRESSIONS FOR THE V1 DEFECTS
    //////////////////////////////////////////////////////////////*/

    /// @notice A token returning a short non-empty payload must escrow, not panic.
    /// @dev Regression for the `_tryTransfer` fix. V1 (and both Stargate adapters) lack the
    ///      `returnData.length >= 32` guard and would revert the whole call here, stranding the funds
    ///      with no escrow entry and no retry that could ever succeed.
    function test_Regression_ShortReturnDataEscrowsInsteadOfPanicking() public {
        ShortReturnToken weird = new ShortReturnToken();
        weird.mint(address(adapter), 100e18);

        adapter.processRelayExecution(address(weird), 100e18, _validMessage(account));

        assertEq(adapter.failedTransfers(account, address(weird)), 100e18, "escrowed, not panicked");
        assertEq(adapter.totalEscrowed(address(weird)), 100e18, "escrow accounted");
    }

    /// @notice Adapter and validator must agree on which DstProof is authoritative when several name
    ///         this chain — both iterate from index 0 and take the first match.
    function test_Regression_MultipleProofsForSameChain_FirstMatchWinsConsistently() public {
        token.mint(address(adapter), 100e18);

        // Two proofs for this chain: the signed one first, a decoy second.
        bytes memory valid = _validMessage(account);
        (bytes memory initData, bytes memory sigData) = abi.decode(valid, (bytes, bytes));
        (
            uint64[] memory chains,
            uint48 until,
            uint48 after_,
            bytes32 root,
            bytes32[] memory proofSrc,
            ISuperValidator.DstProof[] memory proofDst,
            bytes memory sig
        ) = abi.decode(sigData, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

        // NOTE: `two[1] = proofDst[0]` would alias the SAME memory struct, so mutating one mutates
        // both. The decoy must be constructed independently.
        ISuperValidator.DstProof[] memory two = new ISuperValidator.DstProof[](2);
        two[0] = proofDst[0];
        two[1] = ISuperValidator.DstProof({
            proof: proofDst[0].proof,
            dstChainId: proofDst[0].dstChainId,
            info: ISuperValidator.DstInfo({
                account: attackerAccount, // decoy in second position
                executor: address(executor),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(validator),
                data: bytes("")
            })
        });

        bytes memory message =
            abi.encode(initData, abi.encode(chains, until, after_, root, proofSrc, two, sig));

        adapter.processRelayExecution(address(token), 100e18, message);

        assertEq(token.balanceOf(account), 100e18, "first match (the signed account) wins");
        assertEq(token.balanceOf(attackerAccount), 0, "decoy ignored");
    }

    /// @notice Running out of gas after the transfer unwinds everything — nothing is left inconsistent.
    function test_Regression_InsufficientGasUnwindsTheTransfer() public {
        token.mint(address(adapter), 100e18);
        bytes memory valid = _validMessage(account);

        vm.expectRevert(RelayAdapterV2.INSUFFICIENT_GAS.selector);
        adapter.processRelayExecution{ gas: 400_000 }(address(token), 100e18, valid);

        assertEq(token.balanceOf(account), 0, "transfer unwound");
        assertEq(token.balanceOf(address(adapter)), 100e18, "funds still held");
        assertEq(adapter.totalEscrowed(address(token)), 0, "no escrow side effect");
    }

    /*//////////////////////////////////////////////////////////////
                  WHERE DO THE FUNDS GO ON A REVERT?
    //////////////////////////////////////////////////////////////*/

    /// @notice A revert moves nothing: every failure path either fires before `_tryTransfer`, or
    ///         (INSUFFICIENT_GAS) unwinds the transfer with the rest of the call frame.
    /// @dev So "where does the money go" is decided entirely by the TRANSACTION boundary, not by the
    ///      adapter: funds sit wherever they already were when the reverting call began.
    function test_Revert_NothingMovesRegardlessOfWhichGuardFires() public {
        token.mint(address(adapter), 100e18);
        uint256 before = token.balanceOf(address(adapter));

        bytes memory forged = _forgedMessage(attackerAccount);
        vm.prank(attacker);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 100e18, forged);
        assertEq(token.balanceOf(address(adapter)), before, "bad signature: balance unchanged");

        bytes memory wrongExec = _messageFor(account, address(0xBAD), address(validator), validUntil);
        vm.expectRevert(RelayAdapterV2.EXECUTOR_NOT_VALID.selector);
        adapter.processRelayExecution(address(token), 100e18, wrongExec);
        assertEq(token.balanceOf(address(adapter)), before, "executor mismatch: balance unchanged");

        bytes memory valid = _validMessage(account);
        vm.expectRevert(RelayAdapterV2.INSUFFICIENT_GAS.selector);
        adapter.processRelayExecution{ gas: 400_000 }(address(token), 100e18, valid);
        assertEq(token.balanceOf(address(adapter)), before, "gas floor: transfer unwound too");
        assertEq(token.balanceOf(account), 0, "nothing reached the account");
        assertEq(adapter.totalEscrowed(address(token)), 0, "no escrow side effect");
    }

    /// @notice Escrow is credited ONLY when the transfer is attempted and fails — never on a revert.
    /// @dev The distinction matters for recovery: a failed transfer leaves a claimable balance keyed to
    ///      the account, whereas a revert leaves no adapter-side record at all (because nothing happened).
    function test_Revert_EscrowIsCreditedOnTransferFailureNotOnRevert() public {
        token.mint(address(adapter), 100e18);

        // Revert path: no escrow entry is created.
        bytes memory forged = _forgedMessage(attackerAccount);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 100e18, forged);
        assertEq(adapter.failedTransfers(attackerAccount, address(token)), 0, "no escrow from a revert");

        // Transfer-failure path: the call SUCCEEDS and the amount becomes claimable by the account.
        bytes memory valid = _validMessage(account);
        vm.mockCall(
            address(token), abi.encodeWithSelector(IERC20.transfer.selector, account), abi.encode(false)
        );
        adapter.processRelayExecution(address(token), 100e18, valid);
        vm.clearMockedCalls();

        assertEq(adapter.failedTransfers(account, address(token)), 100e18, "escrowed and claimable");
    }

    /// @notice After a revert the funds stay in the adapter, and the LEGITIMATE holder can still
    ///         collect them by submitting their valid intent — the normal recovery path.
    function test_Revert_LegitimateIntentStillRecoversAfterAFailedAttempt() public {
        token.mint(address(adapter), 100e18);

        bytes memory forged = _forgedMessage(attackerAccount);
        vm.prank(attacker);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 100e18, forged);

        // The rightful owner's signed intent still works afterwards.
        adapter.processRelayExecution(address(token), 100e18, _validMessage(account));
        assertEq(token.balanceOf(account), 100e18, "recovered by the rightful account");
        assertEq(token.balanceOf(address(adapter)), 0, "adapter drained correctly");
    }

    /// @notice **Cross-intent fund consumption.** Funds delivered for intent A, left resting after a
    ///         reverted call, ARE consumed by a later call carrying a valid intent for account B.
    /// @dev V2 narrows the V1 hole from "anyone with a fabricated message" to "anyone holding a
    ///      genuinely signed intent", but it does NOT attribute funds to a delivery: the balance check
    ///      `balance - totalEscrowed >= amount` is pool-level, so any resting balance backs any valid
    ///      intent. Eliminating this requires attributing the delivery (pull-based `transferFrom`),
    ///      not just authenticating the message. Pinned so the limitation is explicit, not assumed away.
    function test_Residual_RestingFundsAreConsumedByADifferentValidIntent() public {
        // Leg 1: the solver delivers 100 for `account`'s intent.
        token.mint(address(adapter), 100e18);

        // Leg 2 for `account` reverts (say the signature had expired) — the transfer never happens.
        bytes memory forged = _forgedMessage(account);
        vm.expectRevert();
        adapter.processRelayExecution(address(token), 100e18, forged);
        assertEq(token.balanceOf(address(adapter)), 100e18, "funds still resting");

        // A DIFFERENT, genuinely signed intent for attackerAccount now arrives and takes them.
        vm.prank(attacker);
        adapter.processRelayExecution(address(token), 100e18, _validMessage(attackerAccount));

        assertEq(token.balanceOf(attackerAccount), 100e18, "resting funds consumed by another intent");
        assertEq(token.balanceOf(account), 0, "the intended recipient got nothing");
    }

    /// @notice The transfer is now capped at the amount the SIGNED intent commits to for this token.
    /// @dev `amount` is caller-supplied and not in the signed leaf, so without this cap the signature
    ///      would authenticate WHO is paid but not HOW MUCH — a 1-token intent could move an entire
    ///      resting balance. `intentAmounts` is signed, so it bounds the transfer for free.
    function test_Capped_SignedIntentBoundsTheTransfer() public {
        token.mint(address(adapter), 1000e18); // large resting balance

        bytes memory smallIntent = _validMessageForAmount(attackerAccount, 1e18);

        vm.prank(attacker);
        vm.expectRevert(RelayAdapterV2.AMOUNT_EXCEEDS_SIGNED_INTENT.selector);
        adapter.processRelayExecution(address(token), 1000e18, smallIntent);

        assertEq(token.balanceOf(attackerAccount), 0, "cannot exceed the signed amount");
        assertEq(token.balanceOf(address(adapter)), 1000e18, "resting balance untouched");
    }

    /// @notice Claiming exactly the signed amount still works.
    function test_Capped_ExactSignedAmountIsAllowed() public {
        token.mint(address(adapter), 1000e18);
        bytes memory intent = _validMessageForAmount(account, 250e18);

        adapter.processRelayExecution(address(token), 250e18, intent);

        assertEq(token.balanceOf(account), 250e18, "exact signed amount delivered");
        assertEq(token.balanceOf(address(adapter)), 750e18, "the rest stays put");
    }

    /// @notice Claiming less than the signed amount is allowed (under-delivery by the solver).
    function test_Capped_LessThanSignedAmountIsAllowed() public {
        token.mint(address(adapter), 1000e18);
        bytes memory intent = _validMessageForAmount(account, 250e18);

        adapter.processRelayExecution(address(token), 100e18, intent);
        assertEq(token.balanceOf(account), 100e18, "partial delivery permitted");
    }

    /// @notice An intent naming no amount for this token is left unconstrained — unchanged behaviour.
    /// @dev `intentAmounts` is a MINIMUM-balance requirement for the executor, so an intent may
    ///      legitimately omit it. The cap is derived only when it exists; this case is not worsened.
    function test_Capped_NoSignedAmountForTokenLeavesItUnconstrained() public {
        token.mint(address(adapter), 1000e18);

        // _validMessage uses empty dstTokens/intentAmounts, so no cap is derivable.
        adapter.processRelayExecution(address(token), 1000e18, _validMessage(account));
        assertEq(token.balanceOf(account), 1000e18, "unconstrained when the intent names no amount");
    }

    /// @notice A leftover spendable balance is surfaced for monitoring.
    function test_Capped_RetainedBalanceIsEmitted() public {
        token.mint(address(adapter), 1000e18);
        bytes memory intent = _validMessageForAmount(account, 900e18);

        vm.expectEmit(true, false, false, true);
        emit RelayAdapterV2.SpendableBalanceRetained(address(token), 100e18);
        adapter.processRelayExecution(address(token), 900e18, intent);
    }

    /*//////////////////////////////////////////////////////////////
                             EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice A signature issued for account A cannot be redirected to account B.
    function test_Edge_SignatureForOtherAccountRejected() public {
        token.mint(address(adapter), 1000e18);

        // Valid signature bound to `account`, but the proof names `attackerAccount`.
        bytes memory msgForAccount = _validMessage(account);
        (bytes memory initData, bytes memory sigData) = abi.decode(msgForAccount, (bytes, bytes));
        (
            uint64[] memory chains,
            uint48 until,
            uint48 after_,
            bytes32 root,
            bytes32[] memory proofSrc,
            ISuperValidator.DstProof[] memory proofDst,
            bytes memory sig
        ) = abi.decode(
            sigData, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes)
        );
        proofDst[0].info.account = attackerAccount; // redirect

        bytes memory tampered =
            abi.encode(initData, abi.encode(chains, until, after_, root, proofSrc, proofDst, sig));

        vm.prank(attacker);
        vm.expectRevert(); // validator rejects the redirected leaf (INVALID_PROOF)
        adapter.processRelayExecution(address(token), 1000e18, tampered);

        assertEq(token.balanceOf(attackerAccount), 0, "redirect blocked");
    }

    /// @notice An expired signature is rejected before funds move.
    function test_Edge_ExpiredSignatureRejected() public {
        token.mint(address(adapter), 1000e18);
        uint48 past = uint48(block.timestamp + 100);
        bytes memory message = _messageFor(account, address(executor), address(validator), past);

        vm.warp(block.timestamp + 200);

        vm.expectRevert(RelayAdapterV2.INVALID_SIGNATURE.selector);
        adapter.processRelayExecution(address(token), 1000e18, message);
        assertEq(token.balanceOf(address(adapter)), 1000e18, "funds intact");
    }

    /// @notice A proof naming a different executor fails fast, before the verify gas is spent.
    function test_Edge_ExecutorMismatchRejected() public {
        token.mint(address(adapter), 1000e18);
        bytes memory message = _messageFor(account, address(0xBAD), address(validator), validUntil);
        vm.expectRevert(RelayAdapterV2.EXECUTOR_NOT_VALID.selector);
        adapter.processRelayExecution(address(token), 1000e18, message);
    }

    /// @notice Same for a mismatched validator.
    function test_Edge_ValidatorMismatchRejected() public {
        token.mint(address(adapter), 1000e18);
        bytes memory message = _messageFor(account, address(executor), address(0xBAD), validUntil);

        vm.expectRevert(RelayAdapterV2.VALIDATOR_NOT_VALID.selector);
        adapter.processRelayExecution(address(token), 1000e18, message);
    }

    /// @notice No DstProof for this chain still reverts before any funds move.
    function test_Edge_NoProofForChainRejected() public {
        token.mint(address(adapter), 1000e18);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid) + 1,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: address(executor),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(validator),
                data: bytes("")
            })
        });
        bytes memory sigData = abi.encode(
            new uint64[](0), validUntil, uint48(0), bytes32(0), new bytes32[](0), proofDst, bytes("")
        );

        vm.expectRevert(RelayAdapterV2.NO_DST_PROOF_FOR_CHAIN.selector);
        adapter.processRelayExecution(address(token), 1000e18, abi.encode(bytes(""), sigData));
    }

    /// @notice The escrow guard is retained: escrowed funds stay excluded from the spendable balance.
    function test_Edge_EscrowStillExcludedFromSpendableBalance() public {
        token.mint(address(adapter), 1000e18);
        vm.mockCall(
            address(token), abi.encodeWithSelector(IERC20.transfer.selector, account), abi.encode(false)
        );

        adapter.processRelayExecution(address(token), 1000e18, _validMessage(account));

        assertEq(adapter.failedTransfers(account, address(token)), 1000e18, "escrowed");
        assertEq(adapter.totalEscrowed(address(token)), 1000e18, "tracked");

        vm.clearMockedCalls();

        // Even a VALID intent cannot spend the escrowed balance.
        bytes memory valid = _validMessage(account);
        vm.expectRevert(RelayAdapterV2.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(token), 1000e18, valid);

        // The owner of the escrow can still claim it.
        vm.prank(account);
        adapter.claimFailedTransfer(address(token), 1000e18);
        assertEq(token.balanceOf(account), 1000e18, "claimed");
        assertEq(adapter.totalEscrowed(address(token)), 0, "accounting cleared");
    }

    /// @notice A valid signature is reusable, so the balance guard is what bounds how much it can move.
    /// @dev Documents an intentional property: the merkle-root replay guard lives in the executor, not
    ///      here. A second call only succeeds if the adapter still holds unescrowed funds — i.e. the
    ///      holder of a signed intent can sweep their OWN additional resting fills, never anyone else's.
    function test_Edge_ValidSignatureReusableBoundedByBalance() public {
        token.mint(address(adapter), 1000e18);

        adapter.processRelayExecution(address(token), 600e18, _validMessage(account));
        assertEq(token.balanceOf(account), 600e18, "first delivery");

        adapter.processRelayExecution(address(token), 400e18, _validMessage(account));
        assertEq(token.balanceOf(account), 1000e18, "second delivery drained the rest");

        // Nothing left: the guard stops a third.
        bytes memory valid = _validMessage(account);
        vm.expectRevert(RelayAdapterV2.INSUFFICIENT_FUNDS_RECEIVED.selector);
        adapter.processRelayExecution(address(token), 1, valid);
    }

    /// @notice Zero amount and stray msg.value are rejected.
    function test_Edge_ZeroAmountRejected() public {
        bytes memory valid = _validMessage(account);
        vm.expectRevert(RelayAdapterV2.ZERO_AMOUNT.selector);
        adapter.processRelayExecution(address(token), 0, valid);
    }

    function test_Edge_StrayMsgValueRejected() public {
        bytes memory valid = _validMessage(account);
        vm.deal(address(this), 1 ether);
        vm.expectRevert(RelayAdapterV2.MSG_VALUE_NOT_ALLOWED.selector);
        adapter.processRelayExecution{ value: 1 ether }(address(token), 1, valid);
    }

    /// @notice Constructor rejects a zero executor.
    function test_Edge_ConstructorZeroAddress() public {
        vm.expectRevert(RelayAdapterV2.ADDRESS_NOT_VALID.selector);
        new RelayAdapterV2(address(0));
    }

    /// @notice The validator address is cached from the executor, matching Across/CCTP.
    function test_Edge_ValidatorCachedFromExecutor() public view {
        assertEq(adapter.SUPER_DESTINATION_VALIDATOR(), address(validator), "validator cached");
    }
}
