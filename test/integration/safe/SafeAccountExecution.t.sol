// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { ISafeConfiguration } from "../../../src/vendor/gnosis/ISafeConfiguration.sol";
import { UserOpData, AccountInstance, Execution, ExecutionLib, ModuleKitHelpers } from "modulekit/ModuleKit.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";

contract SafeAccountExecution is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    uint256 public depositAmount;

    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnBase;

    address public accountETH;
    address public accountBase;

    address public addressOracleETH;
    address public addressOracleBase;

    address public underlyingETH_USDC;
    address public underlyingBase_USDC;

    ISuperExecutor public superExecutorETH;
    ISuperExecutor public superExecutorBase;

    AcrossV3Adapter public acrossAdapterETH;
    AcrossV3Adapter public acrossAdapterBase;

    IERC4626 public vaultInstanceMorphoETH;
    IERC4626 public vaultInstanceMorphoBase;

    address public yieldSource4626AddressETH;
    address public yieldSource4626AddressBase;

    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleBase;

    ISuperDestinationExecutor public targetExecutorETH;
    ISuperDestinationExecutor public targetExecutorBase;

    string public constant YIELD_SOURCE_4626_BASE_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_ETH_KEY = "ERC4626_ETH_USDC";

    function setUp() public override {
        super.setUp();

        depositAmount = 1000e6; // 1000 USDC

        vm.selectFork(FORKS[ETH]);

        instanceOnETH = accountInstances[ETH];
        accountETH = instanceOnETH.account;

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];

        yieldSource4626AddressETH = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoETH = IERC4626(yieldSource4626AddressETH);
        vm.label(yieldSource4626AddressETH, "YIELD_SOURCE_MORPHO_USDC_ETH");

        addressOracleETH = new ERC4626YieldSourceOracle(yieldSource4626AddressETH);
        yieldSourceOracleETH = IYieldSourceOracle(addressOracleETH);

        superExecutorETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        targetExecutorETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));

        acrossAdapterETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));

        vm.selectFork(FORKS[BASE]);

        instanceOnBase = accountInstances[BASE];
        accountBase = instanceOnBase.account;

        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];

        yieldSource4626AddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSource4626AddressBase);
        vm.label(yieldSource4626AddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        addressOracleBase = new ERC4626YieldSourceOracle(yieldSource4626AddressBase);
        yieldSourceOracleBase = IYieldSourceOracle(addressOracleBase);

        superExecutorBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        targetExecutorBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));

        acrossAdapterBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
    }

    function test_SafeAccount_SameChain_Execution() public {
        // TODO: Implement test
    }

    function test_SafeAccount_CrossChain_Execution() public {
        // TODO: Implement test
    }
}
