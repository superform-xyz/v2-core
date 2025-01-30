// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../BaseTest.t.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";

// Vault Interfaces
import { IERC5115 } from "../../src/core/interfaces/vendors/vaults/5115/IERC5115.sol";
import { IERC7540 } from "../../src/core/interfaces/vendors/vaults/7540/IERC7540.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Permit2MultiVaultDepositFlow is BaseTest {
    IERC5115 public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540ETH;

    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public yieldSourceOracle5115;
    address public yieldSource5115AddressSUSDe;

    address public yieldSourceOracle7540;
    address public yieldSource7540AddressUSDC;

    address public accountETH;
    AccountInstance public instanceOnETH;

    ISuperExecutor public superExecutorOnETH;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlyingETH_USDC = existingUnderlyingTokens[ETH]["USDC"];
        underlyingETH_sUSDe = existingUnderlyingTokens[ETH]["sUSDe"];

        yieldSource5115AddressSUSDe = realVaultAddresses[ETH]["ERC5115"]["PendleEthena"]["sUSDe"];
        console2.log("yieldSource5115AddressSUSDe", yieldSource5115AddressSUSDe);

        yieldSource7540AddressUSDC = realVaultAddresses[ETH]["ERC7540FullyAsync"]["CentrifugeUSDC"]["USDC"];
        console2.log("yieldSource7540AddressUSDC", yieldSource7540AddressUSDC);

        vaultInstance5115ETH = IERC5115(yieldSource5115AddressSUSDe);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressUSDC);

        yieldSourceOracle5115 = _getContract(ETH, "ERC5115YieldSourceOracle");
        console2.log("yieldSourceOracle5115", yieldSourceOracle5115);

        yieldSourceOracle7540 = _getContract(ETH, "ERC7540YieldSourceOracle");
        console2.log("yieldSourceOracle7540", yieldSourceOracle7540);

        superExecutorOnETH = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        console2.log("superExecutorOnETH", address(superExecutorOnETH));

        accountETH = accountInstances[ETH].account;
        console2.log("accountETH", accountETH);
        instanceOnETH = accountInstances[ETH];
    }

    function test_Permit2_MultiVault_Deposit_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        console2.log("approveHook.hookAddress", hooksAddresses[0]);
        hooksAddresses[1] = _getHookAddress(ETH, "Deposit5115VaultHook");
        console2.log("deposit5115Hook.hookAddress", hooksAddresses[1]);
        // Should there be another approve here?
        hooksAddresses[2] = _getHookAddress(ETH, "RequestDeposit7540VaultHook");
        console2.log("requestDepositHook.hookAddress", hooksAddresses[2]);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(
            underlyingETH_USDC,
            yieldSource5115AddressSUSDe,
            amount,
            false
        );
    }


}
