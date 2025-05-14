// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndDeposit4626VaultHook } from
    "../../../../../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { ApproveAndRedeem4626VaultHook } from
    "../../../../../src/core/hooks/vaults/4626/ApproveAndRedeem4626VaultHook.sol";
import { Deposit4626VaultHook } from
    "../../../../../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Redeem4626VaultHook } from
    "../../../../../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract ERC4626VaultHooksTest is Helpers {

  ApproveAndDeposit4626VaultHook public approveAndDepositHook;
  ApproveAndRedeem4626VaultHook public approveAndRedeemHook;
  Deposit4626VaultHook public depositHook;
  Redeem4626VaultHook public redeemHook;

  bytes4 yieldSourceOracleId;
  address yieldSource;
  address token;

  uint256 shares;
  uint256 amount;
  uint256 prevHookAmount;
  
  function setUp() public {
    yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
    yieldSource = address(this);
    token = address(new MockERC20("Token", "TKN", 18));
    amount = 1000;
    shares = 1000;
    prevHookAmount = 2000;

    approveAndDepositHook = new ApproveAndDeposit4626VaultHook();
    approveAndRedeemHook = new ApproveAndRedeem4626VaultHook();
    depositHook = new Deposit4626VaultHook();
    redeemHook = new Redeem4626VaultHook();
  }

  function test_Constructors() public view {
    assertEq(uint256(approveAndDepositHook.hookType()), uint256(ISuperHook.HookType.INFLOW));
    assertEq(uint256(approveAndRedeemHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    assertEq(uint256(depositHook.hookType()), uint256(ISuperHook.HookType.INFLOW));
    assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
  }

  /*//////////////////////////////////////////////////////////////
                          BUILD TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_Build() public view {
    bytes memory data = _encodeApproveAndDepositData();
    Execution[] memory executions = approveAndDepositHook.build(address(0), address(this), data);

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
    bytes memory data = _encodeDepositData();
    Execution[] memory executions = depositHook.build(address(0), address(this), data);

    assertEq(executions.length, 1);

    assertEq(executions[0].target, yieldSource);
    assertEq(executions[0].value, 0);
    assertGt(executions[0].callData.length, 0);
  }

  function test_ApproveAndRedeemHook_Build() public view {
    bytes memory data = _encodeApproveAndRedeemData();
    Execution[] memory executions = approveAndRedeemHook.build(address(0), address(this), data);

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

  function test_RedeemHook_Build() public view {
    bytes memory data = _encodeRedeemData();
    Execution[] memory executions = redeemHook.build(address(0), address(this), data);

    assertEq(executions.length, 1);

    assertEq(executions[0].target, yieldSource);
    assertEq(executions[0].value, 0);
    assertGt(executions[0].callData.length, 0);
  }

  /*//////////////////////////////////////////////////////////////
                        ZERO ADDRESS TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_ZeroAddress() public {
    address _yieldSource = yieldSource;

    yieldSource = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndDepositHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false));

    yieldSource = _yieldSource;
    token = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndDepositHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false));
  }

  function test_DepositHook_ZeroAddress() public {
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    depositHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, address(0), amount, false));
  }

  function test_ApproveAndRedeemHook_ZeroAddress() public {
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndRedeemHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, address(0), token, address(this), shares, false));

    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndRedeemHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, yieldSource, address(0), address(this), shares, false));
  }

  function test_RedeemHook_ZeroAddress() public {
    yieldSource = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    redeemHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), shares, false));
  }

  /*//////////////////////////////////////////////////////////////
                        ZERO AMOUNT TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_ZeroAmount() public {
    amount = 0;
    vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, uint256(0), false);
    approveAndDepositHook.build(address(0), address(this), data);
  }

  function test_ApproveAndRedeemHook_ZeroAmount() public {
    amount = 0;
    vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), uint256(0), false);
    approveAndRedeemHook.build(address(0), address(this), data);
  }

  function test_DepositHook_ZeroAmount() public {
    amount = 0;
    vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, address(0), uint256(0));
    depositHook.build(address(0), address(this), data);
  }

  function test_RedeemHook_ZeroAmount() public {
    amount = 0;
    vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), uint256(0), false);
    redeemHook.build(address(0), address(this), data);
  }

  /*//////////////////////////////////////////////////////////////
                  PREVIOUS HOOK AMOUNT TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_PrevHookAmount() public {
    address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
    MockHook(mockPrevHook).setOutAmount(prevHookAmount);

    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, prevHookAmount, true);
    Execution[] memory executions = approveAndDepositHook.build(mockPrevHook, address(this), data);
    
    assertEq(executions.length, 4);

    assertEq(executions[0].target, token);
    assertEq(executions[0].value, 0);
    assertGt(executions[0].callData.length, 0);

    assertEq(executions[1].target, token);
    assertEq(executions[1].value, 0);
    assertGt(executions[1].callData.length, 0);

    bytes memory expectedCallData = abi.encodeCall(IERC4626.deposit, (prevHookAmount, address(this)));

    assertEq(executions[2].target, yieldSource);
    assertEq(executions[2].value, 0);
    assertEq(executions[2].callData, expectedCallData);

    assertEq(executions[3].target, token);
    assertEq(executions[3].value, 0);
    assertGt(executions[3].callData.length, 0);
  }

  function test_ApproveAndRedeemHook_PrevHookAmount() public {
    address mockPrevHook = address(new MockHook(ISuperHook.HookType.OUTFLOW, token));
    MockHook(mockPrevHook).setOutAmount(prevHookAmount);

    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), shares, true);
    Execution[] memory executions = approveAndRedeemHook.build(mockPrevHook, address(this), data);

    assertEq(executions.length, 4);

    assertEq(executions[0].target, token);
    assertEq(executions[0].value, 0);
    assertGt(executions[0].callData.length, 0);

    assertEq(executions[1].target, token);
    assertEq(executions[1].value, 0);
    assertGt(executions[1].callData.length, 0);

    bytes memory expectedCallData = abi.encodeCall(IERC4626.redeem, (prevHookAmount, address(this), address(this)));

    assertEq(executions[2].target, yieldSource);
    assertEq(executions[2].value, 0);
    assertEq(executions[2].callData, expectedCallData);

    assertEq(executions[3].target, token);
    assertEq(executions[3].value, 0);
    assertGt(executions[3].callData.length, 0);
  }

  function test_DepositHook_PrevHookAmount() public {
    address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
    MockHook(mockPrevHook).setOutAmount(prevHookAmount);

    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, true, address(0), uint256(0));
    Execution[] memory executions = depositHook.build(mockPrevHook, address(this), data);

    assertEq(executions.length, 1);

    bytes memory expectedCallData = abi.encodeCall(IERC4626.deposit, (prevHookAmount, address(this)));

    assertEq(executions[0].target, yieldSource);
    assertEq(executions[0].value, 0);
    assertEq(executions[0].callData, expectedCallData);
  }

  function test_RedeemHook_PrevHookAmount() public {
    address mockPrevHook = address(new MockHook(ISuperHook.HookType.OUTFLOW, token));
    MockHook(mockPrevHook).setOutAmount(prevHookAmount);

    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), amount, true);
    Execution[] memory executions = redeemHook.build(mockPrevHook, address(this), data);
    
    assertEq(executions.length, 1);

    bytes memory expectedCallData = abi.encodeCall(IERC4626.redeem, (prevHookAmount, address(this), address(this)));

    assertEq(executions[0].target, yieldSource);
    assertEq(executions[0].value, 0);
    assertEq(executions[0].callData, expectedCallData);
  }

  /*//////////////////////////////////////////////////////////////
                      DECODE AMOUNT TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_DecodeAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false);
    assertEq(approveAndDepositHook.decodeAmount(data), amount);
  }

  function test_ApproveAndRedeemHook_DecodeAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), shares, false);
    assertEq(approveAndRedeemHook.decodeAmount(data), amount);
  }

  function test_DepositHook_DecodeAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false);
    assertEq(depositHook.decodeAmount(data), amount);
  }

  function test_RedeemHook_DecodeAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), amount, false);
    assertEq(redeemHook.decodeAmount(data), amount);
  }

  /*//////////////////////////////////////////////////////////////
                DECODE USE PREVIOUS HOOK AMOUNT TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_DecodeUsePrevHookAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false);
    assertEq(approveAndDepositHook.decodeUsePrevHookAmount(data), false);
  }

  function test_ApproveAndRedeemHook_DecodeUsePrevHookAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), shares, false);
    assertEq(approveAndRedeemHook.decodeUsePrevHookAmount(data), false);
  }
  
  function test_DepositHook_DecodeUsePrevHookAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false);
    assertEq(depositHook.decodeUsePrevHookAmount(data), false);
  }

  function test_RedeemHook_DecodeUsePrevHookAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), amount, false);
    assertEq(redeemHook.decodeUsePrevHookAmount(data), false);
  }

  /*//////////////////////////////////////////////////////////////
                REPLACE CALLLDATA AMOUNT TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndRedeemHook_ReplaceCalldataAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), shares, false);
    bytes memory newData = approveAndRedeemHook.replaceCalldataAmount(data, prevHookAmount);
    assertEq(newData, abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), prevHookAmount, false));
  }

  function test_RedeemHook_ReplaceCalldataAmount() public view {
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), shares, false);
    bytes memory newData = redeemHook.replaceCalldataAmount(data, prevHookAmount);
    assertEq(newData, abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), prevHookAmount, false));
  }

  /*//////////////////////////////////////////////////////////////
                      PRE/POST EXECUTE TESTS
  //////////////////////////////////////////////////////////////*/
  function test_ApproveAndDepositHook_PrePostExecute() public {
    yieldSource = token; // for the .balanceOf call
    _getTokens(token, address(this), amount);

    bytes memory data = _encodeApproveAndDepositData();
    approveAndDepositHook.preExecute(address(0), address(this), data);
    assertEq(approveAndDepositHook.outAmount(), amount);

    approveAndDepositHook.postExecute(address(0), address(this), data);
    assertEq(approveAndDepositHook.outAmount(), 0);
  }

  function test_ApproveAndRedeemHook_PrePostExecute() public {
    yieldSource = token; // for the .balanceOf call
    _getTokens(token, address(this), amount);

    bytes memory data = _encodeApproveAndRedeemData();
    approveAndRedeemHook.preExecute(address(0), address(this), data);
    assertEq(approveAndRedeemHook.outAmount(), amount);

    approveAndRedeemHook.postExecute(address(0), address(this), data);
    assertEq(approveAndRedeemHook.outAmount(), 0);
  }

  function test_DepositHook_PrePostExecute() public {
    yieldSource = token; // for the .balanceOf call
    _getTokens(token, address(this), amount);

    bytes memory data = _encodeDepositData();
    depositHook.preExecute(address(0), address(this), data);
    assertEq(depositHook.outAmount(), amount);

    depositHook.postExecute(address(0), address(this), data);
    assertEq(depositHook.outAmount(), 0);
  }

  function test_RedeemHook_PrePostExecute() public {
    yieldSource = token; // for the .balanceOf call
    _getTokens(token, address(this), amount);

    bytes memory data = _encodeRedeemData();
    redeemHook.preExecute(address(0), address(this), data);
    assertEq(redeemHook.outAmount(), amount);

    redeemHook.postExecute(address(0), address(this), data);
    assertEq(redeemHook.outAmount(), 0);
  }

  /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  function _encodeApproveAndDepositData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false, address(0), uint256(0));
  }

  function _encodeApproveAndRedeemData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), shares, false);
  }

  function _encodeDepositData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, address(0), uint256(0));
  }

  function _encodeRedeemData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), shares, false);
  }
  
}