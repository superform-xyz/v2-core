// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { HyperCoreAddApiWalletHook } from "../../../../src/hooks/hypercore/HyperCoreAddApiWalletHook.sol";
import { HyperCoreApproveBuilderFeeHook } from "../../../../src/hooks/hypercore/HyperCoreApproveBuilderFeeHook.sol";
import { ApproveAndHyperCoreDepositHook } from "../../../../src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol";
import { DeployV2OtherHooks } from "../../../../script/DeployV2OtherHooks.s.sol";
import { Helpers } from "../../../utils/Helpers.sol";

/// @notice Exposes the deploy script's shipped builder-fee cap constant.
contract FeeCapHarness is DeployV2OtherHooks {
    function shippedPerpFeeCap() external pure returns (uint64) {
        return HYPERCORE_MAX_BUILDER_FEE_RATE_PERPS;
    }
}

/// @notice Exercises the deploy path: locked bytecode + constructor args, exactly as
///         DeployV2OtherHooks assembles them.
/// @dev A mis-encoded constructor argument produces a contract that deploys successfully and is
///      wrong forever. This is the only place that can catch it before mainnet.
contract HyperCoreDeploymentTest is Helpers {
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;
    address internal constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address internal constant GATEWAY = 0x6B9E773128f453f5c2C60935Ee2DE2CBc5390A24;
    /// @dev destinationDex 0 == perp dex 0 (perp margin). type(uint32).max would be spot.
    uint32 internal constant DESTINATION_DEX = 0;
    uint64 internal constant MAX_BUILDER_FEE_RATE = 100; // decibps: 0.1%, the perp maximum

    function _deploy(string memory contractName, bytes memory args) internal returns (address addr) {
        bytes memory code = vm.getCode(string(abi.encodePacked("script/locked-bytecode/", contractName, ".json")));
        bytes memory creation = abi.encodePacked(code, args);
        assembly {
            addr := create(0, add(creation, 0x20), mload(creation))
        }
        require(addr != address(0), "deploy failed");
    }

    /// @dev Single-arg leaves: the arg the deploy script encodes must land on CORE_WRITER.
    function test_LockedBytecode_SingleArgLeafSetsCoreWriter() public {
        address a = _deploy("HyperCoreAddApiWalletHook", abi.encode(CORE_WRITER));
        assertEq(HyperCoreAddApiWalletHook(a).CORE_WRITER(), CORE_WRITER, "CORE_WRITER immutable");
    }

    /// @dev Two-arg leaf: arg ORDER matters and a swap would still deploy cleanly.
    function test_LockedBytecode_BuilderFeeSetsBothArgsInOrder() public {
        address a = _deploy("HyperCoreApproveBuilderFeeHook", abi.encode(CORE_WRITER, MAX_BUILDER_FEE_RATE));
        assertEq(HyperCoreApproveBuilderFeeHook(a).CORE_WRITER(), CORE_WRITER, "CORE_WRITER immutable");
        assertEq(HyperCoreApproveBuilderFeeHook(a).MAX_BUILDER_FEE_RATE(), MAX_BUILDER_FEE_RATE, "fee cap immutable");
    }

    /// @dev Three-arg deposit hook. TOKEN and GATEWAY are both addresses, so a transposition
    ///      deploys fine and then approves the wrong contract forever.
    function test_LockedBytecode_DepositHookSetsTokenGatewayAndDestinationDex() public {
        address a = _deploy("ApproveAndHyperCoreDepositHook", abi.encode(USDC, GATEWAY, DESTINATION_DEX));
        ApproveAndHyperCoreDepositHook h = ApproveAndHyperCoreDepositHook(a);
        assertEq(h.TOKEN(), USDC, "TOKEN must be the real ERC-20, not the gateway");
        assertEq(h.GATEWAY(), GATEWAY, "GATEWAY must be the tokenInfo.evmContract");
        assertEq(h.DESTINATION_DEX(), DESTINATION_DEX, "perp dex 0: credits perp margin, not spot");
        assertTrue(h.TOKEN() != h.GATEWAY(), "token and gateway must never be the same address");
    }

    /// @dev Guards the single most confusable pair in this whole integration.
    function test_TokenIsNotTheGatewayAddress() public pure {
        assertTrue(USDC != GATEWAY, "tokenInfo.evmContract is the gateway, not the token");
    }

    /// @dev Binds the shipped deploy constant to the tested value. The builder-fee tests use a local
    ///      100; without this, a regression of HYPERCORE_MAX_BUILDER_FEE_RATE_PERPS back to the spot
    ///      maximum (1000, the exact 10x bug fixed in 563ee53f) would deploy a 10x-too-permissive cap
    ///      while every other test stayed green.
    function test_ShippedPerpFeeCapIsPointOnePercent() public {
        FeeCapHarness h = new FeeCapHarness();
        assertEq(h.shippedPerpFeeCap(), MAX_BUILDER_FEE_RATE, "shipped perp cap must be 100 decibps (0.1%)");
    }
}
