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
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
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

    address public morphoVault;
    IERC4626 public morphoVaultInstance;

    uint256 public lltv;
    uint256 public amount;
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

        asset = IERC20Metadata(existingUnderlyingTokens[BASE][WETH_KEY]);

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
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BorrowHook_E2E() public {
        console2.log("Original pps", _getSuperVaultPricePerShare());

        // Request deposit into superVault as user1
        _requestDepositOnBase(instanceOnBase, amount);

        console2.log("\n user1 pending deposit", strategy.pendingDepositRequest(accountBase));
        console2.log("\n pps After Request Deposit1", _getSuperVaultPricePerShare());

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequestsWithBorrow();
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());

        // Claim deposit into superVault as user1
        _claimDepositOnBase(instanceOnBase, amount);
        console2.log("\n user1 SV Share Balance After Claim Deposit", vault.balanceOf(accountBase));
    }

    function test_BorrowHook() public {
        address hook = _getHookAddress(BASE, MORPHO_BORROW_HOOK_KEY);
        address[] memory hooks = new address[](1);
        hooks[0] = hook;

        uint256 collateralAmount = _deriveCollateralAmount(amount, oracle, loanToken, collateralToken);

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountEth);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountEth);

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false);
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
        returns (uint256 collateralAmount)
    {
        IOracle oracleInstance = IOracle(oracleAddress);

        uint256 price = oracleInstance.price();
        uint256 loanDecimals = ERC20(loan).decimals();
        uint256 collateralDecimals = ERC20(collateral).decimals();

        uint256 scalingFactor = 10 ** (36 + collateralDecimals - loanDecimals);
        collateralAmount = Math.mulDiv(loanAmount, scalingFactor, price);
    }

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

        uint256 collateralAmount = _deriveCollateralAmount(amount, oracle, loanToken, collateralToken);

        uint256 loanBalanceBefore = IERC20(loanToken).balanceOf(accountBase);
        uint256 collateralBalanceBefore = IERC20(collateralToken).balanceOf(accountBase);

        bytes memory hookData =
            _createMorphoBorrowHookData(loanToken, collateralToken, oracle, irm, amount, lltv, false);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = amount;

        ISuperVaultStrategy.ExecuteArgs memory executeArgs = ISuperVaultStrategy.ExecuteArgs({
            users: new address[](0),
            hooks: hooks,
            hookCalldata: hookDataArray,
            hookProofs: _getMerkleProofsForAddresses(BASE, hooks),
            //expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
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
            address(asset),
            amount,
            false,
            false
        );

        expectedAssetsOrSharesOut[0] = morphoVaultInstance.previewDeposit(amount);

        ISuperVaultStrategy.ExecuteArgs memory depositArgs = ISuperVaultStrategy.ExecuteArgs({
            users: requestingUsers,
            hooks: depositHooks,
            hookCalldata: depositHookDataArray,
            hookProofs: _getMerkleProofsForAddresses(ETH, depositHooks),
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
}
