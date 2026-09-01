// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookLoans,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../../src/vendor/morpho/MorphoBalancesLib.sol";
import {
    Id,
    IMorpho,
    IMorphoBase,
    MarketParams,
    Market,
    Position
} from "../../../../src/vendor/morpho/IMorpho.sol";

// Hooks
import { MorphoSupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";

/*//////////////////////////////////////////////////////////////
                            LOCAL MOCKS
//////////////////////////////////////////////////////////////*/

contract MockMorpho {
    Market internal marketData;

    mapping(Id => mapping(address => Position)) internal positions;

    function setMarket(Market memory market_) external {
        marketData = market_;
    }

    function setPosition(Id id, address account, Position memory positionParams) external {
        positions[id][account] = positionParams;
    }

    function market(Id) external view returns (Market memory) {
        return marketData;
    }

    // NOTE: returns a struct, which ABI-decodes as the (uint256, uint128, uint128)
    // tuple that IMorphoStaticTyping.position declares and the hooks read
    function position(Id id, address account) external view returns (Position memory) {
        return positions[id][account];
    }

    function accrueInterest(MarketParams memory) external { }
}

contract MockIRM {
    function borrowRateView(MarketParams memory, Market memory) external pure returns (uint256) {
        return 10e18;
    }
}

contract MockPrevHook {
    uint256 public outAmount;
    address public outToken;

    function setOutAmount(uint256 _outAmount) external {
        outAmount = _outAmount;
    }

    function setOutToken(address _outToken) external {
        outToken = _outToken;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }

    function getOutToken(address) external view returns (address) {
        return outToken;
    }
}

contract MockNonLoanHook is BaseHook {
    constructor() BaseHook(ISuperHook.HookType.NONACCOUNTING, keccak256("MockNonLoan")) { }

    function name() external pure override returns (string memory) {
        return "MockNonLoanHook";
    }

    function description() external pure override returns (string memory) {
        return "Minimal non-loan hook used to prove ISuperHookLoans is not advertised by default";
    }

    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](0);
    }
}

