// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import "forge-std/Test.sol";

contract CurveTest is Test {
    error INVALID_SELECTOR_OFFSET();

    // Curve Pool function selectors for different `coins` methods. For details, see contracts/interfaces/ICurvePool.sol
    bytes32 private constant _CURVE_COINS_SELECTORS = 0x87cb4f5723746eb8c6610657b739953eb9947eb0000000000000000000000000;

    uint256 private constant _CURVE_TO_COINS_SELECTOR_OFFSET = 208;
    uint256 private constant _CURVE_TO_COINS_SELECTOR_MASK = 0xff;
    uint256 private constant _CURVE_TO_COINS_ARG_OFFSET = 216;
    uint256 private constant _CURVE_TO_COINS_ARG_MASK = 0xff;

    uint256[] offsets = [0, 4, 8, 12, 16];

    function testEquivalent() public view {
        uint256 dstTokenIndex = 72;
        uint256 selectorOffset;
        uint256 dex;

        for (uint256 i; i < offsets.length; i++) {
            selectorOffset = offsets[i];
            dex = uint256(uint160(address(this))) | (selectorOffset << _CURVE_TO_COINS_SELECTOR_OFFSET)
                | (dstTokenIndex << _CURVE_TO_COINS_ARG_OFFSET);
            assertEq(curve_toToken(dex), own_toToken(dex));
        }
    }

    function own_toToken(uint256 dex) internal pure returns (address) {
        uint256 selectorOffset = (dex >> _CURVE_TO_COINS_SELECTOR_OFFSET) & _CURVE_TO_COINS_SELECTOR_MASK;
        uint256 dstTokenIndex = (dex >> _CURVE_TO_COINS_ARG_OFFSET) & _CURVE_TO_COINS_ARG_MASK;

        address dstToken;
        if (selectorOffset == 0) {
            dstToken = CurveTest(address(uint160(dex))).base_coins(dstTokenIndex);
        } else if (selectorOffset == 4) {
            dstToken = CurveTest(address(uint160(dex))).coins(int128(uint128(dstTokenIndex)));
        } else if (selectorOffset == 8) {
            dstToken = CurveTest(address(uint160(dex))).coins(dstTokenIndex);
        } else if (selectorOffset == 12) {
            dstToken = CurveTest(address(uint160(dex))).underlying_coins(int128(uint128(dstTokenIndex)));
        } else if (selectorOffset == 16) {
            dstToken = CurveTest(address(uint160(dex))).underlying_coins(dstTokenIndex);
        } else {
            revert INVALID_SELECTOR_OFFSET();
        }

        return dstToken;
    }

    function curve_toToken(uint256 dex) internal view returns (address toToken) {
        assembly {
            function curveCoins(pool, selectorOffset, index) -> coin {
                mstore(0, _CURVE_COINS_SELECTORS)
                mstore(add(selectorOffset, 4), index)
                if iszero(staticcall(gas(), pool, selectorOffset, 0x24, 0, 0x20)) { revert(0, 0) }
                coin := mload(0)
            }

            {
                // Stack too deep
                let pool := and(dex, 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                let toSelectorOffset := and(shr(_CURVE_TO_COINS_SELECTOR_OFFSET, dex), _CURVE_TO_COINS_SELECTOR_MASK)
                let toTokenIndex := and(shr(_CURVE_TO_COINS_ARG_OFFSET, dex), _CURVE_TO_COINS_ARG_MASK)
                toToken := curveCoins(pool, toSelectorOffset, toTokenIndex)
            }
        }
    }

    function base_coins(uint256) external pure returns (address) {
        return address(uint160(uint256(keccak256(msg.data))));
    }

    function coins(int128) external pure returns (address) {
        return address(uint160(uint256(keccak256(msg.data))));
    }

    function coins(uint256) external pure returns (address) {
        return address(uint160(uint256(keccak256(msg.data))));
    }

    function underlying_coins(int128) external pure returns (address) {
        return address(uint160(uint256(keccak256(msg.data))));
    }

    function underlying_coins(uint256) external pure returns (address) {
        return address(uint160(uint256(keccak256(msg.data))));
    }
}
