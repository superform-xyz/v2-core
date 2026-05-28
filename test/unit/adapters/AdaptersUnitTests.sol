// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";

import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { DebridgeAdapter } from "../../../src/adapters/DebridgeAdapter.sol";
import { StargateAdapter } from "../../../src/adapters/StargateAdapter.sol";
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

/// @dev Contract that cannot receive ETH (no receive/fallback)
contract NonPayableContract { }

contract StargateAdapterTest is Helpers {
    StargateAdapter public stargateAdapter;
    MockStargatePool public mockPool;
    MockStargatePool public mockNativePool;
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
        stargateAdapter = new StargateAdapter(lzEndpoint, address(this));
    }

    // ------------- CONSTRUCTOR ---------------

    function test_StargateAdapter_Constructor() public {
        StargateAdapter adp = new StargateAdapter(address(0x1), address(0x2));
        assertEq(adp.LZ_ENDPOINT(), address(0x1));
        assertEq(address(adp.SUPER_DESTINATION_EXECUTOR()), address(0x2));
    }

    function test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint() public {
        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(address(0), address(this));
    }

    function test_StargateAdapter_Constructor_RevertIf_ZeroExecutor() public {
        vm.expectRevert(StargateAdapter.ADDRESS_NOT_VALID.selector);
        new StargateAdapter(address(this), address(0));
    }

    // ------------- SENDER VALIDATION ---------------

    function test_StargateAdapter_lzCompose_RevertIf_InvalidSender() public {
        vm.prank(address(0x1));
        vm.expectRevert(StargateAdapter.INVALID_SENDER.selector);
        stargateAdapter.lzCompose(address(mockPool), GUID, new bytes(0), address(0), new bytes(0));
    }

    // ------------- MESSAGE VALIDATION ---------------

    function test_StargateAdapter_lzCompose_RevertIf_MessageTooShort() public {
        // Message with 75 bytes (1 less than the 76-byte OFTComposeMsgCodec header)
        bytes memory shortMessage = new bytes(75);
        vm.expectRevert(StargateAdapter.COMPOSE_MSG_TOO_SHORT.selector);
        stargateAdapter.lzCompose(address(mockPool), GUID, shortMessage, address(0), new bytes(0));
    }

    function test_StargateAdapter_lzCompose_RevertIf_InvalidInnerDecoding() public {
        // 76-byte header + garbage that won't abi.decode to the 6-tuple
        bytes memory invalidMsg = _encodeComposeMsg(1, 30_101, 1000e18, bytes32(uint256(1)), new bytes(32));
        vm.expectRevert();
        stargateAdapter.lzCompose(address(mockPool), GUID, invalidMsg, address(0), new bytes(0));
    }

    // ------------- ERC20 HAPPY PATH ---------------

    function test_StargateAdapter_lzCompose_ERC20_HappyPath() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        // amountLD = 1000 in the header, adapter holds exactly 1000
        bytes memory message = _encodeComposeMsg(1, 30_101, 1000, bytes32(uint256(1)), innerPayload);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        _mockProcessBridgedExecution();

        vm.expectEmit(true, true, false, true);
        emit StargateAdapter.ComposeExecuted(address(this), address(mockERC20), 1000);

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

        vm.expectEmit(true, true, false, true);
        emit StargateAdapter.ComposeExecuted(address(this), address(0), 1 ether);

        uint256 balBefore = address(this).balance;
        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));
        assertEq(address(this).balance - balBefore, 1 ether);
        assertEq(address(stargateAdapter).balance, 0);
    }

    function test_StargateAdapter_lzCompose_NativeETH_RevertIf_AccountNotPayable() public {
        NonPayableContract target = new NonPayableContract();
        bytes memory innerPayload = _buildStargateDestinationData(address(target));
        bytes memory message = _encodeComposeMsg(1, 30_101, 1 ether, bytes32(uint256(1)), innerPayload);

        deal(address(stargateAdapter), 1 ether);

        vm.expectRevert(StargateAdapter.ETH_TRANSFER_FAILED.selector);
        stargateAdapter.lzCompose(address(mockNativePool), GUID, message, address(0), new bytes(0));
    }

    // ------------- AMOUNTLD EDGE CASES ---------------

    function test_StargateAdapter_lzCompose_TransfersOnlyAmountLD() public {
        bytes memory innerPayload = _buildStargateDestinationData(address(this));
        // amountLD in codec says 500, adapter has 1000 — only 500 should be transferred
        bytes memory message = _encodeComposeMsg(1, 30_101, 500, bytes32(uint256(1)), innerPayload);

        _getTokens(address(mockERC20), address(stargateAdapter), 1000);
        _mockProcessBridgedExecution();

        vm.expectEmit(true, true, false, true);
        emit StargateAdapter.ComposeExecuted(address(this), address(mockERC20), 500);

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
