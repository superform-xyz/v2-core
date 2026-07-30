// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StargateAdapterV2Simulations } from "../../mocks/simulationHelpers/StargateAdapterV2Simulations.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

import {
    DestinationSimulationTestBase,
    RecordingDestinationExecutor,
    SimulationStargatePool,
    SimulationTokenMessaging
} from "./DestinationSimulationTestBase.sol";

contract StargateAdapterV2SimulationsTest is DestinationSimulationTestBase {
    uint256 internal constant AMOUNT = 1_000_000;
    bytes32 internal constant GUID = keccak256("stargate-guid");
    bytes32 internal constant ROOT = keccak256("stargate-root");
    uint32 internal constant SOURCE_EID = 30_101;

    address internal endpoint;
    address internal account;
    address internal composeFrom;
    address internal adapterAddress;

    StargateAdapterV2Simulations internal adapter;
    RecordingDestinationExecutor internal executor;
    SimulationTokenMessaging internal tokenMessaging;
    SimulationStargatePool internal pool;
    MockERC20 internal token;

    function setUp() public {
        endpoint = makeAddr("layerZeroEndpoint");
        account = makeAddr("account");
        composeFrom = makeAddr("composeFrom");
        adapterAddress = makeAddr("stargateAdapter");

        executor = new RecordingDestinationExecutor();
        tokenMessaging = new SimulationTokenMessaging();
        token = new MockERC20("Mock Token", "MOCK", 18);
        pool = new SimulationStargatePool(address(token));
        tokenMessaging.setAssetId(address(pool), 1);

        _installConfiguredRuntime(
            adapterAddress,
            type(StargateAdapterV2Simulations).runtimeCode,
            endpoint,
            address(tokenMessaging),
            address(executor)
        );
        adapter = StargateAdapterV2Simulations(payable(adapterAddress));
    }

    function test_RuntimeTrailer_Getters() public view {
        assertEq(adapter.LZ_ENDPOINT(), endpoint);
        assertEq(address(adapter.TOKEN_MESSAGING()), address(tokenMessaging));
        assertEq(address(adapter.SUPER_DESTINATION_EXECUTOR()), address(executor));
        assertEq(adapterAddress.code.length, type(StargateAdapterV2Simulations).runtimeCode.length + 128);
    }

    function test_LzCompose_ERC20HappyPathPreservesSelfCall() public {
        bytes memory executorCalldata = hex"01020304";
        (bytes memory message, bytes memory sigData) =
            _message(account, address(executor), executorCalldata, uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);

        vm.expectCall(
            adapterAddress,
            abi.encodeCall(
                StargateAdapterV2Simulations.handleCompose, (GUID, message, address(token), AMOUNT, composeFrom)
            )
        );
        vm.prank(endpoint);
        adapter.lzCompose(address(pool), GUID, message, address(0), bytes(""));

        assertEq(token.balanceOf(account), AMOUNT);
        assertEq(token.balanceOf(adapterAddress), 0);
        assertEq(executor.callCount(), 1);
        assertEq(
            executor.lastCallHash(),
            keccak256(
                abi.encode(
                    address(token),
                    account,
                    _singleAddress(address(token)),
                    _singleUint(AMOUNT),
                    bytes(""),
                    executorCalldata,
                    sigData
                )
            )
        );
    }

    function test_LzCompose_NativeHappyPath() public {
        SimulationStargatePool nativePool = new SimulationStargatePool(address(0));
        tokenMessaging.setAssetId(address(nativePool), 1);
        (bytes memory message, bytes memory sigData) =
            _message(account, address(executor), hex"01020304", uint64(block.chainid));
        vm.deal(adapterAddress, AMOUNT);

        vm.prank(endpoint);
        adapter.lzCompose(address(nativePool), GUID, message, address(0), bytes(""));

        assertEq(account.balance, AMOUNT);
        assertEq(adapterAddress.balance, 0);
        assertEq(executor.callCount(), 1);
        assertEq(
            executor.lastCallHash(),
            keccak256(
                abi.encode(
                    address(0),
                    account,
                    _singleAddress(address(token)),
                    _singleUint(AMOUNT),
                    bytes(""),
                    hex"01020304",
                    sigData
                )
            )
        );
    }

    function test_LzCompose_RevertIf_ExecutorMismatch() public {
        (bytes memory message,) = _message(account, makeAddr("wrongExecutor"), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);

        vm.prank(endpoint);
        vm.expectRevert(StargateAdapterV2Simulations.EXECUTOR_MISMATCH.selector);
        adapter.lzCompose(address(pool), GUID, message, address(0), bytes(""));

        assertEq(token.balanceOf(adapterAddress), AMOUNT);
        assertEq(token.balanceOf(account), 0);
        assertEq(executor.callCount(), 0);
    }

    function test_LzCompose_RevertIf_WrongSender() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));

        vm.prank(makeAddr("notEndpoint"));
        vm.expectRevert(StargateAdapterV2Simulations.INVALID_SENDER.selector);
        adapter.lzCompose(address(pool), GUID, message, address(0), bytes(""));
    }

    function test_LzCompose_RevertIf_MessageTooShort() public {
        bytes memory shortMessage = new bytes(75);

        vm.prank(endpoint);
        vm.expectRevert(
            abi.encodeWithSelector(StargateAdapterV2Simulations.COMPOSE_MSG_TOO_SHORT.selector, shortMessage.length)
        );
        adapter.lzCompose(address(pool), GUID, shortMessage, address(0), bytes(""));
    }

    function test_LzCompose_RevertIf_UnregisteredPool() public {
        SimulationStargatePool unregisteredPool = new SimulationStargatePool(address(token));
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));

        vm.prank(endpoint);
        vm.expectRevert(
            abi.encodeWithSelector(StargateAdapterV2Simulations.UNREGISTERED_POOL.selector, address(unregisteredPool))
        );
        adapter.lzCompose(address(unregisteredPool), GUID, message, address(0), bytes(""));
    }

    function test_LzCompose_RevertIf_DestinationProofMissing() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid + 1));
        token.mint(adapterAddress, AMOUNT);

        vm.prank(endpoint);
        vm.expectRevert(
            abi.encodeWithSelector(StargateAdapterV2Simulations.NO_DST_PROOF_FOR_CHAIN.selector, uint64(block.chainid))
        );
        adapter.lzCompose(address(pool), GUID, message, address(0), bytes(""));
    }

    function test_LzCompose_TransferRevertRollsBack() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);
        vm.mockCallRevert(
            address(token),
            abi.encodeCall(IERC20.transfer, (account, AMOUNT)),
            abi.encodeWithSignature("Error(string)", "transfer failed")
        );

        vm.prank(endpoint);
        vm.expectRevert(
            abi.encodeWithSelector(
                StargateAdapterV2Simulations.TRANSFER_FAILED.selector, address(token), account, AMOUNT
            )
        );
        adapter.lzCompose(address(pool), GUID, message, address(0), bytes(""));

        assertEq(token.balanceOf(adapterAddress), AMOUNT);
        assertEq(token.balanceOf(account), 0);
        assertEq(executor.callCount(), 0);
    }

    function test_LzCompose_ExecutorRevertRollsBackTransfer() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);
        executor.setShouldRevert(true);

        vm.prank(endpoint);
        vm.expectRevert(RecordingDestinationExecutor.MOCK_EXECUTION_REVERTED.selector);
        adapter.lzCompose(address(pool), GUID, message, address(0), bytes(""));

        assertEq(token.balanceOf(adapterAddress), AMOUNT);
        assertEq(token.balanceOf(account), 0);
        assertEq(executor.callCount(), 0);
    }

    function _message(
        address destinationAccount,
        address destinationExecutor,
        bytes memory executorCalldata,
        uint64 chainId
    )
        private
        view
        returns (bytes memory message, bytes memory sigData)
    {
        sigData = _signatureData(
            destinationAccount,
            destinationExecutor,
            _singleAddress(address(token)),
            _singleUint(AMOUNT),
            executorCalldata,
            chainId,
            ROOT
        );
        bytes memory innerMessage = abi.encode(bytes(""), sigData);
        message = abi.encodePacked(uint64(0), SOURCE_EID, AMOUNT, bytes32(uint256(uint160(composeFrom))), innerMessage);
    }
}
