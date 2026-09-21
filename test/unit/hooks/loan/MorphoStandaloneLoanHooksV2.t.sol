// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { morphoMarketKey } from "../../../utils/MorphoMarketKey.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseMorphoLoanHookV2 } from "../../../../src/hooks/loan/morpho/BaseMorphoLoanHookV2.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookLoans,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoBase, MarketParams, Market, Position } from "../../../../src/vendor/morpho/IMorpho.sol";

// Local mocks shared with the composite-hook suite
import { MockMorpho, MockIRM, MockPrevHook } from "./MorphoLoanHooksV2.t.sol";

// Hooks
import { MorphoSupplyHookV2 } from "../../../../src/hooks/loan/morpho/MorphoSupplyHookV2.sol";
import { MorphoBorrowHookV2 } from "../../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { MorphoWithdrawCollateralHookV2 } from "../../../../src/hooks/loan/morpho/MorphoWithdrawCollateralHookV2.sol";

/// @dev Unit suite for the standalone Morpho V2 borrower hooks (PLEDGE / BORROW / RELEASE).
///      Mirrors the structure and conventions of MorphoLoanHooksV2.t.sol.
contract MorphoStandaloneLoanHooksV2Test is Helpers {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    MorphoSupplyHookV2 public pledgeHook;
    MorphoBorrowHookV2 public borrowHook;
    MorphoWithdrawCollateralHookV2 public releaseHook;

    MockMorpho public mockMorpho;
    MockIRM public mockIRM;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;

    MarketParams public marketParams;
    Id public marketId;

    address public loanToken;
    address public collateralToken;
    address public oracle;
    address public irm;

    uint256 public lltv;
    uint256 public amount1;

    uint128 public constant POSITION_BORROW_SHARES = 10e18;
    uint128 public constant POSITION_COLLATERAL = 5e18;

    address public constant BURN = address(0xdead);

    function setUp() public {
        mockMorpho = new MockMorpho();
        mockIRM = new MockIRM();
        irm = address(mockIRM);
        // The oracle is market identity only in V2 hooks (never priced), a plain address suffices
        oracle = address(0xB0b0);

        pledgeHook = new MorphoSupplyHookV2(address(mockMorpho));
        borrowHook = new MorphoBorrowHookV2(address(mockMorpho));
        releaseHook = new MorphoWithdrawCollateralHookV2(address(mockMorpho));

        mockLoanToken = new MockERC20("Loan Token", "LOAN", 18);
        loanToken = address(mockLoanToken);
        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);

        lltv = 860_000_000_000_000_000;
        amount1 = 1e18;

        marketParams = MarketParams({
            loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv
        });
        marketId = marketParams.id();

        mockMorpho.setMarket(
            Market({
                totalSupplyAssets: 100e18,
                totalSupplyShares: 100e18,
                totalBorrowAssets: 80e18,
                totalBorrowShares: 80e18,
                lastUpdate: uint128(block.timestamp),
                fee: 0
            })
        );

        mockMorpho.setPosition(
            marketId,
            address(this),
            Position({ supplyShares: 0, borrowShares: POSITION_BORROW_SHARES, collateral: POSITION_COLLATERAL })
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ENCODE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 230-byte Morpho V2 hook data layout
    function _encode(
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 amount1_,
        uint256 amount2_,
        bool usePrev_,
        uint256 lltv_
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID,
            morphoMarketKey(loanToken_, collateralToken_, oracle_, irm_, lltv_),
            loanToken_,
            collateralToken_,
            oracle_,
            irm_,
            amount1_,
            amount2_,
            usePrev_,
            lltv_,
            uint8(0)
        );
    }

    function _data(uint256 amount1_, bool usePrev_) internal view returns (bytes memory) {
        return _encode(loanToken, collateralToken, oracle, irm, amount1_, 0, usePrev_, lltv);
    }

    function _hooks() internal view returns (BaseLoanHookV2[3] memory hooks) {
        hooks[0] = BaseLoanHookV2(address(pledgeHook));
        hooks[1] = BaseLoanHookV2(address(borrowHook));
        hooks[2] = BaseLoanHookV2(address(releaseHook));
    }

    /*//////////////////////////////////////////////////////////////
                            1. CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Constructors() public view {
        assertEq(pledgeHook.morpho(), address(mockMorpho));
        assertEq(uint256(pledgeHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(pledgeHook.subtype(), HookSubTypes.LOAN);

        assertEq(borrowHook.morpho(), address(mockMorpho));
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(borrowHook.subtype(), HookSubTypes.LOAN);

        assertEq(releaseHook.morpho(), address(mockMorpho));
        assertEq(uint256(releaseHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(releaseHook.subtype(), HookSubTypes.LOAN);
    }

    function test_Standalone_Constructors_RevertIf_ZeroMorpho() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoSupplyHookV2(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoBorrowHookV2(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoWithdrawCollateralHookV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              2. ERC-165
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_SupportsInterface() public view {
        bytes4 loansId = type(ISuperHookLoans).interfaceId;
        bytes4 inflowOutflowId = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflowId = type(ISuperHookOutflow).interfaceId;

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            // ISuperHookLoans is implemented but deliberately not advertised via ERC-165
            assertFalse(hooks[i].supportsInterface(loansId));
            assertTrue(hooks[i].supportsInterface(inflowOutflowId));
            assertTrue(hooks[i].supportsInterface(outflowId));
        }
    }

    /*//////////////////////////////////////////////////////////////
                        3. STRICT DECODE SURFACE
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Build_RevertIf_WrongLength() public {
        bytes memory good = _data(amount1, false);
        bytes memory shortData = new bytes(229);
        bytes memory longData = bytes.concat(good, hex"00");

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), shortData);
            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), longData);

            vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
            hooks[i].decodeUsePrevHookAmount(shortData);
        }
    }

    function test_Standalone_Build_RevertIf_NonCanonicalBool() public {
        bytes memory data = _data(amount1, false);
        data[196] = 0x02;

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);

            vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
            hooks[i].decodeUsePrevHookAmount(data);
        }
    }

    function test_Standalone_Build_RevertIf_SecondaryWordNotZero() public {
        bytes memory data = _encode(loanToken, collateralToken, oracle, irm, amount1, 1, false, lltv);

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
        }
    }

    function test_Standalone_Build_RevertIf_ReservedByteNotZero() public {
        bytes memory data = _data(amount1, false);
        data[229] = 0x01;

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
        }
    }

    function test_Standalone_Build_RevertIf_ZeroMarketAddress() public {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i]))
                .build(
                    address(0),
                    address(this),
                    _encode(address(0), collateralToken, oracle, irm, amount1, 0, false, lltv)
                );
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i]))
                .build(address(0), address(this), _encode(loanToken, address(0), oracle, irm, amount1, 0, false, lltv));
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i]))
                .build(
                    address(0),
                    address(this),
                    _encode(loanToken, collateralToken, address(0), irm, amount1, 0, false, lltv)
                );
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i]))
                .build(
                    address(0),
                    address(this),
                    _encode(loanToken, collateralToken, oracle, address(0), amount1, 0, false, lltv)
                );
        }
    }

    /// @dev Encodes the canonical standalone layout with an explicit header yield source (offset 32)
    function _encodeHeaderYieldSource(address yieldSource_) internal view returns (bytes memory) {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID,
            yieldSource_,
            loanToken,
            collateralToken,
            oracle,
            irm,
            amount1,
            uint256(0),
            false,
            lltv,
            uint8(0)
        );
    }

    function test_Standalone_Build_RevertIf_ZeroYieldSource() public {
        bytes memory data = _encodeHeaderYieldSource(address(0));
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).preExecute(address(0), address(this), data);
        }
    }

    function test_Standalone_Build_RevertIf_YieldSourceMismatch() public {
        address otherMorpho = address(new MockMorpho());
        bytes memory data = _encodeHeaderYieldSource(otherMorpho);
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
            vm.expectRevert(BaseMorphoLoanHookV2.MARKET_KEY_MISMATCH.selector);
            ISuperHook(address(hooks[i])).preExecute(address(0), address(this), data);
        }
    }

    function test_Standalone_Build_RevertIf_IdenticalTokens() public {
        bytes memory data = _encode(loanToken, loanToken, oracle, irm, amount1, 0, false, lltv);

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          4. AMOUNT RULES
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Build_RevertIf_ZeroAmount() public {
        bytes memory data = _data(0, false);

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
        }
    }

    function test_PledgeBorrow_Build_RevertIf_MaxAmount() public {
        // max is never a valid exact primary for pledge/borrow (no sentinel semantics)
        bytes memory data = _data(type(uint256).max, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(pledgeHook)).build(address(0), address(this), data);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(borrowHook)).build(address(0), address(this), data);
    }

    function test_Release_Build_MaxSentinel_ResolvesToPostedCollateral() public view {
        Execution[] memory executions =
            ISuperHook(address(releaseHook)).build(address(0), address(this), _data(type(uint256).max, false));

        assertEq(executions.length, 3); // preExecute + withdrawCollateral + postExecute
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IMorphoBase.withdrawCollateral,
                (marketParams, uint256(POSITION_COLLATERAL), address(this), address(this))
            )
        );
    }

    function test_Release_Build_MaxSentinel_RevertIf_ZeroPostedCollateral() public {
        mockMorpho.setPosition(marketId, address(this), Position({ supplyShares: 0, borrowShares: 0, collateral: 0 }));

        // reverts at build, before any Morpho execution exists
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(releaseHook)).build(address(0), address(this), _data(type(uint256).max, false));
    }

    /*//////////////////////////////////////////////////////////////
                          5. PREV-HOOK PIPE
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Build_RevertIf_UsePrevWithZeroPrevHook() public {
        bytes memory data = _data(amount1, true);

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), data);
        }
    }

    function test_Standalone_Build_RevertIf_PrevTokenMismatch() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutAmount(amount1);
        bytes memory data = _data(amount1, true);

        // pledge and release expect the collateral token — feed the loan token
        prevHook.setOutToken(loanToken);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        ISuperHook(address(pledgeHook)).build(address(prevHook), address(this), data);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        ISuperHook(address(releaseHook)).build(address(prevHook), address(this), data);

        // borrow expects the loan token — feed the collateral token
        prevHook.setOutToken(collateralToken);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        ISuperHook(address(borrowHook)).build(address(prevHook), address(this), data);
    }

    function test_Standalone_Build_RevertIf_ZeroPrevAmount() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutAmount(0);
        bytes memory data = _data(amount1, true);

        prevHook.setOutToken(collateralToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(pledgeHook)).build(address(prevHook), address(this), data);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(releaseHook)).build(address(prevHook), address(this), data);

        prevHook.setOutToken(loanToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        ISuperHook(address(borrowHook)).build(address(prevHook), address(this), data);
    }

    function test_Pledge_Build_UsePrev_SubstitutesPrimaryAndIgnoresWord() public {
        uint256 prevAmount = 7e18;
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(prevAmount);

        // calldata word is garbage on purpose — it must be ignored under usePrev
        Execution[] memory executions =
            ISuperHook(address(pledgeHook)).build(address(prevHook), address(this), _data(123, true));

        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), prevAmount)));
        assertEq(
            executions[3].callData,
            abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, prevAmount, address(this), ""))
        );
    }

    function test_Borrow_Build_UsePrev_SubstitutesPrimary() public {
        uint256 prevAmount = 3e18;
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(loanToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions =
            ISuperHook(address(borrowHook)).build(address(prevHook), address(this), _data(123, true));

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoBase.borrow, (marketParams, prevAmount, 0, address(this), address(this)))
        );
    }

    function test_Release_Build_UsePrev_IgnoresMaxWord() public {
        // the max sentinel in the calldata word is unreachable under usePrev: the word is ignored
        uint256 prevAmount = 2e18;
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions =
            ISuperHook(address(releaseHook)).build(address(prevHook), address(this), _data(type(uint256).max, true));

        assertEq(executions.length, 3);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoBase.withdrawCollateral, (marketParams, prevAmount, address(this), address(this)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                          6. BUILD SHAPES
    //////////////////////////////////////////////////////////////*/

    function test_Pledge_Build_Shape() public view {
        Execution[] memory executions =
            ISuperHook(address(pledgeHook)).build(address(0), address(this), _data(amount1, false));

        // preExecute + approve0 + approve(amount) + supplyCollateral + approve0 + postExecute
        assertEq(executions.length, 6);
        assertEq(executions[1].target, collateralToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), amount1)));
        assertEq(executions[3].target, address(mockMorpho));
        assertEq(
            executions[3].callData,
            abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, amount1, address(this), ""))
        );
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));
    }

    function test_Borrow_Build_Shape() public view {
        Execution[] memory executions =
            ISuperHook(address(borrowHook)).build(address(0), address(this), _data(amount1, false));

        // preExecute + borrow + postExecute; exact assets, zero shares, account as onBehalf AND receiver
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoBase.borrow, (marketParams, amount1, 0, address(this), address(this)))
        );
    }

    function test_Release_Build_Shape_ExactAmount() public view {
        Execution[] memory executions =
            ISuperHook(address(releaseHook)).build(address(0), address(this), _data(amount1, false));

        // preExecute + withdrawCollateral + postExecute; no repay leg anywhere
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoBase.withdrawCollateral, (marketParams, amount1, address(this), address(this)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        7. SIZING INTERFACES
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_DecodeAmounts_SingleSlot() public view {
        bytes memory data = _data(amount1, false);

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            uint256[] memory amounts = ISuperHookInflowOutflow(address(hooks[i])).decodeAmounts(data);
            assertEq(amounts.length, 1);
            assertEq(amounts[0], amount1);
        }
    }

    function test_Standalone_AmountRoles() public view {
        bytes memory data = _data(amount1, false);

        // pledge consumes: [IN/TOKEN] (inherited default)
        ISuperHookInflowOutflow.AmountMeta[] memory pledgeMeta =
            ISuperHookInflowOutflow(address(pledgeHook)).amountRoles(data);
        assertEq(pledgeMeta.length, 1);
        assertEq(uint256(pledgeMeta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(pledgeMeta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        // borrow and release produce: [OUT/TOKEN]
        ISuperHookInflowOutflow.AmountMeta[] memory borrowMeta =
            ISuperHookInflowOutflow(address(borrowHook)).amountRoles(data);
        assertEq(borrowMeta.length, 1);
        assertEq(uint256(borrowMeta[0].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(borrowMeta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        ISuperHookInflowOutflow.AmountMeta[] memory releaseMeta =
            ISuperHookInflowOutflow(address(releaseHook)).amountRoles(data);
        assertEq(releaseMeta.length, 1);
        assertEq(uint256(releaseMeta[0].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(releaseMeta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_Standalone_ReplaceCalldataAmounts_SingleSlot() public {
        bytes memory data = _data(amount1, false);
        uint256 newAmount = 9e18;

        uint256[] memory one = new uint256[](1);
        one[0] = newAmount;
        uint256[] memory two = new uint256[](2);
        uint256[] memory zero = new uint256[](0);

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            ISuperHookOutflow hook = ISuperHookOutflow(address(hooks[i]));

            bytes memory replaced = hook.replaceCalldataAmounts(data, one);
            uint256[] memory decoded = ISuperHookInflowOutflow(address(hooks[i])).decodeAmounts(replaced);
            assertEq(decoded[0], newAmount);
            // the replaced payload still decodes strictly (amount2 / reserved byte untouched)
            ISuperHook(address(hooks[i])).build(address(0), address(this), replaced);

            vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
            hook.replaceCalldataAmounts(data, two);

            vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
            hook.replaceCalldataAmounts(data, zero);
        }
    }

    /// @dev The sizing API must reject the SAME malformed V2 payloads that build()/inspect()
    ///      reject — off-chain sizing can never read or transform a payload that would later fail
    ///      execution (mirrors the strict decode surface for build).
    function test_Standalone_SizingApi_RejectsMalformedPayloads() public {
        bytes memory good = _data(amount1, false);
        uint256[] memory one = new uint256[](1);
        one[0] = 9e18;

        // (malformed data, expected revert selector)
        bytes[] memory bad = new bytes[](5);
        bytes4[] memory sel = new bytes4[](5);
        bad[0] = new bytes(229);
        sel[0] = BaseLoanHookV2.INVALID_DATA_LENGTH.selector;
        bad[1] = bytes.concat(good, hex"00");
        sel[1] = BaseLoanHookV2.INVALID_DATA_LENGTH.selector;
        bad[2] = _encode(loanToken, collateralToken, oracle, irm, amount1, 1, false, lltv); // nonzero secondary
        sel[2] = BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector;
        bad[3] = _data(amount1, false);
        bad[3][196] = 0x02; // noncanonical bool
        sel[3] = BaseLoanHookV2.INVALID_BOOL_VALUE.selector;
        bad[4] = _data(amount1, false);
        bad[4][229] = 0x01; // nonzero reserved byte
        sel[4] = BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector;

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            for (uint256 j; j < bad.length; ++j) {
                vm.expectRevert(sel[j]);
                ISuperHookInflowOutflow(address(hooks[i])).decodeAmounts(bad[j]);

                vm.expectRevert(sel[j]);
                ISuperHookOutflow(address(hooks[i])).replaceCalldataAmounts(bad[j], one);
            }
        }
    }

    function test_Standalone_DecodeUsePrevHookAmount() public view {
        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            assertFalse(hooks[i].decodeUsePrevHookAmount(_data(amount1, false)));
            assertTrue(hooks[i].decodeUsePrevHookAmount(_data(amount1, true)));
        }
    }

    /*//////////////////////////////////////////////////////////////
                          8. INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Standalone_Inspect_MarketIdentityOnly() public view {
        bytes memory expected = abi.encodePacked(
            morphoMarketKey(loanToken, collateralToken, oracle, irm, lltv),
            loanToken,
            collateralToken,
            oracle,
            irm,
            lltv
        );

        BaseLoanHookV2[3] memory hooks = _hooks();
        for (uint256 i; i < hooks.length; ++i) {
            // exact payload
            assertEq(
                keccak256(ISuperHookInspector(address(hooks[i])).inspect(_data(amount1, false))), keccak256(expected)
            );
            // amount/usePrev variations leave the payload unchanged
            assertEq(
                keccak256(ISuperHookInspector(address(hooks[i])).inspect(_data(amount1 + 1e18, true))),
                keccak256(expected)
            );
            // every market-identity field variation changes the payload
            assertNotEq(
                keccak256(
                    ISuperHookInspector(address(hooks[i]))
                        .inspect(_encode(address(0xAAAA), collateralToken, oracle, irm, amount1, 0, false, lltv))
                ),
                keccak256(expected)
            );
            assertNotEq(
                keccak256(
                    ISuperHookInspector(address(hooks[i]))
                        .inspect(_encode(loanToken, address(0xBBBB), oracle, irm, amount1, 0, false, lltv))
                ),
                keccak256(expected)
            );
            assertNotEq(
                keccak256(
                    ISuperHookInspector(address(hooks[i]))
                        .inspect(_encode(loanToken, collateralToken, address(0xCCCC), irm, amount1, 0, false, lltv))
                ),
                keccak256(expected)
            );
            assertNotEq(
                keccak256(
                    ISuperHookInspector(address(hooks[i]))
                        .inspect(_encode(loanToken, collateralToken, oracle, address(0xDDDD), amount1, 0, false, lltv))
                ),
                keccak256(expected)
            );
            assertNotEq(
                keccak256(
                    ISuperHookInspector(address(hooks[i]))
                        .inspect(_encode(loanToken, collateralToken, oracle, irm, amount1, 0, false, lltv + 1))
                ),
                keccak256(expected)
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                        9. SETTLE ROUND-TRIPS
    //////////////////////////////////////////////////////////////*/

    function test_Pledge_SettleRoundTrip() public {
        bytes memory data = _data(amount1, false);
        mockCollateralToken.mint(address(this), amount1);

        pledgeHook.preExecute(address(0), address(this), data);

        // Simulate the provider leg: collateral leaves the wallet
        mockCollateralToken.transfer(BURN, amount1);

        pledgeHook.postExecute(address(0), address(this), data);

        // Terminal pledge hook publishes outAmount = 0 (spend is not a product); outToken kept
        assertEq(pledgeHook.getOutAmount(address(this)), 0);
        assertEq(pledgeHook.getOutToken(address(this)), collateralToken);
    }

    function test_Pledge_Settle_RevertIf_DeltaMismatch() public {
        bytes memory data = _data(amount1, false);
        mockCollateralToken.mint(address(this), amount1);

        pledgeHook.preExecute(address(0), address(this), data);

        // Spend one wei less collateral than the resolved expectation
        mockCollateralToken.transfer(BURN, amount1 - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        pledgeHook.postExecute(address(0), address(this), data);
    }

    function test_Pledge_Settle_RevertIf_NegativeDelta() public {
        bytes memory data = _data(amount1, false);

        pledgeHook.preExecute(address(0), address(this), data);

        // Balance moves the wrong way: collateral increases instead of being spent
        mockCollateralToken.mint(address(this), 1);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        pledgeHook.postExecute(address(0), address(this), data);
    }

    function test_Borrow_SettleRoundTrip() public {
        bytes memory data = _data(amount1, false);

        borrowHook.preExecute(address(0), address(this), data);

        // Simulate the provider leg: borrowed loan tokens arrive
        mockLoanToken.mint(address(this), amount1);

        borrowHook.postExecute(address(0), address(this), data);

        assertEq(borrowHook.getOutAmount(address(this)), amount1);
        assertEq(borrowHook.getOutToken(address(this)), loanToken);
    }

    function test_Borrow_Settle_RevertIf_ShortDelivery() public {
        bytes memory data = _data(amount1, false);

        borrowHook.preExecute(address(0), address(this), data);

        mockLoanToken.mint(address(this), amount1 - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        borrowHook.postExecute(address(0), address(this), data);
    }

    function test_Release_SettleRoundTrip_ExactAmount() public {
        bytes memory data = _data(amount1, false);

        releaseHook.preExecute(address(0), address(this), data);

        // Simulate the provider leg: released collateral arrives
        mockCollateralToken.mint(address(this), amount1);

        releaseHook.postExecute(address(0), address(this), data);

        assertEq(releaseHook.getOutAmount(address(this)), amount1);
        assertEq(releaseHook.getOutToken(address(this)), collateralToken);
    }

    function test_Release_SettleRoundTrip_MaxSentinel() public {
        bytes memory data = _data(type(uint256).max, false);

        releaseHook.preExecute(address(0), address(this), data);

        // The sentinel resolved to the full posted collateral
        mockCollateralToken.mint(address(this), uint256(POSITION_COLLATERAL));

        releaseHook.postExecute(address(0), address(this), data);

        assertEq(releaseHook.getOutAmount(address(this)), uint256(POSITION_COLLATERAL));
        assertEq(releaseHook.getOutToken(address(this)), collateralToken);
    }

    function test_Release_Settle_RevertIf_ShortDelivery() public {
        bytes memory data = _data(amount1, false);

        releaseHook.preExecute(address(0), address(this), data);

        mockCollateralToken.mint(address(this), amount1 - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        releaseHook.postExecute(address(0), address(this), data);
    }
}
