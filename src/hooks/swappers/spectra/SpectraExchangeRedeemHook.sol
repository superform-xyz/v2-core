// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { SpectraCommands } from "../../../vendor/spectra/SpectraCommands.sol";

/// @title SpectraExchangeRedeemHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address asset = BytesLib.toAddress(data, 32);
/// @notice         address pt = BytesLib.toAddress(data, 52);
/// @notice         uint256 sharesToBurn = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
/// @dev Payload: abi.encode(address recipient, uint256 minAssets, bytes1 command)
contract SpectraExchangeRedeemHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;
    uint256 private constant AMOUNT_POSITION = 72;
    uint256 private constant PAYLOAD_OFFSET = 105;

    bytes1 public constant REDEEM_IBT_FOR_ASSET = bytes1(uint8(SpectraCommands.REDEEM_IBT_FOR_ASSET));
    bytes1 public constant REDEEM_PT_FOR_ASSET = bytes1(uint8(SpectraCommands.REDEEM_PT_FOR_ASSET));

    bytes4 public constant SELECTOR = bytes4(keccak256("execute(bytes,bytes[])"));

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable ROUTER;

    // Struct for decoded parameters
    struct RedeemParams {
        address pt;
        address asset;
        address recipient;
        uint256 minAssets;
        uint256 sharesToBurn;
        bool usePrevHookAmount;
        bytes1 command;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_PT();
    error INVALID_ASSET();
    error INVALID_COMMAND();
    error INVALID_RECIPIENT();
    error INVALID_MIN_ASSETS();

    constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        ROUTER = router_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Spectra Exchange Redeem";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Redeems principal tokens via Spectra exchange";
    }


    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        RedeemParams memory params = _decodeRedeemParams(data);

        if (params.recipient == address(0)) revert INVALID_RECIPIENT();
        if (params.command != REDEEM_IBT_FOR_ASSET && params.command != REDEEM_PT_FOR_ASSET) revert INVALID_COMMAND();

        if (params.usePrevHookAmount) {
            params.sharesToBurn = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (params.sharesToBurn == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        bytes memory callData;
        if (params.command == REDEEM_IBT_FOR_ASSET) {
            // https://dev.spectra.finance/technical-reference/contract-functions/router#redeem_ibt_for_asset-command

            if (params.asset == address(0)) revert INVALID_ASSET();

            callData = _createRedeemIbtForAssetCallData(params.asset, params.sharesToBurn, params.recipient);
        } else if (params.command == REDEEM_PT_FOR_ASSET) {
            // https://dev.spectra.finance/technical-reference/contract-functions/router#redeem_pt_for_asset-command

            if (params.pt == address(0)) revert INVALID_PT();
            if (params.minAssets == 0) revert INVALID_MIN_ASSETS();

            callData =
                _createRedeemPtForAssetCallData(params.pt, params.sharesToBurn, params.recipient, params.minAssets);
        }

        executions[0] = Execution({ target: ROUTER, value: 0, callData: callData });
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

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

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        RedeemParams memory params = _decodeRedeemParams(data);

        return abi.encodePacked(params.asset, params.pt, params.recipient);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, 32), account);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeRedeemParams(bytes calldata data) private pure returns (RedeemParams memory params) {
        address asset = BytesLib.toAddress(data, 32);
        address pt = BytesLib.toAddress(data, 52);
        uint256 sharesToBurn = BytesLib.toUint256(data, AMOUNT_POSITION);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        (address recipient, uint256 minAssets, bytes1 command) =
            abi.decode(data[PAYLOAD_OFFSET:], (address, uint256, bytes1));

        return RedeemParams({
            pt: pt,
            asset: asset,
            recipient: recipient,
            minAssets: minAssets,
            sharesToBurn: sharesToBurn,
            usePrevHookAmount: usePrevHookAmount,
            command: command
        });
    }

    function _createRedeemIbtForAssetCallData(
        address asset,
        uint256 sharesToBurn,
        address recipient
    )
        private
        pure
        returns (bytes memory callData)
    {
        bytes memory command = new bytes(1);
        command[0] = REDEEM_IBT_FOR_ASSET;

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(asset, sharesToBurn, recipient);

        callData = abi.encodeWithSelector(SELECTOR, command, inputs);
    }

    function _createRedeemPtForAssetCallData(
        address pt,
        uint256 sharesToBurn,
        address recipient,
        uint256 minAssets
    )
        private
        pure
        returns (bytes memory callData)
    {
        bytes memory command = new bytes(1);
        command[0] = REDEEM_PT_FOR_ASSET;

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(pt, sharesToBurn, recipient, minAssets);

        callData = abi.encodeWithSelector(SELECTOR, command, inputs);
    }

    function _getBalance(bytes calldata data, address) private view returns (uint256) {
        address asset = BytesLib.toAddress(data, 32);
        (address recipient,,) = abi.decode(data[PAYLOAD_OFFSET:], (address, uint256, bytes1));

        return IERC20(asset).balanceOf(recipient);
    }
}
