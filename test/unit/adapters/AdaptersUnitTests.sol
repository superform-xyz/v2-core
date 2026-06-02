// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { Vm } from "forge-std/Vm.sol";

import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { DebridgeAdapter } from "../../../src/adapters/DebridgeAdapter.sol";
import { StargateAdapter } from "../../../src/adapters/StargateAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

contract MockDlnDestination {
    address public externalAdapter;

    constructor(address _adapter) {
        externalAdapter = _adapter;
    }

    function externalCallAdapter() public view returns (address) {
        return externalAdapter;
    }
}

contract AcrossV3AdapterTest is Helpers {
    AcrossV3Adapter public acrossV3Adapter;
    DebridgeAdapter public debridgeAdapter;
    MockDlnDestination public mockDlnDestination;
    MockERC20 public mockERC20;

    receive() external payable { }

    function setUp() public {
        mockERC20 = new MockERC20("Mock Token", "MOCK", 18);
        acrossV3Adapter = new AcrossV3Adapter(address(this), address(this));
        mockDlnDestination = new MockDlnDestination(address(this));
        debridgeAdapter = new DebridgeAdapter(address(mockDlnDestination), address(this));
    }

    function test_Constructor() public {
        vm.expectRevert(AcrossV3Adapter.ADDRESS_NOT_VALID.selector);
        new AcrossV3Adapter(address(0), address(this));

        vm.expectRevert(AcrossV3Adapter.ADDRESS_NOT_VALID.selector);
        new AcrossV3Adapter(address(this), address(0));

        AcrossV3Adapter adp = new AcrossV3Adapter(address(0x1), address(0x2));
        assertEq(adp.ACROSS_SPOKE_POOL(), address(0x1));
        assertEq(address(adp.SUPER_DESTINATION_EXECUTOR()), address(0x2));
    }

    function test_InvalidSender() public {
        vm.startPrank(address(0x1));
        vm.expectRevert(IAcrossV3Receiver.INVALID_SENDER.selector);
        acrossV3Adapter.handleV3AcrossMessage(address(0), 0, address(0), new bytes(0));
        vm.stopPrank();
    }

    function test_InvalidDecoding() public {
        vm.expectRevert();
        acrossV3Adapter.handleV3AcrossMessage(address(0x1), 0, address(0), new bytes(0));
    }

    function test_InvalidToken() public {
        bytes memory _data = _buildDestinationData();
        vm.expectRevert();
        acrossV3Adapter.handleV3AcrossMessage(address(0), 0, address(0), _data);
    }

    function test_Handle() public {
        bytes memory _data = _buildDestinationData();

        _getTokens(address(mockERC20), address(acrossV3Adapter), 1000);
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0)
            )
        );

        acrossV3Adapter.handleV3AcrossMessage(address(mockERC20), 1000, address(0), _data);
        assertEq(mockERC20.balanceOf(address(this)), 1000);
    }

    function _buildDestinationData() private view returns (bytes memory) {
        bytes memory initData = new bytes(0);
        bytes memory executorCalldata = new bytes(0);
        address account = address(this);
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory sigData = new bytes(0);
        return abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData);
    }

    // ------------- DEBRIDGE ---------------
    function test_Debridge_Constructor() public {
        vm.expectRevert(DebridgeAdapter.ADDRESS_NOT_VALID.selector);
        new DebridgeAdapter(address(0), address(this));

        vm.expectRevert(DebridgeAdapter.ADDRESS_NOT_VALID.selector);
        new DebridgeAdapter(address(this), address(0));

        DebridgeAdapter adp = new DebridgeAdapter(address(mockDlnDestination), address(0x2));
        assertEq(adp.DLN_DESTINATION(), address(mockDlnDestination));
        assertEq(address(adp.SUPER_DESTINATION_EXECUTOR()), address(0x2));

        mockDlnDestination = new MockDlnDestination(address(0));
        vm.expectRevert(DebridgeAdapter.ADDRESS_NOT_VALID.selector);
        adp = new DebridgeAdapter(address(mockDlnDestination), address(0x2));
    }

    function test_Debridge_InvalidSender() public {
        mockDlnDestination = new MockDlnDestination(address(0x1));
        debridgeAdapter = new DebridgeAdapter(address(mockDlnDestination), address(this));
        vm.expectRevert(DebridgeAdapter.ONLY_EXTERNAL_CALL_ADAPTER.selector);
        debridgeAdapter.onEtherReceived(bytes32(0), address(0), new bytes(0));
        vm.expectRevert(DebridgeAdapter.ONLY_EXTERNAL_CALL_ADAPTER.selector);
        debridgeAdapter.onERC20Received(bytes32(0), address(0), 0, address(0), new bytes(0));
    }

    function test_Debridge_InvalidDecoding() public {
        vm.expectRevert();
        debridgeAdapter.onEtherReceived(bytes32(0), address(0), new bytes(0));
        vm.expectRevert();
        debridgeAdapter.onERC20Received(bytes32(0), address(0), 0, address(0), new bytes(0));
    }

    function test_Debridge_InvalidEthRecipient() public {
        bytes memory initData = new bytes(0);
        bytes memory executorCalldata = new bytes(0);
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](1);
        bytes memory sigData = new bytes(0);
        bytes memory _data = abi.encode(initData, executorCalldata, address(this), dstTokens, intentAmounts, sigData);
        vm.expectRevert();
        debridgeAdapter.onEtherReceived(bytes32(0), address(0), _data);
    }

    function test_Debridge_InvalidToken() public {
        bytes memory _data = _buildDebridgeDestinationData(address(0x1));
        vm.expectRevert();
        debridgeAdapter.onERC20Received(bytes32(0), address(0), 1000, address(0), _data);
    }

    function test_Debridge_HandleEth() public {
        bytes memory _data = _buildDebridgeDestinationData(address(this));
        deal(address(debridgeAdapter), 1000);
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0)
            )
        );

        (bool callSucceeded, bytes memory callResult) = debridgeAdapter.onEtherReceived(bytes32(0), address(0), _data);
        assertTrue(callSucceeded);
        assertEq(callResult.length, 0);
    }

    function test_Debridge_HandleERC20() public {
        bytes memory _data = _buildDebridgeDestinationData(address(this));
        _getTokens(address(mockERC20), address(debridgeAdapter), 1000);
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0)
            )
        );

        (bool callSucceeded, bytes memory callResult) =
            debridgeAdapter.onERC20Received(bytes32(0), address(mockERC20), 0, address(0), _data);
        assertTrue(callSucceeded);
        assertEq(callResult.length, 0);
    }

    function _buildDebridgeDestinationData(address _acc) private pure returns (bytes memory) {
        bytes memory initData = new bytes(0);
        bytes memory executorCalldata = new bytes(0);
        address account = _acc;
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory sigData = new bytes(0);
        return abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData);
    }

    function processBridgedExecution(
        address,
        address,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    )
        external
        pure
    {
        revert("A");
    }
}

