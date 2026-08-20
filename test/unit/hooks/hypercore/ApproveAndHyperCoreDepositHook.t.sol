// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { ApproveAndHyperCoreDepositHook } from "../../../../src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { IHyperCoreDepositGateway } from "../../../../src/vendor/hyperliquid/IHyperCoreDepositGateway.sol";
import { ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";

/// @notice Behavioral tests for the one hook in the HyperCore family that moves real ERC-20 value.
/// @dev Its siblings are covered by byte-exact CoreWriter fixtures; this hook never touches
///      CoreWriter, so what needs pinning here is the four-execution approve/deposit/reset
///      sequence, the resizable-amount surface (S1 — unlike the S2 CoreWriter leaves), and the
///      balance-diff outAmount semantics.
contract ApproveAndHyperCoreDepositHookTest is Helpers {
    uint32 internal constant GATEWAY_ARG = 0;
    uint256 internal constant AMOUNT_POSITION = 52;

    ApproveAndHyperCoreDepositHook internal hook;
    address internal token;
    address internal gateway;

    uint256 internal amount;
    uint256 internal prevHookAmount;

    function setUp() public {
        token = address(new MockERC20("USD Coin", "USDC", 6));
        gateway = address(0x6B9E773128f453f5c2C60935Ee2DE2CBc5390A24);
        amount = 1000e6;
        prevHookAmount = 2000e6;

        hook = new ApproveAndHyperCoreDepositHook(token, gateway, GATEWAY_ARG);
    }

    function _encodeData(uint256 amount_, bool usePrevHookAmount_) internal pure returns (bytes memory) {
        // standard 52-byte strategy header + uint256 amount @52 + bool @84
        return abi.encodePacked(bytes32(0), bytes20(0), amount_, usePrevHookAmount_);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(hook.TOKEN(), token, "TOKEN immutable");
        assertEq(hook.GATEWAY(), gateway, "GATEWAY immutable");
        assertEq(hook.GATEWAY_ARG(), GATEWAY_ARG, "GATEWAY_ARG immutable");
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "no ledger participation");
        assertEq(hook.subtype(), HookSubTypes.HYPERCORE, "subtype");
    }

    function test_Revert_ConstructorZeroToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndHyperCoreDepositHook(address(0), gateway, GATEWAY_ARG);
    }

    function test_Revert_ConstructorZeroGateway() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndHyperCoreDepositHook(token, address(0), GATEWAY_ARG);
    }

    /*//////////////////////////////////////////////////////////////
                                 BUILD
    //////////////////////////////////////////////////////////////*/

    /// @dev The exact four-execution sequence: zero the allowance, approve the amount, deposit,
    ///      zero the allowance again. No standing allowance may survive the hook.
    function test_Build_ApproveDepositResetSequence() public view {
        Execution[] memory executions = hook.build(address(0), address(this), _encodeData(amount, false));

        assertEq(executions.length, 6, "pre + 4 + post");

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (gateway, 0)), "reset allowance first");

        assertEq(executions[2].target, token);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (gateway, amount)), "approve exact amount");

        assertEq(executions[3].target, gateway);
        assertEq(executions[3].value, 0);
        assertEq(
            executions[3].callData,
            abi.encodeCall(IHyperCoreDepositGateway.deposit, (amount, GATEWAY_ARG)),
            "deposit with the pinned gateway arg"
        );

        assertEq(executions[4].target, token);
        assertEq(executions[4].value, 0);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (gateway, 0)), "reset allowance last");
    }

    function test_Build_UsePrevHookAmount() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        Execution[] memory executions = hook.build(mockPrevHook, address(this), _encodeData(amount, true));

        assertEq(
            executions[2].callData,
            abi.encodeCall(IERC20.approve, (gateway, prevHookAmount)),
            "approval must track the previous hook's amount"
        );
        assertEq(
            executions[3].callData,
            abi.encodeCall(IHyperCoreDepositGateway.deposit, (prevHookAmount, GATEWAY_ARG)),
            "deposit must track the previous hook's amount"
        );
    }

    function test_Revert_ZeroAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(0, false));
    }

    /// @dev A zero forwarded amount must fail identically to a zero static amount.
    function test_Revert_ZeroPrevHookAmount() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, token));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(mockPrevHook, address(this), _encodeData(amount, true));
    }

    function test_Revert_LengthNotExact() public {
        bytes memory tooLong = abi.encodePacked(_encodeData(amount, false), bytes1(0));
        vm.expectRevert(ApproveAndHyperCoreDepositHook.DATA_NOT_VALID.selector);
        hook.build(address(0), address(this), tooLong);

        bytes memory tooShort = abi.encodePacked(bytes32(0), bytes20(0), amount);
        vm.expectRevert(ApproveAndHyperCoreDepositHook.DATA_NOT_VALID.selector);
        hook.build(address(0), address(this), tooShort);
    }

    /*//////////////////////////////////////////////////////////////
                    SIZING INTERFACE — S1, RESIZABLE
    //////////////////////////////////////////////////////////////*/

    /// @dev Deliberate contrast with the CoreWriter leaves: this hook's amount is in EVM token
    ///      units, so it IS bundler-resizable and declares the full sizing surface.
    function test_S1_DeclaresBothSizingInterfaces() public view {
        assertTrue(IERC165(address(hook)).supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(IERC165(address(hook)).supportsInterface(type(ISuperHookOutflow).interfaceId));
    }

    function test_DecodeUsePrevHookAmount() public view {
        assertFalse(hook.decodeUsePrevHookAmount(_encodeData(amount, false)));
        assertTrue(hook.decodeUsePrevHookAmount(_encodeData(amount, true)));
    }

    function test_DecodeAmounts() public view {
        uint256[] memory amounts = hook.decodeAmounts(_encodeData(amount, false));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);
    }

    function test_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = hook.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function testFuzz_ReplaceCalldataAmounts(uint256 newAmount) public view {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = newAmount;

        bytes memory replaced = hook.replaceCalldataAmounts(_encodeData(amount, false), amounts);
        assertEq(hook.decodeAmounts(replaced)[0], newAmount, "amount must be replaced at offset 52");
        assertEq(replaced.length, 85, "length must be unchanged");
    }

    function test_Revert_ReplaceCalldataAmountsWrongLength() public {
        uint256[] memory amounts = new uint256[](2);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts(_encodeData(amount, false), amounts);
    }

    /*//////////////////////////////////////////////////////////////
                         PRE/POST EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @dev Balance-diff semantics: outAmount ends as the tokens that LEFT the account (the
    ///      deposited amount), and outToken is the pinned TOKEN. Those tokens now live on
    ///      HyperCore — outAmount is a record of what was sent, not an EVM-side output.
    function test_PrePostExecute_MeasuresDeposit() public {
        uint256 balance = 5000e6;
        uint256 deposited = 1200e6;
        _getTokens(token, address(this), balance);

        bytes memory data = _encodeData(deposited, false);

        hook.preExecute(address(0), address(this), data);
        assertEq(hook.getOutAmount(address(this)), balance, "preExecute snapshots the full balance");

        // simulate the gateway pulling the deposit
        IERC20(token).transfer(address(0xdead), deposited);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.getOutAmount(address(this)), deposited, "outAmount is the balance decrease");
        assertEq(hook.getOutToken(address(this)), token, "outToken is the pinned TOKEN");
    }

    /*//////////////////////////////////////////////////////////////
                              INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsTokenAndGateway() public view {
        bytes memory inspected = hook.inspect(_encodeData(amount, false));
        assertEq(inspected.length, 40, "two packed addresses");
        assertEq(inspected, abi.encodePacked(token, gateway));
    }
}
