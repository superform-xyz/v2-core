// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../src/vendor/morpho/MorphoBalancesLib.sol";
import { Id, IMorpho, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { MorphoSupplyAndBorrowHookV2 } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHookV2.sol";
import { MorphoRepayHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayHookV2.sol";
import { MorphoRepayAndWithdrawHookV2 } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHookV2.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";

/// @title MorphoV2HooksFork
/// @notice Ethereum mainnet fork tests for the V2 Morpho Blue loan hooks, executed through the
///         real SuperExecutor + SuperNativePaymaster ERC-4337 UserOp flow.
/// @dev Mirrors the setup/market of MorphoHooksIntegrationTest:
///      - loanToken       = USDC (6 decimals)
///      - collateralToken = WBTC (8 decimals)
///      - oracle          = MORPHO_ORACLE_WBTC_USDC
///      - irm             = MORPHO_IRM_WBTC_USDC
///      - lltv            = 86%
contract MorphoV2HooksFork is MinimalBaseIntegrationTest {
    using MarketParamsLib for MarketParams;

    // Amounts (exact, both legs — V2 hooks never derive amounts from a ratio/oracle)
    uint256 internal constant COLLATERAL_WBTC = 1_000_000; // 0.01 WBTC
    uint256 internal constant BORROW_USDC = 400e6; // 400 USDC — far below the 86% LTV cap
    uint256 internal constant PARTIAL_REPAY_USDC = 100e6;
    uint256 internal constant PARTIAL_WITHDRAW_WBTC = 200_000;

    MorphoSupplyAndBorrowHookV2 public openHook;
    MorphoRepayHookV2 public repayHook;
    MorphoRepayAndWithdrawHookV2 public closeHook;
    ISuperNativePaymaster public superNativePaymaster;

    address public loanToken; // USDC
    address public collateralToken; // WBTC
    uint256 public lltv;
    MarketParams public marketParams;
    Id public marketId;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        loanToken = CHAIN_1_USDC;
        collateralToken = CHAIN_1_WBTC;
        lltv = 860_000_000_000_000_000; // 86%

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: lltv
        });
        marketId = marketParams.id();

        openHook = new MorphoSupplyAndBorrowHookV2(MORPHO);
        repayHook = new MorphoRepayHookV2(MORPHO);
        closeHook = new MorphoRepayAndWithdrawHookV2(MORPHO);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(collateralToken, accountEth, 1e8);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                       HELPERS: ENCODE V2 HOOK DATA
    //////////////////////////////////////////////////////////////*/

    /// @dev Canonical 230-byte Morpho V2 layout:
    ///      52-byte strategy header (bytes32(0) + address(0)), then loanToken (offset 52),
    ///      collateralToken (72), oracle (92), irm (112), amount1 (132), amount2 (164),
    ///      usePrevHookAmount (196), lltv (197), reserved zero byte (229).
    function _morphoV2Data(
        uint256 amount1,
        uint256 amount2,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            bytes32(0),
            address(0),
            loanToken,
            collateralToken,
            MORPHO_ORACLE_WBTC_USDC,
            MORPHO_IRM_WBTC_USDC,
            amount1,
            amount2,
            usePrevHookAmount,
            lltv,
            bytes1(0)
        );
        assertEq(data.length, 230, "V2 layout must be exactly 230 bytes");
    }

    /*//////////////////////////////////////////////////////////////
                       HELPERS: EXECUTE VIA USEROP
    //////////////////////////////////////////////////////////////*/

    function _exec(address[] memory hooks, bytes[] memory data) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    function _execSingle(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _exec(hooks, datas);
    }

    /// @dev Executes the UserOp and asserts the account-level execution reverted (the EntryPoint
    ///      swallows the inner revert and emits UserOperationRevertReason instead).
    function _execExpectUserOpRevert(address[] memory hooks, bytes[] memory data) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        ExecutionReturnData memory ret = executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        bytes memory reason;
        for (uint256 i; i < ret.logs.length; ++i) {
            VmSafe.Log memory logEntry = ret.logs[i];
            if (
                logEntry.topics.length > 0
                    && logEntry.topics[0] == keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)")
            ) {
                (, reason) = abi.decode(logEntry.data, (uint256, bytes));
            }
        }
        assertGt(reason.length, 0, "userOp should have reverted");
    }

    function _execSingleExpectUserOpRevert(address hook, bytes memory data) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _execExpectUserOpRevert(hooks, datas);
    }

    function _open(uint256 collateralAmount, uint256 borrowAmount) internal {
        _execSingle(address(openHook), _morphoV2Data(collateralAmount, borrowAmount, false));
    }

    function _position() internal view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral) {
        return IMorphoStaticTyping(MORPHO).position(marketId, accountEth);
    }

    /*//////////////////////////////////////////////////////////////
                            1. OPEN EXACT
    //////////////////////////////////////////////////////////////*/

    /// @notice Supply exact collateral + borrow exact loan amount; both wallet deltas are exact.
    function test_V2_Open_Exact() external {
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        _open(COLLATERAL_WBTC, BORROW_USDC);

        assertEq(
            collateralBefore - IERC20(collateralToken).balanceOf(accountEth),
            COLLATERAL_WBTC,
            "collateral spent must equal exact amount"
        );
        assertEq(
            IERC20(loanToken).balanceOf(accountEth) - loanBefore,
            BORROW_USDC,
            "loan token received must equal exact borrow amount"
        );

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(collateral), COLLATERAL_WBTC, "position collateral == supplied");
        assertGt(uint256(borrowShares), 0, "borrow shares created");
    }

    /*//////////////////////////////////////////////////////////////
                            2. OPEN CHAINED
    //////////////////////////////////////////////////////////////*/

    /// @notice A previous hook producing the collateral token feeds the open leg via
    ///         usePrevHookAmount; the placeholder amount1 in calldata is ignored.
    function test_V2_Open_Chained_UsesPrevHookOutput() external {
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        address[] memory hooks = new address[](2);
        hooks[0] = approveHook; // position 0: publishes outToken = collateralToken, outAmount = COLLATERAL_WBTC
        hooks[1] = address(openHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(collateralToken, MORPHO, COLLATERAL_WBTC, false);
        data[1] = _morphoV2Data(1, BORROW_USDC, true); // amount1 = 1 wei placeholder, overridden by prev output

        _exec(hooks, data);

        assertEq(
            collateralBefore - IERC20(collateralToken).balanceOf(accountEth),
            COLLATERAL_WBTC,
            "collateral spent must equal prev hook output"
        );
        assertEq(IERC20(loanToken).balanceOf(accountEth) - loanBefore, BORROW_USDC, "exact borrow received");

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(collateral), COLLATERAL_WBTC, "position collateral == prev hook output");
        assertGt(uint256(borrowShares), 0, "borrow shares created");
    }

    /// @notice A previous hook producing the WRONG token (loan token instead of collateral) makes
    ///         the open leg revert with PREV_TOKEN_MISMATCH; state is unchanged.
    function test_V2_Open_Chained_WrongPrevToken_Reverts() external {
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        address[] memory hooks = new address[](2);
        hooks[0] = approveHook; // publishes outToken = loanToken — wrong for the collateral slot
        hooks[1] = address(openHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _createApproveHookData(loanToken, MORPHO, BORROW_USDC, false);
        data[1] = _morphoV2Data(1, BORROW_USDC, true);

        _execExpectUserOpRevert(hooks, data);

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(supplyShares, 0, "no supply shares");
        assertEq(uint256(borrowShares), 0, "no borrow shares");
        assertEq(uint256(collateral), 0, "no collateral");
        assertEq(IERC20(collateralToken).balanceOf(accountEth), collateralBefore, "collateral untouched");
        assertEq(IERC20(loanToken).balanceOf(accountEth), loanBefore, "loan token untouched");
    }

    /*//////////////////////////////////////////////////////////////
                           3. PARTIAL CLOSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Repay part of the debt and withdraw part of the collateral; both legs exact.
    function test_V2_PartialClose_RepayAndWithdraw() external {
        _open(COLLATERAL_WBTC, BORROW_USDC);

        (, uint128 borrowSharesBefore,) = _position();
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        _execSingle(address(closeHook), _morphoV2Data(PARTIAL_REPAY_USDC, PARTIAL_WITHDRAW_WBTC, false));

        assertEq(
            loanBefore - IERC20(loanToken).balanceOf(accountEth),
            PARTIAL_REPAY_USDC,
            "loan token spent must equal exact repay amount"
        );
        assertEq(
            IERC20(collateralToken).balanceOf(accountEth) - collateralBefore,
            PARTIAL_WITHDRAW_WBTC,
            "collateral received must equal exact withdraw amount"
        );

        (, uint128 borrowSharesAfter, uint128 collateralAfter) = _position();
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "debt reduced");
        assertGt(uint256(borrowSharesAfter), 0, "residual debt remains");
        assertEq(uint256(collateralAfter), COLLATERAL_WBTC - PARTIAL_WITHDRAW_WBTC, "collateral reduced by exact amount");
    }

    /*//////////////////////////////////////////////////////////////
                       4. FULL CLOSE AFTER ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Open, accrue 30 days of interest, then close with both max sentinels: the whole
    ///         debt is repaid by shares and the whole collateral is withdrawn.
    function test_V2_FullClose_AfterAccrual() external {
        _open(COLLATERAL_WBTC, BORROW_USDC);

        vm.warp(block.timestamp + 30 days);

        // Accrued interest exceeds the borrowed amount held in the wallet — top up the loan token.
        _getTokens(loanToken, accountEth, IERC20(loanToken).balanceOf(accountEth) + BORROW_USDC);

        uint256 expectedDebt = MorphoBalancesLib.expectedBorrowAssets(IMorpho(MORPHO), marketParams, accountEth);
        assertGt(expectedDebt, BORROW_USDC, "interest accrued");

        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        _execSingle(address(closeHook), _morphoV2Data(type(uint256).max, type(uint256).max, false));

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(borrowShares), 0, "debt fully repaid");
        assertEq(uint256(collateral), 0, "collateral fully withdrawn");
        assertEq(
            IERC20(collateralToken).balanceOf(accountEth) - collateralBefore,
            COLLATERAL_WBTC,
            "full collateral returned to wallet"
        );
        assertEq(loanBefore - IERC20(loanToken).balanceOf(accountEth), expectedDebt, "exact accrued debt spent");
        assertEq(IERC20(loanToken).allowance(accountEth, MORPHO), 0, "loan token allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                        5. STANDALONE REPAY PARTIAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone partial repay: exact loan-token spend, reduced borrow shares, zero
    ///         residual allowance.
    function test_V2_StandaloneRepay_Partial() external {
        _open(COLLATERAL_WBTC, BORROW_USDC);

        (, uint128 borrowSharesBefore,) = _position();
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        _execSingle(address(repayHook), _morphoV2Data(PARTIAL_REPAY_USDC, 0, false));

        assertEq(
            loanBefore - IERC20(loanToken).balanceOf(accountEth),
            PARTIAL_REPAY_USDC,
            "loan token spent must equal exact repay amount"
        );

        (, uint128 borrowSharesAfter, uint128 collateral) = _position();
        assertLt(uint256(borrowSharesAfter), uint256(borrowSharesBefore), "borrow shares reduced");
        assertGt(uint256(borrowSharesAfter), 0, "residual debt remains");
        assertEq(uint256(collateral), COLLATERAL_WBTC, "collateral untouched by repay");
        assertEq(IERC20(loanToken).allowance(accountEth, MORPHO), 0, "loan token allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                    6. STANDALONE REPAY FULL AFTER ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone full repay via the max sentinel after 30 days of accrual.
    function test_V2_StandaloneRepay_Full_AfterAccrual() external {
        _open(COLLATERAL_WBTC, BORROW_USDC);

        vm.warp(block.timestamp + 30 days);
        _getTokens(loanToken, accountEth, IERC20(loanToken).balanceOf(accountEth) + BORROW_USDC);

        uint256 expectedDebt = MorphoBalancesLib.expectedBorrowAssets(IMorpho(MORPHO), marketParams, accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        _execSingle(address(repayHook), _morphoV2Data(type(uint256).max, 0, false));

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(borrowShares), 0, "debt fully repaid");
        assertEq(uint256(collateral), COLLATERAL_WBTC, "collateral untouched by repay");
        assertEq(loanBefore - IERC20(loanToken).balanceOf(accountEth), expectedDebt, "exact accrued debt spent");
        assertEq(IERC20(loanToken).allowance(accountEth, MORPHO), 0, "loan token allowance reset");
    }

    /*//////////////////////////////////////////////////////////////
                              7. REVERTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standalone repay with zero debt reverts at build() time inside the executor call
    ///         (NO_OUTSTANDING_DEBT) — fresh account, never opened a position.
    function test_V2_StandaloneRepay_ZeroDebt_FreshAccount_Reverts() external {
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);

        _execSingleExpectUserOpRevert(address(repayHook), _morphoV2Data(PARTIAL_REPAY_USDC, 0, false));

        (, uint128 borrowShares,) = _position();
        assertEq(uint256(borrowShares), 0, "no debt");
        assertEq(IERC20(loanToken).balanceOf(accountEth), loanBefore, "loan token untouched");
    }

    /// @notice After a full close, repaying again reverts at build() time (NO_OUTSTANDING_DEBT).
    function test_V2_StandaloneRepay_ZeroDebt_AfterFullClose_Reverts() external {
        _open(COLLATERAL_WBTC, BORROW_USDC);
        vm.warp(block.timestamp + 30 days);
        _getTokens(loanToken, accountEth, IERC20(loanToken).balanceOf(accountEth) + BORROW_USDC);
        _execSingle(address(closeHook), _morphoV2Data(type(uint256).max, type(uint256).max, false));

        (, uint128 borrowShares, uint128 collateral) = _position();
        assertEq(uint256(borrowShares), 0, "position closed");
        assertEq(uint256(collateral), 0, "collateral withdrawn");

        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);
        _execSingleExpectUserOpRevert(address(repayHook), _morphoV2Data(PARTIAL_REPAY_USDC, 0, false));
        assertEq(IERC20(loanToken).balanceOf(accountEth), loanBefore, "loan token untouched");
    }
}
