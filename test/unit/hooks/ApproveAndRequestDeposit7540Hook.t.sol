// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";

// Vault Interfaces
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract ApproveAndRequestDeposit7540Hook is BaseTest {
    IERC7540 public vaultInstance7540ETH;

    address public underlyingETH_USDC;

    address public yieldSourceOracle7540;
    address public yieldSource7540AddressUSDC;

    address public accountETH;
    AccountInstance public instanceOnETH;

    ISuperExecutor public superExecutorOnETH;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];

        yieldSource7540AddressUSDC = realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];

        vaultInstance7540ETH = IERC7540(yieldSource7540AddressUSDC);

        yieldSourceOracle7540 = _getContract(ETH, "ERC7540YieldSourceOracle");

        superExecutorOnETH = ISuperExecutor(_getContract(ETH, "SuperExecutor"));

        accountETH = accountInstances[ETH].account;

        instanceOnETH = accountInstances[ETH];
    }

    function test_ApproveAndRequestDeposit7540Hook() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;

        uint256 accountUSDCStartBalance = IERC20(underlyingETH_USDC).balanceOf(accountETH);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        vm.mockCall(
            0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC,
            abi.encodeWithSelector(IRoot.endorsed.selector, accountETH),
            abi.encode(true)
        );

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndRequestDeposit7540HookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressUSDC,
            underlyingETH_USDC,
            amount,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit IERC7540.DepositRequest(accountETH, accountETH, 0, accountETH, amount);
        executeOp(userOpData);

        vm.clearMockedCalls();
    }
}
