// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../../../BaseTest.t.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";

import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { IMorphoBase, IMorphoStaticTyping, IMorpho, Id, MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/core/interfaces/ISuperHook.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoRepayAndWithdrawHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
    }
}

contract MorphoRepayHookTest is BaseTest {
    using MarketParamsLib for MarketParams;

    MorphoRepayAndWithdrawHook public hook;

    MarketParams public marketParams;
    Id public marketId;

    address public loanToken;
    address public collateralToken;

    function setUp() public override {
        super.setUp();

        // Initialize hook
        hook = new MorphoRepayAndWithdrawHook(address(this), MORPHO);

        loanToken = existingUnderlyingTokens[BASE][WETH_KEY];
        collateralToken = existingUnderlyingTokens[BASE][USDC_KEY];
    }

    function test_RepayHook_Constructor() public view {
        assertEq(address(hook.morpho()), MORPHO);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_RepayHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayAndWithdrawHook(address(this), address(0));
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
            false,
            false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), hookData);
    }

    function test_RepayHook_PreAndPostExecute() public {
        bytes memory data = _encodeData(false, false, false);

        // Give some tokens to test with
        _getTokens(loanToken, address(this), 1000e18);

        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 1000e18);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);
    }

    function _encodeData(
        bool usePrevHook,
        bool isFullRepayment,
        bool isPositiveFeed
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            loanToken,
            collateralToken,
            MORPHO_ORACLE,
            MORPHO_IRM,
            uint256(1000e18),
            uint256(860_000_000_000_000_000),
            usePrevHook,
            isFullRepayment,
            isPositiveFeed
        );
    }
}
