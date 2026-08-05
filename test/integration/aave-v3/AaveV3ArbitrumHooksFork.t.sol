// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { AaveV3ChainForkBase } from "./AaveV3ChainForkBase.t.sol";

/// @notice Aave V3 loan-hook fork tests on Arbitrum (Core market).
/// @dev Auto-skips unless ARBITRUM_RPC_URL (archive) is configured. Pool is the canonical Aave V3
///      deployment shared with Optimism/Polygon (0x794a…14aD).
contract AaveV3ArbitrumHooksFork is AaveV3ChainForkBase {
    function _rpcKey() internal pure override returns (string memory) {
        return "ARBITRUM_RPC_URL";
    }

    function _forkBlock() internal pure override returns (uint256) {
        return 300_000_000;
    }

    function _pool() internal pure override returns (address) {
        return 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    }

    function _weth() internal pure override returns (address) {
        return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    }

    function _usdc() internal pure override returns (address) {
        return 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // native USDC
    }
}
