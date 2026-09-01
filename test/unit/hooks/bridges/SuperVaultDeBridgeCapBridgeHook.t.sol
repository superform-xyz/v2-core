// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SuperVaultDeBridgeCapBridgeHook } from
    "../../../../src/hooks/bridges/debridge/SuperVaultDeBridgeCapBridgeHook.sol";
import { DeBridgeSendOrderAndExecuteOnDstHook } from
    "../../../../src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { IDlnSource } from "../../../../src/vendor/bridges/debridge/IDlnSource.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";

/// @dev deBridge signature-storage stub. Empty dst-message orders don't touch the signature, but
///      _createOrder still reads it, so return a well-formed blob.
contract MockDeBridgeSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @dev View no-op matching the real guard (view → the hook STATICCALLs it). The tuple is asserted
///      via vm.expectCall, not by recording here.
interface ICapGuardLike {
    function validateAllocation(address strategy, uint64 chainId, address vault, uint256 amount) external view;
}

contract MockCapGuard is ICapGuardLike {
    function validateAllocation(address, uint64, address, uint256) external view { }
}

/// @dev Records where in-flight exposure landed, keyed by contract instance (for the migration test).
contract MockPositionRegistry {
    mapping(address => uint256) public bridgedOut;
    mapping(address => mapping(uint64 => uint256)) public bridgedOutByChain;

    function recordBridgedOut(address strategy, uint64 chainId, uint256 amount) external {
        bridgedOut[strategy] += amount;
        bridgedOutByChain[strategy][chainId] += amount;
    }
}

/// @dev SuperGovernor address book stub: swappable registry pointer to model a governance migration.
contract MockGovernorAddressBook {
    bytes32 private constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 private constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    address public capGuard;
    address public registry;

    constructor(address capGuard_, address registry_) {
        capGuard = capGuard_;
        registry = registry_;
    }

    function setRegistry(address registry_) external {
        registry = registry_;
    }

    function getAddress(bytes32 key) external view returns (address) {
        if (key == CROSS_CHAIN_CAP_GUARD) return capGuard;
        if (key == CROSS_CHAIN_POSITION_REGISTRY) return registry;
        return address(0);
    }
}

/// @dev Minimal prev-hook returning a fixed getOutAmount for the usePrevHookAmount branch.
contract MockPrevHook {
    uint256 private immutable OUT;

    constructor(uint256 out_) {
        OUT = out_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return OUT;
    }
}

