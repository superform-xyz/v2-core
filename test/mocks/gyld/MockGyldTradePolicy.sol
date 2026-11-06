// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IGyldTradePolicy } from "../../../src/interfaces/accounting/IGyldTradePolicy.sol";

/// @title MockGyldTradePolicy
/// @notice A policy that permits everything unless a test tells it not to.
/// @dev PURPOSE AND LIMIT. This exists so suites whose subject is the trade hook's OWN mechanics — calldata
///      encoding, the per-transaction cap, allowance scoping, outcome assertions — do not have to stand up a
///      registry, an oracle and an aggregator just to construct the hook.
/// @dev DO NOT USE IT TO CLAIM F1 COVERAGE. A passing test against this mock proves the hook CALLS its
///      policy, never that the real policy decides correctly. The checks themselves are covered against the
///      real `GyldTradePolicy` in `GyldTradePolicy.t.sol` and the Gyld integration suites.
contract MockGyldTradePolicy is IGyldTradePolicy {
    error TRADE_REJECTED();
    error FILL_REJECTED();

    bool public rejectTrade;
    bool public rejectFill;
    uint256 public previewCode;

    /// @notice Records of the last call, so a test can assert the hook forwarded the right values
    address public lastAccount;
    TradeSide public lastSide;
    address public lastInputToken;
    address public lastOutputToken;
    uint256 public lastInputSpent;
    uint256 public lastReceived;

    function setRejectTrade(bool value) external {
        rejectTrade = value;
    }

    function setRejectFill(bool value) external {
        rejectFill = value;
    }

    function setPreviewCode(uint256 value) external {
        previewCode = value;
    }

    /// @dev `view` per the interface, so the call records are written by the harness rather than here.
    function validateTrade(address, TradeSide, address, address, bytes calldata) external view {
        if (rejectTrade) revert TRADE_REJECTED();
    }

    function validateFill(FillArgs calldata) external view {
        if (rejectFill) revert FILL_REJECTED();
    }

    function previewTrade(address, TradeSide, address, address) external view returns (uint256) {
        return previewCode;
    }

    /// @notice Settable so a test can simulate the account state moving mid-leg.
    bytes32 public commitment;

    function setCommitment(bytes32 value) external {
        commitment = value;
    }

    function accountStateCommitment(address) external view returns (bytes32) {
        return commitment;
    }
}
