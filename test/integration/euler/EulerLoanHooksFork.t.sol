// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHookLoans } from "../../../src/interfaces/ISuperHook.sol";
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
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";

// Euler hooks
import {
    EulerDepositCollateralAndBorrowHook
} from "../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayHook } from "../../../src/hooks/loan/euler/EulerRepayHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";

// Euler vendor
import { IEVC } from "../../../src/vendor/euler/IEVC.sol";
import { IEVault } from "../../../src/vendor/euler/IEVault.sol";

// test utils
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";

/// @dev EVK views the audited vendor interface intentionally omits but the fork assertions need.
///      maxWithdraw returns 0 while ANY controller is enabled for the owner (EVK cannot price the
///      collateral lock), so the full-exit asset amount is read via convertToAssets(balanceOf) —
///      identical to maxWithdraw once the controller is disabled (verified on this fork).
interface IEVaultForkViews {
    function maxWithdraw(address owner) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @title EulerLoanHooksFork
/// @author Superform Labs
/// @notice Real-address integration tests for the Euler EVK/EVC loan hooks on the BASE chain.
/// @dev No mocks — uses SuperExecutor + SuperNativePaymaster through the real ERC-4337 UserOp flow,
///      against the real Euler (Clearstar) deployment on Base. Hooks are NEVER called directly;
///      every state transition goes through the UserOp flow.
///
/// Market (verified on-chain at the pin block 50_550_000):
///   - EVC                          = 0x5301c7dD20bD945D2013b48ed0DEE3A284ca8989
///   - collateral vault eWETH       = 0x859160DB5841E5cfB8D3f144C6b3381A85A4b410 (asset WETH)
///   - controller vault eUSDC       = 0x0A1a3b5f2041F33522C4efc754a7D096f880eE16 (asset USDC)
///   - eUSDC.LTVBorrow(eWETH)       = 8600 (86%)
///   - eUSDC cash                   ~ 20,559 USDC
///   - eWETH maxDeposit             ~ 1.115e22 (finite supply cap)
contract EulerLoanHooksFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    // Pinned Base block with verified vault liquidity and LTV configuration.
    uint256 internal constant BASE_FORK_BLOCK = 50_550_000;

    // Euler Base (Clearstar) addresses. The EVC and eVaultFactory are constructor-pinned in the
    // hooks; the vaults remain calldata activation data (factory-verified at build time).
    address internal constant EVC = 0x5301c7dD20bD945D2013b48ed0DEE3A284ca8989;
    address internal constant EVAULT_FACTORY = 0x7F321498A801A191a93C840750ed637149dDf8D0;
    address internal constant EWETH_VAULT = 0x859160DB5841E5cfB8D3f144C6b3381A85A4b410;
    address internal constant EUSDC_VAULT = 0x0A1a3b5f2041F33522C4efc754a7D096f880eE16;

    // Legacy (pre-20796) Base loan hook — hardcoded from script/output/prod/8453/Base-latest.json
    // ("MorphoRepayHook"); deployed before the pin block and does NOT implement ISuperHookLoans'
    // current interfaceId.
    address internal constant LEGACY_MORPHO_REPAY_HOOK = 0x5e5F648A3d47B4D032Bc5AE8d78b3c39d549d619;

    // Amounts (exact, both legs — Euler hooks never derive amounts from a ratio/oracle)
    uint256 internal constant COLLATERAL_WETH = 1e18; // 1 WETH collateral
    uint256 internal constant BORROW_USDC = 1000e6; // 1,000 USDC — far below cash and the LTV cap
    uint256 internal constant PARTIAL_REPAY_USDC = 400e6;
    uint256 internal constant PARTIAL_CLOSE_REPAY_USDC = 300e6;
    uint256 internal constant PARTIAL_WITHDRAW_WETH = 2e17;

    // Harness
    address public accountBase;
    AccountInstance public instanceOnBase;
    ISuperExecutor public superExecutorOnBase;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;
    ISuperNativePaymaster public superNativePaymaster;

    // Hooks
    ApproveERC20Hook public approveHook;
    EulerDepositCollateralAndBorrowHook public openHook;
    EulerRepayHook public repayHook;
    EulerRepayAndWithdrawHook public closeHook;

