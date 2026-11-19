// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { GyldInvestorTransferBase } from "./GyldInvestorTransferBase.sol";
import { BaseHook } from "../BaseHook.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../interfaces/ISuperHook.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";
import { GyldInTransitRegistry } from "../../accounting/oracles/GyldInTransitRegistry.sol";
import { IGyldTradePolicy } from "../../interfaces/accounting/IGyldTradePolicy.sol";

/// @title GyldInvestorDepositHook
/// @author Superform Labs
/// @notice Sends cash to Gyld's pinned deposit address for a named instrument and records it as cash in
///         transit, so the account stays valued while the operator's broker order is open.
/// @dev NOT A SWAP. Nothing about the bond, price or fill is on chain; the operator places `POST /invest`
///      against this cash and Gyld mints later. This hook bounds only HOW MUCH can be at Gyld per instrument
///      (registry cap) and WHEN (instrument tradable per `GyldTradePolicy`, no stale transit).
/// @dev The destination is `GyldInTransitRegistry.depositAddressOf(account)` (the strategy's own pair), never calldata.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific), exactly 125 bytes:
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address yieldSource = BytesLib.toAddress(data, 52);
/// @notice         address cashToken = BytesLib.toAddress(data, 72);
/// @notice         uint256 amount = BytesLib.toUint256(data, 92);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 124);
/// @dev THIS NATSPEC IS THE SOURCE OF THE REGISTRY BUILD PATH: the OMS derives offsets from the lines above
///      and reads asset identity from the field named literally `yieldSource`. Do not rename the fields.
contract GyldInvestorDepositHook is GyldInvestorTransferBase {
    /// @notice Eligibility gate reused from the trade family: registered pair, no recovery mark, not
    ///         suspended, NAV fresh on both clocks, strategy registered / not paused / PPS fresh
    IGyldTradePolicy public immutable POLICY;

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

    constructor(address inTransit_, address policy_) GyldInvestorTransferBase(inTransit_) {
        if (policy_ == address(0)) revert ADDRESS_NOT_VALID();
        POLICY = IGyldTradePolicy(policy_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Gyld Investor Deposit";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Sends cash to the strategy's pinned Gyld deposit address and records it as in transit";
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
        uint256 amount = _resolveAmount(prevHook, account, data, cashToken);
        address to = IN_TRANSIT.depositAddressOf(account);
        if (to == address(0)) revert DESTINATION_NOT_SET();
        // Same named errors the record call would throw, so the OMS pre-flight sees the chain's verdict.
        IN_TRANSIT.checkCashOut(account, yieldSource, cashToken, amount);

        executions = new Execution[](2);
        executions[0] =
            Execution({ target: cashToken, value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amount)) });
        executions[1] = Execution({
            target: address(IN_TRANSIT),
            value: 0,
            callData: abi.encodeCall(GyldInTransitRegistry.recordCashOut, (yieldSource, cashToken, amount))
        });
    }

    /// @notice Pre-flight for the OMS. Zero means the leaf would execute right now.
    /// @return code `GyldTradePolicy.previewTrade` code first, then `GyldInTransitRegistry.previewCashOut`; 208 when
    ///         `usePrevHookAmount` is set and every other gate passes (the amount itself is only known at execution)
    function previewDeposit(bytes calldata data, address account) external view returns (uint256 code) {
        (address yieldSource, address cashToken) = _decode(data);
        code = POLICY.previewTrade(account, IGyldTradePolicy.TradeSide.BUY, cashToken, yieldSource);
        if (code != 0) return code;
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            // the amount is the previous hook's output, known only at execution: report the other gates on a
            // nominal amount and, if they pass, say so with a code of its own
            uint256 gates = IN_TRANSIT.previewCashOut(account, yieldSource, cashToken, 1);
            return gates != 0 ? gates : 208;
        }
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);
        return IN_TRANSIT.previewCashOut(account, yieldSource, cashToken, amount);
    }

    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        (address yieldSource, address cashToken) = _decode(data);
        _resolveAmount(prevHook, account, data, cashToken);
        // Inside the transaction, so a state change between simulation and execution is caught here.
        POLICY.validateTrade(account, IGyldTradePolicy.TradeSide.BUY, cashToken, yieldSource, data);
        address to = IN_TRANSIT.depositAddressOf(account);
        if (to == address(0)) revert DESTINATION_NOT_SET();
        _snapshot(account, cashToken, to);
    }

    function _postExecute(address prevHook, address account, bytes calldata data) internal override {
        (, address cashToken) = _decode(data);
        uint256 amount = _resolveAmount(prevHook, account, data, cashToken);
        _verifyTransfer(account, cashToken, IN_TRANSIT.depositAddressOf(account), amount);
    }
}
