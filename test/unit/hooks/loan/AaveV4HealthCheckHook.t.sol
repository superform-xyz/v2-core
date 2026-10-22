// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { AaveV4ReserveKey } from "../../../../src/libraries/AaveV4ReserveKey.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { AaveV4HealthCheckHook } from "../../../../src/hooks/loan/aave-v4/AaveV4HealthCheckHook.sol";

// Mocks shared with the Morpho V2 loan-hook suite
import { MockPrevHook } from "./MorphoLoanHooksV2.t.sol";

/*//////////////////////////////////////////////////////////////
                            LOCAL MOCKS
//////////////////////////////////////////////////////////////*/

/// @dev Spoke stub exposing only the account-data read the guard needs. A fresh account (never set) reports
///      `type(uint256).max`, like the real Spoke does for an account with no debt.
contract MockAaveV4SpokeAccountData {
    mapping(address => uint256) internal healthFactors;
    mapping(address => bool) internal isSet;

    function setHealthFactor(address user, uint256 healthFactor) external {
        healthFactors[user] = healthFactor;
        isSet[user] = true;
    }

    function getUserAccountData(address user) external view returns (IAaveV4Spoke.UserAccountData memory data) {
        data.healthFactor = isSet[user] ? healthFactors[user] : type(uint256).max;
        data.borrowCount = isSet[user] ? 1 : 0;
    }
}

