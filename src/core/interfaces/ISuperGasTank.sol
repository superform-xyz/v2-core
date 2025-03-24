// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperGasTank
/// @author Superform Labs
/// @notice Interface for SuperGasTank contract that manages ETH for gas payments
interface ISuperGasTank {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AllowlistAddressAdded(address indexed contractAddress);
    event AllowlistAddressRemoved(address indexed contractAddress);
    event ETHWithdrawn(address indexed receiver, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_ALLOWLISTED();
    error TRANSFER_FAILED();
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Checks if a contract is allowlisted to withdraw ETH
    /// @param contractAddress Address to check
    /// @return True if the contract is allowlisted, false otherwise
    function isAllowlisted(address contractAddress) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Adds a contract to the allowlist
    /// @param contractAddress Contract address to add
    function addToAllowlist(address contractAddress) external;

    /// @notice Removes a contract from the allowlist
    /// @param contractAddress Contract address to remove
    function removeFromAllowlist(address contractAddress) external;

    /// @notice Withdraws ETH from the gas tank
    /// @param amount Amount of ETH to withdraw
    /// @param receiver Address to receive the ETH
    function withdrawETH(uint256 amount, address payable receiver) external;
}
