// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { SpectraExchangeDepositHook } from "../../../../src/core/hooks/swappers/spectra/SpectraExchangeDepositHook.sol";
import { SpectraExchangeRedeemHook } from "../../../../src/core/hooks/swappers/spectra/SpectraExchangeRedeemHook.sol";
import { SpectraCommands } from "../../../../src/vendor/spectra/SpectraCommands.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

import { MockSpectraRouter } from "../../../mocks/MockSpectraRouter.sol";

contract SpectraExchangeHooksTests is Helpers {
    SpectraExchangeDepositHook public depositHook;
    SpectraExchangeRedeemHook public redeemHook;
    MockSpectraRouter public router;
    MockERC20 public token;
    MockHook public prevHook;
    address public account;

    bytes1 public constant REDEEM_IBT_FOR_ASSET = bytes1(uint8(SpectraCommands.REDEEM_IBT_FOR_ASSET));
    bytes1 public constant REDEEM_PT_FOR_ASSET = bytes1(uint8(SpectraCommands.REDEEM_PT_FOR_ASSET));

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        router = new MockSpectraRouter(address(token));
        depositHook = new SpectraExchangeDepositHook(address(router));
        redeemHook = new SpectraExchangeRedeemHook(address(router));
        account = address(this);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(token));
    }

    function test_DepositHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SpectraExchangeDepositHook(address(0));
    }

    function test_DepositHook_UsePrevHookAmount_Is_Wrong() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(1), // usePrevHookAmount = true
            uint256(0), // value
            txData
        );

        // even the bytes data usePrevHookAmount is set to true but the actual boolean is not set to true
        //assertFalse(hook.decodeUsePrevHookAmount(data));

        // ^ this was fixed
        assertTrue(depositHook.decodeUsePrevHookAmount(data));
    }

    function test_DepositHook_UsePrevHookAmount() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        assertFalse(depositHook.decodeUsePrevHookAmount(data));
    }

    function test_DepositHook_UsePrevHookAmount_SetToTrue() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(1), // usePrevHookAmount = true
            uint256(0), // value
            txData
        );

        assertTrue(depositHook.decodeUsePrevHookAmount(data));
    }

    function test_DepositHook_Build_DepositAssetInPT() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );
        assertEq(depositHook.decodeUsePrevHookAmount(data), false);

        Execution[] memory executions = depositHook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
    }

    function test_DepositHook_DepositAssetInPT_Inspector() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        bytes memory argsEncoded = depositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_DepositHook_Build_DepositAssetInIBT() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        Execution[] memory executions = depositHook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
    }

    function test_DepositHook_DepositAssetInIBT_Inspector() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        bytes memory argsEncoded = depositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_DepositHook_TransferFrom_Inspector() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.TRANSFER_FROM));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        bytes memory argsEncoded = depositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_DepositHook_Build_WithPrevHookAmount() public {
        prevHook.setOutAmount(2e18, address(this));

        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        // Encode the full transaction data
        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(1), // usePrevHookAmount = true
            uint256(2e18), // value
            txData
        );

        Execution[] memory executions = depositHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 2e18);
    }

    function test_DepositHook_Build_RevertIf_InvalidPT() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeDepositHook.INVALID_PT.selector);
        depositHook.build(address(0), account, data);
    }

    function test_DepositHook_Build_RevertIf_InvalidIBT() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(0), 1e18, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeDepositHook.INVALID_IBT.selector);
        depositHook.build(address(0), account, data);
    }

    function test_DepositHook_Build_RevertIf_InvalidRecipient() public {
        address otherAccount = makeAddr("other");

        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, otherAccount, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeDepositHook.INVALID_RECIPIENT.selector);
        depositHook.build(address(0), account, data);
    }

    function test_DepositHook_Build_RevertIf_LengthMismatch() public {
        bytes memory commandsData = new bytes(2); // 2 commands
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));
        commandsData[1] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_IBT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeDepositHook.LENGTH_MISMATCH.selector);
        depositHook.build(address(0), account, data);
    }

    function test_DepositHook_Build_RevertIf_InvalidCommand() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(0xFF)); // Invalid command

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        vm.expectRevert(SpectraExchangeDepositHook.INVALID_COMMAND.selector);
        depositHook.build(address(0), account, data);
    }

    function test_DepositHook_PreExecute_PostExecute() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        bytes memory txData = abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        depositHook.preExecute(address(0), account, data);

        token.mint(account, 2e18);

        depositHook.postExecute(address(0), account, data);
    }

    function test_DepositHook_Build_WithDeadline() public view {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory txData =
            abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[],uint256)")), commandsData, inputs, deadline);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        Execution[] memory executions = depositHook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
    }

    function test_DepositHook_Build_RevertIf_InvalidDeadline() public {
        bytes memory commandsData = new bytes(1);
        commandsData[0] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(token), 1e18, account, account, 1);

        uint256 deadline = block.timestamp - 1;

        bytes memory txData =
            abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[],uint256)")), commandsData, inputs, deadline);

        bytes memory data = abi.encodePacked(
            bytes32(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0),
            uint256(0),
            txData
        );

        vm.expectRevert(SpectraExchangeDepositHook.INVALID_DEADLINE.selector);
        depositHook.build(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            REDEEM HOOK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SpectraExchangeRedeemHook(address(0));
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

    function test_Build_WithPrevHook_CallDataLengthABC() public {
        CallDataTestVars memory vars;

        // Create a custom mock hook with a fixed output amount
        vars.prevHookAmount = 5000e18;
        vars.mockPrevHook = address(new MockPrevHookWithFixedAmount(vars.prevHookAmount));

        // Set up command data for DEPOSIT_ASSET_IN_PT
        vars.commandsData = new bytes(1);
        vars.commandsData[0] = bytes1(uint8(SpectraCommands.REDEEM_PT_FOR_ASSET));

        // Original amount in the input data
        vars.originalAmount = 1000e18;

        // Set up input data with the original amount
        vars.inputs = new bytes[](1);
        vars.inputs[0] = abi.encode(address(token), vars.originalAmount, account, account, 1);

        // Create original transaction data
        vars.originalTxData =
            abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), vars.commandsData, vars.inputs);

        // Get the length of the original transaction data
        vars.originalTxDataLength = vars.originalTxData.length;

        // Create hook data with usePrevHookAmount = true
        vars.data = abi.encodePacked(
            _getYieldSourceOracleId(bytes32(bytes("")), address(this)), // yieldSourceOracleId
            address(token), // asset
            address(token), // pt
            address(this), // recipient
            uint256(2e6), // minAssets
            uint256(0), // shares To burn
            true, // usePrevHookAmount = true
            vars.commandsData[0] // command
        );

        // Verify decodeUsePrevHookAmount is working as expected
        bool usePrevHookAmount = redeemHook.decodeUsePrevHookAmount(vars.data);
        assertTrue(usePrevHookAmount, "usePrevHookAmount should be true");

        // Execute build with the custom previous hook that always returns our fixed amount
        vars.executions = redeemHook.build(vars.mockPrevHook, account, vars.data);

        // Extract the updated callData from the execution
        vars.updatedTxData = vars.executions[1].callData;

        // Verify our mock hook is returning the correct amount
        assertEq(
            MockPrevHookWithFixedAmount(vars.mockPrevHook).getOutAmount(address(this)),
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

        uint256 offset = 32;
        uint256 sharesToBurn;
        bytes memory inputData = vars.updatedInputs[0];
        assembly {
            sharesToBurn := mload(add(inputData, add(0x20, offset)))
        }

        // Verify the amount was updated to use the previous hook amount
        assertEq(sharesToBurn, vars.prevHookAmount, "Amount should be updated to previous hook amount");
    }

    function _getYieldSourceOracleId(bytes32 id, address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, sender));
    }
}

contract MockPrevHookWithFixedAmount {
    uint256 public amount;

    constructor(uint256 _amount) {
        amount = _amount;
    }

    function getOutAmount(address) public view returns (uint256) {
        return amount;
    }
}
