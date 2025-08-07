// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;


contract MockPreValidationHook {
    /// @dev The packed ERC4337 user operation (userOp) struct.
    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode; // Factory address and `factoryData` (or empty).
        bytes callData;
        bytes32 accountGasLimits; // `verificationGas` (16 bytes) and `callGas` (16 bytes).
        uint256 preVerificationGas;
        bytes32 gasFees; // `maxPriorityFee` (16 bytes) and `maxFeePerGas` (16 bytes).
        bytes paymasterAndData; // Paymaster fields (or empty).
        bytes signature;
    }

    uint256 constant MODULE_TYPE_PREVALIDATION_HOOK_ERC1271 = 8;
    uint256 constant MODULE_TYPE_PREVALIDATION_HOOK_ERC4337 = 9;

    event HookOnInstallCalled(bytes32 data);

    function onInstall(bytes calldata data) external {
        if (data.length >= 0x20) {
            emit HookOnInstallCalled(bytes32(data[0:32]));
        }
    }

    function onUninstall(bytes calldata) external { }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC4337 || moduleTypeId == MODULE_TYPE_PREVALIDATION_HOOK_ERC1271;
    }

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function preValidationHookERC1271(address, bytes32 hash, bytes calldata data) external pure returns (bytes32 hookHash, bytes memory hookSignature) {
        return (hash, data);
    }

    function preValidationHookERC4337(
        PackedUserOperation calldata userOp,
        uint256,
        bytes32 userOpHash
    )
        external
        pure
        returns (bytes32 hookHash, bytes memory hookSignature)
    {
        return (userOpHash, userOp.signature);
    }
}
