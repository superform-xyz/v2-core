// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

// Superform
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
/// @title ClaimRFLRHook
/// @author Superform Labs
/// @notice Claims rFLR rewards from Flare's RNat contract
/// @dev rFLR tokens are non-transferable, so fee collection is not supported at the claim stage.
///      Fees should be collected at the WFLR withdrawal stage via WithdrawRFLRHook.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint256 projectIdsLength = BytesLib.toUint256(data, 52);
/// @notice         uint256[] projectIds = [BytesLib.toUint256(data, 84 + i*32) for i in 0..projectIdsLength-1]
contract ClaimRFLRHook is BaseHook, ISuperHookInflowOutflow {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error EMPTY_PROJECT_IDS();
    error INVALID_DATA_LENGTH();
    error TOO_MANY_PROJECT_IDS();

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IRNat contract (also the rFLR ERC-20 token)
    address public immutable RNAT;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant PROJECT_IDS_LENGTH_POSITION = 52;
    uint256 private constant PROJECT_IDS_START_POSITION = 84;
    uint256 private constant MAX_PROJECT_IDS = 50;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address rNat_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (rNat_ == address(0)) revert ADDRESS_NOT_VALID();
        RNAT = rNat_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Claim RFLR";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Claims RFLR rewards from the Flare network";
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
        // 1. Validate minimum data length
        if (data.length < PROJECT_IDS_START_POSITION) revert INVALID_DATA_LENGTH();

        // 2. Decode claim params
        uint256 month = IRNat(RNAT).getCurrentMonth();
        uint256[] memory projectIds = _decodeProjectIds(data);

        // 3. Validate
        if (projectIds.length == 0) revert EMPTY_PROJECT_IDS();

        // 4. Build single claim execution (no fee -- rFLR is non-transferable)
        executions = new Execution[](1);
        executions[0] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IRNat.claimRewards, (projectIds, month))
        });
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(RNAT);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Snapshots the rFLR balance before claim execution
    function _preExecute(address, address account, bytes calldata) internal override {
        asset = RNAT;
        _setOutAmount(IERC20(RNAT).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount is the rFLR delta (balance after claim minus balance before claim)
    function _postExecute(address, address account, bytes calldata) internal override {
        uint256 currentBalance = IERC20(RNAT).balanceOf(account);
        uint256 preBalance = getOutAmount(account);
        uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;
        _setOutAmount(delta, account);
        _setOutToken(asset, account);
    }

    /// @dev Decodes project IDs from packed calldata
    /// @param data The packed calldata containing project IDs starting at PROJECT_IDS_START_POSITION
    /// @return projectIds Array of decoded project IDs
    function _decodeProjectIds(bytes calldata data) private pure returns (uint256[] memory projectIds) {
        uint256 length = BytesLib.toUint256(data, PROJECT_IDS_LENGTH_POSITION);
        if (length > MAX_PROJECT_IDS) revert TOO_MANY_PROJECT_IDS();
        projectIds = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            projectIds[i] = BytesLib.toUint256(data, PROJECT_IDS_START_POSITION + i * 32);
        }
    }
}
