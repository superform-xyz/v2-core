// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IVaultBankSource {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SharesLocked(address indexed account, address indexed token, uint256 amount, uint256 srcChainId, uint256 dstChainId, uint256 nonce);
    event SharesUnlocked(address indexed account, address indexed token, uint256 amount, uint256 srcChainId, uint256 dstChainId, uint256 nonce);

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
    error MERKLE_ROOT_NOT_REGISTERED();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if a merkle root is registered
    /// @param merkleRoot The merkle root to check
    function isMerkleRootRegistered(bytes32 merkleRoot) external view returns (bool);
    /// @notice Get the locked amount of an account for a token
    /// @param account The account to get the locked amount for
    /// @param token The token to get the locked amount for
    /// @param dstChainId The destination chain ID
    function viewLockedAmount(address account, address token, uint64 dstChainId) external view returns (uint256);
    /// @notice Get the total locked amount of an account for a token
    /// @param account The account to get the total locked amount for
    /// @param token The token to get the total locked amount for
    function viewTotalLockedAsset(address account, address token) external view returns (uint256);
    /// @notice Get all the locked assets of an account
    /// @param account The account to get the locked assets for
    /// @param dstChainId The destination chain ID
    function viewAllLockedAssets(address account, uint64 dstChainId) external view returns (address[] memory);
    /// @notice Check if an account can claim any reward
    /// @param merkleRoot The merkle root to check
    /// @param account The account to check
    /// @param rewardToken The reward token to check
    /// @param amount The amount to check
    /// @param proof The proof to check
    function canClaim(
        bytes32 merkleRoot,
        address account,
        address rewardToken,
        uint256 amount,
        bytes32[] calldata proof
    )
        external
        view
        returns (bool);
}

interface IVaultBankDestination {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_BURN_AMOUNT();
    error SYNTHETIC_ASSET_NOT_FOUND();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the synthetic asset for a source asset
    /// @param srcChainId The source chain ID
    /// @param srcAsset The source asset
    function getSpForAsset(uint64 srcChainId, address srcAsset) external view returns (address);
    /// @notice Get the source asset for a synthetic asset
    /// @param srcChainId The source chain ID
    /// @param syntheticAsset The synthetic asset
    function getAssetForSp(uint64 srcChainId, address syntheticAsset) external view returns (address);
    /// @notice Check if a synthetic asset exists
    /// @param syntheticAsset The synthetic asset
    function isSpCreated(address syntheticAsset) external view returns (bool);
    /// @notice Get the balance of a synthetic asset for an account
    /// @param syntheticAsset The synthetic asset
    /// @param account The account
    function getBalance(address syntheticAsset, address account) external view returns (uint256);
}

interface IVaultBank {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct SourceAssetInfo {
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
    error NOTHING_TO_CLAIM();
    error ALREADY_DISTRIBUTED();
    error INVALID_MERKLE_ROOT();
    error INVALID_PROOF_CHAIN();
    error INVALID_PROOF_EVENT();
    error INVALID_PROOF_TOKEN();
    error INVALID_PROOF_AMOUNT();
    error INVALID_PROOF_ACCOUNT();
    error INVALID_PROOF_EMITTER();
    error INVALID_PROOF_SOURCE_CHAIN();
    error INVALID_PROOF_TARGETED_CHAIN();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperpositionsMinted(address indexed account, address indexed spAddress, address indexed srcTokenAddress, uint256 amount, uint64 srcChain, uint256 nonce);
    event SuperpositionsBurned(address indexed account, address indexed spAddress, address indexed srcTokenAddress, uint256 amount, uint64 srcChain, uint256 nonce);
    event ClaimRewards(address indexed target, bytes result);
    event BatchClaimRewards(address[] targets);
    event DistributeRewards(
        bytes32 indexed merkleRoot, address indexed account, address indexed rewardToken, uint256 amount
    );

