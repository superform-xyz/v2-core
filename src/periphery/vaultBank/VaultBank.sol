// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ICrossL2ProverV2 } from "../../vendor/polymer/ICrossL2ProverV2.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";

// Superform
import { IVaultBank, IVaultBankSource } from "../interfaces/IVaultBank.sol";
import { VaultBankSource } from "./VaultBankSource.sol";
import { VaultBankDestination } from "./VaultBankDestination.sol";

contract VaultBank is Ownable, IVaultBank, VaultBankSource, VaultBankDestination {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public prover;

    //TODO: check with Sish if we need a different nonce mechanism
    mapping(address account => mapping(uint64 chainId => uint256 nonce)) public nonces;
    mapping(address => bool) private _allowedExecutors;
    mapping(uint64 => bool) private _allowedChains;
    mapping(address => bool) private _allowedRelayers;

    constructor(
        address owner_,
        address prover_,
        address[] memory allowedExecutors_,
        uint64[] memory allowedChains_,
        address[] memory allowedRelayers_
    )
        Ownable(owner_)
    {
        uint256 len = allowedExecutors_.length;
        for (uint256 i = 0; i < len; i++) {
            _allowedExecutors[allowedExecutors_[i]] = true;
        }

        len = allowedChains_.length;
        for (uint256 i = 0; i < len; i++) {
            _allowedChains[allowedChains_[i]] = true;
        }

        len = allowedRelayers_.length;
        for (uint256 i = 0; i < len; i++) {
            _allowedRelayers[allowedRelayers_[i]] = true;
        }

        prover = prover_;
    }

    modifier onlyExecutor() {
        if (!_allowedExecutors[msg.sender]) revert INVALID_EXECUTOR();
        _;
    }

    // TODO: should be free for all? maybe we can remove this to avoid managing dst chains
    modifier onlyAllowedDestination(uint64 chainId_) {
        if (!_allowedChains[chainId_]) revert INVALID_CHAIN();
        _;
    }

    modifier onlyRelayer() {
        if (!_allowedRelayers[msg.sender]) revert INVALID_RELAYER();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IVaultBank
    function updateMerkleRoot(bytes32 merkleRoot_, bool status) external onlyOwner {
        _registeredMerkleRoots[merkleRoot_] = status;
        emit MerkleRootUpdated(merkleRoot_, status);
    }

    /// @inheritdoc IVaultBank
    function updateChainStatus(uint64 dstChainId_, bool status_) external onlyOwner {
        _allowedChains[dstChainId_] = status_;
        emit DestinationChainUpdated(dstChainId_, status_);
    }

    /// @inheritdoc IVaultBank
    function updateRelayerStatus(address relayer_, bool status_) external onlyOwner {
        _allowedRelayers[relayer_] = status_;
        emit RelayerUpdated(relayer_, status_);
    }

    /// @inheritdoc IVaultBank
    function updateProver(address prover_) external onlyOwner {
        prover = prover_;
        emit ProverUpdated(prover_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ SOURCE VAULTBANK METHODS ------------------
    /// @inheritdoc IVaultBank
    function lockAsset(
        address account,
        address token,
        uint256 amount,
        uint64 toChainId
    )
        external
        onlyExecutor
        onlyAllowedDestination(toChainId)
    {
        _lockAssetForChain(account, token, amount, toChainId, nonces[account][toChainId]++);
    }

    /// @inheritdoc IVaultBank
    function unlockAsset(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        external
        onlyRelayer
    {
        _validateUnlockAssetProof(account, token, amount, fromChainId, proof);
        _releaseAssetFromChain(account, token, amount, fromChainId, nonces[account][fromChainId]++);
    }

    function _validateUnlockAssetProof(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        internal
        view
    {
        (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData) =
            ICrossL2ProverV2(prover).validateEvent(proof);
        if (uint64(chainId) != fromChainId) revert INVALID_PROOF_CHAIN();
        if (emittingContract != address(this)) revert INVALID_PROOF_EMITTER();

        bytes32 eventSelector = topics.toBytes32(0); // event signature
        bytes32 eventAccount = topics.toBytes32(32); // account
        bytes32 eventSrcTokenAddress = topics.toBytes32(96); // srcTokenAddress

        if (eventSelector != IVaultBank.SuperpositionsBurned.selector) revert INVALID_PROOF_EVENT();
        if (eventAccount != keccak256(abi.encodePacked(account))) revert INVALID_PROOF_ACCOUNT();
        if (eventSrcTokenAddress != keccak256(abi.encodePacked(token))) revert INVALID_PROOF_TOKEN();

        (uint256 eventAmount, uint64 eventChainId,) = abi.decode(unindexedData, (uint256, uint64, uint256));
        if (eventAmount != amount) revert INVALID_PROOF_AMOUNT();
        if (eventChainId != uint64(block.chainid)) revert INVALID_PROOF_TARGETED_CHAIN();
    }

    /// @inheritdoc IVaultBank
    function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes calldata data) external payable {
        bytes memory result = _claimRewards(target, gasLimit, msg.value, maxReturnDataCopy, data);
        emit ClaimRewards(target, result);
    }

    /// @inheritdoc IVaultBank
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
        for (uint256 i = 0; i < len; ++i) {
            totalValue += val[i];
        }
        if (msg.value < totalValue) revert INVALID_VALUE();

        for (uint256 i = 0; i < len; ++i) {
            bytes memory result = _claimRewards(targets[i], gasLimit[i], val[i], maxReturnDataCopy, data);
            emit ClaimRewards(targets[i], result);
        }

        emit BatchClaimRewards(targets);
    }

    /// @inheritdoc IVaultBank
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

    // ------------------ DESTINATION VAULTBANK METHODS ------------------

    /// @inheritdoc IVaultBank
    function distributeSuperPosition(
        address account_,
        uint256 amount_,
        SourceAssetInfo calldata sourceAsset_,
        bytes calldata proof_
    )
        external
        override
        onlyRelayer
    {
        _validateDistributeSPProof(account_, sourceAsset_.asset, amount_, sourceAsset_.chainId, proof_);
        address spAddress = _retrieveSyntheticAsset(
            sourceAsset_.chainId, sourceAsset_.asset, sourceAsset_.name, sourceAsset_.symbol, sourceAsset_.decimals
        );
        _mintSP(account_, spAddress, amount_);
        emit SuperpositionsMinted(
            account_,
            spAddress,
            sourceAsset_.asset,
            amount_,
            sourceAsset_.chainId,
            nonces[account_][uint64(block.chainid)]++
        );
    }

    function _validateDistributeSPProof(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        internal
        view
    {
        (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData) =
            ICrossL2ProverV2(prover).validateEvent(proof);

        if (emittingContract != address(this)) revert INVALID_PROOF_EMITTER();

        bytes32 eventSelector = topics.toBytes32(0); // event signature
        bytes32 eventAccount = topics.toBytes32(32); // account
        bytes32 eventSrcTokenAddress = topics.toBytes32(96); // srcTokenAddress

        if (eventSelector != IVaultBankSource.SharesLocked.selector) revert INVALID_PROOF_EVENT();
        if (eventAccount != keccak256(abi.encodePacked(account))) revert INVALID_PROOF_ACCOUNT();
        if (eventSrcTokenAddress != keccak256(abi.encodePacked(token))) revert INVALID_PROOF_TOKEN();

        (uint256 eventAmount, uint64 eventSrcChainId, uint64 eventDstChainId,) =
            abi.decode(unindexedData, (uint256, uint64, uint64, uint256));

        if (eventAmount != amount) revert INVALID_PROOF_AMOUNT();
        if (eventSrcChainId != fromChainId || uint64(chainId) != fromChainId) revert INVALID_PROOF_SOURCE_CHAIN();
        if (eventDstChainId != uint64(block.chainid)) revert INVALID_PROOF_TARGETED_CHAIN();
    }

    /// @inheritdoc IVaultBank
    function burnSuperPosition(uint256 amount_, address spAddress_, uint64 forChainId_) external override {
        _burnSP(msg.sender, spAddress_, amount_);
        emit SuperpositionsBurned(
            msg.sender,
            spAddress_,
            _syntheticAssetsToToken[spAddress_][forChainId_],
            amount_,
            forChainId_,
            nonces[msg.sender][forChainId_]++
        );
    }
}
