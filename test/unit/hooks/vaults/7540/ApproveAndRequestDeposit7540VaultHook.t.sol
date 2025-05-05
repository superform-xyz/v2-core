// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../../../../../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { IERC7540 } from "../../../../../src/vendor/vaults/7540/IERC7540.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { ISuperExecutor } from "../../../../../src/core/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../../../src/core/executors/SuperExecutor.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../InternalHelpers.sol";
import { MockLedger, MockLedgerConfiguration } from "../../../../mocks/MockLedger.sol";
import { RhinestoneModuleKit, AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract ApproveAndRequestDeposit7540VaultHookTest is Helpers, RhinestoneModuleKit, InternalHelpers {
    ApproveAndRequestDeposit7540VaultHook public hook;

    using ModuleKitHelpers for *;

    bytes4 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;

    IERC7540 public vaultInstance7540ETH;
    address public underlyingETH_USDC;
    address public yieldSource7540AddressUSDC;
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

        underlyingETH_USDC = CHAIN_1_USDC;
        _getTokens(underlyingETH_USDC, accountETH, 1e18);

        yieldSource7540AddressUSDC = CHAIN_1_CentrifugeUSDC;

        ledger = new MockLedger();
        ledgerConfig = new MockLedgerConfiguration(address(ledger), feeRecipient, address(token), 100, accountETH);

        superExecutorOnETH = new SuperExecutor(address(ledgerConfig));
        instanceOnETH.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorOnETH), data: "" });

        yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        token = address(new MockERC20("Token", "TKN", 18));
        amount = 1000;

        hook = new ApproveAndRequestDeposit7540VaultHook();
    }

    function test_ApproveAndRequestDeposit7540Hook() public {
        amount = 1e8;

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);

        vm.mockCall(
            0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC,
            abi.encodeWithSelector(IRoot.endorsed.selector, accountETH),
            abi.encode(true)
        );

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createApproveAndRequestDeposit7540HookData(yieldSource7540AddressUSDC, underlyingETH_USDC, amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit IERC7540.DepositRequest(accountETH, accountETH, 0, accountETH, amount);
        executeOp(userOpData);

        vm.clearMockedCalls();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false);
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

        bytes memory data = _encodeData(true);
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

        // yieldSource is address(0)
        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));

        // account is address(0)
        yieldSource = _yieldSource;
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), _encodeData(false));

        // token is address(0)
        token = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_Build_RevertIf_AmountZero() public {
        amount = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_UsedAssetsOrShares() public view {
        (uint256 usedAssets, bool isShares) = hook.getUsedAssetsOrShares();
        assertEq(usedAssets, 0);
        assertEq(isShares, false);
    }

    function test_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);
        bytes memory data = _encodeData(false);
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);
    }

    function _encodeData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHook);
    }
}
