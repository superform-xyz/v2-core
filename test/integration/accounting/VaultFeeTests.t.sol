// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

// Hooks
import { RequestDeposit7540VaultHook } from "../../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { Deposit7540VaultHook } from "../../../src/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { Deposit5115VaultHook } from "../../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../../../src/hooks/vaults/5115/Redeem5115VaultHook.sol";

contract VaultFeeTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    IStandardizedYield public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540;
    IERC4626 public vaultInstance4626;

    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public yieldSource4626AddressUSDC;
    address public yieldSource7540AddressUSDC;
    address public yieldSource5115AddressSUSDe;

    address public accountEth;
    AccountInstance public instanceOnEth;

    SuperLedger public superLedger;
    SuperLedgerConfiguration public config;

    SuperExecutor public superExecutor;
    ISuperExecutor public superExecutorInterface;

    ERC4626YieldSourceOracle public oracle4626;
    ERC5115YieldSourceOracle public oracle5115;
    ERC7540YieldSourceOracle public oracle7540;
    
    address public manager;
    address public feeRecipient;

    bytes32 public yieldSourceOracleId4626;
    bytes32 public yieldSourceOracleId5115;
    bytes32 public yieldSourceOracleId7540;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        instanceOnEth = accountInstances[ETH];
        accountEth = instanceOnEth.account;

        underlyingETH_USDC = CHAIN_1_USDC;
        underlyingETH_sUSDe = CHAIN_1_SUSDE;

        _getTokens(underlyingETH_USDC, accountEth, 1e18);
        _getTokens(underlyingETH_sUSDe, accountEth, 1e18);

        yieldSource4626AddressUSDC = CHAIN_1_MorphoVault;
        vaultInstance4626 = IERC4626(yieldSource4626AddressUSDC);

        yieldSource7540AddressUSDC = CHAIN_1_CentrifugeUSDC;
        vaultInstance7540 = IERC7540(yieldSource7540AddressUSDC);

        yieldSource5115AddressSUSDe = CHAIN_1_PendleEthena;
        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);

        config = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(config));
        superExecutorInterface = ISuperExecutor(address(superExecutor));

        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor);

        superLedger = new SuperLedger(address(config), executors);

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        oracle4626 = new ERC4626YieldSourceOracle(address(superLedger));
        oracle5115 = new ERC5115YieldSourceOracle(address(superLedger));
        oracle7540 = new ERC7540YieldSourceOracle(address(superLedger));

        feeRecipient = makeAddr("feeRecipient");
        manager = makeAddr("manager");

        bytes32[] memory yieldSourceOracleSalts = new bytes32[](3);
        yieldSourceOracleSalts[0] = bytes32(keccak256("4626_ORACLE_ID"));
        yieldSourceOracleSalts[1] = bytes32(keccak256("5115_ORACLE_ID"));
        yieldSourceOracleSalts[2] = bytes32(keccak256("7540_ORACLE_ID"));

        yieldSourceOracleId4626 = keccak256(abi.encodePacked(yieldSourceOracleSalts[0], manager));
        yieldSourceOracleId5115 = keccak256(abi.encodePacked(yieldSourceOracleSalts[1], manager));
        yieldSourceOracleId7540 = keccak256(abi.encodePacked(yieldSourceOracleSalts[2], manager));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](3);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle4626),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle5115),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({  
            yieldSourceOracle: address(oracle7540),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });

        // Set the oracle configs
        vm.prank(manager);
        config.setYieldSourceOracles(yieldSourceOracleSalts, configs);
    }

    function test_4626VaultFees() public { }

    function test_5115VaultFees() public { }

    function test_7540VaultFees() public { }
}
