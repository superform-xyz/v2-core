// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

//external
import { console } from "forge-std/console.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { SharesMathLib } from "../../../../src/vendor/morpho/SharesMathLib.sol";
import { Id, IMorphoStaticTyping, MarketParams, Market } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";

// Hooks
import { MorphoBorrowHook } from "../../../../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoRepayHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../../../src/core/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoWithdrawHook } from "../../../../src/core/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { MorphoSupplyHook } from "../../../../src/core/hooks/loan/morpho/MorphoSupplyHook.sol";

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
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

    function setUp() public {
        mockMorpho = new MockMorpho();
        mockIRM = new MockIRM();
        borrowHook = new MorphoSupplyAndBorrowHook(address(mockMorpho));
        repayHook = new MorphoRepayHook(address(mockMorpho));
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(address(mockMorpho));
        withdrawHook = new MorphoWithdrawHook(address(mockMorpho));
        borrowHookB = new MorphoBorrowHook(address(mockMorpho));
        supplyHook = new MorphoSupplyHook(address(mockMorpho));

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
        assertEq(address(withdrawHook.morphoBase()), address(mockMorpho));

        assertEq(address(borrowHookB.morpho()), address(mockMorpho));
        assertEq(uint256(borrowHookB.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(supplyHook.morpho()), address(mockMorpho));
        assertEq(uint256(supplyHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
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
                address(loanToken), address(0), address(mockOracle), MORPHO_IRM, amount, lltvRatio, false, lltv, false
            )
        );
    }

    function test_BorrowHookB_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHookB.build(
            address(0),
            address(this),
            abi.encodePacked(
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
        assertEq(borrowHookB.outAmount(), amount);

        borrowHookB.postExecute(address(0), address(this), data);
        assertEq(borrowHookB.outAmount(), 0);
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

        assertEq(executions.length, 6);

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
                address(loanToken), address(collateralToken), address(0), MORPHO_IRM, amount, lltv, false, false
            )
        );
    }

    function test_BorrowHook_Build_RevertIf_InvalidLoanToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
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
                address(0), address(collateralToken), address(mockOracle), MORPHO_IRM, amount, lltv, false, false
            )
        );
    }

    function test_BorrowHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(0), address(mockOracle), MORPHO_IRM, amount, lltvRatio, false, lltv, false
            )
        );
    }

    function test_SupplyHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(0), address(mockOracle), MORPHO_IRM, amount, lltv, false, false
            )
        );
    }

    function test_BorrowHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        borrowHook.build(
            address(0),
            address(this),
            abi.encodePacked(
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

    function test_RepayHook_Build() public view {
        bytes memory data = _encodeRepayData(false, false);
        Execution[] memory executions = repayHook.build(address(0), address(this), data);

        assertEq(executions.length, 6);

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
                address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false, false
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
                address(loanToken), address(0), address(mockOracle), address(mockIRM), amount, lltv, false, false
            )
        );
    }

    function test_RepayHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(
            address(0),
            address(this),
            abi.encodePacked(
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
                address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false, false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(0), address(mockOracle), address(mockIRM), amount, lltv, false, false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
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

        assertEq(executions.length, 6);
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
        assertEq(borrowHook.outAmount(), amount, "A");

        borrowHook.postExecute(address(0), address(this), data);
        assertEq(borrowHook.outAmount(), 0, "B");
    }

    function test_SupplyHook_PrePostExecute() public {
        bytes memory data = _encodeSupplyData(false);
        deal(address(collateralToken), address(this), amount);
        supplyHook.preExecute(address(0), address(this), data);
        assertEq(supplyHook.outAmount(), amount);

        supplyHook.postExecute(address(0), address(this), data);
        assertEq(supplyHook.outAmount(), 0);
    }

    function test_RepayHook_PrePostExecute() public {
        bytes memory data = _encodeRepayData(false, false);
        repayHook.preExecute(address(0), address(this), data);
        assertEq(repayHook.outAmount(), 0);

        repayHook.postExecute(address(0), address(this), data);
        assertEq(repayHook.outAmount(), 0);
    }

    function test_RepayAndWithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeRepayAndWithdrawData(false, false);
        repayAndWithdrawHook.preExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.outAmount(), 0);

        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.outAmount(), 0);
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
        assertEq(address(withdrawHook.morphoBase()), address(mockMorpho));
    }

    function test_WithdrawHook_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoWithdrawHook(address(0));
    }

    function test_WithdrawHook_Build() public view {
        bytes memory data = _encodeWithdrawData(
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            address(this),
            address(this),
            lltv,
            amount,
            0
        );
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_WithdrawHook_Build_WithShares() public view {
        bytes memory data = _encodeWithdrawData(
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            address(this),
            address(this),
            lltv,
            0,
            amount
        );
        Execution[] memory executions = withdrawHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(mockMorpho));
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_WithdrawHook_Build_RevertIf_ZeroAssetsAndShares() public {
        bytes memory data = _encodeWithdrawData(
            loanToken, collateralToken, address(mockOracle), address(mockIRM), address(this), address(this), lltv, 0, 0
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_InvalidAddresses() public {
        bytes memory data = _encodeWithdrawData(
            address(0),
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            address(this),
            address(this),
            lltv,
            amount,
            0
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Inspector() public view {
        bytes memory data = _encodeWithdrawData(
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            address(this),
            address(this),
            lltv,
            amount,
            0
        );
        bytes memory argsEncoded = withdrawHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_WithdrawHook_PrePostExecute() public {
        bytes memory data = _encodeWithdrawData(
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
            address(this),
            address(this),
            lltv,
            amount,
            0
        );
        withdrawHook.preExecute(address(0), address(this), data);
        assertEq(withdrawHook.outAmount(), 0);
        withdrawHook.postExecute(address(0), address(this), data);
        assertEq(withdrawHook.outAmount(), 0);
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
        assertEq(repayAndWithdrawHook.outAmount(), 0);
        repayAndWithdrawHook.postExecute(address(0), address(this), data);
        assertEq(repayAndWithdrawHook.outAmount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _encodeBorrowData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
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

    function _encodeWithdrawData(
        address _loanToken,
        address _collateralToken,
        address _oracle,
        address _irm,
        address _onBehalf,
        address _recipient,
        uint256 _lltv,
        uint256 _assets,
        uint256 _shares
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _loanToken, _collateralToken, _oracle, _irm, _onBehalf, _recipient, _lltv, _assets, _shares
        );
    }

    function _encodeBorrowOnlyData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken, collateralToken, address(mockOracle), MORPHO_IRM, amount, lltvRatio, usePrevHook, lltv, false
        );
    }
}
