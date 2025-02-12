// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISuperCollectiveVault {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CLAIM_FAILED();
    error INVALID_VALUE();
    error INVALID_TOKEN();
    error NOT_AUTHORIZED();
    error INVALID_AMOUNT();
    error INVALID_ACCOUNT();
    error TOKEN_NOT_FOUND();
    error NO_LOCKED_ASSETS();
    error NOTHING_TO_CLAIM();
    error ALREADY_DISTRIBUTED();
    error INVALID_MERKLE_ROOT();
    error INVALID_CLAIM_TARGET();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Lock(address indexed account, address indexed token, uint256 amount);
    event Unlock(address indexed account, address indexed token, uint256 amount);
    event ClaimRewards(address indexed target, bytes result);
    event BatchClaimRewards(address[] targets);
    event DistributeRewards(
        bytes32 indexed merkleRoot, address indexed account, address indexed rewardToken, uint256 amount
    );
    event MerkleRootUpdated(bytes32 indexed merkleRoot, bool status);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if a merkle root is registered
    /// @param merkleRoot The merkle root to check
    function isMerkleRootRegistered(bytes32 merkleRoot) external view returns (bool);
    /// @notice Get the locked amount of an account for a token
    /// @param account The account to get the locked amount for
    function viewLockedAmount(address account, address token) external view returns (uint256);
    /// @notice Get all the locked assets of an account
    /// @param account The account to get the locked assets for
    function viewAllLockedAssets(address account) external view returns (address[] memory);
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

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Update the merkle root
    /// @param merkleRoot The merkle root to update
    /// @param status The status of the merkle root (true: active, false: inactive)
    function updateMerkleRoot(bytes32 merkleRoot, bool status) external;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Lock an asset for an account
    /// @param account The account to lock the asset for
    /// @param token The asset to lock
    /// @param amount The amount of the asset to lock
    function lock(address account, address token, uint256 amount) external;
    /// @notice Unlock an asset for an account
    /// @param account The account to unlock the asset for
    /// @param token The asset to unlock
    /// @param amount The amount of the asset to unlock
    function unlock(address account, address token, uint256 amount) external;
    /// @notice Batch unlock assets for an account
    /// @param account The account to unlock the assets for
    /// @param tokens The assets to unlock
    /// @param amounts The amounts of the assets to unlock
    function batchUnlock(address account, address[] calldata tokens, uint256[] calldata amounts) external;
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
