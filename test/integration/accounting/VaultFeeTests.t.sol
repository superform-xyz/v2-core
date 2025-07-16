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

    SuperLedger public superLedger;
    SuperLedgerConfiguration public config;

    MockExecutorModule public executorModule1;

    ERC4626YieldSourceOracle public oracle4626;
    ERC5115YieldSourceOracle public oracle5115;
    ERC7540YieldSourceOracle public oracle7540;

    address public feeRecipient;

    bytes32 public yieldSourceOracleId4626;
    bytes32 public yieldSourceOracleId5115;
    bytes32 public yieldSourceOracleId7540;

    function setUp() public override {
        super.setUp();

        underlyingETH_USDC = CHAIN_1_USDC;
        underlyingETH_sUSDe = CHAIN_1_SUSDE;

        _getTokens(underlyingETH_USDC, accountEth, 1e18);
        _getTokens(underlyingETH_sUSDe, accountEth, 1e18);

        yieldSource5115AddressSUSDe = CHAIN_1_PendleEthena;

        config = new SuperLedgerConfiguration();
        executorModule1 = new MockExecutorModule();

        address[] memory executors = new address[](1);
        executors[0] = address(executorModule1);

        superLedger = new SuperLedger(address(config), executors);

        oracle4626 = new ERC4626YieldSourceOracle(address(superLedger));
        oracle5115 = new ERC5115YieldSourceOracle(address(superLedger));
        oracle7540 = new ERC7540YieldSourceOracle(address(superLedger));

        yieldSourceOracleId4626 = bytes32(keccak256("TEST_4626_ORACLE_ID"));
        yieldSourceOracleId5115 = bytes32(keccak256("TEST_5115_ORACLE_ID"));
        yieldSourceOracleId7540 = bytes32(keccak256("TEST_7540_ORACLE_ID"));

        feeRecipient = makeAddr("feeRecipient");
        
        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);
        vaultInstance7540 = IERC7540(yieldSource7540AddressUSDC);
        vaultInstance4626 = IERC4626(yieldSource4626AddressUSDC);
    }

    function test_4626VaultFees() public {

    }

    function test_5115VaultFees() public {

    }

    function test_7540VaultFees() public {

    }


}