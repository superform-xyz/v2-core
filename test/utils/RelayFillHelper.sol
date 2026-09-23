// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, Vm } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title RelayFillHelper
/// @author Superform Labs
/// @notice Simulates a Relay Protocol (relay.link) solver fill on a destination fork, anchored to a
///         real `RelayDepository` deposit event recorded on the source fork.
/// @dev **Why this exists instead of pigeon's `RelayHelper`.** `lib/pigeon/src/relay/RelayHelper.sol`
///      cannot be compiled in this repository: a contract whose only content is `is RelayHelper` fails
///      with "Stack too deep" under v2-core's profile. Pigeon builds with `solc 0.8.28` and
///      `via_ir = true` (`lib/pigeon/foundry.toml:6,8`); v2-core uses `0.8.30` with via_ir off outside
///      the coverage profile, and `RelayHelper._help` (with its inline-assembly revert bubbling)
///      exceeds the stack without it. That is why nothing in this repo imports it.
///      `CctpV2Helper` is unaffected and is used directly by the CCTP suites.
/// @dev Semantics deliberately mirror `RelayHelper`:
///      1. verify a matching deposit event was emitted by the depository on the source chain;
///      2. fund a synthetic solver on the destination fork from its own capital;
///      3. execute the destination calls in order, reverting on the first failure — modelling the
///         solver router's multicall with `allowFailure = false`, so a failed fill unwinds entirely.
contract RelayFillHelper is Test {
    /// @dev Relay deposit events carry no indexed parameters — everything is decoded from log.data
    bytes32 internal constant RELAY_ERC20_DEPOSIT = keccak256("RelayErc20Deposit(address,address,uint256,bytes32)");
    bytes32 internal constant RELAY_NATIVE_DEPOSIT = keccak256("RelayNativeDeposit(address,uint256,bytes32)");

    /// @notice A destination call in the solver's atomic fill batch (mirrors the quote API `txs[]`)
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    struct Fill {
        address depository;
        bytes32 depositId;
        address solver;
        address outputToken;
        uint256 outputAmount;
        uint256 dstForkId;
    }

    /// @notice Deliver funds to `adapter` then call it — the Superform adapter fill shape.
    /// @param f The fill parameters
    /// @param adapter The destination RelayAdapter
    /// @param adapterCalldata The call executed on the adapter (normally `processRelayExecution`)
    /// @param logs Recorded source-chain logs (`vm.getRecordedLogs()`)
    function fillViaAdapter(
        Fill memory f,
        address adapter,
        bytes memory adapterCalldata,
        Vm.Log[] memory logs
    )
        internal
    {
        Call[] memory txs;
        if (f.outputToken == address(0)) {
            // native rides as value on the adapter call itself
            txs = new Call[](1);
            txs[0] = Call({ to: adapter, value: f.outputAmount, data: adapterCalldata });
        } else {
            txs = new Call[](2);
            txs[0] = Call({
                to: f.outputToken,
                value: 0,
                data: abi.encodeWithSelector(IERC20.transfer.selector, adapter, f.outputAmount)
            });
            txs[1] = Call({ to: adapter, value: 0, data: adapterCalldata });
        }
        _fill(f, txs, logs);
    }

    /// @notice Execute an arbitrary destination batch for a recorded deposit.
    function _fill(Fill memory f, Call[] memory txs, Vm.Log[] memory logs) internal {
        require(_depositEventFound(f.depository, f.depositId, logs), "RelayFillHelper: no matching deposit event");

        uint256 prevForkId = vm.activeFork();
        vm.selectFork(f.dstForkId);

        // Solvers fill from their own capital.
        if (f.outputToken == address(0)) {
            vm.deal(f.solver, f.solver.balance + f.outputAmount);
        } else {
            deal(f.outputToken, f.solver, f.outputAmount);
        }

        vm.startPrank(f.solver);
        _executeBatch(txs);
        vm.stopPrank();

        vm.selectFork(prevForkId);
    }

    /// @dev Split out so the revert-bubbling keeps a shallow stack (the exact spot that forces
    ///      via_ir in pigeon's version).
    function _executeBatch(Call[] memory txs) private {
        for (uint256 i; i < txs.length; ++i) {
            (bool success, bytes memory ret) = txs[i].to.call{ value: txs[i].value }(txs[i].data);
            if (!success) _bubble(ret);
        }
    }

    function _bubble(bytes memory ret) private pure {
        if (ret.length == 0) revert("RelayFillHelper: destination call failed");
        assembly {
            revert(add(ret, 0x20), mload(ret))
        }
    }

    /// @dev Scans for a RelayErc20Deposit/RelayNativeDeposit from `depository`; `bytes32(0)` matches any id.
    function _depositEventFound(
        address depository,
        bytes32 depositId,
        Vm.Log[] memory logs
    )
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != depository || logs[i].topics.length == 0) continue;

            if (logs[i].topics[0] == RELAY_ERC20_DEPOSIT) {
                (,,, bytes32 id) = abi.decode(logs[i].data, (address, address, uint256, bytes32));
                if (depositId == bytes32(0) || id == depositId) return true;
            } else if (logs[i].topics[0] == RELAY_NATIVE_DEPOSIT) {
                (,, bytes32 id) = abi.decode(logs[i].data, (address, uint256, bytes32));
                if (depositId == bytes32(0) || id == depositId) return true;
            }
        }
        return false;
    }
}
