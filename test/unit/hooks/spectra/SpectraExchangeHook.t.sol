// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { SpectraExchangeHook } from "../../../../src/core/hooks/swappers/spectra/SpectraExchangeHook.sol";
import { SpectraCommands } from "../../../../src/vendor/spectra/SpectraCommands.sol";
import { ISpectraRouter } from "../../../../src/vendor/spectra/ISpectraRouter.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

import { MockSpectraRouter } from "../../../mocks/MockSpectraRouter.sol";

import "forge-std/console2.sol";

contract SpectraExchangeHookTest is Helpers {
    SpectraExchangeHook public hook;
    MockSpectraRouter public router;
    MockERC20 public token;
    MockHook public prevHook;
    address public account;

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        router = new MockSpectraRouter(address(token));
        hook = new SpectraExchangeHook(address(router));
        account = address(this);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(token));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SpectraExchangeHook(address(0));
    }

    function test_UsePrevHookAmount_Is_Wrong() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(1), // usePrevHookAmount = true
            uint256(0), // value
            txData
        );

        // even the bytes data usePrevHookAmount is set to true but the actual boolean is not set to true
        //assertFalse(hook.decodeUsePrevHookAmount(data));

        // ^ this was fixed
        assertTrue(hook.decodeUsePrevHookAmount(data));
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
    

    function test_UsePrevHookAmount_SetToTrue() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(1), // usePrevHookAmount = true
            uint256(0), // value
            txData
        );

        assertTrue(hook.decodeUsePrevHookAmount(data));
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

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
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

        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
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

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
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

        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
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

        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
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

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 2e18);
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

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
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

    struct CallDataTestVars {
        address mockPrevHook;
        uint256 prevHookAmount;
        uint256 originalAmount;
        bytes commandsData;
        bytes[] inputs;
        bytes originalTxData;
        uint256 originalTxDataLength;
        bytes data;
        Execution[] executions;
        bytes updatedTxData;
        bytes updatedCommandsData;
        bytes[] updatedInputs;
        address updatedPt;
        uint256 updatedAmount;
        address updatedPtRecipient;
        address updatedYtRecipient;
        uint256 updatedMinShares;
    }

    function test_Build_WithPrevHook_CallDataLength() public {
        CallDataTestVars memory vars;
        
        // Create a custom mock hook with a fixed output amount
        vars.prevHookAmount = 5000e18;
        vars.mockPrevHook = address(new MockPrevHookWithFixedAmount(vars.prevHookAmount));
        
        // Set up command data for DEPOSIT_ASSET_IN_PT
        vars.commandsData = new bytes(1);
        vars.commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));
        
        // Original amount in the input data
        vars.originalAmount = 1000e18;
        
        // Set up input data with the original amount
        vars.inputs = new bytes[](1);
        vars.inputs[0] = abi.encode(address(token), vars.originalAmount, account, account, 1);
        
        // Create original transaction data
        vars.originalTxData = abi.encodeWithSelector(
            bytes4(keccak256("execute(bytes,bytes[])")), 
            vars.commandsData, 
            vars.inputs
        );
        
        // Get the length of the original transaction data
        vars.originalTxDataLength = vars.originalTxData.length;

        // Create hook data with usePrevHookAmount = true
        vars.data = abi.encodePacked(
            bytes4(bytes("")), // yieldSourceOracleId
            address(token),    // yieldSource
            true,              // usePrevHookAmount = true
            uint256(0),        // value
            vars.originalTxData // transaction data
        );
        
        // Verify decodeUsePrevHookAmount is working as expected
        bool usePrevHookAmount = hook.decodeUsePrevHookAmount(vars.data);
        assertTrue(usePrevHookAmount, "usePrevHookAmount should be true");
        
        // Execute build with the custom previous hook that always returns our fixed amount
        vars.executions = hook.build(vars.mockPrevHook, account, vars.data);
        
        // Extract the updated callData from the execution
        vars.updatedTxData = vars.executions[1].callData;
        
        // Verify the updated transaction data has the same length as the original
        assertEq(
            vars.updatedTxData.length,
            vars.originalTxDataLength,
            "Updated transaction data length should match original length"
        );
        
        // Verify our mock hook is returning the correct amount
        assertEq(
            MockPrevHookWithFixedAmount(vars.mockPrevHook).outAmount(),
            vars.prevHookAmount,
            "Mock hook should return the fixed amount"
        );
        
        // Decode the actual callData
        bytes4 selector = bytes4(BytesLib.slice(vars.updatedTxData, 0, 4));
        assertEq(selector, bytes4(keccak256("execute(bytes,bytes[])")), "Selector should match");
        
        (vars.updatedCommandsData, vars.updatedInputs) = 
            abi.decode(BytesLib.slice(vars.updatedTxData, 4, vars.updatedTxData.length - 4), (bytes, bytes[]));
        
        // Verify we have the right number of inputs
        assertEq(vars.updatedInputs.length, 1, "Should have one input");
        
        // Decode the first input to get the updated amount
        (vars.updatedPt, vars.updatedAmount, vars.updatedPtRecipient, vars.updatedYtRecipient, vars.updatedMinShares) = 
            abi.decode(vars.updatedInputs[0], (address, uint256, address, address, uint256));
        
        // Debug output
        console2.log("Original amount:", vars.originalAmount);
        console2.log("Fixed prev hook amount:", vars.prevHookAmount); 
        console2.log("Updated amount in callData:", vars.updatedAmount);
        
        // Verify the amount was updated to use the previous hook amount
        assertEq(vars.updatedAmount, vars.prevHookAmount, "Amount should be updated to previous hook amount");
        
        // Verify other parameters remained unchanged
        assertEq(vars.updatedCommandsData.length, vars.commandsData.length, "Command data length should remain the same");
        assertEq(vars.updatedPt, address(token), "PT address should remain unchanged");
        assertEq(vars.updatedPtRecipient, account, "PT recipient should remain unchanged");
        assertEq(vars.updatedYtRecipient, account, "YT recipient should remain unchanged");
    }
}

contract MockPrevHookWithFixedAmount {
    uint256 public amount;

    constructor(uint256 _amount) {
        amount = _amount;
    }

    function outAmount() public view returns (uint256) {
        return amount;
    }
}
