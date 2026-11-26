// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookInspector } from "../../interfaces/ISuperHook.sol";
import { BaseHook } from "../BaseHook.sol";
import { BaseHyperCoreWriterHook } from "./BaseHyperCoreWriterHook.sol";

/// @title HyperCoreSetUnifiedAccountHook
/// @author Superform Labs
/// @notice Enables Unified account mode for the executing smart account on HyperCore.
/// @dev Hook data consists solely of the 52-byte strategy header. CoreWriter action 16 takes
///      (address user, uint8 abstraction). The account must already exist on HyperCore.
contract HyperCoreSetUnifiedAccountHook is BaseHyperCoreWriterHook {
    uint256 private constant DATA_LENGTH = 52;
    uint8 private constant UNIFIED_ACCOUNT = 2;

    constructor(address coreWriter_) BaseHyperCoreWriterHook(coreWriter_) { }

    /// @inheritdoc ISuperHook
    function name() external pure override returns (string memory) {
        return "HyperCore Set Unified Account";
    }

    /// @inheritdoc ISuperHook
    function description() external pure override returns (string memory) {
        return "Enables shared spot and perpetuals collateral for the executing account on HyperCore";
    }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory)
    {
        if (data.length != DATA_LENGTH) revert DATA_NOT_VALID();
        if (account == address(0)) revert ADDRESS_NOT_VALID();
        return _coreWriterExecution(ACTION_SET_ABSTRACTION, abi.encode(account, UNIFIED_ACCOUNT));
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(CORE_WRITER);
    }
}
