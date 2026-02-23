// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { DeployV2Base } from "./DeployV2Base.s.sol";
import { DeterministicDeployerLib } from "../src/vendor/nexus/DeterministicDeployerLib.sol";

/// @title PendlePTAmortizedOracleV2ScriptBase
/// @notice Shared base contract for PendlePTAmortizedOracleV2 deployment and ownership scripts
/// @dev Contains common constants and utility functions for V2 oracle
/// @dev V2 key differences:
///      - recordPurchase calculates sySpent from on-chain PT rate (no off-chain price dependency)
///      - twapDuration passed per-call via hook (no market config storage)
abstract contract PendlePTAmortizedOracleV2ScriptBase is DeployV2Base {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Contract key for PendlePTAmortizedOracleV2
    string internal constant ORACLE_V2_KEY = "PendlePTAmortizedOracleV2";

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Compute the deterministic address for PendlePTAmortizedOracleV2
    /// @param env Environment (0 = prod, 1 = vnet, 2 = staging)
    /// @param admin Admin address used during deployment
    /// @param superLedgerConfiguration SuperLedgerConfiguration address
    /// @return The computed deterministic address
    function _computeOracleV2Address(
        uint256 env,
        address admin,
        address superLedgerConfiguration
    )
        internal
        view
        returns (address)
    {
        bytes memory bytecode = __getBytecode(ORACLE_V2_KEY, env);
        require(bytecode.length > 0, "BYTECODE_NOT_FOUND");
        return DeterministicDeployerLib.computeAddress(
            abi.encodePacked(bytecode, abi.encode(admin, superLedgerConfiguration)),
            __getSalt(ORACLE_V2_KEY)
        );
    }
}
