// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";

import { DeployV2Core } from "../../script/DeployV2Core.s.sol";
import { SuperValidator } from "../../src/validators/SuperValidator.sol";
import { SuperValidatorV2 } from "../../src/validators/SuperValidatorV2.sol";

contract SuperValidatorV2WiringHarness is DeployV2Core {
    function checkBytecodeExists(string memory name, uint256 env) external view returns (bool) {
        return __checkBytecodeExists(name, env);
    }

    function bytecodeArtifactPath(string memory name, uint256 env) external pure returns (string memory) {
        return __getBytecodeArtifactPath(name, env);
    }
}

/// @title DeployV2CoreSuperValidatorV2WiringTest
/// @author Superform Labs
/// @notice Guards the deploy wiring for `SuperValidatorV2` (SUP-17924) at the level the deploy script
///         actually operates on: the ENV-ROUTED artifact path.
/// @dev `ValidatorBytecodeUnchangedTest` already pins the three artifact FILES against the source. What this
///      adds is the step in between: that `__getBytecodeArtifactPath` — the function
///      `_deployCoreContracts`, `_checkCoreContracts` and the verifier all go through — resolves to one of
///      those pinned files for EVERY environment, and that the bytes it hands back are the reviewed source.
///      Without this, deleting or forgetting `locked-bytecode-dev/SuperValidatorV2.json` leaves every other
///      test green while a staging run silently skips the contract (the deploy is gated on
///      `__checkBytecodeExists`) — the same class of environment-routing bug as SF-S01, which is what
///      `DeployV2CoreVerificationRecordsTest` exists for.
contract DeployV2CoreSuperValidatorV2WiringTest is Test {
    uint256 internal constant ENV_PROD = 0;
    uint256 internal constant ENV_DEV = 1;
    uint256 internal constant ENV_STAGING = 2;

    address internal constant DETERMINISTIC_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    string internal constant PROD_NAMESPACE = "PROD1.0.0";
    string internal constant STAGING_NAMESPACE = "STAGING1.0.0";

    SuperValidatorV2WiringHarness internal harness;

    function setUp() public {
        harness = new SuperValidatorV2WiringHarness();
    }

    /// @notice For every environment the deploy script can run in, the artifact it would consume must exist
    ///         AND contain exactly the creation code of the reviewed source. A mismatch in either direction
    ///         means a deploy would put different code on chain than this repo describes.
    function test_Wiring_ArtifactResolvesToSourceInEveryEnv() public {
        bytes32 expected = keccak256(type(SuperValidatorV2).creationCode);

        for (uint256 env = ENV_PROD; env <= ENV_STAGING; env++) {
            assertTrue(
                harness.checkBytecodeExists("SuperValidatorV2", env),
                string.concat("no SuperValidatorV2 artifact for env ", vm.toString(env))
            );

            bytes memory code = vm.getCode(harness.bytecodeArtifactPath("SuperValidatorV2", env));
            assertGt(code.length, 0, string.concat("empty artifact for env ", vm.toString(env)));
            assertEq(
                keccak256(code),
                expected,
                string.concat("env ", vm.toString(env), " artifact is not the reviewed source")
            );
        }
    }

    /// @notice The env routing actually routes: prod reads `locked-bytecode/`, dev and staging read
    ///         `locked-bytecode-dev/`. Asserted on the resolved paths so a future change to
    ///         `__getBytecodeArtifactPath` cannot quietly collapse the environments into one.
    function test_Wiring_EnvRoutingPicksDistinctDirectories() public view {
        string memory prod = harness.bytecodeArtifactPath("SuperValidatorV2", ENV_PROD);
        string memory dev = harness.bytecodeArtifactPath("SuperValidatorV2", ENV_DEV);
        string memory staging = harness.bytecodeArtifactPath("SuperValidatorV2", ENV_STAGING);

        assertTrue(keccak256(bytes(prod)) != keccak256(bytes(dev)), "prod and dev must differ");
        assertEq(keccak256(bytes(dev)), keccak256(bytes(staging)), "dev and staging share a directory");
    }

    /// @notice The deploy NAME is what separates V2 from V1, so the salts must differ — this is the mechanism
    ///         by which `SuperValidator` keeps its live address. Checked for both namespaces.
    function test_Wiring_SaltAndAddressDifferFromV1() public pure {
        string[2] memory namespaces = [PROD_NAMESPACE, STAGING_NAMESPACE];

        for (uint256 i; i < namespaces.length; ++i) {
            bytes32 saltV1 = _salt(namespaces[i], "SuperValidator");
            bytes32 saltV2 = _salt(namespaces[i], "SuperValidatorV2");
            assertTrue(saltV1 != saltV2, "V1 and V2 must not share a salt");

            address addrV1 = _create2(saltV1, type(SuperValidator).creationCode);
            address addrV2 = _create2(saltV2, type(SuperValidatorV2).creationCode);
            assertTrue(addrV1 != addrV2, "V1 and V2 must not share an address");
            assertTrue(addrV2 != address(0));
        }
    }

    function _salt(string memory namespace, string memory name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("SuperformV2", namespace, name, "v2.0"));
    }

    function _create2(bytes32 salt, bytes memory creationCode) internal pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), DETERMINISTIC_DEPLOYER, salt, keccak256(creationCode)))
                )
            )
        );
    }
}
