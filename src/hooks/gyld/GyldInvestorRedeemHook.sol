// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { GyldInvestorTransferBase } from "./GyldInvestorTransferBase.sol";
import { BaseHook } from "../BaseHook.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../interfaces/ISuperHook.sol";
import { GyldInTransitRegistry } from "../../accounting/oracles/GyldInTransitRegistry.sol";

/// @title GyldInvestorRedeemHook
/// @author Superform Labs
/// @notice Sends bond tokens to Gyld's pinned redeem holding wallet and records them as bonds in transit at
///         Gyld, so the account stays valued until the broker sale pays out.
/// @dev NOT A WITHDRAW. The payout lands in Gyld's off-chain cash balance and is withdrawn to the account's
///      registered withdrawal address by a human; the operator confirms the sale with `limit_price_usd`.
///      This hook moves the tokens and records the exit; it cannot see the sale.
/// @dev SUSPENSION DOES NOT BLOCK. A credit-event exit must stay possible, so only pair approval and the
///      pinned wallet are required. No NAV is recorded: the oracle marks bonds in transit at the live NAV,
///      exactly like wallet bonds (review on SUP-21848).
/// @dev The destination is `GyldInTransitRegistry.redeemHoldingWallet()`, never calldata.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific), exactly 125 bytes:
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address yieldSource = BytesLib.toAddress(data, 52);
/// @notice         address cashToken = BytesLib.toAddress(data, 72);
/// @notice         uint256 shares = BytesLib.toUint256(data, 92);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 124);
/// @dev THIS NATSPEC IS THE SOURCE OF THE REGISTRY BUILD PATH: the OMS derives offsets from the lines above
///      and reads asset identity from the field named literally `yieldSource`. Do not rename the fields.
contract GyldInvestorRedeemHook is GyldInvestorTransferBase {
    /// @dev Exact constant name: the sizing-manifest generator reads it from THIS file.
    uint256 private constant AMOUNT_POSITION = 92;

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
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

    constructor(address inTransit_) GyldInvestorTransferBase(inTransit_) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Gyld Investor Redeem";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Sends bond tokens to Gyld's pinned redeem holding wallet and records them as in transit";
    }

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
        (address yieldSource, address cashToken) = _decode(data);
        uint256 shares = _resolveAmount(prevHook, account, data, yieldSource);
        address to = IN_TRANSIT.redeemHoldingWallet();
        if (to == address(0)) revert DESTINATION_NOT_SET();
        IN_TRANSIT.checkBondsOut(yieldSource, cashToken);

        executions = new Execution[](2);
        executions[0] =
            Execution({ target: yieldSource, value: 0, callData: abi.encodeCall(IERC20.transfer, (to, shares)) });
        executions[1] = Execution({
            target: address(IN_TRANSIT),
            value: 0,
            callData: abi.encodeCall(GyldInTransitRegistry.recordBondsOut, (yieldSource, cashToken, shares))
        });
    }

    /// @notice Pre-flight for the OMS. Zero means the leaf would execute right now.
    /// @return code `GyldInTransitRegistry.previewBondsOut` code
    function previewRedeem(bytes calldata data) external view returns (uint256 code) {
        (address yieldSource, address cashToken) = _decode(data);
        return IN_TRANSIT.previewBondsOut(yieldSource, cashToken);
    }

    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        (address yieldSource,) = _decode(data);
        _resolveAmount(prevHook, account, data, yieldSource);
        address to = IN_TRANSIT.redeemHoldingWallet();
        if (to == address(0)) revert DESTINATION_NOT_SET();
        _snapshot(account, yieldSource, to);
    }

    function _postExecute(address prevHook, address account, bytes calldata data) internal override {
        (address yieldSource,) = _decode(data);
        uint256 shares = _resolveAmount(prevHook, account, data, yieldSource);
        _verifyTransfer(account, yieldSource, IN_TRANSIT.redeemHoldingWallet(), shares);
    }
}
