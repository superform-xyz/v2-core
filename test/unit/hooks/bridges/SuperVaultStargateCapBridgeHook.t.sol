// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SuperVaultStargateCapBridgeHook } from
    "../../../../src/hooks/bridges/stargate/SuperVaultStargateCapBridgeHook.sol";
import { ApproveAndStargateSendHook } from
    "../../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { IStargate } from "../../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";

/// @dev Stargate signature-storage stub (unused with an empty composeMsg, but build() reads it if
///      a compose message is present; our tests use empty composeMsg).
contract MockStargateSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @dev Minimal Stargate pool: build() checks `token() == inputToken` on modes 0-2.
contract MockStargatePool {
    address public token;

    constructor(address token_) {
        token = token_;
    }
}

/// @dev View no-op matching the real cap guard. Tuple asserted via vm.expectCall.
interface ICapGuardLike {
    function validateAllocation(address strategy, uint64 chainId, address vault, uint256 amount) external view;
}

contract MockCapGuard is ICapGuardLike {
    function validateAllocation(address, uint64, address, uint256) external view { }
}

contract MockPositionRegistry {
    mapping(address => uint256) public bridgedOut;
    mapping(address => mapping(uint64 => uint256)) public bridgedOutByChain;

    function recordBridgedOut(address strategy, uint64 chainId, uint256 amount) external {
        bridgedOut[strategy] += amount;
        bridgedOutByChain[strategy][chainId] += amount;
    }
}

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

contract MockPrevHook {
    uint256 private immutable OUT;

    constructor(uint256 out_) {
        OUT = out_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return OUT;
    }
}

