// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { MarketParamsLib } from "../../src/vendor/morpho/MarketParamsLib.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../src/vendor/morpho/IMorpho.sol";
import { MorphoRepayAndWithdrawHook } from "../../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MorphoBorrowHook } from "../../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { console } from "forge-std/console.sol";

contract MorphoHooksIntegrationTest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    address public repayAndWithdrawHookAddress;
    address public morphoBorrowHook;
    address public morphoRepayHook;

    MorphoRepayAndWithdrawHook public repayAndWithdrawHook;

    address public constant CHAIN_1_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address public morpho_oracle_wbtc_usdc = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
    address public morpho_irm_wbtc_usdc = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    uint256 public amount;
    uint256 public lltv;
    uint256 public lltvRatio;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        morphoBorrowHook = address(new MorphoBorrowHook(address(MORPHO)));
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(address(MORPHO));
        repayAndWithdrawHookAddress = address(repayAndWithdrawHook);

        amount = 1_000_000;
        lltv = 860_000_000_000_000_000;
        lltvRatio = 660_000_000_000_000_000;

        _getTokens(CHAIN_1_WBTC, accountEth, 1e8);
    }

    function test_MorphoBorrowHook_TracksCollateralNotLoan() external {
        console.log("=== MorphoBorrowHook Token Tracking Test ===");

        address loanToken = CHAIN_1_USDC;
        address collateralToken = CHAIN_1_WBTC;

        // Log initial balances
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        console.log("Initial Balances:");
        console.log("  Collateral (WBTC):", collateralBefore);
        console.log("  Loan Token (USDC):", loanBefore);

        // Setup the borrow hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = morphoBorrowHook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoBorrowHookData(
            loanToken, collateralToken, morpho_oracle_wbtc_usdc, morpho_irm_wbtc_usdc, amount, lltvRatio, false, lltv
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Execute the borrow operation
        executeOp(userOpData);

        //confirmed by console2.log
    }

    /*//////////////////////////////////////////////////////////////
                      TEST REPAY AND WITHDRAW LLTV
    //////////////////////////////////////////////////////////////*/
    function test_RepayAndWithdrawHook_PartialRepay_Maintains_LTV() public {
        address loanToken = CHAIN_1_USDC;
        address collateralToken = CHAIN_1_WBTC;

        // Setup the borrow hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = morphoBorrowHook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoBorrowHookData(
            loanToken, collateralToken, morpho_oracle_wbtc_usdc, morpho_irm_wbtc_usdc, amount, lltvRatio, false, lltv
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Execute the borrow operation
        executeOp(userOpData);

        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: morpho_oracle_wbtc_usdc,
            irm: morpho_irm_wbtc_usdc,
            lltv: lltv
        });

        // Fast forward some time
        vm.warp(block.timestamp + 10 weeks);

        // Accrue interest
        IMorphoStaticTyping morpho = IMorphoStaticTyping(MORPHO);
        morpho.accrueInterest(marketParams);

        uint128 collateral;
        Id id = marketParams.id();
        (,, collateral) = morpho.position(id, accountEth);

        uint256 initialLtv = (repayAndWithdrawHook.sharesToAssets(marketParams, accountEth) * 1e18) / collateral;

        // Generate data for hook
        uint256 repayAmount = 500_000; // repay 50% of loan

        // Setup the borrow hook execution
        address[] memory repayAndWithdrawHookAddresses = new address[](1);
        repayAndWithdrawHookAddresses[0] = repayAndWithdrawHookAddress;

        bytes[] memory repayAndWithdrawHookData = new bytes[](1);
        repayAndWithdrawHookData[0] = abi.encodePacked(
            loanToken,
            collateralToken,
            morpho_oracle_wbtc_usdc,
            morpho_irm_wbtc_usdc,
            repayAmount,
            lltv,
            false, // don't use prev hook
            false // not a full repayment
        );

        ISuperExecutor.ExecutorEntry memory entry1 = ISuperExecutor.ExecutorEntry({
            hooksAddresses: repayAndWithdrawHookAddresses,
            hooksData: repayAndWithdrawHookData
        });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry1));

        // Execute the partial repayment operation
        executeOp(userOpData1);

        // Fetch final position data. LTV has increased as collateral to withdraw has been computed
        // without accounting for unrealized debt.
        // Final LTV is around 81.9% when it should have mantained at 80% + interest (around 80.9%).
        console.log("Final borrow amount:", repayAndWithdrawHook.sharesToAssets(marketParams, accountEth));
        console.log("Final collateral:", collateral);
        console.log("---LTV1:", (repayAndWithdrawHook.sharesToAssets(marketParams, accountEth) * 1e18) / collateral);

        uint256 finalLtv = (repayAndWithdrawHook.sharesToAssets(marketParams, accountEth) * 1e18) / collateral;
        console.log("---LTV Diff:", initialLtv - finalLtv);
    }
}
