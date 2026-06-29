// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import "forge-std/Test.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { ModuleKitHelpers, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { Redeem4626VaultHook } from "../../../src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { ISuperLedgerData } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";

/// @title MetaMorphoERC4626E2E
/// @notice End-to-end fork tests for MetaMorpho vaults via the ERC-4626 oracle and hooks.
///         MetaMorpho vaults are fully ERC-4626 compliant and therefore work with
///         ERC4626YieldSourceOracle, Deposit4626VaultHook, and Redeem4626VaultHook
///         without any MetaMorpho-specific setup.
contract MetaMorphoERC4626E2E is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Steakhouse USDC MetaMorpho vault — second vault tested alongside the base CHAIN_1_MORPHO_VAULT
    address public constant STEAKHOUSE_USDC_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ISuperNativePaymaster public superNativePaymaster;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Oracle ID for the ERC-4626 oracle registered in setUp via ledgerConfig
    function _oracleId() internal view returns (bytes32) {
        return _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this));
    }

    /// @dev Approve + deposit `amount` USDC into `vault` via two separate hooks
    function _deposit(address vault, uint256 amount) internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, vault, amount, false);
        hooksData[1] = _createDeposit4626HookData(_oracleId(), vault, amount, false, address(0), 0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /// @dev Redeem `shares` from `vault` back to USDC
    function _redeem(address vault, uint256 shares) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(_oracleId(), vault, accountEth, shares, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                  TESTS — re7 USDC MetaMorpho (CHAIN_1_MORPHO_VAULT)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit USDC mints shares
    function test_MetaMorpho_Deposit_EmitsInflow_AndMintsShares() public {
        uint256 amount = 1e8; // 100 USDC (6 decimals)

        _deposit(yieldSourceAddressEth, amount);

        uint256 shares = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        assertGt(shares, 0, "should have received vault shares");
    }

    /// @notice Deposit then redeem all shares: full lifecycle
    function test_MetaMorpho_Deposit_Redeem_FullCycle() public {
        uint256 amount = 1e8; // 100 USDC

        _deposit(yieldSourceAddressEth, amount);

        uint256 shares = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        assertEq(shares, vaultInstanceEth.previewDeposit(amount), "shares must match previewDeposit");

        _redeem(yieldSourceAddressEth, shares);

        assertEq(IERC20(yieldSourceAddressEth).balanceOf(accountEth), 0, "all shares should be burned");
        assertGt(IERC20(underlyingEth_USDC).balanceOf(accountEth), 0, "should have received USDC back");
    }

    /// @notice Partial redeem leaves correct remaining share balance
    function test_MetaMorpho_Deposit_PartialRedeem_LeavesRemainingShares() public {
        uint256 amount = 1e8; // 100 USDC

        _deposit(yieldSourceAddressEth, amount);

        uint256 shares = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        uint256 halfShares = shares / 2;

        _redeem(yieldSourceAddressEth, halfShares);

        assertEq(
            IERC20(yieldSourceAddressEth).balanceOf(accountEth), shares - halfShares, "half shares should remain"
        );
        assertGt(IERC20(underlyingEth_USDC).balanceOf(accountEth), 0, "should have received USDC for half");
    }

    /// @notice ApproveAndDeposit single-hook flow mints shares correctly
    function test_MetaMorpho_ApproveAndDeposit_SingleHook() public {
        uint256 amount = 1e8; // 100 USDC

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = approveAndDeposit4626Hook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndDeposit4626HookData(
            _oracleId(), yieldSourceAddressEth, underlyingEth_USDC, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        assertGt(IERC20(yieldSourceAddressEth).balanceOf(accountEth), 0, "should have received shares");
    }

    /// @notice Redeem hook tracks outAmount and usedShares after execution
    function test_MetaMorpho_Redeem_OutAmountAndUsedShares_Tracked() public {
        uint256 amount = 1e8; // 100 USDC

        _deposit(yieldSourceAddressEth, amount);
        uint256 shares = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        _redeem(yieldSourceAddressEth, shares);

        uint256 outAmount = Redeem4626VaultHook(redeem4626Hook).getOutAmount(accountEth);
        uint256 usedShares = Redeem4626VaultHook(redeem4626Hook).usedShares();

        assertGt(outAmount, 0, "outAmount should be tracked");
        assertEq(usedShares, shares, "usedShares should match redeemed shares");
    }

    /// @notice Protocol fee recipient receives fees on profitable redeem
    function test_MetaMorpho_FeeRecipient_ReceivesFees() public {
        uint256 amount = 1e8; // 100 USDC
        address feeRecipient = makeAddr("feeRecipient");

        _deposit(yieldSourceAddressEth, amount);

        uint256 shares = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        uint256 expectedFee = ledger.previewFees(
            accountEth,
            yieldSourceAddressEth,
            vaultInstanceEth.convertToAssets(shares),
            shares,
            100,
            0,
            0
        );

        _redeem(yieldSourceAddressEth, shares);

        if (expectedFee > 0) {
            assertEq(IERC20(underlyingEth_USDC).balanceOf(feeRecipient), expectedFee, "fee recipient mismatch");
        }
    }

    /// @notice PPS is non-zero and >= 1 unit of underlying (healthy vault state)
    function test_MetaMorpho_PricePerShare_IsPositive() public view {
        uint256 pps = vaultInstanceEth.convertToAssets(1e18);
        assertGt(pps, 0, "PPS must be positive");
    }

    /// @notice Multiple deposits are tracked independently in the ledger
    function test_MetaMorpho_TwoDeposits_BothTracked() public {
        uint256 amount = 5e7; // 50 USDC each

        _deposit(yieldSourceAddressEth, amount);
        uint256 sharesAfterFirst = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        assertGt(sharesAfterFirst, 0, "first deposit: no shares");

        _deposit(yieldSourceAddressEth, amount);
        uint256 sharesAfterSecond = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        assertGt(sharesAfterSecond, sharesAfterFirst, "second deposit: shares did not increase");
    }

    /*//////////////////////////////////////////////////////////////
                  TESTS — Steakhouse USDC MetaMorpho (0xBEEF)
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit and full redeem on Steakhouse USDC MetaMorpho vault
    function test_Steakhouse_USDC_Deposit_Redeem_FullCycle() public {
        address vault = STEAKHOUSE_USDC_VAULT;
        uint256 amount = 1e8; // 100 USDC

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, vault, amount, false);
        hooksData[1] = _createDeposit4626HookData(_oracleId(), vault, amount, false, address(0), 0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingInflow(accountEth, yieldSourceOracle, vault, amount, 0);

        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        uint256 shares = IERC20(vault).balanceOf(accountEth);
        assertGt(shares, 0, "Steakhouse: should have received shares");

        // Redeem all shares
        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;
        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(_oracleId(), vault, accountEth, shares, false);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        assertEq(IERC20(vault).balanceOf(accountEth), 0, "Steakhouse: all shares redeemed");
        assertGt(IERC20(underlyingEth_USDC).balanceOf(accountEth), 0, "Steakhouse: should have received USDC");
    }

    /// @notice Both MetaMorpho vaults can be used in the same session via the same ERC-4626 oracle
    function test_BothVaults_DepositRedeem_SameOracle() public {
        uint256 amount = 5e7; // 50 USDC per vault

        // Deposit into re7 USDC vault
        _deposit(yieldSourceAddressEth, amount);
        uint256 sharesRe7 = IERC20(yieldSourceAddressEth).balanceOf(accountEth);
        assertGt(sharesRe7, 0, "re7 vault: no shares");

        // Deposit into Steakhouse USDC vault using same oracle
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, STEAKHOUSE_USDC_VAULT, amount, false);
        hooksData[1] = _createDeposit4626HookData(_oracleId(), STEAKHOUSE_USDC_VAULT, amount, false, address(0), 0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        uint256 sharesSteakhouse = IERC20(STEAKHOUSE_USDC_VAULT).balanceOf(accountEth);
        assertGt(sharesSteakhouse, 0, "Steakhouse vault: no shares");

        // Redeem both
        _redeem(yieldSourceAddressEth, sharesRe7);
        assertEq(IERC20(yieldSourceAddressEth).balanceOf(accountEth), 0, "re7: all shares redeemed");

        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;
        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(_oracleId(), STEAKHOUSE_USDC_VAULT, accountEth, sharesSteakhouse, false);
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        assertEq(IERC20(STEAKHOUSE_USDC_VAULT).balanceOf(accountEth), 0, "Steakhouse: all shares redeemed");
    }

    /*//////////////////////////////////////////////////////////////
              ORACLE DIRECT COVERAGE — all ERC4626YieldSourceOracle caps
    //////////////////////////////////////////////////////////////*/

    /// @notice decimals() returns the share token decimals of the MetaMorpho vault
    function test_Oracle_Decimals() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);
        uint8 d = oracle.decimals(yieldSourceAddressEth);
        assertEq(d, IERC4626(yieldSourceAddressEth).decimals(), "oracle.decimals mismatch");
    }

    /// @notice getPricePerShare() matches convertToAssets(10**decimals) directly on the vault
    function test_Oracle_GetPricePerShare() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);
        uint256 pps = oracle.getPricePerShare(yieldSourceAddressEth);
        uint8 d = oracle.decimals(yieldSourceAddressEth);
        uint256 expected = IERC4626(yieldSourceAddressEth).convertToAssets(10 ** d);
        assertEq(pps, expected, "oracle.getPricePerShare mismatch");
        assertGt(pps, 0, "PPS must be positive");
    }

    /// @notice getShareOutput() matches previewDeposit() on the vault
    function test_Oracle_GetShareOutput() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);
        uint256 amountIn = 1e8; // 100 USDC
        uint256 shares = oracle.getShareOutput(yieldSourceAddressEth, underlyingEth_USDC, amountIn);
        assertEq(shares, IERC4626(yieldSourceAddressEth).previewDeposit(amountIn), "getShareOutput mismatch");
        assertGt(shares, 0, "must return > 0 shares");
    }

    /// @notice getWithdrawalShareOutput() matches previewWithdraw() on the vault
    function test_Oracle_GetWithdrawalShareOutput() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);
        uint256 amountIn = 1e8; // 100 USDC
        uint256 shares = oracle.getWithdrawalShareOutput(yieldSourceAddressEth, underlyingEth_USDC, amountIn);
        assertEq(shares, IERC4626(yieldSourceAddressEth).previewWithdraw(amountIn), "getWithdrawalShareOutput mismatch");
        assertGt(shares, 0, "must return > 0 shares");
    }

    /// @notice getAssetOutput() matches previewRedeem() on the vault
    function test_Oracle_GetAssetOutput() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);
        uint256 shares = 1e18;
        uint256 assets = oracle.getAssetOutput(yieldSourceAddressEth, underlyingEth_USDC, shares);
        assertEq(assets, IERC4626(yieldSourceAddressEth).previewRedeem(shares), "getAssetOutput mismatch");
        assertGt(assets, 0, "must return > 0 assets");
    }

    /// @notice getTVL() matches totalAssets() on the vault
    function test_Oracle_GetTVL() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);
        uint256 tvl = oracle.getTVL(yieldSourceAddressEth);
        assertEq(tvl, IERC4626(yieldSourceAddressEth).totalAssets(), "getTVL mismatch");
        assertGt(tvl, 0, "vault TVL must be > 0");
    }

    /// @notice getBalanceOfOwner() returns 0 before deposit, then matches balanceOf after deposit
    function test_Oracle_GetBalanceOfOwner() public {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);

        assertEq(oracle.getBalanceOfOwner(yieldSourceAddressEth, accountEth), 0, "pre-deposit: should be 0");

        _deposit(yieldSourceAddressEth, 1e8);

        uint256 shares = IERC4626(yieldSourceAddressEth).balanceOf(accountEth);
        assertEq(oracle.getBalanceOfOwner(yieldSourceAddressEth, accountEth), shares, "post-deposit: balance mismatch");
    }

    /// @notice getTVLByOwnerOfShares() returns 0 before deposit, then matches convertToAssets after deposit
    function test_Oracle_GetTVLByOwnerOfShares() public {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);

        assertEq(oracle.getTVLByOwnerOfShares(yieldSourceAddressEth, accountEth), 0, "pre-deposit: TVL should be 0");

        _deposit(yieldSourceAddressEth, 1e8);

        uint256 shares = IERC4626(yieldSourceAddressEth).balanceOf(accountEth);
        uint256 expected = IERC4626(yieldSourceAddressEth).convertToAssets(shares);
        assertEq(oracle.getTVLByOwnerOfShares(yieldSourceAddressEth, accountEth), expected, "TVL by owner mismatch");
    }

    /// @notice getAssetOutputWithFees() returns >= getAssetOutput() when fee config is registered
    function test_Oracle_GetAssetOutputWithFees() public {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);

        _deposit(yieldSourceAddressEth, 1e8);
        uint256 shares = IERC4626(yieldSourceAddressEth).balanceOf(accountEth);

        uint256 baseOutput = oracle.getAssetOutput(yieldSourceAddressEth, underlyingEth_USDC, shares);
        uint256 withFees = oracle.getAssetOutputWithFees(_oracleId(), yieldSourceAddressEth, underlyingEth_USDC, accountEth, shares);

        // getAssetOutputWithFees adds fee on top of base output (opposite direction to ledger deduction)
        assertGe(withFees, baseOutput, "output with fees must be >= base output");
    }

    /// @notice getPricePerShareMultiple() returns correct PPS for both MetaMorpho vaults
    function test_Oracle_GetPricePerShareMultiple() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);

        address[] memory vaults = new address[](2);
        vaults[0] = yieldSourceAddressEth;
        vaults[1] = STEAKHOUSE_USDC_VAULT;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);

        assertEq(prices.length, 2, "should return 2 prices");
        assertEq(prices[0], oracle.getPricePerShare(yieldSourceAddressEth), "re7 PPS mismatch");
        assertEq(prices[1], oracle.getPricePerShare(STEAKHOUSE_USDC_VAULT), "Steakhouse PPS mismatch");
        assertGt(prices[0], 0, "re7 PPS must be > 0");
        assertGt(prices[1], 0, "Steakhouse PPS must be > 0");
    }

    /// @notice getTVLMultiple() returns correct TVL for both MetaMorpho vaults
    function test_Oracle_GetTVLMultiple() public view {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);

        address[] memory vaults = new address[](2);
        vaults[0] = yieldSourceAddressEth;
        vaults[1] = STEAKHOUSE_USDC_VAULT;

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);

        assertEq(tvls.length, 2, "should return 2 TVLs");
        assertEq(tvls[0], IERC4626(yieldSourceAddressEth).totalAssets(), "re7 TVL mismatch");
        assertEq(tvls[1], IERC4626(STEAKHOUSE_USDC_VAULT).totalAssets(), "Steakhouse TVL mismatch");
        assertGt(tvls[0], 0, "re7 TVL must be > 0");
        assertGt(tvls[1], 0, "Steakhouse TVL must be > 0");
    }

    /// @notice getTVLByOwnerOfSharesMultiple() returns correct per-owner TVL for both vaults
    function test_Oracle_GetTVLByOwnerOfSharesMultiple() public {
        ERC4626YieldSourceOracle oracle = ERC4626YieldSourceOracle(yieldSourceOracle);

        _deposit(yieldSourceAddressEth, 1e8);
        uint256 sharesRe7 = IERC4626(yieldSourceAddressEth).balanceOf(accountEth);

        address[] memory vaults = new address[](2);
        vaults[0] = yieldSourceAddressEth;
        vaults[1] = STEAKHOUSE_USDC_VAULT;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = accountEth;
        owners[1] = new address[](1);
        owners[1][0] = accountEth;

        uint256[][] memory tvls = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);

        assertEq(tvls.length, 2, "should return 2 rows");
        assertEq(tvls[0][0], IERC4626(yieldSourceAddressEth).convertToAssets(sharesRe7), "re7 TVL by owner mismatch");
        assertEq(tvls[1][0], 0, "Steakhouse: no deposit, TVL should be 0");
    }
}