contract SuperVaultStargateCapBridgeHookTest is Test {
    SuperVaultStargateCapBridgeHook internal hook;
    MockStargateSignatureStorage internal validator;
    MockStargatePool internal pool;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;

    address internal account = makeAddr("strategy");
    address internal recipient = makeAddr("destinationVault");
    address internal inputToken = makeAddr("inputToken");

    uint256 internal constant AMOUNT_LD = 1000e6;
    uint256 internal constant MIN_AMOUNT_LD = 995e6;
    uint256 internal constant NATIVE_FEE = 0.01 ether;
    uint32 internal constant DST_EID = 30_184; // Base LayerZero endpoint id

    // build() layout: [0]=pre [1]=approve(0) [2]=approve(amt) [3]=sendToken [4]=approve(0) [5]=post
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 3;

    function setUp() public {
        validator = new MockStargateSignatureStorage();
        pool = new MockStargatePool(inputToken);
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultStargateCapBridgeHook(address(validator), address(governor));
        hook.setExecutionContext(account);
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATED == BRIDGED TUPLE
    //////////////////////////////////////////////////////////////*/

    /// @notice The cap must validate the SAME (dstEid, recipient, amount) the parent hands to
    ///         sendToken. Derived by decoding the actual bridge execution — the drift guard.
    function test_ValidatedTupleEqualsBridgedTuple_StaticAmount() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);

        (uint32 eid, address to, uint256 amt) = _decodeBridged(data);
        assertEq(eid, DST_EID, "dstEid mismatch");
        assertEq(to, recipient, "recipient mismatch");
        assertEq(amt, AMOUNT_LD, "amount mismatch");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(eid), to, amt))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), AMOUNT_LD, "exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, uint64(DST_EID)), AMOUNT_LD, "per-eid exposure not recorded");
    }

    /// @notice Same equivalence when the amount comes from the previous hook's output.
    function test_ValidatedTupleEqualsBridgedTuple_PrevHookAmount() public {
        uint256 prevAmount = 750e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, true, 0);

        (,, uint256 amt) = _decodeBridgedWithPrev(data, address(prevHook));
        assertEq(amt, prevAmount, "bridge did not use prev-hook amount");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_EID), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);

        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");
    }

    /// @notice Mode 1 (bus) also carries recipient+amount at the same offsets, so it caps too.
    function test_ValidatedTuple_Mode1Bus() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 1);
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_EID), recipient, AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), AMOUNT_LD, "mode-1 exposure not recorded");
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY RESOLUTION
    //////////////////////////////////////////////////////////////*/

    function test_RecordsIntoGovernorResolvedRegistry_FollowsMigration() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), AMOUNT_LD, "first registry not credited");

        MockPositionRegistry newRegistry = new MockPositionRegistry();
        governor.setRegistry(address(newRegistry));

        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), AMOUNT_LD, "old registry must not receive new writes");
        assertEq(newRegistry.bridgedOut(account), AMOUNT_LD, "new registry not credited after migration");
    }

    function test_RecordBridgedOut_CalledWithExactTuple() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.expectCall(
            address(registry),
            abi.encodeCall(MockPositionRegistry.recordBridgedOut, (account, uint64(DST_EID), AMOUNT_LD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Mode 3 (lzMulticall) ignores to/amount, so it cannot be capped — reject it.
    function test_RevertIf_Mode3() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 3);
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A non-EVM `to` (top 12 bytes non-zero, e.g. a Solana pubkey) is rejected fail-closed.
    function test_RevertIf_NonEvmRecipient() public {
        bytes32 nonEvm = bytes32(uint256(1) << 200); // set a high bit above the low 160
        bytes memory data = _encode(DST_EID, nonEvm, AMOUNT_LD, false, 0);
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice A zero recipient would hit the periphery guard's idle-hold branch; reject it.
    function test_RevertIf_ZeroRecipient() public {
        bytes memory data = _encode(DST_EID, bytes32(0), AMOUNT_LD, false, 0);
        vm.prank(account);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice Malformed/short data reverts via the length guard.
    function test_RevertIf_DataTooShort() public {
        bytes memory shortData = new bytes(225); // one short of the 226 mode-byte floor
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, shortData);
    }

    /// @notice A large uint32 dstEid still fits uint64 and records under that eid.
    function test_LargeDstEid_Passes() public {
        uint32 bigEid = type(uint32).max;
        bytes memory data = _encode(bigEid, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOutByChain(account, uint64(bigEid)), AMOUNT_LD, "max-eid not recorded");
    }

    /*//////////////////////////////////////////////////////////////
                        ACCUMULATION
    //////////////////////////////////////////////////////////////*/

    function test_MultipleExecutions_AccumulateExposure() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 2 * AMOUNT_LD, "total not accumulated");
        assertEq(registry.bridgedOutByChain(account, uint64(DST_EID)), 2 * AMOUNT_LD, "per-eid not accumulated");
    }

    function test_MultipleEids_AccumulateSeparately() public {
        uint32 otherEid = 30_101; // Ethereum
        bytes memory d1 = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        bytes memory d2 = _encode(otherEid, _toBytes32(recipient), 400e6, false, 0);
        vm.prank(account);
        hook.preExecute(address(0), account, d1);
        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, d2);
        assertEq(registry.bridgedOutByChain(account, uint64(DST_EID)), AMOUNT_LD, "eid A wrong");
        assertEq(registry.bridgedOutByChain(account, uint64(otherEid)), 400e6, "eid B wrong");
        assertEq(registry.bridgedOut(account), AMOUNT_LD + 400e6, "total not the sum");
    }

    /*//////////////////////////////////////////////////////////////
                        LIFECYCLE / ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_PreExecuteNotAccount() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.preExecute(address(0), account, data);
    }

    function test_RevertIf_PreExecuteCalledTwiceSameContext() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        vm.prank(account);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
    }

    function test_CapGuardRevertPropagates() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), 0, "recorded despite cap revert");
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITED SURFACE / super
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_DoesNotPublishOutput() public {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(hook.getOutAmount(account), 0, "cap hook must not set outAmount");
        assertEq(hook.getOutToken(account), address(0), "cap hook must not set outToken");
    }

    function test_Inspect_ExposesPoolTokenAndRecipient() public view {
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0);
        bytes memory payload = hook.inspect(data);
        // Parent packs: stargatePool(20) | inputToken(20) | to-as-address(20)
        assertEq(payload.length, 60, "unexpected inspector payload length");
        assertEq(address(bytes20(_word(payload, 40))), recipient, "recipient not at slot 3 of inspector");
    }

    function test_DecodeUsePrevHookAmount() public view {
        assertEq(
            hook.decodeUsePrevHookAmount(_encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0)), false
        );
        assertEq(hook.decodeUsePrevHookAmount(_encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, true, 0)), true);
    }

    function test_DecodeAmounts_ReturnsAmountLD() public view {
        uint256[] memory amounts = hook.decodeAmounts(_encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, 0));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], AMOUNT_LD, "sized amount is not amountLD");
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultStargateCapBridgeHook(address(validator), address(0));
    }

    function test_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultStargateCapBridgeHook(address(0), address(governor));
    }

    function test_Constructor_SetsGovernor() public view {
        assertEq(address(hook.SUPER_GOVERNOR()), address(governor));
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_StaticAmount_ValidatesAndRecords(uint256 amountLD, uint32 dstEid) public {
        amountLD = bound(amountLD, 1, type(uint128).max);
        bytes memory data = _encode(dstEid, _toBytes32(recipient), amountLD, false, 0);
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(dstEid), recipient, amountLD))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOutByChain(account, uint64(dstEid)), amountLD, "fuzz: per-eid mismatch");
    }

    function testFuzz_PrevAmount_OverridesEncoded(uint256 encoded, uint256 prevAmount) public {
        encoded = bound(encoded, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), encoded, true, 0);
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, uint64(DST_EID), recipient, prevAmount))
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);
        assertEq(registry.bridgedOut(account), prevAmount, "fuzz: prev amount not validated");
    }

    function testFuzz_RevertIf_NonEvmRecipient(bytes32 to) public {
        vm.assume(uint256(to) >> 160 != 0); // top 12 bytes non-zero => non-EVM
        bytes memory data = _encode(DST_EID, to, AMOUNT_LD, false, 0);
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    function testFuzz_RevertIf_ModeAboveTwo(uint8 mode) public {
        mode = uint8(bound(mode, 3, 3)); // parent build rejects >3; cap rejects >2, so 3 is the case
        bytes memory data = _encode(DST_EID, _toBytes32(recipient), AMOUNT_LD, false, mode);
        vm.prank(account);
        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    /// @dev Reads the 20-byte word at `offset` from a packed payload (left-aligned into bytes32).
    function _word(bytes memory payload, uint256 offset) internal pure returns (bytes32 out) {
        for (uint256 i; i < 20; ++i) {
            out |= bytes32(payload[offset + i]) >> (i * 8);
        }
    }

    function _decodeBridged(bytes memory data) internal returns (uint32 eid, address to, uint256 amt) {
        Execution[] memory ex = hook.build(address(0), account, data);
        return _decodeSendToken(ex[BRIDGE_EXECUTION_INDEX].callData);
    }

    function _decodeBridgedWithPrev(
        bytes memory data,
        address prevHook
    )
        internal
        returns (uint32 eid, address to, uint256 amt)
    {
        Execution[] memory ex = hook.build(prevHook, account, data);
        return _decodeSendToken(ex[BRIDGE_EXECUTION_INDEX].callData);
    }

    function _decodeSendToken(bytes memory callData) internal pure returns (uint32 eid, address to, uint256 amt) {
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = callData[i + 4];
        }
        (IStargate.SendParam memory sendParam,,) =
            abi.decode(args, (IStargate.SendParam, IStargate.MessagingFee, address));
        eid = sendParam.dstEid;
        to = address(uint160(uint256(sendParam.to)));
        amt = sendParam.amountLD;
    }

    /// @dev Canonical Stargate hookData with empty extraOptions/composeMsg (min length 290).
    function _encode(
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        bool usePrev,
        uint8 mode
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0), // 52-byte strategy header
            NATIVE_FEE,
            address(pool),
            inputToken,
            dstEid,
            to,
            amountLD,
            MIN_AMOUNT_LD
        );
        return abi.encodePacked(
            fixedPart, usePrev, mode, uint256(0), /* extraOptions len */ uint256(0) /* composeMsg len */
        );
    }
}