/// @title AaveV4HealthCheckHookTest
/// @notice Unit coverage for the Aave V4 Spoke health-factor guard (no fork)
contract AaveV4HealthCheckHookTest is Helpers {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant DATA_LENGTH = 168;
    uint256 internal constant SUPPLY_RESERVE_ID = 0;
    uint256 internal constant BORROW_RESERVE_ID = 7;

    AaveV4HealthCheckHook public hook;
    MockAaveV4SpokeAccountData public spokeA;
    MockAaveV4SpokeAccountData public spokeB;
    MockPrevHook public prevHook;

    function setUp() public {
        hook = new AaveV4HealthCheckHook();
        spokeA = new MockAaveV4SpokeAccountData();
        spokeB = new MockAaveV4SpokeAccountData();
        prevHook = new MockPrevHook();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 168-byte layout with the header key derived from the body
    function _encode(
        address spoke,
        uint256 supplyReserveId,
        uint256 borrowReserveId,
        uint256 minHealthFactor
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeWithKey(
            AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId, borrowReserveId),
            spoke,
            supplyReserveId,
            borrowReserveId,
            minHealthFactor
        );
    }

    function _encodeWithKey(
        address key,
        address spoke,
        uint256 supplyReserveId,
        uint256 borrowReserveId,
        uint256 minHealthFactor
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(bytes32(0), key, spoke, supplyReserveId, borrowReserveId, minHealthFactor);
        require(data.length == DATA_LENGTH, "layout must be exactly 168 bytes");
    }

    function _data(uint256 minHealthFactor) internal view returns (bytes memory) {
        return _encode(address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, minHealthFactor);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_NonAccounting_MiscSubtype() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.MISC);
        assertEq(hook.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(), WAD);
    }

    /*//////////////////////////////////////////////////////////////
                                 BUILD
    //////////////////////////////////////////////////////////////*/

    function test_Build_ReturnsOnlyPreAndPost() public {
        spokeA.setHealthFactor(address(this), 2e18);
        Execution[] memory executions = hook.build(address(0), address(this), _data(WAD));

        assertEq(executions.length, 2, "guard emits no executions of its own");
        assertEq(executions[0].target, address(hook));
        assertEq(bytes4(executions[0].callData), ISuperHook.preExecute.selector);
        assertEq(executions[1].target, address(hook));
        assertEq(bytes4(executions[1].callData), ISuperHook.postExecute.selector);
    }

    function test_Build_Pass_WhenHealthFactorAtOrAboveMin() public {
        spokeA.setHealthFactor(address(this), 2e18);
        hook.build(address(0), address(this), _data(2e18)); // exactly at min
        hook.build(address(0), address(this), _data(WAD));
        assertEq(hook.previewHealthFactor(_data(WAD), address(this)), 2e18);
    }

    function test_Build_Pass_EmptyAccount_MaxHealthFactor() public view {
        hook.build(address(0), address(this), _data(type(uint256).max)); // "must have no debt"
        assertEq(hook.previewHealthFactor(_data(WAD), address(this)), type(uint256).max);
    }

    function test_Build_RevertIf_HealthFactorBelowMin() public {
        spokeA.setHealthFactor(address(this), 1.2e18);
        vm.expectRevert(
            abi.encodeWithSelector(AaveV4HealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, 1.2e18, 1.5e18)
        );
        hook.build(address(0), address(this), _data(1.5e18));
    }

    function test_Build_ReadsSpokeFromCalldata() public {
        spokeA.setHealthFactor(address(this), 2e18);
        spokeB.setHealthFactor(address(this), 1.1e18);

        hook.build(address(0), address(this), _encode(address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, 1.5e18));

        vm.expectRevert(
            abi.encodeWithSelector(AaveV4HealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, 1.1e18, 1.5e18)
        );
        hook.build(address(0), address(this), _encode(address(spokeB), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, 1.5e18));
    }

    function test_Build_RevertIf_HeaderNotMarketKey() public {
        bytes memory data = _encodeWithKey(address(0xBEEF), address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, WAD);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        hook.build(address(0), address(this), data);
    }

    /// @dev The key is order-significant: "collateral A, borrow B" is not "collateral B, borrow A"
    function test_Build_RevertIf_SwappedReserveIds() public {
        address keyForSwapped = AaveV4ReserveKey.computeMarketKey(address(spokeA), BORROW_RESERVE_ID, SUPPLY_RESERVE_ID);
        bytes memory data = _encodeWithKey(keyForSwapped, address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, WAD);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        hook.build(address(0), address(this), data);
    }

    /// @dev Same reserve ids on another Spoke derive another key: a leaf is per Spoke
    function test_Build_RevertIf_KeyFromAnotherSpoke() public {
        address keyForB = AaveV4ReserveKey.computeMarketKey(address(spokeB), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID);
        bytes memory data = _encodeWithKey(keyForB, address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, WAD);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        hook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_WrongLength() public {
        bytes memory data = _data(WAD);
        bytes memory shorter = BytesLib.slice(data, 0, DATA_LENGTH - 1);
        bytes memory longer = abi.encodePacked(data, bytes1(0));

        vm.expectRevert(AaveV4HealthCheckHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), address(this), shorter);
        vm.expectRevert(AaveV4HealthCheckHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), address(this), longer);
    }

    function test_Build_RevertIf_ZeroSpoke() public {
        bytes memory data = _encodeWithKey(
            AaveV4ReserveKey.computeMarketKey(address(0), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID),
            address(0),
            SUPPLY_RESERVE_ID,
            BORROW_RESERVE_ID,
            WAD
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroKey() public {
        bytes memory data = _encodeWithKey(address(0), address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, WAD);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_MinBelowWad() public {
        spokeA.setHealthFactor(address(this), 2e18);
        vm.expectRevert(AaveV4HealthCheckHook.INVALID_MIN_HEALTH_FACTOR.selector);
        hook.build(address(0), address(this), _data(WAD - 1));
        vm.expectRevert(AaveV4HealthCheckHook.INVALID_MIN_HEALTH_FACTOR.selector);
        hook.build(address(0), address(this), _data(0));
    }

    /*//////////////////////////////////////////////////////////////
                           PRE / POST EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_RevertIf_HealthFactorBelowMin() public {
        spokeA.setHealthFactor(address(this), 1.2e18);
        bytes memory data = _data(1.5e18);

        hook.preExecute(address(0), address(this), data);
        vm.expectRevert(
            abi.encodeWithSelector(AaveV4HealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, 1.2e18, 1.5e18)
        );
        hook.postExecute(address(0), address(this), data);
    }

    function test_PostExecute_Pass() public {
        spokeA.setHealthFactor(address(this), 2e18);
        bytes memory data = _data(1.5e18);
        hook.preExecute(address(0), address(this), data);
        hook.postExecute(address(0), address(this), data);
    }

    /// @dev Build passes, the Spoke's number drops before postExecute, the guard still trips
    function test_PostExecute_CatchesStateChangeAfterBuild() public {
        spokeA.setHealthFactor(address(this), 2e18);
        bytes memory data = _data(1.5e18);
        hook.build(address(0), address(this), data);

        spokeA.setHealthFactor(address(this), 1.4e18);
        hook.preExecute(address(0), address(this), data);
        vm.expectRevert(
            abi.encodeWithSelector(AaveV4HealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, 1.4e18, 1.5e18)
        );
        hook.postExecute(address(0), address(this), data);
    }

    function test_PreExecute_Passthrough_ForwardsPrevHookOutput() public {
        spokeA.setHealthFactor(address(this), 2e18);
        prevHook.setOutAmount(123);
        prevHook.setOutToken(address(0xCAFE));

        hook.preExecute(address(prevHook), address(this), _data(WAD));

        assertEq(hook.getOutAmount(address(this)), 123);
        assertEq(hook.getOutToken(address(this)), address(0xCAFE));
    }

    /*//////////////////////////////////////////////////////////////
                           INSPECT / SIZING API
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_PacksIdentityAndThreshold() public view {
        bytes memory out = hook.inspect(_data(WAD));
        assertEq(out.length, 136, "marketKey + spoke + 2 reserve ids + minHealthFactor");
        assertEq(
            BytesLib.toAddress(out, 0),
            AaveV4ReserveKey.computeMarketKey(address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID)
        );
        assertEq(BytesLib.toAddress(out, 20), address(spokeA));
        assertEq(BytesLib.toUint256(out, 40), SUPPLY_RESERVE_ID);
        assertEq(BytesLib.toUint256(out, 72), BORROW_RESERVE_ID);
        assertEq(BytesLib.toUint256(out, 104), WAD);

        assertTrue(keccak256(out) != keccak256(hook.inspect(_data(3e18))), "threshold is identity");
    }

    /// @dev Regression for PR #1037 F1: the SuperVault leaf (`SuperVaultAggregator._createLeaf` replica) must change
    ///      when only the threshold changes, so a proof issued for `minHealthFactor = 1.5e18` cannot authorise a
    ///      downgraded `1e18` check.
    function test_Leaf_ThresholdDowngrade_FailsOldProof() public view {
        bytes32 root = _leaf(hook.inspect(_data(1.5e18))); // single-leaf tree: root == leaf, empty proof
        bytes32[] memory proof = new bytes32[](0);

        assertTrue(MerkleProof.verify(proof, root, _leaf(hook.inspect(_data(1.5e18)))), "intended threshold");
        assertFalse(MerkleProof.verify(proof, root, _leaf(hook.inspect(_data(WAD)))), "downgraded threshold");
        assertFalse(MerkleProof.verify(proof, root, _leaf(hook.inspect(_data(3e18)))), "upgraded threshold");
    }

    /// @dev == SuperVaultAggregator._createLeaf
    function _leaf(bytes memory hookArgs) internal view returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(address(hook), hookArgs))));
    }

    function test_Inspect_RevertIf_HeaderNotMarketKey() public {
        bytes memory data = _encodeWithKey(address(0xBEEF), address(spokeA), SUPPLY_RESERVE_ID, BORROW_RESERVE_ID, WAD);
        vm.expectRevert(AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector);
        hook.inspect(data);
    }

    function test_SizingApi_Sizeless() public view {
        assertEq(hook.decodeAmounts("").length, 0);
        assertEq(hook.amountRoles("").length, 0);
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertFalse(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertFalse(hook.supportsInterface(0xdeadbeef));
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Threshold_PassIffHealthFactorAtLeastMin(uint256 healthFactor, uint256 min) public {
        min = bound(min, WAD, 10e18);
        healthFactor = bound(healthFactor, 0, 20e18);
        spokeA.setHealthFactor(address(this), healthFactor);

        if (healthFactor >= min) {
            hook.build(address(0), address(this), _data(min));
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(AaveV4HealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, healthFactor, min)
            );
            hook.build(address(0), address(this), _data(min));
        }
    }
}
