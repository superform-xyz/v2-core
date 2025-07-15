// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";

// Superform
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { MockExecutorModule } from "../../mocks/MockExecutorModule.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

// Hooks
import { RequestDeposit7540VaultHook } from "../../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { Deposit5115VaultHook } from "../../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../../../src/hooks/vaults/5115/Redeem5115VaultHook.sol";

contract VaultFeeTests is MinimalBaseIntegrationTest {
    IStandardizedYield public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540;
    IERC4626 public vaultInstance4626;
    
    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public yieldSource4626AddressUSDC;
    address public yieldSource7540AddressUSDC;
    address public yieldSource5115AddressSUSDe;

    MockExecutorModule public executorModule1;

    SuperLedger public superLedger;
    SuperLedgerConfiguration public config;

    ERC4626YieldSourceOracle public oracle4626;
    ERC5115YieldSourceOracle public oracle5115;
    ERC7540YieldSourceOracle public oracle7540;

    address public feeRecipient;

    bytes32 public yieldSourceOracleId4626;
    bytes32 public yieldSourceOracleId5115;
    bytes32 public yieldSourceOracleId7540;

    function setUp() public override {
        super.setUp();

        
    }

    function test_4626VaultFees() public {

    }

    function test_5115VaultFees() public {

    }

    function test_7540VaultFees() public {

    }


}