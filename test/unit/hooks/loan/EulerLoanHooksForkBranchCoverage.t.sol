// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Vendor
import { IEVC } from "../../../../src/vendor/euler/IEVC.sol";
import { IEVault } from "../../../../src/vendor/euler/IEVault.sol";

// Hooks under test
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { BaseLoanHookV2 } from "../../../../src/hooks/loan/BaseLoanHookV2.sol";
import { BaseEulerLoanHook } from "../../../../src/hooks/loan/euler/BaseEulerLoanHook.sol";
import {
    EulerDepositCollateralAndBorrowHook
} from "../../../../src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol";
import { EulerRepayHook } from "../../../../src/hooks/loan/euler/EulerRepayHook.sol";
import { EulerRepayAndWithdrawHook } from "../../../../src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol";
import { ISuperHookInflowOutflow } from "../../../../src/interfaces/ISuperHook.sol";

/// @dev EVK view the audited vendor interface intentionally omits but the assertions need
interface IEVaultForkViews {
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @dev Minimal settable previous-hook stub. Only the two ISuperHookResult getters the loan hooks
///      consume are implemented; the provider addresses in hook data stay real.
contract EulerPrevHookStub {
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

/// @title EulerLoanHooksForkBranchCoverage
/// @notice Base-fork branch coverage for the three Euler EVK/EVC loan hooks, complementing the
///         E2E suite (test/integration/euler/EulerLoanHooksFork.t.sol — exact open, chained open,
///         idempotent enables, partial/full repay + close, its 6-revert matrix and the ERC-165
///         legacy fallback). Every test runs against the real Euler (Clearstar) deployment on
///         Base; positions are opened by direct provider calls from this contract (the account is
///         address(this)). build() always wraps the hook executions with preExecute/postExecute,
///         so asserted lengths are hookExecutions + 2.
///
/// UNREACHABLE BRANCHES (documented, not forced):
/// - BaseEulerLoanHook._validateVault VAULT_EVC_MISMATCH (both sides): with the calldata evc
///   pinned to the canonical singleton (EVC_NOT_CANONICAL guards it first) and the vault required
///   to be an eVaultFactory proxy (UNTRUSTED_VAULT guards that), every reachable vault reports the
///   canonical EVC on real Base state (0x7F321498A801A191a93C840750ed637149dDf8D0, 384 proxies at
///   the pin block, all reporting 0x5301c7dD20bD945D2013b48ed0DEE3A284ca8989). The check survives
///   as defense in depth only; the EVC_NOT_CANONICAL and UNTRUSTED_VAULT guards are covered below.
/// - BaseEulerLoanHook._validateControllerState `controllers.length > 1`: outside a
///   checks-deferred EVC batch the real EVC settles every direct enableController call with an
///   immediate account status check that reverts while more than one controller is enabled, so
///   two controllers can never persist to the (non-batched) build/preExecute view. The
///   `length == 1 && controllers[0] != controllerVault` arm is covered by the E2E suite.
/// - BaseEulerLoanHook._validateOpenMarket `LTVBorrow != 0 && LTVLiquidation == 0`: EVK
///   governance sets LTVLiquidation >= LTVBorrow (ramping only ever lowers LTVLiquidation towards
///   a target that still bounds LTVBorrow), so a real vault with a nonzero borrow LTV and a zero
///   liquidation LTV does not exist at the pin block. The `LTVBorrow == 0` short-circuit arm is
///   covered below with a real unlinked vault (eEURC), and the all-nonzero arm by every
///   successful open.
contract EulerLoanHooksForkBranchCoverage is Helpers {
    // ──────── Fork ────────
    uint256 public forkId;
    /// @dev Same pinned Base block as the E2E suite (verified liquidity + LTV configuration)
    uint256 public constant FORK_BLOCK = 50_550_000;

    // ──────── Hooks ────────
    EulerDepositCollateralAndBorrowHook openHook;
    EulerRepayHook repayHook;
    EulerRepayAndWithdrawHook closeHook;

    EulerPrevHookStub prevStub;

    // ──────── Real addresses (Euler Clearstar on Base, verified at the pin block) ────────
    address constant EVC = 0x5301c7dD20bD945D2013b48ed0DEE3A284ca8989;
    address constant EVAULT_FACTORY = 0x7F321498A801A191a93C840750ed637149dDf8D0;
    address constant EWETH_VAULT = 0x859160DB5841E5cfB8D3f144C6b3381A85A4b410; // asset WETH
    address constant EUSDC_VAULT = 0x0A1a3b5f2041F33522C4efc754a7D096f880eE16; // asset USDC
    /// @dev EVault factory proxyList(5): real EVK vault whose collateral is NOT configured on
    ///      eUSDC — eUSDC.LTVBorrow(eEURC) == 0 and eUSDC.LTVLiquidation(eEURC) == 0 (verified)
    address constant EEURC_VAULT = 0x9ECD9fbbdA32b81dee51AdAed28c5C5039c87117; // asset EURC

    // Tokens
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42; // eEURC underlying

    // Position sizes — well inside verified liquidity (eUSDC cash ~20,559e6, eWETH maxDeposit
    // ~1.115e22) and healthy under the 86% borrow LTV
    uint256 constant DEPOSIT_WETH = 5e18;
    uint256 constant BORROW_USDC = 2000e6;

    uint256 constant MAX = type(uint256).max;
    bytes32 constant CONFIG_ID = bytes32(uint256(0xC0FFEE));

    /// @dev Real-token sink for simulated wallet outflows in settle tests
    address constant SINK = address(0xDEAD);

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        openHook = new EulerDepositCollateralAndBorrowHook(EVC, EVAULT_FACTORY);
        repayHook = new EulerRepayHook(EVC, EVAULT_FACTORY);
        closeHook = new EulerRepayAndWithdrawHook(EVC, EVAULT_FACTORY);

        prevStub = new EulerPrevHookStub();
    }

    /*//////////////////////////////////////////////////////////////
                    DATA BUILDERS (CANONICAL 197-BYTE LAYOUT)
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical Euler layout with byte-level control of the usePrevHookAmount boolean:
    ///      configId (0), collateralVault (32), debtAsset (52), collateralAsset (72), evc (92),
    ///      controllerVault (112), primary (132), secondary (164), usePrev (196) — exact 197 bytes
    function _eulerRaw(
        bytes32 configId,
        address collVault,
        address debtA,
        address collA,
        address evc_,
        address ctrlVault,
        uint256 primary,
        uint256 secondary,
        bytes1 usePrev
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(configId, collVault, debtA, collA, evc_, ctrlVault, primary, secondary, usePrev);
        assertEq(data.length, 197);
    }

    /// @dev Composite (open/close) data against the verified eWETH/eUSDC pair
    function _composite(uint256 primary, uint256 secondary, bool usePrev) internal pure returns (bytes memory) {
        return _eulerRaw(
            CONFIG_ID, EWETH_VAULT, USDC, WETH, EVC, EUSDC_VAULT, primary, secondary, usePrev ? bytes1(0x01) : bytes1(0x00)
        );
    }

    /// @dev Standalone repay data: collateralVault, collateralAsset and the secondary word are
    ///      reserved ZERO
    function _repayData(uint256 cap, bool usePrev) internal pure returns (bytes memory) {
        return _eulerRaw(
            CONFIG_ID, address(0), USDC, address(0), EVC, EUSDC_VAULT, cap, 0, usePrev ? bytes1(0x01) : bytes1(0x00)
        );
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

    /// @dev Real EVK position for address(this) via direct provider calls: deposit 5 WETH into
    ///      eWETH, enable it as collateral, enable eUSDC as controller, borrow 2,000 USDC.
    ///      Direct vault calls route through the EVC automatically; EVC self-calls authenticate.
    ///      Leaves 2,000 USDC and zero WETH in the wallet.
    function _openRealPosition() internal returns (uint256 debt) {
        deal(WETH, address(this), DEPOSIT_WETH);
        IERC20(WETH).approve(EWETH_VAULT, DEPOSIT_WETH);
        IEVault(EWETH_VAULT).deposit(DEPOSIT_WETH, address(this));
        IEVC(EVC).enableCollateral(address(this), EWETH_VAULT);
        IEVC(EVC).enableController(address(this), EUSDC_VAULT);
        IEVault(EUSDC_VAULT).borrow(BORROW_USDC, address(this));

        debt = IEVault(EUSDC_VAULT).debtOf(address(this));
        assertGe(debt, BORROW_USDC, "debtOf rounds up, never below the borrow");
    }

    /// @dev Exact assets releasing the whole eWETH share balance (dust-free on EVK:
    ///      previewWithdraw(convertToAssets(shares)) == shares, verified on this fork)
    function _fullWithdrawAssets() internal view returns (uint256 assets) {
        assets = IEVaultForkViews(EWETH_VAULT).convertToAssets(IEVault(EWETH_VAULT).balanceOf(address(this)));
        assertEq(
            IEVault(EWETH_VAULT).previewWithdraw(assets),
            IEVault(EWETH_VAULT).balanceOf(address(this)),
            "exact-assets full exit burns the whole share balance"
        );
    }

    function _increaseBalance(address token, uint256 delta) internal {
        deal(token, address(this), IERC20(token).balanceOf(address(this)) + delta);
    }

    /*//////////////////////////////////////////////////////////////
        A-1/A-2. SIZING ROUND-TRIPS AT 132/164 WITH REAL ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist A-1 (open): two-slot round-trip; EVERY identity field preserved at its real
    ///      offset after the replace
    function test_Fork_EulerOpen_DecodeReplace_RoundTrip() public view {
        bytes memory data = _composite(1e18, 500e6, true);

        uint256[] memory amounts = openHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1e18);
        assertEq(amounts[1], 500e6);

        bytes memory replaced = openHook.replaceCalldataAmounts(data, _dualAmounts(3e18, 1500e6));
        assertEq(openHook.decodeAmounts(replaced)[0], 3e18);
        assertEq(openHook.decodeAmounts(replaced)[1], 1500e6);

        assertEq(BytesLib.toBytes32(replaced, 0), CONFIG_ID, "configId mismatch");
        assertEq(BytesLib.toAddress(replaced, 32), EWETH_VAULT, "collateralVault mismatch");
        assertEq(BytesLib.toAddress(replaced, 52), USDC, "debtAsset mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), WETH, "collateralAsset mismatch");
        assertEq(BytesLib.toAddress(replaced, 92), EVC, "evc mismatch");
        assertEq(BytesLib.toAddress(replaced, 112), EUSDC_VAULT, "controllerVault mismatch");
        assertEq(uint8(replaced[196]), 1, "usePrevHookAmount byte mismatch");
    }

    /// @dev Checklist A-1 (close): identical two-slot surface on the close hook
    function test_Fork_EulerClose_DecodeReplace_RoundTrip() public view {
        bytes memory data = _composite(500e6, 1e18, false);

        uint256[] memory amounts = closeHook.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 500e6);
        assertEq(amounts[1], 1e18);

        bytes memory replaced = closeHook.replaceCalldataAmounts(data, _dualAmounts(42e6, 2e17));
        assertEq(closeHook.decodeAmounts(replaced)[0], 42e6);
        assertEq(closeHook.decodeAmounts(replaced)[1], 2e17);

        assertEq(BytesLib.toBytes32(replaced, 0), CONFIG_ID, "configId mismatch");
        assertEq(BytesLib.toAddress(replaced, 32), EWETH_VAULT, "collateralVault mismatch");
        assertEq(BytesLib.toAddress(replaced, 52), USDC, "debtAsset mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), WETH, "collateralAsset mismatch");
        assertEq(BytesLib.toAddress(replaced, 92), EVC, "evc mismatch");
        assertEq(BytesLib.toAddress(replaced, 112), EUSDC_VAULT, "controllerVault mismatch");
        assertEq(uint8(replaced[196]), 0, "usePrevHookAmount byte mismatch");
    }

    /// @dev Checklist A-2: standalone repay is single-slot at 132; the reserved secondary word
    ///      stays zero through the replace; wrong-length amount arrays revert on both shapes
    function test_Fork_EulerRepay_SingleSlot_And_LengthGuards() public {
        bytes memory data = _repayData(700e6, false);

        uint256[] memory amounts = repayHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 700e6);

        bytes memory replaced = repayHook.replaceCalldataAmounts(data, _singleAmount(999e6));
        assertEq(repayHook.decodeAmounts(replaced)[0], 999e6);
        assertEq(BytesLib.toUint256(replaced, 164), 0, "reserved secondary must stay zero");
        assertEq(BytesLib.toAddress(replaced, 92), EVC, "evc mismatch");
        assertEq(BytesLib.toAddress(replaced, 112), EUSDC_VAULT, "controllerVault mismatch");

        // repay: two amounts on the single-slot surface
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        repayHook.replaceCalldataAmounts(data, _dualAmounts(1, 2));

        // composites: one amount on the two-slot surface
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        openHook.replaceCalldataAmounts(_composite(1e18, 500e6, false), _singleAmount(1));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        closeHook.replaceCalldataAmounts(_composite(500e6, 1e18, false), _singleAmount(1));
    }

