// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { AaveV3ChainForkBase } from "./AaveV3ChainForkBase.t.sol";

/// @notice Aave V3 loan-hook fork tests on Optimism (Core market).
contract AaveV3OptimismHooksFork is AaveV3ChainForkBase {
    function _rpcKey() internal pure override returns (string memory) {
        return "OPTIMISM_RPC_URL";
    }

    function _forkBlock() internal pure override returns (uint256) {
        return 128_000_000;
    }

    function _pool() internal pure override returns (address) {
        return 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    }

    function _weth() internal pure override returns (address) {
        return 0x4200000000000000000000000000000000000006;
    }

    function _usdc() internal pure override returns (address) {
        return 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    }
}
