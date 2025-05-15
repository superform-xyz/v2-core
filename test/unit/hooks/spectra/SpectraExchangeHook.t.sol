// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { SpectraExchangeHook } from "../../../../src/core/hooks/swappers/spectra/SpectraExchangeHook.sol";
import { SpectraCommands } from "../../../../src/vendor/spectra/SpectraCommands.sol";
import { ISpectraRouter } from "../../../../src/vendor/spectra/ISpectraRouter.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";

import { MockSpectraRouter } from "../../../mocks/MockSpectraRouter.sol";

contract SpectraExchangeHookTest is Helpers {
    SpectraExchangeHook public hook;
    MockSpectraRouter public router;
    MockERC20 public token;
    MockHook public prevHook;
    address public account;

    function setUp() public {
        router = new MockSpectraRouter();
        hook = new SpectraExchangeHook(address(router));
        token = new MockERC20("Test Token", "TEST", 18);
        account = address(this);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(token));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SpectraExchangeHook(address(0));
    }

    function test_UsePrevHookAmount() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Build_DepositAssetInPT() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );
        assertEq(hook.decodeUsePrevHookAmount(data), false);

        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(router));
        assertEq(executions[0].value, 0);
    }

    function test_DepositAssetInPT_Inspector() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        (address target, address[] memory args) = hook.inspect(data);
        assertEq(args.length, 3);
    }

    function test_DepositAssetInPT_BeneficiaryArgs() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        uint8[] memory idxs = hook.beneficiaryArgs(data);
        assertEq(idxs.length, 2);
    }

    function test_Build_DepositAssetInIBT() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(router));
        assertEq(executions[0].value, 0);
    }


    function test_DepositAssetInIBT_Inspector() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        (address target, address[] memory args) = hook.inspect(data);
        assertEq(args.length, 2);
    }

    function test_DepositAssetInIBT_BeneficiaryArgs() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        uint8[] memory idxs = hook.beneficiaryArgs(data);
        assertEq(idxs.length, 1);
    }


    function test_TransferFrom_Inspector() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.TRANSFER_FROM));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        (address target, address[] memory args) = hook.inspect(data);
        assertEq(args.length, 1);
    }

    function test_TransferFrom_BeneficiaryArgs() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.TRANSFER_FROM));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        uint8[] memory idxs = hook.beneficiaryArgs(data);
        assertEq(idxs.length, 1);
    }

    function test_Build_WithPrevHookAmount() public {
        prevHook.setOutAmount(2e18);

        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        // Encode the full transaction data
        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(1), // usePrevHookAmount = true
            uint256(0), // value
            txData
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(router));
        assertEq(executions[0].value, 0);
    }

    function test_Build_RevertIf_InvalidPT() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeHook.INVALID_PT.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_InvalidIBT() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeHook.INVALID_IBT.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_InvalidRecipient() public {
        address otherAccount = makeAddr("other");

        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, otherAccount, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeHook.INVALID_RECIPIENT.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_LengthMismatch() public {
        bytes memory commandsData = new bytes(2); // 2 commands
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));
        commandsData[1] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeHook.LENGTH_MISMATCH.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_InvalidCommand() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(0xFF)); // Invalid command

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeHook.INVALID_COMMAND.selector);
        hook.build(address(0), account, data);
    }

    function test_PreExecute_PostExecute() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        hook.preExecute(address(0), account, data);

        token.mint(account, 2e18);

        hook.postExecute(address(0), account, data);
    }

    function test_Build_WithDeadline() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory txData =
            abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[],uint256)")), commandsData, inputs, deadline);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(router));
        assertEq(executions[0].value, 0);
    }

    function test_Build_RevertIf_InvalidDeadline() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        uint256 deadline = block.timestamp - 1;

        bytes memory txData =
            abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[],uint256)")), commandsData, inputs, deadline);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0),
            uint256(0),
            txData
        );

        vm.expectRevert(SpectraExchangeHook.INVALID_DEADLINE.selector);
        hook.build(address(0), account, data);
    }
}
