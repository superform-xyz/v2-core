// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

contract SuperLedgerConfiguration is ISuperLedgerConfiguration, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Yield source oracle configurations
    mapping(bytes4 yieldSourceOracleId => YieldSourceOracleConfig config) private yieldSourceOracleConfig;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedgerConfiguration
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external virtual {
        uint256 length = configs.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length;) {
            YieldSourceOracleConfigArgs calldata config = configs[i];
            _setYieldSourceOracleConfig(
                config.yieldSourceOracleId, config.yieldSourceOracle, config.feePercent, config.feeRecipient, config.ledger
            );
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedgerConfiguration
    function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId)
        external
        virtual
        view
        returns (YieldSourceOracleConfig memory)
    {
        return yieldSourceOracleConfig[yieldSourceOracleId];
    }

    /// @inheritdoc ISuperLedgerConfiguration
    function getYieldSourceOracleConfigs(bytes4[] calldata yieldSourceOracleIds)
        external
        virtual
        view
        returns (YieldSourceOracleConfig[] memory configs)
    {
        uint256 length = yieldSourceOracleIds.length;

        configs = new YieldSourceOracleConfig[](length);
        for (uint256 i; i < length;) {
            configs[i] = yieldSourceOracleConfig[yieldSourceOracleIds[i]];
            unchecked {
                ++i;
            }
        }
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
        internal virtual
    {
        if (yieldSourceOracle == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feeRecipient == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (ledgerContract == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feePercent > 10_000) revert INVALID_FEE_PERCENT();
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

        emit YieldSourceOracleConfigSet(yieldSourceOracleId, yieldSourceOracle, feePercent, msg.sender, feeRecipient, ledgerContract);
    }
}