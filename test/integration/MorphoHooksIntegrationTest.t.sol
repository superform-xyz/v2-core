// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MarketParamsLib } from "../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../src/vendor/morpho/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { MorphoRepayAndWithdrawHook } from "../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

contract MorphoHooksIntegrationTest is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    address public repayAndWithdrawHookAddress;
    address public morphoSupplyAndBorrowHook;
    address public morphoRepayHook;

    MorphoRepayAndWithdrawHook public repayAndWithdrawHook;
    ISuperNativePaymaster public superNativePaymaster;

    uint256 public amount;
    uint256 public lltv;
    uint256 public lltvRatio;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        morphoSupplyAndBorrowHook = address(new MorphoSupplyAndBorrowHook(address(MORPHO)));
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(address(MORPHO));
        repayAndWithdrawHookAddress = address(repayAndWithdrawHook);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        amount = 1_000_000;
        lltv = 860_000_000_000_000_000;
        lltvRatio = 660_000_000_000_000_000;

        _getTokens(CHAIN_1_WBTC, accountEth, 1e8);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                      TESTS
    //////////////////////////////////////////////////////////////*/
    function test_MorphoSupplyAndBorrowHook_TracksCollateralNotLoan() external {
        console2.log("=== MorphoSupplyAndBorrowHook Token Tracking Test ===");

        address loanToken = CHAIN_1_USDC;
        address collateralToken = CHAIN_1_WBTC;

        // Log initial balances
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        console2.log("Initial Balances:");
        console2.log("  Collateral (WBTC):", collateralBefore);
        console2.log("  Loan Token (USDC):", loanBefore);

        // Setup the borrow hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = morphoSupplyAndBorrowHook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoSupplyAndBorrowHookData(
            loanToken, collateralToken, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, amount, lltvRatio, false, lltv
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Execute the borrow operation
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        // Get post-execution balances
        uint256 collateralAfter = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanAfter = IERC20(loanToken).balanceOf(accountEth);

        console2.log("Post-Execution Balances:");
        console2.log("  Collateral (WBTC):", collateralAfter);
        console2.log("  Loan Token (USDC):", loanAfter);

        // Get market parameters
        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: lltv
        });

        Id id = marketParams.id();
        (uint256 borrowed, uint256 supplied, uint128 collateralShares) =
            IMorphoStaticTyping(MORPHO).position(id, accountEth);

        console2.log("Morpho Position:");
        console2.log("  Borrowed:", borrowed);
        console2.log("  Supplied:", supplied);
        console2.log("  Collateral Shares:", collateralShares);

        assertLt(collateralAfter, collateralBefore, "Collateral balance should decrease");
        assertEq(collateralBefore - collateralAfter, amount, "Collateral amount should match supplied amount");
        assertGt(loanAfter, loanBefore, "Loan token balance should increase");
        assertGt(collateralShares, 0, "Collateral shares should be tracked in Morpho");
    }

    function test_RepayAndWithdrawHook_PartialRepay_Maintains_LTV() public {
        address loanToken = CHAIN_1_USDC;
        address collateralToken = CHAIN_1_WBTC;

        // Setup the borrow hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = morphoSupplyAndBorrowHook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoSupplyAndBorrowHookData(
            loanToken, collateralToken, MORPHO_ORACLE_WBTC_USDC, MORPHO_IRM_WBTC_USDC, amount, lltvRatio, false, lltv
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Execute the borrow operation
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
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
            MORPHO_ORACLE_WBTC_USDC,
            MORPHO_IRM_WBTC_USDC,
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
        executeOpsThroughPaymaster(userOpData1, superNativePaymaster, 1e18);

        uint128 collateralAfter;
        (,, collateralAfter) = morpho.position(id, accountEth);

        uint256 finalLtv = (repayAndWithdrawHook.sharesToAssets(marketParams, accountEth) * 1e18) / collateralAfter;

        assertApproxEqRel(finalLtv, initialLtv, 1e16);
    }
}
