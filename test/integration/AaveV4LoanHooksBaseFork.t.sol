// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { AaveV4ReserveRegistryV2 } from "../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { AaveV4LendHook } from "../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4SupplyHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4SupplyHookV2.sol";
import { AaveV4BorrowHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4BorrowHookV2.sol";
import { AaveV4WithdrawHookV2 } from "../../src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol";
import { BaseAaveV4MoneyMarketHook } from "../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { BaseAaveV4LoanHookV2 } from "../../src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { AaveV4ReserveKey } from "../../src/libraries/AaveV4ReserveKey.sol";
import { BytesLib } from "../../src/vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { Helpers } from "../utils/Helpers.sol";
import { InternalHelpers } from "../utils/InternalHelpers.sol";

/// @title AaveV4LoanHooksBaseFork
/// @notice Header identity on a SECOND live Spoke (Base, MAG7 equities spoke, USDC reserve 7): the key is per
///         SPOKE — the Base market key differs from the Ethereum Main Spoke's key for the same pair of reserve
///         ids — and the mode partition / reserve binding hold against live MAG7 state (LOAN hooks are asserted
/// through
///         build(): MAG7's equity tokens carry opcodes this fork's EVM cannot execute, so their balance snapshots
///         cannot run here; the idle USDC lend executes end to end).
/// @dev SUP-21239: the V2 LOAN header is `computeMarketKey(spoke, supplyReserveId, borrowReserveId)`, so the
///      per-spoke statement now lives in the MARKET namespace; since SUP-21254 the idle lend carries a market key too,
///      which is also its SuperLedger key. Both are checked against the same live registry below.
contract AaveV4LoanHooksBaseFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using BytesLib for bytes;
    using ModuleKitHelpers for AccountInstance;

    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    address internal constant ETH_MAIN_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 internal constant USDC_RESERVE_ID = 7;
    uint256 internal constant EQUITY_RESERVE_ID = 0; // 8-decimal RWA equity token, used as the identity-only pair leg
    uint256 internal constant PLEDGE = 1000e6;
    bytes32 internal constant ORACLE_SALT = bytes32("AaveV4ReserveOracle");

    AccountInstance internal instanceOnBase;
    address internal accountBase;
    ISuperExecutor internal superExecutorOnBase;
    ISuperLedgerConfiguration internal ledgerConfig;
    SuperLedger internal ledger;
    ISuperNativePaymaster internal superNativePaymaster;
    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;
    bytes32 internal oracleId;
    address internal usdcKey;
    address internal equityToken;

    AaveV4LendHook internal lendHook;
    AaveV4SupplyHookV2 internal pledgeHook;
    AaveV4BorrowHookV2 internal borrowHook;
    AaveV4WithdrawHookV2 internal releaseHook;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), BASE_FORK_BLOCK);

        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        instanceOnBase = makeAccountInstance(keccak256(abi.encode("aave-loan-base-acc")));
        accountBase = instanceOnBase.account;
        superExecutorOnBase = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instanceOnBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnBase), data: ""
        });
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorOnBase);
        ledger = new SuperLedger(address(ledgerConfig), allowedExecutors);

        registry = new AaveV4ReserveRegistryV2(address(this));
        (usdcKey,) = registry.registerReserve(MAG7_SPOKE, USDC_RESERVE_ID);
        // the equity reserve's legs are needed too: `registerMarket` requires the loan reserve's DEBT leg
        registry.registerReserve(MAG7_SPOKE, EQUITY_RESERVE_ID);
        // SUP-21254: the idle header is a market key and the ledger read resolves it through the oracle,
        // which reverts for an unregistered market — so the idle pair's market must exist up front. Its
        // SUPPLY leg is the USDC reserve the idle ops here move.
        registry.registerMarket(MAG7_SPOKE, USDC_RESERVE_ID, EQUITY_RESERVE_ID);
        oracle = new AaveV4ReserveOracle(address(ledgerConfig), address(registry));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 0,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_SALT;
        ledgerConfig.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(ORACLE_SALT, address(this));

        equityToken = IAaveV4Spoke(MAG7_SPOKE).getReserve(EQUITY_RESERVE_ID).underlying;
        lendHook = new AaveV4LendHook();
        pledgeHook = new AaveV4SupplyHookV2();
        borrowHook = new AaveV4BorrowHookV2();
        releaseHook = new AaveV4WithdrawHookV2();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(CHAIN_8453_USDC, accountBase, 10_000e6);
    }

    receive() external payable { }

    /// @dev LOAN layout on MAG7: collateral = USDC (reserve 7), loan = equity (reserve 0, identity only); header
    ///      is the MARKET key of that pair on this spoke (SUP-21239) — the same key for every leg of the market
    function _loanData(uint256 a1, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(
            oracleId,
            AaveV4ReserveKey.computeMarketKey(MAG7_SPOKE, USDC_RESERVE_ID, EQUITY_RESERVE_ID),
            equityToken,
            CHAIN_8453_USDC,
            MAG7_SPOKE,
            USDC_RESERVE_ID,
            EQUITY_RESERVE_ID,
            a1,
            uint256(0),
            usePrev
        );
    }

    function _idleData(uint256 amount) internal view returns (bytes memory) {
        // SUP-21254: market key whose SUPPLY leg is the USDC reserve this idle op moves
        uint256 borrowLeg = EQUITY_RESERVE_ID;
        return abi.encodePacked(
            oracleId,
            AaveV4ReserveKey.computeMarketKey(MAG7_SPOKE, USDC_RESERVE_ID, borrowLeg),
            CHAIN_8453_USDC,
            MAG7_SPOKE,
            USDC_RESERVE_ID,
            amount,
            false,
            borrowLeg
        );
    }

    function _execute(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _executeExpectFailure(address hook, bytes memory data, bytes4 expectedSelector) internal {
        ExecutionReturnData memory ret = _execute(hook, data);
        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length && !found; ++i) {
            VmSafe.Log memory log = ret.logs[i];
            if (log.topics.length == 0 || log.topics[0] != revertTopic) continue;
            bytes memory blob = log.data;
            for (uint256 j; j + 4 <= blob.length; ++j) {
                if (
                    blob[j] == expectedSelector[0] && blob[j + 1] == expectedSelector[1]
                        && blob[j + 2] == expectedSelector[2] && blob[j + 3] == expectedSelector[3]
                ) {
                    found = true;
                    break;
                }
            }
        }
        assertTrue(found, "expected UserOperationRevertReason with the given selector");
    }

    function _supplied() internal view returns (uint256) {
        return IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_RESERVE_ID, accountBase);
    }

    function _flag() internal view returns (bool f) {
        (f,) = IAaveV4Spoke(MAG7_SPOKE).getUserReserveStatus(USDC_RESERVE_ID, accountBase);
    }

    /// @notice The MARKET key is per spoke: the Base MAG7 (USDC collateral, equity loan) key resolves through
    ///         this registry's MARKET namespace to the MAG7 spoke and both live underlyings, and differs from
    ///         the Ethereum Main Spoke's key for the SAME pair of reserve ids. It is also none of the four leg
    ///         keys of the two reserves, so the NAV namespace on this spoke stays untouched.
    function test_Base_HeaderKey_IsPerSpoke_ResolvesThroughRegistry() external {
        address marketKey = registry.computeMarketKey(MAG7_SPOKE, USDC_RESERVE_ID, EQUITY_RESERVE_ID);
        assertTrue(registry.isMarketRegistered(marketKey), "registered in setUp for the idle pair");
        bytes memory id = pledgeHook.inspect(_loanData(PLEDGE, false));
        address key = id.toAddress(0);
        assertEq(key, marketKey, "inspect key == the registered Base market key");
        assertTrue(registry.isMarketRegistered(key), "resolves in the MARKET namespace");
        assertFalse(registry.isRegistered(key), "and never as a reserve leg");
        assertTrue(key != usdcKey, "not the collateral reserve's SUPPLY key");
        assertTrue(key != registry.computeDebtKey(MAG7_SPOKE, USDC_RESERVE_ID), "not its DEBT key");
        assertTrue(key != registry.computeReserveKey(MAG7_SPOKE, EQUITY_RESERVE_ID), "not the loan SUPPLY key");
        assertTrue(key != registry.computeDebtKey(MAG7_SPOKE, EQUITY_RESERVE_ID), "not the loan DEBT key");
        _assertBaseMarketBinding(marketKey);
        assertTrue(
            key != AaveV4ReserveKey.computeMarketKey(ETH_MAIN_SPOKE, USDC_RESERVE_ID, EQUITY_RESERVE_ID),
            "same reserve ids, different spoke, different market key"
        );
        assertEq(id.length, 144);
    }

    /// @dev The Base market's binding, read from the live MAG7 spoke. Factored out so the five-value
    ///      `getMarketInfo` destructuring does not blow the (non-via-ir) stack frame.
    function _assertBaseMarketBinding(address marketKey) internal view {
        (address spoke, uint256 supplyId, uint256 borrowId, address collateralToken, address loanToken) =
            registry.getMarketInfo(marketKey);
        assertEq(spoke, MAG7_SPOKE, "live MAG7 spoke");
        assertEq(supplyId, USDC_RESERVE_ID, "collateral reserve id");
        assertEq(borrowId, EQUITY_RESERVE_ID, "loan reserve id");
        assertEq(collateralToken, CHAIN_8453_USDC, "collateral underlying read from the live spoke");
        assertEq(loanToken, equityToken, "loan underlying read from the live spoke");
    }

    /// @notice Mode partition on the second live Spoke. The equity tokens listed on MAG7 carry opcodes this fork's EVM
    ///         does not execute, so a LOAN hook cannot be *executed* here (its balance snapshot reads the equity leg);
    ///         build() is a view over live Spoke state and never touches balances, so it proves the guards: with no
    ///         position PLEDGE builds its 7 executions against MAG7; after an executed idle LEND of USDC (the idle hook
    ///         only touches USDC) PLEDGE is refused (RESERVE_HAS_IDLE_POSITION) and RELEASE is refused
    ///         (RESERVE_NOT_COLLATERAL) on the live MAG7 state
    function test_Base_ModePartition_MAG7_Usdc_LiveState() external {
        Execution[] memory ex = pledgeHook.build(address(0), accountBase, _loanData(PLEDGE, false));
        assertEq(ex.length, 7, "fresh reserve: full pledge shape");
        for (uint256 i = 1; i + 1 < ex.length; ++i) {
            assertTrue(ex[i].target == MAG7_SPOKE || ex[i].target == CHAIN_8453_USDC, "MAG7 or USDC only");
        }
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector); // empty position
        releaseHook.build(address(0), accountBase, _loanData(type(uint256).max, false));

        uint256 before = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);
        _execute(address(lendHook), _idleData(PLEDGE));
        assertEq(before - IERC20(CHAIN_8453_USDC).balanceOf(accountBase), PLEDGE, "idle lend executed on MAG7");
        assertFalse(_flag(), "idle: un-flagged");
        // SUP-21254: the ledger key is the idle header, i.e. the MARKET key whose SUPPLY leg is this
        // reserve — not the reserve key. The oracle resolves the two to the same leg, which is why the
        // accumulator equals the live supplied amount.
        address idleMarketKey = registry.computeMarketKey(MAG7_SPOKE, USDC_RESERVE_ID, EQUITY_RESERVE_ID);
        assertEq(ledger.usersAccumulatorShares(accountBase, idleMarketKey), _supplied(), "ledger keyed by the market");
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcKey), 0, "and never by the reserve key");
        assertEq(
            oracle.getBalanceOfOwner(idleMarketKey, accountBase),
            oracle.getBalanceOfOwner(usdcKey, accountBase),
            "both keys read the same leg"
        );

        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_HAS_IDLE_POSITION.selector);
        pledgeHook.build(address(0), accountBase, _loanData(PLEDGE, false));
        vm.expectRevert(BaseAaveV4LoanHookV2.RESERVE_NOT_COLLATERAL.selector);
        releaseHook.build(address(0), accountBase, _loanData(type(uint256).max, false));
        // the borrow-side identity binding runs against the live MAG7 reserves too
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        borrowHook.build(
            address(0),
            accountBase,
            abi.encodePacked(
                oracleId,
                AaveV4ReserveKey.computeMarketKey(MAG7_SPOKE, EQUITY_RESERVE_ID, EQUITY_RESERVE_ID),
                CHAIN_8453_USDC, // wrong: reserve 0's underlying is the equity token
                equityToken,
                MAG7_SPOKE,
                EQUITY_RESERVE_ID,
                EQUITY_RESERVE_ID,
                uint256(1e8),
                uint256(0),
                false
            )
        );
    }

    /// @notice On the second live spoke too, a header naming anything but THIS spoke's market is refused before
    ///         any Spoke call: the Ethereum Main Spoke's market key for the same pair of reserve ids, the
    ///         reversed pair on MAG7 itself, and either leg's OLD per-reserve key (the SUP-21143 header, which
    ///         is the fail-closed migration case) all revert `MARKET_KEY_MISMATCH` with nothing supplied and
    ///         the collateral flag untouched.
    function test_Base_WrongSpokeKey_Refused() external {
        bytes memory body = BytesLib.slice(_loanData(PLEDGE, false), 52, 189);
        address[4] memory wrongKeys = [
            AaveV4ReserveKey.computeMarketKey(ETH_MAIN_SPOKE, USDC_RESERVE_ID, EQUITY_RESERVE_ID),
            AaveV4ReserveKey.computeMarketKey(MAG7_SPOKE, EQUITY_RESERVE_ID, USDC_RESERVE_ID),
            AaveV4ReserveKey.computeReserveKey(MAG7_SPOKE, USDC_RESERVE_ID),
            AaveV4ReserveKey.computeDebtKey(MAG7_SPOKE, EQUITY_RESERVE_ID)
        ];
        for (uint256 w; w < wrongKeys.length; ++w) {
            _executeExpectFailure(
                address(pledgeHook),
                abi.encodePacked(oracleId, wrongKeys[w], body),
                AaveV4ReserveKey.MARKET_KEY_MISMATCH.selector
            );
            assertEq(_supplied(), 0);
            assertFalse(_flag());
        }
    }
}
