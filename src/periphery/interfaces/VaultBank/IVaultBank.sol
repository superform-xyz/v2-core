// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IHookExecutionData } from "../IHookExecutionData.sol";

interface IVaultBankSource {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SharesLocked(
        bytes32 indexed yieldSourceOracleId,
        address indexed account,
        address indexed token,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 nonce
    );
    event SharesUnlocked(
        bytes32 indexed yieldSourceOracleId,
        address indexed account,
        address indexed token,
        uint256 amount,
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 nonce
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CLAIM_FAILED();
    error INVALID_TOKEN();
    error INVALID_AMOUNT();
    error INVALID_ACCOUNT();
    error TOKEN_NOT_FOUND();
    error NO_LOCKED_ASSETS();
    error INVALID_CLAIM_TARGET();
    error INVALID_YIELD_SOURCE_ORACLE_ID();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the total locked amount of a token
    /// @param token The token to get the total locked amount for
    function viewTotalLockedAsset(address token) external view returns (uint256);

    /// @notice Get all the locked assets of a destination chain
    function viewAllLockedAssets() external view returns (address[] memory);
}

interface IVaultBankDestination {
    struct SpAsset {
        bool wasCreated;
        mapping(uint64 srcChainId => mapping(bytes32 yieldSourceOracleId => address srcTokenAddress)) spToToken;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_BURN_AMOUNT();
    error SUPERPOSITION_ASSET_NOT_FOUND();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the synthetic asset for a source asset
    /// @param srcChainId The source chain ID
    /// @param srcAsset The source asset
    /// @param yieldSourceOracleId The yield source oracle ID
    function getSuperPositionForAsset(uint64 srcChainId, address srcAsset, bytes32 yieldSourceOracleId) external view returns (address);
    /// @notice Get the source asset for a synthetic asset
    /// @param srcChainId The source chain ID
    /// @param superPosition The synthetic asset
    /// @param yieldSourceOracleId The yield source oracle ID
    function getAssetForSuperPosition(uint64 srcChainId, address superPosition, bytes32 yieldSourceOracleId) external view returns (address);
    /// @notice Check if a synthetic asset exists
    /// @param superPosition The synthetic asset
    function isSuperPositionCreated(address superPosition) external view returns (bool);
}

interface IVaultBank is IHookExecutionData {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct SourceAssetInfo {
        bytes32 yieldSourceOracleId;
        uint64 chainId;
        address asset;
        string name;
        string symbol;
        uint8 decimals;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_VALUE();
    error INVALID_CHAIN();
    error NOT_AUTHORIZED();
    error INVALID_RELAYER();
    error INVALID_EXECUTOR();
    error NONCE_ALREADY_USED();
    error ALREADY_DISTRIBUTED();
    error INVALID_PROOF_CHAIN();
    error INVALID_PROOF_EVENT();
    error INVALID_PROOF_TOKEN();
    error INVALID_PROOF_AMOUNT();
    error INVALID_BANK_MANAGER();
    error INVALID_PROOF_ACCOUNT();
    error INVALID_PROOF_EMITTER();
    error INVALID_PROOF_SOURCE_CHAIN();
    error INVALID_VAULT_BANK_ADDRESS();
    error INVALID_PROOF_TARGETED_CHAIN();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event BatchDistributeRewardsToSuperBank(address[] indexed rewards, uint256[] amounts);

    event SuperpositionsMinted(
        address indexed account,
        address indexed spAddress,
        address indexed srcTokenAddress,
        uint256 amount,
        uint64 srcChain,
        uint256 nonce
    );
    event SuperpositionsBurned(
        address indexed account,
        address indexed spAddress,
        address indexed srcTokenAddress,
        uint256 amount,
        uint64 srcChain,
        uint256 nonce
    );

    event DestinationChainUpdated(uint64 indexed dstChainId, bool status);
    event RelayerUpdated(address indexed relayer, bool status);
    event ProverUpdated(address indexed prover);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ CREATE SYNTHETIC ASSETS ------------------
    /// @notice Lock an asset for an account
    /// @dev This function is used to lock an asset for an account
    /// @param yieldSourceOracleId The yield source oracle ID
    /// @param account The account to lock the asset for
    /// @param token The asset to lock
    /// @param hookAddress The hook address to lock the asset through
    /// @param amount The amount of the asset to lock
    /// @param toChainId The destination chain ID
    function lockAsset(
        bytes32 yieldSourceOracleId,
        address account,
        address token,
        address hookAddress,
        uint256 amount,
        uint64 toChainId
    )
        external;

    /// @notice Creates or retrieves synthethic asset and distributes it to the account
    /// @param account_ The account to lock the asset for
    /// @param amount_ The amount of the asset to lock
    /// @param sourceAssetInfo_ The source asset info
    /// @param proof_ The proof of the event
    function distributeSuperPosition(
        address account_,
        uint256 amount_,
        SourceAssetInfo calldata sourceAssetInfo_,
        bytes calldata proof_
    )
        external;

    /// @notice Burns a synthetic asset
    /// @dev Should be requested by the account owning the SP assets
    /// @param amount_ The amount of the asset to burn
    /// @param spAddress_ The synthetic asset address
    /// @param forChainId_ The destination chain ID
    /// @param yieldSourceOracleId_ The yield source oracle ID
    function burnSuperPosition(uint256 amount_, address spAddress_, uint64 forChainId_, bytes32 yieldSourceOracleId_) external;

    // ------------------ REMOVE SYNTHETIC ASSETS ------------------
    /// @notice Unlock an asset for an account
    /// @param account The account to unlock the asset for
    /// @param token The asset to unlock
    /// @param amount The amount of the asset to unlock
    /// @param fromChainId The `from` (destination) chain
    /// @param yieldSourceOracleId The yield source oracle ID
    /// @param proof_ The proof of the `burnSuperPosition` event
    function unlockAsset(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes32 yieldSourceOracleId,
        bytes calldata proof_
    )
        external;

    // ------------------ MANAGE REWARDS ------------------
    /// @notice Execute hooks
    /// @dev Used to claim rewards
    /// @param executionData The execution data
    function executeHooks(IVaultBank.HookExecutionData calldata executionData) external;

    /// @notice Batch distribute rewards to the super bank
    /// @param rewards The rewards to distribute
    /// @param amounts The amounts of the rewards
    function batchDistributeRewardsToSuperBank(address[] memory rewards, uint256[] memory amounts) external;
}