contract SuperVaultDeBridgeCapBridgeHookTest is Test {
    SuperVaultDeBridgeCapBridgeHook internal hook;
    MockDeBridgeSignatureStorage internal validator;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;

    address internal dlnSource = makeAddr("dlnSource");
    address internal account = makeAddr("strategy");
    address internal recipient = makeAddr("destinationVault");
    address internal giveToken = makeAddr("giveToken");
    address internal takeToken = makeAddr("takeToken");

    uint256 internal constant GIVE_AMOUNT = 1000e6;
    uint256 internal constant TAKE_AMOUNT = 995e6;
    uint256 internal constant DST_CHAIN_ID = 8453;

    // build() output layout: [0]=preExecute [1]=createOrder [2]=postExecute
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 1;

    function setUp() public {
        validator = new MockDeBridgeSignatureStorage();
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultDeBridgeCapBridgeHook(dlnSource, address(validator), address(governor));
        hook.setExecutionContext(account);
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATED == BRIDGED TUPLE
    //////////////////////////////////////////////////////////////*/

    /// @notice The cap depends on the hook validating the SAME (recipient, chainId, amount) the
    ///         parent hands to createOrder. deBridge offsets are dynamic, so the bridged tuple is
    ///         derived by decoding the actual createOrder execution — the real drift guard.
    function test_ValidatedTupleEqualsBridgedTuple_StaticAmount() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);

        (address bridgedRecipient, uint256 bridgedChainId, uint256 bridgedAmount) = _decodeBridged(data);
        assertEq(bridgedAmount, GIVE_AMOUNT, "static amount not the encoded giveAmount");
        assertEq(bridgedRecipient, recipient, "recipient mismatch");
        assertEq(bridgedChainId, DST_CHAIN_ID, "chainId mismatch");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(
                ICapGuardLike.validateAllocation, (account, uint64(bridgedChainId), bridgedRecipient, bridgedAmount)
            )
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, uint64(DST_CHAIN_ID)), GIVE_AMOUNT, "per-chain exposure not recorded");
    }

    /// @notice Same equivalence when the amount comes from the previous hook's output.
    function test_ValidatedTupleEqualsBridgedTuple_PrevHookAmount() public {
        uint256 prevAmount = 750e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, true);

        // Under usePrev the parent rewrites giveAmount to the prev-hook output.
        (,, uint256 bridgedAmount) = _decodeBridgedWithPrev(data, address(prevHook));
        assertEq(bridgedAmount, prevAmount, "bridge did not use prev-hook amount");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_CHAIN_ID), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);

        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY RESOLUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice The hook must record into the SAME registry the cap reads from. After a governance
    ///         registry migration, exposure follows the new pointer — an immutable would have kept
    ///         writing to the old (now unread) registry, silently zeroing the cap's in-flight term.
    function test_RecordsIntoGovernorResolvedRegistry_FollowsMigration() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "first registry not credited");

        MockPositionRegistry newRegistry = new MockPositionRegistry();
        governor.setRegistry(address(newRegistry));

        hook.setExecutionContext(account); // fresh context: preExecute once-per-context mutex
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "old registry must not receive new writes");
        assertEq(newRegistry.bridgedOut(account), GIVE_AMOUNT, "new registry not credited after migration");
    }

    /*//////////////////////////////////////////////////////////////
                            INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice A takeChainId above uint64 would truncate to a different cap key than the full value
    ///         the parent forwards to DlnSource — reject it.
    function test_RevertIf_ChainIdExceedsUint64() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        bytes memory data = _encode(abi.encodePacked(recipient), tooBig, GIVE_AMOUNT, giveToken, 0, false);

        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice max uint64 is the boundary that must still pass.
    function test_ChainIdAtUint64Max_Passes() public {
        bytes memory data =
            _encode(abi.encodePacked(recipient), uint256(type(uint64).max), GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOutByChain(account, type(uint64).max), GIVE_AMOUNT, "boundary chainId not recorded");
    }

    /// @notice A non-EVM (non-20-byte) receiverDst — e.g. a 32-byte Solana pubkey — is rejected
    ///         fail-closed rather than truncated. deBridge-specific (Across recipient is fixed 20B).
    function test_RevertIf_ReceiverDstNot20Bytes() public {
        bytes memory receiver32 = abi.encodePacked(bytes32(uint256(0xBEEF)));
        bytes memory data = _encode(receiver32, DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);

        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A zero (20-byte) receiver would hit the periphery guard's idle-hold branch; the
    ///         deBridge parent does not reject it, so this hook must.
    function test_RevertIf_ZeroReceiver() public {
        bytes memory data = _encode(abi.encodePacked(address(0)), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);

        vm.prank(account);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Malformed/short data reverts via the vendor lib's bounds check (no typed selector) —
    ///         identical to the parent's own build()/inspect() on the same buffer.
    function test_RevertIf_DataMalformed() public {
        bytes memory shortData = new bytes(120); // far short of a full order
        vm.prank(account);
        vm.expectRevert();
        hook.preExecute(address(0), account, shortData);
    }

    /*//////////////////////////////////////////////////////////////
                        NATIVE giveToken EDGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Native giveToken (address(0)) path: the cap still validates the giveAmount that
    ///         leaves, independent of the native `value` field the parent computes.
    function test_NativeGiveToken_ValidatesGiveAmount() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, address(0), 0, false);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_CHAIN_ID), recipient, GIVE_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), GIVE_AMOUNT, "native path exposure not recorded");
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY WRITE + ACCUMULATION
    //////////////////////////////////////////////////////////////*/

    /// @notice The registry write must be the exact (strategy, chainId, amount) tuple, asserted at
    ///         the call boundary (not just via recorded state).
    function test_RecordBridgedOut_CalledWithExactTuple() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.expectCall(
            address(registry),
            abi.encodeCall(MockPositionRegistry.recordBridgedOut, (account, uint64(DST_CHAIN_ID), GIVE_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
    }

    /// @notice The prev-hook output OVERRIDES the encoded giveAmount — the cap must validate the
    ///         amount that actually leaves, not the calldata placeholder.
    function test_PrevAmountOverridesEncodedGiveAmount() public {
        uint256 prevAmount = 333e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        // Encoded giveAmount is deliberately different from the prev-hook amount.
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, true);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_CHAIN_ID), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "validated the encoded amount, not the prev amount");
    }

    /// @notice Repeated executions accumulate exposure in the registry (per-chain and total).
    function test_MultipleExecutions_AccumulateExposure() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        hook.setExecutionContext(account); // fresh context past the once-per-context mutex
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), 2 * GIVE_AMOUNT, "total exposure not accumulated");
        assertEq(registry.bridgedOutByChain(account, uint64(DST_CHAIN_ID)), 2 * GIVE_AMOUNT, "per-chain not accumulated");
    }

    /// @notice Two different destination chains bucket separately; the total is their sum.
    function test_MultipleChains_AccumulateSeparately() public {
        uint64 otherChain = 42_161; // Arbitrum
        bytes memory data1 = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        bytes memory data2 = _encode(abi.encodePacked(recipient), otherChain, 400e6, giveToken, 0, false);

        vm.prank(account);
        hook.preExecute(address(0), account, data1);
        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data2);

        assertEq(registry.bridgedOutByChain(account, uint64(DST_CHAIN_ID)), GIVE_AMOUNT, "chain A bucket wrong");
        assertEq(registry.bridgedOutByChain(account, otherChain), 400e6, "chain B bucket wrong");
        assertEq(registry.bridgedOut(account), GIVE_AMOUNT + 400e6, "total not the sum of both chains");
    }

    /*//////////////////////////////////////////////////////////////
                        MORE INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice receiverDst of 19 bytes (one short of an address) is rejected.
    function test_RevertIf_ReceiverDst19Bytes() public {
        bytes memory receiver19 = new bytes(19);
        bytes memory data = _encode(receiver19, DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice receiverDst of 21 bytes (one over an address) is rejected.
    function test_RevertIf_ReceiverDst21Bytes() public {
        bytes memory receiver21 = new bytes(21);
        bytes memory data = _encode(receiver21, DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A small EVM chain id (Ethereum = 1) passes and buckets correctly.
    function test_ChainIdOne_Passes() public {
        bytes memory data = _encode(abi.encodePacked(recipient), 1, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOutByChain(account, 1), GIVE_AMOUNT, "chainId 1 not recorded");
    }

    /// @notice A cap-guard revert propagates out of _preExecute and nothing is recorded.
    function test_CapGuardRevertPropagates() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "exposure recorded despite cap revert");
    }

    /*//////////////////////////////////////////////////////////////
                        LIFECYCLE / ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice preExecute is caller-gated to the account (inherited BaseHook guard).
    function test_RevertIf_PreExecuteNotAccount() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice preExecute is once-per-execution-context (inherited mutex): a second call in the
    ///         same context reverts, so the cap cannot be double-recorded within one execution.
    function test_RevertIf_PreExecuteCalledTwiceSameContext() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        vm.prank(account);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITED SURFACE INTACT
    //////////////////////////////////////////////////////////////*/

    /// @notice The inherited inspect() still exposes the giveToken and the receiverDst (the cap
    ///         destination), so off-chain leaf allowlisting sees the same recipient the cap uses.
    function test_Inspect_ExposesGiveTokenAndReceiver() public view {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        bytes memory payload = hook.inspect(data);
        // Parent packs: giveToken(20) | takeToken(20) | receiverDst(20) | givePatch(20) | orderAuth(20) | cancel(20)
        assertEq(payload.length, 120, "unexpected inspector payload length");
        assertEq(address(bytes20(_slice(payload, 0))), giveToken, "giveToken not first in inspector");
        assertEq(address(bytes20(_slice(payload, 40))), recipient, "receiverDst not at slot 3 of inspector");
    }

    /// @notice The inherited usePrevHookAmount decoder reads the same bool the cap path reads.
    function test_DecodeUsePrevHookAmount() public view {
        bytes memory falseData = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        bytes memory trueData = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, true);
        assertEq(hook.decodeUsePrevHookAmount(falseData), false, "false bool misdecoded");
        assertEq(hook.decodeUsePrevHookAmount(trueData), true, "true bool misdecoded");
    }

    /// @notice The inherited sized interface reports the giveAmount at offset 105.
    function test_DecodeAmounts_ReturnsGiveAmount() public view {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        uint256[] memory amounts = hook.decodeAmounts(data);
        assertEq(amounts.length, 1, "expected single sized leg");
        assertEq(amounts[0], GIVE_AMOUNT, "sized amount is not the giveAmount");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultDeBridgeCapBridgeHook(dlnSource, address(validator), address(0));
    }

    /// @notice The zero-dlnSource guard is inherited from the parent constructor and still fires
    ///         through the subclass.
    function test_Constructor_RevertIf_ZeroDlnSource() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultDeBridgeCapBridgeHook(address(0), address(validator), address(governor));
    }

    /// @notice The zero-validator guard is inherited from the parent constructor.
    function test_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultDeBridgeCapBridgeHook(dlnSource, address(0), address(governor));
    }

    function test_Constructor_SetsGovernor() public view {
        assertEq(address(hook.SUPER_GOVERNOR()), address(governor));
    }

    function test_Constructor_ForwardsParentArgs() public view {
        assertEq(hook.DLN_SOURCE(), dlnSource, "dlnSource not forwarded to parent");
    }

    /*//////////////////////////////////////////////////////////////
                        super._preExecute PASSTHROUGH
    //////////////////////////////////////////////////////////////*/

    /// @notice The parent is TRANSFORM pipe-mode, so super._preExecute is a no-op: the cap hook must
    ///         not publish an outAmount/outToken of its own (it is a terminal bridge send).
    function test_PreExecute_DoesNotPublishOutput() public {
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), 0, "cap hook must not set outAmount");
        assertEq(hook.getOutToken(account), address(0), "cap hook must not set outToken");
    }

    /// @notice Native giveToken (address(0)) through the usePrevHookAmount path: the cap validates
    ///         the prev-hook amount that leaves, independent of the native value field.
    function test_NativeGiveToken_UsePrev_ValidatesPrevAmount() public {
        uint256 prevAmount = 2 ether;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, GIVE_AMOUNT, address(0), 0, true);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_CHAIN_ID), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "native+prev path exposure not recorded");
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @notice For any EVM chainId and any static amount, the hook validates and records exactly the
    ///         (account, chainId, recipient, amount) tuple the order gives.
    function testFuzz_StaticAmount_ValidatesAndRecords(uint256 giveAmount, uint64 chainId) public {
        giveAmount = bound(giveAmount, 1, type(uint128).max);
        bytes memory data = _encode(abi.encodePacked(recipient), uint256(chainId), giveAmount, giveToken, 0, false);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, chainId, recipient, giveAmount))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOutByChain(account, chainId), giveAmount, "fuzz: per-chain exposure mismatch");
    }

    /// @notice The prev-hook amount is always what gets validated/recorded, whatever the encoded
    ///         giveAmount is.
    function testFuzz_PrevAmount_OverridesEncoded(uint256 encoded, uint256 prevAmount) public {
        encoded = bound(encoded, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(abi.encodePacked(recipient), DST_CHAIN_ID, encoded, giveToken, 0, true);

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_CHAIN_ID), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "fuzz: prev amount not the validated amount");
    }

    /// @notice Any receiverDst whose length is not exactly 20 bytes is rejected.
    function testFuzz_RevertIf_ReceiverDstWrongLength(uint8 len) public {
        len = uint8(bound(len, 0, 64));
        vm.assume(len != 20);
        bytes memory receiver = new bytes(len);
        // make it non-zero so the length guard is what trips (not the zero-address guard)
        for (uint256 i; i < len; ++i) {
            receiver[i] = 0x11;
        }
        bytes memory data = _encode(receiver, DST_CHAIN_ID, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Any takeChainId above uint64 is rejected.
    function testFuzz_RevertIf_ChainIdExceedsUint64(uint256 rawChainId) public {
        rawChainId = bound(rawChainId, uint256(type(uint64).max) + 1, type(uint256).max);
        bytes memory data = _encode(abi.encodePacked(recipient), rawChainId, GIVE_AMOUNT, giveToken, 0, false);
        vm.prank(account);
        vm.expectRevert(SuperVaultDeBridgeCapBridgeHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes the OrderCreation the parent build() will actually send (static-amount path).
    function _decodeBridged(bytes memory data)
        internal
        returns (address bridgedRecipient, uint256 bridgedChainId, uint256 bridgedAmount)
    {
        Execution[] memory ex = hook.build(address(0), account, data);
        return _decodeCreateOrder(ex[BRIDGE_EXECUTION_INDEX].callData);
    }

    /// @dev Same, but through the usePrev path (build reads prevHook.getOutAmount).
    function _decodeBridgedWithPrev(
        bytes memory data,
        address prevHook
    )
        internal
        returns (address bridgedRecipient, uint256 bridgedChainId, uint256 bridgedAmount)
    {
        Execution[] memory ex = hook.build(prevHook, account, data);
        return _decodeCreateOrder(ex[BRIDGE_EXECUTION_INDEX].callData);
    }

    /// @dev Reads the 20-byte word at `offset` from a packed inspector payload (right-padded to 32
    ///      so `bytes20(...)` takes the leading 20 bytes).
    function _slice(bytes memory payload, uint256 offset) internal pure returns (bytes32 out) {
        for (uint256 i; i < 20; ++i) {
            out |= bytes32(payload[offset + i]) >> (i * 8);
        }
    }

    function _decodeCreateOrder(bytes memory callData)
        internal
        pure
        returns (address bridgedRecipient, uint256 bridgedChainId, uint256 bridgedAmount)
    {
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = callData[i + 4];
        }
        (IDlnSource.OrderCreation memory order,,,) =
            abi.decode(args, (IDlnSource.OrderCreation, bytes, uint32, bytes));
        bridgedRecipient = address(bytes20(order.receiverDst));
        bridgedChainId = order.takeChainId;
        bridgedAmount = order.giveAmount;
    }

    /// @dev Canonical deBridge hookData with parameterized receiverDst / takeChainId / giveAmount /
    ///      giveToken / usePrevHookAmount. Empty destinationMessage (no external call) keeps the
    ///      order minimal; the cap fields are independent of it.
    function _encode(
        bytes memory receiverDst,
        uint256 takeChainId,
        uint256 giveAmount,
        address giveToken_,
        uint256 value,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory part1 = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte strategy header
            usePrev,
            value,
            giveToken_,
            giveAmount,
            uint8(0), // version
            address(0), // fallbackAddress
            address(0) // executorAddress
        );
        bytes memory part2 = abi.encodePacked(
            uint256(0), // executionFee
            false, // allowDelayedExecution
            false, // requireSuccessfulExecution
            uint256(0), // destinationMessage length (empty → no external call)
            abi.encodePacked(takeToken).length, // takeTokenAddress length (20)
            abi.encodePacked(takeToken),
            TAKE_AMOUNT,
            takeChainId
        );
        bytes memory part3 = abi.encodePacked(
            receiverDst.length,
            receiverDst,
            address(0), // givePatchAuthoritySrc
            uint256(0), // orderAuthorityAddressDst length
            uint256(0), // allowedTakerDst length
            uint256(0), // allowedCancelBeneficiarySrc length
            uint256(0), // affiliateFee length
            uint32(0) // referralCode
        );
        return bytes.concat(part1, part2, part3);
    }
}
