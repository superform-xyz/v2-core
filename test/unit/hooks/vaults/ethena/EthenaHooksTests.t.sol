// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Helpers} from "../../../../utils/Helpers.sol";
import {MockERC20} from "../../../../mocks/MockERC20.sol";
import {BaseHook} from "../../../../../src/core/hooks/BaseHook.sol";
import {ISuperHook} from "../../../../../src/core/interfaces/ISuperHook.sol";
import {MockHook} from "../../../../mocks/MockHook.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IStakedUSDeCooldown} from "../../../../../src/vendor/ethena/IStakedUSDeCooldown.sol";
import {HookSubTypes} from "../../../../../src/core/libraries/HookSubTypes.sol";

// Hooks
import {EthenaCooldownSharesHook} from "../../../../../src/core/hooks/vaults/ethena/EthenaCooldownSharesHook.sol";
import {EthenaUnstakeHook} from "../../../../../src/core/hooks/vaults/ethena/EthenaUnstakeHook.sol";

contract EthenaHooksTests is Helpers {
    EthenaCooldownSharesHook cooldownSharesHook;
    EthenaUnstakeHook unstakeHook;

    MockERC20 yieldSource;
    bytes4 yieldSourceOracleId;
    uint256 amount;
    uint256 prevHookAmount;
    address receiver;

    function setUp() public {
        cooldownSharesHook = new EthenaCooldownSharesHook();
        unstakeHook = new EthenaUnstakeHook();

        yieldSource = new MockERC20("Yield Source", "YS", 18);
        yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
        amount = 1000e18;
        prevHookAmount = 2000e18;
        receiver = address(this);
    }

    /*//////////////////////////////////////////////////////////////
                      CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaCooldownSharesHook_Constructor() public view {
        assertEq(uint256(cooldownSharesHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_EthenaUnstakeHook_Constructor() public view {
        assertEq(uint256(unstakeHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_EthenaCooldownSharesSubHookType_Constructor() public view {
        assertEq(
            cooldownSharesHook.subType(),
            HookSubTypes.getHookSubType("Cooldown")
        );
    }

    /*//////////////////////////////////////////////////////////////
                            BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaCooldownSharesHook_build() public view {
        bytes memory data = _encodeCooldownData(false);
        Execution[] memory executions = cooldownSharesHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(yieldSource));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_EthenaUnstakeHook_build() public view {
        bytes memory data = _encodeUnstakeData();
        Execution[] memory executions = unstakeHook.build(address(0), address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(yieldSource));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD REVERT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaUnstakeHook_BuildRevert_InvalidYieldSource() public {
        bytes memory data = _encodeUnstakeDataWithZeroYieldSource();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        unstakeHook.build(address(0), address(this), data);
    }

    function test_EthenaCooldownSharesHook_BuildRevert_InvalidShares() public {
        bytes memory data = _encodeCooldownDataWithZeroShares();
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        cooldownSharesHook.build(address(0), address(this), data);
    }

    function test_EthenaCooldownSharesHook_BuildRevert_InvalidYieldSource() public {
        bytes memory data = _encodeCooldownDataWithZeroYieldSource();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        cooldownSharesHook.build(address(0), address(this), data);
    }

    function test_EthenaCooldownSharesHook_BuildRevert_InvalidReceiver() public {
        bytes memory data = _encodeCooldownData(false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        cooldownSharesHook.build(address(0), address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD WITH PREVIOUS HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaCooldownSharesHook_BuildWithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(yieldSource)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeCooldownData(true);
        Execution[] memory executions = cooldownSharesHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(yieldSource));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_EthenaUnstakeHook_BuildWithPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(yieldSource)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeUnstakeData();
        Execution[] memory executions = unstakeHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(yieldSource));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          DECODE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaCooldownSharesHook_DecodeAmount() public view {
        bytes memory data = _encodeCooldownData(false);
        uint256 decodedAmount = cooldownSharesHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_EthenaUnstakeHook_DecodeAmount() public view {
        bytes memory data = _encodeUnstakeData();
        uint256 decodedAmount = unstakeHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       REPLACE CALLDATA AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaUnstakeHook_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeUnstakeData();
        bytes memory replacedData = unstakeHook.replaceCalldataAmount(data, prevHookAmount);

        // Verify the length is the same
        assertEq(replacedData.length, data.length);

        // Verify the amount was replaced
        uint256 replacedAmount = unstakeHook.decodeAmount(replacedData);
        assertEq(replacedAmount, prevHookAmount);
    }

    /*//////////////////////////////////////////////////////////////
                          PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaCooldownSharesHook_PrePostExecute() public {
        _getTokens(address(yieldSource), address(this), amount);

        bytes memory data = _encodeCooldownData(false);
        cooldownSharesHook.preExecute(address(0), address(this), data);
        assertEq(cooldownSharesHook.usedShares(), amount, "A");

        cooldownSharesHook.postExecute(address(0), address(this), data);
        assertEq(cooldownSharesHook.usedShares(), 0, "B");
    }

    function test_EthenaUnstakeHook_PrePostExecute() public {
        _getTokens(address(yieldSource), address(this), amount);

        bytes memory data = _encodeUnstakeData();
        unstakeHook.preExecute(address(0), address(this), data);
        assertEq(unstakeHook.outAmount(), amount);

        unstakeHook.postExecute(address(0), address(this), data);
        assertEq(unstakeHook.outAmount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                     GET USED ASSETS OR SHARES TESTS
    //////////////////////////////////////////////////////////////*/
    function test_EthenaCooldownSharesHook_GetUsedAssetsOrShares() public {
        _getTokens(address(yieldSource), address(this), amount);

        bytes memory data = _encodeCooldownData(false);
        cooldownSharesHook.preExecute(address(0), address(this), data);

        (uint256 usedAssets, bool isShares) = cooldownSharesHook.getUsedAssetsOrShares();
        assertEq(usedAssets, amount);
        assertEq(isShares, true);
    }

    function test_cooldownSharesHook_Inspector() public view {
        bytes memory data = _encodeCooldownData(false);
        bytes memory argsEncoded = cooldownSharesHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_unstakeHook_Inspector() public view {
        bytes memory data = _encodeUnstakeData();
        bytes memory argsEncoded = unstakeHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/
    function _encodeCooldownData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(yieldSource), amount, usePrevHook);
    }

    function _encodeCooldownDataWithZeroShares() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(yieldSource), uint256(0), false);
    }

    function _encodeCooldownDataWithZeroYieldSource() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(0), amount, false);
    }

    function _encodeUnstakeData() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(yieldSource), amount, false, address(0), uint256(1));
    }

    function _encodeUnstakeDataWithZeroYieldSource() internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, address(0), amount, false, address(0), uint256(1));
    }
}
