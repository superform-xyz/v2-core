// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

//external
import { console } from "forge-std/console.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook, ISuperHookInspector } from "../../../../src/interfaces/ISuperHook.sol";
import { SharesMathLib } from "../../../../src/vendor/morpho/SharesMathLib.sol";
import { Id, IMorphoStaticTyping, MarketParams, Market } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";

// Hooks
import { MorphoBorrowHook } from "../../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoRepayHook } from "../../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoWithdrawHook } from "../../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { MorphoSupplyHook } from "../../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoLendHook } from "../../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoBorrowHookV2 } from "../../../../src/hooks/loan/morpho/MorphoBorrowHookV2.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { ApproveERC20Hook } from "../../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { FeeSplittingHook } from "../../../../src/hooks/tokens/FeeSplittingHook.sol";
import {
    SwapAerodromeUniversalRouterHook
} from "../../../../src/hooks/swappers/aerodrome/SwapAerodromeUniversalRouterHook.sol";
import {
    BaseAerodromeUniversalRouterHook
} from "../../../../src/hooks/swappers/aerodrome/BaseAerodromeUniversalRouterHook.sol";
import { MockAerodromeUniversalRouter } from "../../../mocks/MockAerodromeUniversalRouter.sol";
import { ISuperHookSwap } from "../../../../src/interfaces/ISuperHookSwap.sol";
import { BaseMorphoLoanHook } from "../../../../src/hooks/loan/morpho/BaseMorphoLoanHook.sol";
import { BaseMorphoMoneyMarketHook } from "../../../../src/hooks/loan/morpho/BaseMorphoMoneyMarketHook.sol";
import { MorphoBlueMarketRegistry } from "../../../../src/accounting/oracles/MorphoBlueMarketRegistry.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
    }
}

contract MockZeroOracle is IOracle {
    function price() external pure returns (uint256) {
        return 0;
    }
}

