// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISuperHook, ISuperHookResult, ISuperHookResultOutflow, Execution } from "../../src/interfaces/ISuperHook.sol";

contract MockHook is ISuperHook, ISuperHookResult, ISuperHookResultOutflow {
    HookType public hookType;
    uint256 public outAmount;
    uint256 public usedShares;
    address public asset;
    bool public preExecuteCalled;
    bool public postExecuteCalled;
    Execution[] public executions;
    bool public preExecuteMutex;
    bool public postExecuteMutex;
    address public caller;

    error INCOMPLETE_HOOK_EXECUTION();

    constructor(HookType _hookType, address _asset) {
        hookType = _hookType;
        asset = _asset;
    }

    function subtype() external pure returns (bytes32) {
        return bytes32("Mock");
    }

    function setOutAmount(uint256 _outAmount, address) external {
        outAmount = _outAmount;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }

    function setUsedShares(uint256 _usedShares) external {
        usedShares = _usedShares;
    }

    function setExecutions(Execution[] memory _executions) external {
        delete executions;
        for (uint256 i = 0; i < _executions.length; i++) {
            executions.push(_executions[i]);
        }
    }

    function setAsset(address _asset) external {
        asset = _asset;
    }

    function preExecute(address, address, bytes memory) external override {
        preExecuteCalled = true;
    }

    /// @dev Standard build pattern - MUST include preExecute first, postExecute last
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes calldata hookData
    )
        external
        view
        virtual
        returns (Execution[] memory _executions)
    {
        // Get hook-specific executions
        Execution[] memory hookExecutions = _buildHookExecutions(prevHook, account, hookData);

        // Always include pre + hook + post
        _executions = new Execution[](hookExecutions.length + 2);

        // FIRST: preExecute
        _executions[0] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.preExecute, (prevHook, account, hookData))
        });

        // MIDDLE: hook-specific operations
        for (uint256 i = 0; i < hookExecutions.length; i++) {
            _executions[i + 1] = hookExecutions[i];
        }

        // LAST: postExecute
        _executions[_executions.length - 1] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.postExecute, (prevHook, account, hookData))
        });
    }

    function _buildHookExecutions(address, address, bytes calldata) internal view returns (Execution[] memory) {
        Execution[] memory result = new Execution[](executions.length);
        for (uint256 i = 0; i < executions.length; i++) {
            result[i] = executions[i];
        }
        return result;
    }

    function postExecute(address, address, bytes memory) external override {
        postExecuteCalled = true;
    }

    function lockForSP() external pure returns (bool) {
        return false;
    }

    function spToken() external pure override returns (address) {
        return address(0);
    }

    function vaultBank() public pure returns (address) {
        return address(0);
    }

    function dstChainId() public pure returns (uint256) {
        return 0;
    }

    /// @notice Resets execution state - ONLY callable by executor after accounting
    function resetExecutionState(address) external {
        // Reset both mutexes
        preExecuteMutex = false;
        postExecuteMutex = false;
    }

    function setExecutionContext(address _caller) external {
        caller = _caller;
    }

    function executionNonce() external pure returns (uint256) {
        return 1;
    }

    function lastCaller() external view returns (address) {
        return msg.sender;
    }
}
