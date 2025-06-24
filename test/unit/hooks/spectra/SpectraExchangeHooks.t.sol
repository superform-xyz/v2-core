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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
            address(token), // yieldSource
            uint8(0), // usePrevHookAmount = false
            uint256(0), // value
            txData
        );

        bytes memory argsEncoded = depositHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_DepositHook_Build_WithPrevHookAmount() public {
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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
            bytes4(bytes("")), // yieldSourceOracleId
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

    function test_RedeemHook_UsePrevHookAmount() public view {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(token), account, 1000, 1e18, true, false);

        assertTrue(redeemHook.decodeUsePrevHookAmount(data));
    }

    function test_RedeemHook_Build_RedeemIBTForAsset() public view {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(0), account, 1000, 1e18, false, false);

        Execution[] memory executions = redeemHook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_RedeemHook_Build_InvalidReceiver() public {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(token), address(0), 1000, 1e18, false, true);

        vm.expectRevert(SpectraExchangeRedeemHook.INVALID_RECIPIENT.selector);
        redeemHook.build(address(0), account, data);
    }

    function test_RedeemHook_Build_RedeemPtForAsset_RevertIf_ZeroAmount() public {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(token), account, 0, 1e18, false, true);

        vm.expectRevert(SpectraExchangeRedeemHook.INVALID_MIN_ASSETS.selector);
        redeemHook.build(address(0), account, data);
    }

    function test_RedeemHook_Build_RedeemPTForAsset() public view {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(token), account, 1000, 1e18, false, true);

        Execution[] memory executions = redeemHook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_RedeemHook_Build_RedeemPTForAsset_RevertIf_InvalidPT() public {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(0), account, 1000, 1e18, false, true);

        vm.expectRevert(SpectraExchangeRedeemHook.INVALID_PT.selector);
        redeemHook.build(address(0), account, data);
    }

    function test_RedeemHook_Inspect() public view {
        bytes memory data =
            _createSpectraExchangeRedeemHookData(address(token), address(token), account, 1000, 1e18, false, true);

        bytes memory argsEncoded = redeemHook.inspect(data);
        bytes memory expectedArgs = abi.encodePacked(address(token), address(token), account);

        assertEq(argsEncoded, expectedArgs);
    }

    function _createSpectraExchangeRedeemHookData(
        address asset,
        address pt,
        address recipient,
        uint256 minAssets,
        uint256 sharesToBurn,
        bool usePrevHookAmount,
        bool redeemPtForAsset
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes1 command = redeemPtForAsset ? REDEEM_PT_FOR_ASSET : REDEEM_IBT_FOR_ASSET;

        return abi.encodePacked(
            bytes4(bytes("")), asset, pt, recipient, minAssets, sharesToBurn, usePrevHookAmount, command
        );
    }
}
