// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title MockedEntrypoint
/// @author Superform Labs
/// @notice Mocked entrypoint contract for gas estimation of account calls
/// @dev This contract stores signature data and estimates gas consumption for account calls
contract MockedEntrypoint {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Estimate gas consumption for an account call after storing signature data
    /// @dev First stores signature data in the supervalidator, then executes the account call and measures gas
    /// @param supervalidator The address of the SuperValidator contract (storage contract)
    /// @param sigData The signature data to store
    /// @param account The account address to associate with the signature and execute the call on
    /// @param accountCallData The calldata to execute on the account
    /// @return gasConsumed The gas consumed by the account call
    function estimateCall(
        address supervalidator,
        bytes calldata sigData,
        address account,
        bytes calldata accountCallData
    ) external returns (uint256 gasConsumed) {
        // First store the signature data in the supervalidator
        (bool storeSuccess, ) = supervalidator.call(
            abi.encodeWithSignature(
                "storeSignatureData(bytes,address)",
                sigData,
                account
            )
        );
        require(storeSuccess, "Failed to store signature data");

        // Measure gas before the account call
        uint256 gasBefore = gasleft();

        // Execute the call on the account
        (bool callSuccess, ) = account.call(accountCallData);
        require(callSuccess, "Account call failed");

        // Calculate gas consumed
        uint256 gasAfter = gasleft();
        gasConsumed = gasBefore - gasAfter;

        return gasConsumed;
    }
}
