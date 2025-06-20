// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndRequestDeposit7540VaultHook } from
    "../../../../../src/core/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { ApproveAndRequestRedeem7540VaultHook } from
    "../../../../../src/core/hooks/vaults/7540/ApproveAndRequestRedeem7540VaultHook.sol";
import { Redeem7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/Redeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { Deposit7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { CancelDepositRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../../../../../src/core/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from
    "../../../../../src/core/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { ISuperHook, ISuperHookAsyncCancelations } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { IERC7540 } from "../../../../../src/vendor/vaults/7540/IERC7540.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { Helpers } from "../../../../../test/utils/Helpers.sol";
import { HookSubTypes } from "../../../../../src/core/libraries/HookSubTypes.sol";
import { InternalHelpers } from "../../../../../test/utils/InternalHelpers.sol";
import { CancelRedeemHook } from "../../../../../src/core/hooks/vaults/super-vault/CancelRedeemHook.sol";

contract ERC7540VaultHookTests is Helpers, InternalHelpers {
    RequestDeposit7540VaultHook public requestDepositHook;
    ApproveAndRequestDeposit7540VaultHook public approveAndRequestDepositHook;
    Deposit7540VaultHook public depositHook;
    RequestRedeem7540VaultHook public reqRedeemHook;
    Withdraw7540VaultHook public withdrawHook;
    ApproveAndRequestRedeem7540VaultHook public approveAndReqRedeemHook;
    Redeem7540VaultHook public redeemHook;
    CancelDepositRequest7540Hook public cancelDepositRequestHook;
    CancelRedeemRequest7540Hook public cancelRedeemRequestHook;
    ClaimCancelDepositRequest7540Hook public claimCancelDepositRequestHook;
    ClaimCancelRedeemRequest7540Hook public claimCancelRedeemRequestHook;
    CancelRedeemHook public cancelRedeemHook;

    bytes4 yieldSourceOracleId;
    address yieldSource;
    address shareToken;
    address token;
    uint256 amount;

    IERC7540 public vaultInstance7540ETH;
    address public underlyingETH_USDC;
    address public yieldSource7540AddressUSDC;

    uint256 public prevHookAmount;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), 21_929_476);

        underlyingETH_USDC = CHAIN_1_USDC;

        yieldSource7540AddressUSDC = CHAIN_1_CentrifugeUSDC;

        yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        shareToken = address(this);
        token = address(new MockERC20("Token", "TKN", 18));

        amount = 1000e6;
        prevHookAmount = 2000e6;

        requestDepositHook = new RequestDeposit7540VaultHook();
        approveAndRequestDepositHook = new ApproveAndRequestDeposit7540VaultHook();
        depositHook = new Deposit7540VaultHook();
        reqRedeemHook = new RequestRedeem7540VaultHook();
        redeemHook = new Redeem7540VaultHook();
        approveAndReqRedeemHook = new ApproveAndRequestRedeem7540VaultHook();
        withdrawHook = new Withdraw7540VaultHook();
        cancelDepositRequestHook = new CancelDepositRequest7540Hook();
        cancelRedeemRequestHook = new CancelRedeemRequest7540Hook();
        claimCancelDepositRequestHook = new ClaimCancelDepositRequest7540Hook();
        claimCancelRedeemRequestHook = new ClaimCancelRedeemRequest7540Hook();
        cancelRedeemHook = new CancelRedeemHook();
    }

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
                            INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_redeemHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = redeemHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_approveAndRequestDepositHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = approveAndRequestDepositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_cancelDepositRequestHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = cancelDepositRequestHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_cancelRedeemRequestHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = cancelRedeemRequestHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_claimCancelDepositRequestHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = claimCancelDepositRequestHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_claimCancelRedeemRequestHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = claimCancelRedeemRequestHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_depositHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = depositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_requestDepositHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = requestDepositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_requestRedeemHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = reqRedeemHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_withdrawHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = withdrawHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_cancelRedeemHook_InspectorTests() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = cancelRedeemHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RequestDepositHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = requestDepositHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
    }

    function test_ApproveAndRequestDepositHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = approveAndRequestDepositHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, token);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

        assertEq(executions[3].target, yieldSource);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);

        assertEq(executions[4].target, token);
        assertEq(executions[4].value, 0);
        assertGt(executions[4].callData.length, 0);
    }

    function test_DepositHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = depositHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_RequestRedeemHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = reqRedeemHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
    }

    function test_RedeemHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = redeemHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_WithdrawHook_Build() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_CancelDepositRequestHook_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = cancelDepositRequestHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_CancelRedeemRequestHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = cancelRedeemRequestHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_ClaimCancelDepositRequestHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = claimCancelDepositRequestHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_ClaimCancelRedeemRequestHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = claimCancelRedeemRequestHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_ClaimCancelRedeemRequestHook_Build_ZeroAddresses() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), address(this));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        claimCancelRedeemRequestHook.build(address(0), address(this), data);

        data = abi.encodePacked(yieldSourceOracleId, address(this), address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        claimCancelRedeemRequestHook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                        PREV HOOK BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        Execution[] memory executions = approveAndRequestDepositHook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 6);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, token);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.requestDeposit, (prevHookAmount, address(this), address(this)));

        assertEq(executions[3].target, yieldSource);
        assertEq(executions[3].value, 0);
        assertEq(executions[3].callData, expectedCallData);

        assertEq(executions[4].target, token);
        assertEq(executions[4].value, 0);
        assertGt(executions[4].callData.length, 0);
    }

    function test_RequestDepositHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        Execution[] memory executions = requestDepositHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.requestDeposit, (prevHookAmount, address(this), address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_DepositHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = depositHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData = abi.encodeCall(IERC7540.deposit, (prevHookAmount, address(this), address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_RequestRedeemHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        Execution[] memory executions = reqRedeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.requestRedeem, (prevHookAmount, address(this), address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_RedeemHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeApproveAndRequestRedeemData(true, 1000, false);
        Execution[] memory executions = redeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData = abi.encodeCall(IERC7540.redeem, (prevHookAmount, address(this), address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_WithdrawHook_Build_WithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = withdrawHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData =
            abi.encodeCall(IERC7540.withdraw, (prevHookAmount, address(this), address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);

        assertEq(executions[1].callData, expectedCallData);
    }

    /*//////////////////////////////////////////////////////////////
                      BUILD REVERTING TESTS
    //////////////////////////////////////////////////////////////*/
    // --- ZERO ADDRESS TESTS ---
    function test_ApproveAndRequestDepositHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        vm.expectRevert();
        approveAndRequestDepositHook.build(mockPrevHook, address(0), data);
    }

    function test_RequestDepositHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        vm.expectRevert();
        requestDepositHook.build(mockPrevHook, address(0), data);
    }

    function test_DepositHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        vm.expectRevert();
        depositHook.build(mockPrevHook, address(0), data);
    }

    function test_RequestRedeemHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRequestData(true);
        vm.expectRevert();
        reqRedeemHook.build(mockPrevHook, address(0), data);
    }

    function test_ApproveAndRedeemHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeApproveAndRequestRedeemData(true, 1000, false);
        vm.expectRevert();
        redeemHook.build(mockPrevHook, address(0), data);
    }

    function test_WithdrawHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        vm.expectRevert();
        withdrawHook.build(mockPrevHook, address(0), data);
    }

    function test_CancelDepositRequestHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeCancelDepositRequestZeroAddressData();
        vm.expectRevert();
        cancelDepositRequestHook.build(mockPrevHook, address(0), data);
    }

    function test_CancelRedeemRequestHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeCancelRedeemRequestZeroAddressData();
        vm.expectRevert();
        cancelRedeemRequestHook.build(mockPrevHook, address(0), data);
    }

    function test_ClaimCancelDepositRequestHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeClaimCancelDepositRequestZeroAddressData();
        vm.expectRevert();
        claimCancelDepositRequestHook.build(mockPrevHook, address(0), data);
    }

    function test_ClaimCancelRedeemRequestHook_Build_Revert_ZeroAddress() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeClaimCancelRedeemRequestZeroAddressData();
        vm.expectRevert();
        claimCancelRedeemRequestHook.build(mockPrevHook, address(0), data);
    }

    // --- ZERO AMOUNT TESTS ---

    function test_ApproveAndRequestDepositHook_Build_Revert_AmountZero() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, uint256(0), false);
        vm.expectRevert();
        approveAndRequestDepositHook.build(mockPrevHook, address(this), data);
    }

    function test_RequestDepositHook_Build_Revert_AmountZero() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
        vm.expectRevert();
        requestDepositHook.build(mockPrevHook, address(this), data);
    }

    function test_DepositHook_Build_Revert_AmountZero() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
        vm.expectRevert();
        depositHook.build(mockPrevHook, address(this), data);
    }

    function test_RequestRedeemHook_Build_Revert_AmountZero() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
        vm.expectRevert();
        reqRedeemHook.build(mockPrevHook, address(this), data);
    }

    function test_ApproveAndRedeemHook_Build_Revert_AmountZero() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
        vm.expectRevert();
        redeemHook.build(mockPrevHook, address(this), data);
    }

    function test_WithdrawHook_Build_Revert_AmountZero() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
        vm.expectRevert();
        withdrawHook.build(mockPrevHook, address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                            DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_DecodeAmount() public view {
        bytes memory data = _encodeData(false);
        uint256 decodedAmount = approveAndRequestDepositHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_RequestDepositHook_DecodeAmount() public view {
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
        bytes memory data = _encodeApproveAndRequestRedeemData(false, 1000, false);
        uint256 decodedAmount = redeemHook.decodeAmount(data);
        assertEq(decodedAmount, 1000);
    }

    function test_WithdrawHook_DecodeAmount() public view {
        bytes memory data = _encodeData(false, false);
        uint256 decodedAmount = withdrawHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(false);
        assertFalse(approveAndRequestDepositHook.decodeUsePrevHookAmount(data));
        assertFalse(requestDepositHook.decodeUsePrevHookAmount(data));
        assertFalse(depositHook.decodeUsePrevHookAmount(data));
        assertFalse(reqRedeemHook.decodeUsePrevHookAmount(data));
        assertFalse(redeemHook.decodeUsePrevHookAmount(data));
        assertFalse(withdrawHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                        REPLACE CALLDATA TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRedeemHook_ReplaceCallData() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false, false);

        bytes memory replacedData = redeemHook.replaceCalldataAmount(data, 1);
        assertEq(replacedData.length, data.length);

        uint256 replacedAmount = redeemHook.decodeAmount(replacedData);
        assertEq(replacedAmount, 1);
    }

    function test_WithdrawHook_ReplaceCallData() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, false);

        bytes memory replacedData = withdrawHook.replaceCalldataAmount(data, 1);
        assertEq(replacedData.length, data.length);

        uint256 replacedAmount = withdrawHook.decodeAmount(replacedData);
        assertEq(replacedAmount, 1);
    }

    /*//////////////////////////////////////////////////////////////
                      USED ASSETS OR SHARES TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_UsedAssetsOrShares() public view {
        (uint256 usedAssets, bool isShares) = approveAndRequestDepositHook.getUsedAssetsOrShares();
        assertEq(usedAssets, 0);
        assertEq(isShares, false);
    }

    function test_RequestDepositHook_UsedAssetsOrShares() public view {
        (uint256 usedAssets, bool isShares) = requestDepositHook.getUsedAssetsOrShares();
        assertEq(usedAssets, 0);
        assertEq(isShares, false);
    }

    function test_RequestRedeemHook_UsedAssetsOrShares() public view {
        (uint256 usedAssets, bool isShares) = reqRedeemHook.getUsedAssetsOrShares();
        assertEq(usedAssets, 0);
        assertEq(isShares, true);
    }

    function test_RedeemHook_UsedAssetsOrShares() public view {
        (uint256 usedAssets, bool isShares) = redeemHook.getUsedAssetsOrShares();
        assertEq(usedAssets, 0);
        assertEq(isShares, true);
    }

    function test_ApproveAndRequestRedeemHook_UsedAssetsOrShares() public view {
        (uint256 usedAssets, bool isShares) = approveAndReqRedeemHook.getUsedAssetsOrShares();
        assertEq(usedAssets, 0);
        assertEq(isShares, true);
    }

    /*//////////////////////////////////////////////////////////////
                      PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndRequestDepositHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeData(false);
        approveAndRequestDepositHook.preExecute(address(0), address(this), data);
        assertEq(approveAndRequestDepositHook.outAmount(), amount);

        approveAndRequestDepositHook.postExecute(address(0), address(this), data);
        assertEq(approveAndRequestDepositHook.outAmount(), 0);
    }

    function test_RequestDepositHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeRequestData(false);
        requestDepositHook.preExecute(address(0), address(this), data);
        assertEq(requestDepositHook.outAmount(), amount);

        requestDepositHook.postExecute(address(0), address(this), data);
        assertEq(requestDepositHook.outAmount(), 0);
    }

    function test_DepositHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, address(this), uint256(1));
        depositHook.preExecute(address(0), address(this), data);
        assertEq(depositHook.outAmount(), amount);

        depositHook.postExecute(address(0), address(this), data);
        assertEq(depositHook.outAmount(), 0);
    }

    function test_RequestRedeemHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeRequestData(false);
        reqRedeemHook.preExecute(address(0), address(this), data);
        assertEq(reqRedeemHook.outAmount(), amount);

        reqRedeemHook.postExecute(address(0), address(this), data);
        assertEq(reqRedeemHook.outAmount(), 0);
    }

    function test_ApproveAndRedeemHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeApproveAndRequestRedeemData(false, 1000, false);
        redeemHook.preExecute(address(0), address(this), data);
        assertEq(redeemHook.outAmount(), 1_000_000_000);

        redeemHook.postExecute(address(0), address(this), data);
        assertEq(redeemHook.outAmount(), 0);
    }

    function test_WithdrawHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeData(false, false);
        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.outAmount(), amount);

        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.outAmount(), 0);
    }

    function test_claimCancelRedeemRequestHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data =
            abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), amount, false, address(this), uint256(1));

        claimCancelRedeemRequestHook.preExecute(address(0), address(this), data);
        assertEq(claimCancelRedeemRequestHook.outAmount(), 1_000_000_000);

        claimCancelRedeemRequestHook.postExecute(address(0), address(this), data);
        assertEq(claimCancelRedeemRequestHook.outAmount(), 0);
    }

    function test_claimCancelDepositRequestHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data =
            abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), amount, false, address(this), uint256(1));

        claimCancelDepositRequestHook.preExecute(address(0), address(this), data);
        assertEq(claimCancelDepositRequestHook.outAmount(), 1_000_000_000);

        claimCancelDepositRequestHook.postExecute(address(0), address(this), data);
        assertEq(claimCancelDepositRequestHook.outAmount(), 0);
    }

    function test_cancelRedeemRequest_PreAndPostExecute() public {
        cancelRedeemRequestHook.preExecute(address(0), address(this), "");
        cancelRedeemRequestHook.postExecute(address(0), address(this), "");
    }

    function test_cancelDepositRequestHook_PreAndPostExecute() public {
        cancelDepositRequestHook.preExecute(address(0), address(this), "");
        cancelDepositRequestHook.postExecute(address(0), address(this), "");
    }

    function test_RedeemHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeApproveAndRequestRedeemData(false, 1000, false);
        redeemHook.preExecute(address(0), address(this), data);
        assertEq(redeemHook.outAmount(), 1_000_000_000);

        redeemHook.postExecute(address(0), address(this), data);
        assertEq(redeemHook.outAmount(), 0);
    }

    function test_ApproveAndRequestRedeemHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeApproveAndRequestRedeemData(false, 1000, false);
        approveAndReqRedeemHook.preExecute(address(0), address(this), data);
        assertEq(approveAndReqRedeemHook.outAmount(), 1_000_000_000);

        approveAndReqRedeemHook.postExecute(address(0), address(this), data);
        assertEq(approveAndReqRedeemHook.outAmount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ASYNC HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_CancelRedeemRequestHook_AsyncHook() public view {
        assertEq(cancelRedeemRequestHook.subType(), HookSubTypes.CANCEL_REDEEM_REQUEST);
    }

    function test_CancelDepositRequestHook_AsyncHook() public view {
        assertEq(cancelDepositRequestHook.subType(), HookSubTypes.CANCEL_DEPOSIT_REQUEST);
    }

    function test_ClaimCancelRedeemRequestHook_AsyncHook() public view {
        assertEq(claimCancelRedeemRequestHook.subType(), HookSubTypes.CLAIM_CANCEL_REDEEM_REQUEST);
    }

    function test_ClaimCancelDepositRequestHook_AsyncHook() public view {
        assertEq(claimCancelDepositRequestHook.subType(), HookSubTypes.CLAIM_CANCEL_DEPOSIT_REQUEST);
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL REDEEM HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_CancelRedeemHook_Constructor() public view {
        assertEq(uint256(cancelRedeemHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(cancelRedeemHook.subType(), HookSubTypes.CANCEL_REDEEM);
    }

    function test_CancelRedeemHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = cancelRedeemHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_CancelRedeemHook_Build_Revert_ZeroAddress() public {
        bytes memory data = _encodeData();
        vm.expectRevert();
        cancelRedeemHook.build(address(0), address(0), data);
    }

    function test_CancelRedeemHook_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);

        bytes memory data = _encodeData();
        cancelRedeemHook.preExecute(address(0), address(this), data);
        assertEq(cancelRedeemHook.outAmount(), amount);

        cancelRedeemHook.postExecute(address(0), address(this), data);
        assertEq(cancelRedeemHook.outAmount(), 0);
    }

    function test_CancelRedeemHook_IsAsyncCancelHook() public view {
        assertEq(
            uint256(cancelRedeemHook.isAsyncCancelHook()), uint256(ISuperHookAsyncCancelations.CancelationType.OUTFLOW)
        );
    }

    function test_ClaimCancelRedeemRequestHook_IsAsyncCancelHook() public view {
        assertEq(
            uint256(claimCancelRedeemRequestHook.isAsyncCancelHook()),
            uint256(ISuperHookAsyncCancelations.CancelationType.OUTFLOW)
        );
    }

    function test_ClaimCancelDepositRequestHook_IsAsyncCancelHook() public view {
        assertEq(
            uint256(claimCancelDepositRequestHook.isAsyncCancelHook()),
            uint256(ISuperHookAsyncCancelations.CancelationType.INFLOW)
        );
    }

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
        uint256 shares,
        bool lockForSp
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, shares, usePrevHook, lockForSp);
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
