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
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address sponsor = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount = BytesLib.toUint256(data, 72);
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

    uint256 private constant SPONSOR_POSITION = 52;
    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant MIN_DATA_LENGTH = 104; // 52 (header) + 20 (address) + 32 (uint256)

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address sponsorship_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (sponsorship_ == address(0)) revert ADDRESS_NOT_VALID();
        SPONSORSHIP = sponsorship_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Fetch Native Fee";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Fetches native gas fee for sponsored transactions";
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
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc BaseHook
    /// @dev PROTOCOL REQUIREMENT: Inspector functions MUST only return addresses
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(SPONSORSHIP);
    }

    /// @dev Side-effect only hook — forwards previous hook's outAmount + outToken
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }
}