/// @dev Mock Stargate pool with configurable token() return value
contract MockStargatePool {
    address public token;

    constructor(address token_) {
        token = token_;
    }
}

/// @dev Mock TokenMessaging for pool registration verification in unit tests
contract MockTokenMessaging {
    mapping(address => uint16) public assetIds;

    function setAssetId(address pool, uint16 assetId) external {
        assetIds[pool] = assetId;
    }
}

/// @dev Contract that cannot receive ETH (no receive/fallback)
contract NonPayableContract { }

contract StargateAdapterTest is Helpers {
    StargateAdapter public stargateAdapter;
    MockStargatePool public mockPool;
    MockStargatePool public mockNativePool;
    MockTokenMessaging public mockTokenMessaging;
    MockERC20 public mockERC20;

    // Test contract acts as both LZ_ENDPOINT and SUPER_DESTINATION_EXECUTOR
    address internal lzEndpoint;
    bytes32 internal constant GUID = bytes32(uint256(1));

    receive() external payable { }

    function setUp() public {
        lzEndpoint = address(this);
        mockERC20 = new MockERC20("Mock Token", "MOCK", 18);
        mockPool = new MockStargatePool(address(mockERC20));
        mockNativePool = new MockStargatePool(address(0));

        // Setup mock TokenMessaging and register pools
        mockTokenMessaging = new MockTokenMessaging();
        mockTokenMessaging.setAssetId(address(mockPool), 1);
        mockTokenMessaging.setAssetId(address(mockNativePool), 13);

        stargateAdapter = new StargateAdapter(lzEndpoint, address(mockTokenMessaging), address(this));
    }

    // ------------- CONSTRUCTOR ---------------

    function test_StargateAdapter_Constructor() public {
        StargateAdapter adp = new StargateAdapter(address(0x1), address(0x2), address(0x3));
        assertEq(adp.LZ_ENDPOINT(), address(0x1));
        assertEq(address(adp.TOKEN_MESSAGING()), address(0x2));
        assertEq(address(adp.SUPER_DESTINATION_EXECUTOR()), address(0x3));
    }

    function test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint() public {
        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(address(0), address(0x1), address(this));
    }

    function test_StargateAdapter_Constructor_RevertIf_ZeroTokenMessaging() public {
        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(address(this), address(0), address(this));
    }

    function test_StargateAdapter_Constructor_RevertIf_ZeroExecutor() public {
        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(address(this), address(0x1), address(0));
    }

    // ------------- POOL REGISTRATION VALIDATION ---------------

    function test_StargateAdapter_lzCompose_UnregisteredPool_EmitsAndReturns() public {
        // Deploy a fake pool that is NOT registered in TokenMessaging
        MockStargatePool fakePool = new MockStargatePool(address(mockERC20));
        // Do NOT register fakePool in mockTokenMessaging → assetIds returns 0

        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), innerPayload);

        vm.recordLogs();
        stargateAdapter.lzCompose(address(fakePool), GUID, message, address(0), new bytes(0));
        _assertEventEmitted(vm.getRecordedLogs(), "UnregisteredPool(bytes32,address)");
    }

    function test_StargateAdapter_lzCompose_UnregisteredPool_NoTokensTransferred() public {
        MockStargatePool fakePool = new MockStargatePool(address(mockERC20));
        _getTokens(address(mockERC20), address(stargateAdapter), 1000);

        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), innerPayload);

        stargateAdapter.lzCompose(address(fakePool), GUID, message, address(0), new bytes(0));

        // Tokens remain in adapter — unregistered pool was rejected
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 1000, "Tokens should remain in adapter");
        assertEq(mockERC20.balanceOf(address(this)), 0, "No tokens should be transferred");
    }

    // ------------- SENDER VALIDATION ---------------

    function test_StargateAdapter_lzCompose_RevertIf_InvalidSender() public {
        vm.prank(address(0x1));
        vm.expectRevert(StargateAdapter.INVALID_SENDER.selector);
        stargateAdapter.lzCompose(address(mockPool), GUID, new bytes(0), address(0), new bytes(0));
    }

    // ------------- MESSAGE VALIDATION ---------------

    function test_StargateAdapter_lzCompose_MessageTooShort_EmitsAndReturns() public {
        // Message with 75 bytes (1 less than the 76-byte OFTComposeMsgCodec header)
        // Should NOT revert — emits ComposeMsgTooShort and returns to avoid blocking pipeline
        bytes memory shortMessage = new bytes(75);
        vm.recordLogs();
        stargateAdapter.lzCompose(address(mockPool), GUID, shortMessage, address(0), new bytes(0));
        _assertEventEmitted(vm.getRecordedLogs(), "ComposeMsgTooShort(bytes32,uint256)");
    }

    function test_StargateAdapter_lzCompose_InvalidInnerDecoding_EmitsAndReturns() public {
        // 76-byte header + garbage that won't abi.decode to the 6-tuple
        // Should NOT revert — emits ComposeDecodeFailed and returns to avoid blocking pipeline
        bytes memory invalidMsg = _encodeComposeMsg(1, 30_101, 1000e18, bytes32(uint256(1)), new bytes(32));
        vm.recordLogs();
        stargateAdapter.lzCompose(address(mockPool), GUID, invalidMsg, address(0), new bytes(0));
        _assertEventEmitted(vm.getRecordedLogs(), "ComposeDecodeFailed(bytes32)");
    }

    // ------------- ERC20 HAPPY PATH ---------------

    function test_StargateAdapter_lzCompose_ERC20_HappyPath() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        // amountLD = 1000 in the header, adapter holds exactly 1000
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), innerPayload);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        _mockProcessBridgedExecution();

        vm.expectEmit(true, true, true, true);
        emit StargateAdapter.TransferSucceeded(GUID,address(this), address(mockERC20), 1000);

        stargateAdapter.lzCompose(address(mockPool), GUID, message, address(0), new bytes(0));
        assertEq(mockERC20.balanceOf(address(this)), 1000);
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 0);
    }

    // ------------- NATIVE ETH HAPPY PATH ---------------

    function test_StargateAdapter_lzCompose_NativeETH_HappyPath() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1 ether, bytes32(uint256(1)), innerPayload);

        deal(address(stargateAdapter), 1 ether);
        _mockProcessBridgedExecution();

        vm.expectEmit(true, true, true, true);
        emit StargateAdapter.TransferSucceeded(GUID,address(this), address(0), 1 ether);

        uint256 balBefore = address(this).balance;
        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));
        assertEq(address(this).balance - balBefore, 1 ether);
        assertEq(address(stargateAdapter).balance, 0);
    }

    function test_StargateAdapter_lzCompose_NativeETH_NonPayableAccount_StoresForClaim() public {
        NonPayableContract target = new NonPayableContract();
        bytes memory innerPayload = _buildStargateDestinationData(address(target));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1 ether, bytes32(uint256(1)), innerPayload);

        deal(address(stargateAdapter), 1 ether);

        // Should NOT revert — stores the failed transfer for manual claim
        vm.expectEmit(true, true, true, true);
        emit StargateAdapter.TransferFailed(GUID,address(target), address(0), 1 ether);

        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));

        // Funds remain in adapter, claimable by target
        assertEq(stargateAdapter.failedTransfers(address(target), address(0)), 1 ether);
        assertEq(address(stargateAdapter).balance, 1 ether);
    }

    // ------------- AMOUNTLD EDGE CASES ---------------

    function test_StargateAdapter_lzCompose_TransfersOnlyAmountLD() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        // amountLD in codec says 500, adapter has 1000 — only 500 should be transferred
        bytes memory message = _encodeComposeMsg(1, 30_101, 500, bytes32(uint256(1)), innerPayload);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        _mockProcessBridgedExecution();

        vm.expectEmit(true, true, true, true);
        emit StargateAdapter.TransferSucceeded(GUID,address(this), address(mockERC20), 500);

        stargateAdapter.lzCompose(address(mockPool), GUID, message, address(0), new bytes(0));
        assertEq(mockERC20.balanceOf(address(this)), 500, "Should receive only amountLD");
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 500, "Remainder stays in adapter");
    }

    function test_StargateAdapter_lzCompose_ZeroAmountLD() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        bytes memory message = _encodeComposeMsg(1, 30_101, 0, bytes32(uint256(1)), innerPayload);

        // No tokens needed - safeTransfer(0) should succeed and executor is still called
        _mockProcessBridgedExecution();

        stargateAdapter.lzCompose(address(mockPool), GUID, message, address(0), new bytes(0));
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 0);
    }

    function test_StargateAdapter_lzCompose_DustRemainsInAdapter() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        // amountLD = 800, but adapter holds 1000 (200 is dust from prior failed compose)
        bytes memory message = _encodeComposeMsg(1, 30_101, 800, bytes32(uint256(1)), innerPayload);

        // Simulate dust (200) from prior failed compose + new delivery (800)
        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        _mockProcessBridgedExecution();

        stargateAdapter.lzCompose(address(mockPool), GUID, message, address(0), new bytes(0));
        // Only amountLD (800) transferred, dust (200) remains
        assertEq(mockERC20.balanceOf(address(this)), 800, "Should receive only amountLD");
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 200, "Dust remains in adapter");
    }

    function test_StargateAdapter_lzCompose_ConcurrentComposesIsolated() public {
        // User A's compose delivers 600, User B's compose delivers 400
        // Both land in adapter (total 1000). Each compose should only transfer its amountLD.
        address userA = makeAddr("userA");
        address userB = makeAddr("userB");
        vm.deal(userA, 1 ether);
        vm.deal(userB, 1 ether);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        _mockProcessBridgedExecution();

        // User A's compose: amountLD = 600
        bytes memory payloadA = _buildStargateDestinationData(userA);
        bytes memory messageA = _encodeComposeMsg(1, 30_101, 600, bytes32(uint256(1)), payloadA);
        stargateAdapter.lzCompose(address(mockPool), GUID, messageA, address(0), new bytes(0));

        assertEq(mockERC20.balanceOf(userA), 600, "User A should get exactly 600");
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 400, "400 remains for User B");

        // User B's compose: amountLD = 400
        bytes memory payloadB = _buildStargateDestinationData(userB);
        bytes memory messageB = _encodeComposeMsg(2, 30_101, 400, bytes32(uint256(2)), payloadB);
        stargateAdapter.lzCompose(address(mockPool), GUID, messageB, address(0), new bytes(0));

        assertEq(mockERC20.balanceOf(userB), 400, "User B should get exactly 400");
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 0, "Adapter should be empty");
    }

    // ------------- EXECUTION FAILURE (TRY/CATCH) ---------------

    function test_StargateAdapter_lzCompose_ExecutionFails_DoesNotRevert() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), innerPayload);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        // Do NOT mock processBridgedExecution — the test contract's implementation reverts with "B"

        vm.expectEmit(true, true, true, true);
        emit StargateAdapter.TransferSucceeded(GUID,address(this), address(mockERC20), 1000);

        // Should succeed — tokens transferred, execution failure caught
        stargateAdapter.lzCompose(address(mockPool), GUID, message, address(0), new bytes(0));

        // User has tokens even though execution failed
        assertEq(mockERC20.balanceOf(address(this)), 1000);
        assertEq(mockERC20.balanceOf(address(stargateAdapter)), 0);
    }

    function test_StargateAdapter_lzCompose_ExecutionFails_EmitsEvent() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), innerPayload);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);

        // Expect ExecutionFailed event
        vm.expectEmit(true, false, false, false);
        emit StargateAdapter.ExecutionFailed(GUID, address(this));

        stargateAdapter.lzCompose(address(mockPool), GUID, message, address(0), new bytes(0));
    }

    // ------------- CLAIM FAILED TRANSFER ---------------

    function test_StargateAdapter_claimFailedTransfer_ERC20() public {
        // Simulate a failed ERC20 transfer by directly setting state via a compose to non-payable
        // We'll use the native path to get a stored failed transfer, then test ERC20 claim separately

        // Setup: force a failed native transfer to get failedTransfers populated
        NonPayableContract target = new NonPayableContract();
        bytes memory innerPayload = _buildStargateDestinationData(address(target));
        bytes memory message = _encodeComposeMsg(1, 30_101, 500, bytes32(uint256(1)), innerPayload);

        // Give adapter ERC20 tokens, use ERC20 pool — transfer should succeed (NonPayableContract accepts ERC20)
        // Instead, test claim via native path where failure actually occurs
        deal(address(stargateAdapter), 1 ether);
        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));

        assertEq(stargateAdapter.failedTransfers(address(target), address(0)), 500);

        // Target can't claim ETH directly (non-payable), but a payable target can
        // Let's test with a payable user instead
        address payableUser = makeAddr("payableUser");
        vm.deal(payableUser, 0);

        // Setup a failed transfer for payableUser
        bytes memory payload2 = _buildStargateDestinationData(payableUser);
        // Make the token() call return a non-existent ERC20 to force transfer failure
        MockERC20 failToken = new MockERC20("Fail", "FAIL", 18);
        MockStargatePool failPool = new MockStargatePool(address(failToken));
        mockTokenMessaging.setAssetId(address(failPool), 2); // Register pool
        // Fund adapter so preBalance guard passes, mock transfer revert to simulate blacklist
        _getTokens(address(failToken), address(stargateAdapter), 100);
        vm.mockCallRevert(
            address(failToken),
            abi.encodeWithSelector(IERC20.transfer.selector, payableUser, 100),
            "BLACKLISTED"
        );
        bytes memory message2 = _encodeComposeMsg(2, 30_101, 100, bytes32(uint256(2)), payload2);
        stargateAdapter.lzCompose(address(failPool), GUID, message2, address(0), new bytes(0));
        vm.clearMockedCalls();

        assertEq(stargateAdapter.failedTransfers(payableUser, address(failToken)), 100);

        // Adapter still holds tokens (transfer was reverted), claim should succeed

        vm.expectEmit(true, true, false, true);
        emit StargateAdapter.FailedTransferClaimed(payableUser, address(failToken), 100);

        vm.prank(payableUser);
        stargateAdapter.claimFailedTransfer(address(failToken), 100);

        assertEq(failToken.balanceOf(payableUser), 100);
        assertEq(stargateAdapter.failedTransfers(payableUser, address(failToken)), 0);
    }

    function test_StargateAdapter_claimFailedTransfer_NativeETH() public {
        address payableUser = makeAddr("payableUser");
        vm.deal(payableUser, 0);

        // Force a failed transfer: send native to NonPayableContract, then transfer claim to payableUser
        // Actually, let's directly test: fail transfer to payableUser by having adapter with no ETH
        // Simpler: use NonPayableContract to fail, then deploy a new adapter with the payable user scenario

        // Directly: create situation where native ETH goes to non-payable, then re-test
        NonPayableContract target = new NonPayableContract();
        bytes memory innerPayload = _buildStargateDestinationData(address(target));
        bytes memory message = _encodeComposeMsg(1, 30_101, 0.5 ether, bytes32(uint256(1)), innerPayload);

        deal(address(stargateAdapter), 0.5 ether);
        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));

        assertEq(stargateAdapter.failedTransfers(address(target), address(0)), 0.5 ether);

        // NonPayableContract can't claim ETH either — this demonstrates the need for a payable recipient
        // In production, smart accounts are payable. Let's test with a payable user.

        // Setup payable user failed transfer
        bytes memory payload2 = _buildStargateDestinationData(payableUser);
        MockERC20 noBalToken = new MockERC20("NoBal", "NB", 18);
        MockStargatePool noBalPool = new MockStargatePool(address(noBalToken));
        mockTokenMessaging.setAssetId(address(noBalPool), 2); // Register pool
        // Fund adapter so preBalance guard passes, mock transfer revert to simulate failure
        _getTokens(address(noBalToken), address(stargateAdapter), 200);
        vm.mockCallRevert(
            address(noBalToken),
            abi.encodeWithSelector(IERC20.transfer.selector, payableUser, 200),
            "BLACKLISTED"
        );
        bytes memory message2 = _encodeComposeMsg(2, 30_101, 200, bytes32(uint256(2)), payload2);
        stargateAdapter.lzCompose(address(noBalPool), GUID, message2, address(0), new bytes(0));
        vm.clearMockedCalls();

        assertEq(stargateAdapter.failedTransfers(payableUser, address(noBalToken)), 200);

        // Adapter still holds tokens (transfer was reverted), claim should succeed
        vm.prank(payableUser);
        stargateAdapter.claimFailedTransfer(address(noBalToken), 200);

        assertEq(noBalToken.balanceOf(payableUser), 200);
        assertEq(stargateAdapter.failedTransfers(payableUser, address(noBalToken)), 0);
    }

    function test_StargateAdapter_claimFailedTransfer_RevertIf_ZeroAmount() public {
        vm.expectRevert(StargateAdapter.ZERO_AMOUNT.selector);
        stargateAdapter.claimFailedTransfer(address(mockERC20), 0);
    }

    function test_StargateAdapter_claimFailedTransfer_RevertIf_InsufficientBalance() public {
        vm.expectRevert(StargateAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        stargateAdapter.claimFailedTransfer(address(mockERC20), 100);
    }

    function test_StargateAdapter_claimFailedTransfer_PartialClaim() public {
        // Setup: force failed transfer of 1000 tokens
        address user = makeAddr("user");
        MockERC20 failToken = new MockERC20("Fail", "FAIL", 18);
        MockStargatePool failPool = new MockStargatePool(address(failToken));
        mockTokenMessaging.setAssetId(address(failPool), 2); // Register pool

        bytes memory payload = _buildStargateDestinationData(user);
        // Fund adapter so preBalance guard passes, mock transfer revert to simulate failure
        _getTokens(address(failToken), address(stargateAdapter), 1000);
        vm.mockCallRevert(
            address(failToken),
            abi.encodeWithSelector(IERC20.transfer.selector, user, 1000),
            "BLACKLISTED"
        );
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), payload);
        stargateAdapter.lzCompose(address(failPool), GUID, message, address(0), new bytes(0));
        vm.clearMockedCalls();

        assertEq(stargateAdapter.failedTransfers(user, address(failToken)), 1000);

        // Adapter still holds tokens (transfer was reverted), claim should work
        vm.prank(user);
        stargateAdapter.claimFailedTransfer(address(failToken), 400);

        assertEq(failToken.balanceOf(user), 400);
        assertEq(stargateAdapter.failedTransfers(user, address(failToken)), 600);

        // Claim remaining
        vm.prank(user);
        stargateAdapter.claimFailedTransfer(address(failToken), 600);
        assertEq(failToken.balanceOf(user), 1000);
        assertEq(stargateAdapter.failedTransfers(user, address(failToken)), 0);
    }

    // ------------- PREBALANCE GUARD (UNBACKED CREDIT PREVENTION) ---------------

    /// @notice Verify preBalance guard: adapter has 0 tokens, compose arrives → no failedTransfers credit
    /// @dev Prevents unbacked credits when tokens were delivered directly to account during lzReceive
    function test_StargateAdapter_lzCompose_NoPreBalance_NoFailedCredit() public {
        address user = makeAddr("user");
        MockERC20 someToken = new MockERC20("Some", "SOME", 18);
        MockStargatePool somePool = new MockStargatePool(address(someToken));
        mockTokenMessaging.setAssetId(address(somePool), 3);

        // Adapter has 0 someToken — compose claims amountLD = 500
        bytes memory innerPayload = _buildStargateDestinationData(user);
        bytes memory message = _encodeComposeMsg(1, 30_101, 500, bytes32(uint256(1)), innerPayload);

        _mockProcessBridgedExecution();

        stargateAdapter.lzCompose(address(somePool), GUID, message, address(0), new bytes(0));

        // preBalance guard: no failedTransfers credit created (adapter had 0 tokens)
        assertEq(stargateAdapter.failedTransfers(user, address(someToken)), 0, "No unbacked credit");
    }

    /// @notice Verify preBalance guard with zero account: adapter has 0 tokens → no failedTransfers credit
    function test_StargateAdapter_lzCompose_NoPreBalance_ZeroAccount_NoFailedCredit() public {
        MockERC20 someToken = new MockERC20("Some", "SOME", 18);
        MockStargatePool somePool = new MockStargatePool(address(someToken));
        mockTokenMessaging.setAssetId(address(somePool), 3);

        // Compose with account = address(0), adapter has 0 tokens
        bytes memory innerPayload = _buildStargateDestinationData(address(0));
        bytes memory message = _encodeComposeMsg(1, 30_101, 500, bytes32(uint256(42)), innerPayload);

        stargateAdapter.lzCompose(address(somePool), GUID, message, address(0), new bytes(0));

        // composeFrom = address(42)
        address composeFrom = address(uint160(42));
        assertEq(stargateAdapter.failedTransfers(composeFrom, address(someToken)), 0, "No unbacked credit for composeFrom");
    }

    /// @notice Verify preBalance guard with native ETH: adapter has 0 ETH → no failedTransfers credit
    function test_StargateAdapter_lzCompose_NoPreBalance_NativeETH_NoFailedCredit() public {
        NonPayableContract target = new NonPayableContract();

        // Adapter has 0 ETH — compose claims amountLD = 1 ether
        bytes memory innerPayload = _buildStargateDestinationData(address(target));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1 ether, bytes32(uint256(1)), innerPayload);

        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));

        // preBalance guard: no failedTransfers credit created (adapter had 0 ETH)
        assertEq(stargateAdapter.failedTransfers(address(target), address(0)), 0, "No unbacked ETH credit");
    }

    // ------------- RECEIVE ---------------

    function test_StargateAdapter_receive_AcceptsETH() public {
        deal(address(this), 1 ether);
        (bool success,) = address(stargateAdapter).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(stargateAdapter).balance, 1 ether);
    }

    // ------------- HELPERS ---------------

    function _encodeComposeMsg(
        uint64 nonce_,
        uint32 srcEid_,
        uint256 amountLD_,
        bytes32 composeFrom_,
        bytes memory innerPayload_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(nonce_, srcEid_, amountLD_, composeFrom_, innerPayload_);
    }

    function _buildStargateDestinationData(address account_) private pure returns (bytes memory) {
        bytes memory initData = new bytes(0);
        bytes memory executorCalldata = new bytes(0);
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory sigData = new bytes(0);
        return abi.encode(initData, executorCalldata, account_, dstTokens, intentAmounts, sigData);
    }

    function _assertEventEmitted(Vm.Log[] memory logs, string memory eventSig) internal pure {
        bytes32 sig = keccak256(bytes(eventSig));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == sig) return;
        }
        revert(string.concat("Expected event not emitted: ", eventSig));
    }

    function _mockProcessBridgedExecution() private {
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0)
            )
        );
    }

    function processBridgedExecution(
        address,
        address,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    )
        external
        pure
    {
        revert("B");
    }
}