    /*//////////////////////////////////////////////////////////////
                    A-3. AMOUNT ROLES SHAPES
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Euler_AmountRoles() public view {
        // composites: [IN/TOKEN, OUT/TOKEN]
        ISuperHookInflowOutflow.AmountMeta[] memory openMeta = openHook.amountRoles("");
        assertEq(openMeta.length, 2);
        assertEq(uint8(openMeta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(openMeta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint8(openMeta[1].dir), uint8(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint8(openMeta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));

        ISuperHookInflowOutflow.AmountMeta[] memory closeMeta = closeHook.amountRoles("");
        assertEq(closeMeta.length, 2);
        assertEq(uint8(closeMeta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(closeMeta[1].dir), uint8(ISuperHookInflowOutflow.Direction.OUT));

        // standalone repay: [IN/TOKEN]
        ISuperHookInflowOutflow.AmountMeta[] memory repayMeta = repayHook.amountRoles("");
        assertEq(repayMeta.length, 1);
        assertEq(uint8(repayMeta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(repayMeta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    /*//////////////////////////////////////////////////////////////
            A-4. decodeUsePrevHookAmount STRICT BYTE @196
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Euler_DecodeUsePrevHookAmount_Strict() public {
        assertFalse(openHook.decodeUsePrevHookAmount(_composite(1, 1, false)));
        assertTrue(openHook.decodeUsePrevHookAmount(_composite(1, 1, true)));
        assertFalse(repayHook.decodeUsePrevHookAmount(_repayData(1, false)));
        assertTrue(repayHook.decodeUsePrevHookAmount(_repayData(1, true)));
        assertFalse(closeHook.decodeUsePrevHookAmount(_composite(1, 1, false)));
        assertTrue(closeHook.decodeUsePrevHookAmount(_composite(1, 1, true)));

        bytes memory bad = _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, WETH, EVC, EUSDC_VAULT, 1, 1, 0x02);
        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.decodeUsePrevHookAmount(bad);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.decodeUsePrevHookAmount(bad);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        closeHook.decodeUsePrevHookAmount(bad);
    }

    /*//////////////////////////////////////////////////////////////
                A-5. INSPECT BYTE-EXACT WITH REAL ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @dev Composite identity == abi.encodePacked(EVC, eUSDC, eWETH, USDC, WETH), exactly 100
    ///      bytes; configId/amounts/usePrev never enter the identity
    function test_Fork_Euler_Inspect_Composite() public view {
        bytes memory expected = abi.encodePacked(EVC, EUSDC_VAULT, EWETH_VAULT, USDC, WETH);
        assertEq(expected.length, 100);

        assertEq(openHook.inspect(_composite(1e18, 500e6, false)), expected);
        assertEq(closeHook.inspect(_composite(500e6, 1e18, false)), expected);

        // configId / amounts / usePrev mutations leave the identity unchanged
        assertEq(
            openHook.inspect(_eulerRaw(bytes32(uint256(0xDEAD)), EWETH_VAULT, USDC, WETH, EVC, EUSDC_VAULT, 7, 9, 0x01)),
            expected
        );
        assertEq(
            closeHook.inspect(_eulerRaw(bytes32(0), EWETH_VAULT, USDC, WETH, EVC, EUSDC_VAULT, MAX, 1, 0x01)), expected
        );

        // every identity field mutation changes the payload (decode-valid real-address mutants)
        assertNotEq(
            openHook.inspect(_eulerRaw(CONFIG_ID, EEURC_VAULT, USDC, EURC, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)),
            expected,
            "collateralVault/collateralAsset mutation must change identity"
        );
        assertNotEq(
            openHook.inspect(_eulerRaw(CONFIG_ID, EWETH_VAULT, EURC, WETH, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)),
            expected,
            "debtAsset mutation must change identity"
        );
        assertNotEq(
            openHook.inspect(_eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, EURC, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)),
            expected,
            "collateralAsset mutation must change identity"
        );
        assertNotEq(
            openHook.inspect(_eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, WETH, EWETH_VAULT, EUSDC_VAULT, 1e18, 500e6, 0x00)),
            expected,
            "evc mutation must change identity"
        );
        assertNotEq(
            openHook.inspect(_eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, WETH, EVC, EEURC_VAULT, 1e18, 500e6, 0x00)),
            expected,
            "controllerVault mutation must change identity"
        );
    }

    /// @dev Standalone repay identity == abi.encodePacked(EVC, eUSDC, USDC), exactly 60 bytes —
    ///      collateral/release configuration intentionally excluded
    function test_Fork_Euler_Inspect_Repay() public view {
        bytes memory expected = abi.encodePacked(EVC, EUSDC_VAULT, USDC);
        assertEq(expected.length, 60);

        assertEq(repayHook.inspect(_repayData(700e6, false)), expected);
        // cap / usePrev / configId do not affect the identity
        assertEq(repayHook.inspect(_eulerRaw(bytes32(0), address(0), USDC, address(0), EVC, EUSDC_VAULT, MAX, 0, 0x01)), expected);

        // identity field mutations change the payload
        assertNotEq(
            repayHook.inspect(_eulerRaw(CONFIG_ID, address(0), EURC, address(0), EVC, EUSDC_VAULT, 1, 0, 0x00)),
            expected,
            "debtAsset mutation must change identity"
        );
        assertNotEq(
            repayHook.inspect(_eulerRaw(CONFIG_ID, address(0), USDC, address(0), EWETH_VAULT, EUSDC_VAULT, 1, 0, 0x00)),
            expected,
            "evc mutation must change identity"
        );
        assertNotEq(
            repayHook.inspect(_eulerRaw(CONFIG_ID, address(0), USDC, address(0), EVC, EEURC_VAULT, 1, 0, 0x00)),
            expected,
            "controllerVault mutation must change identity"
        );
    }

    /*//////////////////////////////////////////////////////////////
                A-6. FUZZ: COMPOSITE REPLACE ROUND-TRIP
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Fork_EulerComposite_Replace(uint256 a1, uint256 a2) public view {
        bytes memory replaced = openHook.replaceCalldataAmounts(_composite(0, 0, false), _dualAmounts(a1, a2));
        assertEq(openHook.decodeAmounts(replaced)[0], a1);
        assertEq(openHook.decodeAmounts(replaced)[1], a2);
        // every real identity field always preserved
        assertEq(BytesLib.toBytes32(replaced, 0), CONFIG_ID);
        assertEq(BytesLib.toAddress(replaced, 32), EWETH_VAULT);
        assertEq(BytesLib.toAddress(replaced, 52), USDC);
        assertEq(BytesLib.toAddress(replaced, 72), WETH);
        assertEq(BytesLib.toAddress(replaced, 92), EVC);
        assertEq(BytesLib.toAddress(replaced, 112), EUSDC_VAULT);
        assertEq(uint8(replaced[196]), 0);
    }

    /*//////////////////////////////////////////////////////////////
            B-7/B-8. STRICT DECODE — LENGTH + CANONICAL BOOL
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist B-7: 196 and 198 bytes revert on every hook
    function test_Fork_Euler_Decode_InvalidDataLength() public {
        bytes memory good = _composite(1e18, 500e6, false);
        bytes memory goodRepay = _repayData(700e6, false);

        // 196 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), _truncate(good));

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), _truncate(goodRepay));

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), _truncate(good));

        // 198 bytes
        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        openHook.build(address(0), address(this), bytes.concat(good, hex"00"));

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        repayHook.build(address(0), address(this), bytes.concat(goodRepay, hex"00"));

        vm.expectRevert(BaseLoanHookV2.INVALID_DATA_LENGTH.selector);
        closeHook.build(address(0), address(this), bytes.concat(good, hex"00"));
    }

    /// @dev Checklist B-8: usePrev byte 0x02 rejected on the execution path of every hook
    function test_Fork_Euler_Decode_InvalidBoolValue() public {
        bytes memory badComposite = _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, WETH, EVC, EUSDC_VAULT, 1e18, 500e6, 0x02);
        bytes memory badRepay = _eulerRaw(CONFIG_ID, address(0), USDC, address(0), EVC, EUSDC_VAULT, 700e6, 0, 0x02);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        openHook.build(address(0), address(this), badComposite);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        repayHook.build(address(0), address(this), badRepay);

        vm.expectRevert(BaseLoanHookV2.INVALID_BOOL_VALUE.selector);
        closeHook.build(address(0), address(this), badComposite);
    }

    /*//////////////////////////////////////////////////////////////
            B-9. STANDALONE REPAY RESERVED FIELDS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_EulerRepay_ReservedFieldsNotZero() public {
        // collateralVault (reserved) = eWETH
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, address(0), EVC, EUSDC_VAULT, 700e6, 0, 0x00)
        );

        // collateralAsset (reserved) = WETH
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, WETH, EVC, EUSDC_VAULT, 700e6, 0, 0x00)
        );

        // secondary (reserved word) = 1
        vm.expectRevert(BaseLoanHookV2.RESERVED_FIELD_NOT_ZERO.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, address(0), EVC, EUSDC_VAULT, 700e6, 1, 0x00)
        );
    }

    /*//////////////////////////////////////////////////////////////
            B-10. ZERO-ADDRESS IDENTITY FIELDS
    //////////////////////////////////////////////////////////////*/

    /// @dev Shared fields (debtAsset / evc / controllerVault) checked on the repay hook, the
    ///      composite-only fields (collateralVault / collateralAsset) on the open hook
    function test_Fork_Euler_Decode_ZeroAddressReverts() public {
        // debtAsset = 0
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), address(0), address(0), EVC, EUSDC_VAULT, 1, 0, 0x00)
        );

        // evc = 0
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, address(0), address(0), EUSDC_VAULT, 1, 0, 0x00)
        );

        // controllerVault = 0
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, address(0), EVC, address(0), 1, 0, 0x00)
        );

        // composite collateralVault = 0
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, WETH, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)
        );

        // composite collateralAsset = 0
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, address(0), EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)
        );
    }

    /*//////////////////////////////////////////////////////////////
            B-11. IDENTICAL VAULTS / IDENTICAL TOKENS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Euler_Decode_IdenticalVaultsAndTokens() public {
        // collateralVault == controllerVault (both eUSDC)
        vm.expectRevert(BaseEulerLoanHook.IDENTICAL_VAULTS.selector);
        openHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EUSDC_VAULT, USDC, WETH, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)
        );

        vm.expectRevert(BaseEulerLoanHook.IDENTICAL_VAULTS.selector);
        closeHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EUSDC_VAULT, USDC, WETH, EVC, EUSDC_VAULT, 500e6, 1e18, 0x00)
        );

        // debtAsset == collateralAsset (both USDC, vaults correct)
        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        openHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, USDC, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00)
        );

        vm.expectRevert(BaseLoanHookV2.IDENTICAL_TOKENS.selector);
        closeHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, USDC, EVC, EUSDC_VAULT, 500e6, 1e18, 0x00)
        );
    }

    /*//////////////////////////////////////////////////////////////
            C-12. VAULT_ASSET_MISMATCH AGAINST REAL VAULTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Controller side, repayOnly path (E2E covered the open path): the standalone repay
    ///      declares WETH as the debt asset but the real eUSDC reports USDC
    function test_Fork_Euler_VaultAssetMismatch_ControllerSide_Repay() public {
        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), WETH, address(0), EVC, EUSDC_VAULT, 700e6, 0, 0x00)
        );

        // controller side on the close (composite, repayOnly == false) path: EURC as debt asset
        // keeps decode valid (EURC != WETH) and fails against eUSDC's real USDC underlying
        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        closeHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, EURC, WETH, EVC, EUSDC_VAULT, 500e6, 1e18, 0x00)
        );
    }

    /// @dev Collateral side: the controller binding is fully correct (USDC/eUSDC/EVC) so
    ///      _validateBindings reaches the collateral checks; the collateral vault is the real
    ///      eWETH but the declared collateral asset is the real EURC (a third token — using USDC
    ///      would trip IDENTICAL_TOKENS in decode first, per the _decodeEuler order)
    function test_Fork_Euler_VaultAssetMismatch_CollateralSide() public {
        bytes memory data = _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, EURC, EVC, EUSDC_VAULT, 1e18, 500e6, 0x00);

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        openHook.build(address(0), address(this), data);

        vm.expectRevert(BaseEulerLoanHook.VAULT_ASSET_MISMATCH.selector);
        closeHook.build(address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, EURC, EVC, EUSDC_VAULT, 500e6, 1e18, 0x00));
    }

    /*//////////////////////////////////////////////////////////////
            C-13. VAULT_EVC_MISMATCH AGAINST REAL VAULTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The calldata evc field is pinned to the canonical singleton: any other nonzero value
    ///      (here a real contract, eWETH) is rejected as EVC_NOT_CANONICAL before any vault call.
    ///      The VAULT_EVC_MISMATCH branches survive as defense in depth only — with the pin plus
    ///      the factory isProxy check they are not constructible on real Base state (every factory
    ///      vault reports the canonical EVC), so they are no longer separately reachable here.
    function test_Fork_Euler_EvcNotCanonical() public {
        vm.expectRevert(BaseEulerLoanHook.EVC_NOT_CANONICAL.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, address(0), EWETH_VAULT, EUSDC_VAULT, 700e6, 0, 0x00)
        );

        vm.expectRevert(BaseEulerLoanHook.EVC_NOT_CANONICAL.selector);
        closeHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, WETH, EWETH_VAULT, EUSDC_VAULT, 500e6, 1e18, 0x00)
        );
    }

    /// @dev A contract that is NOT an eVaultFactory proxy is rejected as UNTRUSTED_VAULT before
    ///      any of its self-reported views are trusted — the core defense of the pinned-factory
    ///      design (a hostile vault reporting the canonical EVC and the right asset still fails)
    function test_Fork_Euler_UntrustedVault() public {
        // The prev-hook stub is a real deployed contract that is not a factory proxy
        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        repayHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(0), USDC, address(0), EVC, address(prevStub), 700e6, 0, 0x00)
        );

        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        closeHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, address(prevStub), USDC, WETH, EVC, EUSDC_VAULT, 500e6, 1e18, 0x00)
        );

        vm.expectRevert(BaseEulerLoanHook.UNTRUSTED_VAULT.selector);
        openHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EWETH_VAULT, USDC, WETH, EVC, address(prevStub), 1e18, 500e6, 0x00)
        );
    }

    /*//////////////////////////////////////////////////////////////
            D-15. OPEN/CLOSE AMOUNT VALIDATION ON REAL STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Open: zero and max are invalid on BOTH legs (the secondary/borrow leg is checked
    ///      first in _resolveOpenAmounts — verified against the source order)
    function test_Fork_EulerOpen_AmountValidation() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _composite(1e18, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _composite(1e18, MAX, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _composite(0, 500e6, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(0), address(this), _composite(MAX, 500e6, false));
    }

    /// @dev Close: the exact-assets withdraw leg rejects zero and the max sentinel BEFORE the
    ///      repay-cap resolution (no debt needed — fresh account)
    function test_Fork_EulerClose_WithdrawAmountValidation() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _composite(500e6, 0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _composite(500e6, MAX, false));
    }

    /// @dev LTV_NOT_SET on real state: eEURC (EVault factory proxyList(5)) is a real EVK vault on
    ///      the canonical EVC whose collateral is NOT configured on eUSDC —
    ///      eUSDC.LTVBorrow(eEURC) == 0. Bindings pass (EVC + EURC underlying match), the market
    ///      check fires.
    function test_Fork_EulerOpen_LTVNotSet_RealUnlinkedVault() public {
        assertEq(IEVault(EUSDC_VAULT).LTVBorrow(EEURC_VAULT), 0, "eEURC must be unlinked from eUSDC");
        assertEq(IEVault(EEURC_VAULT).asset(), EURC, "eEURC underlying");
        assertEq(IEVault(EEURC_VAULT).EVC(), EVC, "eEURC on the canonical EVC");

        vm.expectRevert(BaseEulerLoanHook.LTV_NOT_SET.selector);
        openHook.build(
            address(0), address(this), _eulerRaw(CONFIG_ID, EEURC_VAULT, USDC, EURC, EVC, EUSDC_VAULT, 1e6, 100e6, 0x00)
        );
    }

    /*//////////////////////////////////////////////////////////////
            D-16. OPEN PREVIOUS-HOOK PIPE (in-file stub, real providers)
    //////////////////////////////////////////////////////////////*/

    function test_Fork_EulerOpen_Prev_ZeroHookReverts() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        openHook.build(address(0), address(this), _composite(1, 500e6, true));
    }

    /// @dev Open expects the collateral token (WETH); the stub produces the debt token (USDC)
    function test_Fork_EulerOpen_Prev_TokenMismatch() public {
        prevStub.set(USDC, 1e18);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        openHook.build(address(prevStub), address(this), _composite(1, 500e6, true));
    }

    function test_Fork_EulerOpen_Prev_ZeroAmountReverts() public {
        prevStub.set(WETH, 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prevStub), address(this), _composite(1, 500e6, true));
    }

    function test_Fork_EulerOpen_Prev_MaxAmountReverts() public {
        prevStub.set(WETH, MAX);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        openHook.build(address(prevStub), address(this), _composite(1, 500e6, true));
    }

    /// @dev Happy PREV path: the approve and deposit legs encode the stub's amount, not the 1-wei
    ///      calldata placeholder; fresh account emits both EVC enables
    function test_Fork_EulerOpen_Prev_HappyPath() public {
        prevStub.set(WETH, 5e17);
        Execution[] memory execs = openHook.build(address(prevStub), address(this), _composite(1, 500e6, true));

        // pre + approve(0) + approve(prev) + deposit(prev) + approve(0) + enableCollateral +
        // enableController + borrow + post
        assertEq(execs.length, 9);
        assertEq(execs[2].target, WETH);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (EWETH_VAULT, 5e17)));
        assertEq(execs[3].target, EWETH_VAULT);
        assertEq(execs[3].callData, abi.encodeCall(IEVault.deposit, (5e17, address(this))));
        assertEq(execs[5].target, EVC);
        assertEq(execs[5].callData, abi.encodeCall(IEVC.enableCollateral, (address(this), EWETH_VAULT)));
        assertEq(execs[6].callData, abi.encodeCall(IEVC.enableController, (address(this), EUSDC_VAULT)));
        assertEq(execs[7].callData, abi.encodeCall(IEVault.borrow, (500e6, address(this))));
    }

    /*//////////////////////////////////////////////////////////////
        D-17. REPAY/CLOSE PREVIOUS-HOOK PIPE WITH REAL DEBT
    //////////////////////////////////////////////////////////////*/

    /// @dev The zero-debt guard runs before prev resolution, so real debt is required to reach
    ///      the pipe on the repay/close paths (verified against the _resolveRepayCap order)
    function test_Fork_EulerRepay_Prev_ZeroHookReverts() public {
        _openRealPosition();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _repayData(1, true));
    }

    /// @dev Repay expects the debt token (USDC); the stub produces WETH
    function test_Fork_EulerRepay_Prev_TokenMismatch() public {
        _openRealPosition();
        prevStub.set(WETH, 100e6);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        repayHook.build(address(prevStub), address(this), _repayData(1, true));
    }

    /// @dev Close's repay leg expects the debt token too
    function test_Fork_EulerClose_Prev_TokenMismatch() public {
        _openRealPosition();
        prevStub.set(WETH, 100e6);
        vm.expectRevert(BaseLoanHookV2.PREV_TOKEN_MISMATCH.selector);
        closeHook.build(address(prevStub), address(this), _composite(1, 1e17, true));
    }

    /// @dev The prev amount becomes the CAP: below debt it is approved/repaid verbatim (no
    ///      disable), above debt it collapses to debtOf and predicts the clear
    function test_Fork_EulerRepay_Prev_CapSemantics() public {
        uint256 debt = _openRealPosition();

        // prev output below debt → approve/repay exactly the prev amount, 4 hook execs
        prevStub.set(USDC, 500e6);
        Execution[] memory execs = repayHook.build(address(prevStub), address(this), _repayData(1, true));
        assertEq(execs.length, 6); // pre + approve(0) + approve + repay + approve(0) + post
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, 500e6)));
        assertEq(execs[3].callData, abi.encodeCall(IEVault.repay, (500e6, address(this))));

        // prev output above debt → min() to debtOf, predicted clear adds disableController
        prevStub.set(USDC, debt + 1000e6);
        execs = repayHook.build(address(prevStub), address(this), _repayData(1, true));
        assertEq(execs.length, 7);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, debt)));
        assertEq(execs[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
        assertEq(execs[5].target, EUSDC_VAULT, "controller disabled via the vault, never the EVC");
        assertEq(execs[5].callData, abi.encodeCall(IEVault.disableController, ()));
    }

    /*//////////////////////////////////////////////////////////////
        E-18/E-19. CAP + DISABLE BUILD SHAPES WITH REAL DEBT
    //////////////////////////////////////////////////////////////*/

    /// @dev Checklist C-14 + E-18 (repay): the standalone repay carries no collateral fields at
    ///      all — build succeeds regardless of any collateral configuration; a partial cap emits
    ///      4 hook executions (6 with the pre/post wrapper) and the repay leg encodes the cap
    function test_Fork_EulerRepay_Build_PartialCap() public {
        uint256 debt = _openRealPosition();
        uint256 cap = 500e6;
        assertLt(cap, debt);

        Execution[] memory execs = repayHook.build(address(0), address(this), _repayData(cap, false));
        assertEq(execs.length, 6); // pre + approve(0) + approve(cap) + repay(cap) + approve(0) + post
        assertEq(execs[1].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, 0)));
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, cap)));
        assertEq(execs[3].target, EUSDC_VAULT);
        assertEq(execs[3].callData, abi.encodeCall(IEVault.repay, (cap, address(this))));
        assertEq(execs[4].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, 0)));
    }

    /// @dev E-19: a max cap resolves to debtOf ("repay everything", no separate sentinel) and the
    ///      predicted clear appends disableController LAST, targeting the eUSDC vault, never the EVC
    function test_Fork_EulerRepay_Build_MaxCap() public {
        uint256 debt = _openRealPosition();

        Execution[] memory execs = repayHook.build(address(0), address(this), _repayData(MAX, false));
        assertEq(execs.length, 7); // pre + approve(0) + approve(debt) + repay(debt) + approve(0) + disable + post
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, debt)));
        assertEq(execs[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
        assertEq(execs[5].target, EUSDC_VAULT, "disableController targets the vault, never the EVC");
        assertEq(execs[5].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(execs[6].target, address(repayHook), "postExecute last");
    }

    /*//////////////////////////////////////////////////////////////
            E-20. CAP ZERO + ZERO-DEBT GUARDS
    //////////////////////////////////////////////////////////////*/

    /// @dev cap == 0 with REAL debt (the zero-debt guard runs first, so debt is required to reach
    ///      the cap check)
    function test_Fork_Euler_CapZero_Reverts() public {
        _openRealPosition();

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        repayHook.build(address(0), address(this), _repayData(0, false));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        closeHook.build(address(0), address(this), _composite(0, 1e17, false));
    }

    /// @dev Zero debt degrades gracefully instead of reverting (a third party gifting a full
    ///      repayment cannot cancel a signed intent): the repay leg is skipped entirely and, with
    ///      nothing enabled for a fresh account, the standalone repay emits no provider calls at
    ///      all while the close degrades to a plain withdrawal
    function test_Fork_Euler_ZeroDebt_Graceful() public {
        address noDebt = makeAddr("euler-no-debt");
        assertEq(IEVault(EUSDC_VAULT).debtOf(noDebt), 0);

        Execution[] memory execs = repayHook.build(address(0), noDebt, _repayData(700e6, false));
        assertEq(execs.length, 2); // pre + post only

        execs = closeHook.build(address(0), noDebt, _composite(700e6, 1e17, false));
        assertEq(execs.length, 3); // pre + withdraw + post
        assertEq(execs[1].callData, abi.encodeCall(IEVault.withdraw, (1e17, noDebt, noDebt)));
    }

    /*//////////////////////////////////////////////////////////////
            E-21. CLOSE disableCollateral PREDICTION ON REAL STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Three real build shapes: any predicted debt clear appends disableCollateral on the
    ///      EVC after the withdraw whenever the collateral is enabled (partial or full withdrawal
    ///      — the flag release never locks funds and is donation-proof); residual debt disables
    ///      nothing
    function test_Fork_EulerClose_Build_DisableCollateralPrediction() public {
        uint256 debt = _openRealPosition();
        uint256 fullAssets = _fullWithdrawAssets();

        // Full exit: previewWithdraw(secondary) == balanceOf → 7 hook execs (9 wrapped)
        Execution[] memory execs = closeHook.build(address(0), address(this), _composite(MAX, fullAssets, false));
        assertEq(execs.length, 9);
        assertEq(execs[2].callData, abi.encodeCall(IERC20.approve, (EUSDC_VAULT, debt)));
        assertEq(execs[3].callData, abi.encodeCall(IEVault.repay, (debt, address(this))));
        assertEq(execs[5].target, EUSDC_VAULT);
        assertEq(execs[5].callData, abi.encodeCall(IEVault.disableController, ()), "controller disable BEFORE withdraw");
        assertEq(execs[6].callData, abi.encodeCall(IEVault.withdraw, (fullAssets, address(this), address(this))));
        assertEq(execs[7].target, EVC, "collateral released on the EVC, after the withdraw");
        assertEq(execs[7].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), EWETH_VAULT)));

        // Clear with a partial withdrawal: the collateral FLAG is still released (7 hook execs,
        // 9 wrapped) — shares remain redeemable, the flag simply stops counting toward the EVC's
        // 10-collateral cap
        execs = closeHook.build(address(0), address(this), _composite(MAX, fullAssets / 2, false));
        assertEq(execs.length, 9);
        assertEq(execs[5].callData, abi.encodeCall(IEVault.disableController, ()));
        assertEq(execs[6].callData, abi.encodeCall(IEVault.withdraw, (fullAssets / 2, address(this), address(this))));
        assertEq(execs[7].callData, abi.encodeCall(IEVC.disableCollateral, (address(this), EWETH_VAULT)));

        // Residual debt: no disables at all → 5 hook execs (7 wrapped)
        execs = closeHook.build(address(0), address(this), _composite(300e6, 1e17, false));
        assertEq(execs.length, 7);
        assertEq(execs[3].callData, abi.encodeCall(IEVault.repay, (300e6, address(this))));
        assertEq(execs[5].callData, abi.encodeCall(IEVault.withdraw, (1e17, address(this), address(this))));
    }

    /*//////////////////////////////////////////////////////////////
        F-22. _settleOpen VIA DIRECT preExecute/postExecute
        (open _preExecute re-validates the REAL market state, so
         amounts stay inside verified liquidity)
    //////////////////////////////////////////////////////////////*/

    /// @dev Success: WETH out exactly primary, USDC in exactly secondary → publishes the borrowed
    ///      delta with outToken = USDC
    function test_Fork_SettleOpen_Success() public {
        deal(WETH, address(this), 2e18);
        bytes memory data = _composite(1e18, 500e6, false);

        openHook.preExecute(address(0), address(this), data);
        IERC20(WETH).transfer(SINK, 1e18);
        _increaseBalance(USDC, 500e6);
        openHook.postExecute(address(0), address(this), data);

        assertEq(openHook.getOutAmount(address(this)), 500e6);
        assertEq(openHook.getOutToken(address(this)), USDC);
    }

    /// @dev Collateral-delta mismatch with exact args (first branch of _settleOpen)
    function test_Fork_SettleOpen_CollateralDeltaMismatch() public {
        deal(WETH, address(this), 2e18);
        bytes memory data = _composite(1e18, 500e6, false);

        openHook.preExecute(address(0), address(this), data);
        IERC20(WETH).transfer(SINK, 4e17);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 1e18, 4e17));
        openHook.postExecute(address(0), address(this), data);
    }

    /// @dev Exact collateral spend, wrong loan inflow (second branch of _settleOpen)
    function test_Fork_SettleOpen_LoanDeltaMismatch() public {
        deal(WETH, address(this), 2e18);
        bytes memory data = _composite(1e18, 500e6, false);

        openHook.preExecute(address(0), address(this), data);
        IERC20(WETH).transfer(SINK, 1e18);
        _increaseBalance(USDC, 250e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 500e6, 250e6));
        openHook.postExecute(address(0), address(this), data);
    }

    /// @dev The loan-token balance DECREASED where an increase was required
    function test_Fork_SettleOpen_NegativeLoanDelta() public {
        deal(WETH, address(this), 2e18);
        deal(USDC, address(this), 100e6);
        bytes memory data = _composite(1e18, 500e6, false);

        openHook.preExecute(address(0), address(this), data);
        IERC20(WETH).transfer(SINK, 1e18);
        IERC20(USDC).transfer(SINK, 10e6);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        openHook.postExecute(address(0), address(this), data);
    }

    /// @dev The collateral balance INCREASED where a decrease was required
    function test_Fork_SettleOpen_NegativeCollateralDelta() public {
        deal(WETH, address(this), 2e18);
        bytes memory data = _composite(1e18, 500e6, false);

        openHook.preExecute(address(0), address(this), data);
        _increaseBalance(WETH, 1);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        openHook.postExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
        F-23. _settleRepay + POST-VERIFY WITH REAL DEBT
    //////////////////////////////////////////////////////////////*/

    /// @dev Success: exactly actualRepay USDC out publishes (spend, USDC)
    function test_Fork_SettleRepay_Success() public {
        _openRealPosition();
        bytes memory data = _repayData(100e6, false);

        repayHook.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 100e6);
        repayHook.postExecute(address(0), address(this), data);

        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
        assertEq(repayHook.getOutToken(address(this)), USDC);
    }

    function test_Fork_SettleRepay_DeltaMismatch() public {
        _openRealPosition();
        bytes memory data = _repayData(100e6, false);

        repayHook.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 50e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 100e6, 50e6));
        repayHook.postExecute(address(0), address(this), data);
    }

    /// @dev The debt-token balance INCREASED between snapshot and settle
    function test_Fork_SettleRepay_NegativeBalanceDelta() public {
        _openRealPosition();
        bytes memory data = _repayData(100e6, false);

        repayHook.preExecute(address(0), address(this), data);
        _increaseBalance(USDC, 1e6);

        vm.expectRevert(BaseLoanHookV2.NEGATIVE_BALANCE_DELTA.selector);
        repayHook.postExecute(address(0), address(this), data);
    }

    /// @dev Settle runs BEFORE the state-derived release verification (verified against the
    ///      _postExecute order): a predicted-clear preExecute followed by a postExecute without
    ///      any repayment reverts with DELTA_MISMATCH(debt, 0) first
    function test_Fork_SettleRepay_PredictedClear_SettleRunsFirst() public {
        uint256 debt = _openRealPosition();
        deal(USDC, address(this), 3000e6); // funded BEFORE the snapshot
        bytes memory data = _repayData(MAX, false);

        repayHook.preExecute(address(0), address(this), data);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, debt, 0));
        repayHook.postExecute(address(0), address(this), data);
    }

    /// @dev The release verification is STATE-DERIVED: with residual debt at postExecute the
    ///      controller is legitimately still enabled and no release check applies. (On the built
    ///      execution path a predicted clear that leaves debt makes the emitted disableController
    ///      itself revert E_OutstandingDebt on the real vault — that provider-level guarantee is
    ///      what replaced the old transient-flag DEBT_NOT_CLEARED check, which was poisonable by
    ///      an interleaved preExecute.)
    function test_Fork_SettleRepay_ResidualDebt_NoReleaseCheck() public {
        uint256 debt = _openRealPosition();
        deal(USDC, address(this), 3000e6);
        bytes memory data = _repayData(MAX, false);

        repayHook.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, debt); // wallet delta matches, but no actual repayment

        repayHook.postExecute(address(0), address(this), data); // debt != 0 → no release check
        assertEq(repayHook.getOutAmount(address(this)), 0); // terminal repay publishes 0
    }

    /// @dev CONTROLLER_NOT_DISABLED on real state: actually repay the whole debt directly on the
    ///      real vault between pre and post (wallet delta == debtOf, debt cleared) but skip the
    ///      controller disable — the settle and debt checks pass, the controller check fails
    function test_Fork_SettleRepay_ControllerNotDisabled() public {
        uint256 debt = _openRealPosition();
        deal(USDC, address(this), 3000e6);
        bytes memory data = _repayData(MAX, false);

        repayHook.preExecute(address(0), address(this), data);
        IERC20(USDC).approve(EUSDC_VAULT, debt);
        IEVault(EUSDC_VAULT).repay(debt, address(this));
        assertEq(IEVault(EUSDC_VAULT).debtOf(address(this)), 0, "debt cleared, no dust");
        assertTrue(IEVC(EVC).isControllerEnabled(address(this), EUSDC_VAULT), "controller still on");

        vm.expectRevert(BaseEulerLoanHook.CONTROLLER_NOT_DISABLED.selector);
        repayHook.postExecute(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
        F-24. _settleClose + COLLATERAL VERIFY WITH REAL DEBT
    //////////////////////////////////////////////////////////////*/

    /// @dev Success: exact USDC spend and exact WETH inflow publish the released collateral
    function test_Fork_SettleClose_Success() public {
        _openRealPosition(); // wallet: 2,000 USDC, 0 WETH
        bytes memory data = _composite(100e6, 5e16, false);

        closeHook.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 100e6);
        _increaseBalance(WETH, 5e16);
        closeHook.postExecute(address(0), address(this), data);

        assertEq(closeHook.getOutAmount(address(this)), 5e16);
        assertEq(closeHook.getOutToken(address(this)), WETH);
    }

    /// @dev Wrong loan spend → first DELTA_MISMATCH branch of _settleClose with exact args
    function test_Fork_SettleClose_LoanDeltaMismatch() public {
        _openRealPosition();
        bytes memory data = _composite(100e6, 5e16, false);

        closeHook.preExecute(address(0), address(this), data);
        IERC20(USDC).transfer(SINK, 42e6);

        vm.expectRevert(abi.encodeWithSelector(BaseLoanHookV2.DELTA_MISMATCH.selector, 100e6, 42e6));
        closeHook.postExecute(address(0), address(this), data);
    }

    /// @dev COLLATERAL_NOT_DISABLED on real state: perform the WHOLE close manually against the
    ///      real vaults between pre and post (full repay, controller disable via the vault, exact
    ///      full-collateral withdraw) but skip the EVC disableCollateral — settle, debt and
    ///      controller checks all pass, the collateral check fails
    function test_Fork_SettleClose_CollateralNotDisabled() public {
        uint256 debt = _openRealPosition();
        deal(USDC, address(this), 3000e6); // funded BEFORE the snapshot
        uint256 fullAssets = _fullWithdrawAssets();
        bytes memory data = _composite(MAX, fullAssets, false);

        closeHook.preExecute(address(0), address(this), data); // predicts controller + collateral disables

        IERC20(USDC).approve(EUSDC_VAULT, debt);
        IEVault(EUSDC_VAULT).repay(debt, address(this));
        IEVault(EUSDC_VAULT).disableController();
        IEVault(EWETH_VAULT).withdraw(fullAssets, address(this), address(this));
        assertEq(IEVault(EWETH_VAULT).balanceOf(address(this)), 0, "all shares burned");
        assertTrue(IEVC(EVC).isCollateralEnabled(address(this), EWETH_VAULT), "collateral still enabled");

        vm.expectRevert(BaseEulerLoanHook.COLLATERAL_NOT_DISABLED.selector);
        closeHook.postExecute(address(0), address(this), data);
    }

    receive() external payable { }
}
