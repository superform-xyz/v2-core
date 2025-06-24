// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndDeposit4626VaultHook } from
    "../../../../../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Deposit4626VaultHook } from "../../../../../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../../../../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract ERC4626VaultHooksTest is Helpers {
    ApproveAndDeposit4626VaultHook public approveAndDepositHook;
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
        depositHook = new Deposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
    }

    function test_Constructors() public view {
        assertEq(uint256(approveAndDepositHook.hookType()), uint256(ISuperHook.HookType.INFLOW));
        assertEq(uint256(depositHook.hookType()), uint256(ISuperHook.HookType.INFLOW));
        assertEq(uint256(redeemHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndDepositHook_Build() public view {
        bytes memory data = _encodeApproveAndDepositData();
        Execution[] memory executions = approveAndDepositHook.build(address(0), address(this), data);

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
        bytes memory data = _encodeDepositData();
        Execution[] memory executions = depositHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_RedeemHook_Build() public view {
        bytes memory data = _encodeRedeemData();
        Execution[] memory executions = redeemHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ZERO ADDRESS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndDepositHook_ZeroAddress() public {
        address _yieldSource = yieldSource;

        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndDepositHook.build(
            address(0), address(this), abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false)
        );

        yieldSource = _yieldSource;
        token = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndDepositHook.build(
            address(0), address(this), abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false)
        );
    }

    function test_DepositHook_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        depositHook.build(address(0), address(this), abi.encodePacked(yieldSourceOracleId, address(0), amount, false));
    }

    function test_RedeemHook_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        redeemHook.build(
            address(0), address(this), abi.encodePacked(yieldSourceOracleId, address(0), address(this), shares, false)
        );
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
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, prevHookAmount, true);
        Execution[] memory executions = approveAndDepositHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 6);

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, token);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

        bytes memory expectedCallData = abi.encodeCall(IERC4626.deposit, (prevHookAmount, address(this)));

        assertEq(executions[3].target, yieldSource);
        assertEq(executions[3].value, 0);
        assertEq(executions[3].callData, expectedCallData);

        assertEq(executions[4].target, token);
        assertEq(executions[4].value, 0);
        assertGt(executions[4].callData.length, 0);
    }

    function test_DepositHook_PrevHookAmount() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, amount, true, address(0), uint256(0));
        Execution[] memory executions = depositHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData = abi.encodeCall(IERC4626.deposit, (prevHookAmount, address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, expectedCallData);
    }

    function test_RedeemHook_PrevHookAmount() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.OUTFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), amount, true);
        Execution[] memory executions = redeemHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);

        bytes memory expectedCallData = abi.encodeCall(IERC4626.redeem, (prevHookAmount, address(this), address(this)));

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, expectedCallData);
    }

    /*//////////////////////////////////////////////////////////////
                        DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ApproveAndDepositHook_DecodeAmount() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false);
        assertEq(approveAndDepositHook.decodeAmount(data), amount);
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
                      OTHER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_inspect() public view {
        bytes memory argsEncoded = depositHook.inspect(_encodeDepositData());
        assertGt(argsEncoded.length, 0);

        argsEncoded = redeemHook.inspect(_encodeRedeemData());
        assertGt(argsEncoded.length, 0);

        argsEncoded = approveAndDepositHook.inspect(_encodeApproveAndDepositData());
        assertGt(argsEncoded.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _encodeApproveAndDepositData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, false, address(0), uint256(0));
    }

    function _encodeDepositData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, false, address(0), uint256(0));
    }

    function _encodeRedeemData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, address(this), shares, false);
    }
}
