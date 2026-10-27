// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Vm } from "forge-std/Vm.sol";

/// @dev Foundry's cheatcode address, shared by the forwarder and its installer.
Vm constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

/// @title HyperCorePrecompileForwarder
/// @notice Test-only stand-in for the HyperCore read precompiles on a Foundry fork of HyperEVM.
/// @dev The read precompiles (0x800+) are node logic, not EVM bytecode: on a fork the addresses are code-less and
///      a local `staticcall` returns nothing. This contract is `vm.etch`ed at each precompile address; its fallback
///      forwards the RAW calldata it receives to the live node via `vm.rpc("eth_call")` against `address(this)`
///      and returns the live returndata verbatim, so contracts under test (the oracle, the read library) run
///      UNMODIFIED on the fork and read genuine HyperCore state. Unlike the real precompiles, consecutive reads
///      may observe different Core states (the live chain advances between RPC round trips), so live-figure
///      assertions need tolerances; static fields (coin, szDecimals, leverage) are exact. A live precompile
///      error surfaces as a revert, which is what the real precompile does too (minus the gas burn). Same
///      technique as Hyperliquid's `hyper-evm-lib` PrecompileSimulator.
contract HyperCorePrecompileForwarder {
    fallback(bytes calldata input) external returns (bytes memory) {
        // Always `latest`. Pinning to the fork's block was tried and does NOT help: the public node answers
        // precompile reads from its current HyperCore view regardless of the block tag (verified 2026-10-26), so
        // reads inside one call may still straddle Core states. Tests must use tolerances for live figures.
        string memory params =
            string.concat('[{"to":"', VM.toString(address(this)), '","data":"', VM.toString(input), '"},"latest"]');
        return VM.rpc("eth_call", params);
    }
}

/// @notice Installs the forwarder at every HyperCore read precompile address used by the Superform oracle.
library HyperCorePrecompileForwarderLib {
    /// @dev 0x800 .. 0x813 inclusive: covers the legacy `position` (0x800) through `position2` (0x813). Etched
    ///      code may only use cheatcodes once whitelisted, hence `allowCheatcodes` per address.
    function install() internal {
        for (uint160 a = 0x800; a <= 0x813; ++a) {
            VM.etch(address(a), type(HyperCorePrecompileForwarder).runtimeCode);
            VM.allowCheatcodes(address(a));
        }
    }
}