    // Tokens
    address public collateralAsset; // WETH
    address public debtAsset; // USDC

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), BASE_FORK_BLOCK);

        collateralAsset = CHAIN_8453_WETH;
        debtAsset = CHAIN_8453_USDC;

        // ----- Accounting stack (mirrors MinimalBaseIntegrationTest) -----
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));

        instanceOnBase = makeAccountInstance(keccak256(abi.encode("euler-base-acc")));
        accountBase = instanceOnBase.account;

        superExecutorOnBase = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instanceOnBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnBase), data: ""
        });

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
        approveHook = new ApproveERC20Hook();
        openHook = new EulerDepositCollateralAndBorrowHook(EVC, EVAULT_FACTORY);
        repayHook = new EulerRepayHook(EVC, EVAULT_FACTORY);
        closeHook = new EulerRepayAndWithdrawHook(EVC, EVAULT_FACTORY);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                       HELPERS: ENCODE EULER HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 197-byte Euler layout: configId (0), collateralVault (32), debtAsset (52),
    ///      collateralAsset (72), evc (92), controllerVault (112), primary (132), secondary (164),
    ///      usePrevHookAmount (196).
    function _eulerData(
        address collateralVault_,
        address debtAsset_,
        address collateralAsset_,
        address evc_,
        address controllerVault_,
        uint256 primary,
        uint256 secondary,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            bytes32(0),
            collateralVault_,
            debtAsset_,
            collateralAsset_,
            evc_,
            controllerVault_,
            primary,
            secondary,
            usePrevHookAmount
        );
        assertEq(data.length, 197, "Euler layout must be exactly 197 bytes");
    }

    /// @dev Composite (open/close) data against the verified eWETH/eUSDC pair.
    function _compositeData(
        uint256 primary,
        uint256 secondary,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return
            _eulerData(EWETH_VAULT, debtAsset, collateralAsset, EVC, EUSDC_VAULT, primary, secondary, usePrevHookAmount);
    }

    /// @dev Standalone repay data: collateralVault/collateralAsset and the secondary word are
    ///      reserved ZERO.
    function _repayData(uint256 cap, bool usePrevHookAmount) internal view returns (bytes memory) {
        return _eulerData(address(0), debtAsset, address(0), EVC, EUSDC_VAULT, cap, 0, usePrevHookAmount);
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

    /// @dev Executes the UserOp and asserts the account-level execution reverted (the EntryPoint
    ///      swallows the inner revert and emits UserOperationRevertReason instead).
    function _execExpectUserOpRevert(address[] memory hooks, bytes[] memory data) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entry));
        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        bytes memory reason;
        for (uint256 i; i < ret.logs.length; ++i) {
            VmSafe.Log memory logEntry = ret.logs[i];
            if (
                logEntry.topics.length > 0
                    && logEntry.topics[0] == keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)")
            ) {
                (, reason) = abi.decode(logEntry.data, (uint256, bytes));
            }
        }
        assertGt(reason.length, 0, "userOp should have reverted");
    }

    function _execSingleExpectUserOpRevert(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _execExpectUserOpRevert(hooks, datas);
    }

    /// @dev Opens the canonical 1 WETH / 1,000 USDC position through the UserOp flow.
    function _open() internal {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        _execSingle(address(openHook), _compositeData(COLLATERAL_WETH, BORROW_USDC, false));
    }

    /// @dev Exact assets releasing the account's whole eWETH share balance (dust-free:
    ///      previewWithdraw(convertToAssets(shares)) == shares on EVK, verified on this fork).
    function _fullWithdrawAssets() internal view returns (uint256) {
        return IEVaultForkViews(EWETH_VAULT).convertToAssets(IEVault(EWETH_VAULT).balanceOf(accountBase));
    }

    function _controllers() internal view returns (address[] memory) {
        return IEVC(EVC).getControllers(accountBase);
    }

    /*//////////////////////////////////////////////////////////////
                            1. OPEN EXACT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit exact WETH collateral + borrow exact USDC; both wallet deltas are exact,
    ///         debt and EVC controller/collateral state fully asserted.
    function test_Euler_Base_Open_Exact() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);

        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        _execSingle(address(openHook), _compositeData(COLLATERAL_WETH, BORROW_USDC, false));

        assertEq(
            wethBefore - IERC20(collateralAsset).balanceOf(accountBase),
            COLLATERAL_WETH,
            "collateral spent must equal exact amount"
        );
        assertEq(
            IERC20(debtAsset).balanceOf(accountBase) - usdcBefore,
            BORROW_USDC,
            "debt asset received must equal exact borrow amount"
        );

        assertGt(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "collateral shares minted");
        assertApproxEqAbs(IEVault(EUSDC_VAULT).debtOf(accountBase), BORROW_USDC, 1, "debt == borrow (debtOf rounds up)");

        address[] memory controllers = _controllers();
        assertEq(controllers.length, 1, "exactly one controller");
        assertEq(controllers[0], EUSDC_VAULT, "controller == eUSDC");
        assertTrue(IEVC(EVC).isCollateralEnabled(accountBase, EWETH_VAULT), "collateral enabled");

        assertEq(IERC20(collateralAsset).allowance(accountBase, EWETH_VAULT), 0, "collateral allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                            2. OPEN CHAINED
    //////////////////////////////////////////////////////////////*/

    /// @notice A previous hook producing WETH feeds the collateral leg via usePrevHookAmount; the
    ///         placeholder primary in calldata is ignored.
    function test_Euler_Base_Open_Chained_UsesPrevHookOutput() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);

        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook); // position 0: publishes outToken = WETH, outAmount = 1e18
        hooks[1] = address(openHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(collateralAsset, EWETH_VAULT, COLLATERAL_WETH, false);
        data[1] = _compositeData(1, BORROW_USDC, true); // primary = 1 wei placeholder, overridden by prev output

        _exec(hooks, data);

        assertEq(
            wethBefore - IERC20(collateralAsset).balanceOf(accountBase),
            COLLATERAL_WETH,
            "collateral spent must equal prev hook output"
        );
        assertEq(IERC20(debtAsset).balanceOf(accountBase) - usdcBefore, BORROW_USDC, "exact borrow received");

        assertGt(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "collateral shares minted");
        assertApproxEqAbs(IEVault(EUSDC_VAULT).debtOf(accountBase), BORROW_USDC, 1, "debt == borrow");
    }

    /// @notice A previous hook producing the WRONG token (USDC instead of WETH) makes the open
    ///         hook revert with PREV_TOKEN_MISMATCH; state is unchanged.
    function test_Euler_Base_Open_Chained_WrongPrevToken_Reverts() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        _getTokens(debtAsset, accountBase, BORROW_USDC);

        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook); // publishes outToken = USDC — wrong for the collateral slot
        hooks[1] = address(openHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(debtAsset, EUSDC_VAULT, BORROW_USDC, false);
        data[1] = _compositeData(1, BORROW_USDC, true);

        _execExpectUserOpRevert(hooks, data);

        assertEq(IERC20(collateralAsset).balanceOf(accountBase), wethBefore, "WETH untouched");
        assertEq(IERC20(debtAsset).balanceOf(accountBase), usdcBefore, "USDC untouched");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "no collateral shares");
        assertEq(IEVault(EUSDC_VAULT).debtOf(accountBase), 0, "no debt");
        assertEq(_controllers().length, 0, "no controllers");
        assertFalse(IEVC(EVC).isCollateralEnabled(accountBase, EWETH_VAULT), "collateral not enabled");
    }

    /*//////////////////////////////////////////////////////////////
                       3. OPEN IDEMPOTENT ENABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice A second position increment succeeds after an open; the second build emits no EVC
    ///         enable calls (7 executions = pre + 5 hook + post, vs 9 on the first build).
    function test_Euler_Base_Open_SecondIncrement_NoEnableCalls() external {
        // Fresh account: build (view probe) emits both EVC enables — 7 hook execs + pre/post.
        Execution[] memory firstBuild =
            openHook.build(address(0), accountBase, _compositeData(COLLATERAL_WETH, BORROW_USDC, false));
        assertEq(firstBuild.length, 9, "first build: pre + 4 deposit/approve + 2 enables + borrow + post");

        _open();

        // Both enables already active: the probe now emits 5 hook execs + pre/post.
        Execution[] memory secondBuild =
            openHook.build(address(0), accountBase, _compositeData(COLLATERAL_WETH, BORROW_USDC, false));
        assertEq(secondBuild.length, 7, "second build: no enable calls");

        // The second increment executes fine (EVC enables are idempotent / skipped).
        uint256 sharesBefore = IEVault(EWETH_VAULT).balanceOf(accountBase);
        uint256 debtBefore = IEVault(EUSDC_VAULT).debtOf(accountBase);
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        _execSingle(address(openHook), _compositeData(COLLATERAL_WETH, BORROW_USDC, false));

        assertGt(IEVault(EWETH_VAULT).balanceOf(accountBase), sharesBefore, "shares increased");
        assertApproxEqAbs(
            IEVault(EUSDC_VAULT).debtOf(accountBase), debtBefore + BORROW_USDC, 1, "debt increased by exact borrow"
        );
        assertEq(IERC20(debtAsset).balanceOf(accountBase) - usdcBefore, BORROW_USDC, "exact borrow received");
        assertEq(_controllers().length, 1, "still exactly one controller");
    }

    /*//////////////////////////////////////////////////////////////
                        4. STANDALONE REPAY PARTIAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial repay with cap < debt: exact USDC spend, debt reduced by exactly the cap,
    ///         controller still enabled, allowance reset.
    function test_Euler_Base_StandaloneRepay_Partial() external {
        _open();

        uint256 debtBefore = IEVault(EUSDC_VAULT).debtOf(accountBase);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        _execSingle(address(repayHook), _repayData(PARTIAL_REPAY_USDC, false));

        assertEq(
            usdcBefore - IERC20(debtAsset).balanceOf(accountBase), PARTIAL_REPAY_USDC, "USDC spent must equal exact cap"
        );
        assertEq(
            IEVault(EUSDC_VAULT).debtOf(accountBase),
            debtBefore - PARTIAL_REPAY_USDC,
            "debt reduced by exactly the cap (same timestamp, no accrual)"
        );
        assertTrue(IEVC(EVC).isControllerEnabled(accountBase, EUSDC_VAULT), "controller still enabled");
        assertEq(IERC20(debtAsset).allowance(accountBase, EUSDC_VAULT), 0, "debt asset allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                   5. STANDALONE REPAY FULL AFTER ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Full repay via an over-cap after 30 days of accrual: the spend equals the accrued
    ///         debt exactly, debt clears to zero (EVK dust-forgiveness on the real deployment) and
    ///         the controller is disabled via the vault's own path.
    function test_Euler_Base_StandaloneRepay_FullCap_AfterAccrual() external {
        _open();

        vm.warp(block.timestamp + 30 days);

        uint256 debtNow = IEVault(EUSDC_VAULT).debtOf(accountBase);
        assertGt(debtNow, BORROW_USDC, "interest accrued");

        // Accrued interest exceeds the borrowed USDC held in the wallet — top up.
        _getTokens(debtAsset, accountBase, IERC20(debtAsset).balanceOf(accountBase) + debtNow);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        _execSingle(address(repayHook), _repayData(2 * debtNow, false));

        assertEq(
            usdcBefore - IERC20(debtAsset).balanceOf(accountBase),
            debtNow,
            "actual spend == debtOf at execution (cap min'd to debt)"
        );
        assertEq(IEVault(EUSDC_VAULT).debtOf(accountBase), 0, "debt fully cleared, no dust");
        assertEq(_controllers().length, 0, "controller disabled via the vault path");
        assertEq(IERC20(debtAsset).allowance(accountBase, EUSDC_VAULT), 0, "debt asset allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                            6. CLOSE PARTIAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Partial close: repay a 300 USDC cap and withdraw exactly 0.2 WETH; residual debt
    ///         remains and both EVC enables stay on.
    function test_Euler_Base_Close_Partial() external {
        _open();

        uint256 debtBefore = IEVault(EUSDC_VAULT).debtOf(accountBase);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        _execSingle(address(closeHook), _compositeData(PARTIAL_CLOSE_REPAY_USDC, PARTIAL_WITHDRAW_WETH, false));

        assertEq(
            usdcBefore - IERC20(debtAsset).balanceOf(accountBase),
            PARTIAL_CLOSE_REPAY_USDC,
            "USDC spent must equal exact repay cap"
        );
        assertEq(
            IERC20(collateralAsset).balanceOf(accountBase) - wethBefore,
            PARTIAL_WITHDRAW_WETH,
            "WETH received must equal exact withdraw amount"
        );
        assertEq(
            IEVault(EUSDC_VAULT).debtOf(accountBase),
            debtBefore - PARTIAL_CLOSE_REPAY_USDC,
            "residual debt reduced by exactly the cap"
        );
        assertGt(IEVault(EUSDC_VAULT).debtOf(accountBase), 0, "residual debt remains");
        assertTrue(IEVC(EVC).isControllerEnabled(accountBase, EUSDC_VAULT), "controller still enabled");
        assertTrue(IEVC(EVC).isCollateralEnabled(accountBase, EWETH_VAULT), "collateral still enabled");
        assertEq(IERC20(debtAsset).allowance(accountBase, EUSDC_VAULT), 0, "debt asset allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                       7. CLOSE FULL AFTER ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Full close after accrual: over-cap repay clears the debt, the exact full-collateral
    ///         withdrawal burns every share, and both the controller and the collateral end up
    ///         disabled on the EVC.
    /// @dev secondary is computed as convertToAssets(balanceOf) instead of the planned
    ///      maxWithdraw(account): EVK maxWithdraw returns 0 while a controller with outstanding
    ///      debt is enabled (the repay only happens inside the same userOp). The two are identical
    ///      once the controller is off — verified on this fork.
    function test_Euler_Base_Close_Full_AfterAccrual() external {
        _open();

        vm.warp(block.timestamp + 30 days);

        uint256 debtNow = IEVault(EUSDC_VAULT).debtOf(accountBase);
        _getTokens(debtAsset, accountBase, IERC20(debtAsset).balanceOf(accountBase) + debtNow);

        uint256 secondaryFull = _fullWithdrawAssets();
        assertGt(secondaryFull, 0, "full-exit assets resolved");
        assertEq(
            IEVault(EWETH_VAULT).previewWithdraw(secondaryFull),
            IEVault(EWETH_VAULT).balanceOf(accountBase),
            "exact-assets full exit burns the whole share balance"
        );

        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        _execSingle(address(closeHook), _compositeData(2 * debtNow, secondaryFull, false));

        assertEq(IEVault(EUSDC_VAULT).debtOf(accountBase), 0, "debt fully cleared");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "all collateral shares burned");
        assertEq(_controllers().length, 0, "controller disabled");
        assertFalse(IEVC(EVC).isCollateralEnabled(accountBase, EWETH_VAULT), "collateral disabled");
        assertEq(
            IERC20(collateralAsset).balanceOf(accountBase) - wethBefore,
            secondaryFull,
            "WETH wallet delta == exact full-exit assets (published outAmount semantics)"
        );
        assertEq(usdcBefore - IERC20(debtAsset).balanceOf(accountBase), debtNow, "exact accrued debt spent");
        assertEq(IERC20(debtAsset).allowance(accountBase, EUSDC_VAULT), 0, "debt asset allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                              8. REVERTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone repay with zero debt degrades gracefully through the full UserOp flow —
    ///         the repay leg is skipped (no approvals, no spend) and the intent succeeds, so a
    ///         third party gifting a full repayment cannot cancel a signed intent.
    function test_Euler_Base_StandaloneRepay_ZeroDebt_FreshAccount_Graceful() external {
        _getTokens(debtAsset, accountBase, BORROW_USDC);
        uint256 usdcBefore = IERC20(debtAsset).balanceOf(accountBase);

        _execSingle(address(repayHook), _repayData(PARTIAL_REPAY_USDC, false));

        assertEq(IEVault(EUSDC_VAULT).debtOf(accountBase), 0, "no debt");
        assertEq(IERC20(debtAsset).balanceOf(accountBase), usdcBefore, "USDC untouched");
        assertEq(_controllers().length, 0, "no controllers");
        assertEq(IERC20(debtAsset).allowance(accountBase, EUSDC_VAULT), 0, "no allowance ever granted");
    }

    /// @notice Borrow larger than the controller vault's available cash reverts (INSUFFICIENT_CASH).
    function test_Euler_Base_Open_BorrowExceedsCash_Reverts() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        uint256 tooMuch = IEVault(EUSDC_VAULT).cash() + 1;
        _execSingleExpectUserOpRevert(address(openHook), _compositeData(COLLATERAL_WETH, tooMuch, false));

        assertEq(IERC20(collateralAsset).balanceOf(accountBase), wethBefore, "WETH untouched");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "no collateral shares");
        assertEq(_controllers().length, 0, "no controllers");
    }

    /// @notice Deposit above the collateral vault's finite supply cap reverts (DEPOSIT_CAP_EXCEEDED).
    function test_Euler_Base_Open_DepositCapExceeded_Reverts() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        uint256 overCap = IEVault(EWETH_VAULT).maxDeposit(accountBase) + 1;
        _execSingleExpectUserOpRevert(address(openHook), _compositeData(overCap, BORROW_USDC, false));

        assertEq(IERC20(collateralAsset).balanceOf(accountBase), wethBefore, "WETH untouched");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "no collateral shares");
        assertEq(_controllers().length, 0, "no controllers");
    }

    /// @notice Swapping the USDC/WETH asset fields contradicts what the vaults report on-chain
    ///         (VAULT_ASSET_MISMATCH).
    function test_Euler_Base_Open_SwappedAssets_Reverts() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        // debtAsset <-> collateralAsset swapped; vaults unchanged
        bytes memory data = _eulerData(
            EWETH_VAULT, collateralAsset, debtAsset, EVC, EUSDC_VAULT, COLLATERAL_WETH, BORROW_USDC, false
        );
        _execSingleExpectUserOpRevert(address(openHook), data);

        assertEq(IERC20(collateralAsset).balanceOf(accountBase), wethBefore, "WETH untouched");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "no collateral shares");
        assertEq(_controllers().length, 0, "no controllers");
    }

    /// @notice A bogus EVC address (a contract that is not the pinned singleton — here eWETH
    ///         itself) is rejected against the constructor-pinned EVC (EVC_NOT_CANONICAL).
    function test_Euler_Base_Open_BogusEvc_Reverts() external {
        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        bytes memory data = _eulerData(
            EWETH_VAULT, debtAsset, collateralAsset, EWETH_VAULT, EUSDC_VAULT, COLLATERAL_WETH, BORROW_USDC, false
        );
        _execSingleExpectUserOpRevert(address(openHook), data);

        assertEq(IERC20(collateralAsset).balanceOf(accountBase), wethBefore, "WETH untouched");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "no collateral shares");
        assertEq(_controllers().length, 0, "no controllers");
    }

    /// @notice A foreign controller already enabled for the account (prank-enabled eWETH — allowed
    ///         by the real EVC at zero debt) makes an eUSDC open revert (CONTROLLER_MISMATCH).
    function test_Euler_Base_Open_ForeignControllerEnabled_Reverts() external {
        vm.prank(accountBase);
        IEVC(EVC).enableController(accountBase, EWETH_VAULT);
        assertEq(_controllers().length, 1, "foreign controller enabled");

        _getTokens(collateralAsset, accountBase, COLLATERAL_WETH);
        uint256 wethBefore = IERC20(collateralAsset).balanceOf(accountBase);

        _execSingleExpectUserOpRevert(address(openHook), _compositeData(COLLATERAL_WETH, BORROW_USDC, false));

        assertEq(IERC20(collateralAsset).balanceOf(accountBase), wethBefore, "WETH untouched");
        assertEq(IEVault(EWETH_VAULT).balanceOf(accountBase), 0, "no collateral shares");
        address[] memory controllers = _controllers();
        assertEq(controllers.length, 1, "foreign controller unchanged");
        assertEq(controllers[0], EWETH_VAULT, "still the foreign controller");
    }

    /*//////////////////////////////////////////////////////////////
                    9. LEGACY-ADDRESS ERC-165 FALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice The legacy (pre-20796) Base loan hook deployment does NOT advertise the current
    ///         ISuperHookLoans interfaceId. The composite Euler hooks do; the standalone repay
    ///         hook honestly does not (its reserved-zero collateral slot makes the inherited
    ///         collateral-balance getter revert, so the full surface is not honored).
    function test_Euler_Base_LegacyAddress_ERC165Fallback() external view {
        assertGt(LEGACY_MORPHO_REPAY_HOOK.code.length, 0, "legacy hook deployed at pin block");
        assertFalse(
            IERC165(LEGACY_MORPHO_REPAY_HOOK).supportsInterface(type(ISuperHookLoans).interfaceId),
            "legacy loan hook must NOT support the current ISuperHookLoans id"
        );
        assertTrue(
            IERC165(address(openHook)).supportsInterface(type(ISuperHookLoans).interfaceId),
            "Euler open hook supports ISuperHookLoans"
        );
        assertFalse(
            IERC165(address(repayHook)).supportsInterface(type(ISuperHookLoans).interfaceId),
            "Euler standalone repay hook must NOT advertise ISuperHookLoans (reserved collateral slot)"
        );
        assertTrue(
            IERC165(address(closeHook)).supportsInterface(type(ISuperHookLoans).interfaceId),
            "Euler close hook supports ISuperHookLoans"
        );
    }
}
