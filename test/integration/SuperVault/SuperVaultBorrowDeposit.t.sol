// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IMorphoBase } from "../../../src/vendor/morpho/IMorpho.sol";
import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract SuperVaultBorrowDepositTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public morpho;
    address public oracle;
    address public irm;
    address public loanToken;
    address public collateralToken;

    uint256 public lltv;
    uint256 public amount;
    uint256 public constant PRECISION = 1e18;

    ISuperExecutor public superExecutorOnETH;

    function setUp() public override {
        super.setUp();

        amount = 1000e6;
  
        vm.selectFork(FORKS[ETH]);
        
        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];
        vm.label(accountEth, "AccountETH");

        // Set up tokens
        collateralToken = existingUnderlyingTokens[ETH][WST_ETH_KEY];
        vm.label(collateralToken, "CollateralToken");
        _getTokens(CHAIN_1_WST_ETH, accountEth, 3e18);
        loanToken = existingUnderlyingTokens[ETH][USDC_KEY];
        vm.label(loanToken, "LoanToken");

        // Set up morpho
        lltv = 860000000000000000;
        morpho = MORPHO;
        vm.label(morpho, "Morpho");
        irm = MORPHO_IRM;
        vm.label(irm, "MorphoIRM");
        oracle = MORPHO_ORACLE;
        vm.label(oracle, "MorphoOracle");

        // Set up super vault
        vm.startPrank(SV_MANAGER);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault Morpho-Fluid",
                symbol: "svMorphoFluid",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                superVaultCap: SUPER_VAULT_CAP
            })
        );
        vm.label(vaultAddr, "MorphoFluidSuperVault");
        vm.label(strategyAddr, "MorphoFluidSuperVaultStrategy");
        vm.label(escrowAddr, "MorphoFluidSuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        escrow = SuperVaultEscrow(escrowAddr);
        strategy = SuperVaultStrategy(strategyAddr);

        // Add a new yield source as manager
        strategy.manageYieldSource(
            address(fluidVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        vm.stopPrank();

        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(_getMerkleRoot());
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));

        strategy.proposeVaultFeeConfigUpdate(100, TREASURY);
        vm.warp(block.timestamp + 1 weeks);
        strategy.executeVaultFeeConfigUpdate();
        vm.stopPrank();
        
        // Set up yield source oracle
        vm.startPrank(MANAGER);
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: TREASURY,
            ledger: _getContract(ETH, SUPER_LEDGER_KEY)
        });
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(configs);
        vm.stopPrank();

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
    }

    function test_BorrowHook() public {
        address hook = _getHookAddress(ETH, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountEth);
        console2.log("loanBalanceBefore", loanBalanceBefore);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountEth);
        console2.log("collateralBalanceBefore", collateralBalanceBefore);

        bytes memory hookData = _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false);
        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(userOpData);

        uint256 loanBalanceAfter = IERC20(loanToken).balanceOf(accountEth);
        console2.log("loanBalanceAfter", loanBalanceAfter);
        uint256 collateralBalanceAfter = IERC20(collateralToken).balanceOf(accountEth);
        console2.log("collateralBalanceAfter", collateralBalanceAfter);
    }
    
}