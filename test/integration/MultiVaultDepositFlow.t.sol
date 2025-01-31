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

contract MultiVaultDepositFlow is BaseTest {
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
        uint256 amountPerVault = amount / 2;

        console2.log("accountStartBalance", IERC20(underlyingETH_USDC).balanceOf(accountETH));

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, "ApproveERC20Hook");
        console2.log("approveHook.hookAddress", hooksAddresses[0]);
        // hooksAddresses[1] = _getHookAddress(ETH, "ApproveERC20Hook");
        // hooksAddresses[2] = _getHookAddress(ETH, "Deposit5115VaultHook");
        // console2.log("deposit5115Hook.hookAddress", hooksAddresses[1]);
        hooksAddresses[1] = _getHookAddress(ETH, "RequestDeposit7540VaultHook");
        console2.log("requestDepositHook.hookAddress", hooksAddresses[1]);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(
            underlyingETH_USDC,
            yieldSource7540AddressUSDC,
            amountPerVault,
            false
        );
        // hooksData[1] = _createApproveHookData(
        //     underlyingETH_sUSDe,
        //     yieldSource5115AddressSUSDe,
        //     amountPerVault,
        //     false
        // );
        // hooksData[2] = _createDeposit5115VaultHookData(
        //     accountETH,
        //     // bytes32("ERC5115YieldSourceOracle"),
        //     yieldSource5115AddressSUSDe,
        //     underlyingETH_sUSDe,
        //     amountPerVault,
        //     0,
        //     false,
        //     false
        // );
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            accountETH,
            yieldSource7540AddressUSDC,
            bytes32("ERC7540YieldSourceOracle"),
            0x6F94EB271cEB5a33aeab5Bb8B8edEA8ECf35Ee86,
            amountPerVault,
            true
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entry));

        // vm.expectEmit(true, true, true, false);
        // emit IERC7540.DepositRequest(
        //     accountETH, 
        //     0x6F94EB271cEB5a33aeab5Bb8B8edEA8ECf35Ee86,
        //     1, 
        //     address(superExecutorOnETH),
        //     amountPerVault
        // );
        executeOp(userOpData);

        // Check balances
        console2.log("IERC20(underlyingETH_USDC).balanceOf(accountETH)", IERC20(underlyingETH_USDC).balanceOf(accountETH));
        //console2.log("IERC20(underlyingETH_sUSDe).balanceOf(accountETH)", IERC20(underlyingETH_sUSDe).balanceOf(accountETH));
        //console2.log("vaultInstance5115ETH.balanceOf(accountETH)", vaultInstance5115ETH.balanceOf(accountETH));
        //console2.log("vaultInstance7540ETH.pendingDepositRequest(ID, accountETH)", vaultInstance7540ETH.pendingDepositRequest(bytes32(0), accountETH));
        // assertEq(IERC20(underlyingETH_USDC).balanceOf(accountETH), 0);
        // assertEq(IERC20(underlyingETH_sUSDe).balanceOf(accountETH), 0);
        // assertEq(vaultInstance5115ETH.balanceOf(accountETH), amountPerVault);
        // assertEq(vaultInstance7540ETH.balanceOf(accountETH), amountPerVault);
    }
}
