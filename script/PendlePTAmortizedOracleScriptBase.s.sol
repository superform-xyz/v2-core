// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";

/// @title PendlePTAmortizedOracleScriptBase
/// @notice Shared base contract for PendlePTAmortizedOracle deployment and ownership scripts
/// @dev Contains common constants and utility functions
abstract contract PendlePTAmortizedOracleScriptBase is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Contract key for PendlePTAmortizedOracle
    string internal constant ORACLE_KEY = "PendlePTAmortizedOracle";

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Compute the deterministic address for PendlePTAmortizedOracle
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param admin Admin address used during deployment
    /// @param superLedgerConfiguration SuperLedgerConfiguration address
    /// @return The computed deterministic address
    function _computeOracleAddress(
        uint256 env,
        address admin,
        address superLedgerConfiguration
    )
        internal
        view
        returns (address)
    {
        bytes memory bytecode = __getBytecode(ORACLE_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");
        return DeterministicDeployerLib.computeAddress(
            abi.encodePacked(bytecode, abi.encode(admin, superLedgerConfiguration)),
            __getSalt(ORACLE_KEY)
        );
    }
}
