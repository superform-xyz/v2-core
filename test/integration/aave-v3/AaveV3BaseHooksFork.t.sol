// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { AaveV3ChainForkBase } from "./AaveV3ChainForkBase.t.sol";

/// @notice Aave V3 loan-hook fork tests on Base (Core market).
contract AaveV3BaseHooksFork is AaveV3ChainForkBase {
    function _rpcKey() internal pure override returns (string memory) {
        return "BASE_RPC_URL";
    }

    function _forkBlock() internal pure override returns (uint256) {
        return 24_000_000;
    }

    function _pool() internal pure override returns (address) {
        return 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    }

    function _weth() internal pure override returns (address) {
        return 0x4200000000000000000000000000000000000006;
    }

    function _usdc() internal pure override returns (address) {
        return 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    }
}
