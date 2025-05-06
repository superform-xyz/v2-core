// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedgerData } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../../src/core/interfaces/accounting/IYieldSourceOracle.sol";

import { ISuperDestinationExecutor } from "../../src/core/interfaces/ISuperDestinationExecutor.sol";

import { BaseTest } from "../BaseTest.t.sol";

import "forge-std/console2.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
contract ERC4626DepositRedeemFlowTest is BaseTest {
    IERC4626 public vaultInstanceEth;
    IERC4626 public vaultInstanceBase;
    address public yieldSourceAddressEth;
    address public yieldSourceAddressBase;
    address public yieldSourceAddressBaseWeth;
    address public yieldSourceOracle;
    address public underlyingEth_USDC;
    address public underlyingOp_USDC;
    address public underlyingBase_USDC;
    address public underlyingBase_WETH;
    address public underlyingETH_USDC;
    address public underlyingOP_USDC;

    address public accountEth;
    address public accountBase;
    AccountInstance public instanceOnEth;
    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnOP;
    ISuperExecutor public superExecutorOnEth;
    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnOP;

    ISuperDestinationExecutor public superTargetExecutorOnBase;
    ISuperDestinationExecutor public superTargetExecutorOnETH;
    ISuperDestinationExecutor public superTargetExecutorOnOP;

    IValidator public validatorOnBase;
    IValidator public validatorOnETH;
    IValidator public validatorOnOP;

    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;

    address public addressOracleBase_4626;
    IYieldSourceOracle public yieldSourceOracleBase_4626;
    IYieldSourceOracle public yieldSourceOracleBase_WETH;

    IERC4626 public vaultInstance4626Base_USDC;
    IERC4626 public vaultInstance4626Base_WETH;

    string public constant YIELD_SOURCE_ORACLE_4626_BASE = "YieldSourceOracle_4626";

    string public constant YIELD_SOURCE_4626_BASE_USDC_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_BASE_WETH_KEY = "ERC4626_BASE_WETH";
    uint256 public constant WARP_START_TIME = 1_740_559_708;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);
        yieldSource4626AddressBase_WETH =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY];
        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);
        addressOracleBase_4626 = _getContract(BASE, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleBase_4626, YIELD_SOURCE_ORACLE_4626_BASE);
        yieldSourceOracleBase_4626 = IYieldSourceOracle(addressOracleBase_4626);
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];

        underlyingEth_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingOp_USDC = existingUnderlyingTokens[OP][USDC_KEY];
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        yieldSourceAddressEth = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        yieldSourceAddressBase = realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        yieldSourceAddressBaseWeth =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY];
        yieldSourceOracle = _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vaultInstanceEth = IERC4626(yieldSourceAddressEth);
        vaultInstanceBase = IERC4626(yieldSourceAddressBase);
        accountEth = accountInstances[ETH].account;
        accountBase = accountInstances[BASE].account;
        instanceOnEth = accountInstances[ETH];
        instanceOnBase = accountInstances[BASE];
        instanceOnOP = accountInstances[OP];
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));
        superTargetExecutorOnBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));
        validatorOnBase = IValidator(_getContract(BASE, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));

        vm.selectFork(FORKS[BASE]);
        deal(underlyingBase_WETH, mockOdosRouters[BASE], 1e12);
    }

    function test_Deposit_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        vm.selectFork(FORKS[ETH]);

        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingInflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstanceEth.balanceOf(accountEth);
        assertEq(accSharesAfter, vaultInstanceEth.previewDeposit(amount));

        hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressEth,
            accountEth,
            accSharesAfter / 2, // temporary
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingOutflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, accSharesAfter, 0);

        executeOp(userOpData);

        // uint256 accSharesAfterWithdraw = vaultInstanceEth.balanceOf(accountEth);
        // assertEq(accSharesAfterWithdraw, 0);
    }
}
