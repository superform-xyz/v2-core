// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    approveAndDepositHook.build(address(0), address(this), _encodeApproveAndDepositData());

    yieldSource = _yieldSource;
    token = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndDepositHook.build(address(0), address(this), _encodeApproveAndDepositData());
  }

  function test_DepositHook_ZeroAddress() public {
    address _yieldSource = yieldSource;

    yieldSource = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    depositHook.build(address(0), address(this), _encodeDepositData());
  }

  function test_ApproveAndRedeemHook_ZeroAddress() public {
    address _yieldSource = yieldSource;

    yieldSource = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndRedeemHook.build(address(0), address(this), _encodeApproveAndRedeemData());

    yieldSource = _yieldSource;
    token = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    approveAndRedeemHook.build(address(0), address(this), _encodeApproveAndRedeemData());
  }

  function test_RedeemHook_ZeroAddress() public {
    address _yieldSource = yieldSource;

    yieldSource = address(0);
    vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
    redeemHook.build(address(0), address(this), _encodeRedeemData());
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
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, uint256(0), false);
    approveAndRedeemHook.build(address(0), address(this), data);
  }

  function test_DepositHook_ZeroAmount() public {
    amount = 0;
    vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
    depositHook.build(address(0), address(this), data);
  }

  function test_RedeemHook_ZeroAmount() public {
    amount = 0;
    vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
    bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, uint256(0), false);
    redeemHook.build(address(0), address(this), data);
  }

  /*//////////////////////////////////////////////////////////////
                  PREVIOUS HOOK AMOUNT TESTS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  function _encodeApproveAndDepositData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false);
  }

  function _encodeApproveAndRedeemData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, token, address(this), shares, false);
  }

  function _encodeDepositData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false);
  }

  function _encodeRedeemData() internal view returns (bytes memory) {
    return abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), shares, false);
  }
  
}