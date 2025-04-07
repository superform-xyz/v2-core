// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IOracle } from "../../../src/vendor/morpho/IOracle.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IMorphoBase } from "../../../src/vendor/morpho/IMorpho.sol";
import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

contract SuperVaultBorrowDepositTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public morpho;
    address public oracle;
    address public irm;
    address public loanToken;
    address public collateralToken;

    uint256 public lltv;
    uint256 public amount;
    uint256 public constant PRECISION = 1e18;

    ISuperExecutor public superExecutorOnETH;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        amount = 1000e6;
  
        vm.selectFork(FORKS[ETH]);
        
        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];
        vm.label(accountEth, "AccountETH");

        // Set up tokens
        collateralToken = existingUnderlyingTokens[ETH][WST_ETH_KEY];
        vm.label(collateralToken, "CollateralToken");
    
        loanToken = existingUnderlyingTokens[ETH][USDC_KEY];
        vm.label(loanToken, "LoanToken");

        // Set up morpho
        lltv = 860000000000000000;
        morpho = MORPHO;
        vm.label(morpho, "Morpho");
        irm = MORPHO_IRM;
        vm.label(irm, "MorphoIRM");
        oracle = MORPHO_ORACLE;
        vm.label(oracle, "MorphoOracle");

        // Set up super vault
        vm.startPrank(SV_MANAGER);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault Morpho-Fluid",
                symbol: "svMorphoFluid",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                superVaultCap: SUPER_VAULT_CAP
            })
        );
        vm.label(vaultAddr, "MorphoFluidSuperVault");
        vm.label(strategyAddr, "MorphoFluidSuperVaultStrategy");
        vm.label(escrowAddr, "MorphoFluidSuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        escrow = SuperVaultEscrow(escrowAddr);
        strategy = SuperVaultStrategy(strategyAddr);

        // Add a new yield source as manager
        strategy.manageYieldSource(
            address(fluidVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        vm.stopPrank();

        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(_getMerkleRoot());
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));

        strategy.proposeVaultFeeConfigUpdate(100, TREASURY);
        vm.warp(block.timestamp + 1 weeks);
        strategy.executeVaultFeeConfigUpdate();
        vm.stopPrank();
        
        // Set up yield source oracle
        vm.startPrank(MANAGER);
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: TREASURY,
            ledger: _getContract(ETH, SUPER_LEDGER_KEY)
        });
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(configs);
        vm.stopPrank();

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BorrowHook_E2E() public {
        console2.log("Original pps", _getSuperVaultPricePerShare());

        // Request deposit into superVault as user1
        _requestDeposit(amount);

        console2.log("\n user1 pending deposit", strategy.pendingDepositRequest(accountEth));
        console2.log("\n pps After Request Deposit1", _getSuperVaultPricePerShare());

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequestsWithBorrow();
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());

        // Claim deposit into superVault as user1
        _claimDeposit(amount);
        console2.log("\n user1 SV Share Balance After Claim Deposit", vault.balanceOf(accountEth));
        
        

        
    }

    function test_BorrowHook() public {
        address hook = _getHookAddress(ETH, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 collateralAmount = _deriveCollateralAmount(amount, oracle, loanToken, collateralToken);
        _getTokens(CHAIN_1_WST_ETH, accountEth, collateralAmount);

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountEth);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountEth);

        bytes memory hookData = _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false);
        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(userOpData);

        uint256 loanBalanceAfter = IERC20(loanToken).balanceOf(accountEth);
        uint256 collateralBalanceAfter = IERC20(collateralToken).balanceOf(accountEth);

        assertEq(loanBalanceAfter, loanBalanceBefore + amount);
        assertEq(collateralBalanceAfter, collateralBalanceBefore - collateralAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _deriveCollateralAmount(
        uint256 loanAmount,
        address oracleAddress,
        address loan,
        address collateral
    )
        internal
        view
        returns (uint256 collateralAmount) {
        IOracle oracleInstance = IOracle(oracleAddress);

        uint256 price = oracleInstance.price();
        uint256 loanDecimals = ERC20(loan).decimals();
        uint256 collateralDecimals = ERC20(collateral).decimals();

        uint256 scalingFactor = 10 ** (36 + collateralDecimals - loanDecimals);
        collateralAmount = Math.mulDiv(loanAmount, scalingFactor, price);
    }

    function _fulfillDepositRequestsWithBorrow() public {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;

        address hook = _getHookAddress(ETH, MORPHO_BORROW_HOOK_KEY);
        address depositHook = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);
        address[] memory hooks = new address[](2);
        hooks[0] = hook;
        hooks[1] = depositHook;

        uint256 collateralAmount = _deriveCollateralAmount(amount, oracle, loanToken, collateralToken);
        _getTokens(CHAIN_1_WST_ETH, address(strategy), collateralAmount);

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountEth);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountEth);

        bytes memory hookData = _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false);
        bytes memory depositHookData = _createApproveAndDeposit4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), address(asset), amount, false, false);
        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = hookData;
        hookDataArray[1] = depositHookData;

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = fluidVault.previewDeposit(amount);

        ISuperVaultStrategy.ExecuteArgs memory executeArgs = ISuperVaultStrategy.ExecuteArgs({
            users: requestingUsers,
            hooks: hooks,
            hookCalldata: hookDataArray,
            hookProofs: _getMerkleProofsForAddresses(hooks),
            expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
        });

        vm.prank(SV_MANAGER);
        strategy.executeHooks(executeArgs);
    }
    
}