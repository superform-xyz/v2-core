// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";

contract BaseSuperVaultTest is BaseTest, MerkleReader {
    using ModuleKitHelpers for *;
    using Math for uint256;

    address public accountEth;
    AccountInstance public instanceOnEth;
    AccountInstance[] accInstances;

    ISuperExecutor public superExecutorOnEth;

    // Core contracts
    SuperVault public vault;
    SuperVaultEscrow public escrow;
    SuperVaultFactory public factory;
    SuperVaultStrategy public strategy;
    PeripheryRegistry public peripheryRegistry;

    // Roles
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;

    // Tokens and yield sources
    IERC20Metadata public asset;
    IERC4626 public fluidVault;
    IERC4626 public aaveVault;

    // Constants
    uint256 constant VAULT_CAP = 1_000_000e6; // 1M USDC
    uint256 private constant PRECISION = 1e18;
    uint256 constant SUPER_VAULT_CAP = 5_000_000e6; // 5M USDC
    uint256 constant MAX_ALLOCATION_RATE = 6000; // 50%
    uint256 constant VAULT_THRESHOLD = 100_000e6; // 100k USDC
    uint256 constant ONE_HUNDRED_PERCENT = 10_000;

    uint256 public constant REDEEM_THRESHOLD = 100;

    uint256 public constant BOOTSTRAP_AMOUNT = 1e6;

    struct SharePricePoint {
        /// @notice Number of shares at this price point
        uint256 shares;
        /// @notice Price per share in asset decimals when these shares were minted
        uint256 pricePerShare;
    }

    mapping(address user => uint256 sharePricePointCursor) public userSharePricePointCursors;

    mapping(address user => SharePricePoint[] sharePricePoints) public userSharePricePoints;

    function setUp() public virtual override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);
        accInstances = randomAccountInstances[ETH];
        assertEq(accInstances.length, RANDOM_ACCOUNT_COUNT);
        peripheryRegistry = PeripheryRegistry(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        // Deploy factory
        factory = new SuperVaultFactory(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up roles
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);

        address fluidVaultAddr = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
        address aaveVaultAddr = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
        vm.label(fluidVaultAddr, "FluidVault");
        vm.label(aaveVaultAddr, "AaveVault");

        // Get real yield sources from fork
        fluidVault = IERC4626(fluidVaultAddr);
        aaveVault = IERC4626(aaveVaultAddr);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: ONE_HUNDRED_PERCENT,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = depositHookAddress;

        bytes32[][] memory bootstrapHookProofs = new bytes32[][](1);
        bootstrapHookProofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), BOOTSTRAP_AMOUNT, false, false
        );
        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT * 2);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT * 2);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault USDC",
                symbol: "svUSDC",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                config: config,
                finalMaxAllocationRate: MAX_ALLOCATION_RATE,
                initYieldSource: address(fluidVault),
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookProofs: bootstrapHookProofs,
                bootstrappingHookCalldata: bootstrapHooksData
            })
        );
        vm.label(vaultAddr, "SuperVault");
        vm.label(strategyAddr, "SuperVaultStrategy");
        vm.label(escrowAddr, "SuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Add a new yield source as manager

        strategy.manageYieldSource(
            address(aaveVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();

        /*
        // supply initial tokens to SuperVaultStrategy
        /// @dev this is to avoid rounding errors when redeeming
        uint256 initialDepositAmount = 1e6; // 1 USDC
        _getTokens(address(asset), address(this), initialDepositAmount);
        vm.startPrank(address(this));
        asset.approve(address(vault), initialDepositAmount);
        vault.requestDeposit(initialDepositAmount, address(this), address(this));
        vm.stopPrank();
        _fulfillDepositForInitialDeposit(initialDepositAmount);

        vm.startPrank(address(this));
        vault.deposit(initialDepositAmount, address(this), address(this));
        vm.stopPrank();

        uint256 initialBootstrapperShares = vault.balanceOf(address(this));
        console2.log("boostrapper shares          ", initialBootstrapperShares);
        */
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function __requestDeposit(AccountInstance memory accInst, uint256 depositAmount) private {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(asset), address(vault), depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function __claimDeposit(AccountInstance memory accInst, uint256 depositAmount) private {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function __requestRedeem(AccountInstance memory accInst, uint256 redeemShares, bool shouldRevert) private {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(ETH, REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRequestWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, redeemShares, false
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
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(vault), accInst.account, assets, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _requestDeposit(uint256 depositAmount) internal {
        __requestDeposit(instanceOnEth, depositAmount);
    }

    function _requestDepositForAccount(AccountInstance memory accInst, uint256 depositAmount) internal {
        __requestDeposit(accInst, depositAmount);
    }

    function _fulfillDeposit(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(depositHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), depositAmount / 2, false, false
        );

        fulfillHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), depositAmount / 2, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, true);
        vm.stopPrank();

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(PRECISION, pricePerShare);
        userSharePricePoints[accountEth].push(SharePricePoint({ shares: shares, pricePerShare: pricePerShare }));
    }

    function _fulfillDepositForInitialDeposit(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = address(this);
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(depositHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), depositAmount / 2, false, false
        );
        fulfillHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), depositAmount / 2, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, true);
        vm.stopPrank();

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(PRECISION, pricePerShare);
        userSharePricePoints[address(this)].push(SharePricePoint({ shares: shares, pricePerShare: pricePerShare }));
    }

    function _claimDeposit(uint256 depositAmount) internal {
        __claimDeposit(instanceOnEth, depositAmount);
    }

    function _claimDepositForAccount(AccountInstance memory accInst, uint256 depositAmount) internal {
        __claimDeposit(accInst, depositAmount);
    }

    function _requestRedeem(uint256 redeemShares) internal {
        __requestRedeem(instanceOnEth, redeemShares, false);
    }

    function _requestRedeemForAccount(AccountInstance memory accInst, uint256 redeemShares) internal {
        __requestRedeem(accInst, redeemShares, false);
    }

    function _requestRedeemForAccount_Revert(AccountInstance memory accInst, uint256 redeemShares) internal {
        __requestRedeem(accInst, redeemShares, true);
    }

    function _fulfillRedeem(uint256 redeemShares) internal {
        /// @dev with preserve percentages based on USD value allocation
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = withdrawHookAddress;
        fulfillHooksAddresses[1] = withdrawHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = proofs[0];

        (uint256 fluidSharesOut, uint256 aaveSharesOut) = _calculateVaultShares(redeemShares);

        bytes[] memory fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults based on USD value allocation
        fulfillHooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            fluidSharesOut,
            false,
            false
        );

        fulfillHooksData[1] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            aaveSharesOut,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, false);
        vm.stopPrank();
    }

    function _claimWithdrawForAccount(AccountInstance memory accInst, uint256 assets) internal {
        __claimWithdraw(accInst, assets);
    }

    function _claimWithdraw(uint256 assets) internal {
        __claimWithdraw(instanceOnEth, assets);
    }
    // Define a struct to hold test variables to avoid stack too deep errors

    function _requestDepositForAllUsers(uint256 depositAmount) internal {
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            _getTokens(address(asset), accInstances[i].account, depositAmount);
            _requestDepositForAccount(accInstances[i], depositAmount);
            assertEq(strategy.pendingDepositRequest(accInstances[i].account), depositAmount);
            unchecked {
                ++i;
            }
        }
    }

    function _fulfillDepositForUsers(
        address[] memory requestingUsers,
        uint256 allocationAmountVault1,
        uint256 allocationAmountVault2
    )
        internal
    {
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(depositHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(fluidVault), allocationAmountVault1, false, false
        );
        fulfillHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(aaveVault), allocationAmountVault2, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, true);
        vm.stopPrank();
    }

    function _fulfillRedeemForUsers(
        address[] memory requestingUsers,
        uint256 redeemSharesVault1,
        uint256 redeemSharesVault2
    )
        internal
    {
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = withdrawHookAddress;
        fulfillHooksAddresses[1] = withdrawHookAddress;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = _getMerkleProof(withdrawHookAddress);
        proofs[1] = proofs[0];

        bytes[] memory fulfillHooksData = new bytes[](2);
        // Withdraw proportionally from both vaults
        fulfillHooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            redeemSharesVault1,
            false,
            false
        );
        fulfillHooksData[1] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            redeemSharesVault2,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, false);
        vm.stopPrank();
    }

    function _completeDepositFlow(uint256 depositAmount) internal {
        // create deposit requests for all users
        _requestDepositForAllUsers(depositAmount);

        // create fullfillment data
        uint256 totalAmount = depositAmount * RANDOM_ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;
        address[] memory requestingUsers = new address[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            requestingUsers[i] = accInstances[i].account;
            unchecked {
                ++i;
            }
        }
        // fulfill deposits
        _fulfillDepositForUsers(requestingUsers, allocationAmountVault1, allocationAmountVault2);

        // claim deposits
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            _claimDepositForAccount(accInstances[i], depositAmount);
            unchecked {
                ++i;
            }
        }
    }

    function _requestRedeemForAllUsers(uint256 redeemAmount) internal {
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            uint256 redeemShares = redeemAmount > 0 ? redeemAmount : vault.balanceOf(accInstances[i].account);
            _requestRedeemForAccount(accInstances[i], redeemShares);
            unchecked {
                ++i;
            }
        }
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

    function _verifySharesAndAssets(DepositVerificationVars memory vars) internal {
        uint256[] memory initialUserShareBalances = new uint256[](RANDOM_ACCOUNT_COUNT);
        uint256[] memory maxDepositAmounts = new uint256[](RANDOM_ACCOUNT_COUNT);
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            initialUserShareBalances[i] = vault.balanceOf(accInstances[i].account);
            maxDepositAmounts[i] = vault.maxDeposit(accInstances[i].account);
            _claimDepositForAccount(accInstances[i], maxDepositAmounts[i]);
            unchecked {
                ++i;
            }
        }

        vars.totalSharesMinted = 0;
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT;) {
            console2.log("initialUserShareBalances", initialUserShareBalances[i]);
            console2.log("i", i);
            uint256 userSharesReceived = vault.balanceOf(accInstances[i].account) - initialUserShareBalances[i];
            vars.totalSharesMinted += userSharesReceived;

            // Verify user can convert shares back to approximately the original deposit amount
            uint256 assetsFromShares = vault.convertToAssets(userSharesReceived);
            console2.log("totalSupply test", vault.totalSupply());
            console2.log("totalAssets test", vault.totalAssets());
            console2.log("pps", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));
            console2.log("userSharesReceived", userSharesReceived);
            console2.log("assetsFromShares", assetsFromShares);
            console2.log("maxDepositAmounts", maxDepositAmounts[i]);
            assertApproxEqRel(assetsFromShares, maxDepositAmounts[i], 0.01e18); // Allow 1% deviation
            console2.log("--------------------------------");
            unchecked {
                ++i;
            }
        }

        vars.totalAssetsFromShares = vault.convertToAssets(vars.totalSharesMinted);
        assertApproxEqRel(vars.totalAssetsFromShares, vars.totalAmount, 0.01e18); // Allow 1% deviation
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
        uint256[] memory initialAssetBalances = new uint256[](RANDOM_ACCOUNT_COUNT);
        vars.totalSharesBurned = 0;

        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
            initialAssetBalances[i] = asset.balanceOf(accInstances[i].account);
        }
        uint256 totalAssetsReceived = 0;
        for (uint256 i; i < RANDOM_ACCOUNT_COUNT; i++) {
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

    /*//////////////////////////////////////////////////////////////
                      INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setFeeConfig(uint256 performanceFeeBps, address recipient) internal {
        vm.startPrank(SV_MANAGER);
        strategy.proposeVaultFeeConfigUpdate(performanceFeeBps, recipient);
        vm.warp(block.timestamp + 7 days);
        strategy.executeVaultFeeConfigUpdate();
        vm.stopPrank();
    }

    // 0% fee is required for Ledger entries where the SuperVault is the target so that we don't double charge fees
    function _setUpSuperLedgerForVault() internal {
        vm.selectFork(FORKS[ETH]);
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
    }

    /*//////////////////////////////////////////////////////////////
                        FEE DERIVATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deriveSuperVaultFees(
        uint256 requestedShares,
        uint256 currentPricePerShare
    )
        internal
        returns (uint256, uint256)
    {
        uint256 historicalAssets = 0;
        SharePricePoint[] memory sharePricePoints = userSharePricePoints[accountEth];
        uint256 sharePricePointsLength = sharePricePoints.length;
        uint256 remainingShares = requestedShares;
        uint256 currentIndex = userSharePricePointCursors[accountEth];
        uint256 lastConsumedIndex = currentIndex;

        // Calculate historicalAssets for each share price point
        for (uint256 j = currentIndex; j < sharePricePointsLength && remainingShares > 0;) {
            SharePricePoint memory point = sharePricePoints[j];
            uint256 sharesFromPoint = point.shares > remainingShares ? remainingShares : point.shares;
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, PRECISION);

            // Update point's remaining shares or mark for deletion
            if (sharesFromPoint == point.shares) {
                // Point fully consumed, move cursor
                lastConsumedIndex = j + 1;
                userSharePricePointCursors[accountEth]++;
            } else if (sharesFromPoint < point.shares) {
                // Point partially consumed, update shares
                sharePricePoints[j].shares -= sharesFromPoint;
            }

            remainingShares -= sharesFromPoint;
            unchecked {
                ++j;
            }
        }

        // Calculate current value and process fees
        uint256 currentAssets = requestedShares.mulDiv(currentPricePerShare, PRECISION, Math.Rounding.Floor);

        (uint256 superformFee, uint256 recipientFee) = _deriveSuperVaultFeesFromAssets(currentAssets, historicalAssets);

        return (superformFee, recipientFee);
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

        (, SuperVaultStrategy.FeeConfig memory feeConfig) = strategy.getConfigInfo();

        if (currentAssets > historicalAssets) {
            uint256 profit = currentAssets - historicalAssets;
            uint256 performanceFeeBps = feeConfig.performanceFeeBps;
            uint256 totalFee = profit.mulDiv(performanceFeeBps, ONE_HUNDRED_PERCENT);

            if (totalFee > 0) {
                // Calculate Superform's portion of the fee
                superformFee = totalFee.mulDiv(peripheryRegistry.getSuperformFeeSplit(), ONE_HUNDRED_PERCENT);
                recipientFee = totalFee - superformFee;
            }
        }
        return (superformFee, recipientFee);
    }

    function _getSuperVaultPricePerShare() internal view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = vault.totalSupply();
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pricePerShare = PRECISION;
        } else {
            // Calculate current PPS in price decimals
            (uint256 totalAssetsVault,) = strategy.totalAssets();
            // We should use Ceil to make PPS as close to 1 as possible (in case it's < 1).
            // Otherwise rounding issues in other places becomes bigger
            pricePerShare = totalAssetsVault.mulDiv(PRECISION, totalSupplyAmount, Math.Rounding.Ceil);
        }
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
}
