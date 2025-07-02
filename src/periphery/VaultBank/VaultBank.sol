// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICrossL2ProverV2 } from "../../vendor/polymer/ICrossL2ProverV2.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { VaultBankSuperPosition } from "./VaultBankSuperPosition.sol";
import { IVaultBank, IVaultBankSource } from "../interfaces/VaultBank/IVaultBank.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { VaultBankDestination } from "./VaultBankDestination.sol";
import { VaultBankSource } from "./VaultBankSource.sol";
import { Bank } from "../Bank.sol";

/// @title VaultBank
/// @author Superform Labs
/// @notice Locks assets and mints SuperPositions
contract VaultBank is IVaultBank, VaultBankSource, VaultBankDestination, Bank {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperGovernor public immutable SUPER_GOVERNOR;

    mapping(uint64 toChainId => uint256 nonce) public nonces;
    mapping(uint64 fromChainId => mapping(uint256 nonce => bool isUsed)) public noncesUsed;

    constructor(address governor_) {
        if (governor_ == address(0)) revert INVALID_VALUE();
        SUPER_GOVERNOR = ISuperGovernor(governor_);
    }

    modifier onlyRelayer() {
        if (!SUPER_GOVERNOR.isRelayer(msg.sender)) revert INVALID_RELAYER();
        _;
    }

    modifier onlyBankManager() {
        if (!IAccessControl(address(SUPER_GOVERNOR)).hasRole(SUPER_GOVERNOR.BANK_MANAGER_ROLE(), msg.sender)) {
            revert INVALID_BANK_MANAGER();
        }
        _;
    }

    /// @dev to receive ETH rewards
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    // ------------------ SOURCE VAULTBANK METHODS ------------------
    /// @inheritdoc IVaultBank
    function lockAsset(
        bytes32 yieldSourceOracleId,
        address account,
        address token,
        address hookAddress,
        uint256 amount,
        uint64 toChainId
    )
        external
    {
        address vaultBank = SUPER_GOVERNOR.getVaultBank(toChainId);

        if (vaultBank == address(0)) revert INVALID_VAULT_BANK_ADDRESS();
        if (!SUPER_GOVERNOR.isHookRegistered(hookAddress)) revert INVALID_HOOK();

        uint256 _nonce = nonces[toChainId];
        nonces[toChainId]++;
        _lockAssetForChain(yieldSourceOracleId, account, token, amount, toChainId, _nonce);
    }

    /// @inheritdoc IVaultBank
    function unlockAsset(
        address account,
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes32 yieldSourceOracleId,
        bytes calldata proof
    )
        external
    {
        // validate and mark `proof.nonce[fromChainId]` as used
        _validateUnlockAssetProof(token, amount, fromChainId, proof);

        //`toChainId` is current chain
        uint256 _nonce = nonces[uint64(_chainId)];
        nonces[uint64(_chainId)]++;
        _releaseAssetFromChain(yieldSourceOracleId, account, token, amount, fromChainId, _nonce);
    }

    /// @inheritdoc IVaultBank
    function executeHooks(IVaultBank.HookExecutionData calldata executionData) external onlyBankManager {
        _executeHooks(executionData);
    }

    /// @inheritdoc IVaultBank
    function batchDistributeRewardsToSuperBank(
        address[] memory rewards,
        uint256[] memory amounts
    )
        external
        onlyRelayer
    {
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
        _validateDistributeSPProof(sourceAsset_.asset, amount_, sourceAsset_.chainId, proof_);

        address spAddress = _retrieveSuperPosition(
            sourceAsset_.yieldSourceOracleId, sourceAsset_.chainId, sourceAsset_.asset, sourceAsset_.name, sourceAsset_.symbol, sourceAsset_.decimals
        );
        _mintSP(account_, spAddress, amount_);

        nonces[uint64(_chainId)]++;

        emit SuperpositionsMinted(
            account_, spAddress, sourceAsset_.asset, amount_, sourceAsset_.chainId, _extractNonce(proof_)
        );
    }

    /// @inheritdoc IVaultBank
    function burnSuperPosition(uint256 amount_, address spAddress_, uint64 forChainId_, bytes32 yieldSourceOracleId_) external override {
        _burnSP(msg.sender, spAddress_, amount_);
        uint256 _nonce = nonces[forChainId_];
        nonces[forChainId_]++;
        emit SuperpositionsBurned(
            msg.sender, spAddress_, _spAssetsInfo[spAddress_].spToToken[forChainId_][yieldSourceOracleId_], amount_, forChainId_, _nonce
        );
    }

    function transferSuperPositionOwnership(address superPos, address newOwner) external onlyBankManager {
        VaultBankSuperPosition(superPos).transferOwnership(newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _getMerkleRootForHook(address hookAddress) internal view override returns (bytes32) {
        return SUPER_GOVERNOR.getVaultBankHookMerkleRoot(hookAddress);
    }

    function _distributeRewardsToSuperBank(address token, uint256 amount) internal {
        // get SuperBank address
        address superBank = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_BANK());

        if (token == address(0)) {
            // distribute ETH
            (bool success,) = superBank.call{ value: amount }("");
            if (!success) revert INVALID_VALUE();
        } else {
            // distribute ERC20
            IERC20(token).safeTransfer(superBank, amount);
        }
    }

    function _validateDistributeSPProof(
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        internal
    {
        (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData) =
            ICrossL2ProverV2(SUPER_GOVERNOR.getProver()).validateEvent(proof);

        address vaultBank = SUPER_GOVERNOR.getVaultBank(uint64(fromChainId));

        if (emittingContract != vaultBank) revert INVALID_PROOF_EMITTER();

        _validateSPTopics(token, topics);
        _validateSPData(amount, fromChainId, chainId, unindexedData);
    }

    function _extractNonce(bytes calldata proof_) internal view returns (uint256) {
        (,,, bytes memory unindexedData) = ICrossL2ProverV2(SUPER_GOVERNOR.getProver()).validateEvent(proof_);

        (,,, uint256 eventNonce) = abi.decode(unindexedData, (uint256, uint64, uint64, uint256));
        return eventNonce;
    }

    function _validateSPTopics(address token, bytes memory topics) private pure {
        bytes32 eventSelector = topics.toBytes32(0); // event signature
        bytes32 eventSrcTokenAddress = topics.toBytes32(96); // srcTokenAddress

        if (eventSelector != IVaultBankSource.SharesLocked.selector) revert INVALID_PROOF_EVENT();
        if (eventSrcTokenAddress != keccak256(abi.encodePacked(token))) revert INVALID_PROOF_TOKEN();
    }

    function _validateSPData(uint256 amount, uint64 fromChainId, uint32 chainId, bytes memory unindexedData) private {
        (uint256 eventAmount, uint64 eventSrcChainId, uint64 eventDstChainId, uint256 eventNonce) =
            abi.decode(unindexedData, (uint256, uint64, uint64, uint256));

        if (eventAmount != amount) revert INVALID_PROOF_AMOUNT();
        if (eventSrcChainId != fromChainId || uint64(chainId) != fromChainId) revert INVALID_PROOF_SOURCE_CHAIN();
        if (eventDstChainId != _chainId) revert INVALID_PROOF_TARGETED_CHAIN();
        if (noncesUsed[fromChainId][eventNonce]) revert NONCE_ALREADY_USED();
        noncesUsed[fromChainId][eventNonce] = true;
    }

    function _validateUnlockAssetProof(
        address token,
        uint256 amount,
        uint64 fromChainId,
        bytes calldata proof
    )
        internal
    {
        (uint32 chainId, address emittingContract, bytes memory topics, bytes memory unindexedData) =
            ICrossL2ProverV2(SUPER_GOVERNOR.getProver()).validateEvent(proof);

        if (uint64(chainId) != fromChainId) revert INVALID_PROOF_CHAIN();

        address vaultBank = SUPER_GOVERNOR.getVaultBank(uint64(fromChainId));

        if (emittingContract != vaultBank) revert INVALID_PROOF_EMITTER();

        _validateUnlockTopics(token, topics);
        _validateUnlockData(amount, fromChainId, unindexedData);
    }

    function _validateUnlockTopics(address token, bytes memory topics) private pure {
        if (topics.toBytes32(0) != IVaultBank.SuperpositionsBurned.selector) revert INVALID_PROOF_EVENT();
        if (topics.toBytes32(96) != keccak256(abi.encodePacked(token))) revert INVALID_PROOF_TOKEN();
    }

    function _validateUnlockData(uint256 amount, uint64 fromChainId, bytes memory unindexedData) private {
        (uint256 eventAmount, uint64 eventChainId, uint256 eventNonce) =
            abi.decode(unindexedData, (uint256, uint64, uint256));

        if (eventAmount != amount) revert INVALID_PROOF_AMOUNT();
        if (eventChainId != _chainId) revert INVALID_PROOF_TARGETED_CHAIN();
        if (noncesUsed[fromChainId][eventNonce]) revert NONCE_ALREADY_USED();
        noncesUsed[fromChainId][eventNonce] = true;
    }
}
