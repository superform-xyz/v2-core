// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

// external
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { SpectraExchangeDepositHook } from "../../../src/hooks/swappers/spectra/SpectraExchangeDepositHook.sol";
import { SpectraExchangeRedeemHook } from "../../../src/hooks/swappers/spectra/SpectraExchangeRedeemHook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";

// -- mock used when `useRealOdosRouter` is false
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockSpectraRouter, MockSpectraRedeemRouter } from "../../mocks/MockSpectraRouter.sol";

contract SpectraExchangeHooksIntegrationTest is MinimalBaseIntegrationTest {
    address public spectraRouter;
    address public spectraRedeemRouter;

    address public tokenIn;
    address public ptToken;

    SpectraExchangeDepositHook public hook;
    SpectraExchangeRedeemHook public redeemHook;

    bool public useRealSpectraRouter;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        useRealSpectraRouter = useRealOdosRouter;

        if (useRealSpectraRouter) {
            spectraRouter = CHAIN_1_SPECTRA_ROUTER;
            vm.label(spectraRouter, "Spectra Router");
            tokenIn = CHAIN_1_USDC;
            vm.label(tokenIn, "USDC");
            ptToken = CHAIN_1_SPECTRA_PT_IPOR_USDC;
            vm.label(ptToken, "PT-IPOR-USDC");

            hook = new SpectraExchangeDepositHook(CHAIN_1_SPECTRA_ROUTER);
            redeemHook = new SpectraExchangeRedeemHook(CHAIN_1_SPECTRA_ROUTER);
        } else {
            tokenIn = address(new MockERC20("Test Token", "TEST", 18));
            ptToken = address(new MockERC20("Test Token", "TEST", 18));

            spectraRouter = address(new MockSpectraRouter(ptToken));
            spectraRedeemRouter = address(new MockSpectraRedeemRouter(tokenIn, ptToken));

            hook = new SpectraExchangeDepositHook(spectraRouter);
            redeemHook = new SpectraExchangeRedeemHook(spectraRedeemRouter);
        }
    }

    function test_SpectraExchangeSwapHook_DepositAssetInPT() public {
        if (useRealSpectraRouter) {
            uint256 amount = 1e6;

            // get tokens
            deal(tokenIn, accountEth, amount);

            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = address(approveHook);
            hookAddresses_[1] = address(hook);

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(tokenIn, spectraRouter, amount, false);
            hookData[1] = _createSpectraExchangeDepositHookData(false, 0, ptToken, tokenIn, amount, accountEth);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
            UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
            executeOp(opData);

            uint256 balance = IERC20(ptToken).balanceOf(accountEth);
            assertGt(balance, 0);
        } else {
            uint256 amount = 1e6;

            // get tokens
            deal(tokenIn, accountEth, amount);
            deal(ptToken, address(spectraRouter), amount);

            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = address(approveHook);
            hookAddresses_[1] = address(hook);

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(tokenIn, spectraRouter, amount, false);
            hookData[1] = _createSpectraExchangeDepositHookData(false, 0, ptToken, tokenIn, amount, accountEth);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
            UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
            executeOp(opData);

            uint256 balance = IERC20(ptToken).balanceOf(accountEth);
            assertGt(balance, 0);
        }
    }

    function test_SpectraExchangeSwapHook_DepositAndRedeemPT() public {
        if (useRealSpectraRouter) {
            uint256 amount = 1e6;

            // get tokens
            deal(tokenIn, accountEth, amount);

            // First, deposit asset in PT
            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = address(approveHook);
            hookAddresses_[1] = address(hook);

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(tokenIn, spectraRouter, amount, false);
            hookData[1] = _createSpectraExchangeDepositHookData(false, 0, ptToken, tokenIn, amount, accountEth);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
            UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
            executeOp(opData);

            uint256 ptBalance = IERC20(ptToken).balanceOf(accountEth);
            assertGt(ptBalance, 0);

            // Now redeem PT for asset
            uint256 sharesToBurn = ptBalance;
            uint256 minAssets = 1; // Minimum assets to receive

            address[] memory redeemHookAddresses_ = new address[](2);
            redeemHookAddresses_[0] = address(approveHook);
            redeemHookAddresses_[1] = address(redeemHook);

            bytes[] memory redeemHookData = new bytes[](2);
            redeemHookData[0] = _createApproveHookData(ptToken, spectraRedeemRouter, amount, false);
            redeemHookData[0] = _createSpectraExchangeRedeemHookData(
                tokenIn, // asset
                ptToken, // pt
                accountEth, // recipient
                minAssets, // minAssets
                sharesToBurn, // sharesToBurn
                false, // usePrevHookAmount
                true // redeemPtForAsset
            );

            ISuperExecutor.ExecutorEntry memory redeemEntryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHookAddresses_, hooksData: redeemHookData });
            UserOpData memory redeemOpData =
                _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(redeemEntryToExecute));
            executeOp(redeemOpData);

            // Verify the redemption was successful
            uint256 finalAssetBalance = IERC20(tokenIn).balanceOf(accountEth);
            uint256 finalPtBalance = IERC20(ptToken).balanceOf(accountEth);

            assertGt(finalAssetBalance, 0);
            assertEq(finalPtBalance, 0); // All PT tokens should be redeemed
        } else {
            uint256 amount = 1e6;

            // get tokens
            deal(tokenIn, accountEth, amount);
            deal(ptToken, address(spectraRouter), amount);
            deal(tokenIn, address(spectraRedeemRouter), amount);

            // First, deposit asset in PT
            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = address(approveHook);
            hookAddresses_[1] = address(hook);

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(tokenIn, spectraRouter, amount, false);
            hookData[1] = _createSpectraExchangeDepositHookData(false, 0, ptToken, tokenIn, amount, accountEth);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
            UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
            executeOp(opData);

            uint256 ptBalance = IERC20(ptToken).balanceOf(accountEth);
            assertGt(ptBalance, 0);

            // Now redeem PT for asset
            uint256 sharesToBurn = ptBalance;
            uint256 minAssets = 100; // Minimum assets to receive

            address[] memory redeemHookAddresses_ = new address[](2);
            redeemHookAddresses_[0] = address(approveHook);
            redeemHookAddresses_[1] = address(redeemHook);

            bytes[] memory redeemHookData = new bytes[](2);
            redeemHookData[0] = _createApproveHookData(ptToken, spectraRedeemRouter, amount, false);
            redeemHookData[1] = _createSpectraExchangeRedeemHookData(
                tokenIn, // asset
                ptToken, // pt
                accountEth, // recipient
                minAssets, // minAssets
                sharesToBurn, // sharesToBurn
                false, // usePrevHookAmount
                true // redeemPtForAsset
            );

            ISuperExecutor.ExecutorEntry memory redeemEntryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHookAddresses_, hooksData: redeemHookData });
            UserOpData memory redeemOpData =
                _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(redeemEntryToExecute));
            executeOp(redeemOpData);

            // Verify the redemption was successful
            uint256 finalAssetBalance = IERC20(tokenIn).balanceOf(accountEth);
            uint256 finalPtBalance = IERC20(ptToken).balanceOf(accountEth);

            assertGt(finalAssetBalance, 0);
            assertEq(finalPtBalance, 0); // All PT tokens should be redeemed
        }
    }
}
