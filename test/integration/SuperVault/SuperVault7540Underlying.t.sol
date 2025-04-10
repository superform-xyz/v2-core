// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// vault interfaces
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { RestrictionManagerLike } from "../../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IInvestmentManager } from "../../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../../mocks/centrifuge/ITranch.sol";
import { IRoot } from "../../mocks/centrifuge/IRoot.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// superform
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { IYieldSourceOracle } from "../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";

contract SuperVault7540UnderlyingTest is BaseSuperVaultTest {
    using Math for uint256;

    ISuperLedger public superLedgerETH;

    address public centrifugeAddress;
    IERC7540 public centrifugeVault;

    address public underlyingETH_USDC;

    uint256 amount;
    uint64 public poolId;
    uint128 public assetId;
    bytes16 public trancheId;

    address public rootManager;

    IRoot public root;
    IPoolManager public poolManager;
    IInvestmentManager public investmentManager;
    RestrictionManagerLike public restrictionManager;

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "Centrifuge_7540_ETH_USDC";
    string public constant YIELD_SOURCE_ORACLE_7540_KEY = "YieldSourceOracle_7540";

    struct FulfillRedemptionsLocalVars {
        uint256 shares1;
        uint256 shares2;
        uint256 totalShares;
        uint256 sharesFluid;
        uint256 assetsFluid;
        uint256 assetsCentrifuge;
        uint256 totalAssets;
        uint256 vault1Proportion;
        uint256 vault2Proportion;
        uint256 vault1Shares;
        uint256 vault2Shares;
        uint256 fluidRedeemShares;
        uint256 fluidRedeemAmount;
        address[] requestingUsers;
        address redeemHookAddress;
        address redeem7540HookAddress;
        address[] fulfillHooksAddresses;
        bytes[] fulfillHooksData;
        uint256[] expectedAssetsOrSharesOut;
    }

    function setUp() public override {
        super.setUp();

        console2.log("--- SET UP 7540 UNDERLYING SV ---");

        vm.selectFork(FORKS[ETH]);

        // Deploy factory
        factory = new SuperVaultFactory(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        asset = IERC20Metadata(underlyingETH_USDC);

        // Set up the 7540 yield source
        centrifugeAddress = realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(centrifugeAddress, YIELD_SOURCE_7540_ETH_USDC_KEY);

        centrifugeVault = IERC7540(centrifugeAddress);
        // Fluid 4626 vault was set up in BaseTest

        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));

        // Deploy the vault trio
        (address superVaultAddress, address superVaultStrategyAddress, address superVaultEscrowAddress) =
            _deployVault(address(asset), SUPER_VAULT_CAP, "SV7540U");

        vault = SuperVault(superVaultAddress);
        escrow = SuperVaultEscrow(superVaultEscrowAddress);
        strategy = SuperVaultStrategy(superVaultStrategyAddress);

        amount = 1000e6; // 1000 USDC

        vm.startPrank(SV_MANAGER);
        strategy.manageYieldSource(
            address(fluidVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        strategy.manageYieldSource(
            address(centrifugeVault),
            _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            true
        );
        strategy.proposeOrExecuteHookRoot(hookRootPerChain[ETH]);
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();

        address share = centrifugeVault.share();

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        ITranche(share).hook();

        address mngr = ITranche(share).hook();

        restrictionManager = RestrictionManagerLike(mngr);

        vm.prank(RestrictionManagerLike(mngr).root());
        restrictionManager.updateMember(share, address(strategy), type(uint64).max);

        poolId = centrifugeVault.poolId();
        assertEq(poolId, 4_139_607_887);
        trancheId = centrifugeVault.trancheId();
        assertEq(trancheId, bytes16(0x97aa65f23e7be09fcd62d0554d2e9273));

        poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);

        rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        assetId = poolManager.assetToId(underlyingETH_USDC);
        assertEq(assetId, uint128(242_333_941_209_166_991_950_178_742_833_476_896_417));
    }

    function test_SuperVault_7540_Underlying_E2E_Flow() public executeWithoutHookRestrictions {
        // Request deposit into superVault as user1
        _requestDeposit(amount);

        // Request deposit into superVault as user2
        deal(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);
        // Request deposit into 7540 vault using split functions
        _requestCentrifugeDepositStep1(amount);
        _requestCentrifugeDepositStep2(amount);

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequests(amount * 2);
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (uint256 totalAssets_,) = strategy.totalAssets();
        console2.log("\n Total Assets", totalAssets_);

        assertEq(strategy.pendingDepositRequest(accountEth), 0);
        assertEq(strategy.pendingDepositRequest(accInstances[2].account), 0);

        // Claim deposit into superVault as user1
        _claimDeposit(amount);
        // Claim deposit into superVault as user2
        _claimDepositForAccount(accInstances[2], amount);

        assertEq(vault.maxDeposit(accountEth), 0);
        assertEq(vault.maxDeposit(accInstances[2].account), 0);

        // --- REDEMPTIONS ---
        vm.warp(block.timestamp + 10 weeks);
        console2.log("\n --- 10 WEEKS HAVE PASSED ---");
        console2.log("pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (totalAssets_,) = strategy.totalAssets();
        console2.log("Total Assets", totalAssets_);
        //   totalAssets_ 1054109825
        //   totalAssets_ 999999998 (centrifuge())
        uint256 amountToRedeemAccEth = IERC20(vault.share()).balanceOf(accountEth);
        __requestRedeem(instanceOnEth, amountToRedeemAccEth, false);
        uint256 amountToRedeemAcc2 = IERC20(vault.share()).balanceOf(accInstances[2].account);
        __requestRedeem(accInstances[2], amountToRedeemAcc2, false);

        console2.log("user1 pending redeem", strategy.pendingRedeemRequest(accountEth));
        console2.log("user2 pending redeem", strategy.pendingRedeemRequest(accInstances[2].account));

        console2.log("\n REQUEST CENTRIFUGE REDEEM");

        // Request redeem using split functions
        uint256 centrifugeRedeem = _requestCentrifugeRedeemStep1();

        uint256 centrifugeExpectedAssets = _requestCentrifugeRedeemStep2(centrifugeRedeem, false);

        console2.log("---- PPS AFTER REDEEM REQUEST CENTRIFUGE SIDE", _getSuperVaultPricePerShare());

        _fulfillRedemptions(centrifugeExpectedAssets);

        console2.log("---- PPS After Fulfill Redemptions SUPER VAULT SIDE", _getSuperVaultPricePerShare());
    }

    function test_SuperVault_7540_Underlying_E2E_Flow_Warping() public executeWithoutHookRestrictions {
        // Request deposit into superVault as user1
        _requestDeposit(amount);

        // Request deposit into superVault as user2
        deal(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);

        // Request deposit into 7540 vault using split functions
        _requestCentrifugeDepositStep1(amount);
        _requestCentrifugeDepositStep2(amount);

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequests(amount * 2);
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (uint256 totalAssets_,) = strategy.totalAssets();
        console2.log("\n Total Assets", totalAssets_);

        assertEq(strategy.pendingDepositRequest(accountEth), 0);
        assertEq(strategy.pendingDepositRequest(accInstances[2].account), 0);

        // Claim deposit into superVault as user1
        _claimDeposit(amount);
        // Claim deposit into superVault as user2
        _claimDepositForAccount(accInstances[2], amount);

        assertEq(vault.maxDeposit(accountEth), 0);
        assertEq(vault.maxDeposit(accInstances[2].account), 0);

        // --- REDEMPTIONS ---
        vm.warp(block.timestamp + 10 weeks);
        console2.log("\n --- 10 WEEKS HAVE PASSED ---");
        console2.log("pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (totalAssets_,) = strategy.totalAssets();
        console2.log("Total Assets", totalAssets_);
        //   totalAssets_ 1054109825
        //   totalAssets_ 999999998 (centrifuge())
        uint256 amountToRedeemAccEth = IERC20(vault.share()).balanceOf(accountEth);
        __requestRedeem(instanceOnEth, amountToRedeemAccEth, false);
        uint256 amountToRedeemAcc2 = IERC20(vault.share()).balanceOf(accInstances[2].account);
        __requestRedeem(accInstances[2], amountToRedeemAcc2, false);

        console2.log("user1 pending redeem", strategy.pendingRedeemRequest(accountEth));
        console2.log("user2 pending redeem", strategy.pendingRedeemRequest(accInstances[2].account));

        console2.log("\n REQUEST CENTRIFUGE REDEEM");

        // Request redeem using split functions with warping
        uint256 centrifugeRedeem = _requestCentrifugeRedeemStep1();
        uint256 centrifugeExpectedAssets = _requestCentrifugeRedeemStep2(centrifugeRedeem, true);

        console2.log("---- PPS AFTER REDEEM REQUEST CENTRIFUGE SIDE", _getSuperVaultPricePerShare());

        _fulfillRedemptions(centrifugeExpectedAssets);

        console2.log("---- PPS After Fulfill Redemptions SUPER VAULT SIDE", _getSuperVaultPricePerShare());
    }

    function test_SuperVault_7540_Underlying_Cancel_Deposit_Flow() public executeWithoutHookRestrictions {
        // Request deposit into superVault as user1
        _requestDeposit(amount);

        // Request deposit into superVault as user2
        deal(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);

        // Request deposit into 7540 vault - only submit request but don't fulfill
        console2.log("\n --- REQUESTING CENTRIFUGE DEPOSIT ---");
        _requestCentrifugeDepositStep1(amount);

        // Instead of fulfilling the deposit, cancel it
        console2.log("\n --- CANCELLING CENTRIFUGE DEPOSIT REQUEST ---");
        _cancelCentrifugeDepositRequest();

        // Fulfill the cancellation
        _fulfillCancelDepositRequest(amount);

        // Claim the cancelled deposit
        _claimCancelDepositRequest();

        console2.log("Asset balance of strategy", IERC20(vault.asset()).balanceOf(address(strategy)));

        // Request a new deposit with the claimed assets and fulfill it
        console2.log("\n --- REQUESTING NEW CENTRIFUGE DEPOSIT ---");
        _requestCentrifugeDepositStep1(amount);
        _requestCentrifugeDepositStep2(amount);

        // Now fulfill the deposit requests as normally would
        _fulfillDepositRequests(amount * 2);
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (uint256 totalAssets_,) = strategy.totalAssets();
        console2.log("\n Total Assets", totalAssets_);

        assertEq(strategy.pendingDepositRequest(accountEth), 0);
        assertEq(strategy.pendingDepositRequest(accInstances[2].account), 0);

        // Claim deposit into superVault as user1
        _claimDeposit(amount);
        // Claim deposit into superVault as user2
        _claimDepositForAccount(accInstances[2], amount);

        assertEq(vault.maxDeposit(accountEth), 0);
        assertEq(vault.maxDeposit(accInstances[2].account), 0);

        // --- REDEMPTIONS ---
        vm.warp(block.timestamp + 10 weeks);
        console2.log("\n --- 10 WEEKS HAVE PASSED ---");
        console2.log("pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (totalAssets_,) = strategy.totalAssets();
        console2.log("Total Assets", totalAssets_);

        uint256 amountToRedeemAccEth = IERC20(vault.share()).balanceOf(accountEth);
        __requestRedeem(instanceOnEth, amountToRedeemAccEth, false);
        uint256 amountToRedeemAcc2 = IERC20(vault.share()).balanceOf(accInstances[2].account);
        __requestRedeem(accInstances[2], amountToRedeemAcc2, false);

        console2.log("user1 pending redeem", strategy.pendingRedeemRequest(accountEth));
        console2.log("user2 pending redeem", strategy.pendingRedeemRequest(accInstances[2].account));

        console2.log("\n REQUEST CENTRIFUGE REDEEM");

        // Split redeem request into two steps
        uint256 centrifugeRedeem = _requestCentrifugeRedeemStep1();
        uint256 centrifugeExpectedAssets = _requestCentrifugeRedeemStep2(centrifugeRedeem, true);

        console2.log("---- PPS AFTER REDEEM REQUEST CENTRIFUGE SIDE", _getSuperVaultPricePerShare());

        _fulfillRedemptions(centrifugeExpectedAssets);

        console2.log("---- PPS After Fulfill Redemptions SUPER VAULT SIDE", _getSuperVaultPricePerShare());
    }

    function test_SuperVault_7540_Underlying_Cancel_Redeem_Flow() public executeWithoutHookRestrictions {
        // Request deposit into superVault as user1
        _requestDeposit(amount);

        // Request deposit into superVault as user2
        deal(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);

        // Request deposit into 7540 vault
        _requestCentrifugeDepositStep1(amount);
        _requestCentrifugeDepositStep2(amount);

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequests(amount * 2);
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (uint256 totalAssets_,) = strategy.totalAssets();
        console2.log("\n Total Assets", totalAssets_);

        assertEq(strategy.pendingDepositRequest(accountEth), 0);
        assertEq(strategy.pendingDepositRequest(accInstances[2].account), 0);

        // Claim deposit into superVault as user1
        _claimDeposit(amount);
        // Claim deposit into superVault as user2
        _claimDepositForAccount(accInstances[2], amount);

        assertEq(vault.maxDeposit(accountEth), 0);
        assertEq(vault.maxDeposit(accInstances[2].account), 0);

        // --- REDEMPTIONS ---
        vm.warp(block.timestamp + 10 weeks);
        console2.log("\n --- 10 WEEKS HAVE PASSED ---");
        console2.log("pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());
        (totalAssets_,) = strategy.totalAssets();
        console2.log("Total Assets", totalAssets_);

        uint256 amountToRedeemAccEth = IERC20(vault.share()).balanceOf(accountEth);
        __requestRedeem(instanceOnEth, amountToRedeemAccEth, false);
        uint256 amountToRedeemAcc2 = IERC20(vault.share()).balanceOf(accInstances[2].account);
        __requestRedeem(accInstances[2], amountToRedeemAcc2, false);

        console2.log("user1 pending redeem", strategy.pendingRedeemRequest(accountEth));
        console2.log("user2 pending redeem", strategy.pendingRedeemRequest(accInstances[2].account));

        console2.log("\n --- REQUESTING FIRST CENTRIFUGE REDEEM (TO BE CANCELLED) ---");
        // First request the redeem normally
        uint256 initialCentrifugeRedeem = _requestCentrifugeRedeemStep1();
        console2.log("Initial Centrifuge Redeem amount:", initialCentrifugeRedeem);

        // Instead of fulfilling the redemption, cancel it
        console2.log("\n --- CANCELLING CENTRIFUGE REDEEM REQUEST ---");
        _cancelCentrifugeRedeemRequest();

        // Get share balance before cancel
        uint256 sharesBefore = IERC20(centrifugeVault.share()).balanceOf(address(strategy));
        console2.log("Shares before cancel fulfillment:", sharesBefore);

        // Fulfill the cancellation
        _fulfillCancelRedeemRequest(initialCentrifugeRedeem);

        // Claim the cancelled redeem
        _claimCancelRedeemRequest();

        // Request a new redeem with the claimed shares
        console2.log("\n --- REQUESTING NEW CENTRIFUGE REDEEM ---");

        // Request a new redeem with warping to simulate yield
        uint256 finalCentrifugeRedeem = _requestCentrifugeRedeemStep1();
        console2.log("Final Centrifuge Redeem amount:", finalCentrifugeRedeem);

        // Should be the same as claimed shares
        assertEq(
            finalCentrifugeRedeem, initialCentrifugeRedeem, "Final redeem amount should match initialCentrifugeRedeem"
        );

        // Add yield by warping before fulfill
        uint256 centrifugeExpectedAssets = _requestCentrifugeRedeemStep2(finalCentrifugeRedeem, true);
        console2.log("Centrifuge expected assets after fulfillment:", centrifugeExpectedAssets);

        console2.log("---- PPS AFTER REDEEM REQUEST CENTRIFUGE SIDE", _getSuperVaultPricePerShare());

        _fulfillRedemptions(centrifugeExpectedAssets);

        console2.log("---- PPS After Fulfill Redemptions SUPER VAULT SIDE", _getSuperVaultPricePerShare());
    }

    function _fulfillDepositRequests(uint256 amountToDeposit) internal {
        uint256 amountPerVault = amountToDeposit / 2;

        address[] memory requestingUsers = new address[](2);
        requestingUsers[0] = accountEth;
        requestingUsers[1] = accInstances[2].account;

        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);
        address deposit7540HookAddress = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = deposit7540HookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);

        // 7540 claim deposit
        uint256 maxDeposit = centrifugeVault.maxDeposit(address(strategy));
        console2.log("----maxDeposit", maxDeposit);
        expectedAssetsOrSharesOut[0] = centrifugeVault.maxMint(address(strategy));
        expectedAssetsOrSharesOut[1] = fluidVault.convertToShares(amountPerVault);

        bytes[] memory fulfillHooksData = new bytes[](2);
        fulfillHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(centrifugeVault), maxDeposit, false, false
        );
        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(asset),
            amountPerVault,
            false,
            false
        );

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, fulfillHooksAddresses),
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );

        // Track deposits for each user
        uint256 pps = _getSuperVaultPricePerShare();
        uint256 shares = amount.mulDiv(1e18, pps);
        _trackDeposit(accountEth, shares, amount);
        _trackDeposit(accInstances[2].account, shares, amount);

        uint256 centrifugeShares = IERC20(centrifugeVault.share()).balanceOf(address(strategy));

        console2.log(" BALANCE OF CENTRIFUGE SHARES IN SUPER VAULT", centrifugeShares);
    }

    function _fulfillRedemptions(uint256 centrifugeExpectedAssets) internal {
        FulfillRedemptionsLocalVars memory vars;

        vars.shares1 = strategy.pendingRedeemRequest(accountEth);
        vars.shares2 = strategy.pendingRedeemRequest(accInstances[2].account);
        vars.totalShares = vars.shares1 + vars.shares2;

        vars.sharesFluid = IERC4626(address(fluidVault)).balanceOf(address(strategy));
        console2.log("vars.sharesFluid", vars.sharesFluid);
        vars.assetsFluid = fluidVault.convertToAssets(vars.sharesFluid);

        uint256 superVaultPPS = _getSuperVaultPricePerShare();

        uint256 superVaultShares = centrifugeExpectedAssets.mulDiv(1e18, superVaultPPS, Math.Rounding.Floor);
        console2.log("SuperVault shares from centrifuge assets @ current PPS", superVaultShares);

        console2.log("assetsFluid", vars.assetsFluid);
        console2.log("assetsCentrifuge", centrifugeExpectedAssets);

        vars.totalAssets = vars.assetsFluid + centrifugeExpectedAssets;

        console2.log("totalAssets", vars.totalAssets);

        vars.vault1Proportion = vars.assetsFluid.mulDiv(1e18, vars.totalAssets, Math.Rounding.Ceil);
        vars.vault2Proportion = centrifugeExpectedAssets.mulDiv(1e18, vars.totalAssets, Math.Rounding.Ceil);

        vars.vault1Shares = vars.totalShares.mulDiv(vars.vault1Proportion, 1e18, Math.Rounding.Floor);
        vars.vault2Shares = vars.totalShares - vars.vault1Shares;

        console2.log("vault1Shares", vars.vault1Shares);
        console2.log("vault2Shares", vars.vault2Shares);

        vars.requestingUsers = new address[](2);
        vars.requestingUsers[0] = accountEth;
        vars.requestingUsers[1] = accInstances[2].account;

        vars.redeemHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        vars.redeem7540HookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_7540_VAULT_HOOK_KEY);

        vars.fulfillHooksAddresses = new address[](2);
        vars.fulfillHooksAddresses[0] = vars.redeemHookAddress;
        vars.fulfillHooksAddresses[1] = vars.redeem7540HookAddress;

        vars.fulfillHooksData = new bytes[](2);
        vars.fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(fluidVault),
            address(strategy),
            vars.vault1Shares,
            false,
            false
        );

        vars.fulfillHooksData[1] = _createApproveAndRedeem7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(centrifugeVault),
            address(centrifugeVault.share()),
            vars.vault2Shares,
            false,
            false
        );

        vars.expectedAssetsOrSharesOut = new uint256[](2);

        vars.expectedAssetsOrSharesOut[0] = vars.vault1Shares.mulDiv(superVaultPPS, 1e18, Math.Rounding.Floor);
        console2.log("vars.expectedAssetsOrSharesOut[0]", vars.expectedAssetsOrSharesOut[0]);
        vars.expectedAssetsOrSharesOut[1] = vars.vault2Shares.mulDiv(superVaultPPS, 1e18, Math.Rounding.Floor);
        console2.log("vars.expectedAssetsOrSharesOut[1]", vars.expectedAssetsOrSharesOut[1]);

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: vars.requestingUsers,
                hooks: vars.fulfillHooksAddresses,
                hookCalldata: vars.fulfillHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, vars.fulfillHooksAddresses),
                expectedAssetsOrSharesOut: vars.expectedAssetsOrSharesOut
            })
        );

        vars.sharesFluid = IERC4626(address(fluidVault)).balanceOf(address(strategy));
        console2.log("Shares fluid after", vars.sharesFluid);
        console2.log("Shares (claimable) centrifuge after", centrifugeVault.maxRedeem(address(strategy)));
        console2.log("---- PPS After Fulfill Redemptions", _getSuperVaultPricePerShare());

        assertEq(strategy.pendingRedeemRequest(accountEth), 0);
        assertEq(strategy.pendingRedeemRequest(accInstances[2].account), 0);

        assertLt(strategy.getYieldSourceAssetsInTransitInflows(address(centrifugeVault)), 5);
        assertLt(strategy.getYieldSourceSharesInTransitOutflows(address(centrifugeVault)), 5);
    }

    function _cancelCentrifugeDepositRequest() internal {
        address cancelDepositRequestHookAddress = _getHookAddress(ETH, CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY);

        address[] memory cancelHooksAddresses = new address[](1);
        cancelHooksAddresses[0] = cancelDepositRequestHookAddress;

        bytes[] memory cancelHooksData = new bytes[](1);
        cancelHooksData[0] = abi.encodePacked(bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(centrifugeVault));

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: cancelHooksAddresses,
                hookCalldata: cancelHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, cancelHooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );

        console2.log("Centrifuge deposit request cancellation submitted");
    }

    function _fulfillCancelDepositRequest(uint256 amountToCancel) internal {
        // Fulfill Centrifuge Cancel Deposit Request as rootManager
        vm.prank(rootManager);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, address(strategy), assetId, uint128(amountToCancel), uint128(amountToCancel)
        );

        console2.log("Centrifuge cancel deposit request fulfilled");
    }

    function _claimCancelDepositRequest() internal {
        address claimCancelDepositRequestHookAddress = _getHookAddress(ETH, CLAIM_CANCEL_DEPOSIT_REQUEST_7540_HOOK_KEY);

        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = claimCancelDepositRequestHookAddress;

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createClaimCancelHookData(address(centrifugeVault), address(strategy));

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: claimHooksAddresses,
                hookCalldata: claimHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, claimHooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );

        console2.log("Centrifuge cancel deposit request claimed");
    }

    function _cancelCentrifugeRedeemRequest() internal {
        address cancelRedeemRequestHookAddress = _getHookAddress(ETH, CANCEL_REDEEM_REQUEST_7540_HOOK_KEY);

        address[] memory cancelHooksAddresses = new address[](1);
        cancelHooksAddresses[0] = cancelRedeemRequestHookAddress;

        bytes[] memory cancelHooksData = new bytes[](1);
        cancelHooksData[0] = _createCancelHookData(address(centrifugeVault));

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: cancelHooksAddresses,
                hookCalldata: cancelHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, cancelHooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );

        console2.log("Centrifuge redeem request cancellation submitted");
    }

    function _fulfillCancelRedeemRequest(uint256 sharesToCancel) internal {
        // Fulfill Centrifuge Cancel Redeem Request as rootManager
        console2.log("Fulfilling cancel redeem request for shares:", sharesToCancel);

        vm.prank(rootManager);
        investmentManager.fulfillCancelRedeemRequest(
            poolId, trancheId, address(strategy), assetId, uint128(sharesToCancel)
        );

        console2.log("Centrifuge cancel redeem request fulfilled");
    }

    function _claimCancelRedeemRequest() internal {
        address claimCancelRedeemRequestHookAddress = _getHookAddress(ETH, CLAIM_CANCEL_REDEEM_REQUEST_7540_HOOK_KEY);

        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = claimCancelRedeemRequestHookAddress;

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createClaimCancelHookData(address(centrifugeVault), address(strategy));

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: claimHooksAddresses,
                hookCalldata: claimHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, claimHooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );

        console2.log("Centrifuge cancel redeem request claimed");
    }

    // New split functions for deposit and redeem

    function _requestCentrifugeDepositStep1(uint256 amountToDeposit) internal {
        // Request deposit into 7540 vault
        address approveAndRequestDepositHookAddress =
            _getHookAddress(ETH, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        address[] memory requestHooksAddresses = new address[](1);
        requestHooksAddresses[0] = approveAndRequestDepositHookAddress;

        bytes[] memory requestHooksData = new bytes[](1);
        requestHooksData[0] = _createApproveAndRequestDeposit7540HookData(
            address(centrifugeVault), address(asset), amountToDeposit, false
        );

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: requestHooksAddresses,
                hookCalldata: requestHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH,   requestHooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );

        console2.log("Centrifuge deposit request submitted");
    }

    function _requestCentrifugeDepositStep2(uint256 amountToDeposit) internal {
        uint256 expectedShares = centrifugeVault.convertToShares(amountToDeposit);

        // Fulfill Centrifuge Deposit Request as rootManager
        vm.prank(rootManager);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, address(strategy), assetId, uint128(amountToDeposit), uint128(expectedShares)
        );

        console2.log("Centrifuge deposit request fulfilled");
    }

    function _requestCentrifugeRedeemStep1() internal returns (uint256 centrifugeRedeem) {
        address requestRedeemHookAddress = _getHookAddress(ETH, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

        address[] memory requestHooksAddresses = new address[](1);
        requestHooksAddresses[0] = requestRedeemHookAddress;

        centrifugeRedeem = IERC20(centrifugeVault.share()).balanceOf(address(strategy));

        console2.log(" BALANCE OF CENTRIFUGE SHARES IN SUPER VAULT", centrifugeRedeem);

        bytes[] memory requestHooksData = new bytes[](1);
        requestHooksData[0] = _createRequestRedeem7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(centrifugeVault), centrifugeRedeem, false
        );

        vm.prank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: requestHooksAddresses,
                hookCalldata: requestHooksData,
                hookProofs: _getMerkleProofsForAddresses(ETH, requestHooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );

        console2.log("Centrifuge redeem request submitted");
        return centrifugeRedeem;
    }

    function _requestCentrifugeRedeemStep2(
        uint256 centrifugeRedeem,
        bool warp
    )
        internal
        returns (uint256 centrifugeAssets)
    {
        if (warp) vm.warp(block.timestamp + 10 weeks);

        uint256 expectedAssetsOut = centrifugeVault.convertToAssets(centrifugeRedeem) + (warp ? 1e6 : 0);
        console2.log("expected assets out", expectedAssetsOut);

        uint256 expectedPps = expectedAssetsOut.mulDiv(1e18, centrifugeRedeem, Math.Rounding.Floor);

        vm.prank(rootManager);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, address(strategy), assetId, uint128(expectedAssetsOut), uint128(centrifugeRedeem)
        );

        // increase PPS if warping to simulate yield
        if (warp) {
            vm.mockCall(
                address(poolManager),
                abi.encodeWithSelector(IPoolManager.getTranchePrice.selector),
                abi.encode(uint128(expectedPps), uint128(1e18))
            );
        }

        // saving expected assets in advance
        centrifugeAssets = centrifugeVault.maxWithdraw(address(strategy));
        console2.log("Centrifuge redeem request fulfilled, expected assets:", centrifugeAssets);
        return centrifugeAssets;
    }
}
