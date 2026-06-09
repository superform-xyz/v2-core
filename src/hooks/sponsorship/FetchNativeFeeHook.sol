// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { INativeFeeSponsorship } from "../../interfaces/INativeFeeSponsorship.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../interfaces/ISuperHook.sol";

/// @title FetchNativeFeeHook
/// @author Superform Labs
/// @notice Withdraws sponsored native ETH from NativeFeeSponsorship before bridge operations
/// @dev Designed to be placed immediately before a Stargate bridge hook in the execution chain
/// @dev data layout (52 bytes, abi.encodePacked):
///      address sponsor = BytesLib.toAddress(data, 0);
///      uint256 amount = BytesLib.toUint256(data, 20);
contract FetchNativeFeeHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is shorter than the minimum required length
    error INVALID_DATA_LENGTH();

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The NativeFeeSponsorship ledger contract
    address public immutable SPONSORSHIP;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant SPONSOR_POSITION = 0;
    uint256 private constant AMOUNT_POSITION = 20;
    uint256 private constant MIN_DATA_LENGTH = 52; // 20 (address) + 32 (uint256)

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address sponsorship_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (sponsorship_ == address(0)) revert ADDRESS_NOT_VALID();
        SPONSORSHIP = sponsorship_;
    }

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
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        address sponsor = BytesLib.toAddress(data, SPONSOR_POSITION);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);

        if (sponsor == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: SPONSORSHIP,
            value: 0,
            callData: abi.encodeCall(INativeFeeSponsorship.withdrawSponsoredNative, (sponsor, amount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
        return _replaceCalldataAmount(data, amount, AMOUNT_POSITION);
    }

    /// @inheritdoc BaseHook
    /// @dev PROTOCOL REQUIREMENT: Inspector functions MUST only return addresses
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(SPONSORSHIP);
    }
}
