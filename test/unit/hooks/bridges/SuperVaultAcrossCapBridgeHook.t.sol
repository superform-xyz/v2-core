// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SuperVaultAcrossCapBridgeHook } from
    "../../../../src/hooks/bridges/across/SuperVaultAcrossCapBridgeHook.sol";
import { ApproveAndAcrossSendFundsAndExecuteOnDstHook } from
    "../../../../src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol";
import { IAcrossSpokePoolV3 } from "../../../../src/vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";

/// @dev Signature storage stub returning a DstProof matching the current chain (no dst message used).
contract MockAcrossSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @dev View no-op, matching the real guard (which is `view`, so the hook STATICCALLs it). The test
///      asserts the exact tuple the hook passes via `vm.expectCall`, not by recording state here.
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

contract SuperVaultAcrossCapBridgeHookTest is Test {
    SuperVaultAcrossCapBridgeHook internal hook;
    MockAcrossSignatureStorage internal validator;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;

    address internal spokePool = makeAddr("spokePool");
    address internal account = makeAddr("strategy");
    address internal recipient = makeAddr("destinationVault");
    address internal inputToken = makeAddr("inputToken");
    address internal outputToken = makeAddr("outputToken");

    uint256 internal constant INPUT_AMOUNT = 1000e6;
    uint256 internal constant OUTPUT_AMOUNT = 995e6;
    uint64 internal constant DST_CHAIN_ID = 8453;

    // build() output layout for the ApproveAnd variant:
    // [0]=preExecute [1]=approve(0) [2]=approve(amount) [3]=depositV3Now [4]=approve(0) [5]=postExecute
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 3;

    function setUp() public {
        validator = new MockAcrossSignatureStorage();
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultAcrossCapBridgeHook(spokePool, address(validator), address(governor));
        hook.setExecutionContext(account);
    }

    /*//////////////////////////////////////////////////////////////
                        OFFSET-EQUIVALENCE (P3-1)
    //////////////////////////////////////////////////////////////*/

    /// @notice The whole cap depends on the hook validating the SAME (recipient, chainId, amount)
    ///         the parent hands to depositV3Now. The offset constants mirror the locked parent by
    ///         hand, so this asserts they cannot silently drift. Static-amount branch.
    function test_ValidatedTupleEqualsBridgedTuple_StaticAmount() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false);

        // Derive the tuple the parent will actually bridge, then require the cap guard to be called
        // with exactly that tuple.
        (address bridgedRecipient, uint256 bridgedAmount, uint256 bridgedChainId) = _decodeBridged(data, address(0));
        assertEq(bridgedAmount, INPUT_AMOUNT, "static amount not the encoded input");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(
                ICapGuardLike.validateAllocation, (account, uint64(bridgedChainId), bridgedRecipient, bridgedAmount)
            )
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, DST_CHAIN_ID), INPUT_AMOUNT, "per-chain exposure not recorded");
    }

    /// @notice Same equivalence when the amount comes from the previous hook's output.
    function test_ValidatedTupleEqualsBridgedTuple_PrevHookAmount() public {
        uint256 prevAmount = 750e6;
        MockPrevHook prevHook = new MockPrevHook(prevAmount);
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, true);

        (address bridgedRecipient, uint256 bridgedAmount, uint256 bridgedChainId) =
            _decodeBridged(data, address(prevHook));
        assertEq(bridgedAmount, prevAmount, "bridge did not use prev-hook amount");

        vm.expectCall(
            address(capGuard),
            abi.encodeCall(
                ICapGuardLike.validateAllocation, (account, uint64(bridgedChainId), bridgedRecipient, bridgedAmount)
            )
        );
        vm.prank(account);
        hook.preExecute(address(prevHook), account, data);

        assertEq(registry.bridgedOut(account), prevAmount, "exposure not the prev-hook amount");
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTRY RESOLUTION (P1-1)
    //////////////////////////////////////////////////////////////*/

    /// @notice The hook must record into the SAME registry the cap reads from. After a governance
    ///         registry migration, exposure follows the new pointer — an immutable would have kept
    ///         writing to the old (now unread) registry, silently zeroing the cap's in-flight term.
    function test_RecordsIntoGovernorResolvedRegistry_FollowsMigration() public {
        bytes memory data = _encode(DST_CHAIN_ID, INPUT_AMOUNT, false);

        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "first registry not credited");

        // Governance rotates the registry pointer.
        MockPositionRegistry newRegistry = new MockPositionRegistry();
        governor.setRegistry(address(newRegistry));

        // Fresh execution context so preExecute's once-per-context mutex allows a second call.
        hook.setExecutionContext(account);
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "old registry must not receive new writes");
        assertEq(newRegistry.bridgedOut(account), INPUT_AMOUNT, "new registry not credited after migration");
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION (P2-2 / P3-2)
    //////////////////////////////////////////////////////////////*/

    /// @notice A destinationChainId above uint64 would truncate to a different cap key than the full
    ///         value the parent forwards to the SpokePool — reject it.
    function test_RevertIf_ChainIdExceedsUint64() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        bytes memory data = _encode(tooBig, INPUT_AMOUNT, false);

        vm.prank(account);
        vm.expectRevert(ApproveAndAcrossSendFundsAndExecuteOnDstHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, data);
    }

    /// @notice max uint64 is the boundary that must still pass.
    function test_ChainIdAtUint64Max_Passes() public {
        bytes memory data = _encode(uint256(type(uint64).max), INPUT_AMOUNT, false);
        vm.prank(account);
        hook.preExecute(address(0), account, data);
        assertEq(
            registry.bridgedOutByChain(account, type(uint64).max), INPUT_AMOUNT, "boundary chainId not recorded"
        );
    }

    /// @notice Short data must fail with the typed error, not the vendor lib's untyped OOB revert.
    function test_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(bytes(new bytes(268))); // one byte short of 269
        vm.prank(account);
        vm.expectRevert(ApproveAndAcrossSendFundsAndExecuteOnDstHook.DATA_NOT_VALID.selector);
        hook.preExecute(address(0), account, shortData);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SuperVaultAcrossCapBridgeHook(spokePool, address(validator), address(0));
    }

    function test_Constructor_SetsGovernor() public view {
        assertEq(address(hook.SUPER_GOVERNOR()), address(governor));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encode(uint256 chainId, uint256 inputAmount, bool usePrevHookAmount) internal view returns (bytes memory) {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // strategy header
            uint256(0), // value
            recipient,
            inputToken,
            outputToken,
            inputAmount,
            OUTPUT_AMOUNT
        );
        return abi.encodePacked(
            header,
            chainId, // destinationChainId @208
            address(0), // exclusiveRelayer @240
            uint32(3600), // fillDeadlineOffset @260
            uint32(0), // exclusivityPeriod @264
            usePrevHookAmount // @268
        );
    }

    /// @dev Runs build() and decodes the depositV3Now execution the parent produced, returning the
    ///      fields the cap must match: (recipient, inputAmount, destinationChainId).
    function _decodeBridged(
        bytes memory data,
        address prevHook
    )
        internal
        view
        returns (address bridgedRecipient, uint256 bridgedAmount, uint256 bridgedChainId)
    {
        Execution[] memory execs = hook.build(prevHook, account, data);
        bytes memory cd = execs[BRIDGE_EXECUTION_INDEX].callData;
        bytes4 selector = bytes4(cd);
        assertEq(selector, IAcrossSpokePoolV3.depositV3Now.selector, "not a depositV3Now call");

        // Strip the 4-byte selector and decode the depositV3Now argument tuple.
        bytes memory args = new bytes(cd.length - 4);
        for (uint256 i; i < args.length; ++i) {
            args[i] = cd[i + 4];
        }
        (
            , // depositor
            address rcpt,
            , // inputToken
            , // outputToken
            uint256 inAmt,
            , // outputAmount
            uint256 dstChain,
            , // exclusiveRelayer
            , // fillDeadlineOffset
            , // exclusivityDeadline
            // message
        ) = abi.decode(
            args,
            (address, address, address, address, uint256, uint256, uint256, address, uint32, uint32, bytes)
        );
        return (rcpt, inAmt, dstChain);
    }
}
