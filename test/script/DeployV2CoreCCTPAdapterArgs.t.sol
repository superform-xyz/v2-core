// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { DeployV2Core } from "../../script/DeployV2Core.s.sol";
import { DeterministicDeployerLib } from "../../src/vendor/nexus/DeterministicDeployerLib.sol";

/// @dev Runs the generic CHECK pass and exposes what it recorded, plus the primitives the DEPLOY pass uses,
///      so the two constructor-arg encodings can be compared without an RPC.
contract ArgsHarness is DeployV2Core {
    function runCheck(uint64 chainId, uint256 env) external {
        _setConfiguration(env, "");
        ContractAvailability memory availability = _getContractAvailability(chainId, env);
        _checkCoreContracts(chainId, env, availability);
    }

    function checkedAddress(uint64 chainId, string memory name) external view returns (address) {
        return _getContractStatus(chainId, name).contractAddress;
    }

    function deployAddress(string memory name, uint256 env, bytes memory args) external view returns (address) {
        return DeterministicDeployerLib.computeAddress(__getBytecode(name, env), args, __getSalt(name));
    }

    function tokenMessenger() external pure returns (address) {
        return CCTP_V2_TOKEN_MESSENGER;
    }

    function transmitter(uint64 chainId) external view returns (address) {
        return configuration.messageTransmittersV2[chainId];
    }

    function usdc(uint64 chainId) external view returns (address) {
        return configuration.usdcs[chainId];
    }
}

/// @title DeployV2CoreCCTPAdapterArgsTest
/// @notice Regression: the generic CHECK pass and the DEPLOY pass must encode the SAME CCTPAdapter constructor
///         args. They diverged once (check: 3 args, deploy: 4) — the check then computed a wrong CREATE2
///         address, reported the adapter missing forever, and the deploy would have landed elsewhere.
contract DeployV2CoreCCTPAdapterArgsTest is Test {
    uint64 internal constant BASE = 8453;
    uint256 internal constant ENV_STAGING = 2;

    function test_CCTPAdapter_CheckAndDeployEncodeTheSameConstructorArgs() public {
        vm.chainId(BASE);
        ArgsHarness h = new ArgsHarness();
        h.runCheck(BASE, ENV_STAGING);

        address checked = h.checkedAddress(BASE, "CCTPAdapter");
        assertTrue(checked != address(0), "check pass recorded a CCTPAdapter address");

        // the deploy pass wires the executor it deployed/found — in the check pass that is the recorded address
        address executor = h.checkedAddress(BASE, "SuperDestinationExecutor");
        assertTrue(executor != address(0), "executor address recorded");

        address deployed = h.deployAddress(
            "CCTPAdapter", ENV_STAGING, abi.encode(h.transmitter(BASE), h.tokenMessenger(), h.usdc(BASE), executor)
        );
        assertEq(checked, deployed, "check pass and deploy pass must agree on the CCTPAdapter CREATE2 address");
    }
}
