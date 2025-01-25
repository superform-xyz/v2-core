// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IHookDataEncoder {
    /// @notice Encode hook data for deposit operation
    /// @param vault The vault address
    /// @param receiver The receiver address
    /// @param assets The amount of assets to deposit
    /// @param extraData Any additional data needed for the specific vault standard
    function encodeDepositData(
        address vault,
        address receiver,
        uint256 assets,
        bytes memory extraData
    ) external view returns (bytes memory);

    /// @notice Encode hook data for withdraw operation
    /// @param vault The vault address
    /// @param receiver The receiver address
    /// @param owner The owner address
    /// @param shares The amount of shares to withdraw
    /// @param extraData Any additional data needed for the specific vault standard
    function encodeWithdrawData(
        address vault,
        address receiver,
        address owner,
        uint256 shares,
        bytes memory extraData
    ) external view returns (bytes memory);

    /// @notice Get the vault identifier
    function getType() external pure returns (string memory);
} 