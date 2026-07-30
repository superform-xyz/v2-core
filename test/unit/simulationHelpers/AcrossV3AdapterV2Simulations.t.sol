// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AcrossV3AdapterV2Simulations } from "../../mocks/simulationHelpers/AcrossV3AdapterV2Simulations.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

import { DestinationSimulationTestBase, RecordingDestinationExecutor } from "./DestinationSimulationTestBase.sol";

contract AcrossV3AdapterV2SimulationsTest is DestinationSimulationTestBase {
    uint256 internal constant AMOUNT = 1_000_000;
    bytes32 internal constant ROOT = keccak256("across-root");
    uint256 internal constant RUNTIME_LENGTH = 4016;
    bytes32 internal constant RUNTIME_HASH = 0x55e0abd65f7eb9796556faafd0e0e76775019bc053c737ee686a1306d2d5caf9;

    address internal spokePool;
    address internal account;
    address internal adapterAddress;

    AcrossV3AdapterV2Simulations internal adapter;
    AcrossV3AdapterV2Simulations internal implementation;
    RecordingDestinationExecutor internal executor;
    MockERC20 internal token;

    function setUp() public {
        spokePool = makeAddr("spokePool");
        account = makeAddr("account");
        adapterAddress = makeAddr("acrossAdapter");

        executor = new RecordingDestinationExecutor();
        token = new MockERC20("Mock Token", "MOCK", 18);

        implementation = new AcrossV3AdapterV2Simulations(spokePool, address(executor));
        vm.etch(adapterAddress, address(implementation).code);
        adapter = AcrossV3AdapterV2Simulations(adapterAddress);
    }

    function test_ConstructorPatchedRuntime_GettersAfterEtch() public view {
        assertEq(adapter.ACROSS_SPOKE_POOL(), spokePool);
        assertEq(address(adapter.SUPER_DESTINATION_EXECUTOR()), address(executor));
        assertEq(adapterAddress.codehash, address(implementation).codehash);
    }

    function test_ArtifactRuntime_ImmutableReferencesAreLocked() public view {
        bytes memory runtime = vm.getDeployedCode(
            "test/mocks/simulationHelpers/AcrossV3AdapterV2Simulations.sol:AcrossV3AdapterV2Simulations"
        );
        assertEq(runtime.length, RUNTIME_LENGTH);
        assertEq(keccak256(runtime), RUNTIME_HASH);

        _assertAndPatchImmutableReferences(runtime, [uint256(195), uint256(303)], spokePool);
        _assertAndPatchImmutableReferences(runtime, [uint256(258), uint256(627)], address(executor));

        assertEq(runtime, address(implementation).code);
    }

    function test_Constructor_RevertIf_RequiredAddressIsZero() public {
        vm.expectRevert(AcrossV3AdapterV2Simulations.ADDRESS_NOT_VALID.selector);
        new AcrossV3AdapterV2Simulations(address(0), address(executor));

        vm.expectRevert(AcrossV3AdapterV2Simulations.ADDRESS_NOT_VALID.selector);
        new AcrossV3AdapterV2Simulations(spokePool, address(0));
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

    function test_HandleV3AcrossMessage_ProofExecutorDoesNotChangeConfiguredCallTarget() public {
        (bytes memory message,) = _message(account, makeAddr("wrongExecutor"), hex"01", uint64(block.chainid));
        token.mint(adapterAddress, AMOUNT);

        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, address(0), message);

        assertEq(token.balanceOf(adapterAddress), 0);
        assertEq(token.balanceOf(account), AMOUNT);
        assertEq(executor.callCount(), 1);
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
