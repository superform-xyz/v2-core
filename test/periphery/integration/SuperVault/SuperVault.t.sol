// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// testing
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
// superform
import { ISuperVault } from "../../../../src/periphery/interfaces/ISuperVault.sol";
import { SuperVault } from "../../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultEscrow } from "../../../../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { SuperVaultStrategy } from "../../../../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { ISuperVaultEscrow } from "../../../../src/periphery/interfaces/ISuperVaultEscrow.sol";
import { ISuperVaultAggregator } from "../../../../src/periphery/interfaces/ISuperVaultAggregator.sol";
import { IERC7540Redeem, IERC7741 } from "../../../../src/vendor/standards/ERC7540/IERC7540Vault.sol";
import { ISuperVaultStrategy } from "../../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ERC7540YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ISuperLedger } from "../../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperHookInspector } from "../../../../src/core/interfaces/ISuperHook.sol";
import { IGearboxFarmingPool } from "../../../../src/vendor/gearbox/IGearboxFarmingPool.sol";
import { ISuperExecutor } from "../../../../src/core/interfaces/ISuperExecutor.sol";
import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";

contract SuperVaultTest is BaseSuperVaultTest {
    using Math for uint256;

    address operator = address(0x123);
    uint256 constant userPrivateKey = 0xA11CE; // Replace with a known good testing private key
    address userAddress; // Will be derived from private key
    ERC7540YieldSourceOracle public oracle;
    ISuperLedger public superLedgerETH;
    address gearToken;
    IERC4626 gearboxVault;
    IGearboxFarmingPool gearboxFarmingPool;
    SuperVault gearSuperVault;
    SuperVaultEscrow escrowGearSuperVault;
    SuperVaultStrategy strategyGearSuperVault;

    function setUp() public override {
        super.setUp();
        userAddress = vm.addr(userPrivateKey); // Derive the correct address from private key

        vm.selectFork(FORKS[ETH]);

        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));

        oracle = ERC7540YieldSourceOracle(_getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY));

        gearToken = existingUnderlyingTokens[ETH][GEAR_KEY];
        console2.log("gearToken: ", address(gearToken));
        vm.label(gearToken, "GearToken");

        // Get real yield sources from fork
        address gearboxVaultAddr = realVaultAddresses[ETH][ERC4626_VAULT_KEY][GEARBOX_VAULT_KEY][USDC_KEY];
        vm.label(gearboxVaultAddr, "GearboxVault");
        gearboxVault = IERC4626(gearboxVaultAddr);

        address gearboxStakingAddr =
            realVaultAddresses[ETH][STAKING_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY];
        console2.log("gearboxStakingAddr: ", gearboxStakingAddr);
        vm.label(gearboxStakingAddr, "GearboxStaking");
        gearboxFarmingPool = IGearboxFarmingPool(gearboxStakingAddr);
    }

    /*//////////////////////////////////////////////////////////////
                       SUPERVAULT.SOL
    //////////////////////////////////////////////////////////////*/

    function test_Name() public view {
        string memory name = vault.name();
        assertEq(name, "SuperVault");
    }

    function test_Symbol() public view {
        string memory symbol = vault.symbol();
        assertEq(symbol, "SV_USDC");
    }

    function test_Deposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        _deposit(depositAmount);

        // Verify state
        uint256 userShares = vault.balanceOf(accountEth);
        assertGt(userShares, 0, "No shares minted to user");
        assertEq(asset.balanceOf(address(strategy)), depositAmount, "Wrong strategy balance");
    }

    function test_DepositDirectlyMintsShares() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Check state before deposit
        uint256 sharesBefore = vault.balanceOf(accountEth);
        assertEq(sharesBefore, 0, "User has shares before deposit");

        // Perform deposit
        _deposit(depositAmount);

        // Verify shares were minted immediately
        uint256 sharesAfter = vault.balanceOf(accountEth);
        assertGt(sharesAfter, 0, "No shares minted to user");

        // Assets should be in the strategy as free assets
        assertEq(asset.balanceOf(address(strategy)), depositAmount, "Wrong strategy balance");
    }

    function test_DepositAndAllocateToYield() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Direct deposit
        _deposit(depositAmount);

        // Verify deposit state
        uint256 userShares = vault.balanceOf(accountEth);
        assertGt(userShares, 0, "No shares minted to user");
        assertEq(asset.balanceOf(address(strategy)), depositAmount, "Wrong strategy balance");

        // Allocate the assets to yield sources
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Verify allocation state
        assertGt(fluidVault.balanceOf(address(strategy)), 0, "No fluid shares allocated");
        assertGt(aaveVault.balanceOf(address(strategy)), 0, "No aave shares allocated");
    }

    function test_FulfillRedeem_FullAmountWithThreshold() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Deposit and allocate to yield
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        uint256 vaultBalance = vault.balanceOf(accountEth);
        uint256 redeemShares = vaultBalance - (vaultBalance * 2e4 / 1e5);
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares, address(fluidVault), address(aaveVault));

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), 0, "Pending redeem request not cleared");
        assertGt(strategy.claimableWithdraw(accountEth), 0, "No assets available to withdraw");
    }

    function test_FulfillRedeem_FullAmount() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Deposit and allocate to yield
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Request redemption
        uint256 vaultBalance = vault.balanceOf(accountEth);
        _requestRedeem(vaultBalance);
        _fulfillRedeem(vaultBalance, address(fluidVault), address(aaveVault));

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), 0, "Pending redeem request not cleared");
        assertGt(strategy.claimableWithdraw(accountEth), 0, "No assets available to withdraw");
    }

    function test_DepositAndAllocate() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup and fulfill deposit
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Verify state
        uint256 userShares = vault.balanceOf(accountEth);
        assertGt(userShares, 0, "No shares minted to user");

        // Verify allocation
        assertGt(fluidVault.balanceOf(address(strategy)), 0, "No fluid shares allocated");
        assertGt(aaveVault.balanceOf(address(strategy)), 0, "No aave shares allocated");
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestRedeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Deposit and allocate to yield
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Request redemption
        uint256 vaultBalance = vault.balanceOf(accountEth);
        uint256 redeemShares = vaultBalance - (vaultBalance * 2e4 / 1e5);
        _requestRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), redeemShares, "Wrong pending redeem amount");
        assertEq(vault.balanceOf(address(escrow)), redeemShares, "Wrong escrow balance");
    }

    function test_FulfillRedeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Deposit and allocate to yield
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Request redemption
        uint256 vaultBalance = vault.balanceOf(accountEth);
        uint256 redeemShares = vaultBalance - (vaultBalance * 2e4 / 1e5);
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares, address(fluidVault), address(aaveVault));

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), 0, "Pending redeem request not cleared");
        assertGt(strategy.claimableWithdraw(accountEth), 0, "No assets available to withdraw");
    }

    function test_ClaimRedeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC
        uint256 initialAssetBalance = asset.balanceOf(address(accountEth));
        console2.log("-------------- initialAssetBalance user", initialAssetBalance);

        // Deposit and allocate to yield
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        console2.log("-------------- balance strategy after deposit ", asset.balanceOf(address(strategy)));

        // Get balances after deposit
        uint256 assetBalanceAfterDeposit = asset.balanceOf(accountEth);
        uint256 initialShares = vault.balanceOf(accountEth);
        console2.log("-------------- initialAssetBalance user", assetBalanceAfterDeposit);
        console2.log("-------------- initialShares user", initialShares);

        console2.log("-------------- balance strategy after redeem ", asset.balanceOf(address(strategy)));
        // Request redeem of half the shares
        uint256 redeemShares = initialShares / 2;
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares, address(fluidVault), address(aaveVault));

        console2.log("-------------- balance strategy after redeem ", asset.balanceOf(address(strategy)));
        // Get claimable assets
        uint256 claimableAssets = strategy.claimableWithdraw(accountEth);
        console2.log("-------------- claimableAssets user", claimableAssets);
        // Claim redeem
        _claimWithdraw(claimableAssets);

        // Verify state
        assertEq(vault.balanceOf(accountEth), initialShares - redeemShares, "Wrong final share balance");
        assertApproxEqRel(
            asset.balanceOf(accountEth), initialAssetBalance + claimableAssets, 0.05e18, "Wrong final asset balance"
        );
        assertEq(strategy.claimableWithdraw(accountEth), 0, "Assets not claimed");
    }

    function test_AuthorizeOperator() public {
        // Create signature components
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        // Generate signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                vault.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), userAddress, operator, approved, nonce, deadline)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Debug logs
        console2.log("User Address:", userAddress);
        console2.log("Operator:", operator);
        console2.log("Digest:", uint256(digest));

        vm.prank(operator);
        bool success = vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);

        assertTrue(success, "Authorization failed");
        assertTrue(vault.isOperator(userAddress, operator), "Operator not authorized");
        assertTrue(vault.authorizations(userAddress, nonce), "Nonce not marked as used");
    }

    function test_RevertWhen_AuthorizingOperatorWithExpiredDeadline() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp - 1; // Expired deadline

        // Generate signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                vault.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), userAddress, operator, approved, nonce, deadline)
                )
            )
        );

        // User signs the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Operator tries to use expired signature
        vm.prank(operator);
        vm.expectRevert(ISuperVault.TIMELOCK_NOT_EXPIRED.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);
    }

    function test_RevertWhen_AuthorizingOperatorWithUsedNonce() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 domainSeparator = vault.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), userAddress, operator, approved, nonce, deadline)
                )
            )
        );
        vm.startPrank(userAddress);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First authorization
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);

        // Try to use same nonce again
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);

        vm.stopPrank();
    }

    function test_RevertWhen_AuthorizingOperatorWithInvalidSignature() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        // Generate signature with wrong private key
        bytes32 domainSeparator = vault.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), userAddress, operator, approved, nonce, deadline)
                )
            )
        );
        uint256 wrongPrivateKey = 0x789; // Different private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(operator);
        vm.expectRevert(ISuperVault.INVALID_SIGNATURE.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);
    }

    function test_RevertWhen_OperatorAuthorizingSelf() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                vault.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), operator, operator, approved, nonce, deadline)
                )
            )
        );

        // Generate signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Operator tries to authorize themselves
        vm.prank(operator);
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.authorizeOperator(operator, operator, approved, nonce, deadline, signature);
    }

    function test_RevertWhen_AuthorizingOperatorWithDifferentChainId() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        // Change chain ID
        uint256 originalChainId = block.chainid;
        vm.chainId(originalChainId + 1);

        // Generate signature with original chain ID
        bytes32 domainSeparator = vault.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), operator, operator, approved, nonce, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(operator);
        vm.expectRevert(ISuperVault.INVALID_SIGNATURE.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);

        // Reset chain ID
        vm.chainId(originalChainId);
    }

    function test_InvalidateNonce() public {
        bytes32 nonce = keccak256("test_nonce");

        // Invalidate nonce
        vm.prank(userAddress);
        vault.invalidateNonce(nonce);

        // Try to use invalidated nonce
        bool approved = true;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 domainSeparator = vault.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(vault.AUTHORIZE_OPERATOR_TYPEHASH(), userAddress, operator, approved, nonce, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(operator);
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, signature);
    }

    function test_TotalAssets() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Check initial total assets
        uint256 initialTotalAssets = vault.totalAssets();
        assertEq(initialTotalAssets, 0, "Initial totalAssets should be 0");

        // Perform deposit
        _deposit(depositAmount);

        // Allocate to yield
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Verify assets reported by totalAssets
        uint256 totalAssetsAfterDeposit = vault.totalAssets();
        assertApproxEqRel(
            totalAssetsAfterDeposit, depositAmount, 0.01e18, "totalAssets should approximately equal deposit"
        );
    }

    function test_ConvertToShares() public {
        uint256 assetsAmount = 1000e6; // 1000 USDC

        // With fresh vault (1:1 ratio), should convert directly
        uint256 shares = vault.convertToShares(assetsAmount);
        assertEq(shares, assetsAmount, "Initial share conversion should be 1:1");

        // Make a deposit to ensure PPS is established
        _deposit(assetsAmount);

        // Should still be approximately 1:1 after initial deposit
        uint256 sharesAfter = vault.convertToShares(assetsAmount);
        assertApproxEqRel(sharesAfter, assetsAmount, 0.01e18, "Share conversion should be close to 1:1");
    }

    function test_ConvertToAssets() public {
        uint256 sharesAmount = 1000e6; // 1000 shares

        // With fresh vault (1:1 ratio), should convert directly
        uint256 assets = vault.convertToAssets(sharesAmount);
        assertEq(assets, sharesAmount, "Initial asset conversion should be 1:1");

        // Make a deposit to ensure PPS is established
        _deposit(2000e6); // 2000 USDC deposit

        // Should still be approximately 1:1 after initial deposit
        uint256 assetsAfter = vault.convertToAssets(sharesAmount);
        assertApproxEqRel(assetsAfter, sharesAmount, 0.01e18, "Asset conversion should be close to 1:1");
    }

    function test_Mint() public {
        uint256 mintShares = 1000e6; // 1000 shares
        uint256 expectedAssets = vault.previewMint(mintShares);

        // Approve assets for minting
        _getTokens(address(asset), accountEth, expectedAssets);
        vm.prank(accountEth);
        asset.approve(address(vault), expectedAssets);

        // Mint shares
        vm.prank(accountEth);
        uint256 assetsUsed = vault.mint(mintShares, accountEth);

        // Verify results
        assertEq(assetsUsed, expectedAssets, "Wrong amount of assets used");
        assertEq(vault.balanceOf(accountEth), mintShares, "Wrong shares balance");
        assertEq(asset.balanceOf(address(strategy)), expectedAssets, "Wrong strategy asset balance");
    }

    function test_MaxMint() public view {
        uint256 result = vault.maxMint(accountEth);

        // By default, should be proportional to maxDeposit
        uint256 maxDeposit = vault.maxDeposit(accountEth);
        uint256 expectedMax = vault.convertToShares(maxDeposit);

        assertEq(result, expectedMax, "maxMint should match shares equivalent of maxDeposit");
    }

    function test_MaxWithdraw() public executeWithoutHookRestrictions {
        // MaxWithdraw should be the user's claimable balance
        uint256 deposit = 1000e6; // 1000 USDC
        _deposit(deposit);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(deposit, address(fluidVault), address(aaveVault));

        // User balance vs maxWithdraw before redemption
        uint256 userBalance = vault.balanceOf(accountEth);
        uint256 maxWithdraw = vault.maxWithdraw(accountEth);

        // Before fulfilling redeem request, maxWithdraw should be 0
        assertEq(maxWithdraw, 0, "maxWithdraw should be 0 before redemption is fulfilled");

        // Make and fulfill redeem request
        _requestRedeem(userBalance);
        _fulfillRedeem(userBalance, address(fluidVault), address(aaveVault));

        // After fulfillment, maxWithdraw should match claimable amount
        uint256 claimable = strategy.claimableWithdraw(accountEth);
        uint256 maxWithdrawAfter = vault.maxWithdraw(accountEth);
        assertEq(maxWithdrawAfter, claimable, "maxWithdraw should match claimable amount");
    }

    function test_MaxRedeem() public executeWithoutHookRestrictions {
        // Initial deposit and allocation
        uint256 deposit = 1000e6; // 1000 USDC
        _deposit(deposit);
        _depositFreeAssetsFromSingleAmount(deposit, address(fluidVault), address(aaveVault));

        // Before redemption request, maxRedeem should be 0 (no claimable assets)
        uint256 maxRedeemBefore = vault.maxRedeem(accountEth);
        assertEq(maxRedeemBefore, 0, "maxRedeem should be 0 before redemption request is fulfilled");

        // Request and fulfill redemption for half of shares
        uint256 userShares = vault.balanceOf(accountEth);
        uint256 redeemAmount = userShares / 2;
        _requestRedeem(redeemAmount);
        _fulfillRedeem(redeemAmount, address(fluidVault), address(aaveVault));

        // After fulfillment, maxRedeem should match the shares equivalent to claimable assets
        uint256 claimableAssets = strategy.claimableWithdraw(accountEth);
        uint256 maxRedeemAfter = vault.maxRedeem(accountEth);

        // Calculate expected shares based on claimable assets and average withdraw price
        uint256 avgWithdrawPrice = strategy.getAverageWithdrawPrice(accountEth);
        // Use Math.Rounding.Ceil to match the contract's implementation
        uint256 expectedShares = claimableAssets.mulDiv(vault.PRECISION(), avgWithdrawPrice, Math.Rounding.Ceil);

        // Verify maxRedeem matches expected shares with sufficient tolerance
        assertApproxEqAbs(
            maxRedeemAfter, expectedShares, 10, "maxRedeem should match shares equivalent of claimable assets"
        );
    }

    function test_PreviewDepositAndMint() public view {
        uint256 amount = 1000e6; // 1000 USDC/shares

        // Test previewDeposit (implemented)
        uint256 expectedShares = vault.convertToShares(amount);
        uint256 previewShares = vault.previewDeposit(amount);
        assertEq(previewShares, expectedShares, "previewDeposit should match convertToShares");

        // Test previewMint (implemented)
        uint256 expectedAssets = vault.convertToAssets(amount);
        uint256 previewAssets = vault.previewMint(amount);
        assertEq(previewAssets, expectedAssets, "previewMint should match convertToAssets");
    }

    function test_RevertWhen_PreviewWithdraw() public {
        uint256 amount = 1000e6; // 1000 USDC

        // previewWithdraw should revert with NOT_IMPLEMENTED
        vm.expectRevert(ISuperVault.NOT_IMPLEMENTED.selector);
        vault.previewWithdraw(amount);
    }

    function test_RevertWhen_PreviewRedeem() public {
        uint256 amount = 1000e6; // 1000 shares

        // previewRedeem should revert with NOT_IMPLEMENTED
        vm.expectRevert(ISuperVault.NOT_IMPLEMENTED.selector);
        vault.previewRedeem(amount);
    }

    function test_Redeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Deposit and allocate to yield
        _deposit(depositAmount);
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Make and fulfill redemption request to get claimable assets
        uint256 userShares = vault.balanceOf(accountEth);
        _requestRedeem(userShares);
        _fulfillRedeem(userShares, address(fluidVault), address(aaveVault));

        // Get claimable amount
        uint256 maxRedeem = vault.maxRedeem(accountEth);
        uint256 claimableAssets = strategy.claimableWithdraw(accountEth);

        // Use redeem function to claim assets
        uint256 initialAssetBalance = asset.balanceOf(accountEth);
        vm.prank(accountEth);
        uint256 assetsRedeemed = vault.redeem(
            maxRedeem, // shares to redeem
            accountEth, // receiver
            accountEth // owner
        );

        // Verify results with tolerance for rounding errors
        assertApproxEqAbs(assetsRedeemed, claimableAssets, 5, "Wrong redeem amount (with tolerance)");
        assertApproxEqAbs(
            asset.balanceOf(accountEth),
            initialAssetBalance + claimableAssets,
            5,
            "Wrong final asset balance (with tolerance)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        REDEMPTION FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PendingRedeemRequest() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC
        _deposit(depositAmount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Check initial state - no pending request
        uint256 initialPending = vault.pendingRedeemRequest(0, accountEth);
        assertEq(initialPending, 0, "Should have no initial pending request");

        // Request redeem for half of shares
        uint256 userShares = vault.balanceOf(accountEth);
        uint256 redeemAmount = userShares / 2;
        _requestRedeem(redeemAmount);

        // Check pending amount matches requested amount
        uint256 pendingAfterRequest = vault.pendingRedeemRequest(0, accountEth);
        assertEq(pendingAfterRequest, redeemAmount, "Pending request should match requested amount");
    }

    function test_CancelRedeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC
        _deposit(depositAmount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));

        // Request redeem
        uint256 userShares = vault.balanceOf(accountEth);
        uint256 redeemAmount = userShares / 2;
        _requestRedeem(redeemAmount);

        // Check shares are in escrow
        assertEq(vault.balanceOf(address(escrow)), redeemAmount, "Escrow should hold shares");

        // Cancel redeem
        vm.prank(accountEth);
        vault.cancelRedeem(accountEth);

        // Verify state after cancellation
        assertEq(vault.pendingRedeemRequest(0, accountEth), 0, "Pending request should be cleared");
        assertEq(vault.balanceOf(accountEth), userShares, "User should have original shares back");
        assertEq(vault.balanceOf(address(escrow)), 0, "Escrow should no longer hold shares");
    }

    function test_RevertWhen_CancelRedeemWithNoRequest() public {
        // Try to cancel when there's no request
        vm.prank(accountEth);
        vm.expectRevert(ISuperVault.REQUEST_NOT_FOUND.selector);
        vault.cancelRedeem(accountEth);
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetOperator() public {
        // Initially not an operator
        assertFalse(vault.isOperator(accountEth, operator), "Should not be operator initially");

        // Set operator directly
        vm.prank(accountEth);
        vault.setOperator(operator, true);

        // Verify operator was set
        assertTrue(vault.isOperator(accountEth, operator), "Should be operator after setting");

        // Revoke operator permission
        vm.prank(accountEth);
        vault.setOperator(operator, false);

        // Verify operator was revoked
        assertFalse(vault.isOperator(accountEth, operator), "Should not be operator after revoking");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface() public view {
        // Test ERC7540Redeem interface
        bytes4 erc7540RedeemId = type(IERC7540Redeem).interfaceId;
        assertTrue(vault.supportsInterface(erc7540RedeemId), "Should support ERC7540Redeem");

        // Test ERC7741 interface
        bytes4 erc7741Id = type(IERC7741).interfaceId;
        assertTrue(vault.supportsInterface(erc7741Id), "Should support ERC7741");

        // Test ERC4626 interface
        bytes4 erc4626Id = type(IERC4626).interfaceId;
        assertTrue(vault.supportsInterface(erc4626Id), "Should support ERC4626");

        // Test ERC165 interface
        bytes4 erc165Id = type(IERC165).interfaceId;
        assertTrue(vault.supportsInterface(erc165Id), "Should support ERC165");

        // Test non-supported interface
        bytes4 randomId = bytes4(keccak256("random"));
        assertFalse(vault.supportsInterface(randomId), "Should not support random interface");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTION COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ValidateOwnerOrOperator() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        _deposit(depositAmount);
        address randomAddress = address(0xABC);
        vm.prank(randomAddress);
        vm.expectRevert(ISuperVault.INVALID_OWNER_OR_OPERATOR.selector);
        vault.requestRedeem(100e6, accountEth, accountEth);
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGY INTERACTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintShares() public {
        uint256 mintAmount = 1000e6;
        uint256 initialEscrowBalance = vault.balanceOf(address(escrow));

        // Only the strategy can call this function
        vm.prank(address(strategy));
        vault.mintShares(mintAmount);

        // Verify shares were minted to escrow
        uint256 finalEscrowBalance = vault.balanceOf(address(escrow));
        assertEq(finalEscrowBalance, initialEscrowBalance + mintAmount, "Escrow balance should increase");
    }

    function test_RevertWhen_UnauthorizedMintShares() public {
        uint256 mintAmount = 1000e6;

        // Random address cannot call mintShares
        vm.prank(accountEth);
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.mintShares(mintAmount);
    }

    function test_BurnShares() public {
        // First mint some shares to escrow
        uint256 mintAmount = 1000e6;
        vm.prank(address(strategy));
        vault.mintShares(mintAmount);

        uint256 initialEscrowBalance = vault.balanceOf(address(escrow));

        // Only the strategy can call this function
        vm.prank(address(strategy));
        vault.burnShares(mintAmount);

        // Verify shares were burned from escrow
        uint256 finalEscrowBalance = vault.balanceOf(address(escrow));
        assertEq(finalEscrowBalance, initialEscrowBalance - mintAmount, "Escrow balance should decrease");
    }

    function test_RevertWhen_UnauthorizedBurnShares() public {
        uint256 burnAmount = 1000e6;

        // Random address cannot call burnShares
        vm.prank(accountEth);
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.burnShares(burnAmount);
    }

    function test_OnRedeemClaimable() public {
        // Setup mock values for testing
        address user = accountEth;
        uint256 assets = 100e6;
        uint256 shares = 100e6;
        uint256 averageWithdrawPrice = vault.PRECISION();
        uint256 accumulatorShares = 500e6;
        uint256 accumulatorCostBasis = 500e6;

        // Only the strategy can call this function
        vm.expectEmit(true, true, true, true);
        emit ISuperVault.RedeemClaimable(
            user, 0, assets, shares, averageWithdrawPrice, accumulatorShares, accumulatorCostBasis
        );

        vm.prank(address(strategy));
        vault.onRedeemClaimable(user, assets, shares, averageWithdrawPrice, accumulatorShares, accumulatorCostBasis);
    }

    function test_RevertWhen_UnauthorizedOnRedeemClaimable() public {
        // Random address cannot call onRedeemClaimable
        vm.prank(accountEth);
        uint256 precision = vault.PRECISION();
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.onRedeemClaimable(accountEth, 100e6, 100e6, precision, 500e6, 500e6);
    }

    /*//////////////////////////////////////////////////////////////
                       SUPERVAULTSTRATEGY.SOL
    //////////////////////////////////////////////////////////////*/

    function test_RequestRedeem_MultipleUsers(uint256 depositAmount) public executeWithoutHookRestrictions {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // perform deposit operations
        _completeDepositFlow(depositAmount);

        // request redeem for all users
        _requestRedeemForAllUsers(0);
    }

    function test_RequestRedeemMultipleUsers_With_CompleteFullfilment(uint256 depositAmount)
        public
        executeWithoutHookRestrictions
    {
        // bound amount
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // perform deposit operations
        _completeDepositFlow(depositAmount);

        uint256 totalRedeemShares;
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            uint256 vaultBalance = vault.balanceOf(accInstances[i].account);
            totalRedeemShares += vaultBalance;
        }

        // request redeem for all users
        _requestRedeemForAllUsers(0);

        // create fullfillment data
        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        // fulfill redeem
        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // check that all pending requests are cleared
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.claimableWithdraw(accInstances[i].account), 0);
        }
    }

    function test_RequestRedeem_MultipleUsers_DifferentAmounts() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6;

        // first deposit same amount for all users
        _completeDepositFlow(depositAmount);

        uint256[] memory redeemAmounts = new uint256[](ACCOUNT_COUNT);
        uint256 totalRedeemShares;

        // create redeem requests with randomized amounts based on vault balance
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 vaultBalance = vault.balanceOf(accInstances[i].account);
            // random amount between 50% and 100% of maxRedeemable
            redeemAmounts[i] =
                bound(uint256(keccak256(abi.encodePacked(block.timestamp, i))), vaultBalance / 2, vaultBalance);
            redeemAmounts[i] =
                bound(uint256(keccak256(abi.encodePacked(block.timestamp, i))), vaultBalance / 2, vaultBalance);
            _requestRedeemForAccount(accInstances[i], redeemAmounts[i]);
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemAmounts[i]);
            totalRedeemShares += redeemAmounts[i];
        }

        // fulfill all redeem requests
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 allocationAmountVault1 = totalRedeemShares / 2;
        uint256 allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        // verify all redeems were fulfilled
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.claimableWithdraw(accInstances[i].account), 0);
        }
    }

    function test_RequestRedeemMultipleUsers_With_PartialUsersFullfilment(uint256 depositAmount)
        public
        executeWithoutHookRestrictions
    {
        depositAmount = 100e6;

        // perform deposit operations
        _completeDepositFlow(depositAmount);

        // store redeem amounts for later verification
        uint256[] memory redeemAmounts = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            redeemAmounts[i] = vault.balanceOf(accInstances[i].account);
        }

        // request redeem for all users
        _requestRedeemForAllUsers(0);

        // create fulfillment data for half the users
        uint256 partialUsersCount = ACCOUNT_COUNT / 2;
        uint256 totalRedeemShares;

        // calculate total redeem shares for partial users
        for (uint256 i; i < partialUsersCount; ++i) {
            totalRedeemShares += strategy.pendingRedeemRequest(accInstances[i].account);
        }

        address[] memory requestingUsers = new address[](partialUsersCount);
        for (uint256 i; i < partialUsersCount; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        (uint256 allocationAmountVault1, uint256 allocationAmountVault2) = _calculateVaultShares(totalRedeemShares);

        // fulfill redeem for half the users
        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
        console2.log("fulfilled redeem for half the users");
        // check that fulfilled requests are cleared
        for (uint256 i; i < partialUsersCount; ++i) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.claimableWithdraw(accInstances[i].account), 0);
        }
        console2.log("checked that fulfilled requests are cleared");
        // check that remaining users still have pending requests
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT; ++i) {
            uint256 pendingRedeem = strategy.pendingRedeemRequest(accInstances[i].account);
            assertEq(pendingRedeem, redeemAmounts[i]);
            uint256 claimable = strategy.claimableWithdraw(accInstances[i].account);
            assertEq(claimable, 0);
        }

        // calculate total redeem shares for remaining users
        totalRedeemShares = 0;
        uint256 j;
        requestingUsers = new address[](ACCOUNT_COUNT - partialUsersCount);
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT;) {
            requestingUsers[j] = accInstances[i].account;
            totalRedeemShares += strategy.pendingRedeemRequest(accInstances[i].account);
            unchecked {
                ++i;
                ++j;
            }
        }

        allocationAmountVault1 = totalRedeemShares / 2;
        allocationAmountVault2 = totalRedeemShares - allocationAmountVault1;

        // fulfill remaining users
        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
    }

    function test_RequestRedeem_RevertOnExceedingBalance(uint256 depositAmount) public executeWithoutHookRestrictions {
        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        depositAmount = bound(depositAmount, 100e6, 10_000e6);

        // first deposit for single user
        _completeDepositFlow(depositAmount);

        // try to redeem more than balance
        uint256 vaultBalance = vault.balanceOf(accInstances[0].account);
        uint256 excessAmount = vaultBalance * 100;

        // should revert when trying to redeem more than balance
        _requestRedeemForAccount_Revert(accInstances[0], excessAmount);
    }

    function test_ClaimRedeem_RevertBeforeFulfillment() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);

        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;
        _requestRedeemForAccount(accInstances[0], redeemAmount);

        assertEq(strategy.pendingRedeemRequest(accInstances[0].account), redeemAmount);

        // try/catch pattern to verify the revert
        bool claimFailed = false;
        try this.externalClaimWithdraw(accInstances[0], redeemAmount) {
            claimFailed = false;
        } catch {
            claimFailed = true;
        }

        assertTrue(claimFailed, "Claim should have failed before fulfillment");

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        uint256 allocationAmountVault1 = redeemAmount / 2;
        uint256 allocationAmountVault2 = redeemAmount - allocationAmountVault1;

        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
        uint256 pendingRedeem = strategy.pendingRedeemRequest(accInstances[0].account);
        assertEq(pendingRedeem, 0);
        uint256 claimable = strategy.claimableWithdraw(accInstances[0].account);
        assertGt(claimable, 0);

        _claimWithdrawForAccount(accInstances[0], vault.maxWithdraw(accInstances[0].account));

        assertEq(strategy.claimableWithdraw(accInstances[0].account), 0);
    }

    function test_ClaimRedeem_AfterPriceIncrease() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);
        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        _requestRedeemForAccount(accInstances[0], redeemAmount);

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;

        uint256 allocationAmountVault1 = redeemAmount / 2;
        uint256 allocationAmountVault2 = redeemAmount - allocationAmountVault1;
        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );
        console2.log("------fulfilled redeem");
        uint256 initialAssetBalance = asset.balanceOf(accInstances[0].account);

        // increase price of assets
        uint256 yieldAmount = 100e6;
        deal(address(asset), address(this), yieldAmount * 2);
        asset.approve(address(fluidVault), yieldAmount);
        asset.approve(address(aaveVault), yieldAmount);
        fluidVault.deposit(yieldAmount, address(this));
        aaveVault.deposit(yieldAmount, address(this));

        uint256 strategyAssetBalanceBefore = asset.balanceOf(address(strategy));
        uint256 maxWithdraw = vault.maxWithdraw(accInstances[0].account);
        console2.log("maxWithdraw", maxWithdraw);
        _claimWithdrawForAccount(accInstances[0], maxWithdraw);
        console2.log("------claimed withdraw");
        uint256 assetsReceived = asset.balanceOf(accInstances[0].account) - initialAssetBalance;
        assertApproxEqRel(
            assetsReceived,
            maxWithdraw,
            0.01e18,
            "Assets received should be greater than or equal to requested redeem amount"
        );

        uint256 strategyAssetBalanceAfter = asset.balanceOf(address(strategy));
        assertApproxEqRel(
            strategyAssetBalanceBefore - strategyAssetBalanceAfter,
            assetsReceived,
            0.01e18,
            "Strategy asset balance should decrease by the amount sent to user"
        );

        assertApproxEqRel(
            strategyAssetBalanceBefore - strategyAssetBalanceAfter,
            assetsReceived,
            0.01e18,
            "Strategy asset balance should decrease by the amount sent to user"
        );

        console2.log("Requested redeem amount:", redeemAmount);
        console2.log("Actual assets received:", assetsReceived);
        console2.log("Strategy asset withdrawn", strategyAssetBalanceBefore - strategyAssetBalanceAfter);

        // make sure redeem is cleared even if we have small rounding errors
        assertEq(strategy.claimableWithdraw(accInstances[0].account), 0);
    }

    // Helper function to handle deposit setup
    function _setupInitialDeposit(uint256 depositAmount) internal returns (uint256 initialShareBalance) {
        // add some tokens initially to the strategy
        _getTokens(address(asset), address(strategy), 1000);

        _getTokens(address(asset), accInstances[0].account, depositAmount);
        _depositForAccount(accInstances[0], depositAmount);

        // Verify deposit was successful
        initialShareBalance = vault.balanceOf(accInstances[0].account);
        console2.log("Initial share balance after deposit:", initialShareBalance);
        console2.log("Initial asset value:", vault.convertToAssets(initialShareBalance));

        require(initialShareBalance > 0, "Deposit failed - no shares minted");
        return initialShareBalance;
    }

    // Helper function to calculate redeem amounts
    function _calculateRedeemAmounts(uint256 redeemAmount)
        internal
        view
        returns (uint256 firstHalf, uint256 secondHalf)
    {
        // Calculate total assets using vault's conversion
        uint256 totalAssets = vault.convertToAssets(redeemAmount);

        console2.log("Total assets to redeem:", totalAssets);

        // Split evenly, rounding down first half
        firstHalf = totalAssets / 2;
        secondHalf = totalAssets - firstHalf;

        console2.log("First half:", firstHalf);
        console2.log("Second half:", secondHalf);
    }

    struct RoundingTestVars {
        uint256 depositAmount;
        uint256 initialShareBalance;
        uint256 initialAssetBalance;
        uint256 initialStrategyBalance;
        uint256 redeemAmount;
        uint256 firstHalf;
        uint256 secondHalf;
        uint256 maxWithdraw;
        uint256 finalShareBalance;
        uint256 finalAssetBalance;
        uint256 finalStrategyBalance;
        uint256 assetsReceived;
        uint256 remainingShareValue;
    }

    function test_Redeem_RoundingBehavior() public executeWithoutHookRestrictions {
        RoundingTestVars memory vars;
        vars.depositAmount = 1000e6;

        _completeDepositFlow(vars.depositAmount);

        vars.initialShareBalance = vault.balanceOf(accInstances[0].account);
        vars.initialAssetBalance = asset.balanceOf(accInstances[0].account);

        console2.log("Initial shares:", vars.initialShareBalance);
        console2.log(
            "Initial price per share:",
            vault.totalAssets().mulDiv(vault.PRECISION(), vault.totalSupply(), Math.Rounding.Floor)
        );

        // Calculate redeem amount
        vars.redeemAmount = vars.initialShareBalance / 2;
        console2.log("Redeem amount (in shares):", vars.redeemAmount);

        _requestRedeemForAccount(accInstances[0], vars.redeemAmount);

        // Split redeem amount directly (don't convert to assets first)
        vars.firstHalf = vars.redeemAmount / 2;
        vars.secondHalf = vars.redeemAmount - vars.firstHalf;

        console2.log("First vault amount:", vars.firstHalf);
        console2.log("Second vault amount:", vars.secondHalf);

        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accInstances[0].account;
        _fulfillRedeemForUsers(
            requestingUsers, vars.firstHalf, vars.secondHalf, address(fluidVault), address(aaveVault)
        );

        vars.maxWithdraw = vault.maxWithdraw(accInstances[0].account);
        console2.log("maxWithdraw after fulfill:", vars.maxWithdraw);

        _claimWithdrawForAccount(accInstances[0], vars.maxWithdraw);

        vars.finalShareBalance = vault.balanceOf(accInstances[0].account);
        vars.finalAssetBalance = asset.balanceOf(accInstances[0].account);
        vars.assetsReceived = vars.finalAssetBalance - vars.initialAssetBalance;

        assertEq(vars.assetsReceived, vars.maxWithdraw, "Assets received should match maxWithdraw");
        assertApproxEqRel(
            vault.convertToAssets(vars.finalShareBalance), vars.depositAmount - vars.assetsReceived, 0.002e18
        );
    }

    function externalClaimWithdraw(AccountInstance memory accInst, uint256 assets) external {
        _claimWithdrawForAccount(accInst, assets);
    }

    function test_RequestRedeem_VerifyAmounts() public executeWithoutHookRestrictions {
        RedeemVerificationVars memory vars;
        vars.depositAmount = 1000e6;

        _completeDepositFlow(vars.depositAmount);

        vars.userShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            vars.userShareBalances[i] = vault.balanceOf(accInstances[i].account);
        }
        console2.log("pps", vault.totalAssets().mulDiv(vault.PRECISION(), vault.totalSupply(), Math.Rounding.Floor));

        console2.log("deposits done");
        /// redeem half of the shares
        vars.redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;
        console2.log("redeem amount:", vars.redeemAmount);

        console2.log("pps", vault.totalAssets().mulDiv(vault.PRECISION(), vault.totalSupply(), Math.Rounding.Floor));

        console2.log("deposits done");
        /// redeem half of the shares
        vars.redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;
        console2.log("redeem amount:", vars.redeemAmount);

        _requestRedeemForAllUsers(vars.redeemAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialStrategyAssetBalance = asset.balanceOf(address(strategy));

        vars.totalDepositAmount = vars.depositAmount * ACCOUNT_COUNT;
        vars.totalRedeemAmount = vars.redeemAmount * ACCOUNT_COUNT;

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        vars.allocationAmountVault1 = vars.totalRedeemAmount / 2;
        vars.allocationAmountVault2 = vars.totalRedeemAmount - vars.allocationAmountVault1;

        _fulfillRedeemForUsers(
            requestingUsers,
            vars.allocationAmountVault1,
            vars.allocationAmountVault2,
            address(fluidVault),
            address(aaveVault)
        );

        vars.fluidVaultSharesDecrease = vars.initialFluidVaultBalance - fluidVault.balanceOf(address(strategy));
        vars.aaveVaultSharesDecrease = vars.initialAaveVaultBalance - aaveVault.balanceOf(address(strategy));
        vars.strategyAssetBalanceIncrease = asset.balanceOf(address(strategy)) - vars.initialStrategyAssetBalance;

        vars.fluidVaultAssetsValue = fluidVault.convertToAssets(vars.fluidVaultSharesDecrease);
        vars.aaveVaultAssetsValue = aaveVault.convertToAssets(vars.aaveVaultSharesDecrease);

        vars.totalAssetsRedeemed = vars.fluidVaultAssetsValue + vars.aaveVaultAssetsValue;

        vars.totalRedeemedAssets = vault.convertToAssets(vars.totalRedeemAmount);
        assertApproxEqRel(vars.totalAssetsRedeemed, vars.totalRedeemedAssets, 0.01e18);

        assertApproxEqRel(vars.strategyAssetBalanceIncrease, vars.totalRedeemedAssets, 0.01e18);

        _verifyRedeemSharesAndAssets(vars);
    }

    function test_MultipleUsers_SameAllocation_EqualRedeemValue() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);

        uint256[] memory initialShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialShareBalances[i] = vault.balanceOf(accInstances[i].account);
            console2.log("User", i, "initial share balance:", initialShareBalances[i]);
        }
        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        // request redem
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            _requestRedeemForAccount(accInstances[i], redeemAmount);
        }

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalRedeemAmount = redeemAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalRedeemAmount / 2;
        uint256 allocationAmountVault2 = totalRedeemAmount - allocationAmountVault1;

        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        uint256[] memory initialAssetBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialAssetBalances[i] = asset.balanceOf(accInstances[i].account);
        }

        // Arrays to store results
        uint256[] memory assetsReceived = new uint256[](ACCOUNT_COUNT);
        uint256[] memory sharesBurned = new uint256[](ACCOUNT_COUNT);
        uint256[] memory assetPerShare = new uint256[](ACCOUNT_COUNT);

        // Claim redemptions for all users
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            // Record share balance before claiming
            uint256 shareBalanceBeforeClaim = vault.balanceOf(accInstances[i].account);
            console2.log("User", i, "share balance before claim:", shareBalanceBeforeClaim);

            uint256 maxWithdraw = vault.maxWithdraw(accInstances[i].account);
            _claimWithdrawForAccount(accInstances[i], maxWithdraw);

            uint256 shareBalanceAfterClaim = vault.balanceOf(accInstances[i].account);
            uint256 assetBalanceAfterClaim = asset.balanceOf(accInstances[i].account);

            console2.log("User", i, "share balance after claim:", shareBalanceAfterClaim);

            sharesBurned[i] = initialShareBalances[i] - shareBalanceAfterClaim;
            assetsReceived[i] = assetBalanceAfterClaim - initialAssetBalances[i];

            console2.log("User", i, "shares burned:", sharesBurned[i]);
            console2.log("User", i, "assets received:", assetsReceived[i]);

            if (sharesBurned[i] > 0) {
                assetPerShare[i] = assetsReceived[i] * vault.PRECISION() / sharesBurned[i];
                console2.log("User", i, "asset per share:", assetPerShare[i]);
            } else {
                console2.log("User", i, "!!! No shares were burned!");
            }

            assertGt(sharesBurned[i], 0, "No shares were burned for user");
            assertGt(assetsReceived[i], 0, "No assets were received for user");
        }

        for (uint256 i = 1; i < ACCOUNT_COUNT; i++) {
            assertApproxEqRel(assetPerShare[i], assetPerShare[0], 0.001e18, "Asset per share ratio should be equal");
            assertApproxEqRel(assetsReceived[i], assetsReceived[0], 0.001e18, "Assets received should be equal");
            assertApproxEqRel(sharesBurned[i], sharesBurned[0], 0.001e18, "Shares burned should be equal");
        }
    }

    function test_MultipleUsers_ChangingAllocation_RedeemValue() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6;

        _completeDepositFlow(depositAmount);

        uint256[] memory initialShareBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialShareBalances[i] = vault.balanceOf(accInstances[i].account);
        }

        uint256 redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            _requestRedeemForAccount(accInstances[i], redeemAmount);
        }
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        uint256 totalRedeemAmount = redeemAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalRedeemAmount * 90 / 100;
        uint256 allocationAmountVault2 = totalRedeemAmount - allocationAmountVault1;
        console2.log("Redeem allocation vault1:", allocationAmountVault1 * 100 / totalRedeemAmount, "%");
        console2.log("Redeem allocation vault2:", allocationAmountVault2 * 100 / totalRedeemAmount, "%");

        _fulfillRedeemForUsers(
            requestingUsers, allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault)
        );

        uint256[] memory initialAssetBalances = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialAssetBalances[i] = asset.balanceOf(accInstances[i].account);
        }

        uint256[] memory assetsReceived = new uint256[](ACCOUNT_COUNT);
        uint256[] memory sharesBurned = new uint256[](ACCOUNT_COUNT);
        uint256[] memory assetPerShare = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 maxWithdraw = vault.maxWithdraw(accInstances[i].account);
            _claimWithdrawForAccount(accInstances[i], maxWithdraw);

            uint256 shareBalanceAfterClaim = vault.balanceOf(accInstances[i].account);
            uint256 assetBalanceAfterClaim = asset.balanceOf(accInstances[i].account);

            sharesBurned[i] = initialShareBalances[i] - shareBalanceAfterClaim;
            assetsReceived[i] = assetBalanceAfterClaim - initialAssetBalances[i];

            if (sharesBurned[i] > 0) {
                assetPerShare[i] = assetsReceived[i] * vault.PRECISION() / sharesBurned[i];
            }

            assertGt(sharesBurned[i], 0, "No shares were burned for user");
            assertGt(assetsReceived[i], 0, "No assets were received for user");

            console2.log("User", i, "shares burned:", sharesBurned[i]);
            console2.log("User", i, "assets received:", assetsReceived[i]);
            console2.log("User", i, "asset per share:", assetPerShare[i]);
            console2.log("Free assets in vault", asset.balanceOf(address(strategy)));
        }

        for (uint256 i = 1; i < ACCOUNT_COUNT; i++) {
            assertApproxEqRel(assetPerShare[i], assetPerShare[0], 0.001e18, "Asset per share ratio should be equal");
            assertApproxEqRel(assetsReceived[i], assetsReceived[0], 0.001e18, "Assets received should be equal");
            assertApproxEqRel(sharesBurned[i], sharesBurned[0], 0.001e18, "Shares burned should be equal");
        }

        uint256 totalAssetsReceived = 0;
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            totalAssetsReceived += assetsReceived[i];
        }

        assertApproxEqRel(
            totalAssetsReceived, totalRedeemAmount, 0.01e18, "Total assets received should match total redeem amount"
        );
    }
    /*//////////////////////////////////////////////////////////////
                      GAS REPORT TESTS
    //////////////////////////////////////////////////////////////*/

    struct NewYieldSourceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialMockVaultBalance;
        uint256 initialPendleVaultBalance;
        uint256 amountToReallocateFluidVault;
        uint256 amountToReallocateAaveVault;
        uint256 assetAmountToReallocateFromFluidVault;
        uint256 assetAmountToReallocateFromAaveVault;
        uint256 assetAmountToReallocateToMockVault;
        uint256 assetAmountToReallocateToPendleVault;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalMockVaultBalance;
        uint256 finalPendleVaultBalance;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        IERC4626 newVault;
        address pendleVault;
        // Price per share tracking
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialPendleVaultPPS;
        uint256 initialMockVaultPPS;
    }

    function test_gasReport_RequestRedeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // First setup a deposit and claim it
        _deposit(depositAmount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));
        // Now request redeem of half the shares
        uint256 redeemShares = vault.balanceOf(accountEth) / 2;
        _requestRedeem(redeemShares);

        // Verify state
        assertEq(strategy.pendingRedeemRequest(accountEth), redeemShares, "Wrong pending redeem amount");
        assertEq(vault.balanceOf(address(escrow)), redeemShares, "Wrong escrow balance");
    }

    function test_gasReport_ClaimRedeem() public executeWithoutHookRestrictions {
        uint256 depositAmount = 1000e6; // 1000 USDC
        uint256 initialAssetBalance = asset.balanceOf(address(accountEth));

        // First setup a deposit and claim it
        _deposit(depositAmount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(depositAmount, address(fluidVault), address(aaveVault));
        // Get initial balances
        uint256 initialShares = vault.balanceOf(accountEth);

        console2.log("initial shares", initialShares);

        // Request redeem of half the shares
        uint256 redeemShares = initialShares / 2;
        _requestRedeem(redeemShares);
        _fulfillRedeem(redeemShares, address(fluidVault), address(aaveVault));

        // Get claimable assets
        uint256 claimableAssets = strategy.claimableWithdraw(accountEth);
        // Claim redeem
        _claimWithdraw(claimableAssets);

        // Verify state
        assertEq(vault.balanceOf(accountEth), initialShares - redeemShares, "Wrong final share balance");
        assertApproxEqRel(
            asset.balanceOf(accountEth), initialAssetBalance + claimableAssets, 0.05e18, "Wrong final asset balance"
        );
        assertEq(strategy.claimableWithdraw(accountEth), 0, "Assets not claimed");
    }

    function test_gasReport_TwoVaults_Fulfill() public executeWithoutHookRestrictions {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        _completeDepositFlow(vars.depositAmount);
    }

    function test_gasReport_ThreeVaults_Fulfill_And_Rebalance() public executeWithoutHookRestrictions {
        NewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(vault.PRECISION());
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(vault.PRECISION());

        // do an initial allo
        _completeDepositFlow(vars.depositAmount);

        // add new vault as yield source
        vars.newVault = IERC4626(0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9);

        // -- add it as a new yield source
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(vars.newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialPendleVaultBalance = IERC4626(vars.newVault).balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial PendleVault balance:", vars.initialPendleVaultBalance);

        // 30/30/40
        // allocate 20% from each vault to the new one
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        vars.amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        vars.assetAmountToReallocateToPendleVault =
            vars.assetAmountToReallocateFromFluidVault + vars.assetAmountToReallocateFromAaveVault;
        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);

        vm.warp(block.timestamp + 20 days);

        // allocation
        address withdrawHookAddress = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = withdrawHookAddress;
        hooksAddresses[2] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](3);
        // redeem from FluidVault
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false
        );
        // redeem from AaveVault
        hooksData[1] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false
        );
        // deposit to PendleVault
        hooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.newVault),
            address(asset),
            vars.assetAmountToReallocateToPendleVault,
            false,
            address(0),
            0
        );

        vm.startPrank(STRATEGIST);

        bytes[] memory argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);
        argsForProofs[2] = ISuperHookInspector(hooksAddresses[2]).inspect(hooksData[2]);

        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](3),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](3)
            })
        );
        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalPendleVaultBalance = vars.newVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final PendleVault balance:", vars.finalPendleVaultBalance);

        assertApproxEqRel(
            vars.finalFluidVaultBalance,
            vars.initialFluidVaultBalance - vars.amountToReallocateFluidVault,
            0.01e18,
            "FluidVault balance should decrease by the reallocated amount"
        );

        assertApproxEqRel(
            vars.finalAaveVaultBalance,
            vars.initialAaveVaultBalance - vars.amountToReallocateAaveVault,
            0.01e18,
            "AaveVault balance should decrease by the reallocated amount"
        );

        assertGt(vars.finalPendleVaultBalance, vars.initialPendleVaultBalance, "PendleVault balance should increase");

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.initialPendleVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + vars.newVault.convertToAssets(vars.finalPendleVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        // Enhanced checks for price per share and yield
        console2.log("\n=== Enhanced Vault Metrics ===");

        // Price per share comparison
        uint256 fluidVaultFinalPPS = fluidVault.convertToAssets(vault.PRECISION());
        uint256 aaveVaultFinalPPS = aaveVault.convertToAssets(vault.PRECISION());
        uint256 pendleVaultFinalPPS = vars.newVault.convertToAssets(vault.PRECISION());

        console2.log("\nPrice per Share Changes:");
        console2.log("Fluid Vault:");
        console2.log("  Initial PPS:", vars.initialFluidVaultPPS);
        console2.log("  Final PPS:", fluidVaultFinalPPS);
        console2.log(
            "  Change:",
            fluidVaultFinalPPS > vars.initialFluidVaultPPS ? "+" : "",
            fluidVaultFinalPPS - vars.initialFluidVaultPPS
        );
        console2.log(
            "  Change %:", ((fluidVaultFinalPPS - vars.initialFluidVaultPPS) * 10_000) / vars.initialFluidVaultPPS
        );

        console2.log("\nAave Vault:");
        console2.log("  Initial PPS:", vars.initialAaveVaultPPS);
        console2.log("  Final PPS:", aaveVaultFinalPPS);
        console2.log(
            "  Change:",
            aaveVaultFinalPPS > vars.initialAaveVaultPPS ? "+" : "",
            aaveVaultFinalPPS - vars.initialAaveVaultPPS
        );
        console2.log(
            "  Change %:", ((aaveVaultFinalPPS - vars.initialAaveVaultPPS) * 10_000) / vars.initialAaveVaultPPS
        );

        console2.log("\nYield Metrics:");
        uint256 totalYield =
            vars.finalTotalValue > vars.initialTotalValue ? vars.finalTotalValue - vars.initialTotalValue : 0;
        console2.log("Total Yield:", totalYield);
        console2.log("Yield %:", (totalYield * 10_000) / vars.initialTotalValue);

        assertGe(fluidVaultFinalPPS, vars.initialFluidVaultPPS, "Fluid Vault should not lose value");
        assertGe(aaveVaultFinalPPS, vars.initialAaveVaultPPS, "Aave Vault should not lose value");
        assertGe(pendleVaultFinalPPS, vault.PRECISION(), "Pendle Vault should not lose value");

        uint256 totalFinalBalance =
            vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalPendleVaultBalance;

        uint256 fluidRatio = (vars.finalFluidVaultBalance * 100) / totalFinalBalance;
        uint256 aaveRatio = (vars.finalAaveVaultBalance * 100) / totalFinalBalance;
        uint256 pendleRatio = (vars.finalPendleVaultBalance * 100) / totalFinalBalance;

        console2.log("\nFinal Allocation Ratios:");
        console2.log("Fluid Vault:", fluidRatio, "%");
        console2.log("Aave Vault:", aaveRatio, "%");
        console2.log("Pendle Vault:", pendleRatio, "%");
    }

    /*//////////////////////////////////////////////////////////////
                                E2E tests
    //////////////////////////////////////////////////////////////*/

    struct MultipleDepositsPartialRedemptionsVars {
        // Balances
        uint256 initialUserAssets;
        uint256 feeBalanceBefore;
        // Deposit amounts
        uint256 deposit1Amount;
        uint256 deposit2Amount;
        uint256 deposit3Amount;
        // Shares
        uint256 shares1;
        uint256 shares2;
        uint256 shares3;
        uint256 totalShares;
        // Redemption 1
        uint256 redeemAmount1;
        uint256 superformFee1;
        uint256 recipientFee1;
        uint256 totalFee1;
        uint256 userBalanceBeforeRedeem1;
        uint256 treasuryBalanceAfterRedeem1;
        uint256 claimableAssets1;
        uint256 userAssetsAfterRedeem1;
        // Redemption 2
        uint256 remainingShares;
        uint256 redeemAmount2;
        uint256 superformFee2;
        uint256 recipientFee2;
        uint256 totalFee2;
        uint256 userBalanceBeforeRedeem2;
        uint256 treasuryBalanceAfterRedeem2;
        uint256 claimableAssets2;
        uint256 userAssetsAfterRedeem2;
        // Redemption 3
        uint256 finalShares;
        uint256 superformFee3;
        uint256 recipientFee3;
        uint256 totalFee3;
        uint256 userBalanceBeforeRedeem3;
        uint256 treasuryBalanceAfterRedeem3;
        uint256 claimableAssets3;
        uint256 userAssetsAfterRedeem3;
        // Totals
        uint256 totalDeposits;
        uint256 totalFees;
        uint256 totalAssetsReceived;
    }

    function test_SuperVault_E2E_Flow_With_Ledger_Fees() public executeWithoutHookRestrictions {
        uint256 amount = 1000e6; // 1000 USDC

        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);
        uint256 initialVaultAssets = asset.balanceOf(address(vault));

        // Step 1: Request Deposit
        _deposit(amount);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth), initialUserAssets - amount, "User assets not reduced after deposit request"
        );
        assertEq(
            asset.balanceOf(address(strategy)),
            initialVaultAssets + amount,
            "Vault assets not increased after deposit request"
        );

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(amount, address(fluidVault), address(aaveVault));

        // Verify shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 50 weeks);

        console2.log("--pps before---", aggregator.getPPS(address(strategy)));

        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("--pps after---", aggregator.getPPS(address(strategy)));
        // Step 4: Request Redeem
        _requestRedeem(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(IERC20(vault.share()).balanceOf(address(escrow)), userShares, "Shares not transferred to escrow");

        console2.log("--pps before---", aggregator.getPPS(address(strategy)));
        vm.warp(block.timestamp + 6);
        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("--pps after---", aggregator.getPPS(address(strategy)));

        /*
        The impact of fee collection at super vault is that when calculating a fee in core, the user cannot "claim" the
            whole set of shares he had inscribed as historical shares
        Claims 999552226 shares instead of 1000000000 accumulated shares, where the diff is explained by the "assets"
            collected as fees by the strategist/superform in SuperVault
        For this reason, should we continue like this and assume this? Should we set a ledger configuration just for
            super vaults where the core fee on yield is 0 so the user is not double charged on performance?
        */
        (, uint256 superformFee, uint256 recipientFee) = strategy.previewPerformanceFee(accountEth, userShares);

        // Step 5: Fulfill Redeem
        _fulfillRedeem(userShares, address(fluidVault), address(aaveVault));

        // Calculate expected assets based on shares
        uint256 claimableAssets = vault.maxWithdraw(accountEth);
        uint256 claimableShares = vault.maxRedeem(accountEth);
        console2.log("claimableShares", claimableShares);

        uint256 expectedLedgerFee =
            superLedgerETH.previewFees(accountEth, address(vault), claimableAssets, claimableShares, 100);

        console2.log("expectedLedgerFee", expectedLedgerFee);
        console2.log("claimableAssets", claimableAssets);
        console2.log("getAverageWithdrawPrice", strategy.getAverageWithdrawPrice(accountEth));

        // Step 6: Claim Withdraw
        _claimWithdraw(claimableAssets);

        uint256 totalFeesTaken = superformFee + recipientFee + expectedLedgerFee;

        // Final balance assertions
        assertGt(asset.balanceOf(accountEth), preRedeemUserAssets, "User assets not increased after redeem");

        // Verify fee was taken
        _assertFeeDerivation(totalFeesTaken, feeBalanceBefore, asset.balanceOf(TREASURY));
    }

    function test_SuperVault_MultipleDeposits_PartialRedemptions() public executeWithoutHookRestrictions {
        vm.selectFork(FORKS[ETH]);

        MultipleDepositsPartialRedemptionsVars memory vars;

        // Record initial balances
        vars.initialUserAssets = asset.balanceOf(accountEth);
        vars.feeBalanceBefore = asset.balanceOf(TREASURY);

        // ========== DEPOSIT 1 ==========
        console2.log("===== DEPOSIT 1 =====");
        vars.deposit1Amount = 1000e6; // 1000 USDC

        // Step 1: Request first Deposit
        _deposit(vars.deposit1Amount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(vars.deposit1Amount, address(fluidVault), address(aaveVault));

        // Get shares minted to user for first deposit
        vars.shares1 = IERC20(vault.share()).balanceOf(accountEth);
        console2.log("Shares after deposit 1:", vars.shares1);

        // Simulate some yield accrual between deposits
        vm.warp(block.timestamp + 4 weeks);
        console2.log("--pps before---", aggregator.getPPS(address(strategy)));

        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("--pps after---", aggregator.getPPS(address(strategy)));
        // ========== DEPOSIT 2 ==========
        console2.log("===== DEPOSIT 2 =====");
        vars.deposit2Amount = 2000e6; // 2000 USDC

        // Deal more tokens to user
        deal(address(asset), accountEth, vars.deposit2Amount);

        // Step 1: Request second Deposit
        _deposit(vars.deposit2Amount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(vars.deposit2Amount, address(fluidVault), address(aaveVault));

        // Get additional shares minted to user
        vars.shares2 = IERC20(vault.share()).balanceOf(accountEth) - vars.shares1;
        console2.log("Shares after deposit 2:", vars.shares2);

        // Simulate more yield accrual between deposits
        vm.warp(block.timestamp + 4 weeks);
        console2.log("--pps before---", aggregator.getPPS(address(strategy)));

        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("--pps after---", aggregator.getPPS(address(strategy)));
        // ========== DEPOSIT 3 ==========
        console2.log("===== DEPOSIT 3 =====");
        vars.deposit3Amount = 3000e6; // 3000 USDC

        // Deal more tokens to user
        deal(address(asset), accountEth, vars.deposit3Amount);

        // Step 1: Request third Deposit
        _deposit(vars.deposit3Amount);

        // Need to allocate to yield sources before requesting redemption
        _depositFreeAssetsFromSingleAmount(vars.deposit3Amount, address(fluidVault), address(aaveVault));

        // Get additional shares minted to user
        vars.shares3 = IERC20(vault.share()).balanceOf(accountEth) - vars.shares1 - vars.shares2;
        console2.log("Shares after deposit 3:", vars.shares3);

        // Get total shares for user
        vars.totalShares = IERC20(vault.share()).balanceOf(accountEth);
        console2.log("Total shares:", vars.totalShares);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 42 weeks); // significant time for yield accrual

        console2.log("--pps before---", aggregator.getPPS(address(strategy)));

        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("--pps after---", aggregator.getPPS(address(strategy)));

        // ========== REDEMPTION 1 (25% of shares) ==========
        console2.log("===== REDEMPTION 1 (25%) =====");
        vars.redeemAmount1 = vars.totalShares / 4; // 25% of shares
        console2.log("Redeeming shares (25%):", vars.redeemAmount1);

        // Calculate expected fee for first redemption
        (, vars.superformFee1, vars.recipientFee1) = strategy.previewPerformanceFee(accountEth, vars.redeemAmount1);

        vars.treasuryBalanceAfterRedeem1 = vars.feeBalanceBefore;

        // Record asset balance before redemption
        vars.userBalanceBeforeRedeem1 = asset.balanceOf(accountEth);

        // Step 1: Request first Redeem
        _requestRedeem(vars.redeemAmount1);

        // Step 2: Fulfill first Redeem
        _fulfillRedeem(vars.redeemAmount1, address(fluidVault), address(aaveVault));

        // Step 3: Claim first Withdraw
        vars.claimableAssets1 = vault.maxWithdraw(accountEth);

        uint256 expectedLedgerFee = superLedgerETH.previewFees(
            accountEth, address(vault), vars.claimableAssets1, vault.maxRedeem(accountEth), 100
        );
        vars.totalFee1 = vars.superformFee1 + vars.recipientFee1 + expectedLedgerFee;
        console2.log("Expected fee for redemption 1:", vars.totalFee1);
        _claimWithdraw(vars.claimableAssets1);

        vars.treasuryBalanceAfterRedeem1 = asset.balanceOf(TREASURY);

        // Verify user received assets
        vars.userAssetsAfterRedeem1 = asset.balanceOf(accountEth) - vars.userBalanceBeforeRedeem1;
        console2.log("User received assets after redemption 1:", vars.userAssetsAfterRedeem1);

        // Verify fee was taken correctly
        _assertFeeDerivation(vars.totalFee1, vars.feeBalanceBefore, vars.treasuryBalanceAfterRedeem1);
        console2.log("Treasury balance after redemption 1:", vars.treasuryBalanceAfterRedeem1);

        // ========== REDEMPTION 2 (33% of remaining shares) ==========
        console2.log("===== REDEMPTION 2 (33% of remaining) =====");
        vars.remainingShares = IERC20(vault.share()).balanceOf(accountEth);
        vars.redeemAmount2 = vars.remainingShares / 3; // 33% of remaining shares
        console2.log("Redeeming shares (33% of remaining):", vars.redeemAmount2);

        // Calculate expected fee for second redemption
        (, vars.superformFee2, vars.recipientFee2) = strategy.previewPerformanceFee(accountEth, vars.redeemAmount2);

        // Record asset balance before redemption
        vars.userBalanceBeforeRedeem2 = asset.balanceOf(accountEth);

        // Step 1: Request second Redeem
        _requestRedeem(vars.redeemAmount2);

        // Step 2: Fulfill second Redeem
        _fulfillRedeem(vars.redeemAmount2, address(fluidVault), address(aaveVault));

        // Step 3: Claim second Withdraw
        vars.claimableAssets2 = vault.maxWithdraw(accountEth);

        expectedLedgerFee = superLedgerETH.previewFees(
            accountEth, address(vault), vars.claimableAssets2, vault.maxRedeem(accountEth), 100
        );
        vars.totalFee2 = vars.superformFee2 + vars.recipientFee2 + expectedLedgerFee;
        console2.log("Expected fee for redemption 2:", vars.totalFee2);

        _claimWithdraw(vars.claimableAssets2);

        vars.treasuryBalanceAfterRedeem2 = asset.balanceOf(TREASURY);

        // Verify user received assets
        vars.userAssetsAfterRedeem2 = asset.balanceOf(accountEth) - vars.userBalanceBeforeRedeem2;
        console2.log("User received assets after redemption 2:", vars.userAssetsAfterRedeem2);

        // Verify fee was taken correctly
        _assertFeeDerivation(vars.totalFee2, vars.treasuryBalanceAfterRedeem1, vars.treasuryBalanceAfterRedeem2);
        console2.log("Treasury balance after redemption 2:", vars.treasuryBalanceAfterRedeem2);

        // ========== REDEMPTION 3 (all remaining shares) ==========
        console2.log("===== REDEMPTION 3 (all remaining) =====");
        vars.finalShares = IERC20(vault.share()).balanceOf(accountEth);
        console2.log("Redeeming final shares:", vars.finalShares);

        // Calculate expected fee for third redemption
        (, vars.superformFee3, vars.recipientFee3) = strategy.previewPerformanceFee(accountEth, vars.finalShares);

        // Record asset balance before redemption
        vars.userBalanceBeforeRedeem3 = asset.balanceOf(accountEth);

        // Step 1: Request third Redeem
        _requestRedeem(vars.finalShares);

        // Step 2: Fulfill third Redeem
        _fulfillRedeem(vars.finalShares, address(fluidVault), address(aaveVault));

        // Step 3: Claim third Withdraw
        vars.claimableAssets3 = vault.maxWithdraw(accountEth);

        expectedLedgerFee = superLedgerETH.previewFees(
            accountEth, address(vault), vars.claimableAssets3, vault.maxRedeem(accountEth), 100
        );
        vars.totalFee3 = vars.superformFee3 + vars.recipientFee3 + expectedLedgerFee;
        console2.log("Expected fee for redemption 3:", vars.totalFee3);
        _claimWithdraw(vars.claimableAssets3);

        vars.treasuryBalanceAfterRedeem3 = asset.balanceOf(TREASURY);

        // Verify user received assets
        vars.userAssetsAfterRedeem3 = asset.balanceOf(accountEth) - vars.userBalanceBeforeRedeem3;
        console2.log("User received assets after redemption 3:", vars.userAssetsAfterRedeem3);

        // Verify fee was taken correctly
        _assertFeeDerivation(vars.totalFee3, vars.treasuryBalanceAfterRedeem2, vars.treasuryBalanceAfterRedeem3);

        // Verify total fee collection
        vars.totalFees = vars.totalFee1 + vars.totalFee2 + vars.totalFee3;
        console2.log("Total fees collected:", vars.totalFees);
        console2.log("Initial treasury balance:", vars.feeBalanceBefore);
        console2.log("Final treasury balance:", vars.treasuryBalanceAfterRedeem3);
        assertEq(
            vars.treasuryBalanceAfterRedeem3, vars.feeBalanceBefore + vars.totalFees, "Total fee collection mismatch"
        );

        // Verify user has received all assets minus fees
        vars.totalDeposits = vars.deposit1Amount + vars.deposit2Amount + vars.deposit3Amount;
        vars.totalAssetsReceived =
            vars.userAssetsAfterRedeem1 + vars.userAssetsAfterRedeem2 + vars.userAssetsAfterRedeem3;
        console2.log("Total deposits:", vars.totalDeposits);
        console2.log("Total assets received:", vars.totalAssetsReceived);
        assertGt(vars.totalAssetsReceived, vars.totalDeposits, "User should receive more than deposited due to yield");

        // Verify all shares are redeemed
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User should have no shares left");
    }

    /*//////////////////////////////////////////////////////////////
                       Vault Deployment test
    //////////////////////////////////////////////////////////////*/

    function test_DeployVault() public {
        // Deploy a new vault
        (address vaultAddr, address strategyAddr, address escrowAddr) = _deployVault(address(asset), "SV");
        // Verify addresses are not zero
        assertTrue(vaultAddr != address(0), "Vault address should not be zero");
        assertTrue(strategyAddr != address(0), "Strategy address should not be zero");
        assertTrue(escrowAddr != address(0), "Escrow address should not be zero");

        // Verify initialization
        SuperVault vaultContract = SuperVault(vaultAddr);
        ISuperVaultStrategy strategyContract = ISuperVaultStrategy(strategyAddr);
        SuperVaultEscrow escrowContract = SuperVaultEscrow(escrowAddr);

        // Check vault state
        assertEq(vaultContract.name(), "SuperVault", "Wrong vault name");
        assertEq(vaultContract.symbol(), "SV", "Wrong vault symbol");
        assertEq(vaultContract.asset(), address(asset), "Wrong asset");
        assertEq(address(vaultContract.strategy()), strategyAddr, "Wrong strategy");
        assertEq(vaultContract.decimals(), 6, "Wrong decimals");

        // Check strategy state
        (address _vaultAddr, address _asset, uint8 _decimals) = strategyContract.getVaultInfo();
        assertEq(strategyContract.isInitialized(), true, "Strategy not initialized");
        assertEq(_vaultAddr, vaultAddr, "Wrong vault in strategy");
        assertEq(_asset, address(asset), "Wrong asset in strategy");
        assertEq(_decimals, 6, "Wrong decimals in strategy");

        // Check escrow state
        assertTrue(escrowContract.initialized(), "Escrow not initialized");
        assertEq(escrowContract.vault(), vaultAddr, "Wrong vault in escrow");
        assertEq(escrowContract.strategy(), strategyAddr, "Wrong strategy in escrow");
    }

    function test_DeployMultipleVaults() public {
        // Deploy multiple vaults with different names/symbols
        string[3] memory symbols = ["sTV1", "sTV2", "sTV3"];

        for (uint256 i = 0; i < 3; i++) {
            // Deploy a new vault with custom configuration
            (address vaultAddr, address strategyAddr, address escrowAddr) = _deployVault(
                address(asset),
                symbols[i] // symbol
            );

            // Verify each vault is properly initialized
            SuperVault vaultContract = SuperVault(vaultAddr);
            assertEq(vaultContract.symbol(), symbols[i], "Wrong vault symbol");
            assertEq(vaultContract.decimals(), 6, "Wrong decimals");

            assertEq(ISuperVaultStrategy(strategyAddr).isInitialized(), true, "Strategy not initialized");

            assertTrue(SuperVaultEscrow(escrowAddr).initialized(), "Escrow not initialized");
        }
    }

    function test_RevertOnZeroAddresses() public {
        // Test with zero asset address
        vm.expectRevert(ISuperVaultAggregator.ZERO_ADDRESS.selector);
        _createVault(
            VaultCreationParams({
                asset: address(0),
                strategist: STRATEGIST,
                minUpdateInterval: 1000,
                maxStaleness: 10_000,
                performanceFeeBps: 1000,
                symbol: "TV"
            })
        );

        // Test with zero manager address (by temporarily setting SV_MANAGER to address(0))
        vm.expectRevert(ISuperVaultAggregator.ZERO_ADDRESS.selector);
        _createVault(
            VaultCreationParams({
                asset: address(asset),
                strategist: address(0),
                minUpdateInterval: 1000,
                maxStaleness: 10_000,
                performanceFeeBps: 1000,
                symbol: "TV"
            })
        );
    }

    struct VaultCreationParams {
        address asset;
        address strategist;
        uint256 minUpdateInterval;
        uint256 maxStaleness;
        uint256 performanceFeeBps;
        string symbol;
    }

    function _createVault(VaultCreationParams memory params)
        internal
        returns (address vaultAddr, address strategyAddr, address escrowAddr)
    {
        (vaultAddr, strategyAddr, escrowAddr) = aggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: params.asset,
                name: "SuperVault",
                symbol: params.symbol,
                mainStrategist: params.strategist,
                minUpdateInterval: params.minUpdateInterval,
                maxStaleness: params.maxStaleness,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: params.performanceFeeBps,
                    recipient: address(this)
                })
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                       STAKE CLAIM FLOW TEST
    //////////////////////////////////////////////////////////////*/

    function test_SuperVault_StakeClaimFlow() public {
        _setupGearVault();
        uint256 amount = 1000e6;
        uint256 initialUserAssets = asset.balanceOf(accountEth);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        _deposit(amount, address(gearboxVault), address(asset));

        // Step 2: Fulfill Deposit
        _depositFreeAssetsFromSingleAmount_Gearbox(amount);

        uint256 amountToStake = gearboxVault.balanceOf(address(strategyGearSuperVault));

        // Step 3: Execute Arbitrary Hooks
        _executeStakeHook(amountToStake);

        assertGt(
            gearboxFarmingPool.balanceOf(address(strategyGearSuperVault)),
            0,
            "Gearbox vault balance not increased after stake"
        );

        // Get shares minted to user
        uint256 userShares = IERC4626(gearSuperVault).balanceOf(accountEth);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 60 weeks);

        console2.log("ppsBeforeUnStake: ", aggregator.getPPS(address(strategyGearSuperVault)));

        uint256 preUnStakeGearboxBalance = gearboxVault.balanceOf(address(strategyGearSuperVault));

        uint256 amountToUnStake = gearboxFarmingPool.balanceOf(address(strategyGearSuperVault));

        _executeUnStakeHook(amountToUnStake);

        assertGt(
            gearboxVault.balanceOf(address(strategyGearSuperVault)),
            preUnStakeGearboxBalance,
            "Gearbox vault balance not decreased after unstake"
        );

        console2.log("ppsAfterUnStake: ", aggregator.getPPS(address(strategyGearSuperVault)));

        // Step 4: Request Redeem
        _requestRedeem(userShares, address(gearSuperVault));

        // Verify shares are escrowed
        assertEq(IERC20(gearSuperVault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(
            IERC20(gearSuperVault.share()).balanceOf(address(escrowGearSuperVault)),
            userShares,
            "Shares not transferred to escrow"
        );

        (uint256 recipientFee, uint256 superformFee) = _deriveSuperVaultFees(
            userShares, aggregator.getPPS(address(strategyGearSuperVault)), gearSuperVault.PRECISION()
        );

        // Step 5: Fulfill Redeem
        _fulfillRedeem_Gearbox_SV();

        uint256 totalFee = recipientFee + superformFee;
        console2.log("totalFee: ", totalFee);
        console2.log("feeBalanceBefore: ", feeBalanceBefore);
        console2.log("asset.balanceOf(TREASURY): ", asset.balanceOf(TREASURY));
        console2.log("recipientFee: ", recipientFee);
        console2.log("superformFee: ", superformFee);

        uint256 claimableAssets = gearSuperVault.maxWithdraw(accountEth);

        // Step 6: Claim Withdraw
        _claimWithdraw_Gearbox_SV(claimableAssets);

        _assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(TREASURY));

        assertEq(
            asset.balanceOf(accountEth),
            preRedeemUserAssets + claimableAssets,
            "User assets not increased after withdraw"
        );
        console2.log("ppsAfter: ", aggregator.getPPS(address(strategyGearSuperVault)));
    }

    function _setupGearVault() internal {
        // Deploy vault trio
        (address gearSuperVaultAddr, address strategyAddr, address escrowAddr) =
            _deployVault(address(asset), "svGearbox");

        vm.label(gearSuperVaultAddr, "GearSuperVault");
        vm.label(strategyAddr, "GearSuperVaultStrategy");
        vm.label(escrowAddr, "GearSuperVaultEscrow");

        // Cast addresses to contract types
        gearSuperVault = SuperVault(gearSuperVaultAddr);
        escrowGearSuperVault = SuperVaultEscrow(escrowAddr);
        strategyGearSuperVault = SuperVaultStrategy(strategyAddr);

        // Add a new yield source as manager
        strategyGearSuperVault.manageYieldSource(
            address(gearboxVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, false
        );
        strategyGearSuperVault.manageYieldSource(
            address(gearboxFarmingPool), _getContract(ETH, STAKING_YIELD_SOURCE_ORACLE_KEY), 0, false
        );
        vm.stopPrank();

        /*
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
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY)).proposeYieldSourceOracleConfig(
            configs
        );
        vm.warp(block.timestamp + 2 weeks);
        bytes4[] memory yieldSourceOracleIds = new bytes4[](1);
        yieldSourceOracleIds[0] = bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY))
            .acceptYieldSourceOracleConfigProposal(yieldSourceOracleIds);
        vm.stopPrank();
        */
    }

    function _depositFreeAssetsFromSingleAmount_Gearbox(uint256 depositAmount) internal {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](1);

        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxVault),
            address(asset),
            depositAmount,
            false,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = IERC4626(address(gearboxVault)).convertToShares(depositAmount);

        bytes[] memory argsForProofs = new bytes[](1);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
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
        uint256 shares = depositAmount.mulDiv(strategyGearSuperVault.PRECISION(), pricePerShare);

        _trackDeposit(accountEth, shares, depositAmount);
    }

    function _executeStakeHook(uint256 amountToStake) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndGearboxStakeHookData(
            bytes4(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxFarmingPool),
            address(gearboxVault),
            amountToStake,
            false
        );

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](1),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, hooksData),
                strategyProofs: new bytes32[][](1)
            })
        );
    }

    function _executeUnStakeHook(uint256 amountToUnStake) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, GEARBOX_UNSTAKE_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createGearboxUnstakeHookData(
            bytes4(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)), address(gearboxFarmingPool), amountToUnStake, false
        );

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](1),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, hooksData),
                strategyProofs: new bytes32[][](1)
            })
        );
    }

    function _fulfillRedeem_Gearbox_SV() internal {
        /// @dev with preserve percentages based on USD value allocation
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = withdrawHookAddress;

        uint256 shares = strategyGearSuperVault.pendingRedeemRequest(accountEth);

        bytes[] memory fulfillHooksData = new bytes[](1);
        fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxVault),
            address(gearboxVault),
            address(strategyGearSuperVault),
            shares,
            false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        uint256 assets = gearSuperVault.convertToAssets(shares);
        uint256 underlyingShares = gearboxVault.previewDeposit(assets);
        expectedAssetsOrSharesOut[0] = underlyingShares;

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, fulfillHooksData),
                strategyProofs: new bytes32[][](1)
            })
        );
        vm.stopPrank();
    }

    function _claimWithdraw_Gearbox_SV(uint256 assets) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createApproveAndWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), vault.share(), assets, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }
}
