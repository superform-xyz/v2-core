// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

/// @title SuperLedgerConfiguration
/// @author Superform Labs
/// @notice Configuration for SuperLedger
contract SuperLedgerConfiguration is SuperRegistryImplementer, ISuperLedgerConfiguration {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Yield source oracle configurations
    mapping(bytes4 yieldSourceOracleId => YieldSourceOracleConfig config) private yieldSourceOracleConfig;
    /// @notice Pending manager for yield source oracle
    mapping(bytes4 => address) private pendingManager;

    uint256 internal constant MAX_FEE_PERCENT = 10_000;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedgerConfiguration
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external virtual {
        uint256 length = configs.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length; ++i) {
            YieldSourceOracleConfigArgs calldata config = configs[i];
            _setYieldSourceOracleConfig(
                config.yieldSourceOracleId,
                config.yieldSourceOracle,
                config.feePercent,
                config.feeRecipient,
                config.ledger
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedgerConfiguration
    function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId)
        external
        view
        virtual
        returns (YieldSourceOracleConfig memory)
    {
        return yieldSourceOracleConfig[yieldSourceOracleId];
    }

    /// @inheritdoc ISuperLedgerConfiguration
    function getYieldSourceOracleConfigs(bytes4[] calldata yieldSourceOracleIds)
        external
        view
        virtual
        returns (YieldSourceOracleConfig[] memory configs)
    {
        uint256 length = yieldSourceOracleIds.length;

        configs = new YieldSourceOracleConfig[](length);
        for (uint256 i; i < length; ++i) {
            configs[i] = yieldSourceOracleConfig[yieldSourceOracleIds[i]];
        }
    }
    /// @inheritdoc ISuperLedgerConfiguration
    function transferManagerRole(bytes4 yieldSourceOracleId, address newManager) external virtual {
        YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracleId];
        if (config.manager != msg.sender) revert NOT_MANAGER();

        pendingManager[yieldSourceOracleId] = newManager;

        emit ManagerRoleTransferStarted(yieldSourceOracleId, msg.sender, newManager);
    }

    /// @inheritdoc ISuperLedgerConfiguration
    function acceptManagerRole(bytes4 yieldSourceOracleId) external virtual {
        if (pendingManager[yieldSourceOracleId] != msg.sender) revert NOT_PENDING_MANAGER();
        yieldSourceOracleConfig[yieldSourceOracleId].manager = msg.sender;
        delete pendingManager[yieldSourceOracleId];

        emit ManagerRoleTransferAccepted(yieldSourceOracleId, msg.sender);
    }
    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _setYieldSourceOracleConfig(
        bytes4 yieldSourceOracleId,
        address yieldSourceOracle,
        uint256 feePercent,
        address feeRecipient,
        address ledgerContract
    )
        internal
        virtual
    {
        if (yieldSourceOracle == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feeRecipient == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (ledgerContract == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feePercent > MAX_FEE_PERCENT) revert INVALID_FEE_PERCENT();
        if (yieldSourceOracleId == bytes4(0)) revert ZERO_ID_NOT_ALLOWED();

        // Only allow updates if no config exists or if caller is the manager
        YieldSourceOracleConfig memory existingConfig = yieldSourceOracleConfig[yieldSourceOracleId];
        if (existingConfig.manager != address(0) && msg.sender != existingConfig.manager) revert NOT_MANAGER();

        yieldSourceOracleConfig[yieldSourceOracleId] = YieldSourceOracleConfig({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            manager: msg.sender,
            ledger: ledgerContract
        });

        emit YieldSourceOracleConfigSet(
            yieldSourceOracleId, yieldSourceOracle, feePercent, msg.sender, feeRecipient, ledgerContract
        );
    }
}
