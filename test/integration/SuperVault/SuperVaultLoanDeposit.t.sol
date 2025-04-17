// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { strings } from "@stringutils/strings.sol";
import { console2 } from "forge-std/console2.sol";
import { IIrm } from "../../../src/vendor/morpho/IIrm.sol";
import { MathLib } from "../../../src/vendor/morpho/MathLib.sol";
import { IOracle } from "../../../src/vendor/morpho/IOracle.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SharesMathLib } from "../../../src/vendor/morpho/SharesMathLib.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IMorpho, MarketParams, Market, IMorphoStaticTyping, Id } from "../../../src/vendor/morpho/IMorpho.sol";
import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract SuperVaultLoanDepositTest is BaseSuperVaultTest {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using ModuleKitHelpers for *;
    using Math for uint256;
    using strings for *;

    address public morpho;
    address public oracleAddress;
    IOracle public oracle;

    address public irm;
    address public loanToken;
    address public collateralToken;

    address public swapRouter;

    address public morphoVault;
    IMorpho public morphoInterface;
    IERC4626 public morphoVaultInstance;
    IMorphoStaticTyping public morphoStaticTyping;

    uint256 public lltv;
    uint256 public amount;
    uint256 public collateralAmount;
    uint256 public constant PRECISION = 1e18;

    uint256 liabilityAmount;

    address public accountBase;
    AccountInstance public instanceOnBase;

    ISuperExecutor public superExecutorOnBase;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        amount = 1000e6;
        vm.selectFork(FORKS[BASE]);

        // Set up accounts
        accountBase = accountInstances[BASE].account;
        instanceOnBase = accountInstances[BASE];
        vm.label(accountBase, "AccountBase");

        // Set up tokens
        collateralToken = existingUnderlyingTokens[BASE][USDC_KEY];
        vm.label(collateralToken, "CollateralToken");

        loanToken = existingUnderlyingTokens[BASE][WETH_KEY];
        vm.label(loanToken, "LoanToken");

        asset = IERC20Metadata(collateralToken);

        // Set up underlying vault
        morphoVault = realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        morphoVaultInstance = IERC4626(morphoVault);
        vm.label(morphoVault, "MorphoVault");

        // Set up morpho
        lltv = 860_000_000_000_000_000;
        morpho = MORPHO;
        vm.label(morpho, "Morpho");
        irm = MORPHO_IRM;
        vm.label(irm, "MorphoIRM");
        oracleAddress = MORPHO_ORACLE;
        vm.label(oracleAddress, "MorphoOracle");
        oracle = IOracle(oracleAddress);
        morphoInterface = IMorpho(morpho);
        morphoStaticTyping = IMorphoStaticTyping(morpho);
        // Set up factory
        factory = new SuperVaultFactory(_getContract(BASE, PERIPHERY_REGISTRY_KEY));

        // Set up super vault
        vm.startPrank(SV_MANAGER);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault Morpho",
                symbol: "svMorpho",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                superVaultCap: SUPER_VAULT_CAP
            })
        );
        vm.label(vaultAddr, "MorphoSuperVault");
        vm.label(strategyAddr, "MorphoSuperVaultStrategy");
        vm.label(escrowAddr, "MorphoSuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        escrow = SuperVaultEscrow(escrowAddr);
        strategy = SuperVaultStrategy(strategyAddr);

        // Add a new yield source as manager
        strategy.manageYieldSource(
            morphoVault,
            _getContract(BASE, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        vm.stopPrank();

        // Set up super executor
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));

        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(_getMerkleRoot());
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));

        strategy.proposeVaultFeeConfigUpdate(100, TREASURY);
        vm.warp(block.timestamp + 1 weeks);
        strategy.executeVaultFeeConfigUpdate();

        strategy.proposeOrExecuteHookRoot(hookRootPerChain[BASE]);
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();

        collateralAmount = _deriveCollateralAmount(amount);

        _getTokens(address(asset), accountBase, 1e18);

        // Set up odos router
        swapRouter = ODOS_ROUTER[BASE];
        deal(address(asset), swapRouter, 2e18);
        deal(address(loanToken), swapRouter, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Borrow_Repay_Hooks_E2E() public {
        console2.log("Original pps", _getSuperVaultPricePerShare());

        // Request deposit into superVault as user1
        _requestDepositOnBase(instanceOnBase, amount);

        console2.log("\n user1 pending deposit", strategy.pendingDepositRequest(accountBase));

        _executeSuperVault_Borrow();

        // Repay loan
        _repayLoan();

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequest();
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());

        // Claim deposit into superVault as user1
        _claimDepositOnBase(instanceOnBase, amount);
        console2.log("\n user1 SV Share Balance After Claim Deposit", vault.balanceOf(accountBase));

        console2.log("\n pps After Repay", _getSuperVaultPricePerShare());
        console2.log("----collateralBalanceAfterRepay", IERC20(collateralToken).balanceOf(address(strategy)));

        // Request redeem on superVault as user1
        _requestRedeemOnBase(instanceOnBase, vault.balanceOf(accountBase));
        console2.log("\n user1 pending redeem", strategy.pendingRedeemRequest(accountBase));

        // Fulfill redeem request
        _fulfillRedeemRequests();
        console2.log("\n user1 SV Share Balance After Fulfill Redeem", vault.balanceOf(accountBase));
        console2.log("\n pps After Fulfill Redeem", _getSuperVaultPricePerShare());

        // Claim redeem as user
        _claimRedeemOnBase();
    }

    function test_BorrowHook() public {
        _implementBorrowFlow();
    }

    function test_RepayAndWithdrawHook_FullRepayment() public {
        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountBase);

        // borrow
        _implementBorrowFlow();

        uint256 ltvRatio = 0.75e18;

        // repay
        address[] memory hooks = new address[](1);
        address repayHook = _getHookAddress(BASE, MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY);
        hooks[0] = repayHook;

        bytes[] memory repayHookDataArray = new bytes[](1);
        bytes memory repayHookData =
            _createMorphoRepayHookData(loanToken, collateralToken, oracleAddress, irm, amount, lltv, false, true);
        repayHookDataArray[0] = repayHookData;

        uint256 assetsPaid = _deriveAssetsPaid();

        ISuperExecutor.ExecutorEntry memory repayEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: repayHookDataArray });
        UserOpData memory repayUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(repayEntry));
        executeOp(repayUserOpData);

        uint256 loanBalanceAfterRepay = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceAfterRepay = IERC20(collateralToken).balanceOf(accountBase);

        assertEq(loanBalanceAfterRepay, (loanBalanceBefore + _deriveLoanAmount(amount, ltvRatio)) - assetsPaid);
        assertEq(collateralBalanceAfterRepay, collateralBalanceBefore);
    }

    function test_RepayAndWithdrawHook_PartialRepayment() public {
        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountBase);

        // borrow
        _implementBorrowFlow();

        uint256 ltvRatio = 0.75e18;

        // repay
        address[] memory hooks = new address[](1);
        address repayHook = _getHookAddress(BASE, MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY);
        hooks[0] = repayHook;

        bytes[] memory repayHookDataArray = new bytes[](1);

        bytes memory repayHookData = _createMorphoRepayHookData(
            loanToken, collateralToken, oracleAddress, irm, amount / 2, lltv, false, false
        );
        repayHookDataArray[0] = repayHookData;

        uint256 expectedCollateralBalanceAfterRepay =
            _deriveCollateralForPartialWithdraw(amount / 2, amount);

        ISuperExecutor.ExecutorEntry memory repayEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: repayHookDataArray });
        UserOpData memory repayUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(repayEntry));
        executeOp(repayUserOpData);

        uint256 loanBalanceAfterRepay = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceAfterRepay = IERC20(collateralToken).balanceOf(accountBase);

        assertEq(loanBalanceAfterRepay, (loanBalanceBefore + _deriveLoanAmount(amount, ltvRatio)) - amount / 2);

        assertEq(collateralBalanceAfterRepay, collateralBalanceBefore - amount + expectedCollateralBalanceAfterRepay);
    }

    function test_RepayHook_FullRepayment() public {
        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);

        // borrow
        _implementBorrowFlow();

        uint256 ltvRatio = 0.75e18;

        // repay
        address[] memory hooks = new address[](1);
        address repayHook = _getHookAddress(BASE, MORPHO_REPAY_HOOK_KEY);
        hooks[0] = repayHook;

        bytes[] memory repayHookDataArray = new bytes[](1);
        bytes memory repayHookData =
            _createMorphoRepayHookData(loanToken, collateralToken, oracleAddress, irm, amount, lltv, false, true);
        repayHookDataArray[0] = repayHookData;

        uint256 assetsPaid = _deriveAssetsPaid();

        ISuperExecutor.ExecutorEntry memory repayEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: repayHookDataArray });
        UserOpData memory repayUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(repayEntry));
        executeOp(repayUserOpData);

        uint256 loanBalanceAfterRepay = IERC20(loanToken).balanceOf(accountBase);

        assertEq(loanBalanceAfterRepay, (loanBalanceBefore + _deriveLoanAmount(amount, ltvRatio)) - assetsPaid);
    }

    function test_RepayHook_PartialRepayment() public {
        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);

        // borrow
        _implementBorrowFlow();

        uint256 ltvRatio = 0.75e18;

        bytes[] memory repayHookDataArray = new bytes[](1);

        // repay
        address[] memory hooks = new address[](1);
        address repayHook = _getHookAddress(BASE, MORPHO_REPAY_HOOK_KEY);
        hooks[0] = repayHook;

        bytes memory repayHookData = _createMorphoRepayHookData(
            loanToken, collateralToken, oracleAddress, irm, amount / 2, lltv, false, false
        );
        repayHookDataArray[0] = repayHookData;

        ISuperExecutor.ExecutorEntry memory repayEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: repayHookDataArray });
        UserOpData memory repayUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(repayEntry));
        executeOp(repayUserOpData);

        uint256 loanBalanceAfterRepay = IERC20(loanToken).balanceOf(accountBase);

        assertEq(loanBalanceAfterRepay, (loanBalanceBefore + _deriveLoanAmount(amount, ltvRatio)) - amount / 2);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _implementBorrowFlow() internal {
        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountBase);

        // borrow
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 ltvRatio = 0.75e18;

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracleAddress, irm, amount, ltvRatio, false, lltv);
        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        executeOp(userOpData);

        uint256 loanBalanceAfter = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceAfter = IERC20(collateralToken).balanceOf(accountBase);

        assertEq(loanBalanceAfter, loanBalanceBefore + _deriveLoanAmount(amount, ltvRatio));
        assertEq(collateralBalanceAfter, collateralBalanceBefore - amount);
    }

    function _requestDepositOnBase(AccountInstance memory accInst, uint256 depositAmount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(BASE, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndRequestDeposit7540HookData(address(vault), address(asset), depositAmount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnBase, abi.encode(entry));
        executeOp(userOpData);
    }

    function _executeSuperVault_Borrow() internal {
        // Execute borrow hook
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);

        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 ltvRatio = 0.75e18;

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracleAddress, irm, amount, ltvRatio, false, lltv);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperVaultStrategy.ExecuteArgs memory executeArgs = ISuperVaultStrategy.ExecuteArgs({
            users: new address[](0),
            hooks: hooks,
            hookCalldata: hookDataArray,
            hookProofs: _getMerkleProofsForAddresses(BASE, hooks),
            expectedAssetsOrSharesOut: new uint256[](1)
        });

        vm.prank(STRATEGIST);
        strategy.executeHooks(executeArgs);

        console2.log("\n pps After Borrow", _getSuperVaultPricePerShare());
    }

    function _fulfillDepositRequest() public {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountBase;

        // Fulfill deposit into morpho vault
        address depositHook = _getHookAddress(BASE, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory depositHooks = new address[](1);
        depositHooks[0] = depositHook;

        bytes[] memory depositHookDataArray = new bytes[](1);
        depositHookDataArray[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, collateralToken, amount, false, false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = IERC4626(morphoVault).previewDeposit(amount);

        ISuperVaultStrategy.ExecuteArgs memory depositArgs = ISuperVaultStrategy.ExecuteArgs({
            users: requestingUsers,
            hooks: depositHooks,
            hookCalldata: depositHookDataArray,
            hookProofs: _getMerkleProofsForAddresses(BASE, depositHooks),
            expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
        });

        vm.prank(STRATEGIST);
        strategy.executeHooks(depositArgs);
    }

    function _claimDepositOnBase(AccountInstance memory accInst, uint256 depositAmount) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(BASE, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(vault), depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnBase, abi.encode(claimEntry));
        executeOp(claimUserOpData);
        console2.log("pps after claimDepositOnBase", _getSuperVaultPricePerShare());
    }

    function _requestRedeemOnBase(AccountInstance memory accInst, uint256 redeemShares) internal {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(BASE, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRequestRedeem7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), redeemShares, false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });
        UserOpData memory redeemUserOpData = _getExecOps(accInst, superExecutorOnBase, abi.encode(redeemEntry));

        executeOp(redeemUserOpData);
    }

    function _fulfillRedeemRequests() internal {
        // redeem
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountBase;

        address redeemHook = _getHookAddress(BASE, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);

        address[] memory redeemHooks = new address[](1);
        redeemHooks[0] = redeemHook;

        uint256 redeemShares = strategy.pendingRedeemRequest(accountBase);

        bytes[] memory redeemHookData = new bytes[](1);
        redeemHookData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(morphoVaultInstance),
            address(morphoVaultInstance),
            address(strategy),
            redeemShares,
            false,
            false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        uint256 strategyShares = morphoVaultInstance.maxRedeem(address(strategy));
        expectedAssetsOrSharesOut[0] = morphoVaultInstance.convertToAssets(strategyShares);
        console2.log("----expectedAssetsOrSharesOut", expectedAssetsOrSharesOut[0]);

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: requestingUsers,
                hooks: redeemHooks,
                hookCalldata: redeemHookData,
                hookProofs: _getMerkleProofsForAddresses(BASE, redeemHooks),
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );

        console2.log("----loanToken balance after redeem", IERC20(loanToken).balanceOf(address(strategy)));
        console2.log("----collateral balance after redeem", IERC20(collateralToken).balanceOf(address(strategy)));
    }

    function _claimRedeemOnBase() internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(BASE, WITHDRAW_7540_VAULT_HOOK_KEY);

        uint256 withdrawAssets = vault.maxWithdraw(accountBase);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), withdrawAssets, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _repayLoan() internal {
        // repay and claim collateral
        address repayHook = _getHookAddress(BASE, MORPHO_REPAY_AND_WITHDRAW_HOOK_KEY);

        address[] memory repayHooks = new address[](1);
        repayHooks[0] = repayHook;

        uint256 ltvRatio = 0.75e18;

        //uint256 loanAmount = IERC20(loanToken).balanceOf(address(strategy));
        uint256 loanAmount = _deriveLoanAmount(amount, ltvRatio);
        console2.log("----loanAmount", loanAmount);

        bytes[] memory repayHookData = new bytes[](1);
        repayHookData[0] = _createMorphoRepayAndWithdrawHookData(
            loanToken, collateralToken, oracleAddress, irm, loanAmount, lltv, false, true
        );

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: repayHooks,
                hookCalldata: repayHookData,
                hookProofs: _getMerkleProofsForAddresses(BASE, repayHooks),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );
        vm.stopPrank();
        console2.log("----collateral balance after repay", IERC20(collateralToken).balanceOf(address(strategy)));
        console2.log("pps after loan repay", _getSuperVaultPricePerShare());
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _deriveCollateralAmount(
        uint256 loanAmount
    )
        internal
        view
        returns (uint256 collateral)
    {
        uint256 price = oracle.price();

        // For a positive feed, price is given as the amount of loan tokens per collateral token,
        // so we invert the price to calculate collateral:
        // collateralAmount = loanAmount * scalingFactor / price
        collateral = Math.mulDiv(loanAmount, 1e36, price);

    }

    function _deriveFeeAmount() internal view returns (uint256 feeAmount) {
        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracleAddress,
            irm: irm,
            lltv: lltv
        });
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
        uint256 elapsed = block.timestamp - market.lastUpdate;
        uint256 interest = MathLib.wMulDown(market.totalBorrowAssets, MathLib.wTaylorCompounded(borrowRate, elapsed));

        feeAmount = MathLib.wMulDown(interest, market.fee);
    }

    function _deriveShareBalance(address account) internal view returns (uint128 borrowShares) {
        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracleAddress,
            irm: irm,
            lltv: lltv
        });
        Id id = marketParams.id();
        (, borrowShares,) = morphoStaticTyping.position(id, account);
    }

    function _getMarketInfo() internal view returns (uint256 totalBorrowAssets, uint256 totalBorrowShares) {
        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracleAddress,
            irm: irm,
            lltv: lltv
        });
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        totalBorrowAssets = market.totalBorrowAssets;
        totalBorrowShares = market.totalBorrowShares;
    }

    function _deriveAssetsPaid() internal view returns (uint256 assetsPaid) {
        uint256 shareBalance = _deriveShareBalance(accountBase);
        (uint256 totalBorrowAssets, uint256 totalBorrowShares) = _getMarketInfo();
        assetsPaid = shareBalance.toAssetsUp(totalBorrowAssets, totalBorrowShares);
    }

    function _deriveLoanAmount(
        uint256 amountCollateral,
        uint256 ltvRatio
    )
        internal
        view
        returns (uint256 loanAmount)
    {
        IOracle oracleInstance = IOracle(oracleAddress);
        uint256 price = oracleInstance.price();

        // loanAmount = collateralAmount * price / scalingFactor
        uint256 fullAmount = Math.mulDiv(amountCollateral, price, 1e36);
        uint256 availableLoanAmount = Math.mulDiv(fullAmount, lltv, 1e18);
        loanAmount = Math.mulDiv(availableLoanAmount, ltvRatio, 1e18);
    }

    function _deriveCollateralForWithdraw(address account) internal view returns (uint256 collateral) {
        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracleAddress,
            irm: irm,
            lltv: lltv
        });
        Id id = marketParams.id();
        (,, uint128 collateralForPosition) = morphoStaticTyping.position(id, account);
        collateral = uint256(collateralForPosition);
    }

    function _deriveCollateralForPartialWithdraw(
        uint256 repaymentAmount,
        uint256 fullCollateral
    )
        internal
        view
        returns (uint256 withdrawableCollateral)
    {   
        uint256 ltvRatio = 0.75e18;
        uint256 fullLoanAmount = _deriveLoanAmount(amount, ltvRatio);

        withdrawableCollateral = Math.mulDiv(fullCollateral, repaymentAmount, fullLoanAmount);
    }
}
