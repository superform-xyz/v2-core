// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Helpers} from "../../utils/Helpers.sol";

import {AcrossV3Adapter} from "../../../src/core/adapters/AcrossV3Adapter.sol";
import {IAcrossV3Receiver} from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import {DebridgeAdapter} from "../../../src/core/adapters/DebridgeAdapter.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

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

    receive() external payable {}

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
        assertEq(adp.acrossSpokePool(), address(0x1));
        assertEq(address(adp.superDestinationExecutor()), address(0x2));
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
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes,uint256)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0),
                uint256(0)
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
        assertEq(adp.externalCallAdapter(), address(this));
        assertEq(address(adp.superDestinationExecutor()), address(0x2));

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
        bytes memory _data = _buildDebridgeDestinationData(address(0x1));
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
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes,uint256)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0),
                uint256(0)
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
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes,uint256)"),
            abi.encode(
                address(mockERC20),
                address(this),
                new address[](0),
                new uint256[](0),
                new bytes(0),
                new bytes(0),
                new bytes(0),
                uint256(0)
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
}
