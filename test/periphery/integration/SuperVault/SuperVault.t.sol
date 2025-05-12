// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

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
import { ISuperVault } from "src/periphery/interfaces/ISuperVault.sol";
import { IERC7540Redeem, IERC7741 } from "src/vendor/standards/ERC7540/IERC7540Vault.sol";

contract SuperVaultTest is BaseSuperVaultTest {
    using Math for uint256;

    address operator = address(0x123);
    uint256 constant userPrivateKey = 0xA11CE; // Replace with a known good testing private key
    address userAddress; // Will be derived from private key

    function setUp() public override {
        super.setUp();
        userAddress = vm.addr(userPrivateKey); // Derive the correct address from private key
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

    function test_MaxDeposit() public view {
        uint256 result = vault.maxDeposit(accountEth);

        // By default, should return the remaining cap
        (uint256 cap,) = strategy.getConfigInfo();
        uint256 currentAssets = vault.totalAssets();
        uint256 expectedMax = cap - currentAssets;

        // For a fresh vault, maxDeposit should be the full cap
        assertEq(result, expectedMax, "maxDeposit should return remaining cap");
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
        uint256 expectedShares = claimableAssets.mulDiv(1e18, avgWithdrawPrice, Math.Rounding.Ceil);

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

    function test_RevertWhen_ExceedingCap() public {
        // Lower the cap to a small value for testing
        uint256 lowCap = 500e6; // 500 USDC

        // Update cap to a small value
        vm.startPrank(STRATEGIST);
        strategy.updateSuperVaultCap(lowCap);
        vm.stopPrank();

        // This should pass (under cap)
        uint256 smallDeposit = 100e6; // 100 USDC
        _deposit(smallDeposit);

        // Try to deposit more than the cap
        uint256 largeDeposit = 1000e6; // 1000 USDC
        _getTokens(address(asset), accountEth, largeDeposit);

        vm.startPrank(accountEth);
        asset.approve(address(vault), largeDeposit);
        vm.expectRevert(ISuperVault.CAP_EXCEEDED.selector);
        vault.deposit(largeDeposit, accountEth);
        vm.stopPrank();
    }

    function test_InvalidSignatureLengths() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        // Create invalid signature (too short)
        bytes memory shortSignature = new bytes(64); // ERC7741 expects 65 bytes

        // Try to use invalid signature length
        vm.prank(operator);
        vm.expectRevert(ISuperVault.INVALID_SIGNATURE.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, shortSignature);
    }

    function test_InvalidSignatureRecovery() public {
        bool approved = true;
        bytes32 nonce = keccak256("test_nonce");
        uint256 deadline = block.timestamp + 1 hours;

        // Create proper length signature but with invalid recovery byte
        bytes32 r = bytes32(uint256(1));
        bytes32 s = bytes32(uint256(2));
        uint8 v = 26; // Invalid v value (not 27 or 28)
        bytes memory invalidSignature = abi.encodePacked(r, s, v);

        // Try to use invalid signature
        vm.prank(operator);
        vm.expectRevert(ISuperVault.INVALID_SIGNATURE.selector);
        vault.authorizeOperator(userAddress, operator, approved, nonce, deadline, invalidSignature);
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
        uint256 averageWithdrawPrice = 1e18;
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
        vm.expectRevert(ISuperVault.UNAUTHORIZED.selector);
        vault.onRedeemClaimable(accountEth, 100e6, 100e6, 1e18, 500e6, 500e6);
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

        // check that fulfilled requests are cleared
        for (uint256 i; i < partialUsersCount; ++i) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.claimableWithdraw(accInstances[i].account), 0);
        }

        // check that remaining users still have pending requests
        for (uint256 i = partialUsersCount; i < ACCOUNT_COUNT; ++i) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), redeemAmounts[i]);
            assertGt(strategy.claimableWithdraw(accInstances[i].account), 0);
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
            "Initial price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor)
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

        console2.log("Final shares:", vars.finalShareBalance);
        console2.log("Assets received:", vars.assetsReceived);

        /// @dev  -4 is the SuperLedger fee
        assertEq(vars.assetsReceived, vars.maxWithdraw - 4, "Assets received should match maxWithdraw");
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
        console2.log("pps", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        console2.log("deposits done");
        /// redeem half of the shares
        vars.redeemAmount = IERC20(vault).balanceOf(accInstances[0].account) / 2;
        console2.log("redeem amount:", vars.redeemAmount);

        console2.log("pps", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

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
                assetPerShare[i] = assetsReceived[i] * 1e18 / sharesBurned[i];
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
                assetPerShare[i] = assetsReceived[i] * 1e18 / sharesBurned[i];
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
}
