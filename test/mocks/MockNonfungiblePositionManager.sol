// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

/// @title MockNonfungiblePositionManager
/// @notice Mock for unit testing UniV3CLPYieldSourceOracle's getBalanceOfOwner
contract MockNonfungiblePositionManager {
    struct Position {
        address token0;
        address token1;
        uint24 feeOrTickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    mapping(uint256 => Position) private _positions;
    mapping(address => uint256[]) private _ownedTokens;
    uint256 private _nextTokenId = 1;

    /// @notice Mint a mock position NFT to owner
    function mint(
        address owner,
        address token0,
        address token1,
        uint24 feeOrTickSpacing,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    )
        external
        returns (uint256 tokenId)
    {
        tokenId = _nextTokenId++;
        _positions[tokenId] = Position(token0, token1, feeOrTickSpacing, tickLower, tickUpper, liquidity);
        _ownedTokens[owner].push(tokenId);
    }

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
        )
    {
        Position memory p = _positions[tokenId];
        return (0, address(0), p.token0, p.token1, p.feeOrTickSpacing, p.tickLower, p.tickUpper, p.liquidity, 0, 0, 0, 0);
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _ownedTokens[owner].length;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        return _ownedTokens[owner][index];
    }
}
