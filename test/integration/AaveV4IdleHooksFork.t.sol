// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { VmSafe } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { AaveV4ReserveRegistry } from "../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { AaveV4LendHook } from "../../src/hooks/loan/aave-v4/AaveV4LendHook.sol";
import { AaveV4RedeemHook } from "../../src/hooks/loan/aave-v4/AaveV4RedeemHook.sol";
import { BaseAaveV4MoneyMarketHook } from "../../src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { IAaveV4Spoke } from "../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4IdleHooksFork
/// @notice SUP-21142 E2E on Ethereum mainnet: AaveV4LendHook / AaveV4RedeemHook through the REAL
///         SuperExecutor, SuperLedger and AaveV4SupplyYieldSourceOracle registered at the reserve key,
///         against the live Main Spoke USDC reserve (id 7). Proves: supply-only (collateral flag never
///         flips), exact wallet deltas, identity-PPS ledger netting, fail-closed on unregistered keys.
contract AaveV4IdleHooksFork is MinimalBaseIntegrationTest {
    address public constant SPOKE = 0x94e7A5dCbE816e498b89aB752661904E2F56c485;
    uint256 public constant USDC_RESERVE_ID = 7;
    uint256 public constant GHO_RESERVE_ID = 13;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    uint256 public constant LEND = 1000e6;
    bytes32 public constant ORACLE_SALT = bytes32("AaveV4SupplyYieldSourceOracle");
    bytes32 internal constant COLLATERAL_EVENT = keccak256("SetUsingAsCollateral(uint256,address,address,bool)");

    AaveV4LendHook public lendHook;
    AaveV4RedeemHook public redeemHook;
    AaveV4ReserveRegistry public registry;
    AaveV4SupplyYieldSourceOracle public oracle;
    ISuperNativePaymaster public superNativePaymaster;
    SuperLedger public superLedger;
    address public feeRecipient;
    address public usdcKey;
    bytes32 public oracleId;

    function setUp() public override {
        blockNumber = AAVE_V4_BLOCK;
        super.setUp();

        registry = new AaveV4ReserveRegistry(address(this));
        usdcKey = registry.registerReserve(SPOKE, USDC_RESERVE_ID);
        oracle = new AaveV4SupplyYieldSourceOracle(address(ledgerConfig), address(registry));
        feeRecipient = makeAddr("aaveIdleFeeRecipient");

        // Register the identity-PPS supply oracle with feePercent = 0 (operational invariant) on the
        // real SuperLedger the executor posts to.
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle), feePercent: 0, feeRecipient: feeRecipient, ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = ORACLE_SALT;
        ledgerConfig.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(ORACLE_SALT, address(this));

        superLedger = SuperLedger(address(ledger));
        lendHook = new AaveV4LendHook();
        redeemHook = new AaveV4RedeemHook();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        _getTokens(CHAIN_1_USDC, accountEth, 10_000e6);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _idleData(
        address underlying,
        uint256 reserveId,
        uint256 amount,
        bool usePrev
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            oracleId, registry.computeReserveKey(SPOKE, reserveId), underlying, SPOKE, reserveId, amount, usePrev
        );
    }

    function _lendData(uint256 amount) internal view returns (bytes memory) {
        return _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, amount, false);
    }

    function _redeemData(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return _idleData(CHAIN_1_USDC, USDC_RESERVE_ID, amount, usePrev);
    }

    function _execute(address hook, bytes memory data) internal returns (ExecutionReturnData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return _executeHooks(hooks, datas);
    }

    function _executeHooks(address[] memory hooks, bytes[] memory datas) internal returns (ExecutionReturnData memory) {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        return executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /// @dev The userOp execution phase must revert with `expectedSelector` (surfaced by the EntryPoint via
    ///      UserOperationRevertReason)
    function _executeExpectFailure(address hook, bytes memory data, bytes4 expectedSelector) internal {
        ExecutionReturnData memory ret = _execute(hook, data);
        bytes32 revertTopic = keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)");
        bool found;
        for (uint256 i; i < ret.logs.length; ++i) {
            VmSafe.Log memory log = ret.logs[i];
            if (log.topics.length > 0 && log.topics[0] == revertTopic && _containsSelector(log.data, expectedSelector))
            {
                found = true;
                break;
            }
        }
        assertTrue(found, "expected UserOperationRevertReason with the given selector");
    }

    function _containsSelector(bytes memory blob, bytes4 selector) internal pure returns (bool) {
        if (blob.length < 4) return false;
        for (uint256 i; i <= blob.length - 4; ++i) {
            if (
                blob[i] == selector[0] && blob[i + 1] == selector[1] && blob[i + 2] == selector[2]
                    && blob[i + 3] == selector[3]
            ) return true;
        }
        return false;
    }

    function _collateralEventCount(ExecutionReturnData memory ret) internal pure returns (uint256 n) {
        for (uint256 i; i < ret.logs.length; ++i) {
            if (ret.logs[i].topics.length > 0 && ret.logs[i].topics[0] == COLLATERAL_EVENT) ++n;
        }
    }

    function _isCollateral() internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(SPOKE).getUserReserveStatus(USDC_RESERVE_ID, accountEth);
    }

    function _supplied() internal view returns (uint256) {
        return IAaveV4Spoke(SPOKE).getUserSuppliedAssets(USDC_RESERVE_ID, accountEth);
    }

    /// @dev Lends LEND and returns the credited position (within 1 wei of LEND, Aave rounds down)
    function _lend() internal returns (uint256 credited) {
        _execute(address(lendHook), _lendData(LEND));
        credited = _supplied();
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Lend_SupplyOnly_CollateralFlagNotFlipped() public {
        assertFalse(_isCollateral(), "fresh account: not collateral");
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        vm.expectCall(SPOKE, abi.encodeWithSelector(IAaveV4Spoke.setUsingAsCollateral.selector), 0);
        ExecutionReturnData memory ret = _execute(address(lendHook), _lendData(LEND));

        assertFalse(_isCollateral(), "lend must not flip the collateral bit");
        assertEq(_collateralEventCount(ret), 0, "no SetUsingAsCollateral event");
        assertEq(walletBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), LEND, "wallet spend exact");

        uint256 credited = _supplied();
        assertLe(LEND - credited, 1, "Aave rounds the credited position down by at most 1 wei");
        // Ledger keyed by the reserve key, in the oracle's units (identity pps), never by the spoke
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), credited, "accumulator shares");
        assertEq(superLedger.usersAccumulatorCostBasis(accountEth, usdcKey), credited, "cost basis 1:1");
        assertEq(superLedger.usersAccumulatorShares(accountEth, SPOKE), 0, "spoke never keyed");
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountEth), credited, "oracle balance == ledger shares");
        assertEq(oracle.getPricePerShare(usdcKey), 1e6, "identity pps");
    }

    function test_Lend_Then_RedeemFull_LedgerNets() public {
        uint256 credited = _lend();
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 feeBefore = IERC20(CHAIN_1_USDC).balanceOf(feeRecipient);

        ExecutionReturnData memory ret = _execute(address(redeemHook), _redeemData(type(uint256).max, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - walletBefore, credited, "full redeem pays the position");
        assertEq(_supplied(), 0);
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0, "shares net to zero");
        assertEq(superLedger.usersAccumulatorCostBasis(accountEth, usdcKey), 0, "cost basis nets to zero");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(feeRecipient), feeBefore, "feePercent 0: nothing charged");
        assertFalse(_isCollateral());
        assertEq(_collateralEventCount(ret), 0, "redeem needs no collateral toggle");
    }

    function test_Lend_Then_RedeemPartial_ExactAmount() public {
        uint256 credited = _lend();
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        _execute(address(redeemHook), _redeemData(400e6, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - walletBefore, 400e6, "partial receipt exact");
        uint256 remaining = _supplied();
        assertApproxEqAbs(remaining, credited - 400e6, 1, "position consumed within share rounding");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), remaining, "ledger tracks the position");
        assertEq(oracle.getBalanceOfOwner(usdcKey, accountEth), remaining);
    }

    function test_Lend_Then_Warp_RedeemFull_YieldNotTaxed() public {
        uint256 credited = _lend();
        vm.warp(block.timestamp + 30 days);
        uint256 accrued = _supplied();
        assertGt(accrued, credited, "position accrued interest");
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 feeBefore = IERC20(CHAIN_1_USDC).balanceOf(feeRecipient);

        _execute(address(redeemHook), _redeemData(type(uint256).max, false));

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth) - walletBefore, accrued, "yield paid out");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0, "capped usedShares clears the slot");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(feeRecipient), feeBefore, "feePercent 0: yield untaxed");
    }

    function test_Chain_Lend_Then_Redeem_UsePrev() public {
        uint256 walletBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooks = new address[](2);
        hooks[0] = address(lendHook);
        hooks[1] = address(redeemHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _lendData(LEND);
        datas[1] = _redeemData(0, true); // consumes the lend's outAmount against outToken == reserve key

        _executeHooks(hooks, datas);

        assertEq(_supplied(), 0, "everything the lend credited was redeemed");
        assertLe(walletBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), 1, "round trip loses at most 1 wei");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0);
    }

    function test_Redeem_RevertIf_NothingSupplied() public {
        _executeExpectFailure(address(redeemHook), _redeemData(LEND, false), BaseHook.AMOUNT_NOT_VALID.selector);
    }

    function test_UnregisteredKey_FailsClosed() public {
        // GHO reserve 13 is listed on the spoke but its key is NOT registered: the hook itself is happy,
        // accounting reverts through the oracle -> the whole userOp reverts (allowlist by construction).
        _getTokens(GHO, accountEth, 1000e18);
        _executeExpectFailure(
            address(lendHook),
            _idleData(GHO, GHO_RESERVE_ID, 100e18, false),
            AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector
        );
        assertEq(IAaveV4Spoke(SPOKE).getUserSuppliedAssets(GHO_RESERVE_ID, accountEth), 0, "nothing supplied");
    }

    /// @dev One mode per (account, reserve): once the account flags the reserve as collateral (LOAN
    ///      semantics), both idle hooks refuse it; clearing the flag restores idle operation.
    function test_CollateralFlaggedReserve_IsRefusedByBothHooks() public {
        uint256 credited = _lend();
        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(USDC_RESERVE_ID, true, accountEth);
        assertTrue(_isCollateral());

        _executeExpectFailure(
            address(redeemHook),
            _redeemData(type(uint256).max, false),
            BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        _executeExpectFailure(
            address(lendHook), _lendData(LEND), BaseAaveV4MoneyMarketHook.RESERVE_IS_COLLATERAL.selector
        );
        assertEq(_supplied(), credited, "nothing moved");
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), credited, "ledger untouched");

        vm.prank(accountEth);
        IAaveV4Spoke(SPOKE).setUsingAsCollateral(USDC_RESERVE_ID, false, accountEth);
        _execute(address(redeemHook), _redeemData(type(uint256).max, false));
        assertEq(_supplied(), 0);
        assertEq(superLedger.usersAccumulatorShares(accountEth, usdcKey), 0);
    }

    function test_Lend_RevertIf_HeaderKeyMismatch() public {
        bytes memory data = abi.encodePacked(
            oracleId,
            SPOKE,
            CHAIN_1_USDC,
            SPOKE,
            USDC_RESERVE_ID,
            LEND,
            false // LOAN-style: spoke in the header
        );
        _executeExpectFailure(address(lendHook), data, BaseAaveV4MoneyMarketHook.RESERVE_KEY_MISMATCH.selector);
    }

    function test_Lend_RevertIf_UnderlyingMismatch() public {
        _executeExpectFailure(
            address(lendHook),
            _idleData(CHAIN_1_WETH, USDC_RESERVE_ID, LEND, false),
            BaseAaveV4MoneyMarketHook.TOKEN_RESERVE_MISMATCH.selector
        );
    }
}
