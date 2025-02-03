// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";

// Vault Interfaces
import { IStandardizedYield } from "../../src/core/interfaces/vendors/pendle/IStandardizedYield.sol";
import { IERC7540 } from "../../src/core/interfaces/vendors/vaults/7540/IERC7540.sol";
import { IERC4626 } from "../../src/core/interfaces/vendors/vaults/4626/IERC4626.sol";
// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract BridgeToMultiVaultDepositAndRedeemFlow is BaseTest {
    IStandardizedYield public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540ETH;
    IERC4626 public vaultInstance4626OP;

    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public underlyingOP_USDC;

    address public underlyingBase_USDC;
    address public underlyingBase_WETH;

    address public yieldSourceOracleBase;
    address public yieldSourceOracleOP;

    address public yieldSourceOracle5115;
    address public yieldSource5115AddressSUSDe;

    address public yieldSourceOracle7540;
    address public yieldSource7540AddressUSDC;

    address public accountBase;
    address public accountETH;
    address public accountOP;

    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;

    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);


    }
}
