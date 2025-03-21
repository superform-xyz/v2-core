// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ISuperGasTank } from "../interfaces/ISuperGasTank.sol";

/// @title SuperGasTank
/// @author Superform Labs
/// @notice A contract that holds ETH and allows only whitelisted contracts to withdraw from it
/// @dev This is used to fund gas for cross-chain operations
contract SuperGasTank is ISuperGasTank, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping to track allowlisted contracts
    mapping(address => bool) private allowlist;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address owner_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the contract to receive ETH
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGasTank
    function isAllowlisted(address contractAddress) external view returns (bool) {
        return allowlist[contractAddress];
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGasTank
    /// @dev Only callable by the owner
    function addToAllowlist(address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert ZERO_ADDRESS();

        allowlist[contractAddress] = true;
        emit AllowlistAddressAdded(contractAddress);
    }

    /// @inheritdoc ISuperGasTank
    /// @dev Only callable by the owner
    function removeFromAllowlist(address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert ZERO_ADDRESS();

        allowlist[contractAddress] = false;
        emit AllowlistAddressRemoved(contractAddress);
    }

    /// @inheritdoc ISuperGasTank
    function withdrawETH(uint256 amount, address payable receiver) external onlyOwner {
        if (!allowlist[msg.sender]) revert NOT_ALLOWLISTED();
        if (amount == 0) revert ZERO_AMOUNT();
        if (receiver == address(0)) revert ZERO_ADDRESS();

        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert TRANSFER_FAILED();

        emit ETHWithdrawn(receiver, amount);
    }
}
