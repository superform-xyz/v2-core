// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../BaseTest.t.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";

// external
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Permit2MultiVaultDepositFlow is BaseTest {
    IERC4626 public vaultInstanceETH;

    address public underlyingETH_USDC;
    address public underlyingETH_WETH;

    address public yieldSourceOracle;
    address public yieldSourceAddressETH;

    address public accountETH;
    AccountInstance public instanceOnETH;

    ISuperExecutor public superExecutorOnETH;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlyingETH_USDC = existingUnderlyingTokens[ETH]["USDC"];
        underlyingETH_WETH = existingUnderlyingTokens[ETH]["WETH"];

        yieldSourceAddressETH = realVaultAddresses[ETH]["ERC7540FullyAsync"]["CentrifugeUSDC"]["USDC"];
        console2.log("yieldSourceAddressETH", yieldSourceAddressETH);
        vaultInstanceETH = IERC4626(yieldSourceAddressETH);
        yieldSourceOracle = _getContract(ETH, "ERC4626YieldSourceOracle");
        console2.log("yieldSourceOracle", yieldSourceOracle);

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
            yieldSourceAddressETH,
            amount,
            false
        );
    }


}
