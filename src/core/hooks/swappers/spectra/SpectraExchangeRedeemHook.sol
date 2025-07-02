// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { SpectraCommands } from "../../../../vendor/spectra/SpectraCommands.sol";

/// @title SpectraExchangeRedeemHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address asset = BytesLib.toAddress(data, 32);
/// @notice         address pt = BytesLib.toAddress(data, 52);
/// @notice         address recipient = BytesLib.toAddress(data, 72);
/// @notice         uint256 minAssets = BytesLib.toUint256(data, 92);
/// @notice         uint256 sharesToBurn = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         bytes1 command = BytesLib.slice(data, 157, 1);
contract SpectraExchangeRedeemHook is BaseHook, ISuperHookContextAware, ISuperHookInspector {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;
    uint256 private constant SHARES_POSITION = 124;

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

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
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
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeRedeemParams(bytes calldata data) private pure returns (RedeemParams memory params) {
        address asset = BytesLib.toAddress(data, 32);
        address pt = BytesLib.toAddress(data, 52);
        address recipient = BytesLib.toAddress(data, 72);
        uint256 minAssets = BytesLib.toUint256(data, 92);
        uint256 sharesToBurn = BytesLib.toUint256(data, 124);
        bool usePrevHookAmount = _decodeBool(data, 156);
        bytes memory encodedCommand = BytesLib.slice(data, 157, 1);
        bytes1 command = encodedCommand[0];

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
        address recipient = BytesLib.toAddress(data, 72);

        return IERC20(asset).balanceOf(recipient);
    }
}
