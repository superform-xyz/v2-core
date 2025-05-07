// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Id, MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoRepayAndWithdrawHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
    }
}

contract MorphoRepayHookTest is Helpers {
    using MarketParamsLib for MarketParams;

    MorphoRepayAndWithdrawHook public hook;

    MarketParams public marketParams;
    Id public marketId;

    address public loanToken;
    address public collateralToken;

    function setUp() public {
        // Initialize hook
        hook = new MorphoRepayAndWithdrawHook(MORPHO);

        loanToken = 0x4200000000000000000000000000000000000006;
        collateralToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    }

    function test_RepayHook_Constructor() public view {
        assertEq(address(hook.morpho()), MORPHO);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_RepayHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayAndWithdrawHook(address(0));
    }

    function test_RepayHook_Build_RevertIf_InvalidAddresses() public {
        bytes memory hookData = abi.encodePacked(
            address(0),
            collateralToken,
            MORPHO_ORACLE,
            MORPHO_IRM,
            uint256(1000e18),
            uint256(860_000_000_000_000_000),
            false,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), hookData);
    }

    function _encodeData(bool usePrevHook, bool isFullRepayment) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken,
            collateralToken,
            MORPHO_ORACLE,
            MORPHO_IRM,
            uint256(1000e18),
            uint256(860_000_000_000_000_000),
            usePrevHook,
            isFullRepayment
        );
    }
}