contract MockMorpho {
    Market public marketData;

    struct Position {
        uint256 supplyShares;
        uint128 borrowShares;
        uint128 collateral;
    }

    mapping(Id => mapping(address => Position)) public positions;

    function setMarket(Id, Market memory _market) external {
        marketData = _market;
    }

    function setPosition(Id id, address account, Position memory positionParams) external {
        positions[id][account] = positionParams;
    }

    function market(Id) external view returns (Market memory) {
        return Market({
            totalSupplyAssets: 100e18,
            totalSupplyShares: 10e18,
            totalBorrowAssets: 10e18,
            totalBorrowShares: 1e18,
            lastUpdate: uint128(block.timestamp),
            fee: 100
        });
    }

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

contract MockHook {
    ISuperHook.HookType public hookType;
    address public loanToken;
    uint256 public outAmount;

    constructor(ISuperHook.HookType _hookType, address _loanToken) {
        hookType = _hookType;
        loanToken = _loanToken;
    }

    function setOutAmount(uint256 _outAmount, address) external {
        outAmount = _outAmount;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }
}

contract MorphoLoanHooksTest is Helpers {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;

    // Hooks
    MorphoSupplyAndBorrowHook public borrowHook;
    MorphoBorrowHook public borrowHookB;
    MorphoRepayHook public repayHook;
    MorphoRepayAndWithdrawHook public repayAndWithdrawHook;
    MorphoWithdrawHook public withdrawHook;
    MorphoSupplyHook public supplyHook;
    MorphoLendHook public lendHook;

    MarketParams public marketParams;
    Id public marketId;

    address public loanToken;
    address public collateralToken;

    uint256 public amount;
    uint256 public lltv;
    uint256 public lltvRatio;

    MockIRM public mockIRM;
    MockOracle public mockOracle;
    MockMorpho public mockMorpho;
    MockERC20 public mockLoanToken;
    MockERC20 public mockCollateralToken;

    /// @dev Canonical 52-byte strategy header for lend/withdraw: oracleId at offset 0 + yieldSource (Morpho) at offset
    /// 32
    /// @dev LOAN hooks: header = oracle id + the Morpho singleton (call target)
    function _header() internal view returns (bytes memory) {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, address(mockMorpho));
    }

    /// @dev MONEY_MARKET hooks (lend / withdraw): header = oracle id + the REGISTRY MARKET KEY of the
    ///      body MarketParams (the SuperLedger / PPS key); the singleton is fixed in the hook
    function _mmHeader(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(MORPHO_YS_ORACLE_ID, _mmKey(loan, coll, oracle, irm, lltv_));
    }

    /// @dev == MorphoBlueMarketRegistry.computeMarketKey
    function _mmKey(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv_
    )
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    Id.unwrap(
                        MarketParams({ loanToken: loan, collateralToken: coll, oracle: oracle, irm: irm, lltv: lltv_ })
                            .id()
                    )
                )
            )
        );
    }

    function setUp() public {
        mockMorpho = new MockMorpho();
        mockIRM = new MockIRM();
        borrowHook = new MorphoSupplyAndBorrowHook(address(mockMorpho));
        repayHook = new MorphoRepayHook(address(mockMorpho));
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(address(mockMorpho));
        withdrawHook = new MorphoWithdrawHook(address(mockMorpho));
        borrowHookB = new MorphoBorrowHook(address(mockMorpho));
        supplyHook = new MorphoSupplyHook(address(mockMorpho));
        lendHook = new MorphoLendHook(address(mockMorpho));

        amount = 1e18;
        lltv = 860_000_000_000_000_000;
        lltvRatio = 660_000_000_000_000_000;

        mockOracle = new MockOracle();
        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);
        mockLoanToken = new MockERC20("Loan Token", "LOAN", 18);
        loanToken = address(mockLoanToken);

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });

        Market memory market = Market({
            totalSupplyAssets: 100e18,
            totalSupplyShares: 10e18,
            totalBorrowAssets: 10e18,
            totalBorrowShares: 1e18,
            lastUpdate: uint128(block.timestamp),
            fee: 100
        });
        mockMorpho.setMarket(marketParams.id(), market);

        mockMorpho.setPosition(
            marketParams.id(),
            address(this),
            MockMorpho.Position({ supplyShares: 100e18, borrowShares: 100e18, collateral: 1e18 })
        );
    }

    function test_Constructors() public view {
        assertEq(address(borrowHook.morpho()), address(mockMorpho));
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(repayHook.morpho()), address(mockMorpho));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(repayAndWithdrawHook.morpho()), address(mockMorpho));
        assertEq(uint256(repayAndWithdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(withdrawHook.morpho()), address(mockMorpho));

        assertEq(address(borrowHookB.morpho()), address(mockMorpho));
        assertEq(uint256(borrowHookB.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(supplyHook.morpho()), address(mockMorpho));
        assertEq(uint256(supplyHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(lendHook.morpho()), address(mockMorpho));
        assertEq(uint256(lendHook.hookType()), uint256(ISuperHook.HookType.INFLOW)); // MONEY_MARKET (SUP-21024)
    }

    function test_Constructors_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoSupplyAndBorrowHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayAndWithdrawHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoWithdrawHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoBorrowHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoLendHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                           MORPHO LEND HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_LendHook_Build() public view {
        bytes memory data = _encodeLendData(false);
        Execution[] memory executions = lendHook.build(address(0), address(this), data);

        assertFalse(lendHook.decodeUsePrevHookAmount(data));

        // 6 executions: preExecute + approve(0) + approve(amount) + supply + approve(0) + postExecute
        assertEq(executions.length, 6);

        // Check approve(0) call targets loanToken
        assertEq(executions[1].target, address(loanToken));
        assertEq(executions[1].value, 0);

        // Check approve(amount) call targets loanToken
        assertEq(executions[2].target, address(loanToken));
        assertEq(executions[2].value, 0);

        // Check supply call targets morpho
        assertEq(executions[3].target, address(mockMorpho));
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_LendHook_Inspector() public view {
        bytes memory data = _encodeLendData(false);
        bytes memory argsEncoded = lendHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    /// @dev MONEY_MARKET identity is yield-source-first: the header market key, then MarketParams
    function test_LendHook_Inspector_PacksHeaderYieldSourceAndLltv() public view {
        bytes memory data = _encodeLendData(false);
        bytes memory expected = abi.encodePacked(
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            lltv
        );
        assertEq(lendHook.inspect(data), expected);
        assertEq(lendHook.inspect(data).length, 132);
    }

    /// @dev MONEY_MARKET header: offset 32 is the market key, so the singleton itself is a mismatch
    function test_LendHook_Build_RevertIf_HeaderIsSingletonNotMarketKey() public {
        bytes memory data = _withYieldSource(_encodeLendData(false), address(mockMorpho));
        vm.expectRevert(BaseMorphoMoneyMarketHook.MARKET_KEY_MISMATCH.selector);
        lendHook.build(address(0), address(this), data);
        vm.expectRevert(BaseMorphoMoneyMarketHook.MARKET_KEY_MISMATCH.selector);
        lendHook.preExecute(address(0), address(this), data);
    }

    function test_LendHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _mmHeader(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(mockIRM),
                uint256(0),
                lltv,
                false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(0),
                address(collateralToken),
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(), address(loanToken), address(0), address(mockOracle), address(mockIRM), amount, lltv, false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidOracle() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(0),
                address(mockIRM),
                amount,
                lltv,
                false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(0),
                amount,
                lltv,
                false
            )
        );
    }

    function test_LendHook_BuildWithPreviousHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, loanToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeLendData(true);
        Execution[] memory executions = lendHook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 6);
    }

    function test_LendHook_PrePostExecute() public {
        bytes memory data = _encodeLendData(false);

        // preExecute stores current supply shares (100e18 from setUp)
        lendHook.preExecute(address(0), address(this), data);
        assertEq(lendHook.getOutAmount(address(this)), 100e18);

        // Simulate supply by increasing supplyShares in MockMorpho
        mockMorpho.setPosition(
            marketParams.id(),
            address(this),
            MockMorpho.Position({ supplyShares: 200e18, borrowShares: 100e18, collateral: 1e18 })
        );

        // postExecute computes shares received: 200e18 - 100e18 = 100e18
        lendHook.postExecute(address(0), address(this), data);
        assertEq(lendHook.getOutAmount(address(this)), 100e18);
    }

    function test_LendHook_Build_RevertIf_InvalidDataLength() public {
        bytes memory shortData = abi.encodePacked(loanToken, collateralToken); // only 40 bytes
        vm.expectRevert(BaseMorphoLoanHook.INVALID_DATA_LENGTH.selector);
        lendHook.build(address(0), address(this), shortData);
    }

    function test_LendHook_DecodeUsePrevHookAmount() public view {
        bytes memory data = _encodeLendData(false);
        assertEq(lendHook.decodeUsePrevHookAmount(data), false);

        data = _encodeLendData(true);
        assertEq(lendHook.decodeUsePrevHookAmount(data), true);
    }

    function test_LendHook_GetLoanTokenAddress() public view {
        bytes memory data = _encodeLendData(false);
        assertNotEq(lendHook.getLoanTokenAddress(data), address(0));
        assertEq(lendHook.getLoanTokenAddress(data), loanToken);
    }

    function test_LendHook_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeLendData(false);
        assertNotEq(lendHook.getCollateralTokenAddress(data), address(0));
        assertEq(lendHook.getCollateralTokenAddress(data), collateralToken);
    }

    function test_LendHook_GetLoanTokenBalance() public {
        bytes memory data = _encodeLendData(false);
        assertEq(lendHook.getLoanTokenBalance(address(this), data), 0);

        deal(address(loanToken), address(this), 500);
        assertEq(lendHook.getLoanTokenBalance(address(this), data), 500);
    }

    /*//////////////////////////////////////////////////////////////
                           MORPHO BORROW HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BorrowHookB_Build() public view {
        bytes memory data = _encodeBorrowOnlyData(false);
        Execution[] memory executions = borrowHookB.build(address(0), address(this), data);

        assertFalse(borrowHookB.decodeUsePrevHookAmount(data));

        assertEq(executions.length, 3);

        // Check borrow call
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_BorrowHookB_Inspector() public view {
        bytes memory data = _encodeBorrowOnlyData(false);
        bytes memory argsEncoded = borrowHookB.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_BorrowHookB_Build_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        borrowHookB.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(0),
                MORPHO_IRM,
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_BorrowHookB_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHookB.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(0),
                address(collateralToken),
                address(mockOracle),
                MORPHO_IRM,
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_BorrowHookB_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHookB.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(0),
                address(mockOracle),
                MORPHO_IRM,
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_BorrowHookB_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHookB.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                MORPHO_IRM,
                uint256(0),
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_BorrowHookB_BuildWithPreviousHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, loanToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeBorrowOnlyData(true);
        Execution[] memory executions = borrowHookB.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        // Verify the borrow call is present
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_BorrowHookB_PrePostExecute() public {
        bytes memory data = _encodeBorrowOnlyData(false);
        deal(loanToken, address(this), amount);
        borrowHookB.preExecute(address(0), address(this), data);
        assertEq(borrowHookB.getOutAmount(address(this)), amount);

        borrowHookB.postExecute(address(0), address(this), data);
        assertEq(borrowHookB.getOutAmount(address(this)), 0);
    }

    function test_BorrowHookB_DecodeUsePrevHookAmount() public view {
        bytes memory data = _encodeBorrowOnlyData(false);
        assertEq(borrowHookB.decodeUsePrevHookAmount(data), false);

        data = _encodeBorrowOnlyData(true);
        assertEq(borrowHookB.decodeUsePrevHookAmount(data), true);
    }

    function test_BorrowHookB_GetLoanTokenAddress() public view {
        bytes memory data = _encodeBorrowOnlyData(false);
        assertNotEq(borrowHookB.getLoanTokenAddress(data), address(0));
        assertEq(borrowHookB.getLoanTokenAddress(data), loanToken);
    }

    function test_BorrowHookB_GetCollateralTokenAddress() public view {
        bytes memory data = _encodeBorrowOnlyData(false);
        assertNotEq(borrowHookB.getCollateralTokenAddress(data), address(0));
        assertEq(borrowHookB.getCollateralTokenAddress(data), collateralToken);
    }

    function test_BorrowHookB_GetCollateralTokenBalance() public view {
        bytes memory data = _encodeBorrowOnlyData(false);
        assertEq(borrowHookB.getCollateralTokenBalance(address(this), data), 0);
    }

    function test_BorrowHookB_GetLoanTokenBalance() public {
        loanToken = address(mockCollateralToken);
        bytes memory data = _encodeBorrowOnlyData(false);
        assertEq(borrowHookB.getLoanTokenBalance(address(this), data), 0);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoSupplyHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BorrowHook_Build() public view {
        bytes memory data = _encodeBorrowData(false);
        Execution[] memory executions = borrowHook.build(address(0), address(this), data);

        assertFalse(borrowHook.decodeUsePrevHookAmount(data));

        assertEq(executions.length, 7);

        // Check approve(0) call
        assertEq(executions[1].target, address(collateralToken));
        assertEq(executions[1].value, 0);

        // Check approve(collateralAmount) call
        assertEq(executions[2].target, address(collateralToken));
        assertEq(executions[2].value, 0);

        // Check supplyCollateral call
        assertEq(executions[3].target, address(mockMorpho));
        assertEq(executions[3].value, 0);

        // Check borrow call
        assertEq(executions[4].target, address(mockMorpho));
        assertEq(executions[4].value, 0);
    }

    function test_BorrowHook_Inspector() public view {
        bytes memory data = _encodeBorrowData(false);
        bytes memory argsEncoded = borrowHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_SupplyHook_Inspector() public view {
        bytes memory data = _encodeSupplyData(false);
        bytes memory argsEncoded = supplyHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_BorrowHook_Build_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(0),
                MORPHO_IRM,
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_SupplyHook_Build_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(0),
                MORPHO_IRM,
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_BorrowHook_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(0),
                address(collateralToken),
                address(mockOracle),
                MORPHO_IRM,
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_SupplyHook_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(0),
                address(collateralToken),
                address(mockOracle),
                MORPHO_IRM,
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_BorrowHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(0),
                address(mockOracle),
                MORPHO_IRM,
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_SupplyHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(), address(loanToken), address(0), address(mockOracle), MORPHO_IRM, amount, lltv, false, false
            )
        );
    }

    function test_BorrowHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                MORPHO_IRM,
                uint256(0),
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_SupplyHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                MORPHO_IRM,
                uint256(0),
                lltv,
                false,
                false
            )
        );
    }

    function test_SupplyHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(0),
                uint256(100),
                lltv,
                false,
                false
            )
        );
    }

    function test_SupplyHook_Build() public view {
        bytes memory data = abi.encodePacked(
            _header(), // 52-byte header
            address(loanToken),
            address(collateralToken),
            address(mockOracle),
            MORPHO_IRM,
            uint256(1000),
            lltv,
            false,
            false
        );
        Execution[] memory executions = supplyHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        assertEq(executions[1].target, address(collateralToken));
        assertEq(executions[1].value, 0);

        assertEq(executions[2].target, address(collateralToken));
        assertEq(executions[2].value, 0);

        assertEq(executions[3].target, address(mockMorpho));
        assertEq(executions[3].value, 0);
    }

    function test_SupplyHook_Build_UsePrevHookAmount() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, loanToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = abi.encodePacked(
            _header(), // 52-byte header
            address(loanToken),
            address(collateralToken),
            address(mockOracle),
            MORPHO_IRM,
            uint256(1000),
            lltv,
            true,
            true
        );
        Execution[] memory executions = supplyHook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 6);
    }

    function test_RepayHook_Inspector() public view {
        bytes memory data = _encodeRepayData(false, false);
        bytes memory argsEncoded = repayHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_RepayHook_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(0),
                collateralToken,
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayHook_Build_NoRevertIf_PartialRepay() public {
        bytes memory data = _encodeRepayData(false, false);
        vm.warp(block.timestamp + 10_000);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
    }

    function test_RepayHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(0),
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(mockIRM),
                uint256(0),
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        assertEq(executions.length, 7);

        assertEq(executions[1].target, address(loanToken));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, address(loanToken));
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

        assertEq(executions[3].target, address(mockMorpho));
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);

        assertEq(executions[4].target, address(loanToken));
        assertEq(executions[4].value, 0);
        assertGt(executions[4].callData.length, 0);

        assertEq(executions[5].target, address(mockMorpho));
        assertEq(executions[5].value, 0);
        assertGt(executions[5].callData.length, 0);
    }

    function test_RepayAndWithdrawHook_Inspector() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        bytes memory argsEncoded = repayAndWithdrawHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(0),
                collateralToken,
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(0),
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(mockIRM),
                uint256(0),
                lltv,
                false,
                false
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD WITH PREVIOUS HOOK TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BorrowHook_BuildWithPreviousHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, loanToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeBorrowData(true);
        Execution[] memory executions = borrowHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 7);
        // Verify the amount from previous hook is used in the approve call
        assertEq(executions[2].target, collateralToken);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);
    }

    function test_RepayHook_BuildWithPreviousHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, loanToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeRepayData(true, false);
        Execution[] memory executions = repayHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 6);
        // Verify the amount from previous hook is used in the approve call
        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);
    }

    function test_RepayAndWithdrawHook_BuildWithPreviousHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, loanToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeRepayAndWithdrawData(true, false);
        Execution[] memory executions = repayAndWithdrawHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 7);
        // Verify the amount from previous hook is used in the approve call
        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        DERIVE SHARE BALANCE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RepayHook_DeriveShareBalance() public view {
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint128 borrowShares = repayHook.deriveShareBalance(id, address(this));
        assertEq(borrowShares, 100e18); // From MockMorpho position() return value
    }

    function test_RepayAndWithdrawHook_DeriveShareBalance() public view {
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint128 borrowShares = repayAndWithdrawHook.deriveShareBalance(id, address(this));
        assertEq(borrowShares, 100e18); // From MockMorpho position() return value
    }

    /*//////////////////////////////////////////////////////////////
                DERIVE COLLATERAL FOR FULL REPAYMENT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RepayAndWithdrawHook_DeriveCollateralForFullRepayment() public view {
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint256 collateral = repayAndWithdrawHook.deriveCollateralForFullRepayment(id, address(this));
        MockMorpho.Position memory position = mockMorpho.position(id, address(this));
        assertEq(collateral, uint256(position.collateral));
    }

    /*//////////////////////////////////////////////////////////////
              DERIVE COLLATERAL FOR PARTIAL REPAYMENT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RepayAndWithdrawHook_DeriveCollateralForPartialRepayment() public view {
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint256 fullCollateral = 100e18; // From MockMorpho position() return value
        uint256 partialAmount = 50e18; // Half of the full amount

        uint256 withdrawableCollateral =
            repayAndWithdrawHook.deriveCollateralForPartialRepayment(id, address(this), partialAmount, fullCollateral);

        assertEq(withdrawableCollateral, 5_000_000_000_004_999_999);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSETS TO SHARES TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RepayAndWithdrawHook_AssetsToShares() public view {
        uint256 assets = 100e18;
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint256 shares = repayAndWithdrawHook.assetsToShares(params, assets);
        uint256 assetsToShares =
            assets.toSharesUp(mockMorpho.market(id).totalBorrowAssets, mockMorpho.market(id).totalBorrowShares);
        assertEq(shares, assetsToShares);
    }

    function test_RepayAndWithdrawHook_SharesToAssets() public view {
        uint256 shares = 100e18;
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint256 assets = repayAndWithdrawHook.sharesToAssets(params, address(this));
        uint256 sharesToAssets =
            shares.toAssetsUp(mockMorpho.market(id).totalBorrowAssets, mockMorpho.market(id).totalBorrowShares);
        assertEq(assets, sharesToAssets);
    }

    function test_RepayHook_SharesToAssets() public view {
        uint256 shares = 100e18;
        MarketParams memory params = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: lltv
        });
        Id id = params.id();
        uint256 assets = repayHook.sharesToAssets(params, address(this));
        uint256 sharesToAssets =
            shares.toAssetsUp(mockMorpho.market(id).totalBorrowAssets, mockMorpho.market(id).totalBorrowShares);
        assertEq(assets, sharesToAssets);
    }

    /*//////////////////////////////////////////////////////////////
                      PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BorrowHook_PrePostExecute() public {
        bytes memory data = _encodeBorrowData(false);
        deal(address(collateralToken), address(this), amount);
        borrowHook.preExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), amount, "A");

        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutAmount(address(this)), 0, "B");
    }

    function test_SupplyHook_PrePostExecute() public {
        bytes memory data = _encodeSupplyData(false);
        deal(address(collateralToken), address(this), amount);
        supplyHook.preExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutAmount(address(this)), amount);

        supplyHook.postExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutAmount(address(this)), 0);
    }

    function test_RepayHook_PrePostExecute() public {
        bytes memory data = _encodeRepayData(false, false);
        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 0);

        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), 0);
    }

    function test_RepayAndWithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 0);

        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            BASE LOAN HOOK
    //////////////////////////////////////////////////////////////*/
    function test_DecodeUsePrevHookAmount() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.decodeUsePrevHookAmount(data), false);

        data = _encodeRepayData(true, false);
        assertEq(repayHook.decodeUsePrevHookAmount(data), true);
    }

    function test_getLoanTokenAddress() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertNotEq(repayHook.getLoanTokenAddress(data), address(0));
    }

    function test_getCollateralTokenAddress() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertNotEq(repayHook.getCollateralTokenAddress(data), address(0));
    }

    function test_getCollateralTokenBalance() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.getCollateralTokenBalance(address(this), data), 0);
    }

    function test_getLoanTokenBalance() public {
        loanToken = address(mockCollateralToken);
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.getLoanTokenBalance(address(this), data), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        MORPHO WITHDRAW HOOK
    //////////////////////////////////////////////////////////////*/
    function test_WithdrawHook_Constructor() public view {
        assertEq(address(withdrawHook.morpho()), address(mockMorpho));
    }

    function test_WithdrawHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoWithdrawHook(address(0));
    }

    function test_WithdrawHook_Build() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_WithdrawHook_Build_WithShares() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, 0, amount);
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_WithdrawHook_Build_RevertIf_ZeroAssetsAndShares() public {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, 0, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_InvalidAddresses() public {
        bytes memory data =
            _encodeWithdrawData(address(0), collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Inspector() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        bytes memory argsEncoded = withdrawHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    /// @dev MONEY_MARKET identity is yield-source-first: the header market key, then MarketParams
    function test_WithdrawHook_Inspector_PacksHeaderYieldSourceAndLltv() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        bytes memory expected = abi.encodePacked(
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            lltv
        );
        assertEq(withdrawHook.inspect(data), expected);
        assertEq(withdrawHook.inspect(data).length, 132);
    }

    /// @dev MONEY_MARKET header: offset 32 is the market key, so the singleton itself is a mismatch
    function test_WithdrawHook_Build_RevertIf_HeaderIsSingletonNotMarketKey() public {
        bytes memory data = _withYieldSource(
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0),
            address(mockMorpho)
        );
        vm.expectRevert(BaseMorphoMoneyMarketHook.MARKET_KEY_MISMATCH.selector);
        withdrawHook.build(address(0), address(this), data);
        vm.expectRevert(BaseMorphoMoneyMarketHook.MARKET_KEY_MISMATCH.selector);
        withdrawHook.preExecute(address(0), address(this), data);
    }

    function test_WithdrawHook_PrePostExecute() public {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), 0);
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutAmount(address(this)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          ASSETS TO PAY TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RepayHook_No_OverestimatedAssetsToPay() public {
        address account = address(this);

        MarketParams memory params = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: address(mockOracle),
            irm: address(mockIRM),
            lltv: 0.8e18
        });
        Id id = params.id();

        Market memory newMarket = Market({
            totalSupplyAssets: 0,
            totalSupplyShares: 0,
            totalBorrowAssets: 1000e18, // 1000 loan tokens borrowed
            totalBorrowShares: 1000e18, // 1000 shares
            lastUpdate: uint128(block.timestamp),
            fee: 0
        });
        mockMorpho.setMarket(id, newMarket);
        MockMorpho.Position memory positionMock =
            MockMorpho.Position({ supplyShares: 0, borrowShares: 10e18, collateral: 0 });
        mockMorpho.setPosition(id, account, positionMock); // User has 1% of total shares
        vm.warp(block.timestamp + 1 days); // Accrue interest for 1 day

        bytes memory data = abi.encodePacked(
            _header(), // 52-byte header: oracleId at offset 0 + yieldSource (Morpho) at offset 32
            address(loanToken),
            address(collateralToken),
            address(mockOracle),
            address(mockIRM),
            uint256(0), // amount (unused for full repayment)
            uint256(0.8e18), // lltv
            false, // usePrevHookAmount
            true // isFullRepayment
        );

        Execution[] memory executions = repayHook.build(address(0), account, data);

        bytes memory approveCallData = executions[1].callData;
        bytes memory args = BytesLib.slice(approveCallData, 4, approveCallData.length - 4);

        (, uint256 currentAssetsToPay) = abi.decode(args, (address, uint256));

        // Calculate expected assetsToPay
        uint256 deriveInterest = 0; // Removed from RepayHook
        uint256 estimatedTotalBorrowAssets = newMarket.totalBorrowAssets + deriveInterest;
        MockMorpho.Position memory position = mockMorpho.position(id, account);
        uint256 shareBalance = uint256(position.borrowShares);
        uint256 expectedAssetsToPay = shareBalance.toAssetsUp(estimatedTotalBorrowAssets, newMarket.totalBorrowShares);

        // Log values for clarity
        emit log_named_uint("Current assetsToPay", currentAssetsToPay);
        emit log_named_uint("Expected assetsToPay", expectedAssetsToPay);

        // Assert overestimation
        assertFalse(currentAssetsToPay > expectedAssetsToPay, "assetsToPay is overestimated");
    }

    /*//////////////////////////////////////////////////////////////
                    REPAY AND WITHDRAW FULL REPAYMENT
    //////////////////////////////////////////////////////////////*/

    function test_RepayAndWithdrawHook_Build_FullRepayment() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, true);
        Execution[] memory executions = repayAndWithdrawHook.build(address(0), address(this), data);

        // For full repayment, executions array should have length 5
        assertEq(executions.length, 7);
        // Approve(0)
        assertEq(executions[1].target, address(loanToken));
        assertGt(executions[1].callData.length, 0);
        // Approve(loanAmount)
        assertEq(executions[2].target, address(loanToken));
        assertGt(executions[2].callData.length, 0);
        // Repay (amount=0, shares=borrowBalance)
        assertEq(executions[3].target, address(mockMorpho));
        assertGt(executions[3].callData.length, 0);
        // Approve(0)
        assertEq(executions[4].target, address(loanToken));
        assertGt(executions[4].callData.length, 0);
        // WithdrawCollateral
        assertEq(executions[5].target, address(mockMorpho));
        assertGt(executions[5].callData.length, 0);
    }

    function test_RepayAndWithdrawHook_PrePostExecute_FullRepayment() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, true);
        // outAmount should be 0 before and after since MockERC20 has no balance logic
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 0);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutAmount(address(this)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY FIX VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev P2-1: WithdrawHook outAmount tracks account's loanToken balance delta
    function test_WithdrawHook_PrePostExecute_TracksAccountBalance() public {
        address account = address(this);

        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);

        // Deal loanToken to account (Morpho sends to account on withdraw, since recipient == account)
        deal(loanToken, account, 100e18);

        // preExecute stores account's loanToken balance
        withdrawHook.preExecute(address(0), account, data);
        assertEq(withdrawHook.getOutAmount(account), 100e18);

        // Simulate Morpho sending more loanToken to account
        deal(loanToken, account, 200e18);

        // postExecute computes received: 200e18 - 100e18 = 100e18
        withdrawHook.postExecute(address(0), account, data);
        assertEq(withdrawHook.getOutAmount(account), 100e18);
    }

    /// @dev P2-2: Both assets and shares non-zero should revert (XOR validation)
    function test_WithdrawHook_Build_RevertIf_BothAssetsAndSharesNonZero() public {
        bytes memory data = _encodeWithdrawData(
            loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, amount
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    /// @dev P2-3: Zero oracle price must revert on deriveLoanAmount
    function test_SupplyAndBorrowHook_DeriveLoanAmount_RevertIf_ZeroOraclePrice() public {
        MockZeroOracle zeroOracle = new MockZeroOracle();

        vm.expectRevert(BaseMorphoLoanHook.ORACLE_PRICE_NOT_VALID.selector);
        borrowHook.deriveLoanAmount(amount, lltvRatio, lltv, address(zeroOracle));
    }

    /// @dev P2-3: Zero oracle price reverts through full build path
    function test_SupplyAndBorrowHook_Build_RevertIf_ZeroOraclePrice() public {
        MockZeroOracle zeroOracle = new MockZeroOracle();

        bytes memory data = abi.encodePacked(
            _header(), // 52-byte header
            loanToken,
            collateralToken,
            address(zeroOracle),
            address(mockIRM),
            amount,
            lltvRatio,
            false,
            lltv,
            false
        );

        vm.expectRevert(BaseMorphoLoanHook.ORACLE_PRICE_NOT_VALID.selector);
        borrowHook.build(address(0), address(this), data);
    }

    /// @dev P2-7: RepayHook now tracks consumed loanToken via _preExecute/_postExecute
    function test_RepayHook_PrePostExecute_TracksConsumedLoanToken() public {
        bytes memory data = _encodeRepayData(false, false);
        uint256 initialBalance = 100e18;
        deal(loanToken, address(this), initialBalance);

        // preExecute accrues interest and stores loanToken balance
        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), initialBalance);

        // Simulate repay consuming 50e18 of loanToken
        uint256 consumed = 50e18;
        deal(loanToken, address(this), initialBalance - consumed);

        // postExecute computes consumed: initialBalance - (initialBalance - consumed) = consumed
        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), consumed);
    }

    /// @dev P2-7: RepayHook full repayment tracks total consumed
    function test_RepayHook_PrePostExecute_TracksFullRepaymentConsumed() public {
        bytes memory data = _encodeRepayData(false, true);
        uint256 initialBalance = 100e18;
        deal(loanToken, address(this), initialBalance);

        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), initialBalance);

        // Simulate full repayment consuming all loanToken
        deal(loanToken, address(this), 0);

        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutAmount(address(this)), initialBalance);
    }

    /// @dev P3-3: Address validation in decode means inspect() also reverts on zero addresses
    function test_WithdrawHook_Inspector_RevertIf_InvalidAddresses() public {
        bytes memory data =
            _encodeWithdrawData(address(0), collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.inspect(data);
    }

    function test_BorrowHookB_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHookB.inspect(
            abi.encodePacked(
                _header(),
                address(0),
                collateralToken,
                address(mockOracle),
                address(mockIRM),
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_SupplyAndBorrowHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.inspect(
            abi.encodePacked(
                _header(),
                address(0),
                collateralToken,
                address(mockOracle),
                address(mockIRM),
                amount,
                lltvRatio,
                false,
                lltv,
                false
            )
        );
    }

    function test_SupplyHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.inspect(
            abi.encodePacked(
                _header(), address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false
            )
        );
    }

    function test_LendHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.inspect(
            abi.encodePacked(
                _header(), address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false
            )
        );
    }

    function test_RepayHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.inspect(
            abi.encodePacked(
                _header(),
                address(0),
                collateralToken,
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayAndWithdrawHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.inspect(
            abi.encodePacked(
                _header(),
                address(0),
                collateralToken,
                address(mockOracle),
                address(mockIRM),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(0),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                _header(),
                address(loanToken),
                address(collateralToken),
                address(mockOracle),
                address(0),
                amount,
                lltv,
                false,
                false
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
              DECODE AMOUNT / REPLACE CALLDATA AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_SupplyHook_DecodeAmounts() public view {
        bytes memory data = _encodeSupplyData(false);
        assertEq(supplyHook.decodeAmounts(data)[0], amount);
    }

    function test_SupplyHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeSupplyData(false);
        uint256 newAmount = 2e18;
        bytes memory result = supplyHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(supplyHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SupplyHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeSupplyData(false);
        bytes memory result = supplyHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(supplyHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_LendHook_DecodeAmounts() public view {
        bytes memory data = _encodeLendData(false);
        assertEq(lendHook.decodeAmounts(data)[0], amount);
    }

    function test_LendHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeLendData(false);
        uint256 newAmount = 2e18;
        bytes memory result = lendHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(lendHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_LendHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeLendData(false);
        bytes memory result = lendHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(lendHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_BorrowHook_DecodeAmounts() public view {
        bytes memory data = _encodeBorrowData(false);
        assertEq(borrowHook.decodeAmounts(data)[0], amount);
    }

    function test_BorrowHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeBorrowData(false);
        uint256 newAmount = 2e18;
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(borrowHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_BorrowHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeBorrowData(false);
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(borrowHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_RepayHook_DecodeAmounts() public view {
        bytes memory data = _encodeRepayData(false, false);
        assertEq(repayHook.decodeAmounts(data)[0], amount);
    }

    function test_RepayHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRepayData(false, false);
        uint256 newAmount = 2e18;
        bytes memory result = repayHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(repayHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_RepayHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRepayData(false, false);
        bytes memory result = repayHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(repayHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SupplyAndBorrowHook_DecodeAmounts() public view {
        bytes memory data = _encodeBorrowData(false);
        assertEq(borrowHook.decodeAmounts(data)[0], amount);
    }

    function test_SupplyAndBorrowHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeBorrowData(false);
        uint256 newAmount = 2e18;
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(borrowHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SupplyAndBorrowHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeBorrowData(false);
        bytes memory result = borrowHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(borrowHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_RepayAndWithdrawHook_DecodeAmounts() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        assertEq(repayAndWithdrawHook.decodeAmounts(data)[0], amount);
    }

    function test_RepayAndWithdrawHook_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        uint256 newAmount = 2e18;
        bytes memory result = repayAndWithdrawHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(repayAndWithdrawHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_RepayAndWithdrawHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        bytes memory result = repayAndWithdrawHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(repayAndWithdrawHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_WithdrawHook_DecodeAmounts() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        assertEq(withdrawHook.decodeAmounts(data)[0], amount);
    }

    function test_WithdrawHook_ReplaceCalldataAmounts() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        uint256 newAmount = 2e18;
        // MorphoWithdrawHook has dual-slot: [assets, shares] with XOR invariant
        bytes memory result = withdrawHook.replaceCalldataAmounts(data, _dualAmounts(newAmount, 0));
        assertEq(result.length, data.length);
        assertEq(withdrawHook.decodeAmounts(result)[0], newAmount);
        assertEq(withdrawHook.decodeAmounts(result)[1], 0);
    }

    function testFuzz_WithdrawHook_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        // MorphoWithdrawHook has dual-slot: [assets, shares] with XOR invariant
        bytes memory result = withdrawHook.replaceCalldataAmounts(data, _dualAmounts(fuzzAmount, 0));
        assertEq(withdrawHook.decodeAmounts(result)[0], fuzzAmount);
        assertEq(withdrawHook.decodeAmounts(result)[1], 0);
    }

    function test_MorphoSupply_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeSupplyData(false);
        uint256 newAmount = 500;
        bytes memory replaced = supplyHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = supplyHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 6);
        assertEq(supplyHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_MorphoLend_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeLendData(false);
        uint256 newAmount = 500;
        bytes memory replaced = lendHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = lendHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 6);
        assertEq(lendHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_MorphoWithdraw_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        uint256 newAmount = 500;
        // MorphoWithdrawHook has dual-slot: [assets, shares] with XOR invariant
        bytes memory replaced = withdrawHook.replaceCalldataAmounts(data, _dualAmounts(newAmount, 0));
        Execution[] memory executions = withdrawHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(withdrawHook.decodeAmounts(replaced)[0], newAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _encodeBorrowData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            _header(), // 52-byte header: oracleId at offset 0 + yieldSource (Morpho) at offset 32
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            amount,
            lltvRatio,
            usePrevHook,
            lltv,
            false
        );
    }

    function _encodeSupplyData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            _header(), // 52-byte header: oracleId at offset 0 + yieldSource (Morpho) at offset 32
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            amount,
            lltv,
            usePrevHook,
            false // isFullRepayment
        );
    }

    function _encodeRepayData(bool usePrevHook, bool isFullRepayment) internal view returns (bytes memory) {
        return abi.encodePacked(
            _header(), // 52-byte header: oracleId at offset 0 + yieldSource (Morpho) at offset 32
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            amount,
            lltv,
            usePrevHook,
            isFullRepayment
        );
    }

    function _encodeRepayAndWithdrawData(bool usePrevHook, bool isFullRepayment) internal view returns (bytes memory) {
        return abi.encodePacked(
            _header(), // 52-byte header: oracleId at offset 0 + yieldSource (Morpho) at offset 32
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            amount,
            lltv,
            usePrevHook,
            isFullRepayment
        );
    }

    /*//////////////////////////////////////////////////////////////
       V1 BORROWER HOOKS: HEADER IDENTITY (freeze lifted — PR #1009 review F1)
    //////////////////////////////////////////////////////////////*/

    /// @dev Overwrites the header yield source (bytes 32..51) of an already-encoded payload
    function _withYieldSource(bytes memory d, address ys) internal pure returns (bytes memory) {
        bytes20 b = bytes20(ys);
        for (uint256 i; i < 20; ++i) {
            d[32 + i] = b[i];
        }
        return d;
    }

    /// @dev (hook, payload) pairs for the five V1 borrower hooks
    function _v1BorrowerCases() internal view returns (BaseMorphoLoanHook[5] memory hooks, bytes[5] memory datas) {
        hooks[0] = supplyHook;
        datas[0] = _encodeSupplyData(false);
        hooks[1] = borrowHookB;
        datas[1] = _encodeBorrowOnlyData(false);
        hooks[2] = repayHook;
        datas[2] = _encodeRepayData(false, false);
        hooks[3] = borrowHook;
        datas[3] = _encodeBorrowData(false);
        hooks[4] = repayAndWithdrawHook;
        datas[4] = _encodeRepayAndWithdrawData(false, false);
    }

    /// @dev A zero header yield source fails closed on build and preExecute for every V1 borrower hook
    function test_V1Borrowers_RevertIf_ZeroYieldSource() public {
        (BaseMorphoLoanHook[5] memory hooks, bytes[5] memory datas) = _v1BorrowerCases();
        for (uint256 i; i < 5; ++i) {
            bytes memory d = _withYieldSource(datas[i], address(0));
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), d);
            vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
            ISuperHook(address(hooks[i])).preExecute(address(0), address(this), d);
        }
    }

    /// @dev A header pointing at a different Morpho fails closed (YIELD_SOURCE_MISMATCH) on build and
    ///      preExecute for every V1 borrower hook — the pin is the primary call-target control
    function test_V1Borrowers_RevertIf_YieldSourceMismatch() public {
        address otherMorpho = address(new MockMorpho());
        (BaseMorphoLoanHook[5] memory hooks, bytes[5] memory datas) = _v1BorrowerCases();
        for (uint256 i; i < 5; ++i) {
            bytes memory d = _withYieldSource(datas[i], otherMorpho);
            vm.expectRevert(BaseMorphoLoanHook.YIELD_SOURCE_MISMATCH.selector);
            ISuperHook(address(hooks[i])).build(address(0), address(this), d);
            vm.expectRevert(BaseMorphoLoanHook.YIELD_SOURCE_MISMATCH.selector);
            ISuperHook(address(hooks[i])).preExecute(address(0), address(this), d);
        }
    }

    /// @dev With a valid header every V1 borrower hook builds, and every Morpho call / approve spender
    ///      targets the header yield source (== mockMorpho); the wrong Morpho is never targeted
    function test_V1Borrowers_ValidHeader_TargetsHeaderMorpho() public {
        (BaseMorphoLoanHook[5] memory hooks, bytes[5] memory datas) = _v1BorrowerCases();
        for (uint256 i; i < 5; ++i) {
            Execution[] memory execs = ISuperHook(address(hooks[i])).build(address(0), address(this), datas[i]);
            bool morphoSeen;
            for (uint256 j; j < execs.length; ++j) {
                address t = execs[j].target;
                if (t != loanToken && t != collateralToken && t != address(hooks[i])) {
                    assertEq(t, address(mockMorpho), "non-token call must target header Morpho");
                    morphoSeen = true;
                }
            }
            assertTrue(morphoSeen, "at least one Morpho call");
        }
    }

    /// @dev inspect() on every V1 borrower hook is the 6-field identity: header Morpho + loan +
    ///      collateral + oracle + irm + lltv (132 bytes); Morpho is the header yield source, never a
    ///      separate/6th MarketParams field
    function test_V1Borrowers_Inspect_IsMorphoPlusMarketParams() public view {
        (BaseMorphoLoanHook[5] memory hooks, bytes[5] memory datas) = _v1BorrowerCases();
        for (uint256 i; i < 5; ++i) {
            bytes memory out = ISuperHookInspector(address(hooks[i])).inspect(datas[i]);
            assertEq(out.length, 132, "6-field inspect");
            assertEq(BytesLib.toAddress(out, 0), address(mockMorpho), "field 0 = header Morpho");
            assertEq(BytesLib.toAddress(out, 20), loanToken, "field 1 = loan token");
            assertEq(BytesLib.toAddress(out, 40), collateralToken, "field 2 = collateral");
            assertEq(BytesLib.toUint256(out, 100), lltv, "field 5 = lltv");
            // header yield source changes the identity; amounts do not
            bytes memory other =
                ISuperHookInspector(address(hooks[i])).inspect(_withYieldSource(datas[i], address(0xBEEF)));
            assertEq(BytesLib.toAddress(other, 0), address(0xBEEF));
        }
    }

    /*//////////////////////////////////////////////////////////////
          SUP-21024: MONEY_MARKET TYPE FLIP + PER-MARKET ACCOUNTING KEY
    //////////////////////////////////////////////////////////////*/

    /// @dev Lend is INFLOW and withdraw is OUTFLOW (vault-main accounting); the V1 borrower
    ///      hooks sharing the same bases stay NONACCOUNTING.
    function test_MoneyMarket_HookTypes() public view {
        assertEq(uint256(lendHook.hookType()), uint256(ISuperHook.HookType.INFLOW), "lend INFLOW");
        assertEq(uint256(withdrawHook.hookType()), uint256(ISuperHook.HookType.OUTFLOW), "withdraw OUTFLOW");
        assertEq(uint256(supplyHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "supply stays LOAN");
        assertEq(uint256(borrowHookB.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "borrow stays LOAN");
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "repay stays LOAN");
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "open stays LOAN");
        assertEq(
            uint256(repayAndWithdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "close stays LOAN"
        );
    }

    /// @dev The ERC-165 list is BaseHook's, unchanged: no accounting adapter is advertised — the executor
    ///      is untouched and keys the ledger by header offset 32, which these hooks fill with the market key.
    function test_MoneyMarket_SupportsInterface_Unchanged() public view {
        assertTrue(lendHook.supportsInterface(type(IERC165).interfaceId));
        assertTrue(lendHook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(lendHook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(lendHook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertTrue(withdrawHook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId), "sized");
        assertTrue(withdrawHook.supportsInterface(type(ISuperHookOutflow).interfaceId), "sized");
    }

    /// @dev Header offset 32 must be exactly the registry's market key for the body MarketParams —
    ///      never the Morpho singleton (which would merge every market's cost basis). With it, every
    ///      Morpho call still targets the singleton fixed in the hook.
    function test_MoneyMarket_HeaderMarketKey_MatchesRegistry_TargetsSingleton() public {
        MorphoBlueMarketRegistry registry = new MorphoBlueMarketRegistry(address(this));
        address expected =
            registry.computeMarketKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv);
        assertEq(
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv), expected, "key == registry"
        );
        assertTrue(expected != address(mockMorpho), "key is never the Morpho singleton");

        Execution[] memory lend = lendHook.build(address(0), address(this), _encodeLendData(false));
        assertEq(lend[3].target, address(mockMorpho), "lend supply targets the singleton");
        Execution[] memory wd = withdrawHook.build(
            address(0),
            address(this),
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0)
        );
        assertEq(wd[1].target, address(mockMorpho), "withdraw targets the singleton");

        // A different market (lltv) on the same Morpho keys differently
        address other =
            registry.computeMarketKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv + 1);
        assertTrue(other != expected, "distinct market => distinct key");
        assertEq(_mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv + 1), other);
    }

    /// @dev A header naming ANOTHER market's key, or the singleton, fails closed on build and preExecute
    function test_MoneyMarket_RevertIf_HeaderKeyMismatch() public {
        bytes4 sel = BaseMorphoMoneyMarketHook.MARKET_KEY_MISMATCH.selector;
        address[2] memory bad =
            [_mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv + 1), address(mockMorpho)];
        for (uint256 i; i < 2; ++i) {
            bytes memory l = _withYieldSource(_encodeLendData(false), bad[i]);
            vm.expectRevert(sel);
            lendHook.build(address(0), address(this), l);
            vm.expectRevert(sel);
            lendHook.preExecute(address(0), address(this), l);

            bytes memory w = _withYieldSource(
                _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0),
                bad[i]
            );
            vm.expectRevert(sel);
            withdrawHook.build(address(0), address(this), w);
            vm.expectRevert(sel);
            withdrawHook.preExecute(address(0), address(this), w);
        }
    }

    function testFuzz_MoneyMarket_HeaderKey_MatchesRegistry(
        address coll,
        address oracle,
        address irm,
        uint256 lltv_
    )
        public
    {
        vm.assume(coll != address(0) && oracle != address(0) && irm != address(0) && coll != loanToken);
        MorphoBlueMarketRegistry registry = new MorphoBlueMarketRegistry(address(this));
        assertEq(
            _mmKey(loanToken, coll, oracle, irm, lltv_), registry.computeMarketKey(loanToken, coll, oracle, irm, lltv_)
        );
        Execution[] memory wd = withdrawHook.build(
            address(0), address(this), _encodeWithdrawData(loanToken, coll, oracle, irm, lltv_, amount, 0)
        );
        assertEq(wd[1].target, address(mockMorpho), "always the singleton");
    }

    function _lendDataZeroOracleId() internal view returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0),
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            amount,
            lltv,
            false
        );
    }

    function _withdrawDataZeroOracleId() internal view returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0),
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            lltv,
            amount,
            uint256(0)
        );
    }

    /// @dev A zero header oracle id fails closed on every entry point (ticket item 2).
    function test_MoneyMarket_RevertIf_ZeroOracleId() public {
        bytes4 sel = BaseMorphoMoneyMarketHook.ORACLE_ID_NOT_VALID.selector;

        bytes memory l = _lendDataZeroOracleId();
        vm.expectRevert(sel);
        lendHook.build(address(0), address(this), l);
        vm.expectRevert(sel);
        lendHook.inspect(l);
        vm.expectRevert(sel);
        lendHook.preExecute(address(0), address(this), l);

        bytes memory w = _withdrawDataZeroOracleId();
        vm.expectRevert(sel);
        withdrawHook.build(address(0), address(this), w);
        vm.expectRevert(sel);
        withdrawHook.inspect(w);
        vm.expectRevert(sel);
        withdrawHook.preExecute(address(0), address(this), w);
    }

    /// @dev PR #1010 review F1: SuperVaultAggregator hashes the RAW inspect bytes into the Merkle
    ///      leaf, so a SUP-21025 leaf (market key first) must equal the on-chain leaf. Also pins
    ///      header-key sensitivity, per-MarketParams-field sensitivity and amount invariance.
    function test_MoneyMarket_Inspect_KeyFirst_AggregatorLeafParity() public view {
        address key = _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv);
        bytes memory lendData = _encodeLendData(false);
        bytes memory wdData =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        bytes memory required =
            abi.encodePacked(key, loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv);
        bytes memory singletonFirst = abi.encodePacked(
            address(mockMorpho), loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv
        );

        // leaf parity with the aggregator's exact formula
        assertEq(_leaf(address(lendHook), lendHook.inspect(lendData)), _leaf(address(lendHook), required), "lend leaf");
        assertEq(
            _leaf(address(withdrawHook), withdrawHook.inspect(wdData)),
            _leaf(address(withdrawHook), required),
            "wd leaf"
        );
        assertTrue(
            _leaf(address(lendHook), required) != _leaf(address(lendHook), singletonFirst),
            "singleton-first leaf differs"
        );

        // header-key sensitivity: only field 0 moves
        bytes memory other = lendHook.inspect(_withYieldSource(lendData, address(0xBEEF)));
        assertEq(BytesLib.toAddress(other, 0), address(0xBEEF));
        assertEq(BytesLib.toAddress(other, 20), loanToken);

        // amount invariance
        assertEq(lendHook.inspect(_withAmount(lendData, amount * 3)), lendHook.inspect(lendData), "amount ignored");
        assertEq(
            withdrawHook.inspect(
                _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, 0, 5e18)
            ),
            withdrawHook.inspect(wdData),
            "assets/shares ignored"
        );

        // every MarketParams field is part of the identity (loan token varied via a fresh header key)
        bytes memory h = lendHook.inspect(lendData);
        assertTrue(
            keccak256(
                lendHook.inspect(_lendWith(loanToken, address(0xC011), address(mockOracle), address(mockIRM), lltv))
            ) != keccak256(h),
            "collateral"
        );
        assertTrue(
            keccak256(lendHook.inspect(_lendWith(loanToken, collateralToken, address(0x0AC1), address(mockIRM), lltv)))
                != keccak256(h),
            "oracle"
        );
        assertTrue(
            keccak256(
                    lendHook.inspect(_lendWith(loanToken, collateralToken, address(mockOracle), address(0x1AB), lltv))
                ) != keccak256(h),
            "irm"
        );
        assertTrue(
            keccak256(
                lendHook.inspect(_lendWith(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv + 1))
            ) != keccak256(h),
            "lltv"
        );
    }

    /// @dev == SuperVaultAggregator._createLeaf (v2-periphery): keccak256(bytes.concat(keccak256(abi.encode(hook,
    /// args))))
    function _leaf(address hook, bytes memory args) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(hook, args))));
    }

    function _withAmount(bytes memory d, uint256 a) internal pure returns (bytes memory) {
        bytes32 w = bytes32(a);
        for (uint256 i; i < 32; ++i) {
            d[132 + i] = w[i];
        }
        return d;
    }

    /// @dev Lend payload for arbitrary MarketParams with a matching header key
    function _lendWith(
        address loan,
        address coll,
        address oracle,
        address irm,
        uint256 lltv_
    )
        internal
        view
        returns (bytes memory)
    {
        return
            abi.encodePacked(_mmHeader(loan, coll, oracle, irm, lltv_), loan, coll, oracle, irm, amount, lltv_, false);
    }

    /// @dev OUTFLOW correctness: usedShares = supply shares actually burned (position diff), asset =
    ///      loan token — identical whether the withdraw is denominated in shares or assets.
    function test_WithdrawHook_PrePost_SetsUsedSharesAndAsset_ByShares() public {
        _assertWithdrawUsedShares(
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, 0, 40e18)
        );
    }

    function test_WithdrawHook_PrePost_SetsUsedSharesAndAsset_ByAssets() public {
        _assertWithdrawUsedShares(
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0)
        );
    }

    function _assertWithdrawUsedShares(bytes memory data) internal {
        // setUp seeds supplyShares = 100e18 for this account in marketParams
        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.usedShares(), 100e18, "usedShares baseline = position before");
        assertEq(withdrawHook.asset(), loanToken, "asset = loan token (fee token)");

        // Simulate Morpho burning 40e18 supply shares
        mockMorpho.setPosition(
            marketParams.id(),
            address(this),
            MockMorpho.Position({ supplyShares: 60e18, borrowShares: 100e18, collateral: 1e18 })
        );
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.usedShares(), 40e18, "usedShares = shares burned");
    }

    function test_LendHook_PreExecute_SetsAsset() public {
        lendHook.preExecute(address(0), address(this), _encodeLendData(false));
        assertEq(lendHook.asset(), loanToken, "asset = loan token");
    }

    function _encodeWithdrawData(
        address _loanToken,
        address _collateralToken,
        address _oracle,
        address _irm,
        uint256 _lltv,
        uint256 _assets,
        uint256 _shares
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            _mmHeader(_loanToken, _collateralToken, _oracle, _irm, _lltv), // header: oracle id + market key
            _loanToken,
            _collateralToken,
            _oracle,
            _irm,
            _lltv,
            _assets,
            _shares
        );
    }

    function _encodeBorrowOnlyData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            _header(), // 52-byte header: oracleId at offset 0 + yieldSource (Morpho) at offset 32
            loanToken,
            collateralToken,
            address(mockOracle),
            MORPHO_IRM,
            amount,
            lltvRatio,
            usePrevHook,
            lltv,
            false
        );
    }

    function _encodeLendData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            _mmHeader(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv), // header: oracle id +
            // market key
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            amount,
            lltv,
            usePrevHook
        );
    }

    /*//////////////////////////////////////////////////////////////
                         GET OUT TOKEN TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev SUP-21005: outAmount is Morpho supply shares (not an ERC-20), so outToken is the header
    ///      market key — the synthetic share identity the executor posts INFLOW against — never the
    ///      loan token (which would let PREV feed share wei into a loan-token hop).
    function test_LendHook_GetOutToken_IsMarketKey_NotLoanToken() public {
        bytes memory data = _encodeLendData(false);
        lendHook.preExecute(address(0), address(this), data);
        lendHook.postExecute(address(0), address(this), data);

        address out = lendHook.getOutToken(address(this));
        assertEq(out, _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv), "market key");
        assertEq(out, BytesLib.toAddress(data, 32), "== header yield source");
        assertTrue(out != loanToken, "never the loan token");
        assertTrue(out != address(0), "never unset / native");
    }

    /// @dev SUP-21005: OMS sizes lend as MONEY_MARKET ASSETS — one rewritable slot (offset 132),
    ///      same as the ERC-4626 deposit hook; the borrower V1 family keeps IN/TOKEN.
    function test_LendHook_AmountRoles_SingleSlot_InAssets() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = lendHook.amountRoles("");
        assertEq(meta.length, 1, "one slot");
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.ASSETS));

        // Slot layout unchanged: decode / replace still act on offset 132
        bytes memory data = _encodeLendData(false);
        uint256[] memory amounts = lendHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);
        uint256[] memory replaced = new uint256[](1);
        replaced[0] = 777;
        bytes memory out = lendHook.replaceCalldataAmounts(data, replaced);
        assertEq(BytesLib.toUint256(out, 132), 777, "written at offset 132");
        assertEq(out.length, data.length, "length unchanged");

        // Borrower V1 family untouched
        ISuperHookInflowOutflow.AmountMeta[] memory supplyMeta = supplyHook.amountRoles("");
        assertEq(
            uint256(supplyMeta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN), "supply stays TOKEN"
        );
    }

    /// @dev SUP-21005: a PASSTHROUGH hook after lend forwards the pair unchanged — (marketKey, shares) —
    ///      so the identity survives intermediate approve/mark hops and still fails closed downstream.
    function test_LendHook_PassthroughForwardsMarketKeyAndShares() public {
        ApproveERC20Hook approve = new ApproveERC20Hook();
        bytes memory data = _encodeLendData(false);
        lendHook.preExecute(address(0), address(this), data);
        mockMorpho.setPosition(
            marketParams.id(),
            address(this),
            MockMorpho.Position({ supplyShares: 200e18, borrowShares: 100e18, collateral: 1e18 })
        );
        lendHook.postExecute(address(0), address(this), data); // outAmount = 100e18 shares

        // ApproveERC20Hook (125 bytes): header + token@52 + spender@72 + amount@92 + usePrev@124
        bytes memory approveData =
            abi.encodePacked(bytes32(0), address(0), loanToken, address(0xBEEF), uint256(0), true);
        approve.preExecute(address(lendHook), address(this), approveData);

        assertEq(approve.getOutAmount(address(this)), 100e18, "shares forwarded unchanged");
        assertEq(
            approve.getOutToken(address(this)),
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
            "market key forwarded (never the loan token)"
        );
        assertTrue(approve.getOutToken(address(this)) != loanToken);
    }

    /// @dev SUP-21005: FeeSplittingHook (PASSTHROUGH with fee reconciliation) after lend forwards the
    ///      (marketKey, shares) pair unchanged — a fee leg paid in the LOAN token is not the flow token
    ///      any more, so it is no longer subtracted from the share count (the pre-SUP-21005 unit bug),
    ///      and the codeless key is not mistaken for native ETH.
    function test_LendHook_FeeSplittingAfterLend_ForwardsUnchanged_LoanTokenFeeNotSubtracted() public {
        FeeSplittingHook fee = new FeeSplittingHook(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        bytes memory data = _encodeLendData(false);
        lendHook.preExecute(address(0), address(this), data);
        mockMorpho.setPosition(
            marketParams.id(),
            address(this),
            MockMorpho.Position({ supplyShares: 200e18, borrowShares: 100e18, collateral: 1e18 })
        );
        lendHook.postExecute(address(0), address(this), data); // outAmount = 100e18 shares

        // one fee leg: 5 loan tokens to a recipient
        address recipient = makeAddr("feeRecipient");
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory receivers = new address[](1);
        tokens[0] = loanToken;
        amounts[0] = 5e18;
        receivers[0] = recipient;
        bytes memory feeData = abi.encodePacked(bytes(new bytes(52)), abi.encode(tokens, amounts, receivers));
        MockERC20(loanToken).mint(address(this), 5e18);

        fee.setExecutionContext(address(this));
        fee.preExecute(address(lendHook), address(this), feeData);
        MockERC20(loanToken).transfer(recipient, 5e18); // the executor would run this leg
        fee.postExecute(address(lendHook), address(this), feeData);

        assertEq(
            fee.getOutAmount(address(this)), 100e18, "shares forwarded unchanged (loan-token fee is not the flow token)"
        );
        assertEq(
            fee.getOutToken(address(this)),
            _mmKey(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv),
            "market key forwarded"
        );
    }

    /// @dev SUP-21005: a swap hook that verifies the previous output token (Aerodrome) sized from lend
    ///      with usePrevHookAmount fails closed — the market key is never the swap's input token.
    function test_LendHook_PrevIntoAerodromeSwap_RevertsTokenMismatch() public {
        SwapAerodromeUniversalRouterHook swap =
            new SwapAerodromeUniversalRouterHook(address(new MockAerodromeUniversalRouter()));
        bytes memory data = _encodeLendData(false);
        lendHook.preExecute(address(0), address(this), data);
        mockMorpho.setPosition(
            marketParams.id(),
            address(this),
            MockMorpho.Position({ supplyShares: 200e18, borrowShares: 100e18, collateral: 1e18 })
        );
        lendHook.postExecute(address(0), address(this), data);

        // classic route (kind 0), deadline in the future, path loanToken -> collateralToken
        bytes memory swapData = swap.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: loanToken,
                outputToken: collateralToken,
                inputAmount: 1000,
                outputQuote: 950,
                outputMin: 900,
                usePrevHookAmount: true
            }),
            abi.encode(uint8(0), uint256(10_000), abi.encodePacked(loanToken, bytes1(0), collateralToken))
        );
        vm.expectRevert(BaseAerodromeUniversalRouterHook.PREV_HOOK_TOKEN_MISMATCH.selector);
        swap.build(address(lendHook), address(this), swapData);
    }

    /// @dev SUP-21005: PREV from lend into a loan-token hop must fail the previous-output token
    ///      check (the V2 borrower hooks expect outToken == loanToken).
    function test_LendHook_PrevIntoLoanTokenHop_RevertsTokenMismatch() public {
        MorphoBorrowHookV2 borrowV2 = new MorphoBorrowHookV2(address(mockMorpho));

        bytes memory data = _encodeLendData(false);
        lendHook.preExecute(address(0), address(this), data);
        lendHook.postExecute(address(0), address(this), data);
        assertTrue(lendHook.getOutToken(address(this)) != loanToken);

        // V2 borrow (230 bytes): LOAN header (singleton) + market + amount1 + amount2 + usePrev=true + lltv + reserved
        bytes memory v2 = abi.encodePacked(
            _header(),
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            uint256(1),
            uint256(0),
            true,
            lltv,
            uint8(0)
        );
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        borrowV2.build(address(lendHook), address(this), v2);
    }

    function test_BorrowHookB_GetOutToken() public {
        bytes memory data = _encodeBorrowData(false);
        // preExecute: loanToken balance = 0
        borrowHookB.preExecute(address(0), address(this), data);
        // simulate borrow receiving loan tokens
        deal(loanToken, address(this), amount);
        borrowHookB.postExecute(address(0), address(this), data);
        assertEq(borrowHookB.getOutToken(address(this)), loanToken);
    }

    function test_RepayHook_GetOutToken() public {
        bytes memory data = _encodeRepayData(false, false);
        // deal loan tokens to account before repay
        deal(loanToken, address(this), amount);
        repayHook.preExecute(address(0), address(this), data);
        // simulate repay consuming loan tokens
        deal(loanToken, address(this), 0);
        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.getOutToken(address(this)), loanToken);
    }

    function test_WithdrawHook_GetOutToken() public {
        bytes memory data =
            _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        // preExecute: loanToken balance = 0
        withdrawHook.preExecute(address(0), address(this), data);
        // simulate withdraw receiving loan tokens
        deal(loanToken, address(this), amount);
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.getOutToken(address(this)), loanToken);
    }

    function test_SupplyHook_GetOutToken() public {
        bytes memory data = _encodeSupplyData(false);
        // deal collateral tokens to account before supply
        deal(collateralToken, address(this), amount);
        supplyHook.preExecute(address(0), address(this), data);
        // simulate supply consuming collateral tokens
        deal(collateralToken, address(this), 0);
        supplyHook.postExecute(address(0), address(this), data);
        assertEq(supplyHook.getOutToken(address(this)), collateralToken);
    }

    function test_BorrowHook_GetOutToken() public {
        bytes memory data = _encodeBorrowData(false);
        // deal collateral tokens to account before supply+borrow
        deal(collateralToken, address(this), amount);
        borrowHook.preExecute(address(0), address(this), data);
        // simulate supply consuming collateral tokens
        deal(collateralToken, address(this), 0);
        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.getOutToken(address(this)), collateralToken);
    }

    function test_RepayAndWithdrawHook_GetOutToken() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        // preExecute: collateralToken balance = 0
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        // simulate withdraw receiving collateral tokens back
        deal(collateralToken, address(this), amount);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.getOutToken(address(this)), collateralToken);
    }
}
