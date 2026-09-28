// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { AaveV4ReserveRegistry } from "../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { AaveV4LendHook } from "../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { Helpers } from "../utils/Helpers.sol";
import { InternalHelpers } from "../utils/InternalHelpers.sol";

/// @title AaveV4IdleHooksBaseFork
/// @notice SUP-21142 E2E on Base: idle lend / redeem of USDC (reserve 7) on the MAG7 equities spoke
///         through a real SuperExecutor + SuperLedger stack. The equity reserves (ids 0-6) are
///         node-native tokens and are deliberately not touched; USDC is a normal ERC-20.
contract AaveV4IdleHooksBaseFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    uint256 internal constant USDC_RESERVE_ID = 7;
    uint256 internal constant LEND = 1000e6;
    bytes32 internal constant ORACLE_SALT = bytes32("AaveV4SupplyYieldSourceOracle");
    bytes32 internal constant COLLATERAL_EVENT = keccak256("SetUsingAsCollateral(uint256,address,address,bool)");

    address public accountBase;
    AccountInstance public instanceOnBase;
    ISuperExecutor public superExecutorOnBase;
    ISuperLedgerConfiguration public ledgerConfig;
    SuperLedger public ledger;
    ISuperNativePaymaster public superNativePaymaster;
    AaveV4ReserveRegistry public registry;
    AaveV4SupplyYieldSourceOracle public oracle;
    AaveV4LendHook public lendHook;
    AaveV4RedeemHook public redeemHook;
    address public usdcKey;
    bytes32 public oracleId;
    address public feeRecipient;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY), BASE_FORK_BLOCK);

        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        instanceOnBase = makeAccountInstance(keccak256(abi.encode("aave-idle-base-acc")));
        accountBase = instanceOnBase.account;
        superExecutorOnBase = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instanceOnBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnBase), data: ""
        });
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorOnBase);
        ledger = new SuperLedger(address(ledgerConfig), allowedExecutors);

        registry = new AaveV4ReserveRegistry(address(this));
        usdcKey = registry.registerReserve(MAG7_SPOKE, USDC_RESERVE_ID);
        oracle = new AaveV4SupplyYieldSourceOracle(address(ledgerConfig), address(registry));
        feeRecipient = makeAddr("feeRecipient");

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle), feePercent: 0, feeRecipient: feeRecipient, ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_SALT;
        ledgerConfig.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(ORACLE_SALT, address(this));

        lendHook = new AaveV4LendHook();
        redeemHook = new AaveV4RedeemHook();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(CHAIN_8453_USDC, accountBase, 10_000e6);
    }

    receive() external payable { }

    function _data(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(oracleId, usdcKey, CHAIN_8453_USDC, MAG7_SPOKE, USDC_RESERVE_ID, amount, usePrev);
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

    function _isCollateral() internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(MAG7_SPOKE).getUserReserveStatus(USDC_RESERVE_ID, accountBase);
    }

    function _supplied() internal view returns (uint256) {
        return IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(USDC_RESERVE_ID, accountBase);
    }

    function _collateralEventCount(ExecutionReturnData memory ret) internal pure returns (uint256 n) {
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == COLLATERAL_EVENT) ++n;
        }
    }

    function test_Base_Lend_SupplyOnly_CollateralFlagNotFlipped() public {
        assertFalse(_isCollateral());
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        ExecutionReturnData memory ret = _execute(address(lendHook), _data(LEND, false));

        assertFalse(_isCollateral(), "supply-only: collateral bit untouched");
        assertEq(_collateralEventCount(ret), 0);
        assertEq(walletBefore - IERC20(CHAIN_8453_USDC).balanceOf(accountBase), LEND);
        uint256 credited = _supplied();
        assertLe(LEND - credited, 1);
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcKey), credited, "keyed by reserve key");
        assertEq(ledger.usersAccumulatorShares(accountBase, MAG7_SPOKE), 0, "never by the spoke");
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountBase), credited);
    }

    function test_Base_Lend_Then_RedeemFull_LedgerNets() public {
        _execute(address(lendHook), _data(LEND, false));
        uint256 credited = _supplied();
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        _execute(address(redeemHook), _data(type(uint256).max, false));

        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(accountBase) - walletBefore, credited);
        assertEq(_supplied(), 0);
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcKey), 0);
        assertEq(ledger.usersAccumulatorCostBasis(accountBase, usdcKey), 0);
        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(feeRecipient), 0, "feePercent 0");
    }

    function test_Base_Lend_Then_RedeemPartial() public {
        _execute(address(lendHook), _data(LEND, false));
        uint256 credited = _supplied();
        uint256 walletBefore = IERC20(CHAIN_8453_USDC).balanceOf(accountBase);

        _execute(address(redeemHook), _data(250e6, false));

        assertEq(IERC20(CHAIN_8453_USDC).balanceOf(accountBase) - walletBefore, 250e6, "exact receipt");
        assertApproxEqAbs(_supplied(), credited - 250e6, 1);
        assertEq(ledger.usersAccumulatorShares(accountBase, usdcKey), _supplied());
    }
}
