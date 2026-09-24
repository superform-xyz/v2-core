// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { DeployV2Core } from "../../script/DeployV2Core.s.sol";
import { DeterministicDeployerLib } from "../../src/vendor/nexus/DeterministicDeployerLib.sol";

/// @dev Runs the generic CHECK pass and exposes what it recorded, plus the primitives the DEPLOY pass uses,
///      so the two constructor-arg encodings can be compared without an RPC.
contract GatewayArgsHarness is DeployV2Core {
    function runCheck(uint64 chainId, uint256 env) external {
        _setConfiguration(env, "");
        ContractAvailability memory availability = _getContractAvailability(chainId, env);
        _checkCoreContracts(chainId, env, availability);
    }

    function available(uint64 chainId, uint256 env) external returns (bool) {
        _setConfiguration(env, "");
        return _getContractAvailability(chainId, env).circleGatewayAdapter;
    }

    function checkedAddress(uint64 chainId, string memory name) external view returns (address) {
        return _getContractStatus(chainId, name).contractAddress;
    }

    function deployAddress(string memory name, uint256 env, bytes memory args) external view returns (address) {
        return DeterministicDeployerLib.computeAddress(__getBytecode(name, env), args, __getSalt(name));
    }

    function bytecodeExists(string memory name, uint256 env) external view returns (bool) {
        return __checkBytecodeExists(name, env);
    }

    function ctorArgs(uint64 chainId, address executor) external view returns (bytes memory) {
        return _circleGatewayCtorArgs(chainId, executor);
    }

    function gatewayMinter(uint64 chainId) external view returns (address) {
        return configuration.gatewayMinters[chainId];
    }

    function usdc(uint64 chainId) external view returns (address) {
        return configuration.usdcs[chainId];
    }
}

/// @title DeployV2CoreCircleGatewayAdapterArgsTest
/// @notice Regression (same class as DeployV2CoreCCTPAdapterArgs): the generic CHECK pass and the DEPLOY pass must
///         encode the SAME CircleGatewayAdapter constructor args `(gatewayMinter, usdc, superDestinationExecutor)`,
///         otherwise the check computes a wrong CREATE2 address and reports the adapter missing forever.
contract DeployV2CoreCircleGatewayAdapterArgsTest is Test {
    uint64 internal constant BASE = 8453;
    uint64 internal constant MAINNET = 1;
    uint64 internal constant LINEA = 59_144;
    uint256 internal constant ENV_STAGING = 2;
    uint256 internal constant ENV_PROD = 0;

    function test_CircleGatewayAdapter_CheckAndDeployEncodeTheSameConstructorArgs() public {
        vm.chainId(BASE);
        GatewayArgsHarness h = new GatewayArgsHarness();
        h.runCheck(BASE, ENV_STAGING);

        address checked = h.checkedAddress(BASE, "CircleGatewayAdapter");
        assertTrue(checked != address(0), "check pass recorded a CircleGatewayAdapter address");

        address executor = h.checkedAddress(BASE, "SuperDestinationExecutor");
        assertTrue(executor != address(0), "executor address recorded");

        // the deploy pass uses the SAME encoder (`_circleGatewayCtorArgs`) the check pass used above; pin that
        // encoder to the ABI order (gatewayMinter, usdc, executor) so an arg-order regression cannot hide
        bytes memory shared = h.ctorArgs(BASE, executor);
        assertEq(shared, abi.encode(h.gatewayMinter(BASE), h.usdc(BASE), executor), "encoder matches the ABI order");
        address deployed = h.deployAddress("CircleGatewayAdapter", ENV_STAGING, shared);
        assertEq(checked, deployed, "check pass and deploy pass must agree on the CircleGatewayAdapter CREATE2 address");
    }

    /// @notice The locked artifact exists for every env and both locked dirs carry byte-identical creation code
    ///         (a CREATE2 address is never zero, so existence must be asserted directly, not via the address).
    function test_CircleGatewayAdapter_LockedBytecodePresentAndIdenticalAcrossEnvs() public {
        vm.chainId(MAINNET);
        GatewayArgsHarness h = new GatewayArgsHarness();
        assertTrue(h.bytecodeExists("CircleGatewayAdapter", ENV_PROD), "prod artifact present");
        assertTrue(h.bytecodeExists("CircleGatewayAdapter", 1), "dev artifact present");
        assertTrue(h.bytecodeExists("CircleGatewayAdapter", ENV_STAGING), "staging artifact present");
        assertFalse(h.bytecodeExists("DefinitelyNotAContract", ENV_PROD), "existence check is falsifiable");

        bytes memory args = abi.encode(h.gatewayMinter(MAINNET), h.usdc(MAINNET), address(0xE));
        assertEq(
            h.deployAddress("CircleGatewayAdapter", ENV_PROD, args),
            h.deployAddress("CircleGatewayAdapter", ENV_STAGING, args),
            "locked and locked-dev creation code are identical"
        );
    }

    /// @notice Gate: enabled where the minter is configured with native USDC, skipped on Linea (no minter).
    function test_CircleGatewayAdapter_AvailabilityGate() public {
        // one harness per chain: _setConfiguration is single-shot per instance (Stargate OFT reinit guard)
        assertTrue(new GatewayArgsHarness().available(BASE, ENV_STAGING), "Base enabled");
        assertTrue(new GatewayArgsHarness().available(MAINNET, ENV_STAGING), "Ethereum enabled");
        assertFalse(new GatewayArgsHarness().available(LINEA, ENV_STAGING), "Linea skipped: Gateway minter not live");
    }
}
