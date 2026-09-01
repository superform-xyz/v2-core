// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

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
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";

// Morpho V2 hooks
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";

// Morpho vendor
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../src/vendor/morpho/MorphoBalancesLib.sol";
import { Id, IMorpho, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

// test utils
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";

/// @title MorphoV2BaseChainHooksFork
/// @author Superform Labs
/// @notice Real-address integration tests for the V2 Morpho Blue loan hooks on the BASE chain.
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
contract MorphoV2BaseChainHooksFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;
    using MarketParamsLib for MarketParams;

    // Pinned Base block with verified market liquidity (~16.25 WETH supplied, ~6.5 WETH borrowable).
    uint256 internal constant BASE_FORK_BLOCK = 49_500_000;

    // Amounts (exact, both legs — V2 hooks never derive amounts from a ratio/oracle)
    uint256 internal constant COLLATERAL_USDC = 10_000e6; // 10,000 USDC collateral
    uint256 internal constant BORROW_WETH = 5e16; // 0.05 WETH — far below the LTV cap and market liquidity
    uint256 internal constant PARTIAL_REPAY_WETH = 2e16;
    uint256 internal constant PARTIAL_WITHDRAW_USDC = 1000e6;

    // Harness
    address public accountBase;
    AccountInstance public instanceOnBase;
    ISuperExecutor public superExecutorOnBase;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;
    ISuperNativePaymaster public superNativePaymaster;

    // Hooks
    ApproveERC20Hook public approveHook;
    MorphoSupplyAndBorrowHookV2 public openHook;
    MorphoRepayHookV2 public repayHook;
    MorphoRepayAndWithdrawHookV2 public closeHook;

    // Market
    address public loanToken; // WETH
    address public collateralToken; // USDC
    uint256 public lltv;
    MarketParams public marketParams;
    Id public marketId;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), BASE_FORK_BLOCK);

        loanToken = CHAIN_8453_WETH;
        collateralToken = CHAIN_8453_USDC;
        lltv = 860_000_000_000_000_000; // 86%

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

        instanceOnBase = makeAccountInstance(keccak256(abi.encode("morpho-v2-base-acc")));
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
        approveHook = new ApproveERC20Hook();
        openHook = new MorphoSupplyAndBorrowHookV2(MORPHO);
        repayHook = new MorphoRepayHookV2(MORPHO);
        closeHook = new MorphoRepayAndWithdrawHookV2(MORPHO);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                       HELPERS: ENCODE V2 HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 230-byte Morpho V2 layout:
    ///      52-byte strategy header (bytes32(0) + address(0)), then loanToken (offset 52),
    ///      collateralToken (72), oracle (92), irm (112), amount1 (132), amount2 (164),
    ///      usePrevHookAmount (196), lltv (197), reserved zero byte (229).
    function _morphoV2Data(
        uint256 amount1,
        uint256 amount2,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            bytes32(0),
            address(0),
            loanToken,
            collateralToken,
            MORPHO_ORACLE,
            MORPHO_IRM,
            amount1,
            amount2,
            usePrevHookAmount,
            lltv,
            bytes1(0)
        );
        assertEq(data.length, 230, "V2 layout must be exactly 230 bytes");
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

    function _open(uint256 collateralAmount, uint256 borrowAmount) internal {
        _getTokens(collateralToken, accountBase, collateralAmount);
        _execSingle(address(openHook), _morphoV2Data(collateralAmount, borrowAmount, false));
    }

    function _position() internal view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral) {
        return IMorphoStaticTyping(MORPHO).position(marketId, accountBase);
    }

    /*//////////////////////////////////////////////////////////////
                            1. OPEN EXACT
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply exact USDC collateral + borrow exact WETH; both wallet deltas are exact.
    function test_V2_Base_Open_Exact() external {
        _getTokens(collateralToken, accountBase, COLLATERAL_USDC);

        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountBase);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        _execSingle(address(openHook), _morphoV2Data(COLLATERAL_USDC, BORROW_WETH, false));

        assertEq(
            collateralBefore - IERC20(collateralToken).balanceOf(accountBase),
            COLLATERAL_USDC,
            "collateral spent must equal exact amount"
        );
        assertEq(
            IERC20(loanToken).balanceOf(accountBase) - loanBefore,
            BORROW_WETH,
            "loan token received must equal exact borrow amount"
        );

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(collateral), COLLATERAL_USDC, "position collateral == supplied");
        assertGt(uint256(borrowShares), 0, "borrow shares created");
    }

    /*//////////////////////////////////////////////////////////////
                            2. OPEN CHAINED
    //////////////////////////////////////////////////////////////*/

    /// @notice A previous hook producing the collateral token feeds the open leg via
    ///         usePrevHookAmount; the placeholder amount1 in calldata is ignored.
    function test_V2_Base_Open_Chained_UsesPrevHookOutput() external {
        _getTokens(collateralToken, accountBase, COLLATERAL_USDC);

        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountBase);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook); // position 0: publishes outToken = collateralToken, outAmount = COLLATERAL_USDC
        hooks[1] = address(openHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(collateralToken, MORPHO, COLLATERAL_USDC, false);
        data[1] = _morphoV2Data(1, BORROW_WETH, true); // amount1 = 1 wei placeholder, overridden by prev output

        _exec(hooks, data);

        assertEq(
            collateralBefore - IERC20(collateralToken).balanceOf(accountBase),
            COLLATERAL_USDC,
            "collateral spent must equal prev hook output"
        );
        assertEq(IERC20(loanToken).balanceOf(accountBase) - loanBefore, BORROW_WETH, "exact borrow received");

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(collateral), COLLATERAL_USDC, "position collateral == prev hook output");
        assertGt(uint256(borrowShares), 0, "borrow shares created");
    }

    /// @notice A previous hook producing the WRONG token (loan token instead of collateral) makes
    ///         the open leg revert with PREV_TOKEN_MISMATCH; state is unchanged.
    function test_V2_Base_Open_Chained_WrongPrevToken_Reverts() external {
        _getTokens(collateralToken, accountBase, COLLATERAL_USDC);

        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountBase);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook); // publishes outToken = loanToken — wrong for the collateral slot
        hooks[1] = address(openHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(loanToken, MORPHO, BORROW_WETH, false);
        data[1] = _morphoV2Data(1, BORROW_WETH, true);

        _execExpectUserOpRevert(hooks, data);

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(supplyShares, 0, "no supply shares");
        assertEq(uint256(borrowShares), 0, "no borrow shares");
        assertEq(uint256(collateral), 0, "no collateral");
        assertEq(IERC20(collateralToken).balanceOf(accountBase), collateralBefore, "collateral untouched");
        assertEq(IERC20(loanToken).balanceOf(accountBase), loanBefore, "loan token untouched");
    }

    /*//////////////////////////////////////////////////////////////
                           3. PARTIAL CLOSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Repay part of the debt and withdraw part of the collateral; both legs exact.
    function test_V2_Base_PartialClose_RepayAndWithdraw() external {
        _open(COLLATERAL_USDC, BORROW_WETH);

        (, uint128 borrowSharesBefore,) = _position();
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountBase);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        _execSingle(address(closeHook), _morphoV2Data(PARTIAL_REPAY_WETH, PARTIAL_WITHDRAW_USDC, false));

        assertEq(
            loanBefore - IERC20(loanToken).balanceOf(accountBase),
            PARTIAL_REPAY_WETH,
            "loan token spent must equal exact repay amount"
        );
        assertEq(
            IERC20(collateralToken).balanceOf(accountBase) - collateralBefore,
            PARTIAL_WITHDRAW_USDC,
            "collateral received must equal exact withdraw amount"
        );

        (, uint128 borrowSharesAfter, uint128 collateralAfter) = _position();
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "debt reduced");
        assertGt(uint256(borrowSharesAfter), 0, "residual debt remains");
        assertEq(
            uint256(collateralAfter), COLLATERAL_USDC - PARTIAL_WITHDRAW_USDC, "collateral reduced by exact amount"
        );
    }

    /*//////////////////////////////////////////////////////////////
                       4. FULL CLOSE AFTER ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Open, accrue 30 days of interest, then close with both max sentinels: the whole
    ///         debt is repaid by shares and the whole collateral is withdrawn.
    function test_V2_Base_FullClose_AfterAccrual() external {
        _open(COLLATERAL_USDC, BORROW_WETH);

        vm.warp(block.timestamp + 30 days);

        // Accrued interest exceeds the borrowed amount held in the wallet — top up the loan token.
        _getTokens(loanToken, accountBase, IERC20(loanToken).balanceOf(accountBase) + BORROW_WETH);

        uint256 expectedDebt = MorphoBalancesLib.expectedBorrowAssets(IMorpho(MORPHO), marketParams, accountBase);
        assertGt(expectedDebt, BORROW_WETH, "interest accrued");

        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountBase);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        _execSingle(address(closeHook), _morphoV2Data(type(uint256).max, type(uint256).max, false));

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(borrowShares), 0, "debt fully repaid");
        assertEq(uint256(collateral), 0, "collateral fully withdrawn");
        assertEq(
            IERC20(collateralToken).balanceOf(accountBase) - collateralBefore,
            COLLATERAL_USDC,
            "full collateral returned to wallet"
        );
        assertEq(loanBefore - IERC20(loanToken).balanceOf(accountBase), expectedDebt, "exact accrued debt spent");
        assertEq(IERC20(loanToken).allowance(accountBase, MORPHO), 0, "loan token allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                        5. STANDALONE REPAY PARTIAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone partial repay: exact loan-token spend, reduced borrow shares, zero
    ///         residual allowance.
    function test_V2_Base_StandaloneRepay_Partial() external {
        _open(COLLATERAL_USDC, BORROW_WETH);

        (, uint128 borrowSharesBefore,) = _position();
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        _execSingle(address(repayHook), _morphoV2Data(PARTIAL_REPAY_WETH, 0, false));

        assertEq(
            loanBefore - IERC20(loanToken).balanceOf(accountBase),
            PARTIAL_REPAY_WETH,
            "loan token spent must equal exact repay amount"
        );

        (, uint128 borrowSharesAfter, uint128 collateral) = _position();
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "borrow shares reduced");
        assertGt(uint256(borrowSharesAfter), 0, "residual debt remains");
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral untouched by repay");
        assertEq(IERC20(loanToken).allowance(accountBase, MORPHO), 0, "loan token allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                    6. STANDALONE REPAY FULL AFTER ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone full repay via the max sentinel after 30 days of accrual.
    function test_V2_Base_StandaloneRepay_Full_AfterAccrual() external {
        _open(COLLATERAL_USDC, BORROW_WETH);

        vm.warp(block.timestamp + 30 days);
        _getTokens(loanToken, accountBase, IERC20(loanToken).balanceOf(accountBase) + BORROW_WETH);

        uint256 expectedDebt = MorphoBalancesLib.expectedBorrowAssets(IMorpho(MORPHO), marketParams, accountBase);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        _execSingle(address(repayHook), _morphoV2Data(type(uint256).max, 0, false));

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(borrowShares), 0, "debt fully repaid");
        assertEq(uint256(collateral), COLLATERAL_USDC, "collateral untouched by repay");
        assertEq(loanBefore - IERC20(loanToken).balanceOf(accountBase), expectedDebt, "exact accrued debt spent");
        assertEq(IERC20(loanToken).allowance(accountBase, MORPHO), 0, "loan token allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                              7. REVERTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone repay with zero debt reverts at build() time inside the executor call
    ///         (NO_OUTSTANDING_DEBT) — fresh account, never opened a position.
    function test_V2_Base_StandaloneRepay_ZeroDebt_FreshAccount_Reverts() external {
        _getTokens(loanToken, accountBase, BORROW_WETH);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);

        _execSingleExpectUserOpRevert(address(repayHook), _morphoV2Data(PARTIAL_REPAY_WETH, 0, false));

        (, uint128 borrowShares,) = _position();
        assertEq(uint256(borrowShares), 0, "no debt");
        assertEq(IERC20(loanToken).balanceOf(accountBase), loanBefore, "loan token untouched");
    }

    /// @notice After a full close, repaying again reverts at build() time (NO_OUTSTANDING_DEBT).
    function test_V2_Base_StandaloneRepay_ZeroDebt_AfterFullClose_Reverts() external {
        _open(COLLATERAL_USDC, BORROW_WETH);
        vm.warp(block.timestamp + 30 days);
        _getTokens(loanToken, accountBase, IERC20(loanToken).balanceOf(accountBase) + BORROW_WETH);
        _execSingle(address(closeHook), _morphoV2Data(type(uint256).max, type(uint256).max, false));

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(borrowShares), 0, "position closed");
        assertEq(uint256(collateral), 0, "collateral withdrawn");

        uint256 loanBefore = IERC20(loanToken).balanceOf(accountBase);
        _execSingleExpectUserOpRevert(address(repayHook), _morphoV2Data(PARTIAL_REPAY_WETH, 0, false));
        assertEq(IERC20(loanToken).balanceOf(accountBase), loanBefore, "loan token untouched");
    }
}
