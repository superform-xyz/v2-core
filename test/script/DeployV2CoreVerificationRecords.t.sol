// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

import { Test } from "forge-std/Test.sol";

import { DeployV2Core } from "../../script/DeployV2Core.s.sol";

contract DeployV2CoreHarness is DeployV2Core {
    function buildCoreVerificationRecords(uint256 env) external pure returns (ContractVerification[] memory) {
        return _buildCoreVerificationRecords(env, "");
    }

    function checkBytecodeExists(string memory contractName, uint256 env) external view returns (bool) {
        return __checkBytecodeExists(contractName, env);
    }
}

/// @notice Regression tests for the environment routing of verification records (SF-S01).
///         The verifier's existence check is env-aware, but the records used to hardcode the
///         production bytecode directory: for dev/staging, contracts whose lock files exist only
///         in locked-bytecode-dev/ passed the existence check and then reverted when the record's
///         production path was loaded, blocking ledger configuration.
contract DeployV2CoreVerificationRecordsTest is Test {
    uint256 internal constant ENV_PROD = 0;
    uint256 internal constant ENV_DEV = 1;
    uint256 internal constant ENV_STAGING = 2;

    DeployV2CoreHarness internal harness;

    function setUp() public {
        harness = new DeployV2CoreHarness();
    }

    /// @notice For every environment, each record's bytecodePath must load exactly when the
    ///         env-aware existence check says the artifact exists. A mismatch in either direction
    ///         means the existence gating and the verification load resolve different artifacts.
    function test_VerificationRecords_PathMatchesExistenceCheck_AllEnvs() public view {
        for (uint256 env = ENV_PROD; env <= ENV_STAGING; env++) {
            DeployV2Core.ContractVerification[] memory records = harness.buildCoreVerificationRecords(env);
            assertEq(records.length, 14, "unexpected record count");

            for (uint256 i = 0; i < records.length; i++) {
                bool exists = harness.checkBytecodeExists(records[i].name, env);
                bool recordLoads = _artifactLoads(records[i].bytecodePath);

                assertEq(
                    recordLoads,
                    exists,
                    string.concat(
                        "record path and existence check disagree for ",
                        records[i].name,
                        " at env ",
                        vm.toString(env)
                    )
                );
            }
        }
    }

    /// @notice The concrete pre-fix failure: the Morpho Blue registry and oracle have lock files
    ///         only in locked-bytecode-dev/. Their records must load in dev and staging; before
    ///         the fix the existence check passed and the production-path load reverted.
    function test_VerificationRecords_DevOnlyArtifactsLoadInDevAndStaging() public view {
        string[2] memory devOnlyContracts = ["MorphoBlueMarketRegistry", "MorphoBlueYieldSourceOracle"];

        for (uint256 c = 0; c < devOnlyContracts.length; c++) {
            for (uint256 env = ENV_DEV; env <= ENV_STAGING; env++) {
                DeployV2Core.ContractVerification memory record = _findRecord(devOnlyContracts[c], env);

                assertTrue(
                    harness.checkBytecodeExists(record.name, env),
                    string.concat(record.name, " should have a dev lock file")
                );
                assertTrue(
                    _artifactLoads(record.bytecodePath),
                    string.concat(record.name, " record path must load in env ", vm.toString(env))
                );
            }
        }
    }

    function _findRecord(
        string memory name,
        uint256 env
    )
        internal
        view
        returns (DeployV2Core.ContractVerification memory)
    {
        DeployV2Core.ContractVerification[] memory records = harness.buildCoreVerificationRecords(env);
        for (uint256 i = 0; i < records.length; i++) {
            if (keccak256(bytes(records[i].name)) == keccak256(bytes(name))) return records[i];
        }
        revert(string.concat("record not found: ", name));
    }

    function _artifactLoads(string memory path) internal view returns (bool) {
        try vm.getCode(path) returns (bytes memory code) {
            return code.length > 0;
        } catch {
            return false;
        }
    }
}
