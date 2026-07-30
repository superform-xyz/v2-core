// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AcrossV3AdapterV2Simulations } from "../../mocks/simulationHelpers/AcrossV3AdapterV2Simulations.sol";
import {
    DestinationAdapterSimulationConfig
} from "../../mocks/simulationHelpers/DestinationAdapterSimulationConfig.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

import { DestinationSimulationTestBase, RecordingDestinationExecutor } from "./DestinationSimulationTestBase.sol";

contract AcrossV3AdapterV2SimulationsTest is DestinationSimulationTestBase {
    uint256 internal constant AMOUNT = 1_000_000;
    bytes32 internal constant ROOT = keccak256("across-root");

    address internal spokePool;
    address internal account;
    address internal adapterAddress;

    AcrossV3AdapterV2Simulations internal adapter;
    RecordingDestinationExecutor internal executor;
    MockERC20 internal token;

    function setUp() public {
        spokePool = makeAddr("spokePool");
        account = makeAddr("account");
        adapterAddress = makeAddr("acrossAdapter");

        executor = new RecordingDestinationExecutor();
        token = new MockERC20("Mock Token", "MOCK", 18);

        _installConfiguredRuntime(
            adapterAddress, type(AcrossV3AdapterV2Simulations).runtimeCode, spokePool, address(0), address(executor)
        );
        adapter = AcrossV3AdapterV2Simulations(adapterAddress);
    }

    function test_RuntimeTrailer_Getters() public view {
        assertEq(adapter.ACROSS_SPOKE_POOL(), spokePool);
        assertEq(address(adapter.SUPER_DESTINATION_EXECUTOR()), address(executor));
        assertEq(adapterAddress.code.length, type(AcrossV3AdapterV2Simulations).runtimeCode.length + 128);
    }

    function test_RuntimeTrailer_RevertIf_Missing() public {
        address unconfigured = makeAddr("unconfiguredAcrossAdapter");
        vm.etch(unconfigured, type(AcrossV3AdapterV2Simulations).runtimeCode);

        vm.expectRevert(DestinationAdapterSimulationConfig.INVALID_SIMULATION_CONFIG.selector);
        AcrossV3AdapterV2Simulations(unconfigured).ACROSS_SPOKE_POOL();
    }

    function test_RuntimeTrailer_RevertIf_WrongMagic() public {
        address misconfigured = makeAddr("misconfiguredAcrossAdapter");
        vm.etch(
            misconfigured,
            bytes.concat(
                type(AcrossV3AdapterV2Simulations).runtimeCode,
                abi.encode(bytes32(uint256(1)), spokePool, address(0), address(executor))
            )
        );

        vm.expectRevert(DestinationAdapterSimulationConfig.INVALID_SIMULATION_CONFIG.selector);
        AcrossV3AdapterV2Simulations(misconfigured).ACROSS_SPOKE_POOL();
    }

    function test_RuntimeTrailer_RevertIf_AddressWordIsNotCanonical() public {
        address misconfigured = makeAddr("nonCanonicalAcrossAdapter");
        bytes32 nonCanonicalSpokePool = bytes32((uint256(1) << 160) | uint160(spokePool));
        vm.etch(
            misconfigured,
            bytes.concat(
                type(AcrossV3AdapterV2Simulations).runtimeCode,
                abi.encode(CONFIG_MAGIC, nonCanonicalSpokePool, address(0), address(executor))
            )
        );

        vm.expectRevert(DestinationAdapterSimulationConfig.INVALID_SIMULATION_CONFIG.selector);
        AcrossV3AdapterV2Simulations(misconfigured).ACROSS_SPOKE_POOL();
    }

    function test_RuntimeTrailer_RevertIf_RequiredAddressIsZero() public {
        address misconfigured = makeAddr("zeroAddressAcrossAdapter");
        _installConfiguredRuntime(
            misconfigured, type(AcrossV3AdapterV2Simulations).runtimeCode, address(0), address(0), address(executor)
        );

        vm.expectRevert(DestinationAdapterSimulationConfig.INVALID_SIMULATION_CONFIG.selector);
        AcrossV3AdapterV2Simulations(misconfigured).ACROSS_SPOKE_POOL();
    }

    function test_HandleV3AcrossMessage_HappyPath() public {
        bytes memory executorCalldata = hex"01020304";
        (bytes memory message, bytes memory sigData) =
            _message(account, address(executor), executorCalldata, uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);

        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), message);

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

    function test_HandleV3AcrossMessage_RevertIf_WrongSender() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));

        vm.prank(makeAddr("notSpokePool"));
        vm.expectRevert(IAcrossV3Receiver.INVALID_SENDER.selector);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, address(0), message);
    }

    function test_HandleV3AcrossMessage_RevertIf_ExecutorMismatch() public {
        (bytes memory message,) = _message(account, makeAddr("wrongExecutor"), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);

        vm.prank(spokePool);
        vm.expectRevert(AcrossV3AdapterV2Simulations.EXECUTOR_MISMATCH.selector);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, address(0), message);

        assertEq(token.balanceOf(adapterAddress), AMOUNT);
        assertEq(token.balanceOf(account), 0);
        assertEq(executor.callCount(), 0);
    }

    function test_HandleV3AcrossMessage_TransferRevertRollsBack() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);
        vm.mockCallRevert(
            address(token),
            abi.encodeCall(IERC20.transfer, (account, AMOUNT)),
            abi.encodeWithSignature("Error(string)", "transfer failed")
        );

        vm.prank(spokePool);
        vm.expectRevert(AcrossV3AdapterV2Simulations.TRANSFER_FAILED.selector);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, address(0), message);

        assertEq(token.balanceOf(adapterAddress), AMOUNT);
        assertEq(token.balanceOf(account), 0);
        assertEq(executor.callCount(), 0);
    }

    function test_HandleV3AcrossMessage_ExecutorRevertRollsBackTransfer() public {
        (bytes memory message,) = _message(account, address(executor), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);
        executor.setShouldRevert(true);

        vm.prank(spokePool);
        vm.expectRevert(RecordingDestinationExecutor.MOCK_EXECUTION_REVERTED.selector);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, address(0), message);

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
        message = abi.encode(bytes(""), sigData);
    }
}
