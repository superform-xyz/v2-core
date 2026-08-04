// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { FlatFeeLedger } from "../../../src/accounting/FlatFeeLedger.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../mocks/unused-oracles/ERC7540YieldSourceOracle.sol";

// Morpho hooks
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";

// Morpho vendor
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// test utils
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";

/// @title MorphoBaseChainHooksFork
/// @author Superform Labs
/// @notice Real-address integration tests for the Morpho Blue loan-hook suite on the BASE chain.
/// @dev No mocks — uses SuperExecutor + SuperNativePaymaster through the real ERC-4337 UserOp flow,
///      against the real Morpho Blue deployment and a real, funded Base market.
///
/// Market (verified on-chain, id 0x3b3769cfca57be2eaed03fcc5299c25691b77781a1e124e7a8d520eb9a7eabb5):
///   - loanToken       = WETH  (0x4200000000000000000000000000000000000006, 18 decimals)
///   - collateralToken = USDC  (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, 6 decimals)
///   - oracle          = MORPHO_ORACLE (0xD09048c8B568Dbf5f189302beA26c9edABFC4858)
///   - irm             = MORPHO_IRM    (0x46415998764C29aB2a25CbeA6254146D50D22687, Base Adaptive Curve IRM)
///   - lltv            = 86%
///
/// NOTE: this market lends WETH against USDC collateral — the inverse of the Ethereum WBTC/USDC tests.
contract MorphoBaseChainHooksFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;
    using MarketParamsLib for MarketParams;

    // Pinned Base block with verified market liquidity (~16.25 WETH supplied, ~6.5 WETH borrowable).
    uint256 internal constant BASE_FORK_BLOCK = 49_500_000;

    // Amounts
    uint256 internal constant COLLATERAL_USDC = 10_000e6; // 10,000 USDC collateral
    uint256 internal constant BORROW_WETH = 5e16; // 0.05 WETH — far below the LTV cap and market liquidity
    uint256 internal constant LEND_WETH = 1e18; // 1 WETH supplied to the lend side

    // Harness
    address public accountBase;
    AccountInstance public instanceOnBase;
    ISuperExecutor public superExecutorOnBase;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;
    ISuperNativePaymaster public superNativePaymaster;

    // Hooks
    MorphoLendHook public lendHook;
    MorphoWithdrawHook public withdrawHook;
    MorphoSupplyHook public supplyHook;
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoSupplyAndBorrowHook public supplyAndBorrowHook;
    MorphoRepayAndWithdrawHook public repayAndWithdrawHook;

    // Market
    address public loanToken; // WETH
    address public collateralToken; // USDC
    uint256 public lltv;
    uint256 public lltvRatio;
    MarketParams public marketParams;
    Id public marketId;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), BASE_FORK_BLOCK);

        loanToken = CHAIN_8453_WETH;
        collateralToken = CHAIN_8453_USDC;
        lltv = 860_000_000_000_000_000; // 86%
        lltvRatio = 660_000_000_000_000_000; // 66% target LTV used by the borrow hook

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: MORPHO_ORACLE,
            irm: MORPHO_IRM,
            lltv: lltv
        });
        marketId = marketParams.id();

        // ----- Accounting stack (mirrors MinimalBaseIntegrationTest) -----
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));

        instanceOnBase = makeAccountInstance(keccak256(abi.encode("morpho-base-acc")));
        accountBase = instanceOnBase.account;

        superExecutorOnBase = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instanceOnBase.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnBase), data: "" });

        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorOnBase);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](3);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(new ERC4626YieldSourceOracle(address(ledgerConfig))),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(new ERC7540YieldSourceOracle(address(ledgerConfig))),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(new ERC5115YieldSourceOracle(address(ledgerConfig))),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(new FlatFeeLedger(address(ledgerConfig), allowedExecutors))
        });
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
        ledgerConfig.setYieldSourceOracles(salts, configs);

        // ----- Hooks + paymaster -----
        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);
        supplyHook = new MorphoSupplyHook(MORPHO);
        borrowHook = new MorphoBorrowHook(MORPHO);
        repayHook = new MorphoRepayHook(MORPHO);
        supplyAndBorrowHook = new MorphoSupplyAndBorrowHook(MORPHO);
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(MORPHO);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPERS: ENCODE HOOK DATA
    //////////////////////////////////////////////////////////////*/

    // Supply and Lend share the same data layout (supply-collateral vs supply-loan differ only by hook).
    function _supplyData(uint256 amount) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken, collateralToken, bytes12(0), loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, amount, lltv, false
        );
    }

    function _lendData(uint256 amount) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken, collateralToken, bytes12(0), loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, amount, lltv, false
        );
    }

    function _withdrawData(uint256 assets, uint256 shares) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken, collateralToken, bytes12(0), loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, lltv, assets, shares
        );
    }

    function _borrowData(uint256 amount) internal view returns (bytes memory) {
        return _createMorphoBorrowHookData(loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, amount, lltvRatio, false, lltv);
    }

    function _repayData(uint256 amount, bool isFullRepayment) internal view returns (bytes memory) {
        return _createMorphoRepayHookData(loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, amount, lltv, false, isFullRepayment);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS: EXECUTE VIA USEROP
    //////////////////////////////////////////////////////////////*/

    function _exec(address[] memory hooks, bytes[] memory data) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _execSingle(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _exec(hooks, datas);
    }

    function _supplyCollateral(uint256 amount) internal {
        _getTokens(collateralToken, accountBase, amount);
        _execSingle(address(supplyHook), _supplyData(amount));
    }

    /*//////////////////////////////////////////////////////////////
                       LEND SIDE (supply loan token)
    //////////////////////////////////////////////////////////////*/

    /// @notice Lend WETH into the market via MorphoLendHook and confirm supply shares are created.
    function test_Base_Lend_SupplyWETH() external {
        _getTokens(loanToken, accountBase, LEND_WETH);

        uint256 wethBefore = IERC20(loanToken).balanceOf(accountBase);
        _execSingle(address(lendHook), _lendData(LEND_WETH));

        assertEq(wethBefore - IERC20(loanToken).balanceOf(accountBase), LEND_WETH, "should spend exact WETH");

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertGt(supplyShares, 0, "should have supply shares");
        assertEq(uint256(borrowShares), 0, "no borrow shares");
        assertEq(uint256(collateral), 0, "no collateral");
    }

    /// @notice Lend WETH then withdraw the full lent position back to the account.
    function test_Base_Lend_And_Withdraw_FullCycle() external {
        _getTokens(loanToken, accountBase, LEND_WETH);
        _execSingle(address(lendHook), _lendData(LEND_WETH));

        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertGt(supplyShares, 0, "lent");

        uint256 wethBefore = IERC20(loanToken).balanceOf(accountBase);
        // Withdraw by shares (assets = 0) to exit the entire position.
        _execSingle(address(withdrawHook), _withdrawData(0, supplyShares));

        (uint256 supplySharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(supplySharesAfter, 0, "position closed");
        assertGt(IERC20(loanToken).balanceOf(accountBase), wethBefore, "WETH returned");
    }

    /*//////////////////////////////////////////////////////////////
                     BORROW SIDE (collateral + borrow)
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply USDC as collateral via MorphoSupplyHook.
    function test_Base_Supply_Collateral() external {
        _getTokens(collateralToken, accountBase, COLLATERAL_USDC);
        uint256 usdcBefore = IERC20(collateralToken).balanceOf(accountBase);

        _execSingle(address(supplyHook), _supplyData(COLLATERAL_USDC));

        assertEq(usdcBefore - IERC20(collateralToken).balanceOf(accountBase), COLLATERAL_USDC, "spent USDC");

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(supplyShares, 0, "collateral is not supply shares");
        assertEq(uint256(borrowShares), 0, "no borrow yet");
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral recorded");
    }

    /// @notice Supply USDC collateral, then borrow WETH against it.
    function test_Base_Borrow_AfterSupply() external {
        _supplyCollateral(COLLATERAL_USDC);

        uint256 wethBefore = IERC20(loanToken).balanceOf(accountBase);
        _execSingle(address(borrowHook), _borrowData(BORROW_WETH));

        assertEq(IERC20(loanToken).balanceOf(accountBase) - wethBefore, BORROW_WETH, "received borrowed WETH");

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral kept");
        assertGt(uint256(borrowShares), 0, "borrow shares created");
        assertEq(supplyShares, 0, "no supply shares");
    }

    /// @notice Supply + borrow chained in a single UserOp.
    function test_Base_SupplyAndBorrow_Chained() external {
        _getTokens(collateralToken, accountBase, COLLATERAL_USDC);

        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _supplyData(COLLATERAL_USDC);
        data[1] = _borrowData(BORROW_WETH);

        uint256 wethBefore = IERC20(loanToken).balanceOf(accountBase);
        _exec(hooks, data);

        (, uint128 borrowShares, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral supplied");
        assertGt(uint256(borrowShares), 0, "borrowed");
        assertEq(IERC20(loanToken).balanceOf(accountBase) - wethBefore, BORROW_WETH, "WETH received");
    }

    /// @notice Supply + borrow via the dedicated MorphoSupplyAndBorrowHook (single hook).
    function test_Base_SupplyAndBorrowHook() external {
        _getTokens(collateralToken, accountBase, COLLATERAL_USDC);

        // For SupplyAndBorrow, `amount` is the COLLATERAL supplied; the borrow amount is derived
        // from the collateral value and `ltvRatio` (66%).
        bytes memory data = _createMorphoSupplyAndBorrowHookData(
            loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, COLLATERAL_USDC, lltvRatio, false, lltv
        );

        uint256 wethBefore = IERC20(loanToken).balanceOf(accountBase);
        _execSingle(address(supplyAndBorrowHook), data);

        (, uint128 borrowShares, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral supplied");
        assertGt(uint256(borrowShares), 0, "borrowed WETH");
        assertGt(IERC20(loanToken).balanceOf(accountBase), wethBefore, "WETH received from borrow");
    }

    /*//////////////////////////////////////////////////////////////
                              REPAY
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial repay reduces borrow shares but leaves a residual debt.
    function test_Base_Repay_Partial() external {
        _supplyCollateral(COLLATERAL_USDC);
        _execSingle(address(borrowHook), _borrowData(BORROW_WETH));

        (, uint128 borrowSharesBefore,) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);

        _execSingle(address(repayHook), _repayData(BORROW_WETH / 2, false));

        (, uint128 borrowSharesAfter,) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "debt reduced");
        assertGt(uint256(borrowSharesAfter), 0, "residual debt remains");
    }

    /// @notice Full lifecycle: supply -> borrow -> accrue interest -> full repay.
    function test_Base_FullCycle_SupplyBorrowRepay() external {
        _supplyCollateral(COLLATERAL_USDC);
        _execSingle(address(borrowHook), _borrowData(BORROW_WETH));

        // Let interest accrue, then sync so build() sees up-to-date debt for the approval calc.
        vm.warp(block.timestamp + 30 days);
        IMorpho(MORPHO).accrueInterest(marketParams);

        // Fund the account with enough WETH to cover principal + accrued interest.
        _getTokens(loanToken, accountBase, IERC20(loanToken).balanceOf(accountBase) + BORROW_WETH);

        _execSingle(address(repayHook), _repayData(0, true));

        (, uint128 borrowShares, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(uint256(borrowShares), 0, "debt fully repaid");
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral untouched by repay");
    }

    /// @notice Repay + withdraw collateral via the combined MorphoRepayAndWithdrawHook.
    function test_Base_RepayAndWithdraw() external {
        _supplyCollateral(COLLATERAL_USDC);
        _execSingle(address(borrowHook), _borrowData(BORROW_WETH));

        vm.warp(block.timestamp + 7 days);
        IMorpho(MORPHO).accrueInterest(marketParams);
        _getTokens(loanToken, accountBase, IERC20(loanToken).balanceOf(accountBase) + BORROW_WETH);

        uint256 usdcBefore = IERC20(collateralToken).balanceOf(accountBase);

        bytes memory data = _createMorphoRepayAndWithdrawHookData(
            loanToken, collateralToken, MORPHO_ORACLE, MORPHO_IRM, 0, lltv, false, true
        );
        _execSingle(address(repayAndWithdrawHook), data);

        (, uint128 borrowShares, uint128 collateral) = IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
        assertEq(uint256(borrowShares), 0, "debt cleared");
        assertLt(uint256(collateral), COLLATERAL_USDC, "collateral withdrawn");
        assertGt(IERC20(collateralToken).balanceOf(accountBase), usdcBefore, "USDC returned");
    }
}
