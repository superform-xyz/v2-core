// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { IDETHAsyncRedeemer } from "../../../vendor/vaults/deth/IDETHAsyncRedeemer.sol";
import { IMachine } from "../../../vendor/vaults/deth/IMachine.sol";

/// @title ClaimAssetsDETHHook
/// @author Superform Labs
/// @notice Claims WETH from a finalized DETH redemption request by burning the ERC-721 NFT receipt.
///         Must be used after RequestRedeemDETHHook has created the redemption request and
///         Dialectic's keeper has finalized it.
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address asyncRedeemer = BytesLib.toAddress(data, 32);
/// @notice         uint256 requestId = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
contract ClaimAssetsDETHHook is BaseHook, ISuperHookInflowOutflow, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant REQUEST_ID_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC4626) { }

    /// @inheritdoc ISuperHook
    function name() external pure override returns (string memory) {
        return "Claim Assets DETH";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Claims redeemed assets from a DETH vault";
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
        address asyncRedeemer = data.extractYieldSource();
        uint256 requestId = _decodeRequestId(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            requestId = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (asyncRedeemer == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: asyncRedeemer,
            value: 0,
            callData: abi.encodeCall(IDETHAsyncRedeemer.claimAssets, (requestId))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Returns empty — requestId is not a sizable amount (it's an NFT receipt ID)
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev This hook implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    ///      (no replaceCalldataAmounts). Override base to distinguish the two interfaces.
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address asyncRedeemer = data.extractYieldSource();
        address machine = IDETHAsyncRedeemer(asyncRedeemer).machine();
        asset = IMachine(machine).accountingToken();
        spToken = IMachine(machine).shareToken();
        _setOutAmount(_getBalance(account), account);
        // NOTE: usedShares intentionally not set — shares were consumed in the prior RequestRedeem step
    }

    /// @dev outAmount is the WETH delta (balance after claim minus balance before claim)
    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(_getBalance(account) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeRequestId(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, REQUEST_ID_POSITION);
    }

    function _getBalance(address account) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }
}
