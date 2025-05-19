// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// testing
import { BaseTest } from "../../../BaseTest.t.sol";
import { TotalAssetHelper } from "./TotalAssetHelper.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import { ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../../../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { SuperVaultAggregator } from "../../../../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { SuperGovernor } from "../../../../src/periphery/SuperGovernor.sol";
import { ISuperVaultStrategy } from "../../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../../src/core/interfaces/ISuperExecutor.sol";
import { FeeType } from "../../../../src/periphery/interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../../../../src/periphery/interfaces/ISuperVaultAggregator.sol";
import { IECDSAPPSOracle } from "../../../../src/periphery/interfaces/IECDSAPPSOracle.sol";
import { MerkleReader } from "../../../utils/merkle/helper/MerkleReader.sol";
import { ISuperHookInspector } from "../../../../src/core/interfaces/ISuperHook.sol";

contract BaseSuperVaultTest is MerkleReader, BaseTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public accountEth;
    AccountInstance public instanceOnEth;
    AccountInstance[] accInstances;

    ISuperExecutor public superExecutorOnEth;

    // Core contracts
    SuperVault public vault;
    SuperVaultEscrow public escrow;
    SuperVaultAggregator public aggregator;
    SuperVaultStrategy public strategy;
    SuperGovernor public superGovernor;
    IECDSAPPSOracle public ecdsappsOracle;

    // Helper contracts
    TotalAssetHelper public totalAssetHelper;

    // Tokens and yield sources
    IERC20Metadata public asset;
    IERC4626 public fluidVault;
    IERC4626 public aaveVault;

    // Constants
    uint256 constant LARGE_DEPOSIT = 100_000e6; // 100k USDC

    uint256 constant ONE_HUNDRED_PERCENT = 10_000;

    // Update state tracking
    struct SuperVaultState {
        uint256 accumulatorShares;
        uint256 accumulatorCostBasis;
    }

    // Track state for each user
    mapping(address user => SuperVaultState) private superVaultStates;

    function setUp() public virtual override {
        super.setUp();
        console2.log("--- SETUP BASE SUPERVAULT ---");

        vm.selectFork(FORKS[ETH]);
        accInstances = randomAccountInstances[ETH];
        assertEq(accInstances.length, ACCOUNT_COUNT);
        superGovernor = SuperGovernor(_getContract(ETH, SUPER_GOVERNOR_KEY));

        // Get aggregator
        aggregator = SuperVaultAggregator(_getContract(ETH, SUPER_VAULT_AGGREGATOR_KEY));

        superGovernor.proposeGlobalHooksRoot(_getMerkleRoot());
        vm.warp(block.timestamp + 20 minutes);
        aggregator.executeGlobalHooksRootUpdate();

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        accInstances = randomAccountInstances[ETH];

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        // Get ECDSA Oracle
        ecdsappsOracle = IECDSAPPSOracle(_getContract(ETH, ECDSAPPS_ORACLE_KEY));

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);

        address fluidVaultAddr = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        address aaveVaultAddr = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        vm.label(fluidVaultAddr, "FluidVault");
        vm.label(aaveVaultAddr, "AaveVault");

        // Get real yield sources from fork
        fluidVault = IERC4626(fluidVaultAddr);
        aaveVault = IERC4626(aaveVaultAddr);

        // Deploy vault using the new _deployVault function
        (address vaultAddr, address strategyAddr, address escrowAddr) = _deployVault("SV_USDC");

        console2.log("\n-----------");
        console2.log("SUPER VAULT STRATEGY", strategyAddr);
        console2.log("\n-----------");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Deploy TotalAssetHelper
        totalAssetHelper = new TotalAssetHelper();

        _setFeeConfig(100, TREASURY);

        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(
            address(fluidVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        strategy.manageYieldSource(
            address(aaveVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Struct to hold local variables for _deployVault to avoid stack too deep errors
     */
    struct DeployVaultVars {
        uint256 superVaultCap;
    }

    /**
     * @notice Deploys a new SuperVault with default configuration
     * @return vaultAddr The address of the deployed SuperVault
     * @return strategyAddr The address of the deployed SuperVaultStrategy
     * @return escrowAddr The address of the deployed SuperVaultEscrow
     */
    function _deployVault(
        address _asset,
        string memory _superVaultSymbol
    )
        internal
        returns (address vaultAddr, address strategyAddr, address escrowAddr)
    {
        vm.startPrank(SV_MANAGER);

        // Deploy the vault trio
        (vaultAddr, strategyAddr, escrowAddr) = aggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: _asset,
                name: "SuperVault",
                symbol: _superVaultSymbol,
                mainStrategist: STRATEGIST,
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: address(this) })
            })
        );

        // Label the contracts for easier identification
        vm.label(vaultAddr, string.concat("SuperVault ", _superVaultSymbol));
        vm.label(strategyAddr, string.concat("SuperVaultStrategy ", _superVaultSymbol));
        vm.label(escrowAddr, string.concat("SuperVaultEscrow ", _superVaultSymbol));

        vm.stopPrank();

        return (vaultAddr, strategyAddr, escrowAddr);
    }

    /**
     * @notice Deploys a new SuperVault with default configuration
     * @param _superVaultSymbol The symbol for the SuperVault
     * @return vaultAddr The address of the deployed SuperVault
     * @return strategyAddr The address of the deployed SuperVaultStrategy
     * @return escrowAddr The address of the deployed SuperVaultEscrow
     */
    function _deployVault(string memory _superVaultSymbol)
        internal
        returns (address vaultAddr, address strategyAddr, address escrowAddr)
    {
        return _deployVault(address(asset), _superVaultSymbol);
    }

    function __deposit(AccountInstance memory accInst, uint256 depositAmount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vault),
            address(asset),
            depositAmount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }
    /*
    Leaving commented for now
    function __requestDeposit(AccountInstance memory accInst, uint256 depositAmount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
    hooksData[0] = _createApproveAndRequestDeposit7540HookData(address(vault), address(asset), depositAmount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function __claimDeposit(AccountInstance memory accInst, uint256 depositAmount) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(vault), depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }
    */

    function __requestRedeem(AccountInstance memory accInst, uint256 redeemShares, bool shouldRevert) internal {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(ETH, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRequestRedeem7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), redeemShares, false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });
        UserOpData memory redeemUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(redeemEntry));

        if (shouldRevert) {
            accInst.expect4337Revert();
        }
        executeOp(redeemUserOpData);
    }

    function __claimWithdraw(AccountInstance memory accInst, uint256 assets) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createWithdraw7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(vault), assets, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _deposit(uint256 depositAmount) internal {
        __deposit(instanceOnEth, depositAmount);
    }

    function _depositForAccount(AccountInstance memory accInst, uint256 depositAmount) internal {
        __deposit(accInst, depositAmount);
    }

    function _depositForAllUsers(uint256 depositAmount) internal {
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            _getTokens(address(asset), accInstances[i].account, depositAmount);
            _depositForAccount(accInstances[i], depositAmount);
        }
    }

    /*
        Leaving commented for now

    function _claimDeposit(uint256 depositAmount) internal {
        __claimDeposit(instanceOnEth, depositAmount);
    }

    function _claimDepositForAccount(AccountInstance memory accInst, uint256 depositAmount) internal {
        __claimDeposit(accInst, depositAmount);
    }
    */

    function _requestRedeem(uint256 redeemShares) internal {
        __requestRedeem(instanceOnEth, redeemShares, false);
    }

    function _requestRedeemForAccount(AccountInstance memory accInst, uint256 redeemShares) internal {
        __requestRedeem(accInst, redeemShares, false);
    }

    function _requestRedeemForAccount_Revert(AccountInstance memory accInst, uint256 redeemShares) internal {
        __requestRedeem(accInst, redeemShares, true);
    }

    function _requestRedeemForAllUsers(uint256 redeemAmount) internal {
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            uint256 redeemShares = redeemAmount > 0 ? redeemAmount : vault.balanceOf(accInstances[i].account);
            _requestRedeemForAccount(accInstances[i], redeemShares);
        }
    }

    function _claimWithdrawForAccount(AccountInstance memory accInst, uint256 assets) internal {
        __claimWithdraw(accInst, assets);
    }

    function _claimWithdraw(uint256 assets) internal {
        __claimWithdraw(instanceOnEth, assets);
    }

    function _depositFreeAssetsFromSingleAmount(uint256 depositAmount, address vault1, address vault2) internal {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);

        // Split the deposit between two hooks
        uint256 halfAmount = depositAmount / 2;
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vault1, address(asset), halfAmount, false, address(0), 0
        );

        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault2,
            address(asset),
            depositAmount - halfAmount,
            false,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = IERC4626(address(vault1)).convertToShares(halfAmount);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vault2)).convertToShares(depositAmount - halfAmount);

        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(strategy.PRECISION(), pricePerShare);

        _trackDeposit(accountEth, shares, depositAmount);
    }

    // Local variables struct for _fulfillRedeem
    struct FulfillRedeemLocalVars {
        address[] requestingUsers;
        address withdrawHookAddress;
        address[] fulfillHooksAddresses;
        uint256 fluidSharesOut;
        uint256 aaveSharesOut;
        bytes[] fulfillHooksData;
        uint256 totalSvAssets;
        uint256 pricePerShare;
        uint256 amountForVault1;
        uint256 amountForVault2;
        uint256 underlyingSharesForVault1;
        uint256 underlyingSharesForVault2;
        uint256[] expectedAssetsOrSharesOut;
    }

    function _fulfillRedeem(uint256 redeemShares, address vault1, address vault2) internal {
        /// @dev with preserve percentages based on USD value allocation
        FulfillRedeemLocalVars memory vars;

        vars.requestingUsers = new address[](1);
        vars.requestingUsers[0] = accountEth;
        vars.withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);

        vars.fulfillHooksAddresses = new address[](2);
        vars.fulfillHooksAddresses[0] = vars.withdrawHookAddress;
        vars.fulfillHooksAddresses[1] = vars.withdrawHookAddress;

        (vars.fluidSharesOut, vars.aaveSharesOut) = _calculateVaultShares(redeemShares);

        vars.fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults based on USD value allocation
        vars.fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault1,
            vault1,
            address(strategy),
            vars.fluidSharesOut,
            false
        );

        vars.fulfillHooksData[1] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vault2, vault2, address(strategy), vars.aaveSharesOut, false
        );

        (vars.totalSvAssets,) = totalAssetHelper.totalAssets(address(strategy));
        vars.pricePerShare = vars.totalSvAssets.mulDiv(strategy.PRECISION(), vault.totalSupply(), Math.Rounding.Floor);

        vars.amountForVault1 = vars.fluidSharesOut * vault.PRECISION() / vars.pricePerShare;
        vars.amountForVault2 = vars.aaveSharesOut * vault.PRECISION() / vars.pricePerShare;

        vars.underlyingSharesForVault1 = IERC4626(address(vault1)).convertToShares(vars.amountForVault1);
        vars.underlyingSharesForVault2 = IERC4626(address(vault2)).convertToShares(vars.amountForVault2);

        vars.expectedAssetsOrSharesOut = new uint256[](2);
        vars.expectedAssetsOrSharesOut[0] = IERC4626(address(vault1)).convertToAssets(vars.underlyingSharesForVault1);
        vars.expectedAssetsOrSharesOut[1] = IERC4626(address(vault2)).convertToAssets(vars.underlyingSharesForVault2);

        vm.startPrank(STRATEGIST);
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(vars.fulfillHooksAddresses[0]).inspect(vars.fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(vars.fulfillHooksAddresses[1]).inspect(vars.fulfillHooksData[1]);

        strategy.fulfillRedeemRequests(
            ISuperVaultStrategy.FulfillArgs({
                controllers: vars.requestingUsers,
                hooks: vars.fulfillHooksAddresses,
                hookCalldata: vars.fulfillHooksData,
                expectedAssetsOrSharesOut: vars.expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(vars.fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();
    }

    function _depositFreeAssets(
        uint256 allocationAmountVault1,
        uint256 allocationAmountVault2,
        address vault1,
        address vault2
    )
        internal
    {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault1,
            address(asset),
            allocationAmountVault1,
            false,
            address(0),
            0
        );
        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault2,
            address(asset),
            allocationAmountVault2,
            false,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = IERC4626(address(vault1)).convertToShares(allocationAmountVault1);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vault2)).convertToShares(allocationAmountVault2);

        vm.startPrank(STRATEGIST);
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();
    }

    function _depositFreeAssets(
        uint256 allocationAmountVault1,
        uint256 allocationAmountVault2,
        address vault1,
        address vault2,
        bytes4 revertSelector
    )
        internal
    {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault1,
            address(asset),
            allocationAmountVault1,
            false,
            address(0),
            0
        );
        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault2,
            address(asset),
            allocationAmountVault2,
            false,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = IERC4626(address(vault1)).convertToShares(allocationAmountVault1);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vault2)).convertToShares(allocationAmountVault2);

        vm.startPrank(STRATEGIST);
        if (revertSelector != bytes4(0)) {
            vm.expectRevert(revertSelector);
        }
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();
    }

    function _depositFreeAssets(
        uint256 allocationAmountVault1,
        uint256 allocationAmountVault2,
        address vault1,
        address vault2,
        uint256[] memory expectedAssetsOrSharesOut,
        bytes4 revertSelector
    )
        internal
    {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault1,
            address(asset),
            allocationAmountVault1,
            false,
            address(0),
            0
        );
        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault2,
            address(asset),
            allocationAmountVault2,
            false,
            address(0),
            0
        );

        vm.startPrank(STRATEGIST);
        if (revertSelector != bytes4(0)) {
            vm.expectRevert(revertSelector);
        }
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();
    }

    function _depositFreeAssets(
        address vault1,
        address vault2,
        address vault3,
        uint256 allocationAmountVault1,
        uint256 allocationAmountVault2,
        uint256 allocationAmountVault3
    )
        internal
    {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](3);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;
        fulfillHooksAddresses[2] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](3);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault1,
            address(asset),
            allocationAmountVault1,
            false,
            address(0),
            0
        );
        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault2,
            address(asset),
            allocationAmountVault2,
            false,
            address(0),
            0
        );
        fulfillHooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            vault3,
            address(asset),
            allocationAmountVault3,
            false,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](3);
        expectedAssetsOrSharesOut[0] = IERC4626(address(vault1)).convertToShares(allocationAmountVault1);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vault2)).convertToShares(allocationAmountVault2);
        expectedAssetsOrSharesOut[2] = IERC4626(address(vault3)).convertToShares(allocationAmountVault3);
        vm.startPrank(STRATEGIST);
        bytes[] memory argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);
        argsForProofs[2] = ISuperHookInspector(fulfillHooksAddresses[2]).inspect(fulfillHooksData[2]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](3)
            })
        );
        vm.stopPrank();
    }

    function _fulfillRedeemForUsers(
        address[] memory requestingUsers,
        uint256 redeemSharesVault1,
        uint256 redeemSharesVault2,
        address vault1,
        address vault2
    )
        internal
    {
        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = withdrawHookAddress;
        fulfillHooksAddresses[1] = withdrawHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults
        fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vault1, vault1, address(strategy), redeemSharesVault1, false
        );
        fulfillHooksData[1] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vault2, vault2, address(strategy), redeemSharesVault2, false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        {
            (uint256 totalSvAssets,) = totalAssetHelper.totalAssets(address(strategy));
            uint256 pricePerShare = totalSvAssets.mulDiv(vault.PRECISION(), vault.totalSupply(), Math.Rounding.Floor);

            uint256 amountForVault1 = redeemSharesVault1 * vault.PRECISION() / pricePerShare;
            uint256 amountForVault2 = redeemSharesVault2 * vault.PRECISION() / pricePerShare;

            uint256 underlyingSharesForVault1 = IERC4626(address(vault1)).convertToShares(amountForVault1);
            uint256 underlyingSharesForVault2 = IERC4626(address(vault2)).convertToShares(amountForVault2);

            expectedAssetsOrSharesOut[0] = IERC4626(address(vault1)).convertToAssets(underlyingSharesForVault1);
            expectedAssetsOrSharesOut[1] = IERC4626(address(vault2)).convertToAssets(underlyingSharesForVault2);
        }

        console2.log("----requestingUsersLength", requestingUsers.length);
        vm.startPrank(STRATEGIST);
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);

        strategy.fulfillRedeemRequests(
            ISuperVaultStrategy.FulfillArgs({
                controllers: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();
    }

    function _fulfillRedeemForUsers(
        address[] memory requestingUsers,
        uint256 redeemSharesVault1,
        uint256 redeemSharesVault2,
        address vault1,
        address vault2,
        uint256[] memory expectedAssetsOrSharesOut,
        bytes4 revertSelector
    )
        internal
    {
        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = withdrawHookAddress;
        fulfillHooksAddresses[1] = withdrawHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults
        fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vault1, vault1, address(strategy), redeemSharesVault1, false
        );
        fulfillHooksData[1] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), vault2, vault2, address(strategy), redeemSharesVault2, false
        );

        vm.startPrank(STRATEGIST);
        if (revertSelector != bytes4(0)) {
            vm.expectRevert(revertSelector);
        }
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);

        strategy.fulfillRedeemRequests(
            ISuperVaultStrategy.FulfillArgs({
                controllers: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](2)
            })
        );
        vm.stopPrank();
    }

    function _completeDepositFlow(uint256 depositAmount) internal {
        // create deposit requests for all users
        _depositForAllUsers(depositAmount);

        // create fullfillment data
        uint256 totalAmount = depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        // fulfill deposits
        _depositFreeAssets(allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault));
    }

    function _completeDepositFlowWithVaryingAmounts(uint256[] memory depositAmounts) internal {
        require(depositAmounts.length == ACCOUNT_COUNT, "Invalid deposit amounts length");

        // Calculate total amount for allocation
        uint256 totalAmount;
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            _getTokens(address(asset), accInstances[i].account, depositAmounts[i]);
            _depositForAccount(accInstances[i], depositAmounts[i]);
            totalAmount += depositAmounts[i];
        }

        // create fullfillment data
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        // fulfill deposits
        _depositFreeAssets(allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault));
    }

    /**
     * @notice Struct to hold local variables for the _reallocate function
     */
    struct ReallocateLocalVars {
        // Current balances
        uint256 currentVault1Balance;
        uint256 currentVault2Balance;
        uint256 currentVault3Balance;
        uint256 totalBalance;
        // Target balances
        uint256 targetVault1Assets;
        uint256 targetVault2Assets;
        uint256 targetVault3Assets;
        // Differences
        int256 vault1Diff;
        int256 vault2Diff;
        int256 vault3Diff;
        // Sources and destinations
        address[] sources;
        uint256[] sourceAmounts;
        address[] destinations;
        uint256[] destinationAmounts;
        uint256 sourceCount;
        uint256 destCount;
        // For moving assets
        address source;
        address destination;
        uint256 amountToMove;
        uint256 sharesToRedeem;
        address[] hooksAddresses;
        bytes[] hooksData;
        // Final balances and ratios
        uint256 finalVault1Balance;
        uint256 finalVault2Balance;
        uint256 finalVault3Balance;
        uint256 totalFinalBalance;
        uint256 finalVault1Ratio;
        uint256 finalVault2Ratio;
        uint256 finalVault3Ratio;
    }

    /**
     * @notice Struct to hold arguments for the _reallocate function
     */
    struct ReallocateArgs {
        IERC4626 vault1;
        IERC4626 vault2;
        IERC4626 vault3;
        uint256 targetVault1Percentage;
        uint256 targetVault2Percentage;
        uint256 targetVault3Percentage;
        address withdrawHookAddress;
        address depositHookAddress;
    }

    function _reallocate(ReallocateArgs memory args)
        internal
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        ReallocateLocalVars memory vars;

        // Get current balances
        vars.currentVault1Balance = args.vault1.convertToAssets(args.vault1.balanceOf(address(strategy)));
        vars.currentVault2Balance = args.vault2.convertToAssets(args.vault2.balanceOf(address(strategy)));
        vars.currentVault3Balance = args.vault3.convertToAssets(args.vault3.balanceOf(address(strategy)));

        vars.totalBalance = vars.currentVault1Balance + vars.currentVault2Balance + vars.currentVault3Balance;

        // Calculate target balances based on percentages (in basis points)
        vars.targetVault1Assets = vars.totalBalance * args.targetVault1Percentage / 10_000;
        vars.targetVault2Assets = vars.totalBalance * args.targetVault2Percentage / 10_000;
        vars.targetVault3Assets = vars.totalBalance * args.targetVault3Percentage / 10_000;

        console2.log("Total balance:", vars.totalBalance);
        console2.log("Target Vault1 Assets:", vars.targetVault1Assets);
        console2.log("Target Vault2 Assets:", vars.targetVault2Assets);
        console2.log("Target Vault3 Assets:", vars.targetVault3Assets);

        // Calculate the differences between current and target allocations
        vars.vault1Diff = int256(vars.targetVault1Assets) - int256(vars.currentVault1Balance);
        vars.vault2Diff = int256(vars.targetVault2Assets) - int256(vars.currentVault2Balance);
        vars.vault3Diff = int256(vars.targetVault3Assets) - int256(vars.currentVault3Balance);

        console2.log("\n=== Allocation Differences ===");
        console2.log("Vault1 Diff:", vars.vault1Diff);
        console2.log("Vault2 Diff:", vars.vault2Diff);
        console2.log("Vault3 Diff:", vars.vault3Diff);

        // Identify sources (vaults with excess assets) and destinations (vaults needing assets)
        vars.sources = new address[](3);
        vars.sourceAmounts = new uint256[](3);
        vars.destinations = new address[](3);
        vars.destinationAmounts = new uint256[](3);
        vars.sourceCount = 0;
        vars.destCount = 0;

        if (vars.vault1Diff < 0) {
            vars.sources[vars.sourceCount] = address(args.vault1);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.vault1Diff);
            vars.sourceCount++;
        } else if (vars.vault1Diff > 0) {
            vars.destinations[vars.destCount] = address(args.vault1);
            vars.destinationAmounts[vars.destCount] = uint256(vars.vault1Diff);
            vars.destCount++;
        }

        if (vars.vault2Diff < 0) {
            vars.sources[vars.sourceCount] = address(args.vault2);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.vault2Diff);
            vars.sourceCount++;
        } else if (vars.vault2Diff > 0) {
            vars.destinations[vars.destCount] = address(args.vault2);
            vars.destinationAmounts[vars.destCount] = uint256(vars.vault2Diff);
            vars.destCount++;
        }

        if (vars.vault3Diff < 0) {
            vars.sources[vars.sourceCount] = address(args.vault3);
            vars.sourceAmounts[vars.sourceCount] = uint256(-vars.vault3Diff);
            vars.sourceCount++;
        } else if (vars.vault3Diff > 0) {
            vars.destinations[vars.destCount] = address(args.vault3);
            vars.destinationAmounts[vars.destCount] = uint256(vars.vault3Diff);
            vars.destCount++;
        }

        // Resize arrays to actual count
        vars.sources = _resizeAddressArray(vars.sources, vars.sourceCount);
        vars.sourceAmounts = _resizeUint256Array(vars.sourceAmounts, vars.sourceCount);
        vars.destinations = _resizeAddressArray(vars.destinations, vars.destCount);
        vars.destinationAmounts = _resizeUint256Array(vars.destinationAmounts, vars.destCount);

        console2.log("\n=== Sources and Destinations ===");
        for (uint256 i = 0; i < vars.sourceCount; i++) {
            console2.log("Source:", vars.sources[i]);
            console2.log("Amount:", vars.sourceAmounts[i]);
        }
        for (uint256 i = 0; i < vars.destCount; i++) {
            console2.log("Destination:", vars.destinations[i]);
            console2.log("Amount:", vars.destinationAmounts[i]);
        }

        // Create a single array of all transfers (source to destination)
        // Each transfer requires 2 hooks: withdraw and deposit
        uint256 maxTransfers = vars.sourceCount * vars.destCount;
        address[] memory allHooksAddresses = new address[](maxTransfers * 2);
        bytes[] memory allHooksData = new bytes[](maxTransfers * 2);
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](maxTransfers * 2);
        bytes[] memory argsForProofs = new bytes[](maxTransfers * 2);
        uint256 hookIndex = 0;

        // Create a matrix of transfers from sources to destinations
        for (uint256 i = 0; i < vars.sourceCount; i++) {
            for (uint256 j = 0; j < vars.destCount; j++) {
                if (vars.sourceAmounts[i] > 0 && vars.destinationAmounts[j] > 0) {
                    vars.amountToMove = vars.sourceAmounts[i] < vars.destinationAmounts[j]
                        ? vars.sourceAmounts[i]
                        : vars.destinationAmounts[j];

                    if (vars.amountToMove > 0) {
                        console2.log("\nMoving", vars.amountToMove);
                        console2.log("from", vars.sources[i], "to", vars.destinations[j]);

                        // Convert asset amount to shares for the source vault
                        if (vars.sources[i] == address(args.vault1)) {
                            vars.sharesToRedeem = args.vault1.convertToShares(vars.amountToMove);
                        } else if (vars.sources[i] == address(args.vault2)) {
                            vars.sharesToRedeem = args.vault2.convertToShares(vars.amountToMove);
                        } else if (vars.sources[i] == address(args.vault3)) {
                            vars.sharesToRedeem = args.vault3.convertToShares(vars.amountToMove);
                        }

                        console2.log("Shares to redeem:", vars.sharesToRedeem);

                        // Add withdraw hook
                        allHooksAddresses[hookIndex] = args.withdrawHookAddress;
                        allHooksData[hookIndex] = _createApproveAndRedeem4626HookData(
                            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                            vars.sources[i],
                            vars.sources[i],
                            address(strategy),
                            vars.sharesToRedeem,
                            false
                        );
                        argsForProofs[hookIndex] =
                            ISuperHookInspector(allHooksAddresses[hookIndex]).inspect(allHooksData[hookIndex]);
                        hookIndex++;

                        // Add deposit hook
                        allHooksAddresses[hookIndex] = args.depositHookAddress;
                        allHooksData[hookIndex] = _createApproveAndDeposit4626HookData(
                            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                            vars.destinations[j],
                            address(asset),
                            vars.amountToMove,
                            true,
                            address(0),
                            0
                        );
                        expectedAssetsOrSharesOut[hookIndex] =
                            IERC4626(vars.sources[i]).previewRedeem(vars.sharesToRedeem);
                        argsForProofs[hookIndex] =
                            ISuperHookInspector(allHooksAddresses[hookIndex]).inspect(allHooksData[hookIndex]);
                        hookIndex++;

                        // Update remaining amounts
                        vars.sourceAmounts[i] -= vars.amountToMove;
                        vars.destinationAmounts[j] -= vars.amountToMove;

                        // If source is depleted, break inner loop and move to next source
                        if (vars.sourceAmounts[i] == 0) {
                            break;
                        }
                    }
                }
            }
        }

        // Resize hook arrays to actual count
        if (hookIndex > 0) {
            address[] memory finalHooksAddresses = new address[](hookIndex);
            bytes[] memory finalHooksData = new bytes[](hookIndex);
            uint256[] memory finalExpectedAssetsOrSharesOut = new uint256[](hookIndex);
            bytes[] memory finalArgsForProofs = new bytes[](hookIndex);
            for (uint256 i = 0; i < hookIndex; i++) {
                finalHooksAddresses[i] = allHooksAddresses[i];
                finalHooksData[i] = allHooksData[i];
                finalExpectedAssetsOrSharesOut[i] = expectedAssetsOrSharesOut[i];
                finalArgsForProofs[i] = argsForProofs[i];
            }

            // Execute all hooks in a single transaction
            vm.startPrank(STRATEGIST);

            strategy.executeHooks(
                ISuperVaultStrategy.ExecuteArgs({
                    hooks: finalHooksAddresses,
                    hookCalldata: finalHooksData,
                    expectedAssetsOrSharesOut: finalExpectedAssetsOrSharesOut,
                    globalProofs: _getMerkleProofsForHooks(finalHooksAddresses, finalArgsForProofs),
                    strategyProofs: new bytes32[][](finalHooksAddresses.length)
                })
            );
            vm.stopPrank();
        }

        // Check new balances after reallocation
        vars.finalVault1Balance = args.vault1.convertToAssets(args.vault1.balanceOf(address(strategy)));
        vars.finalVault2Balance = args.vault2.convertToAssets(args.vault2.balanceOf(address(strategy)));
        vars.finalVault3Balance = args.vault3.convertToAssets(args.vault3.balanceOf(address(strategy)));

        console2.log("\n=== Final Balances After Reallocation ===");
        console2.log("Final Vault1 balance:", vars.finalVault1Balance);
        console2.log("Final Vault2 balance:", vars.finalVault2Balance);
        console2.log("Final Vault3 balance:", vars.finalVault3Balance);

        // Calculate final allocation percentages
        vars.totalFinalBalance = vars.finalVault1Balance + vars.finalVault2Balance + vars.finalVault3Balance;
        vars.finalVault1Ratio = (vars.finalVault1Balance * 10_000) / vars.totalFinalBalance;
        vars.finalVault2Ratio = (vars.finalVault2Balance * 10_000) / vars.totalFinalBalance;
        vars.finalVault3Ratio = (vars.finalVault3Balance * 10_000) / vars.totalFinalBalance;

        console2.log("\n=== Final Allocation Ratios ===");
        console2.log("Vault1:", vars.finalVault1Ratio / 100, "%");
        console2.log("Vault2:", vars.finalVault2Ratio / 100, "%");
        console2.log("Vault3:", vars.finalVault3Ratio / 100, "%");

        return (
            vars.finalVault1Balance,
            vars.finalVault2Balance,
            vars.finalVault3Balance,
            vars.finalVault1Ratio,
            vars.finalVault2Ratio,
            vars.finalVault3Ratio
        );
    }

    struct DepositVerificationVars {
        uint256 depositAmount;
        uint256 totalAmount;
        uint256 allocationAmountVault1;
        uint256 allocationAmountVault2;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialStrategyAssetBalance;
        uint256 fluidVaultSharesIncrease;
        uint256 aaveVaultSharesIncrease;
        uint256 strategyAssetBalanceDecrease;
        uint256 fluidVaultAssetsValue;
        uint256 aaveVaultAssetsValue;
        uint256 totalAssetsAllocated;
        uint256 totalSharesMinted;
        uint256 totalAssetsFromShares;
    }

    struct ChangingAllocationVars {
        uint256 firstDepositAmount;
        uint256 secondDepositAmount;
        uint256 firstAllocationVault1;
        uint256 firstAllocationVault2;
        uint256 secondAllocationVault1;
        uint256 secondAllocationVault2;
        uint256 initialShareBalance;
        uint256 firstDepositShares;
        uint256 firstDepositSharePrice;
        uint256 shareBalanceAfterFirstDeposit;
        uint256 secondDepositShares;
        uint256 secondDepositSharePrice;
        uint256 totalShares;
        uint256 totalShareValue;
    }

    function _verifyAndLogChangingAllocation(ChangingAllocationVars memory vars) internal view {
        vars.totalShares = vault.balanceOf(accInstances[0].account) - vars.initialShareBalance;
        assertEq(vars.totalShares, vars.firstDepositShares + vars.secondDepositShares);

        vars.totalShareValue = vault.convertToAssets(vars.totalShares);
        assertApproxEqRel(vars.totalShareValue, vars.firstDepositAmount + vars.secondDepositAmount, 0.01e18); // 1%
            // tolerance

        console2.log(
            "first deposit - vault1 allocation:", vars.firstAllocationVault1 * 100 / vars.firstDepositAmount, "%"
        );
        console2.log(
            "first deposit - vault2 allocation:", vars.firstAllocationVault2 * 100 / vars.firstDepositAmount, "%"
        );
        console2.log("first deposit share price:", vars.firstDepositSharePrice);

        console2.log(
            "second deposit - vault1 allocation:", vars.secondAllocationVault1 * 100 / vars.secondDepositAmount, "%"
        );
        console2.log(
            "second deposit - vault2 allocation:", vars.secondAllocationVault2 * 100 / vars.secondDepositAmount, "%"
        );
        console2.log("second deposit share price:", vars.secondDepositSharePrice);

        console2.log(
            "share price difference percentage:",
            (vars.firstDepositSharePrice > vars.secondDepositSharePrice)
                ? ((vars.firstDepositSharePrice - vars.secondDepositSharePrice) * 100 / vars.firstDepositSharePrice)
                : ((vars.secondDepositSharePrice - vars.firstDepositSharePrice) * 100 / vars.firstDepositSharePrice)
        );
    }

    struct RedeemVerificationVars {
        uint256 depositAmount;
        uint256 redeemAmount;
        uint256 totalDepositAmount;
        uint256 totalRedeemAmount;
        uint256 totalRedeemedAssets;
        uint256 allocationAmountVault1;
        uint256 allocationAmountVault2;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialStrategyAssetBalance;
        uint256 fluidVaultSharesDecrease;
        uint256 aaveVaultSharesDecrease;
        uint256 strategyAssetBalanceIncrease;
        uint256 fluidVaultAssetsValue;
        uint256 aaveVaultAssetsValue;
        uint256 totalAssetsRedeemed;
        uint256 totalSharesBurned;
        uint256[] userShareBalances;
    }

    function _verifyRedeemSharesAndAssets(RedeemVerificationVars memory vars) internal {
        uint256[] memory initialAssetBalances = new uint256[](ACCOUNT_COUNT);
        vars.totalSharesBurned = 0;

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialAssetBalances[i] = asset.balanceOf(accInstances[i].account);
        }
        uint256 totalAssetsReceived = 0;
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 claimableWithdraw = vault.maxWithdraw(accInstances[i].account);
            console2.log("claimable withdraw:", claimableWithdraw);
            _claimWithdrawForAccount(accInstances[i], claimableWithdraw);

            uint256 sharesBurned = vars.userShareBalances[i] - vault.balanceOf(accInstances[i].account);
            vars.totalSharesBurned += sharesBurned;

            uint256 assetsReceived = asset.balanceOf(accInstances[i].account) - initialAssetBalances[i];
            totalAssetsReceived += assetsReceived;
            console2.log("\n---");
            console2.log("assets received:", assetsReceived);
            /// @dev a deviation exists here because of the averageWithdrawPrice
            assertApproxEqRel(assetsReceived, claimableWithdraw, 0.001e18);

            uint256 remainingShares = vault.balanceOf(accInstances[i].account);
            uint256 remainingSharesValue = vault.convertToAssets(remainingShares);
            assertApproxEqRel(remainingSharesValue, vars.depositAmount - claimableWithdraw, 0.01e18);
        }

        uint256 assetsFromTotalSharesBurned = vault.convertToAssets(vars.totalSharesBurned);
        assertApproxEqRel(assetsFromTotalSharesBurned, totalAssetsReceived, 0.01e18);
    }

    function _setFeeConfig(uint256 feePercent, address feeRecipient) internal {
        vm.startPrank(STRATEGIST);
        strategy.proposeVaultFeeConfigUpdate(feePercent, feeRecipient);
        vm.warp(block.timestamp + 1 weeks);
        strategy.executeVaultFeeConfigUpdate();
        vm.stopPrank();
    }

    function _rebalanceFixedAmountFromVaultToVault(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        address sourceVault,
        address targetVault,
        uint256 assetsToMove
    )
        internal
    {
        uint256 sharesToRedeem = IERC4626(sourceVault).convertToShares(assetsToMove);

        vm.startPrank(STRATEGIST);
        hooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            sourceVault,
            sourceVault,
            address(strategy),
            sharesToRedeem,
            false
        );
        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            targetVault,
            address(asset),
            assetsToMove,
            true,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = 0;
        expectedAssetsOrSharesOut[1] = IERC4626(sourceVault).previewRedeem(sharesToRedeem);
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();
    }

    function _rebalanceFromVaultToVault(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        address sourceVault,
        address targetVault,
        uint256 targetAssets,
        uint256 currentAssets
    )
        internal
    {
        uint256 assetsToMove = targetAssets - currentAssets;
        uint256 sharesToRedeem = IERC4626(sourceVault).convertToShares(assetsToMove);

        vm.startPrank(STRATEGIST);
        hooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            sourceVault,
            sourceVault,
            address(strategy),
            sharesToRedeem,
            false
        );
        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY)),
            targetVault,
            address(asset),
            assetsToMove,
            true,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = 0;
        expectedAssetsOrSharesOut[1] = IERC4626(sourceVault).previewRedeem(sharesToRedeem);
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();
    }

    function _deriveSuperVaultFees(
        uint256 requestedShares,
        uint256 currentPricePerShare,
        uint256 precision
    )
        internal
        returns (uint256, uint256)
    {
        // Use the weighted average approach to calculate historical assets
        SuperVaultState storage state = superVaultStates[accountEth];

        // Check for insufficient shares
        if (requestedShares > state.accumulatorShares) {
            revert("INSUFFICIENT_SHARES");
        }

        // Calculate cost basis proportionally based on requested shares
        uint256 historicalAssets =
            requestedShares.mulDiv(state.accumulatorCostBasis, state.accumulatorShares, Math.Rounding.Floor);

        // Update user's accumulator state
        state.accumulatorShares -= requestedShares;
        state.accumulatorCostBasis -= historicalAssets;

        // Calculate current value and process fees
        uint256 currentAssets = requestedShares.mulDiv(currentPricePerShare, precision, Math.Rounding.Floor);

        (uint256 superformFee, uint256 recipientFee) = _deriveSuperVaultFeesFromAssets(currentAssets, historicalAssets);

        return (superformFee, recipientFee);
    }

    // Update function to track deposits
    function _trackDeposit(address user, uint256 shares, uint256 assets) internal {
        SuperVaultState storage state = superVaultStates[user];
        state.accumulatorShares += shares;
        state.accumulatorCostBasis += assets;
    }

    function _deriveSuperVaultFeesFromAssets(
        uint256 currentAssets,
        uint256 historicalAssets
    )
        internal
        view
        returns (uint256, uint256)
    {
        uint256 superformFee;
        uint256 recipientFee;

        SuperVaultStrategy.FeeConfig memory feeConfig = strategy.getConfigInfo();

        if (currentAssets > historicalAssets) {
            uint256 profit = currentAssets - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            uint256 totalFee = profit.mulDiv(performanceFeeBps, ONE_HUNDRED_PERCENT, Math.Rounding.Floor);

            if (totalFee > 0) {
                uint256 superVaultFeePercent = superGovernor.getFee(FeeType.SUPER_VAULT_PERFORMANCE_FEE);
                // Calculate Superform's portion of the fee
                superformFee = totalFee.mulDiv(superVaultFeePercent, ONE_HUNDRED_PERCENT, Math.Rounding.Floor);
                recipientFee = totalFee - superformFee;
            }
        }
        return (superformFee, recipientFee);
    }

    function _getSuperVaultPricePerShare() internal view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = vault.totalSupply();
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pricePerShare = vault.PRECISION();
        } else {
            // Calculate current PPS in price decimals
            (uint256 totalAssetsVault,) = totalAssetHelper.totalAssets(address(strategy));
            pricePerShare = totalAssetsVault.mulDiv(vault.PRECISION(), totalSupplyAmount, Math.Rounding.Floor);
        }
    }

    /**
     * @notice Updates the PPS (Price Per Share) using TotalAssetHelper
     * @return pps The calculated and updated price per share value
     * @dev This function uses TotalAssetHelper to get totalAssets, calculates PPS,
     *      creates a signature, and updates the PPS through the ECDSAPPSOracle contract
     */
    function _updateSuperVaultPPS(address strategyAddr, address vault_) internal returns (uint256 pps) {
        uint256 totalSupplyAmount = SuperVault(vault_).totalSupply();

        // Get current totalAssets from TotalAssetHelper
        (uint256 currentTotalAssets,) = totalAssetHelper.totalAssets(strategyAddr);
        uint256 precision = SuperVault(vault_).PRECISION();
        // Calculate price per share based on current totalAssets and totalSupply
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pps = precision;
        } else {
            // Calculate current PPS in price decimals using total assets from helper
            pps = currentTotalAssets.mulDiv(precision, totalSupplyAmount, Math.Rounding.Floor);
        }

        // Get the current timestamp for the signature
        uint256 timestamp = block.timestamp;

        // Create the message hash
        bytes32 messageHash = keccak256(abi.encodePacked(strategyAddr, pps, timestamp));

        // Create the Ethereum signed message hash
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Create signature (r, s, v) components using the constant KEEPER address
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VALIDATOR_KEY, ethSignedMessageHash);

        // Combine the signature components into a single bytes signature
        bytes memory signature = abi.encodePacked(r, s, v);

        // Create an array of proofs with the signature
        bytes[] memory proofs = new bytes[](1);
        proofs[0] = signature;

        // Call updatePPS on the ECDSAPPSOracle
        ecdsappsOracle.updatePPS(strategyAddr, proofs, pps, timestamp);

        // Log the updated PPS for debugging
        console2.log("Updated PPS:", pps);

        return pps;
    }

    function _calculateVaultShares(uint256 redeemShares)
        internal
        view
        returns (uint256 fluidSharesOut, uint256 aaveSharesOut)
    {
        // Get current shares in each vault
        uint256 fluidShares = fluidVault.balanceOf(address(strategy));
        uint256 aaveShares = aaveVault.balanceOf(address(strategy));

        // Convert shares to underlying asset values
        uint256 fluidUsdcValue = fluidVault.convertToAssets(fluidShares);
        uint256 aaveUsdcValue = aaveVault.convertToAssets(aaveShares);

        console2.log("fluidUsdcValue", fluidUsdcValue);
        console2.log("aaveUsdcValue", aaveUsdcValue);

        // Calculate proportional split based on USD values
        uint256 totalUsdValue = fluidUsdcValue + aaveUsdcValue;

        if (totalUsdValue > 0) {
            fluidSharesOut = (redeemShares * fluidUsdcValue) / totalUsdValue;
            aaveSharesOut = redeemShares - fluidSharesOut; // Use subtraction to avoid rounding errors

            console2.log("fluidSharesOut", fluidSharesOut);
            console2.log("aaveSharesOut", aaveSharesOut);
        }

        return (fluidSharesOut, aaveSharesOut);
    }

    /**
     * @notice Resizes an array of addresses to the specified length
     * @param array The original array to resize
     * @param newLength The new length for the array
     * @return A new array with the specified length containing elements from the original array
     */
    function _resizeAddressArray(address[] memory array, uint256 newLength) internal pure returns (address[] memory) {
        address[] memory newArray = new address[](newLength);
        for (uint256 i = 0; i < newLength; i++) {
            newArray[i] = array[i];
        }
        return newArray;
    }

    /**
     * @notice Resizes an array of uint256 to the specified length
     * @param array The original array to resize
     * @param newLength The new length for the array
     * @return A new array with the specified length containing elements from the original array
     */
    function _resizeUint256Array(uint256[] memory array, uint256 newLength) internal pure returns (uint256[] memory) {
        uint256[] memory newArray = new uint256[](newLength);
        for (uint256 i = 0; i < newLength; i++) {
            newArray[i] = array[i];
        }
        return newArray;
    }
}