contract MorphoLoanHooksV2Test is Helpers {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    MorphoSupplyAndBorrowHookV2 public openHook;
    MorphoRepayHookV2 public repayHook;
    MorphoRepayAndWithdrawHookV2 public closeHook;

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
    uint256 public amount2;

    uint128 public constant POSITION_BORROW_SHARES = 10e18;
    uint128 public constant POSITION_COLLATERAL = 5e18;

    address public constant BURN = address(0xdead);

    function setUp() public {
        mockMorpho = new MockMorpho();
        mockIRM = new MockIRM();
        irm = address(mockIRM);
        // The oracle is market identity only in V2 hooks (never priced), a plain address suffices
        oracle = address(0xB0b0);

        openHook = new MorphoSupplyAndBorrowHookV2(address(mockMorpho));
        repayHook = new MorphoRepayHookV2(address(mockMorpho));
        closeHook = new MorphoRepayAndWithdrawHookV2(address(mockMorpho));

        mockLoanToken = new MockERC20("Loan Token", "LOAN", 18);
        loanToken = address(mockLoanToken);
        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);

        lltv = 860_000_000_000_000_000;
        amount1 = 1e18;
        amount2 = 2e18;

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
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
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            address(0),
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

    function _data(uint256 amount1_, uint256 amount2_, bool usePrev_) internal view returns (bytes memory) {
        return _encode(loanToken, collateralToken, oracle, irm, amount1_, amount2_, usePrev_, lltv);
    }

    /*//////////////////////////////////////////////////////////////
                            1. CONSTRUCTORS
    //////////////////////////////////////////////////////////////*/

    function test_Constructors() public view {
        assertEq(openHook.morpho(), address(mockMorpho));
        assertEq(uint256(openHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(openHook.subtype(), HookSubTypes.LOAN);

        assertEq(repayHook.morpho(), address(mockMorpho));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(repayHook.subtype(), HookSubTypes.LOAN_REPAY);

        assertEq(closeHook.morpho(), address(mockMorpho));
        assertEq(uint256(closeHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(closeHook.subtype(), HookSubTypes.LOAN_REPAY);
    }

    function test_Constructors_RevertIf_ZeroMorpho() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoSupplyAndBorrowHookV2(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayHookV2(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayAndWithdrawHookV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              2. ERC-165
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_LoanHooks() public view {
        bytes4 loansId = type(ISuperHookLoans).interfaceId;
        bytes4 inflowOutflowId = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflowId = type(ISuperHookOutflow).interfaceId;

        assertTrue(openHook.supportsInterface(loansId));
        assertTrue(repayHook.supportsInterface(loansId));
        assertTrue(closeHook.supportsInterface(loansId));

        assertTrue(openHook.supportsInterface(inflowOutflowId));
        assertTrue(repayHook.supportsInterface(inflowOutflowId));
        assertTrue(closeHook.supportsInterface(inflowOutflowId));

        assertTrue(openHook.supportsInterface(outflowId));
        assertTrue(repayHook.supportsInterface(outflowId));
        assertTrue(closeHook.supportsInterface(outflowId));
    }

    function test_SupportsInterface_NonLoanHook_ReturnsFalse() public {
        MockNonLoanHook nonLoanHook = new MockNonLoanHook();
        assertFalse(nonLoanHook.supportsInterface(type(ISuperHookLoans).interfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                        3. STRICT DECODE VIA BUILD
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_InvalidDataLength() public {
        // 229 bytes: everything except the trailing reserved byte
        bytes memory shortData = abi.encodePacked(
            bytes32(0), address(0), loanToken, collateralToken, oracle, irm, amount1, amount2, false, lltv
        );
        assertEq(shortData.length, 229);

        // 231 bytes: valid layout + one extra byte
        bytes memory longData = abi.encodePacked(_data(amount1, amount2, false), uint8(0));
        assertEq(longData.length, 231);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), longData);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), longData);

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), shortData);
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), longData);
    }

    function test_Build_RevertIf_InvalidBoolValue() public {
        bytes memory data = _data(amount1, amount2, false);
        data[196] = 0x02;

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), data);

        bytes memory repayData = _data(amount1, 0, false);
        repayData[196] = 0x02;
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.build(address(0), address(this), repayData);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ReservedByteNotZero() public {
        bytes memory data = _data(amount1, amount2, false);
        data[229] = 0x01;

        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        openHook.build(address(0), address(this), data);

        bytes memory repayData = _data(amount1, 0, false);
        repayData[229] = 0x01;
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), repayData);

        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_ZeroMarketAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(
            address(0), address(this), _encode(address(0), collateralToken, oracle, irm, amount1, amount2, false, lltv)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(
            address(0), address(this), _encode(loanToken, address(0), oracle, irm, amount1, amount2, false, lltv)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(
            address(0), address(this), _encode(loanToken, collateralToken, address(0), irm, amount1, amount2, false, lltv)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(
            address(0),
            address(this),
            _encode(loanToken, collateralToken, oracle, address(0), amount1, amount2, false, lltv)
        );
    }

    function test_Build_RevertIf_IdenticalTokens() public {
        bytes memory data = _encode(loanToken, loanToken, oracle, irm, amount1, amount2, false, lltv);

        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        openHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        repayHook.build(address(0), address(this), data);

        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        closeHook.build(address(0), address(this), data);
    }

    function test_RepayHook_Build_RevertIf_NonzeroAmount2() public {
        // The amount2 word is reserved (must be zero) for the standalone repay hook
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(address(0), address(this), _data(amount1, 1, false));
    }

    /*//////////////////////////////////////////////////////////////
                          4. AMOUNT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_RevertIf_InvalidAmounts() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _data(0, amount2, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _data(amount1, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _data(type(uint256).max, amount2, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _data(amount1, type(uint256).max, false));
    }

    function test_RepayHook_Build_RevertIf_MaxWithPrev() public {
        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        repayHook.build(address(1), address(this), _data(type(uint256).max, 0, true));
    }

    function test_RepayHook_Build_RevertIf_ZeroAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _data(0, 0, false));
    }

    function test_CloseHook_Build_RevertIf_MaxWithPrev() public {
        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        closeHook.build(address(1), address(this), _data(type(uint256).max, amount2, true));
    }

    function test_CloseHook_Build_RevertIf_ZeroAmount1() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _data(0, amount2, false));
    }

    function test_CloseHook_Build_RevertIf_ZeroAmount2() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _data(amount1, 0, false));
    }

    /*//////////////////////////////////////////////////////////////
                            5. ZERO DEBT
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_RevertIf_NoOutstandingDebt() public {
        mockMorpho.setPosition(
            marketId, address(this), Position({ supplyShares: 0, borrowShares: 0, collateral: POSITION_COLLATERAL })
        );
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        repayHook.build(address(0), address(this), _data(amount1, 0, false));
    }

    function test_CloseHook_Build_RevertIf_NoOutstandingDebt() public {
        mockMorpho.setPosition(
            marketId, address(this), Position({ supplyShares: 0, borrowShares: 0, collateral: POSITION_COLLATERAL })
        );
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        closeHook.build(address(0), address(this), _data(amount1, amount2, false));
    }

    /*//////////////////////////////////////////////////////////////
                        6. PREVIOUS-HOOK PIPE
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build_RevertIf_PrevHookZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), _data(amount1, amount2, true));
    }

    function test_OpenHook_Build_RevertIf_PrevTokenMismatch() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(loanToken); // open pipes into the collateral slot
        prevHook.setOutAmount(1e18);

        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        openHook.build(address(prevHook), address(this), _data(amount1, amount2, true));
    }

    function test_OpenHook_Build_RevertIf_PrevAmountZero() public {
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(0);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prevHook), address(this), _data(amount1, amount2, true));
    }

    function test_OpenHook_BuildWithPrevHook() public {
        uint256 prevAmount = 7e17;
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(collateralToken);
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions = openHook.build(address(prevHook), address(this), _data(amount1, amount2, true));
        assertEq(executions.length, 7);

        // The collateral approval uses the previous hook's output, not the calldata amount1
        assertEq(executions[2].target, collateralToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), prevAmount)));

        // The supplied collateral leg follows the same resolved amount
        assertEq(
            executions[3].callData,
            abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, prevAmount, address(this), ""))
        );
    }

    function test_RepayHook_BuildWithPrevHook() public {
        uint256 prevAmount = 3e18;
        MockPrevHook prevHook = new MockPrevHook();
        prevHook.setOutToken(loanToken); // repay pipes into the loan-token slot
        prevHook.setOutAmount(prevAmount);

        Execution[] memory executions = repayHook.build(address(prevHook), address(this), _data(amount1, 0, true));
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), prevAmount)));
        assertEq(
            executions[3].callData, abi.encodeCall(IMorphoBase.repay, (marketParams, prevAmount, 0, address(this), ""))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        7. BUILD SHAPE (HAPPY PATHS)
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_Build() public view {
        bytes memory data = _data(amount1, amount2, false);
        Execution[] memory executions = openHook.build(address(0), address(this), data);

        // preExecute + approve0 + approve(amount1) + supplyCollateral + borrow + approve0 + postExecute
        assertEq(executions.length, 7);

        assertEq(executions[0].target, address(openHook));
        assertEq(executions[6].target, address(openHook));

        assertEq(executions[1].target, collateralToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));

        assertEq(executions[2].target, collateralToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), amount1)));

        // onBehalf == account and empty callback bytes
        assertEq(executions[3].target, address(mockMorpho));
        assertEq(
            executions[3].callData,
            abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, amount1, address(this), ""))
        );

        assertEq(executions[4].target, address(mockMorpho));
        assertEq(
            executions[4].callData,
            abi.encodeCall(IMorphoBase.borrow, (marketParams, amount2, 0, address(this), address(this)))
        );

        assertEq(executions[5].target, collateralToken);
        assertEq(executions[5].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));
    }

    function test_RepayHook_Build() public view {
        bytes memory data = _data(amount1, 0, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        // preExecute + approve0 + approve(amount1) + repay + approve0 + postExecute
        assertEq(executions.length, 6);

        assertEq(executions[0].target, address(repayHook));
        assertEq(executions[5].target, address(repayHook));

        assertEq(executions[1].target, loanToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));

        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), amount1)));

        // Exact repay: assets-denominated, onBehalf == account, empty callback bytes
        assertEq(executions[3].target, address(mockMorpho));
        assertEq(
            executions[3].callData, abi.encodeCall(IMorphoBase.repay, (marketParams, amount1, 0, address(this), ""))
        );

        assertEq(executions[4].target, loanToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));
    }

    function test_CloseHook_Build() public view {
        bytes memory data = _data(amount1, amount2, false);
        Execution[] memory executions = closeHook.build(address(0), address(this), data);

        // preExecute + approve0 + approve(amount1) + repay + approve0 + withdrawCollateral + postExecute
        assertEq(executions.length, 7);

        assertEq(executions[0].target, address(closeHook));
        assertEq(executions[6].target, address(closeHook));

        assertEq(executions[1].target, loanToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));

        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), amount1)));

        // Repay executes strictly before withdrawCollateral (index 3 < index 5)
        assertEq(executions[3].target, address(mockMorpho));
        assertEq(
            executions[3].callData, abi.encodeCall(IMorphoBase.repay, (marketParams, amount1, 0, address(this), ""))
        );

        assertEq(executions[4].target, loanToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), 0)));

        assertEq(executions[5].target, address(mockMorpho));
        assertEq(
            executions[5].callData,
            abi.encodeCall(IMorphoBase.withdrawCollateral, (marketParams, amount2, address(this), address(this)))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        8. FULL-REPAY SENTINEL
    //////////////////////////////////////////////////////////////*/

    function test_RepayHook_Build_FullRepay() public view {
        uint256 expectedAssets =
            MorphoBalancesLib.expectedBorrowAssets(IMorpho(address(mockMorpho)), marketParams, address(this));

        Execution[] memory executions =
            repayHook.build(address(0), address(this), _data(type(uint256).max, 0, false));
        assertEq(executions.length, 6);

        // Approval covers the accrued debt resolved via MorphoBalancesLib
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), expectedAssets)));

        // Full repay is shares-denominated with assets == 0
        assertEq(
            executions[3].callData,
            abi.encodeCall(
                IMorphoBase.repay, (marketParams, 0, uint256(POSITION_BORROW_SHARES), address(this), "")
            )
        );
    }

    function test_CloseHook_Build_FullRepayAndFullWithdraw() public view {
        uint256 expectedAssets =
            MorphoBalancesLib.expectedBorrowAssets(IMorpho(address(mockMorpho)), marketParams, address(this));

        Execution[] memory executions =
            closeHook.build(address(0), address(this), _data(type(uint256).max, type(uint256).max, false));
        assertEq(executions.length, 7);

        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(mockMorpho), expectedAssets)));
        assertEq(
            executions[3].callData,
            abi.encodeCall(
                IMorphoBase.repay, (marketParams, 0, uint256(POSITION_BORROW_SHARES), address(this), "")
            )
        );

        // The max sentinel on the withdraw leg resolves to the position's full collateral
        assertEq(
            executions[5].callData,
            abi.encodeCall(
                IMorphoBase.withdrawCollateral,
                (marketParams, uint256(POSITION_COLLATERAL), address(this), address(this))
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                    9. DECODE USE PREV HOOK AMOUNT
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_ReadsByte196() public view {
        bytes memory data = _data(amount1, amount2, false);
        assertFalse(openHook.decodeUsePrevHookAmount(data));
        assertFalse(repayHook.decodeUsePrevHookAmount(data));
        assertFalse(closeHook.decodeUsePrevHookAmount(data));

        // Flipping only byte 196 flips the decoded flag
        data[196] = 0x01;
        assertTrue(openHook.decodeUsePrevHookAmount(data));
        assertTrue(repayHook.decodeUsePrevHookAmount(data));
        assertTrue(closeHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                    SIZING INTERFACE (AMOUNT SLOTS)
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_DecodeAmountsAndRoles() public view {
        bytes memory data = _data(amount1, amount2, false);

        uint256[] memory amounts = openHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount1);
        assertEq(amounts[1], amount2);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = openHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint256(meta[1].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_RepayHook_DecodeAmountsAndRoles() public view {
        bytes memory data = _data(amount1, 0, false);

        // Inherited single-slot sizing interface
        uint256[] memory amounts = repayHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount1);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = repayHook.amountRoles(data);
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_CloseHook_DecodeAmountsAndRoles() public view {
        bytes memory data = _data(amount1, amount2, false);

        uint256[] memory amounts = closeHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], amount1);
        assertEq(amounts[1], amount2);

        ISuperHookInflowOutflow.AmountMeta[] memory meta = closeHook.amountRoles(data);
        assertEq(meta.length, 2);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[1].dir), uint256(ISuperHookInflowOutflow.Direction.OUT));
    }

    function test_OpenHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _data(amount1, amount2, false);

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 11e18;
        newAmounts[1] = 22e18;

        bytes memory replaced = openHook.replaceCalldataAmounts(data, newAmounts);
        uint256[] memory decoded = openHook.decodeAmounts(replaced);
        assertEq(decoded[0], 11e18);
        assertEq(decoded[1], 22e18);
    }

    function test_OpenHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _data(amount1, amount2, false);
        uint256[] memory oneAmount = new uint256[](1);
        oneAmount[0] = 11e18;

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        openHook.replaceCalldataAmounts(data, oneAmount);
    }

    function test_RepayHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _data(amount1, 0, false);
        uint256[] memory newAmounts = new uint256[](1);
        newAmounts[0] = 11e18;

        bytes memory replaced = repayHook.replaceCalldataAmounts(data, newAmounts);
        uint256[] memory decoded = repayHook.decodeAmounts(replaced);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 11e18);
    }

    function test_RepayHook_ReplaceCalldataAmounts_RevertIf_WrongLength() public {
        bytes memory data = _data(amount1, 0, false);
        uint256[] memory twoAmounts = new uint256[](2);
        twoAmounts[0] = 11e18;
        twoAmounts[1] = 22e18;

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        repayHook.replaceCalldataAmounts(data, twoAmounts);
    }

    function test_CloseHook_ReplaceCalldataAmounts() public {
        bytes memory data = _data(amount1, amount2, false);

        uint256[] memory newAmounts = new uint256[](2);
        newAmounts[0] = 11e18;
        newAmounts[1] = 22e18;

        bytes memory replaced = closeHook.replaceCalldataAmounts(data, newAmounts);
        uint256[] memory decoded = closeHook.decodeAmounts(replaced);
        assertEq(decoded[0], 11e18);
        assertEq(decoded[1], 22e18);

        uint256[] memory oneAmount = new uint256[](1);
        oneAmount[0] = 11e18;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        closeHook.replaceCalldataAmounts(data, oneAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              10. INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_MarketIdentityOnly() public view {
        bytes memory expected = abi.encodePacked(address(mockMorpho), loanToken, collateralToken, oracle, irm, lltv);

        assertEq(openHook.inspect(_data(amount1, amount2, false)), expected);
        assertEq(repayHook.inspect(_data(amount1, 0, false)), expected);
        assertEq(closeHook.inspect(_data(amount1, amount2, false)), expected);

        // Amount fields and usePrevHookAmount do not affect the inspector payload
        assertEq(openHook.inspect(_data(9e18, 8e18, true)), expected);

        // Every market-identity field affects the inspector payload
        address other = address(0xCAFE);
        assertNotEq(
            keccak256(openHook.inspect(_encode(other, collateralToken, oracle, irm, amount1, amount2, false, lltv))),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(openHook.inspect(_encode(loanToken, other, oracle, irm, amount1, amount2, false, lltv))),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(openHook.inspect(_encode(loanToken, collateralToken, other, irm, amount1, amount2, false, lltv))),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                openHook.inspect(_encode(loanToken, collateralToken, oracle, other, amount1, amount2, false, lltv))
            ),
            keccak256(expected)
        );
        assertNotEq(
            keccak256(
                openHook.inspect(_encode(loanToken, collateralToken, oracle, irm, amount1, amount2, false, lltv + 1))
            ),
            keccak256(expected)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        11. SETTLE ROUND-TRIPS
    //////////////////////////////////////////////////////////////*/

    function test_OpenHook_SettleRoundTrip() public {
        bytes memory data = _data(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        // Simulate the provider legs: collateral leaves the wallet, borrowed loan tokens arrive
        mockCollateralToken.transfer(BURN, amount1);
        mockLoanToken.mint(address(this), amount2);

        openHook.postExecute(address(0), address(this), data);

        assertEq(openHook.getOutAmount(address(this)), amount2);
        assertEq(openHook.getOutToken(address(this)), loanToken);
    }

    function test_OpenHook_Settle_RevertIf_CollateralDeltaMismatch() public {
        bytes memory data = _data(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        // Spend one wei less collateral than the resolved expectation
        mockCollateralToken.transfer(BURN, amount1 - 1);
        mockLoanToken.mint(address(this), amount2);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount1, amount1 - 1));
        openHook.postExecute(address(0), address(this), data);
    }

    function test_OpenHook_Settle_RevertIf_LoanDeltaMismatch() public {
        bytes memory data = _data(amount1, amount2, false);
        mockCollateralToken.mint(address(this), amount1);

        openHook.preExecute(address(0), address(this), data);

        mockCollateralToken.transfer(BURN, amount1);
        // Receive one wei less than the resolved borrow expectation
        mockLoanToken.mint(address(this), amount2 - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, amount2, amount2 - 1));
        openHook.postExecute(address(0), address(this), data);
    }

    function test_RepayHook_SettleRoundTrip() public {
        uint256 repayAmount = 4e18;
        bytes memory data = _data(repayAmount, 0, false);
        mockLoanToken.mint(address(this), 10e18);

        repayHook.preExecute(address(0), address(this), data);

        // Simulate the repay: exact loan-token spend
        mockLoanToken.transfer(BURN, repayAmount);

        repayHook.postExecute(address(0), address(this), data);

        // Terminal repay hook publishes outAmount = 0 (spend is not a product); outToken kept
        assertEq(repayHook.getOutAmount(address(this)), 0);
        assertEq(repayHook.getOutToken(address(this)), loanToken);
    }

    function test_RepayHook_SettleRoundTrip_FullRepay() public {
        bytes memory data = _data(type(uint256).max, 0, false);
        uint256 expectedAssets =
            MorphoBalancesLib.expectedBorrowAssets(IMorpho(address(mockMorpho)), marketParams, address(this));
        mockLoanToken.mint(address(this), expectedAssets + 1e18);

        repayHook.preExecute(address(0), address(this), data);

        mockLoanToken.transfer(BURN, expectedAssets);

        repayHook.postExecute(address(0), address(this), data);

        // Terminal repay hook publishes outAmount = 0 (spend is not a product); outToken kept
        assertEq(repayHook.getOutAmount(address(this)), 0);
        assertEq(repayHook.getOutToken(address(this)), loanToken);
    }

    function test_RepayHook_Settle_RevertIf_DeltaMismatch() public {
        uint256 repayAmount = 4e18;
        bytes memory data = _data(repayAmount, 0, false);
        mockLoanToken.mint(address(this), 10e18);

        repayHook.preExecute(address(0), address(this), data);

        mockLoanToken.transfer(BURN, repayAmount - 1);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, repayAmount, repayAmount - 1));
        repayHook.postExecute(address(0), address(this), data);
    }

    function test_CloseHook_SettleRoundTrip() public {
        uint256 repayAmount = 4e18;
        uint256 withdrawAmount = 3e18;
        bytes memory data = _data(repayAmount, withdrawAmount, false);
        mockLoanToken.mint(address(this), 10e18);

        closeHook.preExecute(address(0), address(this), data);

        // Simulate the provider legs: loan tokens spent repaying, collateral released
        mockLoanToken.transfer(BURN, repayAmount);
        mockCollateralToken.mint(address(this), withdrawAmount);

        closeHook.postExecute(address(0), address(this), data);

        assertEq(closeHook.getOutAmount(address(this)), withdrawAmount);
        assertEq(closeHook.getOutToken(address(this)), collateralToken);
    }

    function test_CloseHook_Settle_RevertIf_CollateralDeltaMismatch() public {
        uint256 repayAmount = 4e18;
        uint256 withdrawAmount = 3e18;
        bytes memory data = _data(repayAmount, withdrawAmount, false);
        mockLoanToken.mint(address(this), 10e18);

        closeHook.preExecute(address(0), address(this), data);

        mockLoanToken.transfer(BURN, repayAmount);
        // Receive one wei less collateral than the resolved expectation
        mockCollateralToken.mint(address(this), withdrawAmount - 1);

        vm.expectRevert(
            abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, withdrawAmount, withdrawAmount - 1)
        );
        closeHook.postExecute(address(0), address(this), data);
    }
}
