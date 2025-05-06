// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndDeposit5115VaultHook } from
    "../../../../../src/core/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { SuperExecutor } from "../../../../../src/core/executors/SuperExecutor.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../InternalHelpers.sol";
import { ISuperExecutor } from "../../../../../src/core/interfaces/ISuperExecutor.sol";
import { IStandardizedYield } from "../../../../../src/vendor/pendle/IStandardizedYield.sol";
import { MockLedger, MockLedgerConfiguration } from "../../../../mocks/MockLedger.sol";
import { RhinestoneModuleKit, AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";

import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

contract ApproveAndDeposit5115VaultHookTest is Helpers, RhinestoneModuleKit, InternalHelpers {
    ApproveAndDeposit5115VaultHook public hook;

    using ModuleKitHelpers for *;

    bytes4 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;

    IStandardizedYield public vaultInstance5115ETH;

    address public underlyingETH_sUSDe;
    address public yieldSource5115AddressSUSDe;
    address public accountETH;
    address public feeRecipient;

    AccountInstance public instanceOnETH;
    ISuperExecutor public superExecutorOnETH;
    MockLedger public ledger;
    MockLedgerConfiguration public ledgerConfig;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), 21_929_476);
        instanceOnETH = makeAccountInstance(keccak256(abi.encode("TEST")));
        accountETH = instanceOnETH.account;
        feeRecipient = makeAddr("feeRecipient");

        underlyingETH_sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
        _getTokens(underlyingETH_sUSDe, accountETH, 100e6);

        yieldSource5115AddressSUSDe = 0x3Ee118EFC826d30A29645eAf3b2EaaC9E8320185;

        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);

        ledger = new MockLedger();
        ledgerConfig = new MockLedgerConfiguration(address(ledger), feeRecipient, address(token), 100, accountETH);

        superExecutorOnETH = new SuperExecutor(address(ledgerConfig));
        instanceOnETH.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnETH), data: "" });

        yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        token = address(new MockERC20("Token", "TKN", 18));
        amount = 1000;

        hook = new ApproveAndDeposit5115VaultHook();
    }

    function test_ApproveAndDeposit5115VaultHook() public {
        amount = 1e8;

        uint256 accountSUSDEStartBalance = IERC20(underlyingETH_sUSDe).balanceOf(accountETH);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource5115AddressSUSDe,
            underlyingETH_sUSDe,
            amount,
            0,
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit IStandardizedYield.Deposit(accountETH, accountETH, underlyingETH_sUSDe, amount, amount);
        executeOp(userOpData);

        // Check asset balances
        assertEq(IERC20(underlyingETH_sUSDe).balanceOf(accountETH), accountSUSDEStartBalance - amount);

        // Check vault shares balances
        assertEq(vaultInstance5115ETH.balanceOf(accountETH), amount);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.INFLOW));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 4);
        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 4);
        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        address _yieldSource = yieldSource;

        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));

        yieldSource = _yieldSource;
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), _encodeData(false, false));
    }

    function test_Build_RevertIf_AmountZero() public {
        amount = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_DecodeAmount() public view {
        bytes memory data = _encodeData(false, false);
        uint256 decodedAmount = hook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);
        bytes memory data = _encodeData(false, false);
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);
    }

    function _encodeData(bool usePrevHook, bool lockForSp) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, amount, usePrevHook, lockForSp);
    }
}
