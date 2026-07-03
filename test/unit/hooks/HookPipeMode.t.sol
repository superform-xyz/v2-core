// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

/// @dev Mock TRANSFORM hook that sets outAmount and outToken in _postExecute
contract MockTransformHook is BaseHook {
    address public tokenToSet;
    uint256 public amountToSet;

    constructor() BaseHook(ISuperHook.HookType.NONACCOUNTING, bytes32("TRANSFORM_TEST")) {}

    function name() external pure override returns (string memory) {
        return "Mock Transform";
    }

    function description() external pure override returns (string memory) {
        return "Mock transform hook for testing";
    }

    function setOutput(address token, uint256 amount) external {
        tokenToSet = token;
        amountToSet = amount;
    }

    function _buildHookExecutions(address, address, bytes calldata)
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](0);
    }

    function _preExecute(address, address, bytes calldata) internal override {}

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(amountToSet, account);
        _setOutToken(tokenToSet, account);
    }
}

/// @dev Mock PASSTHROUGH hook — relies on BaseHook's default _preExecute auto-forward
contract MockPassthroughHook is BaseHook {
    constructor() BaseHook(ISuperHook.HookType.NONACCOUNTING, bytes32("PASSTHROUGH_TEST")) {}

    function name() external pure override returns (string memory) {
        return "Mock Passthrough";
    }

    function description() external pure override returns (string memory) {
        return "Mock passthrough hook for testing";
    }

    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    function _buildHookExecutions(address, address, bytes calldata)
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](0);
    }

    // No _preExecute override — uses BaseHook's default PASSTHROUGH auto-forward
    // No _postExecute override — passthrough hooks don't transform
}

contract HookPipeModeTest is Test {
    MockTransformHook transformHook;
    MockPassthroughHook passthroughHook;

    address constant ACCOUNT = address(0xBEEF);
    address constant TOKEN_A = address(0xA);
    address constant TOKEN_B = address(0xB);
    uint256 constant AMOUNT = 1000e18;

    function setUp() public {
        transformHook = new MockTransformHook();
        passthroughHook = new MockPassthroughHook();
    }

    /*//////////////////////////////////////////////////////////////
                       TRANSFORM MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TransformHook_SetsOutTokenAndAmount() public {
        transformHook.setOutput(TOKEN_A, AMOUNT);

        bytes memory data = "";
        vm.startPrank(ACCOUNT);
        transformHook.preExecute(address(0), ACCOUNT, data);
        transformHook.postExecute(address(0), ACCOUNT, data);
        vm.stopPrank();

        assertEq(transformHook.getOutAmount(ACCOUNT), AMOUNT);
        assertEq(transformHook.getOutToken(ACCOUNT), TOKEN_A);
    }

    function test_TransformHook_DefaultPipeMode() public view {
        // Transform is the default PipeMode — no override needed
        assertEq(transformHook.getOutAmount(ACCOUNT), 0);
        assertEq(transformHook.getOutToken(ACCOUNT), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                       PASSTHROUGH MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PassthroughHook_ForwardsFromPrevHook() public {
        transformHook.setOutput(TOKEN_A, AMOUNT);
        bytes memory data = "";

        // Step 1: Execute transform hook → sets outAmount + outToken
        vm.startPrank(ACCOUNT);
        transformHook.preExecute(address(0), ACCOUNT, data);
        transformHook.postExecute(address(0), ACCOUNT, data);

        // Step 2: Execute passthrough hook with transformHook as prevHook
        passthroughHook.preExecute(address(transformHook), ACCOUNT, data);
        passthroughHook.postExecute(address(transformHook), ACCOUNT, data);
        vm.stopPrank();

        // Verify passthrough forwarded transform hook's output
        assertEq(passthroughHook.getOutAmount(ACCOUNT), AMOUNT);
        assertEq(passthroughHook.getOutToken(ACCOUNT), TOKEN_A);
    }

    function test_PassthroughHook_NoPrevHook_ZeroValues() public {
        bytes memory data = "";

        vm.startPrank(ACCOUNT);
        passthroughHook.preExecute(address(0), ACCOUNT, data);
        passthroughHook.postExecute(address(0), ACCOUNT, data);
        vm.stopPrank();

        // With no prevHook, passthrough should have zero values
        assertEq(passthroughHook.getOutAmount(ACCOUNT), 0);
        assertEq(passthroughHook.getOutToken(ACCOUNT), address(0));
    }

    function test_PassthroughChain_MultiplePassthrough() public {
        MockPassthroughHook passthrough2 = new MockPassthroughHook();
        transformHook.setOutput(TOKEN_B, 500e18);
        bytes memory data = "";

        vm.startPrank(ACCOUNT);
        // Transform → Passthrough1 → Passthrough2
        transformHook.preExecute(address(0), ACCOUNT, data);
        transformHook.postExecute(address(0), ACCOUNT, data);

        passthroughHook.preExecute(address(transformHook), ACCOUNT, data);
        passthroughHook.postExecute(address(transformHook), ACCOUNT, data);

        passthrough2.preExecute(address(passthroughHook), ACCOUNT, data);
        passthrough2.postExecute(address(passthroughHook), ACCOUNT, data);
        vm.stopPrank();

        // All should carry the same values
        assertEq(passthrough2.getOutAmount(ACCOUNT), 500e18);
        assertEq(passthrough2.getOutToken(ACCOUNT), TOKEN_B);
    }

    function test_TransformOverridesPassthroughValues() public {
        MockTransformHook transform2 = new MockTransformHook();
        transform2.setOutput(TOKEN_B, 200e18);
        transformHook.setOutput(TOKEN_A, AMOUNT);
        bytes memory data = "";

        vm.startPrank(ACCOUNT);
        // Transform1 (TOKEN_A, 1000) → Transform2 (TOKEN_B, 200)
        transformHook.preExecute(address(0), ACCOUNT, data);
        transformHook.postExecute(address(0), ACCOUNT, data);

        transform2.preExecute(address(transformHook), ACCOUNT, data);
        transform2.postExecute(address(transformHook), ACCOUNT, data);
        vm.stopPrank();

        // Transform2 should have its OWN output, not Transform1's
        assertEq(transform2.getOutAmount(ACCOUNT), 200e18);
        assertEq(transform2.getOutToken(ACCOUNT), TOKEN_B);

        // Transform1's values should still be readable
        assertEq(transformHook.getOutAmount(ACCOUNT), AMOUNT);
        assertEq(transformHook.getOutToken(ACCOUNT), TOKEN_A);
    }
}
