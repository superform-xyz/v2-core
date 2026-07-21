// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title INonfungiblePositionManager
/// @notice Minimal interface for UniV3-compatible NFT position managers
/// @dev Compatible with:
///       - Uniswap V3 NonfungiblePositionManager (fee at position[4])
///       - Aerodrome Slipstream NonfungiblePositionManager (tickSpacing at position[4])
///      NOT compatible with Algebra / SparkDEX which omits the fee/tickSpacing field entirely
///      (use a separate Algebra-specific interface for those DEXes).
///
///      ABI note: both UniV3 and Slipstream place a uint24/int24 value at the same byte offset
///      before tickLower, so decoding is correct for both even though the field meaning differs.
interface INonfungiblePositionManager {
    /// @notice Returns the position information associated with a given token ID
    /// @param tokenId The ID of the token that represents the position
    /// @return nonce The nonce for permits
    /// @return operator The approved address of the token
    /// @return token0 The address of the token0 for a specific pool
    /// @return token1 The address of the token1 for a specific pool
    /// @return feeOrTickSpacing The fee tier (UniV3) or tick spacing (Slipstream) of the pool
    /// @return tickLower The lower end of the tick range for the position
    /// @return tickUpper The upper end of the tick range for the position
    /// @return liquidity The liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
    /// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 feeOrTickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns the number of NFT positions owned by a given address
    function balanceOf(address owner) external view returns (uint256);

    /// @notice Returns the tokenId at a given index of the positions list for the given owner
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}
