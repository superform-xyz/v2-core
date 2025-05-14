// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Helpers } from "../../utils/Helpers.sol";
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";

contract TestHook is BaseHook {
    constructor(ISuperHook.HookType hookType_, bytes32 subType_) BaseHook(hookType_, subType_) { }

    function _preExecute(address prevHook, address account, bytes calldata data) internal override { }

    function _postExecute(address prevHook, address account, bytes calldata data) internal override { }

    // Expose internal functions for testing
    function testDecodeBool(bytes memory data, uint256 offset) external pure returns (bool) {
        return _decodeBool(data, offset);
    }

    function testReplaceCalldataAmount(
        bytes memory data,
        uint256 amount,
        uint256 offset
    )
        external
        pure
        returns (bytes memory)
    {
        return _replaceCalldataAmount(data, amount, offset);
    }
}

contract BaseHookTest is Helpers {
    TestHook public hook;
    bytes32 public subType;
    ISuperHook.HookType public hookType;

    function setUp() public {
        subType = bytes32("TEST_SUBTYPE");
        hookType = ISuperHook.HookType.INFLOW;
        hook = new TestHook(hookType, subType);
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(hookType));
        assertEq(hook.subtype(), subType);
    }

    /*//////////////////////////////////////////////////////////////
                          EXECUTION SECURITY TESTS
    //////////////////////////////////////////////////////////////*/
    function test_GetExecutionCaller() public {
        // First call should set the caller
        hook.preExecute(address(0), address(this), "");
        assertEq(hook.getExecutionCaller(), address(this));

        // Subsequent calls from same caller should succeed
        hook.preExecute(address(0), address(this), "");
        assertEq(hook.getExecutionCaller(), address(this));
    }

    function test_GetExecutionCaller_NotAuthorized() public {
        // First call sets the caller
        hook.preExecute(address(0), address(this), "");

        // Call from different address should revert
        vm.prank(address(1));
        vm.expectRevert(BaseHook.NOT_AUTHORIZED.selector);
        hook.preExecute(address(0), address(this), "");
    }

    /*//////////////////////////////////////////////////////////////
                          PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_PreExecute() public {
        bytes memory data = abi.encodePacked(uint256(100));
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.getExecutionCaller(), address(this));
    }

    function test_PostExecute() public {
        bytes memory data = abi.encodePacked(uint256(100));
        hook.postExecute(address(0), address(this), data);
        assertEq(hook.getExecutionCaller(), address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER METHOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_DecodeBool() public view {
        bytes memory data = abi.encodePacked(true);
        assertTrue(hook.testDecodeBool(data, 0));

        data = abi.encodePacked(false);
        assertFalse(hook.testDecodeBool(data, 0));
    }

    function test_ReplaceCalldataAmount() public view {
        bytes memory data = abi.encodePacked(uint256(100));
        bytes memory newData = hook.testReplaceCalldataAmount(data, 200, 0);
        assertEq(abi.decode(newData, (uint256)), 200);
    }

    function test_ReplaceCalldataAmount_Offset() public view {
        bytes memory data = abi.encodePacked(uint256(100), uint256(200));
        bytes memory newData = hook.testReplaceCalldataAmount(data, 300, 32);

        // Create a new bytes array with just the second uint256
        bytes memory secondValue = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            secondValue[i] = newData[i + 32];
        }

        assertEq(abi.decode(secondValue, (uint256)), 300);
    }
}
