// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// testing
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";

contract SuperVault5115Underlying is BaseSuperVaultTest {
    using Math for uint256;

    IStandardizedYield public pendleEthena;
    address public pendleEthenaAddress;

    address public account;
    AccountInstance public instance;

    uint256 public amountToDeposit;
    uint256 public constant PRECISION = 1e18;

    function setUp() public override {
        super.setUp();

        console2.log("\n--- SETUP 5115 FOCUSED SUPERVAULT ---");

        amountToDeposit = 1000e6;

        vm.selectFork(FORKS[ETH]);

        // Set up accounts
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDE_KEY]);
        vm.label(address(asset), "USDE");

        pendleEthenaAddress = realVaultAddresses[ETH][ERC5115_VAULT_KEY][PENDLE_ETHENA_KEY][SUSDE_KEY];
        vm.label(pendleEthenaAddress, "PendleEthena");

        // Get real yield sources from fork
        pendleEthena = IStandardizedYield(pendleEthenaAddress);

        vm.startPrank(SV_MANAGER);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault sUSDE",
                symbol: "svsUSDE",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                superVaultCap: SUPER_VAULT_CAP
            })
        );
        vm.label(vaultAddr, "SuperVaultsUSDE");
        vm.label(escrowAddr, "SuperVaultEscrowUSDE");
        vm.label(strategyAddr, "SuperVaultStrategyUSDE");
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        vm.stopPrank();

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategy.manageYieldSource(
            address(pendleEthenaAddress),
            _getContract(ETH, ERC5115_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );

        strategy.manageYieldSource(
            CHAIN_1_SUSDE,
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            true
        );

        strategy.proposeOrExecuteHookRoot(_getMerkleRoot());
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }

    function test_SuperVault_5115_Underlying_E2EFlow() public {
        console2.log("\n");
        console2.log("----test_SuperVault_5115_Underlying_E2EFlow-----");
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);

        // Step 1: Request Deposit
        _requestDeposit(amountToDeposit);

        uint256 balanceAfterDeposit = asset.balanceOf(account);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(account),
            initialUserAssets - amountToDeposit,
            "User assets not reduced after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillSV5115Deposit(amountToDeposit);

        // Step 3: Claim Deposit
        _claimDeposit(amountToDeposit);

        console2.log("\n Claim deposit done");

        // Get shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(account);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 50 weeks);
        uint256 pricePerShare = _getPPS();
        console2.log("\n PPS BEFORE REDEEM", pricePerShare);

        // Step 4: Request Redeem
        _requestRedeem(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(vault.share()).balanceOf(account), 0, "User shares not transferred from account");
        assertEq(IERC20(vault.share()).balanceOf(address(escrow)), userShares, "Shares not transferred to escrow");

        console2.log("\n REQUESTING REDEEM ON UNDERLYING ETHENA VAULT");
        _requestRedeem_Async5115(CHAIN_1_SUSDE);

        pricePerShare = _getPPS();
        console2.log("\n PPS AFTER REDEEM START", pricePerShare);

        vm.warp(block.timestamp + 2 weeks);

        _claimRedeem_Async5115(CHAIN_1_SUSDE);

        pricePerShare = _getPPS();
        console2.log("\n PPS AFTER FULFILL REQUESTS ASSETS CLAIM", pricePerShare);

        uint256 claimableAssets = vault.maxWithdraw(account);

        // Step 5: Claim Redeem
        _claimWithdraw(claimableAssets);

        uint256 balanceAfterRedeem = asset.balanceOf(account);
        uint256 amountRedeemed = balanceAfterRedeem - balanceAfterDeposit;
        console2.log("Balance difference", amountRedeemed);
        console2.log("LOSS to initial deposit", amountToDeposit - amountRedeemed);
    }

    function _fulfillSV5115Deposit(uint256 amount) internal {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_5115_VAULT_HOOK_KEY);

        address[] memory hooks_ = new address[](1);
        hooks_[0] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getMerkleProof(depositHookAddress);

        uint256 expectedShares = IStandardizedYield(pendleEthenaAddress).previewDeposit(address(asset), amount);
        console2.log("preview deposit", expectedShares);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = _createApproveAndDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            pendleEthenaAddress,
            address(asset),
            amount,
            expectedShares,
            false,
            false
        );

        address[] memory users = new address[](1);
        users[0] = account;

        uint256[] memory minAssetsOrSharesOut = new uint256[](1);
        minAssetsOrSharesOut[0] = expectedShares;

        vm.startPrank(STRATEGIST);
        strategy.execute(
            ISuperVaultStrategy.ExecuteArgs({
                users: users,
                hooks: hooks_,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: minAssetsOrSharesOut,
                isDeposit: true
            })
        );
        vm.stopPrank();
        console2.log("-------SVShare balance", IStandardizedYield(pendleEthenaAddress).balanceOf(address(strategy)));
        uint256 pps = _getPPS();
        console2.log("PPS AFTER FULFILL DEPOSIT", pps);
    }

    function _requestRedeem_Async5115(address tokenOut) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = account;

        address[] memory hooks_ = new address[](2);
        hooks_[0] = _getHookAddress(ETH, REDEEM_5115_VAULT_HOOK_KEY);
        hooks_[1] = _getHookAddress(ETH, ETHENA_COOLDOWN_SHARES_HOOK_KEY);

        uint256 shares = strategy.pendingRedeemRequest(account);
        uint256 pps = _getPPS();
        console2.log("PPS BEFORE REDEEM REQUEST", pps);
        uint256 assetsSV = shares.mulDiv(pps, 1e18, Math.Rounding.Floor);
        console2.log("USDE FOR REDEEM", assetsSV);
        console2.log("balance of pendleEthena", pendleEthena.balanceOf(address(strategy)));
        uint256 underlyingSharesOut = pendleEthena.previewDeposit(address(asset), assetsSV);
        console2.log("underlyingSharesOut", underlyingSharesOut);
        uint256 underlyingAssetsOut = pendleEthena.previewRedeem(tokenOut, underlyingSharesOut);
        console2.log("underlyingAssetsOut", underlyingAssetsOut);

        bytes[] memory hookCalldata = new bytes[](2);
        hookCalldata[0] = _create5115RedeemHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            pendleEthenaAddress,
            tokenOut,
            underlyingSharesOut,
            underlyingAssetsOut,
            false,
            false
        );

        hookCalldata[1] =
            abi.encodePacked(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), tokenOut, underlyingAssetsOut, false);

        vm.startPrank(STRATEGIST);
        strategy.execute(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: hooks_,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: new uint256[](0),
                isDeposit: false
            })
        );
        vm.stopPrank();
    }

    function _claimRedeem_Async5115(address tokenOut) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = account;

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = _getHookAddress(ETH, ETHENA_UNSTAKE_HOOK_KEY);

        uint256 shares = strategy.pendingRedeemRequest(account);
        uint256 pps = _getPPS();
        console2.log("PPS BEFORE CLAIM REDEEM", pps);
        uint256 assetsSV = shares.mulDiv(pps, 1e18, Math.Rounding.Floor);
        console2.log("USDE FOR CLAIM REDEEM", assetsSV);
        uint256 underlyingSharesOut = IERC4626(tokenOut).previewDeposit(assetsSV);
        console2.log("underlyingSharesOut", underlyingSharesOut);
        uint256 underlyingAssetsOut = IERC4626(tokenOut).previewRedeem(underlyingSharesOut);
        console2.log("underlyingAssetsOut", underlyingAssetsOut);

        bytes[] memory fulfillHooksData = new bytes[](1);
        fulfillHooksData[0] =
            abi.encodePacked(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), tokenOut, shares, address(strategy), false);

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = underlyingAssetsOut;

        vm.startPrank(STRATEGIST);
        strategy.execute(
            ISuperVaultStrategy.ExecuteArgs({
                users: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                isDeposit: false
            })
        );
        vm.stopPrank();
    }

    function _getPPS() internal view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = vault.totalSupply();
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pricePerShare = PRECISION;
        } else {
            // Calculate current PPS in price decimals
            (uint256 totalAssetsValue,) = strategy.totalAssets();
            pricePerShare = totalAssetsValue.mulDiv(PRECISION, totalSupplyAmount, Math.Rounding.Floor);
        }
    }
}
