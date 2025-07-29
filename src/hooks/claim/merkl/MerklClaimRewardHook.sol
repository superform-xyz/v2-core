// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IDistributor } from "../../../vendor/merkl/IDistributor.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import {
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title MerklClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address distributor = BytesLib.toAddress(data, 32);
/// @notice         uint256 usersLength = BytesLib.toUint256(data, 52);
/// @notice         address[] users = BytesLib.slice(data, 64, usersLength * 20);
/// @notice         uint256 tokensLength = BytesLib.toUint256(data, 64 + usersLength * 20, 32);
/// @notice         address[] tokens = BytesLib.slice(data, 64 + usersLength * 20 + 32, tokensLength * 20);
/// @notice         uint256 amountsLength = BytesLib.toUint256(data, 64 + usersLength * 20 + 32 + tokensLength * 20, 32);
/// @notice         uint256[] amounts = BytesLib.slice(data, 64 + usersLength * 20 + tokensLength * 20 + 64, amountsLength * 32);
/// @notice         uint256 proofsLength = BytesLib.toUint256(data, 64 + usersLength * 20 + tokensLength * 20 + amountsLength * 32 + 64, 32);
/// @notice         bytes32[][] proofs = BytesLib.slice(data, 64 + usersLength * 20 + tokensLength * 20 + amountsLength * 32 + 96, data.length - proofsLength * 32);
contract MerklClaimRewardHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    error INVALID_PROOF();

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) { }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        (address distributor, address[] memory users, address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) = _decodeClaimParams(data);

        return _build(distributor, abi.encodeCall(IDistributor.claim, (users, tokens, amounts, proofs)));
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256) external pure returns (bytes memory) {
        return data;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        (address distributor, address[] memory users, address[] memory tokens,,) = _decodeClaimParams(data);
        return abi.encodePacked(distributor, users, tokens);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }

    function _decodeClaimParams(bytes calldata data) internal pure returns (address distributor, address[] memory users, address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) {
        distributor = data.extractYieldSource();
        if (distributor == address(0)) revert ADDRESS_NOT_VALID();

        uint256 users_paramLength = BytesLib.toUint256(data, 52);
        for (uint256 i = 0; i < users_paramLength; i++) {
            address user = BytesLib.toAddress(data, 64 + i * 32);
            if (user == address(0)) revert ADDRESS_NOT_VALID();
            users[i] = user;
        }

        uint256 tokens_paramLength = BytesLib.toUint256(data, 64 + users_paramLength);
        for (uint256 i = 0; i < tokens_paramLength; i++) {
            address token = BytesLib.toAddress(data, 64 + users_paramLength + i * 32);
            if (token == address(0)) revert ADDRESS_NOT_VALID();
            tokens[i] = token;
        }
        
        uint256 amounts_paramLength = BytesLib.toUint256(data, 64 + users_paramLength + tokens_paramLength);
        for (uint256 i = 0; i < amounts_paramLength; i++) {
            uint256 amount = BytesLib.toUint256(data, 64 + users_paramLength + tokens_paramLength + i * 32);
            if (amount == 0) revert AMOUNT_NOT_VALID();
            amounts[i] = amount;
        }

        uint256 proofs_paramLength = BytesLib.toUint256(data, 64 + users_paramLength + tokens_paramLength + amounts_paramLength);
        for (uint256 i = 0; i < proofs_paramLength; i++) {
            bytes32 proof = BytesLib.toBytes32(data, 64 + users_paramLength + tokens_paramLength + amounts_paramLength + i * 32);
            if (proof == bytes32(0)) revert INVALID_PROOF();
            proofs[i] = proof;
        }
    }

}