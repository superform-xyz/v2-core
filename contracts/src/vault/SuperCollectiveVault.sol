// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ExcessivelySafeCall } from "excessivelySafeCall/ExcessivelySafeCall.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";
import { ISuperCollectiveVault } from "../interfaces/vault/ISuperCollectiveVault.sol";

import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract SuperCollectiveVault is ISuperCollectiveVault, SuperRegistryImplementer {
    using ExcessivelySafeCall for address;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Rewards merkle roots
    mapping(bytes32 => bool) private _registeredMerkleRoots;

    // locked assets
    mapping(address => address[]) private _lockedAssets;
    mapping(address => mapping(address => uint256)) private _lockedAmounts;
    mapping(address => mapping(address => mapping(bytes32 => bool))) private _hasBeenDistributed;

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    modifier onlyExecutor() {
        if (_getAddress(superRegistry.SUPER_EXECUTOR_ID()) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    modifier onlySuperCollectiveVaultManager() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SUPER_COLLECTIVE_VAULT_MANAGER())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperCollectiveVault
    function viewLockedAmount(address account, address token) external view returns (uint256) {
        return _lockedAmounts[account][token];
    }

    /// @inheritdoc ISuperCollectiveVault
    function viewAllLockedAssets(address account) external view returns (address[] memory) {
        return _lockedAssets[account];
    }

    /// @inheritdoc ISuperCollectiveVault
    function isMerkleRootRegistered(bytes32 merkleRoot) external view returns (bool) {
        return _registeredMerkleRoots[merkleRoot];
    }

    /// @inheritdoc ISuperCollectiveVault
    function canClaim(
        bytes32 merkleRoot,
        address account,
        address rewardToken,
        uint256 amount,
        bytes32[] calldata proof
    )
        public
        view
        returns (bool)
    {
        if (!_registeredMerkleRoots[merkleRoot]) revert INVALID_MERKLE_ROOT();
        bytes32 leaf = keccak256(abi.encodePacked(account, rewardToken, amount));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperCollectiveVault
    function updateMerkleRoot(bytes32 merkleRoot_, bool status) external onlySuperCollectiveVaultManager {
        _registeredMerkleRoots[merkleRoot_] = status;
        emit MerkleRootUpdated(merkleRoot_, status);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperCollectiveVault
    function lock(address account, address token, uint256 amount) external onlyExecutor {
        if (amount == 0) revert INVALID_AMOUNT();
        if (token == address(0)) revert INVALID_TOKEN();
        if (account == address(0)) revert INVALID_ACCOUNT();
        _lockedAmounts[account][token] += amount;
        _lockedAssets[account].push(token);

        IERC20(token).safeTransferFrom(account, address(this), amount);
        emit Lock(account, token, amount);
    }

    /// @inheritdoc ISuperCollectiveVault
    function unlock(address account, address token, uint256 amount) external onlySuperCollectiveVaultManager {
        if (account == address(0)) revert INVALID_ACCOUNT();
        _unlock(account, token, amount);
    }

    /// @inheritdoc ISuperCollectiveVault
    function batchUnlock(address account, address[] calldata tokens, uint256[] calldata amounts) external onlySuperCollectiveVaultManager {
        if (account == address(0)) revert INVALID_ACCOUNT();

        uint256 len = tokens.length;
        if (len != amounts.length) revert INVALID_VALUE();
        for (uint256 i = 0; i < len; i++) {
            _unlock(account, tokens[i], amounts[i]);
        }
    }

    /// @inheritdoc ISuperCollectiveVault
    function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes calldata data) external payable {
        bytes memory result = _claim(target, gasLimit, msg.value, maxReturnDataCopy, data);
        emit ClaimRewards(target, result);
    }

    /// @inheritdoc ISuperCollectiveVault
    function batchClaim(
        address[] calldata targets,
        uint256[] calldata gasLimit,
        uint256[] calldata val,
        uint16 maxReturnDataCopy,
        bytes calldata data
    )
        external
        payable
    {

        uint256 totalValue;
        uint256 len = targets.length;
        for (uint256 i = 0; i < len;) {
            totalValue += val[i];
            unchecked {
                ++i;
            }
        }
        if (msg.value < totalValue) revert INVALID_VALUE();

        for (uint256 i = 0; i < len;) {
            bytes memory result = _claim(targets[i], gasLimit[i], val[i], maxReturnDataCopy, data);
            emit ClaimRewards(targets[i], result);
            unchecked {
                ++i;
            }
        }

        emit BatchClaimRewards(targets);
    }

    /// @inheritdoc ISuperCollectiveVault
    function distributeRewards(
        bytes32 merkleRoot,
        address account,
        address rewardToken,
        uint256 amount,
        bytes32[] calldata proof
    )
        external
    {   
        if (account == address(0)) revert INVALID_ACCOUNT();
        if (amount == 0) revert INVALID_AMOUNT();
        if (rewardToken == address(0)) revert INVALID_TOKEN();
        if (!_registeredMerkleRoots[merkleRoot]) revert INVALID_MERKLE_ROOT();
        if (!canClaim(merkleRoot, account, rewardToken, amount, proof)) revert NOTHING_TO_CLAIM();
        if (_hasBeenDistributed[account][rewardToken][merkleRoot]) revert ALREADY_DISTRIBUTED();

        IERC20(rewardToken).safeTransfer(account, amount);
        _hasBeenDistributed[account][rewardToken][merkleRoot] = true;
        emit DistributeRewards(merkleRoot, account, rewardToken, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }

    function _claim(
        address target,
        uint256 gasLimit,
        uint256 value,
        uint16 maxReturnDataCopy,
        bytes calldata data
    )
        private
        returns (bytes memory)
    {
        if (target == address(0) || target == address(this)) revert INVALID_CLAIM_TARGET();
        (bool success, bytes memory result) = target.excessivelySafeCall(gasLimit, value, maxReturnDataCopy, data);
        if (!success) revert CLAIM_FAILED();
        return result;
    }

    function _removeFromLockedAssets(address account, address token) private {
        uint256 len = _lockedAssets[account].length;
        if (len == 0) revert NO_LOCKED_ASSETS();

        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < len;) {
            if (_lockedAssets[account][i] == token) {
                index = i;
                found = true;
                break;
            }

            unchecked {
                ++i;
            }
        }

        if (!found) revert TOKEN_NOT_FOUND();

        if (index != len - 1) {
            _lockedAssets[account][index] = _lockedAssets[account][len - 1];
        }
        _lockedAssets[account].pop();
    }
    
    function _unlock(address account, address token, uint256 amount) private {
        if (token == address(0)) revert INVALID_TOKEN();
        if (amount == 0 || amount > _lockedAmounts[account][token]) revert INVALID_AMOUNT();
        _lockedAmounts[account][token] -= amount;
        _removeFromLockedAssets(account, token);

        IERC20(token).safeTransfer(account, amount);
        emit Unlock(account, token, amount);
    }
}