    event MerkleRootUpdated(bytes32 indexed merkleRoot, bool status);
    event DestinationChainUpdated(uint64 indexed dstChainId, bool status);
    event RelayerUpdated(address indexed relayer, bool status);
    event ProverUpdated(address indexed prover);

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Update the merkle root
    /// @param merkleRoot The merkle root to update
    /// @param status The status of the merkle root (true: active, false: inactive)
    function updateMerkleRoot(bytes32 merkleRoot, bool status) external;

    /// @notice Update the status of a destination chain
    /// @param dstChainId_ The destination chain ID
    /// @param status_ The status of the destination chain (true: active, false: inactive)
    function updateChainStatus(uint64 dstChainId_, bool status_) external;

    /// @notice Update the status of a relayer
    /// @param relayer_ The relayer to update
    /// @param status_ The status of the relayer (true: active, false: inactive)
    function updateRelayerStatus(address relayer_, bool status_) external;

    /// @notice Update the prover
    /// @param prover_ The prover to update
    function updateProver(address prover_) external;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ CREATE SYNTHETIC ASSETS ------------------
    /// @notice Lock an asset for an account
    /// @param account The account to lock the asset for
    /// @param token The asset to lock
    /// @param amount The amount of the asset to lock
    /// @param toChainId The destination chain ID
    function lockAsset(address account, address token, uint256 amount, uint64 toChainId) external;
    /// @notice Creates or retrieves synthethic asset and distributes it to the account
    /// @param account_ The account to lock the asset for
    /// @param amount_ The amount of the asset to lock
    /// @param sourceAssetInfo_ The source asset info
    /// @param proof_ The proof of the event
    function distributeSuperPosition(address account_, uint256 amount_, SourceAssetInfo calldata sourceAssetInfo_, bytes calldata proof_) external;
    /// @notice Burns a synthetic asset
    /// @dev Should be requested by the account owning the SP assets
    /// @param amount_ The amount of the asset to burn
    /// @param spAddress_ The synthetic asset address
    /// @param forChainId_ The destination chain ID
    function burnSuperPosition(uint256 amount_, address spAddress_, uint64 forChainId_) external;

    // ------------------ REMOVE SYNTHETIC ASSETS ------------------
    /// @notice Unlock an asset for an account
    /// @param account The account to unlock the asset for
    /// @param token The asset to unlock
    /// @param amount The amount of the asset to unlock
    /// @param fromChainId The `from` (destination) chain
    /// @param proof_ The proof of the `burnSuperPosition` event
    function unlockAsset(address account, address token, uint256 amount, uint64 fromChainId, bytes calldata proof_) external;
 
    // ------------------ MANAGE REWARDS ------------------
    /// @notice Claim rewards for an account
    /// @param target The target to claim rewards from
    /// @param gasLimit The gas limit for the claim
    /// @param maxReturnDataCopy The maximum return data copy
    /// @param data The data to pass to the target
    function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes calldata data) external payable;
    /// @notice Batch claim rewards for multiple accounts
    /// @param targets The targets to claim rewards from
    /// @param gasLimit The gas limit for the claim
    /// @param val The values to claim
    /// @param maxReturnDataCopy The maximum return data copy
    /// @param data The data to pass to the targets
    function batchClaim(
        address[] calldata targets,
        uint256[] calldata gasLimit,
        uint256[] calldata val,
        uint16 maxReturnDataCopy,
        bytes calldata data
    )
        external
        payable;
    /// @notice Distribute rewards to an account
    /// @param merkleRoot The merkle root to distribute the rewards from
    /// @param account The account to distribute the rewards to
    /// @param rewardToken The reward token to distribute
    /// @param amount The amount to distribute
    /// @param proof The proof to distribute the rewards
    function distributeRewards(
        bytes32 merkleRoot,
        address account,
        address rewardToken,
        uint256 amount,
        bytes32[] calldata proof
    )
        external;
}
