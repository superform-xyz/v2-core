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
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
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
import { BaseMorphoLoanHook } from "../../../../src/hooks/loan/morpho/BaseMorphoLoanHook.sol";

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
        assertEq(uint256(lendHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
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

    function test_LendHook_Build_RevertIf_InvalidAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
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
                address(0), address(collateralToken), address(mockOracle), address(mockIRM), amount, lltv, false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidCollateralToken() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(0), address(mockOracle), address(mockIRM), amount, lltv, false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidOracle() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(collateralToken), address(0), address(mockIRM), amount, lltv, false
            )
        );
    }

    function test_LendHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(collateralToken), address(mockOracle), address(0), amount, lltv, false
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

    function test_SupplyHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.build(
            address(0),
            address(this),
            abi.encodePacked(
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
        bytes memory data = _encodeWithdrawData(
            loanToken,
            collateralToken,
            address(mockOracle),
            address(mockIRM),
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
        bytes memory data = _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, 0, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        withdrawHook.build(address(0), address(this), data);
    }

    function test_WithdrawHook_Build_RevertIf_InvalidAddresses() public {
        bytes memory data = _encodeWithdrawData(
            address(0),
            collateralToken,
            address(mockOracle),
            address(mockIRM),
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
            lltv,
            amount,
            0
        );
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

        bytes memory data = _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);

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
        bytes memory data = _encodeWithdrawData(loanToken, collateralToken, address(mockOracle), address(mockIRM), lltv, amount, amount);
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
            loanToken, collateralToken, address(zeroOracle), address(mockIRM), amount, lltvRatio, false, lltv, false
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
        bytes memory data = _encodeWithdrawData(address(0), collateralToken, address(mockOracle), address(mockIRM), lltv, amount, 0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        withdrawHook.inspect(data);
    }

    function test_BorrowHookB_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHookB.inspect(
            abi.encodePacked(
                address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltvRatio, false, lltv, false
            )
        );
    }

    function test_SupplyAndBorrowHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        borrowHook.inspect(
            abi.encodePacked(
                address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltvRatio, false, lltv, false
            )
        );
    }

    function test_SupplyHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        supplyHook.inspect(
            abi.encodePacked(address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false)
        );
    }

    function test_LendHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        lendHook.inspect(
            abi.encodePacked(address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false)
        );
    }

    function test_RepayHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.inspect(
            abi.encodePacked(
                address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false, false
            )
        );
    }

    function test_RepayAndWithdrawHook_Inspector_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.inspect(
            abi.encodePacked(
                address(0), collateralToken, address(mockOracle), address(mockIRM), amount, lltv, false, false
            )
        );
    }

    function test_RepayHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(collateralToken), address(mockOracle), address(0), amount, lltv, false, false
            )
        );
    }

    function test_RepayAndWithdrawHook_Build_RevertIf_InvalidIrm() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayAndWithdrawHook.build(
            address(0),
            address(this),
            abi.encodePacked(
                address(loanToken), address(collateralToken), address(mockOracle), address(0), amount, lltv, false, false
            )
        );
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
        uint256 _lltv,
        uint256 _assets,
        uint256 _shares
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(_loanToken, _collateralToken, _oracle, _irm, _lltv, _assets, _shares);
    }

    function _encodeBorrowOnlyData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken, collateralToken, address(mockOracle), MORPHO_IRM, amount, lltvRatio, usePrevHook, lltv, false
        );
    }

    function _encodeLendData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            loanToken, collateralToken, address(mockOracle), address(mockIRM), amount, lltv, usePrevHook
        );
    }
}
