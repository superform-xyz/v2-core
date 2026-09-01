// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Vendor
import { IPool } from "../../../../src/vendor/aave-v3/IPool.sol";
import { IAaveV4Spoke } from "../../../../src/vendor/aave-v4/IAaveV4Spoke.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../../src/vendor/morpho/MorphoBalancesLib.sol";
import { IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams } from "../../../../src/vendor/morpho/IMorpho.sol";

// Hooks under test
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { BaseAaveV3LoanHookV2 } from "../../../../src/hooks/loan/aave-v3/BaseAaveV3LoanHookV2.sol";
import { AaveV3SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHookV2.sol";
import { AaveV3RepayHookV2 } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayHookV2.sol";
import { AaveV3RepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHookV2.sol";
import { AaveV4SupplyAndBorrowHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHookV2.sol";
import { AaveV4RepayHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayHookV2.sol";
import { AaveV4RepayAndWithdrawHookV2 } from "../../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHookV2.sol";

/// @dev Minimal settable previous-hook stub. Only the two ISuperHookResult getters the loan hooks
///      consume are implemented; the provider addresses in hook data stay real.
contract LoanPrevHookStub {
    uint256 internal outAmount;
    address internal outToken;

    function set(address token_, uint256 amount_) external {
        outToken = token_;
        outAmount = amount_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outAmount;
    }

    function getOutToken(address) external view returns (address) {
        return outToken;
    }
}

/// @title LoanHooksV2ForkBranchCoverage
/// @notice Mainnet-fork branch coverage for the V2 loan hooks, complementing
///         LoanHooksV2SizingIntegration (which covers decode/replace/inspect round-trips, positive
///         open builds, reserve binding and the zero-debt guards). Every test runs against the real
///         Morpho Blue singleton, Aave V3 Core Pool and Aave V4 Main Spoke; positions are opened by
///         direct provider calls from this contract (the account is address(this)).
///
/// UNREACHABLE BRANCHES (documented, not forced):
/// - MorphoRepayAndWithdrawHookV2._resolveWithdrawLeg `withdrawAmount == 0` under the
///   type(uint256).max sentinel: the zero-debt guard in _resolveRepayLeg runs first, so reaching
///   the withdraw leg requires borrowShares > 0. On Morpho Blue debt is only healthy against
///   collateral posted on the SAME market (borrow/withdrawCollateral enforce
///   collateral * price * lltv >= debt), so borrowShares > 0 with position collateral == 0 cannot
///   exist (bad-debt realization zeroes the shares together with the collateral). The equivalent
///   branch IS reachable on Aave V3/V4 because debt there can be backed by a DIFFERENT collateral
///   reserve — covered below.
contract LoanHooksV2ForkBranchCoverage is Helpers {
    using MarketParamsLib for MarketParams;

    // ──────── Fork ────────
    uint256 public forkId;
    /// @dev Same fork block as LoanHooksV2SizingIntegration (post Aave V4 launch)
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

    LoanPrevHookStub prevStub;

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

    // Aave V4 Main Spoke reserve ids (verified against the real Spoke at FORK_BLOCK)
    uint256 constant WETH_RESERVE_ID = 0;
    uint256 constant WBTC_RESERVE_ID = 3;
    uint256 constant USDC_RESERVE_ID = 7;

    uint256 constant MAX = type(uint256).max;

    /// @dev Real-token sink for simulated wallet outflows in settle tests
    address constant SINK = address(0xDEAD);

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        morphoOpen = new MorphoSupplyAndBorrowHookV2(MORPHO_BLUE);
        morphoRepay = new MorphoRepayHookV2(MORPHO_BLUE);
        morphoClose = new MorphoRepayAndWithdrawHookV2(MORPHO_BLUE);
        aaveV3Open = new AaveV3SupplyAndBorrowHookV2();
        aaveV3Repay = new AaveV3RepayHookV2();
        aaveV3Close = new AaveV3RepayAndWithdrawHookV2();
        aaveV4Open = new AaveV4SupplyAndBorrowHookV2();
        aaveV4Repay = new AaveV4RepayHookV2();
        aaveV4Close = new AaveV4RepayAndWithdrawHookV2();

        prevStub = new LoanPrevHookStub();
    }

    /*//////////////////////////////////////////////////////////////
                        DATA BUILDERS (V2 LAYOUTS)
    //////////////////////////////////////////////////////////////*/

    /// @dev Morpho V2 raw layout — exact 230 bytes with byte-level control of bool/reserved fields
    function _morphoRaw(
        address loanT,
        address collT,
        address oracle,
        address irm,
        uint256 a1,
        uint256 a2,
        bytes1 usePrev,
        bytes1 reservedByte
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            bytes32(0), address(0), loanT, collT, oracle, irm, a1, a2, usePrev, MORPHO_LLTV, reservedByte
        );
        assertEq(data.length, 230);
    }

    function _morphoData(uint256 a1, uint256 a2, bool usePrev) internal pure returns (bytes memory) {
        return _morphoRaw(
            USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, a1, a2, usePrev ? bytes1(0x01) : bytes1(0x00), 0x00
        );
    }

    /// @dev Aave V3 V2 raw layout — exact 178 bytes
    function _aaveV3Raw(
        address loanT,
        address collT,
        address pool,
        uint8 rateMode,
        uint256 a1,
        uint256 a2,
        bytes1 usePrev
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(bytes32(0), address(0), loanT, collT, pool, rateMode, a1, a2, usePrev);
        assertEq(data.length, 178);
    }

    function _aaveV3Data(uint256 a1, uint256 a2, bool usePrev) internal pure returns (bytes memory) {
        return _aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 2, a1, a2, usePrev ? bytes1(0x01) : bytes1(0x00));
    }

    /// @dev Aave V4 V2 raw layout — exact 241 bytes
    function _aaveV4Raw(
        address loanT,
        address collT,
        address spoke,
        uint256 sid,
        uint256 bid,
        uint256 a1,
        uint256 a2,
        bytes1 usePrev
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(bytes32(0), address(0), loanT, collT, spoke, sid, bid, a1, a2, usePrev);
        assertEq(data.length, 241);
    }

    function _aaveV4Data(uint256 a1, uint256 a2, bool usePrev) internal pure returns (bytes memory) {
        return _aaveV4Raw(
            USDC, WETH, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, a1, a2, usePrev ? bytes1(0x01) : bytes1(0x00)
        );
    }

    function _mp() internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: USDC,
            collateralToken: WBTC,
            oracle: MORPHO_ORACLE_WBTC,
            irm: MORPHO_IRM_WBTC,
            lltv: MORPHO_LLTV
        });
    }

    function _truncate(bytes memory data) internal pure returns (bytes memory out) {
        out = new bytes(data.length - 1);
        for (uint256 i; i < out.length; ++i) {
            out[i] = data[i];
        }
    }

    /*//////////////////////////////////////////////////////////////
                        REAL POSITION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Real Morpho Blue position: 1 WBTC collateral, 5000 USDC debt (safe under 86% lltv).
    ///      Leaves 1 WBTC and 5000 USDC in the wallet.
    function _openMorphoPosition() internal {
        deal(WBTC, address(this), 2e8);
        IERC20(WBTC).approve(MORPHO_BLUE, type(uint256).max);
        IMorphoBase(MORPHO_BLUE).supplyCollateral(_mp(), 1e8, address(this), "");
        IMorphoBase(MORPHO_BLUE).borrow(_mp(), 5000e6, 0, address(this), address(this));
    }

    /// @dev Real Aave V3 Core Pool position: 10 WETH supplied, 5000 USDC variable debt
    function _openAaveV3Position() internal {
        deal(WETH, address(this), 10e18);
        IERC20(WETH).approve(AAVE_V3_POOL, type(uint256).max);
        IPool(AAVE_V3_POOL).supply(WETH, 10e18, address(this), 0);
        IPool(AAVE_V3_POOL).borrow(USDC, 5000e6, 2, 0, address(this));
    }

    /// @dev Real Aave V4 Main Spoke position: 10 WETH supplied to reserve 0 (as collateral),
    ///      5000 USDC borrowed from reserve 7
    function _openAaveV4Position() internal {
        deal(WETH, address(this), 10e18);
        IERC20(WETH).approve(AAVE_V4_SPOKE, type(uint256).max);
        IAaveV4Spoke(AAVE_V4_SPOKE).supply(WETH_RESERVE_ID, 10e18, address(this));
        IAaveV4Spoke(AAVE_V4_SPOKE).setUsingAsCollateral(WETH_RESERVE_ID, true, address(this));
        IAaveV4Spoke(AAVE_V4_SPOKE).borrow(USDC_RESERVE_ID, 5000e6, address(this));
    }

    function _increaseBalance(address token, uint256 delta) internal {
        deal(token, address(this), IERC20(token).balanceOf(address(this)) + delta);
    }

    /*//////////////////////////////////////////////////////////////
              A. STRICT DECODE — data length (checklist 1)
    //////////////////////////////////////////////////////////////*/

    function test_Fork_MorphoV2_Decode_InvalidDataLength() public {
        bytes memory good = _morphoData(1e8, 750e6, false);

        // 229 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        morphoOpen.build(address(0), address(this), _truncate(good));

        // 231 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        morphoOpen.build(address(0), address(this), bytes.concat(good, hex"00"));
    }

    function test_Fork_AaveV3V2_Decode_InvalidDataLength() public {
        bytes memory good = _aaveV3Data(1e18, 750e6, false);

        // 177 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        aaveV3Open.build(address(0), address(this), _truncate(good));

        // 179 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        aaveV3Open.build(address(0), address(this), bytes.concat(good, hex"00"));
    }

    function test_Fork_AaveV4V2_Decode_InvalidDataLength() public {
        bytes memory good = _aaveV4Data(1e18, 750e6, false);

        // 240 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        aaveV4Open.build(address(0), address(this), _truncate(good));

        // 242 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        aaveV4Open.build(address(0), address(this), bytes.concat(good, hex"00"));
    }

    /*//////////////////////////////////////////////////////////////
        A. STRICT DECODE — canonical bool 0x02 (checklist 2)
    //////////////////////////////////////////////////////////////*/

    function test_Fork_MorphoV2_Decode_InvalidBoolValue() public {
        bytes memory data = _morphoRaw(USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1e8, 750e6, 0x02, 0x00);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        morphoOpen.build(address(0), address(this), data);
    }

    function test_Fork_AaveV3V2_Decode_InvalidBoolValue() public {
        bytes memory data = _aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 2, 1e18, 750e6, 0x02);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        aaveV3Open.build(address(0), address(this), data);
    }

    function test_Fork_AaveV4V2_Decode_InvalidBoolValue() public {
        bytes memory data =
            _aaveV4Raw(USDC, WETH, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, 750e6, 0x02);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        aaveV4Open.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
        A. STRICT DECODE — reserved fields (checklist 3 + 4)
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist 3: Morpho reserved byte @229 must be 0x00
    function test_Fork_MorphoV2_Decode_ReservedByteNotZero() public {
        bytes memory data = _morphoRaw(USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1e8, 750e6, 0x00, 0x01);
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        morphoOpen.build(address(0), address(this), data);
    }

    /// @dev Checklist 4: standalone repay must carry a zero amount2 word (offset 164)
    function test_Fork_MorphoV2_Repay_NonzeroReservedAmount2Reverts() public {
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        morphoRepay.build(address(0), address(this), _morphoData(750e6, 1, false));
    }

    /// @dev Checklist 4: offset 145
    function test_Fork_AaveV3V2_Repay_NonzeroReservedAmount2Reverts() public {
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        aaveV3Repay.build(address(0), address(this), _aaveV3Data(750e6, 1, false));
    }

    /// @dev Checklist 4: offset 208
    function test_Fork_AaveV4V2_Repay_NonzeroReservedAmount2Reverts() public {
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        aaveV4Repay.build(address(0), address(this), _aaveV4Data(750e6, 1, false));
    }

    /*//////////////////////////////////////////////////////////////
        A. STRICT DECODE — identity fields (checklist 5 + 6)
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist 5: every Morpho identity field zero-address checked
    function test_Fork_MorphoV2_Decode_ZeroAddressReverts() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        morphoOpen.build(
            address(0),
            address(this),
            _morphoRaw(address(0), WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1e8, 750e6, 0x00, 0x00)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        morphoOpen.build(
            address(0),
            address(this),
            _morphoRaw(USDC, address(0), MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1e8, 750e6, 0x00, 0x00)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        morphoOpen.build(
            address(0), address(this), _morphoRaw(USDC, WBTC, address(0), MORPHO_IRM_WBTC, 1e8, 750e6, 0x00, 0x00)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        morphoOpen.build(
            address(0), address(this), _morphoRaw(USDC, WBTC, MORPHO_ORACLE_WBTC, address(0), 1e8, 750e6, 0x00, 0x00)
        );
    }

    /// @dev Checklist 5: loanToken / collateralToken / pool
    function test_Fork_AaveV3V2_Decode_ZeroAddressReverts() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Raw(address(0), WETH, AAVE_V3_POOL, 2, 1e18, 750e6, 0x00));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Raw(USDC, address(0), AAVE_V3_POOL, 2, 1e18, 750e6, 0x00));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Raw(USDC, WETH, address(0), 2, 1e18, 750e6, 0x00));
    }

    /// @dev Checklist 5: loanToken / collateralToken / spoke
    function test_Fork_AaveV4V2_Decode_ZeroAddressReverts() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV4Open.build(
            address(0),
            address(this),
            _aaveV4Raw(address(0), WETH, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, 750e6, 0x00)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV4Open.build(
            address(0),
            address(this),
            _aaveV4Raw(USDC, address(0), AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, 750e6, 0x00)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV4Open.build(
            address(0),
            address(this),
            _aaveV4Raw(USDC, WETH, address(0), WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, 750e6, 0x00)
        );
    }

    /// @dev Checklist 6: loanToken == collateralToken, one per provider
    function test_Fork_LoanHooksV2_Decode_IdenticalTokensReverts() public {
        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        morphoOpen.build(
            address(0), address(this), _morphoRaw(USDC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1e8, 750e6, 0x00, 0x00)
        );

        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Raw(USDC, USDC, AAVE_V3_POOL, 2, 1e18, 750e6, 0x00));

        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        aaveV4Open.build(
            address(0),
            address(this),
            _aaveV4Raw(USDC, USDC, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1e18, 750e6, 0x00)
        );
    }

    /// @dev Checklist 7: only variable rate mode (2) is valid on Aave V3.2+
    function test_Fork_AaveV3V2_Decode_InvalidRateMode() public {
        vm.expectRevert(BaseAaveV3LoanHookV2.INVALID_RATE_MODE.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 1, 1e18, 750e6, 0x00));

        vm.expectRevert(BaseAaveV3LoanHookV2.INVALID_RATE_MODE.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 0, 1e18, 750e6, 0x00));
    }

    /// @dev Constructor guard on the Morpho V2 base (extra branch, not in existing fork suites)
    function test_Fork_MorphoV2_Constructor_ZeroAddressReverts() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoSupplyAndBorrowHookV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
          B. OPEN AMOUNT RULES via build() (checklist 8)
    //////////////////////////////////////////////////////////////*/

    function test_Fork_MorphoV2_Open_AmountValidation() public {
        // amount2 (borrow) checked first
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoOpen.build(address(0), address(this), _morphoData(1e8, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoOpen.build(address(0), address(this), _morphoData(1e8, MAX, false));

        // then amount1 (collateral)
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoOpen.build(address(0), address(this), _morphoData(0, 750e6, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoOpen.build(address(0), address(this), _morphoData(MAX, 750e6, false));
    }

    function test_Fork_AaveV3V2_Open_AmountValidation() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Data(1e18, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Data(1e18, MAX, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Data(0, 750e6, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV3Open.build(address(0), address(this), _aaveV3Data(MAX, 750e6, false));
    }

    function test_Fork_AaveV4V2_Open_AmountValidation() public {
        // Reserve binding passes (real Spoke resolves reserve 0 → WETH, 7 → USDC) so the amount
        // checks are the ones that revert
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV4Open.build(address(0), address(this), _aaveV4Data(1e18, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV4Open.build(address(0), address(this), _aaveV4Data(1e18, MAX, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV4Open.build(address(0), address(this), _aaveV4Data(0, 750e6, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV4Open.build(address(0), address(this), _aaveV4Data(MAX, 750e6, false));
    }

    /*//////////////////////////////////////////////////////////////
             C. PREVIOUS-HOOK PIPE (checklist 12-16)
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist 12 (open): usePrev with prevHook == address(0)
    function test_Fork_MorphoV2_Open_PrevHookZeroAddressReverts() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        morphoOpen.build(address(0), address(this), _morphoData(1e8, 750e6, true));
    }

    /// @dev Checklist 12 (repay): needs real debt because the zero-debt guard runs first
    function test_Fork_AaveV3V2_Repay_PrevHookZeroAddressReverts() public {
        _openAaveV3Position();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV3Repay.build(address(0), address(this), _aaveV3Data(100e6, 0, true));
    }

    /// @dev Checklist 12 (close): needs real debt because the zero-debt guard runs first
    function test_Fork_AaveV4V2_Close_PrevHookZeroAddressReverts() public {
        _openAaveV4Position();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        aaveV4Close.build(address(0), address(this), _aaveV4Data(100e6, 1e18, true));
    }

    /// @dev Checklist 13 (open expects the collateral token; stub produces the loan token)
    function test_Fork_MorphoV2_Open_PrevTokenMismatch() public {
        prevStub.set(USDC, 1e8);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        morphoOpen.build(address(prevStub), address(this), _morphoData(1e8, 750e6, true));
    }

    /// @dev Checklist 13 (repay expects the loan token; stub produces the collateral token)
    function test_Fork_AaveV3V2_Repay_PrevTokenMismatch() public {
        _openAaveV3Position();
        prevStub.set(WETH, 100e6);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        aaveV3Repay.build(address(prevStub), address(this), _aaveV3Data(100e6, 0, true));
    }

    /// @dev Checklist 13 (close expects the loan token; stub produces the collateral token)
    function test_Fork_AaveV4V2_Close_PrevTokenMismatch() public {
        _openAaveV4Position();
        prevStub.set(WETH, 100e6);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        aaveV4Close.build(address(prevStub), address(this), _aaveV4Data(100e6, 1e18, true));
    }

    /// @dev Checklist 14: previous hook produced a zero amount
    function test_Fork_MorphoV2_Open_PrevAmountZeroReverts() public {
        prevStub.set(WBTC, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoOpen.build(address(prevStub), address(this), _morphoData(1e8, 750e6, true));
    }

    /// @dev Checklist 15: previous hook produced the reserved type(uint256).max sentinel
    function test_Fork_MorphoV2_Open_PrevAmountMaxReverts() public {
        prevStub.set(WBTC, MAX);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoOpen.build(address(prevStub), address(this), _morphoData(1e8, 750e6, true));
    }

    /// @dev Checklist 16: happy PREV path on open — approve + supplyCollateral encode the stub's
    ///      amount, not the calldata amount
    function test_Fork_MorphoV2_Open_PrevHappyPath() public {
        prevStub.set(WBTC, 777e4);
        Execution[] memory execs =
            morphoOpen.build(address(prevStub), address(this), _morphoData(1e8, 750e6, true));

        // pre + approve(0) + approve(prev) + supplyCollateral(prev) + borrow + approve(0) + post
        assertEq(execs.length, 7);
        assertEq(execs[2].target, WBTC);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (MORPHO_BLUE, 777e4)));
        assertEq(execs[3].target, MORPHO_BLUE);
        assertEq(
            execs[3].callData, abi.encodeCall(IMorphoBase.supplyCollateral, (_mp(), 777e4, address(this), ""))
        );
    }

    /// @dev Happy PREV path on the repay leg (non-sentinel, usePrev=true) with real debt: the
    ///      approve and repay legs encode the stub's amount
    function test_Fork_MorphoV2_Repay_PrevHappyPath() public {
        _openMorphoPosition();
        prevStub.set(USDC, 123e6);
        Execution[] memory execs =
            morphoRepay.build(address(prevStub), address(this), _morphoData(1e6, 0, true));

        // pre + approve(0) + approve(prev) + repay(prev assets) + approve(0) + post
        assertEq(execs.length, 6);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (MORPHO_BLUE, 123e6)));
        assertEq(execs[3].callData, abi.encodeCall(IMorphoBase.repay, (_mp(), 123e6, 0, address(this), "")));
    }

    /*//////////////////////////////////////////////////////////////
        D. decodeUsePrevHookAmount STRICT VIEW (checklist D)
    //////////////////////////////////////////////////////////////*/

    function test_Fork_MorphoV2_DecodeUsePrevHookAmount_Strict() public {
        assertFalse(
            morphoRepay.decodeUsePrevHookAmount(
                _morphoRaw(USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1, 0, 0x00, 0x00)
            )
        );
        assertTrue(
            morphoRepay.decodeUsePrevHookAmount(
                _morphoRaw(USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1, 0, 0x01, 0x00)
            )
        );
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        morphoRepay.decodeUsePrevHookAmount(
            _morphoRaw(USDC, WBTC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, 1, 0, 0x02, 0x00)
        );
    }

    function test_Fork_AaveV3V2_DecodeUsePrevHookAmount_Strict() public {
        assertFalse(aaveV3Repay.decodeUsePrevHookAmount(_aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 2, 1, 0, 0x00)));
        assertTrue(aaveV3Repay.decodeUsePrevHookAmount(_aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 2, 1, 0, 0x01)));
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        aaveV3Repay.decodeUsePrevHookAmount(_aaveV3Raw(USDC, WETH, AAVE_V3_POOL, 2, 1, 0, 0x02));
    }

    function test_Fork_AaveV4V2_DecodeUsePrevHookAmount_Strict() public {
        assertFalse(
            aaveV4Repay.decodeUsePrevHookAmount(
                _aaveV4Raw(USDC, WETH, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1, 0, 0x00)
            )
        );
        assertTrue(
            aaveV4Repay.decodeUsePrevHookAmount(
                _aaveV4Raw(USDC, WETH, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1, 0, 0x01)
            )
        );
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        aaveV4Repay.decodeUsePrevHookAmount(
            _aaveV4Raw(USDC, WETH, AAVE_V4_SPOKE, WETH_RESERVE_ID, USDC_RESERVE_ID, 1, 0, 0x02)
        );
    }

    /*//////////////////////////////////////////////////////////////
        E-17. MAX_WITH_PREV with real debt (checklist 9 + 17)
    //////////////////////////////////////////////////////////////*/

    /// @dev _resolveRepayLeg checks debt first, so real debt is required to reach the sentinel
    ///      + usePrev combination check (verified against the source order)
    function test_Fork_MorphoV2_MaxWithPrevReverts() public {
        _openMorphoPosition();

        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        morphoRepay.build(address(prevStub), address(this), _morphoData(MAX, 0, true));

        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        morphoClose.build(address(prevStub), address(this), _morphoData(MAX, 1e6, true));
    }

    function test_Fork_AaveV3V2_MaxWithPrevReverts() public {
        _openAaveV3Position();

        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        aaveV3Repay.build(address(prevStub), address(this), _aaveV3Data(MAX, 0, true));

        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        aaveV3Close.build(address(prevStub), address(this), _aaveV3Data(MAX, 1e18, true));
    }

    function test_Fork_AaveV4V2_MaxWithPrevReverts() public {
        _openAaveV4Position();

        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        aaveV4Repay.build(address(prevStub), address(this), _aaveV4Data(MAX, 0, true));

        vm.expectRevert(BaseLoanHookV2.MAX_WITH_PREV_NOT_ALLOWED.selector);
        aaveV4Close.build(address(prevStub), address(this), _aaveV4Data(MAX, 1e18, true));
    }

    /*//////////////////////////////////////////////////////////////
        E. WITHDRAW-LEG VALIDATION on close (checklist 10 + 11)
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist 10: close amount2 == 0 (real debt required to reach the withdraw leg).
    ///      Checklist 11 (Morpho): the withdrawAmount==0-under-max branch is UNREACHABLE — debt
    ///      requires collateral on the same market (see contract-level comment) — so only the
    ///      sentinel's POSITIVE resolution is asserted: withdrawCollateral encodes the position's
    ///      full real collateral.
    function test_Fork_MorphoV2_Close_WithdrawLegValidation() public {
        _openMorphoPosition();

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoClose.build(address(0), address(this), _morphoData(100e6, 0, false));

        // amount2 == max resolves to the real position collateral (1 WBTC)
        Execution[] memory execs = morphoClose.build(address(0), address(this), _morphoData(100e6, MAX, false));
        // pre + approve(0) + approve + repay + approve(0) + withdrawCollateral + post
        assertEq(execs.length, 7);
        assertEq(
            execs[5].callData,
            abi.encodeCall(IMorphoBase.withdrawCollateral, (_mp(), 1e8, address(this), address(this)))
        );
    }

    /// @dev Checklist 10 + 11 (Aave V3): reachable zero-supplied branch — debt is backed by WETH
    ///      but the close declares WBTC collateral (aWBTC balance is zero) with the max sentinel
    function test_Fork_AaveV3V2_Close_WithdrawLegValidation() public {
        _openAaveV3Position();

        // amount2 == 0
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV3Close.build(address(0), address(this), _aaveV3Data(100e6, 0, false));

        // Checklist 11: debt > 0 (USDC) but zero aWBTC balance under the max sentinel
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV3Close.build(
            address(0), address(this), _aaveV3Raw(USDC, WBTC, AAVE_V3_POOL, 2, 100e6, MAX, 0x00)
        );

        // Positive sentinel: max passes through to the pool withdraw (Aave resolves it natively)
        Execution[] memory execs = aaveV3Close.build(address(0), address(this), _aaveV3Data(100e6, MAX, false));
        assertEq(execs.length, 7);
        assertEq(execs[5].callData, abi.encodeCall(IPool.withdraw, (WETH, MAX, address(this))));
    }

    /// @dev Checklist 10 + 11 (Aave V4): reachable zero-supplied branch — USDC debt is backed by
    ///      the WETH reserve, but the close declares the (empty) WBTC reserve 3 as the supply side
    function test_Fork_AaveV4V2_Close_WithdrawLegValidation() public {
        _openAaveV4Position();

        // amount2 == 0
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV4Close.build(address(0), address(this), _aaveV4Data(100e6, 0, false));

        // Checklist 11: debt > 0 on reserve 7 but zero supplied balance on reserve 3 (WBTC) under
        // the max sentinel — reserve binding passes because reserve 3's underlying IS WBTC
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        aaveV4Close.build(
            address(0),
            address(this),
            _aaveV4Raw(USDC, WBTC, AAVE_V4_SPOKE, WBTC_RESERVE_ID, USDC_RESERVE_ID, 100e6, MAX, 0x00)
        );

        // Positive sentinel: max passes through to the spoke withdraw (Spoke resolves it natively)
        Execution[] memory execs = aaveV4Close.build(address(0), address(this), _aaveV4Data(100e6, MAX, false));
        assertEq(execs.length, 7);
        assertEq(execs[5].callData, abi.encodeCall(IAaveV4Spoke.withdraw, (WETH_RESERVE_ID, MAX, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
             E-18. FULL-REPAY BUILD PATHS with real debt
    //////////////////////////////////////////////////////////////*/

    /// @dev Morpho full repay: approval == MorphoBalancesLib.expectedBorrowAssets and the repay is
    ///      shares-denominated (0 assets, current borrow shares)
    function test_Fork_MorphoV2_Repay_FullRepayBuild() public {
        _openMorphoPosition();

        uint256 expectedAssets =
            MorphoBalancesLib.expectedBorrowAssets(IMorpho(MORPHO_BLUE), _mp(), address(this));
        (, uint128 shares,) = IMorphoStaticTyping(MORPHO_BLUE).position(_mp().id(), address(this));
        assertGt(shares, 0);

        Execution[] memory execs = morphoRepay.build(address(0), address(this), _morphoData(MAX, 0, false));
        assertEq(execs.length, 6);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (MORPHO_BLUE, expectedAssets)));
        assertEq(
            execs[3].callData,
            abi.encodeCall(IMorphoBase.repay, (_mp(), 0, uint256(shares), address(this), ""))
        );

        // Same full-repay branch via the shared _resolveRepayLeg in the close hook
        Execution[] memory closeExecs =
            morphoClose.build(address(0), address(this), _morphoData(MAX, 1e6, false));
        assertEq(closeExecs.length, 7);
        assertEq(closeExecs[2].callData, abi.encodeCall(IERC20.approve, (MORPHO_BLUE, expectedAssets)));
        assertEq(
            closeExecs[3].callData,
            abi.encodeCall(IMorphoBase.repay, (_mp(), 0, uint256(shares), address(this), ""))
        );
    }

    /// @dev Aave V3 full repay: approval == current variable-debt balance, repay calldata carries
    ///      the max sentinel (Aave resolves it natively)
    function test_Fork_AaveV3V2_Repay_FullRepayBuild() public {
        _openAaveV3Position();

        address vDebt = IPool(AAVE_V3_POOL).getReserveData(USDC).variableDebtTokenAddress;
        uint256 debt = IERC20(vDebt).balanceOf(address(this));
        assertGt(debt, 0);

        Execution[] memory execs = aaveV3Repay.build(address(0), address(this), _aaveV3Data(MAX, 0, false));
        assertEq(execs.length, 6);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (AAVE_V3_POOL, debt)));
        assertEq(execs[3].callData, abi.encodeCall(IPool.repay, (USDC, MAX, 2, address(this))));

        // Same branch in the close hook's own copy
        Execution[] memory closeExecs =
            aaveV3Close.build(address(0), address(this), _aaveV3Data(MAX, 1e18, false));
        assertEq(closeExecs.length, 7);
        assertEq(closeExecs[2].callData, abi.encodeCall(IERC20.approve, (AAVE_V3_POOL, debt)));
        assertEq(closeExecs[3].callData, abi.encodeCall(IPool.repay, (USDC, MAX, 2, address(this))));
    }

    /// @dev Aave V4 full repay: approval == drawn + premium debt, repay calldata carries the max
    ///      sentinel (Spoke resolves it natively)
    function test_Fork_AaveV4V2_Repay_FullRepayBuild() public {
        _openAaveV4Position();

        (uint256 drawn, uint256 premium) = IAaveV4Spoke(AAVE_V4_SPOKE).getUserDebt(USDC_RESERVE_ID, address(this));
        uint256 debt = drawn + premium;
        assertGt(debt, 0);

        Execution[] memory execs = aaveV4Repay.build(address(0), address(this), _aaveV4Data(MAX, 0, false));
        assertEq(execs.length, 6);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (AAVE_V4_SPOKE, debt)));
        assertEq(execs[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (USDC_RESERVE_ID, MAX, address(this))));

        // Same branch in the close hook's own copy
        Execution[] memory closeExecs =
            aaveV4Close.build(address(0), address(this), _aaveV4Data(MAX, 1e18, false));
        assertEq(closeExecs.length, 7);
        assertEq(closeExecs[2].callData, abi.encodeCall(IERC20.approve, (AAVE_V4_SPOKE, debt)));
        assertEq(closeExecs[3].callData, abi.encodeCall(IAaveV4Spoke.repay, (USDC_RESERVE_ID, MAX, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
        E-19. SETTLE BRANCHES via direct preExecute/postExecute
        (shared BaseLoanHookV2 code — exercised on Morpho hooks;
         wallet deltas simulated with real-token transfers)
    //////////////////////////////////////////////////////////////*/

    // ── _settleRepay (19a/19b) ──

    /// @dev 19a: expected spend resolved at preExecute; a smaller actual USDC spend reverts with
    ///      the exact DELTA_MISMATCH(expected, actual) payload
    function test_Fork_SettleRepay_DeltaMismatch() public {
        _openMorphoPosition();
        bytes memory data = _morphoData(100e6, 0, false);

        morphoRepay.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 50e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 100e6, 50e6));
        morphoRepay.postExecute(address(0), address(this), data);
    }

    /// @dev 19b: the loan-token balance INCREASED between snapshot and settle
    function test_Fork_SettleRepay_NegativeBalanceDelta() public {
        _openMorphoPosition();
        bytes memory data = _morphoData(100e6, 0, false);

        morphoRepay.preExecute(address(0), address(this), data);
        _increaseBalance(USDC, 1e6);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        morphoRepay.postExecute(address(0), address(this), data);
    }

    /// @dev _settleRepay success branch: exact spend publishes outAmount/outToken
    function test_Fork_SettleRepay_Success() public {
        _openMorphoPosition();
        bytes memory data = _morphoData(100e6, 0, false);

        morphoRepay.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 100e6);
        morphoRepay.postExecute(address(0), address(this), data);

        // Terminal repay hook publishes outAmount = 0 (spend is not a product); outToken kept
        assertEq(morphoRepay.getOutAmount(address(this)), 0);
        assertEq(morphoRepay.getOutToken(address(this)), USDC);
    }

    // ── _settleOpen (19c) — no provider position needed: preExecute only decodes + snapshots ──

    /// @dev 19c success: collateral out == amount1, loan in == amount2 → publishes borrowed delta
    function test_Fork_SettleOpen_Success() public {
        deal(WBTC, address(this), 1e8);
        bytes memory data = _morphoData(2e7, 100e6, false);

        morphoOpen.preExecute(address(0), address(this), data);
        IERC20(WBTC).transfer(SINK, 2e7);
        _increaseBalance(USDC, 100e6);
        morphoOpen.postExecute(address(0), address(this), data);

        assertEq(morphoOpen.getOutAmount(address(this)), 100e6);
        assertEq(morphoOpen.getOutToken(address(this)), USDC);
    }

    /// @dev 19c: wrong collateral spend → first DELTA_MISMATCH branch of _settleOpen
    function test_Fork_SettleOpen_CollateralDeltaMismatch() public {
        deal(WBTC, address(this), 1e8);
        bytes memory data = _morphoData(2e7, 100e6, false);

        morphoOpen.preExecute(address(0), address(this), data);
        IERC20(WBTC).transfer(SINK, 1e7);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 2e7, 1e7));
        morphoOpen.postExecute(address(0), address(this), data);
    }

    /// @dev 19c: exact collateral spend, wrong loan inflow → second DELTA_MISMATCH branch
    function test_Fork_SettleOpen_LoanDeltaMismatch() public {
        deal(WBTC, address(this), 1e8);
        bytes memory data = _morphoData(2e7, 100e6, false);

        morphoOpen.preExecute(address(0), address(this), data);
        IERC20(WBTC).transfer(SINK, 2e7);
        _increaseBalance(USDC, 50e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 100e6, 50e6));
        morphoOpen.postExecute(address(0), address(this), data);
    }

    /// @dev 19c: loan-token balance DECREASED where an increase was required →
    ///      NEGATIVE_BALANCE_DELTA from _balanceIncrease
    function test_Fork_SettleOpen_NegativeLoanDelta() public {
        deal(WBTC, address(this), 1e8);
        deal(USDC, address(this), 100e6);
        bytes memory data = _morphoData(2e7, 100e6, false);

        morphoOpen.preExecute(address(0), address(this), data);
        IERC20(WBTC).transfer(SINK, 2e7);
        IERC20(USDC).transfer(SINK, 10e6);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        morphoOpen.postExecute(address(0), address(this), data);
    }

    // ── _settleClose (19d) — real Morpho position; preExecute accrues on the REAL singleton ──

    /// @dev 19d success: loan out == expected repay, collateral in == expected withdraw →
    ///      publishes the released collateral delta
    function test_Fork_SettleClose_Success() public {
        _openMorphoPosition(); // wallet: 1 WBTC + 5000 USDC
        bytes memory data = _morphoData(100e6, 5e6, false);

        morphoClose.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 100e6);
        _increaseBalance(WBTC, 5e6);
        morphoClose.postExecute(address(0), address(this), data);

        assertEq(morphoClose.getOutAmount(address(this)), 5e6);
        assertEq(morphoClose.getOutToken(address(this)), WBTC);
    }

    /// @dev 19d: wrong loan spend → first DELTA_MISMATCH branch of _settleClose
    function test_Fork_SettleClose_LoanDeltaMismatch() public {
        _openMorphoPosition();
        bytes memory data = _morphoData(100e6, 5e6, false);

        morphoClose.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 42e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 100e6, 42e6));
        morphoClose.postExecute(address(0), address(this), data);
    }

    /// @dev 19d: exact loan spend, wrong collateral inflow → second DELTA_MISMATCH branch
    function test_Fork_SettleClose_CollateralDeltaMismatch() public {
        _openMorphoPosition();
        bytes memory data = _morphoData(100e6, 5e6, false);

        morphoClose.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 100e6);
        _increaseBalance(WBTC, 1e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 5e6, 1e6));
        morphoClose.postExecute(address(0), address(this), data);
    }

    receive() external payable { }
}
