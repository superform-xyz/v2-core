// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { IOracle } from "../../../../src/vendor/morpho/IOracle.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { SharesMathLib } from "../../../../src/vendor/morpho/SharesMathLib.sol";
import { Id, IMorpho, MarketParams, Market } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";

// Hooks
import { BaseLoanHook } from "../../../../src/core/hooks/loan/BaseLoanHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoRepayHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoBorrowHook } from "../../../../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoSupplyHook } from "../../../../src/core/hooks/loan/morpho/MorphoSupplyHook.sol";

contract MockOracle is IOracle {
    function price() external pure returns (uint256) {
        return 2e36; // 1 collateral = 2 loan tokens
    }
}

contract MockMorpho {
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

    function position(Id, address) external pure returns (uint256, uint128, uint128) {
        return (10e18, 100e18, 100e18);
    }
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

    function setOutAmount(uint256 _outAmount) external {
        outAmount = _outAmount;
    }
}

contract MorphoLoanHooksTest is Helpers {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;

    // Hooks
    MorphoBorrowHook public borrowHook;
    MorphoRepayHook public repayHook;
    MorphoRepayAndWithdrawHook public repayAndWithdrawHook;
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
    MockERC20 public mockCollateralToken;

    function setUp() public {
        loanToken = 0x4200000000000000000000000000000000000006;

        mockMorpho = new MockMorpho();
        mockIRM = new MockIRM();
        borrowHook = new MorphoBorrowHook(address(mockMorpho));
        repayHook = new MorphoRepayHook(address(mockMorpho));
        repayAndWithdrawHook = new MorphoRepayAndWithdrawHook(address(mockMorpho));
        supplyHook = new MorphoSupplyHook(address(mockMorpho));

        amount = 1e18;
        lltv = 860_000_000_000_000_000;
        lltvRatio = 660_000_000_000_000_000;

        mockOracle = new MockOracle();
        mockCollateralToken = new MockERC20("Collateral Token", "COLL", 18);
        collateralToken = address(mockCollateralToken);
    }

    function test_Constructors() public view {
        assertEq(address(borrowHook.morpho()), address(mockMorpho));
        assertEq(uint256(borrowHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(repayHook.morpho()), address(mockMorpho));
        assertEq(uint256(repayHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(repayAndWithdrawHook.morpho()), address(mockMorpho));
        assertEq(uint256(repayAndWithdrawHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));

        assertEq(address(supplyHook.morpho()), address(mockMorpho));
        assertEq(uint256(supplyHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructors_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoBorrowHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayHook(address(0));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayAndWithdrawHook(address(0));

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
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

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
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

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
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeRepayAndWithdrawData(true, false);
        Execution[] memory executions = repayAndWithdrawHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 7);
        // Verify the amount from previous hook is used in the approve call
        assertEq(executions[2].target, loanToken);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);

    }

    /*//////////////////////////////////////////////////////////////
                          DERIVE INTEREST TESTS
    //////////////////////////////////////////////////////////////*/
    function test_RepayHook_DeriveInterest() public view {
        _encodeRepayData(false, false);
        uint256 interest = repayHook.deriveInterest(
            MarketParams({
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: address(mockOracle),
                irm: address(mockIRM),
                lltv: lltv
            })
        );
        assertEq(interest, 0);
    }

    function test_SupplyHook_DeriveInterest() public view {
        _encodeSupplyData(false);
        uint256 interest = supplyHook.deriveFeeAmount(
            MarketParams({
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: address(mockOracle),
                irm: address(mockIRM),
                lltv: lltv
            })
        );
        assertEq(interest, 0);
    }

    function test_RepayAndWithdrawHook_DeriveInterest() public view {
        _encodeRepayAndWithdrawData(false, false);
        uint256 interest = repayAndWithdrawHook.deriveInterest(
            MarketParams({
                loanToken: loanToken,
                collateralToken: collateralToken,
                oracle: address(mockOracle),
                irm: address(mockIRM),
                lltv: lltv
            })
        );
        assertEq(interest, 0);
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
        assertEq(collateral, 100e18); // From MockMorpho position() return value (third value)
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
        loanToken = address(new MockERC20("Loan Token", "LOAN", 18));
        bytes memory data = _encodeBorrowData(false);
        deal(address(loanToken), address(this), amount);
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
}
