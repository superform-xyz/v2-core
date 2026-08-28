// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { ISuperHookInflowOutflow } from "../../../src/interfaces/ISuperHook.sol";

// Hooks under test
import { BaseLoanHookV2 } from "../../../src/hooks/loan/BaseLoanHookV2.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { BaseAaveV4LoanHookV2 } from "../../../src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol";
import { AaveV3SupplyAndBorrowHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHookV2.sol";
import { AaveV3RepayHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3RepayHookV2.sol";
import { AaveV3RepayAndWithdrawHookV2 } from "../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHookV2.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";

/// @title LoanHooksV2SizingIntegration
/// @notice Fork-based tests to prove the V2 loan hook sizing interface, inspectors and build-time
///         provider bindings match actual protocol data layouts.
///         Uses real mainnet addresses (Morpho Blue singleton, Aave V3 Core Pool, Aave V4 Main
///         Spoke) to verify decode/replace works with production-realistic data and that
///         provider-state validations (reserve/token binding, zero-debt guards) hold against the
///         real deployments.
contract LoanHooksV2SizingIntegration is Helpers {
    // ──────── Fork ────────
    uint256 public forkId;
    /// @dev Post Aave V4 launch so the real Spoke exists on the fork
    uint256 public constant FORK_BLOCK = 24_884_274;

    // ──────── Hooks ────────
    MorphoSupplyAndBorrowHookV2 morphoOpen;
    MorphoRepayHookV2 morphoRepay;
    MorphoRepayAndWithdrawHookV2 morphoClose;
    AaveV3SupplyAndBorrowHookV2 aaveV3Open;
    AaveV3RepayHookV2 aaveV3Repay;
    AaveV3RepayAndWithdrawHookV2 aaveV3Close;
    AaveV4SupplyAndBorrowHookV2 aaveV4Open;
    AaveV4RepayHookV2 aaveV4Repay;
    AaveV4RepayAndWithdrawHookV2 aaveV4Close;

    // ──────── Real addresses ────────
    address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Core Pool
    address constant AAVE_V4_SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485; // Main Spoke

    // Tokens
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // Morpho market params (WBTC collateral / USDC loan market)
    address constant MORPHO_ORACLE_WBTC = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
    address constant MORPHO_IRM_WBTC = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 constant MORPHO_LLTV = 86e16; // 86%

    // Aave V4 Main Spoke reserve ids
    uint256 constant WETH_RESERVE_ID = 0;
    uint256 constant USDC_RESERVE_ID = 7;

    uint256 constant COLLATERAL_AMOUNT = 1e8; // 1 WBTC / placeholder collateral leg
    uint256 constant BORROW_AMOUNT = 750e6; // 750 USDC

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        // Deploy hooks with real constructor args
        morphoOpen = new MorphoSupplyAndBorrowHookV2(MORPHO_BLUE);
        morphoRepay = new MorphoRepayHookV2(MORPHO_BLUE);
        morphoClose = new MorphoRepayAndWithdrawHookV2(MORPHO_BLUE);
        aaveV3Open = new AaveV3SupplyAndBorrowHookV2();
        aaveV3Repay = new AaveV3RepayHookV2();
        aaveV3Close = new AaveV3RepayAndWithdrawHookV2();
        aaveV4Open = new AaveV4SupplyAndBorrowHookV2();
        aaveV4Repay = new AaveV4RepayHookV2();
        aaveV4Close = new AaveV4RepayAndWithdrawHookV2();
    }

    /*//////////////////////////////////////////////////////////////
                        DATA BUILDERS (V2 LAYOUTS)
    //////////////////////////////////////////////////////////////*/

    /// @dev Morpho V2 layout — exact 230 bytes
    function _morphoData(uint256 a1, uint256 a2, bool usePrev) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            bytes32(0),
            address(0),
            USDC,
            WBTC,
            MORPHO_ORACLE_WBTC,
            MORPHO_IRM_WBTC,
            a1,
            a2,
            usePrev,
            MORPHO_LLTV,
            uint8(0)
        );
        assertEq(data.length, 230);
    }

    /// @dev Aave V3 V2 layout — exact 178 bytes
    function _aaveV3Data(uint256 a1, uint256 a2, bool usePrev) internal pure returns (bytes memory data) {
        data = abi.encodePacked(bytes32(0), address(0), USDC, WETH, AAVE_V3_POOL, uint8(2), a1, a2, usePrev);
        assertEq(data.length, 178);
    }

    /// @dev Aave V4 V2 layout — exact 241 bytes
    function _aaveV4Data(
        uint256 supplyReserveId,
        uint256 borrowReserveId,
        uint256 a1,
        bool usePrev,
        uint256 a2
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            bytes32(0), address(0), USDC, WETH, AAVE_V4_SPOKE, supplyReserveId, borrowReserveId, a1, a2, usePrev
        );
        assertEq(data.length, 241);
    }

    /*//////////////////////////////////////////////////////////////
              MORPHO V2: real market decode/replace/inspect
    //////////////////////////////////////////////////////////////*/

    /// @dev Composite two-slot round-trip with the real WBTC/USDC market — all identity fields preserved
    function test_Fork_MorphoV2_Open_RealMarket_DecodeReplace() public view {
        bytes memory data = _morphoData(COLLATERAL_AMOUNT, BORROW_AMOUNT, false);

        uint256[] memory amounts = morphoOpen.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], COLLATERAL_AMOUNT);
        assertEq(amounts[1], BORROW_AMOUNT);

        bytes memory replaced = morphoOpen.replaceCalldataAmounts(data, _dualAmounts(5e8, 1500e6));
        uint256[] memory newAmounts = morphoOpen.decodeAmounts(replaced);
        assertEq(newAmounts[0], 5e8);
        assertEq(newAmounts[1], 1500e6);

        // All real market identity fields preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), USDC, "loanToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), WBTC, "collateralToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 92), MORPHO_ORACLE_WBTC, "oracle mismatch");
        assertEq(BytesLib.toAddress(replaced, 112), MORPHO_IRM_WBTC, "irm mismatch");
        assertEq(BytesLib.toUint256(replaced, 197), MORPHO_LLTV, "lltv mismatch");
        assertEq(uint8(replaced[229]), 0, "reserved byte mismatch");
    }

    /// @dev Standalone repay replaces the primary slot only; reserved secondary stays zero
    function test_Fork_MorphoV2_Repay_RealMarket_SingleSlot() public {
        bytes memory data = _morphoData(BORROW_AMOUNT, 0, false);

        assertEq(morphoRepay.decodeAmounts(data).length, 1);
        assertEq(morphoRepay.decodeAmounts(data)[0], BORROW_AMOUNT);

        bytes memory replaced = morphoRepay.replaceCalldataAmounts(data, _singleAmount(999e6));
        assertEq(morphoRepay.decodeAmounts(replaced)[0], 999e6);
        assertEq(BytesLib.toUint256(replaced, 164), 0, "reserved secondary must stay zero");

        vm.expectRevert();
        morphoRepay.replaceCalldataAmounts(data, _dualAmounts(1, 2));
    }

    /// @dev Roles: composite [IN/TOKEN, OUT/TOKEN]; standalone [IN/TOKEN]
    function test_Fork_MorphoV2_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = morphoOpen.amountRoles("");
        assertEq(meta.length, 2);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint8(meta[1].dir), uint8(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint8(meta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));

        ISuperHookInflowOutflow.AmountMeta[] memory repayMeta = morphoRepay.amountRoles("");
        assertEq(repayMeta.length, 1);
        assertEq(uint8(repayMeta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(repayMeta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    /// @dev Inspect binds the full real market identity and ignores amount changes
    function test_Fork_MorphoV2_Inspect_RealMarket() public view {
        bytes memory expected =
            abi.encodePacked(MORPHO_BLUE, USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, MORPHO_LLTV);

        assertEq(morphoOpen.inspect(_morphoData(COLLATERAL_AMOUNT, BORROW_AMOUNT, false)), expected);
        assertEq(morphoRepay.inspect(_morphoData(BORROW_AMOUNT, 0, false)), expected);
        assertEq(morphoClose.inspect(_morphoData(BORROW_AMOUNT, COLLATERAL_AMOUNT, false)), expected);

        // amounts do not affect the inspected identity
        assertEq(morphoOpen.inspect(_morphoData(1, 2, true)), expected);
    }

    /// @dev Zero-debt guard evaluated against the real singleton: this account has no Morpho position
    function test_Fork_MorphoV2_Repay_RealMarket_ZeroDebtReverts() public {
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        morphoRepay.build(address(0), address(this), _morphoData(BORROW_AMOUNT, 0, false));

        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        morphoClose.build(address(0), address(this), _morphoData(BORROW_AMOUNT, COLLATERAL_AMOUNT, false));
    }

    /// @dev Open build against the real singleton produces the documented execution shape
    function test_Fork_MorphoV2_Open_RealMarket_Build() public view {
        // pre + approve(0) + approve(amount) + supplyCollateral + borrow + approve(0) + post
        assertEq(
            morphoOpen.build(address(0), address(this), _morphoData(COLLATERAL_AMOUNT, BORROW_AMOUNT, false)).length, 7
        );
    }

    /*//////////////////////////////////////////////////////////////
              AAVE V3 V2: real pool decode/replace/inspect
    //////////////////////////////////////////////////////////////*/

    function test_Fork_AaveV3V2_Open_RealPool_DecodeReplace() public view {
        bytes memory data = _aaveV3Data(1e18, BORROW_AMOUNT, false);

        uint256[] memory amounts = aaveV3Open.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1e18);
        assertEq(amounts[1], BORROW_AMOUNT);

        bytes memory replaced = aaveV3Open.replaceCalldataAmounts(data, _dualAmounts(2e18, 900e6));
        assertEq(aaveV3Open.decodeAmounts(replaced)[0], 2e18);
        assertEq(aaveV3Open.decodeAmounts(replaced)[1], 900e6);

        // Real pool/token identity preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), USDC, "loanToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), WETH, "collateralToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 92), AAVE_V3_POOL, "pool mismatch");
        assertEq(BytesLib.toUint8(replaced, 112), 2, "rate mode mismatch");
    }

    function test_Fork_AaveV3V2_Repay_RealPool_SingleSlot() public {
        bytes memory data = _aaveV3Data(BORROW_AMOUNT, 0, false);

        assertEq(aaveV3Repay.decodeAmounts(data).length, 1);
        assertEq(aaveV3Repay.decodeAmounts(data)[0], BORROW_AMOUNT);

        bytes memory replaced = aaveV3Repay.replaceCalldataAmounts(data, _singleAmount(111e6));
        assertEq(aaveV3Repay.decodeAmounts(replaced)[0], 111e6);
        assertEq(BytesLib.toUint256(replaced, 145), 0, "reserved secondary must stay zero");
        assertEq(BytesLib.toAddress(replaced, 92), AAVE_V3_POOL, "pool mismatch");

        vm.expectRevert();
        aaveV3Repay.replaceCalldataAmounts(data, _dualAmounts(1, 2));
    }

    function test_Fork_AaveV3V2_Inspect_RealPool() public view {
        bytes memory expected = abi.encodePacked(AAVE_V3_POOL, USDC, WETH, uint8(2));

        assertEq(aaveV3Open.inspect(_aaveV3Data(1e18, BORROW_AMOUNT, false)), expected);
        assertEq(aaveV3Repay.inspect(_aaveV3Data(BORROW_AMOUNT, 0, false)), expected);
        assertEq(aaveV3Close.inspect(_aaveV3Data(BORROW_AMOUNT, 1e18, false)), expected);
        assertEq(aaveV3Open.inspect(_aaveV3Data(1, 2, true)), expected);
    }

    /// @dev Zero-debt guard evaluated against the real Core Pool's variable debt token
    function test_Fork_AaveV3V2_Repay_RealPool_ZeroDebtReverts() public {
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        aaveV3Repay.build(address(0), address(this), _aaveV3Data(BORROW_AMOUNT, 0, false));

        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        aaveV3Close.build(address(0), address(this), _aaveV3Data(BORROW_AMOUNT, 1e18, false));
    }

    function test_Fork_AaveV3V2_Open_RealPool_Build() public view {
        // pre + approve(0) + approve(amount) + supply + borrow + approve(0) + post
        assertEq(aaveV3Open.build(address(0), address(this), _aaveV3Data(1e18, BORROW_AMOUNT, false)).length, 7);
    }

    /*//////////////////////////////////////////////////////////////
              AAVE V4 V2: real spoke binding + decode/replace
    //////////////////////////////////////////////////////////////*/

    function test_Fork_AaveV4V2_Open_RealSpoke_DecodeReplace() public view {
        bytes memory data = _aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, false, BORROW_AMOUNT);

        uint256[] memory amounts = aaveV4Open.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1e18);
        assertEq(amounts[1], BORROW_AMOUNT);

        bytes memory replaced = aaveV4Open.replaceCalldataAmounts(data, _dualAmounts(3e18, 100e6));
        assertEq(aaveV4Open.decodeAmounts(replaced)[0], 3e18);
        assertEq(aaveV4Open.decodeAmounts(replaced)[1], 100e6);

        // Real spoke/token/reserve identity preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), USDC, "loanToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), WETH, "collateralToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 92), AAVE_V4_SPOKE, "spoke mismatch");
        assertEq(BytesLib.toUint256(replaced, 112), WETH_RESERVE_ID, "supplyReserveId mismatch");
        assertEq(BytesLib.toUint256(replaced, 144), USDC_RESERVE_ID, "borrowReserveId mismatch");
    }

    function test_Fork_AaveV4V2_Repay_RealSpoke_SingleSlot() public {
        bytes memory data = _aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, BORROW_AMOUNT, false, 0);

        assertEq(aaveV4Repay.decodeAmounts(data).length, 1);
        assertEq(aaveV4Repay.decodeAmounts(data)[0], BORROW_AMOUNT);

        bytes memory replaced = aaveV4Repay.replaceCalldataAmounts(data, _singleAmount(42e6));
        assertEq(aaveV4Repay.decodeAmounts(replaced)[0], 42e6);
        assertEq(BytesLib.toUint256(replaced, 208), 0, "reserved secondary must stay zero");
        assertEq(BytesLib.toUint256(replaced, 112), WETH_RESERVE_ID, "supplyReserveId mismatch");
        assertEq(BytesLib.toUint256(replaced, 144), USDC_RESERVE_ID, "borrowReserveId mismatch");

        vm.expectRevert();
        aaveV4Repay.replaceCalldataAmounts(data, _dualAmounts(1, 2));
    }

    function test_Fork_AaveV4V2_Inspect_RealSpoke() public view {
        bytes memory expected = abi.encodePacked(AAVE_V4_SPOKE, USDC, WETH, WETH_RESERVE_ID, USDC_RESERVE_ID);

        assertEq(
            aaveV4Open.inspect(_aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, false, BORROW_AMOUNT)), expected
        );
        assertEq(aaveV4Repay.inspect(_aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, BORROW_AMOUNT, false, 0)), expected);
        assertEq(
            aaveV4Close.inspect(_aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, BORROW_AMOUNT, false, 1e18)), expected
        );
    }

    /// @dev Reserve/token binding validated against the REAL Spoke's getReserve().underlying:
    ///      correct ids pass the binding (open build succeeds), swapped ids revert
    function test_Fork_AaveV4V2_RealSpoke_ReserveBinding() public {
        // Correct binding: WETH reserve 0 = collateral, USDC reserve 7 = loan → open build succeeds
        // pre + approve(0) + approve(amount) + supply + setUsingAsCollateral + borrow + approve(0) + post
        assertEq(
            aaveV4Open.build(
                address(0), address(this), _aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, false, BORROW_AMOUNT)
            )
            .length,
            8
        );

        // Swapped reserve ids: real spoke resolves reserve 7 → USDC != WETH collateral → revert
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        aaveV4Open.build(
            address(0), address(this), _aaveV4Data(USDC_RESERVE_ID, WETH_RESERVE_ID, 1e18, false, BORROW_AMOUNT)
        );

        // Borrow-side mismatch only: borrowReserveId 0 resolves to WETH != USDC loan token
        vm.expectRevert(BaseAaveV4LoanHookV2.TOKEN_RESERVE_MISMATCH.selector);
        aaveV4Open.build(
            address(0), address(this), _aaveV4Data(WETH_RESERVE_ID, WETH_RESERVE_ID, 1e18, false, BORROW_AMOUNT)
        );
    }

    /// @dev Zero-debt guard evaluated against the real Spoke's getUserDebt
    function test_Fork_AaveV4V2_Repay_RealSpoke_ZeroDebtReverts() public {
        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        aaveV4Repay.build(
            address(0), address(this), _aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, BORROW_AMOUNT, false, 0)
        );

        vm.expectRevert(BaseLoanHookV2.NO_OUTSTANDING_DEBT.selector);
        aaveV4Close.build(
            address(0), address(this), _aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, BORROW_AMOUNT, false, 1e18)
        );
    }

    /*//////////////////////////////////////////////////////////////
              FUZZ: Fork-based with real addresses
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Fork_MorphoV2_Open_RealMarket(uint256 a1, uint256 a2) public view {
        bytes memory data = _morphoData(0, 0, false);
        bytes memory replaced = morphoOpen.replaceCalldataAmounts(data, _dualAmounts(a1, a2));
        assertEq(morphoOpen.decodeAmounts(replaced)[0], a1);
        assertEq(morphoOpen.decodeAmounts(replaced)[1], a2);
        // Real market identity always preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), USDC);
        assertEq(BytesLib.toAddress(replaced, 72), WBTC);
        assertEq(BytesLib.toAddress(replaced, 92), MORPHO_ORACLE_WBTC);
        assertEq(BytesLib.toAddress(replaced, 112), MORPHO_IRM_WBTC);
        assertEq(BytesLib.toUint256(replaced, 197), MORPHO_LLTV);
    }

    function testFuzz_Fork_AaveV3V2_Open_RealPool(uint256 a1, uint256 a2) public view {
        bytes memory data = _aaveV3Data(0, 0, false);
        bytes memory replaced = aaveV3Open.replaceCalldataAmounts(data, _dualAmounts(a1, a2));
        assertEq(aaveV3Open.decodeAmounts(replaced)[0], a1);
        assertEq(aaveV3Open.decodeAmounts(replaced)[1], a2);
        assertEq(BytesLib.toAddress(replaced, 92), AAVE_V3_POOL);
        assertEq(BytesLib.toUint8(replaced, 112), 2);
    }

    function testFuzz_Fork_AaveV4V2_Open_RealSpoke(uint256 a1, uint256 a2) public view {
        bytes memory data = _aaveV4Data(WETH_RESERVE_ID, USDC_RESERVE_ID, 0, false, 0);
        bytes memory replaced = aaveV4Open.replaceCalldataAmounts(data, _dualAmounts(a1, a2));
        assertEq(aaveV4Open.decodeAmounts(replaced)[0], a1);
        assertEq(aaveV4Open.decodeAmounts(replaced)[1], a2);
        assertEq(BytesLib.toAddress(replaced, 92), AAVE_V4_SPOKE);
        assertEq(BytesLib.toUint256(replaced, 112), WETH_RESERVE_ID);
        assertEq(BytesLib.toUint256(replaced, 144), USDC_RESERVE_ID);
    }

    receive() external payable { }
}
