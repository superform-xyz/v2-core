// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISuperPositions {
    error NOT_RELAYER_SENTINEL();
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mint tokens to an address
    /// @param to_ The address to mint tokens to
    /// @param amount_ The amount of tokens to mint

    function mint(address to_, uint256 amount_) external;
}
