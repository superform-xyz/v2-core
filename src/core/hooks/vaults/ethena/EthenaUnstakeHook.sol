// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IStakedUSDeCooldown } from "../../../../vendor/ethena/IStakedUSDeCooldown.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title EthenaUnstakeHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 24);
/// @notice         address vaultBank = BytesLib.toAddress(data, 25);
/// @notice         uint256 dstChainId = BytesLib.toUint256(data, 45);
contract EthenaUnstakeHook is BaseHook, ISuperHookInspector {
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.OUTFLOW, "Ethena") { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address, /* prevHook */
        address account,
        bytes memory data
    )
        external
        pure
        override
        returns (Execution[] memory executions)
    {
        // Note: prev amount cannot be used in here, it unstakes everything available

        address yieldSource = data.extractYieldSource();
        if (yieldSource == address(0) || account == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);

        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IStakedUSDeCooldown.unstake, (account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/


    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource();
        asset = IERC4626(yieldSource).asset();
        outAmount = _getBalance(account, data);
        usedShares = _getSharesBalance(account, data);
        vaultBank = BytesLib.toAddress(data, 57);
        dstChainId = BytesLib.toUint256(data, 77);
        spToken = yieldSource;
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        address yieldSource = data.extractYieldSource(); // sUSDE
        outAmount = _getBalance(account, data) - outAmount;
        // this is how cooldownShares converts the shares to underlying.
        // might not match the exact pps when cooldownShares was called.
        // will likely underestimate the actual shares burned
        usedShares = IERC4626(yieldSource).previewWithdraw(outAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IERC4626(yieldSource).balanceOf(account);
    }
}
