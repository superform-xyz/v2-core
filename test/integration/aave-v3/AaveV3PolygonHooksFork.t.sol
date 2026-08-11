// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { AaveV3ChainForkBase } from "./AaveV3ChainForkBase.t.sol";

/// @notice Aave V3 loan-hook fork tests on Polygon (Core market).
/// @dev Auto-skips unless POLYGON_RPC_URL (archive) is configured. Pool is the canonical Aave V3
///      deployment shared with Arbitrum/Optimism (0x794a…14aD).
contract AaveV3PolygonHooksFork is AaveV3ChainForkBase {
    function _rpcKey() internal pure override returns (string memory) {
        return "POLYGON_RPC_URL";
    }

    function _forkBlock() internal pure override returns (uint256) {
        return 66_000_000;
    }

    function _pool() internal pure override returns (address) {
        return 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    }

    function _weth() internal pure override returns (address) {
        return 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    }

    function _usdc() internal pure override returns (address) {
        return 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; // native USDC
    }
}
