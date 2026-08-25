// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { AcrossV3Helper } from "pigeon/across/AcrossV3Helper.sol";

import { SuperVaultAcrossCapBridgeHook } from
    "../../../src/hooks/bridges/across/SuperVaultAcrossCapBridgeHook.sol";

/// @dev View no-op matching the real cap guard (STATICCALL-safe). Tuple asserted via vm.expectCall.
interface ICapGuardLike {
    function validateAllocation(address strategy, uint64 chainId, address vault, uint256 amount) external view;
}

contract MockCapGuard is ICapGuardLike {
    function validateAllocation(address, uint64, address, uint256) external view { }
}

contract MockPositionRegistry {
    mapping(address => uint256) public bridgedOut;
    mapping(address => mapping(uint64 => uint256)) public bridgedOutByChain;

    function recordBridgedOut(address strategy, uint64 chainId, uint256 amount) external {
        bridgedOut[strategy] += amount;
        bridgedOutByChain[strategy][chainId] += amount;
    }
}

contract MockGovernorAddressBook {
    bytes32 private constant CROSS_CHAIN_CAP_GUARD = keccak256("CROSS_CHAIN_CAP_GUARD");
    bytes32 private constant CROSS_CHAIN_POSITION_REGISTRY = keccak256("CROSS_CHAIN_POSITION_REGISTRY");

    address public immutable CAP_GUARD;
    address public immutable REGISTRY;

    constructor(address capGuard_, address registry_) {
        CAP_GUARD = capGuard_;
        REGISTRY = registry_;
    }

    function getAddress(bytes32 key) external view returns (address) {
        if (key == CROSS_CHAIN_CAP_GUARD) return CAP_GUARD;
        if (key == CROSS_CHAIN_POSITION_REGISTRY) return REGISTRY;
        return address(0);
    }
}

