// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";

/// @title SuperLedgerConfiguration
/// @author Superform Labs
/// @notice Configuration management contract for yield source oracles and ledgers
/// @dev Manages oracle configurations, fee settings, and governance of changes
///      Implements a proposal-acceptance pattern for configuration changes
///      Provides role-based access control for managers of different yield sources
contract SuperLedgerConfiguration is ISuperLedgerConfiguration {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Current active yield source oracle configurations
    /// @dev Maps from oracle ID to its configuration including oracle address, fees, and management info
    mapping(bytes32 yieldSourceOracleId => YieldSourceOracleConfig config) private yieldSourceOracleConfig;

    /// @notice Proposed yield source oracle configurations pending acceptance
    /// @dev Stores proposed configuration changes that must be accepted after a timelock period
    mapping(bytes32 yieldSourceOracleId => YieldSourceOracleConfig config) private yieldSourceOracleConfigProposals;

    /// @notice Timestamps for when proposals can be accepted
    /// @dev Implements timelock period for configuration changes to allow for review
    mapping(bytes32 yieldSourceOracleId => uint256 proposalExpirationTime) private
        yieldSourceOracleConfigProposalGracePeriod;

    /// @notice Addresses nominated to receive manager role transfers
    /// @dev Used in the two-step process for transferring management rights
    mapping(bytes32 => address) private pendingManager;

    /// @notice Maximum allowed fee percentage (50% = 5000 basis points)
    /// @dev Used to prevent setting excessive fees
    uint256 internal constant MAX_FEE_PERCENT = 5000;

    /// @notice Maximum allowed fee percentage change (50% = 5000 basis points)
    /// @dev Limits how much fees can be increased or decreased in a single proposal
    /// @dev Allow fee percent change without validation when the new fee percentage is 0
    uint256 internal constant MAX_FEE_PERCENT_CHANGE = 5000;

    /// @notice Duration of the timelock period for configuration proposals
    /// @dev After this period elapses, proposals can be accepted
    uint256 internal constant PROPOSAL_EXPIRATION_TIME = 1 weeks;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedgerConfiguration
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external virtual {
        
        uint256 length = configs.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length; ++i) {
            YieldSourceOracleConfigArgs calldata config = configs[i];
            _setInitialYieldSourceOracleConfig(
                config.uniqueIdentifier,
                config.yieldSourceOracle,
                config.feePercent,
                config.feeRecipient,
                config.ledger
            );
        }
    }

    /// @inheritdoc ISuperLedgerConfiguration
    /// @dev `config.uniqueIdentifier` represents the `yieldSourceOracleId` (salt + msg.sender)
    function proposeYieldSourceOracleConfig(YieldSourceOracleConfigArgs[] calldata configs) external virtual {
        uint256 length = configs.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length; ++i) {
            YieldSourceOracleConfigArgs calldata config = configs[i];

            YieldSourceOracleConfig memory existingConfig = yieldSourceOracleConfig[config.uniqueIdentifier];
            if (existingConfig.ledger == address(0) || existingConfig.manager == address(0)) revert CONFIG_NOT_FOUND();

            if (existingConfig.manager != msg.sender) revert NOT_MANAGER();

            if (yieldSourceOracleConfigProposalGracePeriod[config.uniqueIdentifier] > block.timestamp) {
                revert CHANGE_ALREADY_PROPOSED();
            }

            if (existingConfig.feePercent > 0) {
                // allow fee percent change without validation when the new fee percentage is 0
                if (config.feePercent > 0) {
                    uint256 minFee = Math.mulDiv(existingConfig.feePercent, (10_000 - MAX_FEE_PERCENT_CHANGE), 10_000);
                    uint256 maxFee = Math.mulDiv(existingConfig.feePercent, (10_000 + MAX_FEE_PERCENT_CHANGE), 10_000);
                    if (config.feePercent < minFee || config.feePercent > maxFee) revert INVALID_FEE_PERCENT();
                }
            }

            _validateYieldSourceOracleConfig(
                config.uniqueIdentifier,
                config.yieldSourceOracle,
                config.feePercent,
                config.feeRecipient,
                config.ledger
            );

            yieldSourceOracleConfigProposals[config.uniqueIdentifier] = YieldSourceOracleConfig({
                yieldSourceOracle: config.yieldSourceOracle,
                feePercent: config.feePercent,
                feeRecipient: config.feeRecipient,
                manager: existingConfig.manager,
                ledger: config.ledger
            });
            yieldSourceOracleConfigProposalGracePeriod[config.uniqueIdentifier] =
                block.timestamp + PROPOSAL_EXPIRATION_TIME;

            emit YieldSourceOracleConfigProposalSet(
                config.uniqueIdentifier,
                config.yieldSourceOracle,
                config.feePercent,
                config.feeRecipient,
                existingConfig.manager,
                config.ledger
            );
        }
    }

    /// @notice Cancels a pending yield source oracle configuration proposal.
    /// @param yieldSourceOracleId The identifier of the yield source oracle.
    /// @dev Only the current manager can call this function.
    function cancelYieldSourceOracleConfigProposal(bytes32 yieldSourceOracleId) external virtual {
        // Ensure only the current manager can cancel
        if (yieldSourceOracleConfig[yieldSourceOracleId].manager != msg.sender) {
            revert NOT_MANAGER();
        }
        // Check if there is a pending proposal
        if (yieldSourceOracleConfigProposalGracePeriod[yieldSourceOracleId] == 0) {
            revert NO_PENDING_PROPOSAL();
        }
        // Store proposal details for event emission
        YieldSourceOracleConfig memory proposal = yieldSourceOracleConfigProposals[yieldSourceOracleId];
        // Clear the pending proposal and expiration time
        delete yieldSourceOracleConfigProposals[yieldSourceOracleId];
        delete yieldSourceOracleConfigProposalGracePeriod[yieldSourceOracleId];
        // Emit event for transparency
        emit YieldSourceOracleConfigProposalCancelled(
            yieldSourceOracleId,
            proposal.yieldSourceOracle,
            proposal.feePercent,
            proposal.feeRecipient,
            proposal.manager,
            proposal.ledger
        );
    }

    /// @inheritdoc ISuperLedgerConfiguration
    function acceptYieldSourceOracleConfigProposal(bytes32[] calldata yieldSourceOracleIds) external virtual {
        uint256 length = yieldSourceOracleIds.length;
        if (length == 0) revert ZERO_LENGTH();

        for (uint256 i; i < length; ++i) {
            bytes32 yieldSourceOracleId = yieldSourceOracleIds[i];
            YieldSourceOracleConfig memory proposal = yieldSourceOracleConfigProposals[yieldSourceOracleId];
            YieldSourceOracleConfig memory existingConfig = yieldSourceOracleConfig[yieldSourceOracleId];

            if (
                proposal.yieldSourceOracle == address(0) && proposal.feeRecipient == address(0)
                    && proposal.ledger == address(0)
            ) revert CONFIG_NOT_FOUND();

            // Cannot check on `proposal.manager` because:
            // if the manager role is transferred after the proposal is created, the new manager cannot accept the
            // proposal
            // and the outdated manager is reinstated upon acceptance
            // also as long as an existing proposal remains pending, the current manager is blocked from submitting a
            // new one
            // So, we check against `existingConfig.manager` instead and rewrite `proposal.manager`
            if (existingConfig.manager != msg.sender) revert NOT_MANAGER();
            proposal.manager = existingConfig.manager;

            // If the proposal has not expired, the manager cannot accept it
            if (yieldSourceOracleConfigProposalGracePeriod[yieldSourceOracleId] > block.timestamp) {
                revert CANNOT_ACCEPT_YET();
            }

            yieldSourceOracleConfig[yieldSourceOracleId] = proposal;

            delete yieldSourceOracleConfigProposals[yieldSourceOracleId];
            delete yieldSourceOracleConfigProposalGracePeriod[yieldSourceOracleId];

            emit YieldSourceOracleConfigAccepted(
                yieldSourceOracleId,
                proposal.yieldSourceOracle,
                proposal.feePercent,
                proposal.feeRecipient,
                proposal.manager,
                proposal.ledger
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperLedgerConfiguration
    function getYieldSourceOracleConfig(bytes32 yieldSourceOracleId)
        external
        view
        virtual
        returns (YieldSourceOracleConfig memory)
    {
        return yieldSourceOracleConfig[yieldSourceOracleId];
    }

    /// @inheritdoc ISuperLedgerConfiguration
    function getYieldSourceOracleConfigs(bytes32[] calldata yieldSourceOracleIds)
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

    function transferManagerRole(bytes32 yieldSourceOracleId, address newManager) external virtual {
        YieldSourceOracleConfig memory config = yieldSourceOracleConfig[yieldSourceOracleId];
        if (config.manager != msg.sender) revert NOT_MANAGER();
        if (newManager == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();

        pendingManager[yieldSourceOracleId] = newManager;

        emit ManagerRoleTransferStarted(yieldSourceOracleId, msg.sender, newManager);
    }

    /// @inheritdoc ISuperLedgerConfiguration
    function acceptManagerRole(bytes32 yieldSourceOracleId) external virtual {
        if (pendingManager[yieldSourceOracleId] != msg.sender) revert NOT_PENDING_MANAGER();
        yieldSourceOracleConfig[yieldSourceOracleId].manager = msg.sender;
        delete pendingManager[yieldSourceOracleId];

        emit ManagerRoleTransferAccepted(yieldSourceOracleId, msg.sender);
    }
    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setInitialYieldSourceOracleConfig(
        bytes32 salt,
        address yieldSourceOracle,
        uint256 feePercent,
        address feeRecipient,
        address ledgerContract
    )
        internal
        virtual
    {
        _validateYieldSourceOracleConfig(
            salt, yieldSourceOracle, feePercent, feeRecipient, ledgerContract
        );

        // re-create id with sender address
        bytes32 yieldSourceOracleId = _deriveWithSender(salt, msg.sender);

        YieldSourceOracleConfig memory existingConfig = yieldSourceOracleConfig[yieldSourceOracleId];
        if (existingConfig.manager != address(0) && existingConfig.ledger != address(0)) revert CONFIG_EXISTS();

        yieldSourceOracleConfig[yieldSourceOracleId] = YieldSourceOracleConfig({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            manager: msg.sender,
            ledger: ledgerContract
            // originalOwner: msg.sender
        });

        

        emit YieldSourceOracleConfigSet(
            yieldSourceOracleId, yieldSourceOracle, feePercent, feeRecipient, msg.sender, ledgerContract
        );
    }

    function _validateYieldSourceOracleConfig(
        bytes32 salt,
        address yieldSourceOracle,
        uint256 feePercent,
        address feeRecipient,
        address ledgerContract
    )
        internal
        view
        virtual
    {
        if (yieldSourceOracle == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feeRecipient == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (ledgerContract == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        if (feePercent > MAX_FEE_PERCENT) revert INVALID_FEE_PERCENT();
        if (salt == bytes32(0)) revert ZERO_ID_NOT_ALLOWED();
    }

    function _deriveWithSender(bytes32 id, address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, sender));
    }

}
