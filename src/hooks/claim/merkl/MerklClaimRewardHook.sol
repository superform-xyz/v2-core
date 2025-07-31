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
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title MerklClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address distributor = BytesLib.toAddress(data, 32);
/// @notice         uint256 arraysLength = BytesLib.toUint256(data, 52);
/// @notice         address[] users = BytesLib.slice(data, 84, arrayLength * 20);
/// @notice         address[] tokens = BytesLib.slice(data, 84 + arrayLength * 20, tokensLength * 20);
/// @notice         uint256[] amounts = BytesLib.slice(data, 84 + arrayLength * 20 + tokensLength * 20, amountsLength * 32);
/// @notice         bytes proofBlob = BytesLib.slice(data, 84 + arrayLength * 20 + tokensLength * 20 + amountsLength * 32, data.length - (84 + arrayLength * 20 + tokensLength * 20 + amountsLength * 32));
contract MerklClaimRewardHook is
    BaseHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    error INVALID_PROOF();
    error INVALID_LENGTH();
    error LENGTH_MISMATCH();
    error INVALID_ENCODING();

    struct ClaimParams {
        address distributor;
        uint256 arrayLength;
        address[] users;
        address[] tokens;
        uint256[] amounts;
        bytes32[][] proofs;
    }

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) { }

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
        ClaimParams memory params = _decodeClaimParams(data);

        executions = new Execution[](1);
        executions[0] = Execution({ 
            target: params.distributor, 
            value: 0, 
            callData: abi.encodeCall(IDistributor.claim, (params.users, params.tokens, params.amounts, params.proofs)) 
        });
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
        ClaimParams memory params = _decodeClaimParams(data);

        bytes memory addressData = abi.encodePacked(params.distributor);
        for (uint256 i = 0; i < params.users.length; i++) {
            addressData = bytes.concat(addressData, bytes20(params.users[i]));
        }

        for (uint256 i = 0; i < params.tokens.length; i++) {
            addressData = bytes.concat(addressData, bytes20(params.tokens[i]));
        }

        return addressData;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(0, account);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(0, account);
    }

    function _decodeClaimParams(bytes calldata data) internal pure returns (ClaimParams memory params) {
        // decode distributor address
        params.distributor = BytesLib.toAddress(data, 32);
        if (params.distributor == address(0)) revert ADDRESS_NOT_VALID();

        // decode users
        (uint256 cursorAfterUsers, address[] memory users) = _decodeUsers(data);
        params.users = users;

        // decode tokens and amounts
        (
            uint256 cursorAfterAmounts,
            address[] memory tokens,
            uint256[] memory amounts
        ) = _decodeTokensAndAmounts(data, cursorAfterUsers);

        params.tokens = tokens;
        params.amounts = amounts;

        // decode proofs
        params.proofs = _decodeProofs(data, cursorAfterAmounts);
    }

    function _decodeUsers(bytes calldata data) internal pure returns (uint256 cursor, address[] memory users) {
        // decode array length
        uint256 arrayLength = BytesLib.toUint256(data, 52);

        cursor = 84;
        users = new address[](arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            address user = BytesLib.toAddress(data, cursor);
            cursor += 20;

            if (user == address(0)) revert ADDRESS_NOT_VALID();
            users[i] = user;
        }
    }

    function _decodeTokensAndAmounts(
        bytes calldata data,
        uint256 cursorAfterUsers
    )
        internal
        pure
        returns (
            uint256 cursor,
            address[] memory tokens,
            uint256[] memory amounts
        )
    {   
        uint256 arrayLength = BytesLib.toUint256(data, 52);

        cursor = cursorAfterUsers;

        tokens = new address[](arrayLength); 
        for (uint256 i = 0; i < arrayLength; i++) {
            address token = BytesLib.toAddress(data, cursor);
            cursor += 20;

            if (token == address(0)) revert ADDRESS_NOT_VALID();
            tokens[i] = token;
        }

        amounts = new uint256[](arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            uint256 amount = BytesLib.toUint256(data, cursor);
            cursor += 32;

            if (amount == 0) revert AMOUNT_NOT_VALID();
            amounts[i] = amount;
        }
    }

    function _decodeProofs(
        bytes calldata data,
        uint256 cursor
    )
        internal
        pure
        returns (bytes32[][] memory proofs)
    {
        uint256 arrayLength = BytesLib.toUint256(data, 52);
        proofs = new bytes32[][](arrayLength);

        for (uint256 i; i < arrayLength; ++i) {
            uint256 innerLength = BytesLib.toUint256(data, cursor);
            cursor += 32;

            bytes32[] memory proof = new bytes32[](innerLength);
            for (uint256 j; j < innerLength; ++j) {
                proof[j] = BytesLib.toBytes32(data, cursor);
                cursor += 32;
            }
            proofs[i] = proof;
        }

        // sanity‑check: cursor should now equal data.length
        if (cursor != data.length) revert INVALID_ENCODING();
    }
}
