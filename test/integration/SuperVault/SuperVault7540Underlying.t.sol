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

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { IYieldSourceOracle } from "../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";

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

    function test_SuperVault_7540_Underlying_E2E_Flow() public {
        console2.log("Original pps", _getSuperVaultPricePerShare());

        // Request deposit into superVault as user1
        _requestDeposit(amount);

        console2.log("\n user1 pending deposit", strategy.pendingDepositRequest(accountEth));
        console2.log("\n pps After Request Deposit1", _getSuperVaultPricePerShare());

        // Request deposit into superVault as user2
        deal(address(asset), accInstances[2].account, amount);
        _requestDepositForAccount(accInstances[2], amount);

        console2.log("\n pps After Request Deposit2", _getSuperVaultPricePerShare());

        // Request deposit into 7540 vault
        _requestCentrifugeDeposit(amount);
        console2.log("\n pps After Request Centrifuge Deposit", _getSuperVaultPricePerShare());

        // Deposit into underlying vaults as strategy
        _fulfillDepositRequests(amount * 2);
        console2.log("\n pps After Fulfill Deposit Requests", _getSuperVaultPricePerShare());

        // Claim deposit into superVault as user1
        _claimDeposit(amount);
        console2.log("\n User1 SV Share Balance After Claim Deposit", vault.balanceOf(accountEth));

        // Claim deposit into superVault as user2
        _claimDepositForAccount(accInstances[2], amount);
        console2.log("\n User2 SV Share Balance After Claim Deposit", vault.balanceOf(accInstances[2].account));

        // --- REDEMPTIONS ---
        vm.warp(block.timestamp + 10 weeks);

        uint256 amountToRedeemAccEth = IERC20(vault.share()).balanceOf(accountEth);
        __requestRedeem(instanceOnEth, amountToRedeemAccEth, false);
        uint256 amountToRedeemAcc2 = IERC20(vault.share()).balanceOf(accInstances[2].account);
        __requestRedeem(accInstances[2], amountToRedeemAcc2, false);

        console2.log("\n user1 pending redeem", strategy.pendingRedeemRequest(accountEth));
        console2.log("\n user2 pending redeem", strategy.pendingRedeemRequest(accInstances[2].account));

        _requestCentrifugeRedeem();

        console2.log("user1 pending redeem", strategy.pendingRedeemRequest(accountEth));
        console2.log("user2 pending redeem", strategy.pendingRedeemRequest(accInstances[2].account));

        console2.log("---- PPS Before Fulfill Redemptions", _getSuperVaultPricePerShare());

        _fulfillRedemptions();

        console2.log("---- PPS After Fulfill Redemptions", _getSuperVaultPricePerShare());
    }

    function _requestCentrifugeDeposit(uint256 amountToDeposit) internal {
        // Request deposit into 7540 vault
        address approveAndRequestDepositHookAddress =
            _getHookAddress(ETH, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        address[] memory requestHooksAddresses = new address[](1);
        requestHooksAddresses[0] = approveAndRequestDepositHookAddress;

        bytes[] memory requestHooksData = new bytes[](1);
        requestHooksData[0] = _createApproveAndRequestDeposit7540HookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            address(centrifugeVault),
            address(asset),
            amountToDeposit,
            false
        );

        vm.prank(STRATEGIST);
        strategy.execute(new address[](0), requestHooksAddresses, requestHooksData, new uint256[](0), false);
        console2.log("---- Pending deposit request", centrifugeVault.pendingDepositRequest(0, address(strategy)));

        uint256 expectedShares = centrifugeVault.convertToShares(amountToDeposit);

        // Fulfill Centrifuge Deposit Request as rootManager
        vm.prank(rootManager);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, address(strategy), assetId, uint128(amountToDeposit), uint128(expectedShares)
        );

        console2.log("------ Claimable deposit request", centrifugeVault.claimableDepositRequest(0, address(strategy)));
        console2.log("------ Max deposit", centrifugeVault.maxDeposit(address(strategy)));
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
        strategy.execute(requestingUsers, fulfillHooksAddresses, fulfillHooksData, expectedAssetsOrSharesOut, true);

        // Update share price points for each user
        uint256 pps = _getSuperVaultPricePerShare();
        uint256 shares = amount.mulDiv(1e18, pps);
        userSharePricePoints[accountEth].push(SharePricePoint({ shares: shares, pricePerShare: pps }));
        userSharePricePoints[accInstances[2].account].push(SharePricePoint({ shares: shares, pricePerShare: pps }));
    }

    function _requestCentrifugeRedeem() internal {
        address requestRedeemHookAddress = _getHookAddress(ETH, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

        address[] memory requestHooksAddresses = new address[](1);
        requestHooksAddresses[0] = requestRedeemHookAddress;

        uint256 centrifugeRedeem = IERC20(centrifugeVault.share()).balanceOf(address(strategy));

        bytes[] memory requestHooksData = new bytes[](1);
        requestHooksData[0] = _createRequestRedeem7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(centrifugeVault), centrifugeRedeem, false
        );

        vm.prank(STRATEGIST);
        strategy.execute(new address[](0), requestHooksAddresses, requestHooksData, new uint256[](0), false);

        console2.log("---- PPS After Centrifuge Request Redeem", _getSuperVaultPricePerShare());

        uint256 expectedAssetsOut = centrifugeVault.convertToAssets(centrifugeRedeem);

        vm.prank(rootManager);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, address(strategy), assetId, uint128(expectedAssetsOut), uint128(centrifugeRedeem)
        );

        console2.log("---- PPS After Centrifuge Fulfill Redeem", _getSuperVaultPricePerShare());
    }

    function _fulfillRedemptions() internal {
        uint256 shares1 = strategy.pendingRedeemRequest(accountEth);
        uint256 shares2 = strategy.pendingRedeemRequest(accInstances[2].account);
        uint256 shares = (shares1 + shares2) / 2;

        // uint256 centrifugeRedeemShares = centrifugeVault.maxRedeem(address(strategy));
        // uint256 centrifugeExpectedAssets = centrifugeVault.maxWithdraw(address(strategy));
        uint256 sharesAsAssets = shares.mulDiv(_getSuperVaultPricePerShare(), 1e18, Math.Rounding.Floor);
        uint256 assetsAsCentrifugeShares = IYieldSourceOracle(_getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY)).getShareOutput(address(centrifugeVault), address(asset), sharesAsAssets);
        uint256 centrifugeExpectedAssets = centrifugeVault.convertToAssets(assetsAsCentrifugeShares);
        
        uint256 fluidRedeemShares = fluidVault.maxRedeem(address(strategy));
        uint256 fluidRedeemAmount = fluidVault.convertToAssets(fluidRedeemShares);

        address[] memory requestingUsers = new address[](2);
        requestingUsers[0] = accountEth;
        requestingUsers[1] = accInstances[2].account;

        address redeemHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address withdraw7540HookAddress = _getHookAddress(ETH, APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](2);
        fulfillHooksAddresses[0] = redeemHookAddress;
        fulfillHooksAddresses[1] = withdraw7540HookAddress;

        bytes[] memory fulfillHooksData = new bytes[](2);
        fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(fluidVault),
            address(strategy),
            shares,
            false,
            false
        );

        fulfillHooksData[1] = _createApproveAndWithdraw7540VaultHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(centrifugeVault),
            address(centrifugeVault.share()),
            //centrifugeRedeemShares,
            shares,
            false,
            false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = fluidRedeemAmount;
        expectedAssetsOrSharesOut[1] = centrifugeExpectedAssets;

        console2.log("----expectedAssetsOrSharesOut[0]", expectedAssetsOrSharesOut[0]);
        console2.log("----expectedAssetsOrSharesOut[1]", expectedAssetsOrSharesOut[1]);

        vm.prank(STRATEGIST);
        strategy.execute(requestingUsers, fulfillHooksAddresses, fulfillHooksData, expectedAssetsOrSharesOut, false);

        console2.log("---- PPS After Fulfill Redemptions", _getSuperVaultPricePerShare());
    }
}
