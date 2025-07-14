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
     * @return delegatee the address of the delegatee account. Same as `sender` for non-7702 flow
     */
    function createSender(bytes calldata initCode, address) external returns (address sender, address delegatee) {
        address initAddress = address(bytes20(initCode[0 : 20]));
        bytes memory initCallData = initCode[20 :];
        bool success;
        /* solhint-disable no-inline-assembly */
        assembly {
            success := call(gas(), initAddress, 0, add(initCallData, 0x20), mload(initCallData), 0, 32)
            sender := mload(0)
        }
        if (!success) {
            sender = address(0);
        }
        delegatee = sender;
    }
}