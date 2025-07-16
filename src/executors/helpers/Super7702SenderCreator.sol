// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/console2.sol";

/// @title Super7702SenderCreator
/// @author Superform Labs
/// @notice Deploys a temporary smart account for EIP-7702-style transaction execution
/// @dev This is compatible with EIP-7702-style `initCode`, where calldata starts with a known 0x7702 prefix.
contract Super7702SenderCreator {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    bytes2 internal constant INITCODE_EIP7702_MARKER = 0x7702;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_7702_INITCODE_LENGTH();
    error INVALID_7702_MARKER();

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createSender(bytes calldata initCode) external returns (address sender) {
        console2.log("----- Super7702SenderCreator initCode.length", initCode.length);
        // 0x7702 || factory address (20 bytes) || init calldata
        if (initCode.length < 22) {
            revert INVALID_7702_INITCODE_LENGTH();
        }

        bytes2 marker = bytes2(initCode[0:2]);
        if (marker != INITCODE_EIP7702_MARKER) {
            revert INVALID_7702_MARKER();
        }

        address factory = address(bytes20(initCode[2:22]));
        console2.log("----- Super7702SenderCreator factory", factory);
        bytes calldata factoryCallData = initCode[22:];

        (bool success, bytes memory returnData) = factory.call(factoryCallData);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        sender = abi.decode(returnData, (address));
    }
}