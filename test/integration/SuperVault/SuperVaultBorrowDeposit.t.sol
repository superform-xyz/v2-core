// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IIrm } from "../../../src/vendor/morpho/IIrm.sol";
import { MathLib } from "../../../src/vendor/morpho/MathLib.sol";
import { IOracle } from "../../../src/vendor/morpho/IOracle.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SharesMathLib } from "../../../src/vendor/morpho/SharesMathLib.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IMorpho, MarketParams, Market, IMorphoStaticTyping, Id} from "../../../src/vendor/morpho/IMorpho.sol";
import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract SuperVaultBorrowDepositTest is BaseSuperVaultTest {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public morpho;
    address public oracle;
    address public irm;
    address public loanToken;
    address public collateralToken;

    address public morphoVault;
    IMorpho public morphoInterface;
    IERC4626 public morphoVaultInstance;
    IMorphoStaticTyping public morphoStaticTyping;

    uint256 public lltv;
    uint256 public amount;
    uint256 public collateralAmount;
    uint256 public constant PRECISION = 1e18;

    address public accountBase;
    AccountInstance public instanceOnBase;

    ISuperExecutor public superExecutorOnBase;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
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
        morphoVault = realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY];
        morphoVaultInstance = IERC4626(morphoVault);
        vm.label(morphoVault, "MorphoVault");

        // Set up morpho
        lltv = 860_000_000_000_000_000;
        morpho = MORPHO;
        vm.label(morpho, "Morpho");
        irm = MORPHO_IRM;
        vm.label(irm, "MorphoIRM");
        oracle = MORPHO_ORACLE;
        vm.label(oracle, "MorphoOracle");
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

        collateralAmount = _deriveCollateralAmount(amount, oracle, loanToken, collateralToken, false);
        console2.log("----collateralAmount", collateralAmount);
        _getTokens(address(asset), accountBase, collateralAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BorrowHook_E2E() public {
        console2.log("Original pps", _getSuperVaultPricePerShare());

        // Request deposit into superVault as user1
        _requestDepositOnBase(instanceOnBase, collateralAmount);

        console2.log("\n user1 pending deposit", strategy.pendingDepositRequest(accountBase));
        console2.log("\n pps After Request Deposit1", _getSuperVaultPricePerShare());

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequestsWithBorrow();
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());

        // Claim deposit into superVault as user1
        _claimDepositOnBase(instanceOnBase, collateralAmount);
        console2.log("\n user1 SV Share Balance After Claim Deposit", vault.balanceOf(accountBase));

        // Warp forward to simulate yield
        vm.warp(block.timestamp + 15 weeks);

        // Request redeem on superVault as user1
        _requestRedeemOnBase(instanceOnBase, vault.balanceOf(accountBase));
        console2.log("\n user1 pending redeem", strategy.pendingRedeemRequest(accountBase));
    }

    function test_BorrowHook() public {
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountBase);

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false, false);
        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        executeOp(userOpData);

        uint256 loanBalanceAfter = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceAfter = IERC20(collateralToken).balanceOf(accountBase);

        assertEq(loanBalanceAfter, loanBalanceBefore + amount);
        assertEq(collateralBalanceAfter, collateralBalanceBefore - collateralAmount);
    }

    function test_RepayHook_FullRepayment() public {
        // borrow
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountBase);

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false, false);
        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });
        UserOpData memory userOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        executeOp(userOpData);

        uint256 loanBalanceAfter = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceAfter = IERC20(collateralToken).balanceOf(accountBase);

        assertEq(loanBalanceAfter, loanBalanceBefore + amount);
        assertEq(collateralBalanceAfter, collateralBalanceBefore - collateralAmount);

        // repay
        address repayHook = _getHookAddress(BASE, MORPHO_REPAY_HOOK_KEY);
        hooks[0] = repayHook;

        bytes memory repayHookData =
            _createMorphoRepayHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false, true);
        hookDataArray[0] = repayHookData;

        uint256 assetsPaid = _deriveAssetsPaid();

        ISuperExecutor.ExecutorEntry memory repayEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });
        UserOpData memory repayUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(repayEntry));
        executeOp(repayUserOpData);

        uint256 loanBalanceAfterRepay = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceAfterRepay = IERC20(collateralToken).balanceOf(accountBase);

        assertEq(loanBalanceAfterRepay, loanBalanceAfter - assetsPaid);
        //assertEq(collateralBalanceAfterRepay, expectedCollateralBalanceAfterRepay);
    }

    function test_RepayHook_PartialRepayment() public {
        // borrow
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _requestDepositOnBase(AccountInstance memory accInst, uint256 depositAmount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(BASE, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndRequestDeposit7540HookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), address(asset), depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnBase, abi.encode(entry));
        executeOp(userOpData);
    }

    function _fulfillDepositRequestsWithBorrow() public {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountBase;

        // Execute borrow hook
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);

        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false, false);

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

        // Fulfill deposit into morpho vault
        address depositHook = _getHookAddress(BASE, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory depositHooks = new address[](1);
        depositHooks[0] = depositHook;

        bytes[] memory depositHookDataArray = new bytes[](1);
        depositHookDataArray[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(morphoVaultInstance),
            loanToken,
            amount,
            false,
            false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = morphoVaultInstance.previewDeposit(amount);

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

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _deriveCollateralAmount(
        uint256 loanAmount,
        address oracleAddress,
        address loan,
        address collateral,
        bool isPositiveFeed
    )
        internal
        view
        returns (uint256 collateralAmount)
    {
        IOracle oracleInstance = IOracle(oracleAddress);
        uint256 price = oracleInstance.price();
        uint256 loanDecimals = ERC20(loan).decimals();
        uint256 collateralDecimals = ERC20(collateral).decimals();

        // Correct scaling factor as per the oracle's specification:
        // 10^(36 + loanDecimals - collateralDecimals)
        uint256 scalingFactor = 10 ** (36 + loanDecimals - collateralDecimals);

        if (isPositiveFeed) {
            // For a positive feed, price is given as the amount of loan tokens per collateral token,
            // so we invert the price to calculate collateral:
            // collateralAmount = loanAmount * scalingFactor / price
            collateralAmount = Math.mulDiv(loanAmount, scalingFactor, price);
        } else {
            // For a negative feed, price is given as the amount of collateral tokens per loan token,
            // so no inversion is necessary:
            // collateralAmount = loanAmount * price / scalingFactor
            collateralAmount = Math.mulDiv(loanAmount, price, scalingFactor);
        }
    }

    function _deriveFeeAmount() internal view returns (uint256 feeAmount) {
        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
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
            oracle: oracle,
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
            oracle: oracle,
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
}
