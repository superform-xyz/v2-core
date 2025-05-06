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
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { VaultBankDestination } from "./VaultBankDestination.sol";
import { VaultBankSource } from "./VaultBankSource.sol";

/// @title VaultBank
/// @author Superform Labs
/// @notice Locks assets and mints SuperPositions
contract VaultBank is Ownable, IVaultBank, VaultBankSource, VaultBankDestination {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable prover;
    address public immutable governor;

    mapping(address account => mapping(uint64 toChainId => uint256 nonce)) public nonces;
    mapping(address account => mapping(uint64 fromChainId => mapping(uint256 nonce => bool isUsed))) public noncesUsed;

    constructor(
        address owner_,
        address prover_,
        address governor_
    )
        Ownable(owner_)
    {
        if (prover_ == address(0) || governor_ == address(0)) revert INVALID_VALUE();

        prover = prover_;
        governor = governor_;
    }

    modifier onlyExecutor() {
        if (!ISuperGovernor(governor).isExecutor(msg.sender)) revert INVALID_EXECUTOR();
        _;
    }

    modifier onlyRelayer() {
        if (!ISuperGovernor(governor).isRelayer(msg.sender)) revert INVALID_RELAYER();
        _;
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
    {   
        uint256 _nonce = nonces[account][toChainId];
        nonces[account][toChainId]++;
        _lockAssetForChain(account, token, amount, toChainId, _nonce);
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
        // validate and mark `proof.nonce[fromChainId]` as used
        _validateUnlockAssetProof(account, token, amount, fromChainId, proof);

        //`toChainId` is current chain
        uint256 _nonce = nonces[account][uint64(block.chainid)];
        nonces[account][uint64(block.chainid)]++;
        _releaseAssetFromChain(account, token, amount, fromChainId, _nonce);
    }


    /// @inheritdoc IVaultBank
    function claim(address target, uint256 gasLimit, uint16 maxReturnDataCopy, bytes calldata data) external payable onlyRelayer {
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
        onlyRelayer
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
    function batchDistributeRewardsToSuperBank(address[] memory rewards, uint256[] memory amounts) external onlyRelayer {
        uint256 len = rewards.length;
        for (uint256 i; i < len; ++i) {
            _distributeRewardsToSuperBank(rewards[i], amounts[i]);
        }
        emit BatchDistributeRewardsToSuperBank(rewards, amounts);
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
        // validate and mark `proof.nonce[sourceAsset_.chainId]` as used
        _validateDistributeSPProof(account_, sourceAsset_.asset, amount_, sourceAsset_.chainId, proof_);

        address spAddress = _retrieveSuperPosition(
            sourceAsset_.chainId, sourceAsset_.asset, sourceAsset_.name, sourceAsset_.symbol, sourceAsset_.decimals
        );
        _mintSP(account_, spAddress, amount_);

        //`toChainId` is current chain
        uint256 _nonce = nonces[account_][uint64(block.chainid)];
        nonces[account_][uint64(block.chainid)]++;
        emit SuperpositionsMinted(
            account_,
            spAddress,
            sourceAsset_.asset,
            amount_,
            sourceAsset_.chainId,
            _nonce
        );
    }
    
    /// @inheritdoc IVaultBank
    function burnSuperPosition(uint256 amount_, address spAddress_, uint64 forChainId_) external override {
        _burnSP(msg.sender, spAddress_, amount_);
        uint256 _nonce = nonces[msg.sender][forChainId_];
        nonces[msg.sender][forChainId_]++;
        emit SuperpositionsBurned(
            msg.sender,
            spAddress_,
            _superPositionToToken[spAddress_][forChainId_],
            amount_,
            forChainId_,
            _nonce
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _distributeRewardsToSuperBank(address token, uint256 amount) internal {
        // get SuperBank address
        ISuperGovernor governorContract = ISuperGovernor(governor);
        address superBank = governorContract.getAddress(governorContract.SUPER_BANK());
        
        if (token == address(0)) {
            // distribute ETH
            (bool success, ) = superBank.call{value: amount}('');
            if (!success) revert INVALID_VALUE();
        } else {
            // distribute ERC20
            IERC20(token).safeTransfer(superBank, amount);
        }
    }

    function _validateDistributeSPProof(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        internal
    {
        (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData) =
            ICrossL2ProverV2(prover).validateEvent(proof);

        if (emittingContract != address(this)) revert INVALID_PROOF_EMITTER();

        _validateSPTopics(account, token, topics);
        _validateSPData(account, amount, fromChainId, chainId, unindexedData);
    }
    function _validateSPTopics(address account, address token, bytes memory topics) private pure {
        bytes32 eventSelector = topics.toBytes32(0); // event signature
        bytes32 eventAccount = topics.toBytes32(32); // account
        bytes32 eventSrcTokenAddress = topics.toBytes32(96); // srcTokenAddress

        if (eventSelector != IVaultBankSource.SharesLocked.selector) revert INVALID_PROOF_EVENT();
        if (eventAccount != keccak256(abi.encodePacked(account))) revert INVALID_PROOF_ACCOUNT();
        if (eventSrcTokenAddress != keccak256(abi.encodePacked(token))) revert INVALID_PROOF_TOKEN();
    }
    function _validateSPData(
        address account,
        uint256 amount,
        uint64 fromChainId,
        uint32 chainId,
        bytes memory unindexedData
    ) private {
        (uint256 eventAmount, uint64 eventSrcChainId, uint64 eventDstChainId, uint256 eventNonce) =
            abi.decode(unindexedData, (uint256, uint64, uint64, uint256));

        if (eventAmount != amount) revert INVALID_PROOF_AMOUNT();
        if (eventSrcChainId != fromChainId || uint64(chainId) != fromChainId) revert INVALID_PROOF_SOURCE_CHAIN();
        if (eventDstChainId != _chainId) revert INVALID_PROOF_TARGETED_CHAIN();
        if (noncesUsed[account][fromChainId][eventNonce]) revert NONCE_ALREADY_USED();
        noncesUsed[account][fromChainId][eventNonce] = true;
    }

    function _validateUnlockAssetProof(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        internal
    {
        (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData) =
            ICrossL2ProverV2(prover).validateEvent(proof);

        if (uint64(chainId) != fromChainId) revert INVALID_PROOF_CHAIN();
        if (emittingContract != address(this)) revert INVALID_PROOF_EMITTER();

        _validateUnlockTopics(account, token, topics);
        _validateUnlockData(account, amount, fromChainId, unindexedData);
    }
    function _validateUnlockTopics(address account, address token, bytes memory topics) private pure {
        if (topics.toBytes32(0) != IVaultBank.SuperpositionsBurned.selector) revert INVALID_PROOF_EVENT();
        if (topics.toBytes32(32) != keccak256(abi.encodePacked(account))) revert INVALID_PROOF_ACCOUNT();
        if (topics.toBytes32(96) != keccak256(abi.encodePacked(token))) revert INVALID_PROOF_TOKEN();
    }
    function _validateUnlockData(
        address account,
        uint256 amount,
        uint64 fromChainId,
        bytes memory unindexedData
    ) private {
        (uint256 eventAmount, uint64 eventChainId, uint256 eventNonce) =
            abi.decode(unindexedData, (uint256, uint64, uint256));

        if (eventAmount != amount) revert INVALID_PROOF_AMOUNT();
        if (eventChainId != _chainId) revert INVALID_PROOF_TARGETED_CHAIN();
        if (noncesUsed[account][fromChainId][eventNonce]) revert NONCE_ALREADY_USED();
        noncesUsed[account][fromChainId][eventNonce] = true;
    }

}
