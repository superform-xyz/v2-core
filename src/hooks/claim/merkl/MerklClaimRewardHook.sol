// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IDistributor } from "../../../vendor/merkl/IDistributor.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

import "forge-std/console2.sol";

/// @title MerklClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         uint256 arraysLength = BytesLib.toUint256(data, 0);
/// @notice         address[] tokens = BytesLib.slice(data, 32, arraysLength * 20);
/// @notice         uint256[] amounts = BytesLib.slice(data, 32 + arraysLength * 20, arraysLength * 32);
/// @notice         bytes proofBlob = BytesLib.slice(data, 32 + arraysLength * 20 + arraysLength * 32, data.length - (32
/// + arraysLength * 20 + arraysLength * 32));
contract MerklClaimRewardHook is BaseHook {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    error INVALID_ENCODING();
    error FEE_NOT_VALID();

    address public immutable distributor;
    address public immutable feeReceiver;
    uint256 public immutable feePercent;

    uint256 public constant BPS = 10_000;

    struct ClaimParams {
        address[] users;
        address[] tokens;
        uint256[] amounts;
        bytes32[][] proofs;
    }

    constructor(address _distributor, address _feeReceiver, uint256 _feePercent) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (_distributor == address(0) || _feeReceiver == address(0)) revert ADDRESS_NOT_VALID();
        if (_feePercent > BPS) revert FEE_NOT_VALID();
        distributor = _distributor;
        feeReceiver = _feeReceiver;
        feePercent = _feePercent;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        ClaimParams memory params;

        // decode users
        address[] memory users = _setUsersArray(account, data);
        params.users = users;

        // decode other params
        (params.tokens, params.amounts, params.proofs) = _decodeClaimParams(data);

        executions = new Execution[](users.length + 1);
        executions[0] = Execution({
            target: distributor,
            value: 0,
            callData: abi.encodeCall(IDistributor.claim, (params.users, params.tokens, params.amounts, params.proofs))
        });

        // Known limitations:
        // - can't verify deviations in the transfer (won't actually execute the code until the `handleOps` execution)
        // - `feeReceiver` and `feePercent` must be configured by the hook instead of the ledgers
        // - won't work for tokens reverting on 0 amount transfer in case of 0 fees
        uint256 len = users.length;
        for (uint256 i; i < len; ++i ) {
            uint208 amount;
            uint256 fee;

            console2.log("------------- feePercent", feePercent);
            if (feePercent > 0) {
                (amount, , ) = IDistributor(distributor).claimed(
                    params.users[i],
                    params.tokens[i]
                );
                fee = ((params.amounts[i] - amount) * feePercent) / BPS;
            }

            executions[i + 1] = Execution({
                target: params.tokens[i],
                value: 0,
                callData: abi.encodeCall(IERC20.transfer, (feeReceiver, fee))
            });
       }
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory addressData) {
        (address[] memory tokens,,) = _decodeClaimParams(data);

        uint256 length = tokens.length;
        for (uint256 i; i < length; i++) {
            addressData = bytes.concat(addressData, bytes20(tokens[i]));
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

    function _decodeClaimParams(bytes calldata data)
        internal
        pure
        returns (address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs)
    {
        // decode tokens and amounts
        (uint256 cursorAfterAmounts, address[] memory _tokens, uint256[] memory _amounts) =
            _decodeTokensAndAmounts(data);

        tokens = _tokens;
        amounts = _amounts;

        // decode proofs
        proofs = _decodeProofs(data, cursorAfterAmounts);
    }

    function _setUsersArray(address account, bytes calldata data) internal pure returns (address[] memory users) {
        uint256 arrayLength = BytesLib.toUint256(data, 0);

        users = new address[](arrayLength);
        for (uint256 i; i < arrayLength; i++) {
            users[i] = account;
        }
    }

    function _decodeTokensAndAmounts(bytes calldata data)
        internal
        pure
        returns (uint256 cursor, address[] memory tokens, uint256[] memory amounts)
    {
        uint256 arrayLength = BytesLib.toUint256(data, 0);
        cursor = 32;

        tokens = new address[](arrayLength);
        for (uint256 i; i < arrayLength; i++) {
            address token = BytesLib.toAddress(data, cursor);
            cursor += 20;

            if (token == address(0)) revert ADDRESS_NOT_VALID();
            tokens[i] = token;
        }

        amounts = new uint256[](arrayLength);
        for (uint256 i; i < arrayLength; i++) {
            uint256 amount = BytesLib.toUint256(data, cursor);
            cursor += 32;

            if (amount == 0) revert AMOUNT_NOT_VALID();
            amounts[i] = amount;
        }
    }

    function _decodeProofs(bytes calldata data, uint256 cursor) internal pure returns (bytes32[][] memory proofs) {
        uint256 arrayLength = BytesLib.toUint256(data, 0);
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
