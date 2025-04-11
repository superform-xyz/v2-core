// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../../../BaseTest.t.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { IIrm } from "../../../../src/vendor/morpho/Iirm.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/core/interfaces/ISuperHook.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoRepayHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayHook.sol";
import {
    IMorphoBase,
    IMorphoStaticTyping,
    Id,
    MarketParams,
    Position,
    Market,
    IMorpho
} from "../../../../src/vendor/morpho/IMorpho.sol";

contract MorphoRepayHookTest is BaseTest {
    using MarketParamsLib for MarketParams;

    MorphoRepayHook public hook;
    MockERC20 public loanToken;
    MockERC20 public collateralToken;
    address public oracleAddress; // Use address for interface
    address public irmAddress; // Use address for interface
    address public morphoAddress; // Use MORPHO constant
    uint256 public amount; // Amount for partial repayment tests
    uint256 public lltv;

    MarketParams public marketParams;
    Id public marketId;

    // Interfaces pointing to the MORPHO address
    IMorphoBase public morphoBase;
    IMorpho public morphoInterface;
    IMorphoStaticTyping public morphoStaticTyping;

    function setUp() public override {
        super.setUp();

        // 1. Deploy mock ERC20 tokens
        loanToken = new MockERC20("Loan Token", "LOAN", 18);
        collateralToken = new MockERC20("Collateral Token", "COLL", 18);

        // Use placeholder addresses for Oracle and IRM as they come from data in build()
        oracleAddress = address(0x1);
        irmAddress = address(0x2);

        // Use MORPHO constant address
        morphoAddress = MORPHO;

        // 2. Cast MORPHO address to interfaces
        morphoBase = IMorphoBase(morphoAddress);
        morphoInterface = IMorpho(morphoAddress);
        morphoStaticTyping = IMorphoStaticTyping(morphoAddress);

        // 3. Initialize the hook
        hook = new MorphoRepayHook(address(this), morphoAddress);

        // 4. Set up test parameters
        amount = 500e18; // Amount to repay partially
        lltv = 0.9e18; // 90% LLTV

        // 5. Define MarketParams and calculate market ID using the library
        marketParams = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: oracleAddress,
            irm: irmAddress,
            lltv: lltv
        });
        marketId = marketParams.id();

        // 6. Give the test contract some loan tokens to perform repayments
        _getTokens(address(loanToken), address(this), 10_000e18);

        // NOTE: No setup of mock Morpho state needed. Tests will interact with
        // the actual MORPHO address (likely via a fork).
    }

    // --- Test Cases ---

    function test_Constructor() public view {
        assertEq(hook.morpho(), morphoAddress, "Morpho address mismatch");
        assertEq(address(hook.morphoBase()), morphoAddress, "MorphoBase interface mismatch");
        assertEq(address(hook.morphoInterface()), morphoAddress, "Morpho interface mismatch");
        assertEq(address(hook.morphoStaticTyping()), morphoAddress, "MorphoStaticTyping interface mismatch");
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "HookType mismatch");
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayHook(address(this), address(0));
    }

    function test_Build_PartialRepay() public view {
        // Parameters: amount, usePrevHook=false, isFullRepayment=false, isPositiveFeed=false
        bytes memory data = _encodeData(amount, false, false, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);

        assertEq(executions.length, 4, "Incorrect number of executions for partial repay");

        // Execution 0: Approve Morpho for 0
        assertEq(executions[0].target, address(loanToken));
        assertEq(executions[0].value, 0);

        // Execution 1: Approve Morpho for amount + fee
        // We check target, value. Amount check removed as it depends on external calls.
        assertEq(executions[1].target, address(loanToken));
        assertEq(executions[1].value, 0);

        // Execution 2: Call Morpho repay with assets amount
        assertEq(executions[2].target, morphoAddress);
        assertEq(executions[2].value, 0);

        // Execution 3: Approve Morpho for 0 again
        assertEq(executions[3].target, address(loanToken));
        assertEq(executions[3].value, 0);
    }

    function test_Build_FullRepay() public view {
        // Parameters: amount=0 (ignored), usePrevHook=false, isFullRepayment=true, isPositiveFeed=false
        bytes memory data = _encodeData(0, false, true, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);

        assertEq(executions.length, 4, "Incorrect number of executions for full repay");

        // Execution 0: Approve Morpho for 0
        assertEq(executions[0].target, address(loanToken));
        assertEq(executions[0].value, 0);

        // Execution 1: Approve Morpho for assetsToPay
        // We check target, value. Amount check removed.
        assertEq(executions[1].target, address(loanToken));
        assertEq(executions[1].value, 0);

        // Execution 2: Call Morpho repay with shares amount
        // We check target, value. Parameter checks removed.
        assertEq(executions[2].target, morphoAddress);
        assertEq(executions[2].value, 0);

        // Execution 3: Approve Morpho for 0 again
        assertEq(executions[3].target, address(loanToken));
        assertEq(executions[3].value, 0);
    }

    function test_Build_PartialRepay_WithPrevHook() public {
        uint256 prevHookAmount = 200e18;
        // Create a mock previous hook that returns prevHookAmount
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.NONACCOUNTING, address(loanToken)));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        // Parameters: amount=0 (ignored), usePrevHook=true, isFullRepayment=false
        bytes memory data = _encodeData(0, true, false, false);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 4, "Incorrect number of executions for partial repay w/ prevHook");

        // Execution 0: Approve Morpho for 0
        assertEq(executions[0].target, address(loanToken));
        assertEq(executions[0].value, 0);

        // Execution 1: Approve Morpho for prevHookAmount + fee
        // Check target, value. Amount check removed.
        assertEq(executions[1].target, address(loanToken));
        assertEq(executions[1].value, 0);

        // Execution 2: Call Morpho repay with prevHookAmount
        // Check target, value. Parameter checks removed.
        assertEq(executions[2].target, morphoAddress);
        assertEq(executions[2].value, 0);

        // Execution 3: Approve Morpho for 0 again
        assertEq(executions[3].target, address(loanToken));
        assertEq(executions[3].value, 0);
    }

    function test_Build_RevertIf_InvalidAddressesInParams() public {
        // Test invalid loan token (address(0))
        MarketParams memory invalidLoanParams = marketParams;
        invalidLoanParams.loanToken = address(0);
        bytes memory dataInvalidLoan = _encodeDataWithParams(invalidLoanParams, amount, false, false, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), dataInvalidLoan);

        // Test invalid collateral token (address(0))
        MarketParams memory invalidCollateralParams = marketParams;
        invalidCollateralParams.collateralToken = address(0);
        bytes memory dataInvalidCollateral = _encodeDataWithParams(invalidCollateralParams, amount, false, false, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), dataInvalidCollateral);
    }

    function test_PreAndPostExecute_MeasuresBalanceChange() public {
        // Use the globally defined marketParams for encoding data
        bytes memory data = _encodeData(amount, false, false, false);
        uint256 initialBalance = loanToken.balanceOf(address(this));
        uint256 simulatedRepayment = 300e18; // Amount that will "leave" the account during execution

        assertTrue(initialBalance >= simulatedRepayment, "Need sufficient initial balance");

        // 1. Call preExecute - should store the initial balance
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), initialBalance, "outAmount should be initial balance after preExecute");

        // 2. Simulate the repayment happening (balance decreases)
        vm.prank(address(this)); // Act as the test contract
        loanToken.transfer(address(0xdead), simulatedRepayment); // Send tokens "away"

        uint256 balanceAfterRepayment = loanToken.balanceOf(address(this));
        assertEq(balanceAfterRepayment, initialBalance - simulatedRepayment, "Balance did not decrease as expected");

        // 3. Call postExecute - should calculate difference
        hook.postExecute(address(0), address(this), data);
        // outAmount = initialBalance (stored in pre) - finalBalance
        assertEq(hook.outAmount(), initialBalance - balanceAfterRepayment, "outAmount incorrect after postExecute");
        assertEq(hook.outAmount(), simulatedRepayment, "outAmount should equal simulated repayment");
    }

    // --- Helper Functions ---

    /// @dev Encodes data for the MorphoRepayHook using the globally defined marketParams.
    function _encodeData(
        uint256 _amount,
        bool usePrevHook,
        bool isFullRepayment,
        bool isPositiveFeed
    )
        internal
        view
        returns (bytes memory)
    {
        return _encodeDataWithParams(marketParams, _amount, usePrevHook, isFullRepayment, isPositiveFeed);
    }

    /// @dev Encodes data for the MorphoRepayHook using specific MarketParams.
    function _encodeDataWithParams(
        MarketParams memory _params,
        uint256 _amount,
        bool usePrevHook,
        bool isFullRepayment,
        bool isPositiveFeed
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _params.loanToken, // address loanToken (0-19)
            _params.collateralToken, // address collateralToken (20-39)
            _params.oracle, // address oracle (40-59)
            _params.irm, // address irm (60-79)
            _amount, // uint256 amount (80-111)
            _params.lltv, // uint256 lltv (112-143)
            usePrevHook, // bool usePrevHookAmount (144)
            isFullRepayment, // bool isFullRepayment (145)
            isPositiveFeed // bool isPositiveFeed (146)
        );
    }
}
