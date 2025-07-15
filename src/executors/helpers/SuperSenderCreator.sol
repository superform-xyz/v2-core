// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;


/// @title SuperSenderCreator
/// @author Superform Labs
/// @notice Contract to create sender accounts from initCode
/// @dev This contract is used by SuperDestinationExecutor to create sender accounts
contract SuperSenderCreator {
     /**
     * call the "initCode" factory to create and return the sender account address
     * @param initCode the initCode value from a UserOp. contains 20 bytes of factory address, followed by calldata
     * @return sender the returned address of the created account, or zero address on failure.
     */
    function createSender(bytes calldata initCode) external returns (address sender) {
        address initAddress = address(bytes20(initCode[0 : 20]));
        bytes memory initCallData = initCode[20 :];
        (bool success, bytes memory returnData) = initAddress.call(initCallData);
        if (!success) {
            return address(0);
        }
        sender = abi.decode(returnData, (address));
    }
}