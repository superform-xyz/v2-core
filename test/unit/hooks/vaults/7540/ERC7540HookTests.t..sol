// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../../../../../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { ApproveAndWithdraw7540VaultHook } from
    "../../../../../src/core/hooks/vaults/7540/ApproveAndWithdraw7540VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { ApproveAndRedeem7540VaultHook } from
    "../../../../../src/core/hooks/vaults/7540/ApproveAndRedeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { Deposit7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { CancelDepositRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { IERC7540 } from "../../../../../src/vendor/vaults/7540/IERC7540.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { ISuperExecutor } from "../../../../../src/core/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../../../src/core/executors/SuperExecutor.sol";
import { Helpers } from "../../../../../test/utils/Helpers.sol";
import { InternalHelpers } from "../../../../../test/utils/InternalHelpers.sol";
import { MockLedger, MockLedgerConfiguration } from "../../../../mocks/MockLedger.sol";
import { RhinestoneModuleKit, AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract HooksFor7540VaultTest is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    RequestDeposit7540VaultHook public requestDepositHook;
    ApproveAndRequestDeposit7540VaultHook public approveAndRequestDepositHook;
    Deposit7540VaultHook public depositHook;
    RequestRedeem7540VaultHook public reqRedeemHook;
    Withdraw7540VaultHook public withdrawHook;
    ApproveAndRedeem7540VaultHook public redeemHook;
    ApproveAndWithdraw7540VaultHook public approveAndWithdrawHook;
    CancelDepositRequest7540Hook public cancelDepositRequestHook;
    CancelRedeemRequest7540Hook public cancelRedeemRequestHook;
    ClaimCancelDepositRequest7540Hook public claimCancelDepositRequestHook;
    ClaimCancelRedeemRequest7540Hook public claimCancelRedeemRequestHook;

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

    uint256 public prevHookAmount;

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

        amount = 1000e6;
        prevHookAmount = 2000e6;

        requestDepositHook = new RequestDeposit7540VaultHook();
        approveAndRequestDepositHook = new ApproveAndRequestDeposit7540VaultHook();
        depositHook = new Deposit7540VaultHook();
        reqRedeemHook = new RequestRedeem7540VaultHook();
        redeemHook = new ApproveAndRedeem7540VaultHook();
        withdrawHook = new Withdraw7540VaultHook();
        approveAndWithdrawHook = new ApproveAndWithdraw7540VaultHook();
        cancelDepositRequestHook = new CancelDepositRequest7540Hook();
        cancelRedeemRequestHook = new CancelRedeemRequest7540Hook();
        claimCancelDepositRequestHook = new ClaimCancelDepositRequest7540Hook();
        claimCancelRedeemRequestHook = new ClaimCancelRedeemRequest7540Hook();
    }

    function test_7540Flow() public { }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_WithdrawHookConstructor() public view {
        assertEq(uint256(withdrawHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_RequestDepositHookConstructor() public view {
        assertEq(uint256(requestDepositHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ApproveAndRequestDepositHookConstructor() public view {
        assertEq(uint256(approveAndRequestDepositHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_DepositHookConstructor() public view {
        assertEq(uint256(depositHook.hookType()), uint256(ISuperHook.HookType.INFLOW));
    }

    function test_RequestRedeemHookConstructor() public view {
        assertEq(uint256(reqRedeemHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_RedeemHookConstructor() public view {
        assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_WithdrawHook_Constructor() public view {
        assertEq(uint256(withdrawHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_CancelDepositRequestHookConstructor() public view {
        assertEq(uint256(cancelDepositRequestHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_CancelRedeemRequestHookConstructor() public view {
        assertEq(uint256(cancelRedeemRequestHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ClaimCancelDepositRequestHookConstructor() public view {
        assertEq(uint256(claimCancelDepositRequestHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ClaimCancelRedeemRequestHookConstructor() public view {
        assertEq(uint256(claimCancelRedeemRequestHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestDepositHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = requestDepositHook.build(address(0), address(this), data);
        assertEq(executions.length, 1);
        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
    }

    function test_ApproveAndRequestDepositHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = approveAndRequestDepositHook.build(address(0), address(this), data);
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

    function test_DepositHook_Build() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = depositHook.build(address(0), address(this), data);
        assertEq(executions.length, 1);
        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_RequestRedeemHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = reqRedeemHook.build(address(0), address(this), data);
        assertEq(executions.length, 1);
        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
    }

    function test_ApproveAndWithdrawHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = approveAndWithdrawHook.build(address(0), address(this), data);
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

    function test_ApproveAndRedeemHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = redeemHook.build(address(0), address(this), data);
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

    function test_WithdrawHook_Build() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);

        assertEq(executions.length, 1);

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_CancelDepositRequestHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = cancelDepositRequestHook.build(address(0), address(this), data);
        assertEq(executions.length, 1);

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_CancelRedeemRequestHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = cancelRedeemRequestHook.build(address(0), address(this), data);
        assertEq(executions.length, 1);

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_ClaimCancelDepositRequestHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = claimCancelDepositRequestHook.build(address(0), address(this), data);
        assertEq(executions.length, 1);

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_ClaimCancelRedeemRequestHook_Build() public {
        bytes memory data = _encodeData();
        Execution[] memory executions = claimCancelRedeemRequestHook.build(address(0), address(this), data);

        assertEq(executions.length, 1);

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PREV HOOK BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        Execution[] memory executions = approveAndRequestDepositHook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 4);

        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.requestDeposit, (prevHookAmount, address(this), address(this)));

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, expectedCallData);

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_RequestDepositHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        Execution[] memory executions = requestDepositHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 1);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.requestDeposit, (prevHookAmount, address(this), address(this)));

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertEq(executions[0].callData, expectedCallData);
    }

    function test_DepositHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = depositHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 1);

        bytes memory expectedCallData = abi.encodeCall(IERC7540.deposit, (prevHookAmount, address(this), address(this)));

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertEq(executions[0].callData, expectedCallData);
    }

    function test_RequestRedeemHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        Execution[] memory executions = reqRedeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 1);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.requestRedeem, (prevHookAmount, address(this), address(this)));

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertEq(executions[0].callData, expectedCallData);
    }

    function test_ApproveAndRedeemHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeApproveAndRequestRedeemData(true, 1000);
        Execution[] memory executions = redeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 4);

        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        bytes memory expectedCallData = abi.encodeCall(IERC7540.redeem, (prevHookAmount, address(this), address(this)));

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, expectedCallData);

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_ApproveAndWithdrawHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeApproveAndRequestRedeemData(true, 1000);
        Execution[] memory executions = approveAndWithdrawHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 4);

        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.withdraw, (prevHookAmount, address(this), address(this)));

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, expectedCallData);

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_WithdrawHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = withdrawHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 1);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.withdraw, (prevHookAmount, address(this), address(this)));

        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);

        assertEq(executions[0].callData, expectedCallData);
    }

    /*//////////////////////////////////////////////////////////////
                      BUILD REVERTING TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        vm.expectRevert();
        approveAndRequestDepositHook.build(mockPrevHook, address(0), data);
    }

    function test_RequestDepositHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        vm.expectRevert();
        requestDepositHook.build(mockPrevHook, address(0), data);
    }

    function test_DepositHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        vm.expectRevert();
        depositHook.build(mockPrevHook, address(0), data);
    }

    function test_RequestRedeemHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        vm.expectRevert();
        reqRedeemHook.build(mockPrevHook, address(0), data);
    }

    function test_ApproveAndRedeemHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeApproveAndRequestRedeemData(true, 1000);
        vm.expectRevert();
        redeemHook.build(mockPrevHook, address(0), data);
    }

    function test_WithdrawHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        vm.expectRevert();
        withdrawHook.build(mockPrevHook, address(0), data);
    }

    function test_CancelDepositRequestHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeCancelDepositRequestZeroAddressData();
        vm.expectRevert();
        cancelDepositRequestHook.build(mockPrevHook, address(0), data);
    }

    function test_CancelRedeemRequestHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeCancelRedeemRequestZeroAddressData();
        vm.expectRevert();
        cancelRedeemRequestHook.build(mockPrevHook, address(0), data);
    }
    
    function test_ClaimCancelDepositRequestHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeClaimCancelDepositRequestZeroAddressData();
        vm.expectRevert();
        claimCancelDepositRequestHook.build(mockPrevHook, address(0), data);
    }

    function test_ClaimCancelRedeemRequestHook_Build_Reverting() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);    

        bytes memory data = _encodeClaimCancelRedeemRequestZeroAddressData();
        vm.expectRevert();
        claimCancelRedeemRequestHook.build(mockPrevHook, address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
                            DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_DecodeAmount() public view {
        bytes memory data = _encodeData(false);
        uint256 decodedAmount = approveAndRequestDepositHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_RequestDepositHook_DecodeAmount() public view{
        bytes memory data = _encodeRequestData(false);
        uint256 decodedAmount = requestDepositHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_DepositHook_DecodeAmount() public view {
        bytes memory data = _encodeData(false, false);
        uint256 decodedAmount = depositHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_RequestRedeemHook_DecodeAmount() public view {
        bytes memory data = _encodeRequestData(false);
        uint256 decodedAmount = reqRedeemHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_ApproveAndRedeemHook_DecodeAmount() public view {
        bytes memory data = _encodeApproveAndRequestRedeemData(false, 1000);
        uint256 decodedAmount = redeemHook.decodeAmount(data);
        assertEq(decodedAmount, 1000);
    }

    function test_WithdrawHook_DecodeAmount() public view {
        bytes memory data = _encodeData(false, false);
        uint256 decodedAmount = withdrawHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_ApproveAndWithdrawHook_DecodeAmount() public view {
        bytes memory data = _encodeApproveAndRequestRedeemData(false, 1000);
        uint256 decodedAmount = approveAndWithdrawHook.decodeAmount(data);
        assertEq(decodedAmount, 1000);
    }

    /*//////////////////////////////////////////////////////////////
                        REPLACE CALLDATA TESTS
    //////////////////////////////////////////////////////////////*/
    // function test_ApproveAndRedeemHook_ReplaceCallData() public {
    //     bytes memory data = _encodeRedeemData(false);
        
    //     bytes memory replacedData = redeemHook.replaceCalldataAmount(data, 1);

    //     uint256 replacedAmount = redeemHook.decodeAmount(replacedData);
    //     assertEq(replacedAmount, 1);
    // }
    
    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, address(this));
    }
    
    function _encodeData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHook);
    }

    function _encodeData(bool usePrevHook, bool lockForSp) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHook, lockForSp);
    }

    function _encodeRedeemData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHook);
    }

    function _encodeRequestData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHook);
    }

    function _encodeApproveAndRequestRedeemData(
        bool usePrevHook,
        uint256 shares
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, shares, usePrevHook);
    }

    function _encodeCancelDepositRequestZeroAddressData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(0));
    }

    function _encodeCancelRedeemRequestZeroAddressData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(0));
    }

    function _encodeClaimCancelDepositRequestZeroAddressData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, address(0));
    }

    function _encodeClaimCancelRedeemRequestZeroAddressData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, address(0));
    }
}
