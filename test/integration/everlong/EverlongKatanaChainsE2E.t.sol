// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { SwapEverlongHook } from "../../../src/hooks/swappers/everlong/SwapEverlongHook.sol";
import { ApproveAndSwapEverlongHook } from "../../../src/hooks/swappers/everlong/ApproveAndSwapEverlongHook.sol";
import { SwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/SwapSushiSwapHook.sol";
import { ApproveAndSwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/ApproveAndSwapSushiSwapHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../../../src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { EverlongKatanaFixtures } from "./EverlongKatanaFixtures.sol";
import { SushiKatanaFixtures } from "../sushiswap/SushiKatanaFixtures.sol";

/// @dev Both fixture mixins declare the shared Katana constants; this shim re-exports the Sushi samples under
///      distinct names so one test can hold both aggregators' calldata.
abstract contract SushiSamples is SushiKatanaFixtures {
    function _sushiUsdcKat(address account) internal pure returns (bytes memory) {
        return _withRecipient(TX_USDC_KAT, account);
    }

    function _sushiNativeIn(address account) internal pure returns (bytes memory) {
        return _withRecipient(TX_NATIVE_IN_USDC, account);
    }
}

/// @title EverlongKatanaChainsE2E
/// @author Superform Labs
/// @notice Multi-hook chains on REAL Katana liquidity at the pinned block, every downstream hook sized by
///         `usePrevHookAmount` from the real output of the previous one:
///           - Sushi -> Everlong round trip (vbUSDC -> KAT via RedSnwapper, KAT -> vbUSDC via the Everlong router)
///           - Everlong -> Sushi round trip (vbUSDC -> native via Everlong, native -> vbUSDC via Sushi)
///           - Everlong -> Everlong on the SAME hook instance (the adjacency case that was a HIGH review finding)
///           - the product flow: swap on Everlong, then deposit the real output into an ERC-4626 vault through the
///             accounting executor (ledger configured, inflow recorded)
/// @dev Runs against KATANA_RPC_URL (default public RPC); skips without connectivity; excluded from `ftest-ci`.
contract EverlongKatanaChainsE2E is Helpers, RhinestoneModuleKit, InternalHelpers, EverlongKatanaFixtures {
    using ModuleKitHelpers for *;

    // Sushi live venue (same addresses as SushiKatanaFixtures)
    address internal constant SUSHI_RED_SNWAPPER = 0xAC4c6e212A361c968F1725b4d055b47E63F80b75;
    address internal constant SUSHI_ROUTE_PROCESSOR = 0xC10eE9031F2a0B84766A86B55a8D90F357910fb4;
    uint256 internal constant SUSHI_USDC_KAT_IN = 100_000_000;
    uint256 internal constant SUSHI_USDC_KAT_OUT = 30_932_333_548_926_897_487_872;
    uint256 internal constant SUSHI_USDC_KAT_MIN = 30_777_671_881_182_263_000_432;
    uint256 internal constant SUSHI_NATIVE_USDC_IN = 1e18;
    uint256 internal constant SUSHI_NATIVE_USDC_OUT = 2_038_313_022;
    uint256 internal constant SUSHI_NATIVE_USDC_MIN = 2_028_121_456;

    SushiSamplesHolder internal sushi;

    SwapEverlongHook internal everSwap;
    ApproveAndSwapEverlongHook internal everApprove;
    SwapSushiSwapHook internal sushiSwap;
    ApproveAndSwapSushiSwapHook internal sushiApprove;
    ApproveAndDeposit4626VaultHook internal depositHook;

    ISuperLedgerConfiguration internal ledgerConfig;
    ISuperLedger internal ledger;
    ERC4626YieldSourceOracle internal oracle;
    Mock4626Vault internal vault;

    AccountInstance internal instance;
    address internal account;
    ISuperExecutor internal superExecutor;
    bool internal forked;

    receive() external payable { }

    function setUp() public {
        string memory rpc = envOr("KATANA_RPC_URL", "https://rpc.katana.network");
        if (bytes(rpc).length == 0) return;
        try vm.createSelectFork(rpc, KATANA_BLOCK) {
            forked = true;
        } catch {
            return;
        }

        sushi = new SushiSamplesHolder();

        // accounting stack: ledger configuration + ERC-4626 oracle + ledger, the executor bound to the configuration
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        oracle = new ERC4626YieldSourceOracle(address(ledgerConfig));
        superExecutor = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutor);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        ledgerConfig.setYieldSourceOracles(salts, configs);

        everSwap = new SwapEverlongHook(EVERLONG_ROUTER, WETH9, NATIVE);
        everApprove = new ApproveAndSwapEverlongHook(EVERLONG_ROUTER, WETH9, NATIVE);
        sushiSwap = new SwapSushiSwapHook(SUSHI_RED_SNWAPPER, SUSHI_ROUTE_PROCESSOR, NATIVE);
        sushiApprove = new ApproveAndSwapSushiSwapHook(SUSHI_RED_SNWAPPER, SUSHI_ROUTE_PROCESSOR, NATIVE);
        depositHook = new ApproveAndDeposit4626VaultHook();
        vault = new Mock4626Vault(VB_USDC, "Katana vbUSDC Vault", "kvbUSDC");

        instance = makeAccountInstance(keccak256("everlong-katana-chains"));
        account = instance.account;
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        deal(VB_USDC, account, 1_000_000e6);
        deal(KAT, account, 1_000_000e18);
        vm.deal(account, 100 ether);
        instance.aux.entrypoint.depositTo{ value: 10 ether }(account); // exact native deltas
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-AGGREGATOR ROUND TRIPS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sushi (vbUSDC -> KAT, flag off) feeds Everlong (KAT -> vbUSDC, flag ON). Sushi delivers ~30,930 KAT
    ///         against Everlong's 30,000 KAT quote, so the 4 Everlong legs are rescaled to ~103% and their sum equals
    ///         Sushi's real output exactly: no KAT is left behind.
    function test_Chain_SushiToEverlong_RoundTrip_SecondSizedFromFirst() public {
        _requireFork();
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        uint256 katBefore = IERC20(KAT).balanceOf(account);
        uint256 feeBefore = IERC20(VB_USDC).balanceOf(FEE_RECIPIENT);

        bytes memory first = _hookData(
            VB_USDC, KAT, SUSHI_USDC_KAT_IN, SUSHI_USDC_KAT_OUT, SUSHI_USDC_KAT_MIN, false, sushi.usdcKat(account)
        );
        bytes memory second = _hookData(
            KAT,
            VB_USDC,
            QUOTE_KAT_USDC_IN,
            QUOTE_KAT_USDC_OUT,
            HEADER_MIN_KAT_USDC,
            true,
            _withRecipient(TX_KAT_USDC, TAIL_RECIPIENT_OFFSET_KAT_USDC, account)
        );
        executeOp(_op2(address(sushiApprove), first, address(everApprove), second));

        assertEq(IERC20(KAT).balanceOf(account), katBefore, "every KAT Sushi produced went into Everlong");
        uint256 usdcAfter = IERC20(VB_USDC).balanceOf(account);
        assertLe(usdcBefore - usdcAfter, SUSHI_USDC_KAT_IN * 3 / 100, "round trip cost within two spreads + fees");
        uint256 fee = IERC20(VB_USDC).balanceOf(FEE_RECIPIENT) - feeBefore;
        uint256 everlongOut = usdcAfter + SUSHI_USDC_KAT_IN - usdcBefore; // vbUSDC produced by the Everlong leg
        assertEq(fee, (everlongOut + fee) * FEE_BIPS / 10_000, "4 bps fee identity on the rescaled second leg");
        uint256 katFromSushi = SUSHI_USDC_KAT_OUT; // the cap binds at the pinned block (Sushi suite)
        assertGe(
            everlongOut,
            Math.mulDiv(HEADER_MIN_KAT_USDC, katFromSushi, QUOTE_KAT_USDC_IN, Math.Rounding.Ceil),
            "scaled floor"
        );
        assertEq(IERC20(KAT).allowance(account, EVERLONG_ROUTER), 0);
        assertEq(IERC20(VB_USDC).allowance(account, SUSHI_RED_SNWAPPER), 0);
    }

    /// @notice Everlong (vbUSDC -> native, flag off) feeds Sushi (native -> vbUSDC, flag ON). Everlong delivers
    ///         ~0.0488 ETH against Sushi's 1 ETH quote: Sushi's nested cap and outer floor are rescaled to ~4.9%.
    function test_Chain_EverlongToSushi_RoundTrip_SecondSizedFromFirst() public {
        _requireFork();
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        uint256 ethBefore = account.balance;

        bytes memory first = _hookData(
            VB_USDC,
            NATIVE,
            QUOTE_USDC_NATIVE_IN,
            QUOTE_USDC_NATIVE_OUT,
            HEADER_MIN_USDC_NATIVE,
            false,
            _withRecipient(TX_USDC_NATIVE_OUT, TAIL_RECIPIENT_OFFSET_USDC_NATIVE, account)
        );
        bytes memory second = _hookData(
            NATIVE,
            VB_USDC,
            SUSHI_NATIVE_USDC_IN,
            SUSHI_NATIVE_USDC_OUT,
            SUSHI_NATIVE_USDC_MIN,
            true,
            sushi.nativeIn(account)
        );
        executeOp(_op2(address(everApprove), first, address(sushiSwap), second));

        assertEq(account.balance, ethBefore, "Sushi consumed exactly Everlong's native output");
        uint256 usdcAfter = IERC20(VB_USDC).balanceOf(account);
        assertLe(usdcBefore - usdcAfter, QUOTE_USDC_NATIVE_IN * 3 / 100, "round trip cost within two spreads + fees");
    }

    /// @notice Everlong feeds the SAME Everlong instance on live liquidity: vbUSDC -> KAT (flag off) then KAT -> vbUSDC
    ///         (flag on, sized from the first leg's real post-fee output). This is the same-address adjacency the
    ///         review flagged; the transient pin makes the second leg's floor real and scaled.
    function test_Chain_EverlongFeedsEverlong_SameInstance_LiveLiquidity() public {
        _requireFork();
        uint256 katBefore = IERC20(KAT).balanceOf(account);
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        bytes memory first = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            HEADER_MIN_USDC_KAT,
            false,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)
        );
        bytes memory second = _hookData(
            KAT,
            VB_USDC,
            QUOTE_KAT_USDC_IN,
            QUOTE_KAT_USDC_OUT,
            HEADER_MIN_KAT_USDC,
            true,
            _withRecipient(TX_KAT_USDC, TAIL_RECIPIENT_OFFSET_KAT_USDC, account)
        );
        executeOp(_op2(address(everApprove), first, address(everApprove), second));
        assertEq(IERC20(KAT).balanceOf(account), katBefore, "second leg consumed exactly the first leg's output");
        assertLe(
            usdcBefore - IERC20(VB_USDC).balanceOf(account), QUOTE_USDC_KAT_IN * 3 / 100, "round trip cost bounded"
        );
    }

    /// @notice Same chain with a header min on the second leg that its scaled floor cannot clear: the whole op reverts
    ///         atomically (first leg undone too) — the adjacent floor is enforced, not vacuous.
    function test_Chain_EverlongFeedsEverlong_SameInstance_TightSecondFloor_Reverts() public {
        _requireFork();
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        bytes memory first = _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            HEADER_MIN_USDC_KAT,
            false,
            _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account)
        );
        bytes memory second = _hookData(
            KAT,
            VB_USDC,
            QUOTE_KAT_USDC_IN,
            QUOTE_KAT_USDC_OUT,
            QUOTE_KAT_USDC_OUT * 2, // unreachable even after the ~103% upsize
            true,
            _withRecipient(TX_KAT_USDC, TAIL_RECIPIENT_OFFSET_KAT_USDC, account)
        );
        instance.expect4337Revert(ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector);
        executeOp(_op2(address(everApprove), first, address(everApprove), second));
        assertEq(IERC20(VB_USDC).balanceOf(account), usdcBefore, "first leg rolled back with the op");
    }

    /*//////////////////////////////////////////////////////////////
                      THE PRODUCT FLOW: SWAP THEN DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap KAT -> vbUSDC on Everlong, then deposit the REAL output into an ERC-4626 vault through the
    ///         accounting executor: the deposit hook reads the swap's outAmount/outToken, the vault receives exactly
    /// the post-fee swap output, and the ledger records the inflow.
    function test_Chain_SwapThenDeposit4626_AccountingRecorded() public {
        _requireFork();
        bytes32 oracleId = _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this));
        uint256 usdcBefore = IERC20(VB_USDC).balanceOf(account);
        uint256 katBefore = IERC20(KAT).balanceOf(account);

        bytes memory swap = _hookData(
            KAT,
            VB_USDC,
            QUOTE_KAT_USDC_IN,
            QUOTE_KAT_USDC_OUT,
            HEADER_MIN_KAT_USDC,
            false,
            _withRecipient(TX_KAT_USDC, TAIL_RECIPIENT_OFFSET_KAT_USDC, account)
        );
        // the deposit amount in the header is a placeholder; usePrevHookAmount sizes it from the swap's output
        bytes memory deposit =
            _createApproveAndDeposit4626HookData(oracleId, address(vault), VB_USDC, 1, true, address(0), 0);
        executeOp(_op2(address(everApprove), swap, address(depositHook), deposit));

        assertEq(katBefore - IERC20(KAT).balanceOf(account), QUOTE_KAT_USDC_IN, "swap input spent");
        assertEq(IERC20(VB_USDC).balanceOf(account), usdcBefore, "all swap output went into the vault");
        uint256 deposited = IERC4626(address(vault)).totalAssets();
        assertGe(deposited, HEADER_MIN_KAT_USDC, "vault holds the post-fee swap output");
        assertEq(IERC4626(address(vault)).balanceOf(account), deposited, "1:1 shares on a fresh vault");
        assertEq(IERC20(VB_USDC).allowance(account, address(vault)), 0, "deposit approval reset");
        assertEq(IERC20(KAT).allowance(account, EVERLONG_ROUTER), 0, "swap approval reset");
        assertEq(IERC20(VB_USDC).balanceOf(address(vault)), deposited, "vault really holds the assets");
        // the ledger recorded the inflow: cost basis of the minted shares equals the deposited assets (pps 1e18)
        (uint256 costBasis,) = ledger.calculateCostBasisView(account, address(vault), deposited);
        assertEq(costBasis, deposited, "ledger cost basis == swap output deposited");
        assertEq(oracle.getPricePerShare(address(vault)), 1e18, "fresh vault pps");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _op2(
        address hookA,
        bytes memory dataA,
        address hookB,
        bytes memory dataB
    )
        internal
        returns (UserOpData memory)
    {
        address[] memory hooks = new address[](2);
        hooks[0] = hookA;
        hooks[1] = hookB;
        bytes[] memory datas = new bytes[](2);
        datas[0] = dataA;
        datas[1] = dataB;
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas }))
        );
    }
}

/// @dev Separate contract (not a mixin) because both fixture sets declare identical constant names; it just serves
///      the Sushi samples with the recipient rewritten.
contract SushiSamplesHolder is SushiSamples {
    function usdcKat(address account) external pure returns (bytes memory) {
        return _sushiUsdcKat(account);
    }

    function nativeIn(address account) external pure returns (bytes memory) {
        return _sushiNativeIn(account);
    }
}
