// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";

// Aave V3
import { IPool } from "../../src/vendor/aave-v3/IPool.sol";
import { AaveV3SupplyHook } from "../../src/hooks/loan/aave-v3/AaveV3SupplyHook.sol";
import { AaveV3WithdrawHook } from "../../src/hooks/loan/aave-v3/AaveV3WithdrawHook.sol";
import { AaveV3BorrowHook } from "../../src/hooks/loan/aave-v3/AaveV3BorrowHook.sol";
import { AaveV3RepayHook } from "../../src/hooks/loan/aave-v3/AaveV3RepayHook.sol";
import { AaveV3SupplyAndBorrowHook } from "../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHook.sol";
import { AaveV3RepayAndWithdrawHook } from "../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHook.sol";
import { AaveV3RepayWithATokensHook } from "../../src/hooks/loan/aave-v3/AaveV3RepayWithATokensHook.sol";

/// @title AaveV3HooksIntegrationTest
/// @notice No-mock fork integration tests for the Aave V3 loan-hook suite against the real Aave V3
///         Core market on Ethereum, driven through the real ERC-4337 UserOp flow.
/// @dev Market: WETH collateral / USDC borrow. aToken & variableDebtToken are resolved in setUp via
///      getReserveData — never hardcoded. Positions asserted via those token balances.
contract AaveV3HooksIntegrationTest is MinimalBaseIntegrationTest {
    IPool public constant POOL = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2); // Ethereum Core Pool
    IPool public constant PRIME_POOL = IPool(0x4e033931ad43597d96D6bcc25c280717730B58B1); // Ethereum Prime market
    uint256 internal constant AAVE_V3_ETH_BLOCK = 21_929_476; // postdates V3.2 stable-rate removal
    uint8 internal constant VARIABLE = 2;

    uint256 internal constant SUPPLY_WETH = 1e18; // 1 WETH collateral
    uint256 internal constant BORROW_USDC = 500e6; // 500 USDC

    address internal weth; // collateral
    address internal usdc; // debt
    address internal aWeth; // aToken of collateral
    address internal vUsdc; // variableDebtToken of debt
    address internal aUsdc; // aToken of debt (for repayWithATokens collateral slot)

    AaveV3SupplyHook internal supplyHook;
    AaveV3WithdrawHook internal withdrawHook;
    AaveV3BorrowHook internal borrowHook;
    AaveV3RepayHook internal repayHook;
    AaveV3SupplyAndBorrowHook internal supplyAndBorrowHook;
    AaveV3RepayAndWithdrawHook internal repayAndWithdrawHook;
    AaveV3RepayWithATokensHook internal repayWithATokensHook;
    ISuperNativePaymaster internal paymaster;

    function setUp() public override {
        blockNumber = AAVE_V3_ETH_BLOCK;
        super.setUp();

        weth = CHAIN_1_WETH;
        usdc = CHAIN_1_USDC;
        aWeth = POOL.getReserveData(weth).aTokenAddress;
        vUsdc = POOL.getReserveData(usdc).variableDebtTokenAddress;
        aUsdc = POOL.getReserveData(usdc).aTokenAddress;
        require(aWeth != address(0) && vUsdc != address(0) && aUsdc != address(0), "reserves not found");

        supplyHook = new AaveV3SupplyHook();
        withdrawHook = new AaveV3WithdrawHook();
        borrowHook = new AaveV3BorrowHook();
        repayHook = new AaveV3RepayHook();
        supplyAndBorrowHook = new AaveV3SupplyAndBorrowHook();
        repayAndWithdrawHook = new AaveV3RepayAndWithdrawHook();
        repayWithATokensHook = new AaveV3RepayWithATokensHook();
        paymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(weth, accountEth, 10e18);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              ENCODERS
    //////////////////////////////////////////////////////////////*/
    function _hdr() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(0));
    }

    // loanToken@52, collateralToken@72, pool@92, amount@112, usePrev@144
    function _sw(address loan, address coll, uint256 amt) internal view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loan, coll, address(POOL), amt, false);
    }

    // ...pool@92, rate@112, amount@113, usePrev@145
    function _br(address loan, address coll, uint8 mode, uint256 amt) internal view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loan, coll, address(POOL), mode, amt, false);
    }

    // ...rate@112, amount1@113, amount2@145, usePrev@177
    function _cb(address loan, address coll, uint256 a1, uint256 a2) internal view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loan, coll, address(POOL), VARIABLE, a1, a2, false);
    }

    function _exec(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _execMany(hooks, datas);
    }

    function _execMany(address[] memory hooks, bytes[] memory datas) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory op = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(op, paymaster, 1e18);
    }

    function _supply(uint256 amt) internal {
        _exec(address(supplyHook), _sw(usdc, weth, amt));
    }

    /*//////////////////////////////////////////////////////////////
                               TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply WETH; collateral is auto-enabled (LTV > 0) with NO explicit toggle (gap #1).
    function test_Supply_AutoEnablesCollateral() external {
        _supply(SUPPLY_WETH);
        assertApproxEqAbs(IERC20(aWeth).balanceOf(accountEth), SUPPLY_WETH, 2, "aWETH minted");
        (,,,,, uint256 hf) = POOL.getUserAccountData(accountEth);
        assertEq(hf, type(uint256).max, "no debt yet -> infinite HF");
        (,, uint256 availableBorrowsBase,,,) = POOL.getUserAccountData(accountEth);
        assertGt(availableBorrowsBase, 0, "collateral auto-enabled -> borrowing power");
    }

    /// @notice Supply then Borrow (two hooks chained in one UserOp).
    function test_SupplyThenBorrow() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _sw(usdc, weth, SUPPLY_WETH);
        datas[1] = _br(usdc, weth, VARIABLE, BORROW_USDC);

        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        _execMany(hooks, datas);

        assertEq(IERC20(usdc).balanceOf(accountEth) - usdcBefore, BORROW_USDC, "USDC borrowed");
        assertApproxEqAbs(IERC20(vUsdc).balanceOf(accountEth), BORROW_USDC, 2, "vDebt USDC");
        assertApproxEqAbs(IERC20(aWeth).balanceOf(accountEth), SUPPLY_WETH, 2, "collateral kept");
    }

    /// @notice Combined SupplyAndBorrow in a single hook.
    function test_SupplyAndBorrow() external {
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        _exec(address(supplyAndBorrowHook), _cb(usdc, weth, SUPPLY_WETH, BORROW_USDC));
        assertEq(IERC20(usdc).balanceOf(accountEth) - usdcBefore, BORROW_USDC, "USDC borrowed");
        assertGt(IERC20(vUsdc).balanceOf(accountEth), 0, "has debt");
        assertGt(IERC20(aWeth).balanceOf(accountEth), 0, "has collateral");
    }

    /// @notice Partial repay reduces but does not clear debt.
    function test_Repay_Partial() external {
        _exec(address(supplyAndBorrowHook), _cb(usdc, weth, SUPPLY_WETH, BORROW_USDC));
        uint256 debtBefore = IERC20(vUsdc).balanceOf(accountEth);

        _exec(address(repayHook), _br(usdc, weth, VARIABLE, BORROW_USDC / 2));

        uint256 debtAfter = IERC20(vUsdc).balanceOf(accountEth);
        assertLt(debtAfter, debtBefore, "debt reduced");
        assertGt(debtAfter, 0, "residual debt");
    }

    /// @notice Full repay via type(uint256).max after interest accrues — no dust left (gap: max sentinel).
    function test_Repay_Full_Max() external {
        _exec(address(supplyAndBorrowHook), _cb(usdc, weth, SUPPLY_WETH, BORROW_USDC));

        vm.warp(block.timestamp + 15 days);
        vm.roll(block.number + 100_000);
        _getTokens(usdc, accountEth, IERC20(usdc).balanceOf(accountEth) + 50e6); // cover interest

        _exec(address(repayHook), _br(usdc, weth, VARIABLE, type(uint256).max));

        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "debt fully cleared, no dust");
    }

    /// @notice Combined RepayAndWithdraw: full repay (max) + full withdraw (max).
    function test_RepayAndWithdraw_Full() external {
        _exec(address(supplyAndBorrowHook), _cb(usdc, weth, SUPPLY_WETH, BORROW_USDC));

        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_000);
        _getTokens(usdc, accountEth, IERC20(usdc).balanceOf(accountEth) + 50e6);

        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);
        _exec(address(repayAndWithdrawHook), _cb(usdc, weth, type(uint256).max, type(uint256).max));

        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "debt cleared");
        assertEq(IERC20(aWeth).balanceOf(accountEth), 0, "collateral fully withdrawn");
        assertGt(IERC20(weth).balanceOf(accountEth), wethBefore, "WETH returned");
    }

    /// @notice Partial withdraw of supplied collateral (no debt).
    function test_Withdraw_Partial() external {
        _supply(SUPPLY_WETH);
        uint256 aBefore = IERC20(aWeth).balanceOf(accountEth);
        uint256 wethBefore = IERC20(weth).balanceOf(accountEth);

        _exec(address(withdrawHook), _sw(usdc, weth, SUPPLY_WETH / 2));

        assertApproxEqAbs(aBefore - IERC20(aWeth).balanceOf(accountEth), SUPPLY_WETH / 2, 2, "aWETH burned");
        assertApproxEqAbs(IERC20(weth).balanceOf(accountEth) - wethBefore, SUPPLY_WETH / 2, 2, "WETH received");
    }

    /// @notice Leverage-unwind via repayWithATokens (aUSDC in the collateral slot; no approval).
    function test_RepayWithATokens() external {
        // Build a USDC-collateral / (also USDC) position so the account holds aUSDC to repay with:
        // supply USDC, borrow USDC against WETH is circular — instead supply USDC as extra collateral.
        // Simplest: supply WETH + borrow USDC, then supply that USDC to get aUSDC, then repayWithATokens.
        _exec(address(supplyAndBorrowHook), _cb(usdc, weth, SUPPLY_WETH, BORROW_USDC));
        // supply the borrowed USDC to mint aUSDC
        _exec(address(supplyHook), _sw(usdc, usdc, BORROW_USDC));

        uint256 debtBefore = IERC20(vUsdc).balanceOf(accountEth);
        assertGt(debtBefore, 0, "has USDC debt");
        assertGt(IERC20(aUsdc).balanceOf(accountEth), 0, "has aUSDC");

        // repayWithATokens: loanToken=USDC (underlying), collateralToken=aUSDC (aToken, for balance-delta)
        _exec(address(repayWithATokensHook), _br(usdc, aUsdc, VARIABLE, type(uint256).max));

        assertLt(IERC20(vUsdc).balanceOf(accountEth), debtBefore, "debt reduced via aTokens");
    }

    /// @notice interestRateMode != 2 is rejected in-hook — the borrow does not execute (gap: rate validation).
    function test_InvalidRateMode_DoesNotBorrow() external {
        _supply(SUPPLY_WETH);
        // A stable-mode (1) borrow: the hook's build() reverts INVALID_RATE_MODE, so the op does not borrow.
        _exec(address(borrowHook), _br(usdc, weth, 1, BORROW_USDC));
        assertEq(IERC20(vUsdc).balanceOf(accountEth), 0, "no debt created with invalid rate mode");
    }

    /// @notice The SAME hook deployment works against a second Ethereum market (Prime) purely via the
    ///         pool address in calldata — proving the pool-in-data design (no per-market deployment).
    function test_MultiMarket_Prime_SameHookDeployment() external {
        address primeAWeth = PRIME_POOL.getReserveData(weth).aTokenAddress;
        address primeVUsdc = PRIME_POOL.getReserveData(usdc).variableDebtTokenAddress;

        bytes memory data =
            abi.encodePacked(_hdr(), usdc, weth, address(PRIME_POOL), VARIABLE, SUPPLY_WETH, BORROW_USDC, false);
        uint256 usdcBefore = IERC20(usdc).balanceOf(accountEth);
        _exec(address(supplyAndBorrowHook), data);

        assertEq(IERC20(usdc).balanceOf(accountEth) - usdcBefore, BORROW_USDC, "borrowed from Prime");
        assertGt(IERC20(primeAWeth).balanceOf(accountEth), 0, "Prime aWETH minted");
        assertGt(IERC20(primeVUsdc).balanceOf(accountEth), 0, "Prime vDebt minted");
        // Core market position is untouched — routing is purely calldata-driven.
        assertEq(IERC20(aWeth).balanceOf(accountEth), 0, "no Core position");
    }
}
