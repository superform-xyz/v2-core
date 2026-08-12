// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {
    RelaySendFundsAndExecuteOnDstHook
} from "../../../src/hooks/bridges/relay/RelaySendFundsAndExecuteOnDstHook.sol";
import {
    ApproveAndRelaySendFundsAndExecuteOnDstHook
} from "../../../src/hooks/bridges/relay/ApproveAndRelaySendFundsAndExecuteOnDstHook.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { Vm } from "forge-std/Vm.sol";

/// @title RelayHooksFork
/// @notice Fork tests for the Relay send hooks against the REAL deployed RelayDepository on Base
/// @dev Verifies the hook-built executions succeed against Relay's production depository
///      (0x4cD00E387622C35bDDB9b4c962C136462338BC31, CREATE2-canonical on most EVM chains)
///      and that the depository emits the expected deposit events.
///      Relay deposit events carry NO indexed params — decode everything from log.data.
contract RelayHooksFork is MerkleTreeHelper {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Relay depository on Base (canonical CREATE2 address)
    address public constant RELAY_DEPOSITORY_BASE = 0x4cD00E387622C35bDDB9b4c962C136462338BC31;

    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    bytes32 public constant RELAY_ERC20_DEPOSIT_TOPIC = keccak256("RelayErc20Deposit(address,address,uint256,bytes32)");
    bytes32 public constant RELAY_NATIVE_DEPOSIT_TOPIC = keccak256("RelayNativeDeposit(address,uint256,bytes32)");

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public baseForkId;
    RelaySendFundsAndExecuteOnDstHook public relayHook;
    ApproveAndRelaySendFundsAndExecuteOnDstHook public approveAndRelayHook;

    address public account;
    bytes32 public depositId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        baseForkId = vm.createFork(vm.envString(BASE_RPC_URL_KEY));
        vm.selectFork(baseForkId);

        account = makeAddr("account");
        depositId = keccak256("relay_order_id_fork");

        relayHook = new RelaySendFundsAndExecuteOnDstHook(RELAY_DEPOSITORY_BASE);
        approveAndRelayHook = new ApproveAndRelaySendFundsAndExecuteOnDstHook(RELAY_DEPOSITORY_BASE);

        // Sanity: depository actually exists on the fork
        assertGt(RELAY_DEPOSITORY_BASE.code.length, 0, "Relay depository not deployed on fork");
    }

    /*//////////////////////////////////////////////////////////////
                        REAL DEPOSITORY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice ApproveAnd hook executions (approve/deposit/approve-0) succeed against the real depository
    function test_Fork_RelayHook_Erc20Deposit_RealDepository() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, account, amount);

        bytes memory data = _encodeRelayData(USDC_BASE, amount, depositId, false);
        Execution[] memory executions = approveAndRelayHook.build(address(0), account, data);

        vm.recordLogs();

        // Run the hook-built executions from the account, skipping the BaseHook pre/post
        // self-calls (they require executor transient context) — index 1..length-2
        vm.startPrank(account);
        for (uint256 i = 1; i < executions.length - 1; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, "execution failed against real depository");
        }
        vm.stopPrank();

        // Funds pulled into the depository
        assertEq(IERC20(USDC_BASE).balanceOf(account), 0, "account should have deposited all");

        // No residual allowance to the depository
        assertEq(IERC20(USDC_BASE).allowance(account, RELAY_DEPOSITORY_BASE), 0, "approval residue");

        // RelayErc20Deposit(from=account, token=USDC, amount, id) — all non-indexed
        Vm.Log memory log = _findLog(vm.getRecordedLogs(), RELAY_ERC20_DEPOSIT_TOPIC, RELAY_DEPOSITORY_BASE);
        (address from, address token, uint256 emittedAmount, bytes32 id) =
            abi.decode(log.data, (address, address, uint256, bytes32));
        assertEq(from, account, "depositor should be the account");
        assertEq(token, USDC_BASE);
        assertEq(emittedAmount, amount);
        assertEq(id, depositId);
    }

    /// @notice Native hook execution succeeds against the real depository
    function test_Fork_RelayHook_NativeDeposit_RealDepository() public {
        uint256 amount = 1 ether;
        vm.deal(account, amount);

        bytes memory data = _encodeRelayData(address(0), amount, depositId, false);
        Execution[] memory executions = relayHook.build(address(0), account, data);

        vm.recordLogs();

        vm.prank(account);
        (bool success,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(success, "native deposit failed against real depository");

        assertEq(account.balance, 0, "account should have deposited all native");

        // RelayNativeDeposit(from=account, amount, id) — all non-indexed
        Vm.Log memory log = _findLog(vm.getRecordedLogs(), RELAY_NATIVE_DEPOSIT_TOPIC, RELAY_DEPOSITORY_BASE);
        (address from, uint256 emittedAmount, bytes32 id) = abi.decode(log.data, (address, uint256, bytes32));
        assertEq(from, account, "depositor should be the account");
        assertEq(emittedAmount, amount);
        assertEq(id, depositId);
    }

    /// @notice Plain (no-approve) hook against the real depository reverts without prior approval —
    ///         documents the requirement to chain an approve hook or use the ApproveAnd variant
    function test_Fork_RelayHook_Erc20WithoutApproval_Reverts() public {
        uint256 amount = 1000e6;
        deal(USDC_BASE, account, amount);

        bytes memory data = _encodeRelayData(USDC_BASE, amount, depositId, false);
        Execution[] memory executions = relayHook.build(address(0), account, data);

        vm.prank(account);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "deposit without approval should fail");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes hook data: 52-byte header + token (52) + amount (72) + depositId (104) + bool (136)
    function _encodeRelayData(
        address token,
        uint256 amount,
        bytes32 depositId_,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), token, amount, depositId_, usePrevHookAmount);
    }

    /// @dev Finds the first log with the given topic0 from the given emitter
    function _findLog(
        Vm.Log[] memory logs,
        bytes32 topic,
        address emitter
    )
        internal
        pure
        returns (Vm.Log memory)
    {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic && logs[i].emitter == emitter) {
                return logs[i];
            }
        }
        revert("expected Relay deposit event not found");
    }
}