/// @title SuperVaultAcrossCapBridgeHookFork
/// @notice Fork test: the cap-aware Across hook enforces the cap and produces a depositV3Now call the
///         REAL mainnet Across SpokePool accepts; pigeon then relays the fill to Base. Proves the
///         validated (recipient, chainId, amount) equals what actually bridges, end to end.
contract SuperVaultAcrossCapBridgeHookFork is Test {
    // Real Across SpokePools
    address internal constant SPOKE_POOL_ETH = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address internal constant SPOKE_POOL_BASE = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;

    // Tokens
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint64 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant INPUT_AMOUNT = 1000e6;
    uint256 internal constant OUTPUT_AMOUNT = 999e6;

    // build() layout: [0]=pre [1]=approve(0) [2]=approve(amt) [3]=depositV3Now [4]=approve(0) [5]=post
    uint256 internal constant BRIDGE_EXECUTION_INDEX = 3;

    uint256 internal ethFork;
    uint256 internal baseFork;

    SuperVaultAcrossCapBridgeHook internal hook;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal registry;
    MockGovernorAddressBook internal governor;
    AcrossV3Helper internal acrossHelper;

    address internal account = makeAddr("strategy");
    address internal recipient = makeAddr("destinationVault");
    address internal relayer = makeAddr("relayer");
    address internal validatorStub = makeAddr("validator");

    function setUp() public {
        ethFork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), 23_096_042);
        baseFork = vm.createFork(vm.envString("BASE_RPC_URL"), 33_931_553);

        // Pigeon helper must exist on both forks (it self-selects the destination fork).
        vm.selectFork(baseFork);
        acrossHelper = new AcrossV3Helper();
        vm.allowCheatcodes(address(acrossHelper));
        vm.makePersistent(address(acrossHelper));

        vm.selectFork(ethFork);
        capGuard = new MockCapGuard();
        registry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(registry));
        hook = new SuperVaultAcrossCapBridgeHook(SPOKE_POOL_ETH, validatorStub, address(governor));
        hook.setExecutionContext(account);

        deal(USDC_ETH, account, INPUT_AMOUNT);
    }

    /// @notice Full round trip: cap enforced on ETH, real depositV3Now accepted by the live mainnet
    ///         SpokePool, pigeon fills on Base, recipient receives USDC. The validated tuple must
    ///         equal the bridged tuple, and the registry must reflect the in-flight exposure.
    function test_Fork_CapEnforcedThenRealBridgeAndPigeonFill() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(BASE_CHAIN_ID, INPUT_AMOUNT, false);

        // The hook must validate exactly the tuple the parent will bridge.
        vm.expectCall(
            address(capGuard),
            abi.encodeCall(ICapGuardLike.validateAllocation, (account, BASE_CHAIN_ID, recipient, INPUT_AMOUNT))
        );
        vm.prank(account);
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), INPUT_AMOUNT, "in-flight exposure not recorded");
        assertEq(registry.bridgedOutByChain(account, BASE_CHAIN_ID), INPUT_AMOUNT, "per-chain exposure not recorded");

        // Execute the real bridge executions as the account: approve(0), approve(amount), depositV3Now.
        Execution[] memory execs = hook.build(address(0), account, data);
        assertEq(execs[BRIDGE_EXECUTION_INDEX].target, SPOKE_POOL_ETH, "bridge target is not the SpokePool");

        vm.recordLogs();
        vm.startPrank(account);
        for (uint256 i = 1; i <= 4; i++) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            assertTrue(ok, "source execution failed");
        }
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Funds left the account into the real SpokePool.
        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "input not pulled by SpokePool");

        // Pigeon relays the V3FundsDeposited log to Base and fills to the recipient.
        uint256 recipientBefore = _baseBalanceOf(recipient);
        acrossHelper.help(
            SPOKE_POOL_ETH,
            SPOKE_POOL_BASE,
            relayer,
            block.timestamp + 1 hours,
            baseFork,
            uint256(BASE_CHAIN_ID),
            uint256(1), // refund chain id (origin)
            logs
        );

        vm.selectFork(baseFork);
        assertEq(
            IERC20(USDC_BASE).balanceOf(recipient) - recipientBefore, OUTPUT_AMOUNT, "recipient not filled on Base"
        );
    }

    /// @notice A cap breach reverts in _preExecute, before any approval/deposit — no funds leave the
    ///         account and nothing reaches the SpokePool.
    function test_Fork_CapBreachRevertsBeforeAnyBridge() public {
        vm.selectFork(ethFork);
        bytes memory data = _encode(BASE_CHAIN_ID, INPUT_AMOUNT, false);

        // Force the cap guard to reject this allocation.
        vm.mockCallRevert(
            address(capGuard),
            abi.encodeWithSelector(ICapGuardLike.validateAllocation.selector),
            abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()")
        );

        vm.prank(account);
        vm.expectRevert(abi.encodeWithSignature("CROSS_CHAIN_CAP_EXCEEDED()"));
        hook.preExecute(address(0), account, data);

        assertEq(registry.bridgedOut(account), 0, "no exposure should be recorded on a breach");
        assertEq(IERC20(USDC_ETH).balanceOf(account), INPUT_AMOUNT, "funds must not move on a breach");
    }

    function _baseBalanceOf(address who) internal returns (uint256 bal) {
        uint256 prev = vm.activeFork();
        vm.selectFork(baseFork);
        bal = IERC20(USDC_BASE).balanceOf(who);
        vm.selectFork(prev);
    }

    function _encode(uint256 chainId, uint256 inputAmount, bool usePrevHookAmount) internal view returns (bytes memory) {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // strategy header
            uint256(0), // value
            recipient,
            USDC_ETH, // inputToken
            USDC_BASE, // outputToken
            inputAmount,
            OUTPUT_AMOUNT
        );
        return abi.encodePacked(
            header,
            chainId, // destinationChainId @208
            address(0), // exclusiveRelayer @240
            uint32(3600), // fillDeadlineOffset @260
            uint32(0), // exclusivityPeriod @264
            usePrevHookAmount // @268
        );
    }
}
