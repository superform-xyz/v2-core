// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// testing
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
// superform
import { ISuperVault } from "../../../../src/periphery/interfaces/SuperVault/ISuperVault.sol";
import { SuperVault } from "../../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultEscrow } from "../../../../src/periphery/SuperVault/SuperVaultEscrow.sol";
import { SuperVaultStrategy } from "../../../../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { ISuperVaultEscrow } from "../../../../src/periphery/interfaces/SuperVault/ISuperVaultEscrow.sol";
import { ISuperVaultAggregator } from "../../../../src/periphery/interfaces/SuperVault/ISuperVaultAggregator.sol";
import { IERC7540Redeem, IERC7741 } from "../../../../src/vendor/standards/ERC7540/IERC7540Vault.sol";
import { ISuperVaultStrategy } from "../../../../src/periphery/interfaces/SuperVault/ISuperVaultStrategy.sol";
import { ERC7540YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ISuperLedger } from "../../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperHookInspector } from "../../../../src/core/interfaces/ISuperHook.sol";
import { IGearboxFarmingPool } from "../../../../src/vendor/gearbox/IGearboxFarmingPool.sol";
import { ISuperExecutor } from "../../../../src/core/interfaces/ISuperExecutor.sol";
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { Mock4626Vault } from "../../../mocks/Mock4626Vault.sol";
import { RuggableVault } from "../../../mocks/RuggableVault.sol";
import { RuggableConvertVault } from "../../../mocks/RuggableConvertVault.sol";

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

    function test_Name_X() public view {
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

    function test_SuperVault_StakeClaimFlow() public executeWithoutHookRestrictions {
        _setupGearVault();
        uint256 amount = 1000e6;
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        console2.log("DEPOSITING");
        _deposit(amount, address(gearSuperVault), address(asset));

        console2.log("DEPOSITING FREE ASSETS");
        _depositFreeAssetsFromSingleAmount_Gearbox(amount);

        uint256 amountToStake = gearboxVault.balanceOf(address(strategyGearSuperVault));

        console2.log("STAKING");
        _executeStakeHook(amountToStake);

        assertGt(
            gearboxFarmingPool.balanceOf(address(strategyGearSuperVault)),
            0,
            "Gearbox vault balance not increased after stake"
        );

        // Get shares minted to user
        uint256 userShares = IERC4626(gearSuperVault).balanceOf(accountEth);

        // Record balances before redeem
        // uint256 preRedeemUserAssets = asset.balanceOf(accountEth);

        console2.log("update pps before 60 week warp");
        vm.warp(block.timestamp + 1 hours);

        _updateSuperVaultPPS(address(strategyGearSuperVault), address(gearSuperVault));

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 60 weeks);

        console2.log("update pps before 60 week warp");

        _updateSuperVaultPPS(address(strategyGearSuperVault), address(gearSuperVault));

        console2.log("ppsBeforeUnStake: ", aggregator.getPPS(address(strategyGearSuperVault)));

        uint256 preUnStakeGearboxBalance = gearboxVault.balanceOf(address(strategyGearSuperVault));

        uint256 amountToUnStake = gearboxFarmingPool.balanceOf(address(strategyGearSuperVault));

        _executeUnStakeHook(amountToUnStake);

        assertGt(
            gearboxVault.balanceOf(address(strategyGearSuperVault)),
            preUnStakeGearboxBalance,
            "Gearbox vault balance not decreased after unstake"
        );

        vm.warp(block.timestamp + 1 hours);

        _updateSuperVaultPPS(address(strategyGearSuperVault), address(gearSuperVault));

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
        vm.warp(block.timestamp + 1 hours);

        _updateSuperVaultPPS(address(strategyGearSuperVault), address(gearSuperVault));

        (, uint256 superformFee, uint256 recipientFee) =
            strategyGearSuperVault.previewPerformanceFee(accountEth, userShares);

        // Step 5: Fulfill Redeem
        _fulfillRedeem_Gearbox_SV();

        uint256 claimableAssets = gearSuperVault.maxWithdraw(accountEth);
        uint256 claimableShares = gearSuperVault.maxRedeem(accountEth);
        console2.log("claimableShares", claimableShares);

        uint256 expectedLedgerFee =
            superLedgerETH.previewFees(accountEth, address(gearSuperVault), claimableAssets, claimableShares, 100);

        uint256 totalFee = superformFee + recipientFee + expectedLedgerFee;
        console2.log("totalFee: ", totalFee);
        console2.log("feeBalanceBefore: ", feeBalanceBefore);
        console2.log("asset.balanceOf(TREASURY): ", asset.balanceOf(TREASURY));
        console2.log("recipientFee: ", recipientFee);
        console2.log("superformFee: ", superformFee);
        console2.log("expectedLedgerFee: ", expectedLedgerFee);

        // Step 6: Claim Withdraw
        _claimWithdraw_Gearbox_SV(claimableAssets);

        _assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(TREASURY));

        /*
        assertEq(
            asset.balanceOf(accountEth),
            preRedeemUserAssets +  claimableAssets ,
            "User assets not increased after withdraw"
        );
        */
        /// @dev commented the above as there are small deviations between what the user actually got and what were the
        /// claimable assets
        /// this is due to ledger fees in core
        console2.log("ppsAfter: ", aggregator.getPPS(address(strategyGearSuperVault)));
    }

    function _setupGearVault() internal {
        // Deploy vault trio
        (address gearSuperVaultAddr, address strategyAddr, address escrowAddr) =
            _deployVault(address(asset), "svGearbox");

        assertEq(strategyAddr, globalSVGearStrategy, "SV STRATEGY NOT EQUAL TO PREDICTED");

        vm.label(gearSuperVaultAddr, "GearSuperVault");
        vm.label(strategyAddr, "GearSuperVaultStrategy");
        vm.label(escrowAddr, "GearSuperVaultEscrow");

        // Cast addresses to contract types
        gearSuperVault = SuperVault(gearSuperVaultAddr);
        escrowGearSuperVault = SuperVaultEscrow(escrowAddr);
        strategyGearSuperVault = SuperVaultStrategy(strategyAddr);

        // Add a new yield source as manager
        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.manageYieldSource(
            address(gearboxVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, false
        );
        strategyGearSuperVault.manageYieldSource(
            address(gearboxFarmingPool), _getContract(ETH, STAKING_YIELD_SOURCE_ORACLE_KEY), 0, false
        );
        vm.stopPrank();

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.proposeVaultFeeConfigUpdate(100, TREASURY);
        vm.warp(block.timestamp + 1 weeks);
        strategyGearSuperVault.executeVaultFeeConfigUpdate();
        vm.stopPrank();
    }

    function _depositFreeAssetsFromSingleAmount_Gearbox(uint256 depositAmount) internal {
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = depositHookAddress;
        console2.log("GearSuperVault balance: ", asset.balanceOf(address(strategyGearSuperVault)));
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
                strategyProofs: new bytes32[][](1)
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

        bytes[] memory argsForProofs = new bytes[](1);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](1),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
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

        bytes[] memory argsForProofs = new bytes[](1);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](1),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
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
        bytes[] memory argsForProofs = new bytes[](1);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.fulfillRedeemRequests(
            ISuperVaultStrategy.FulfillArgs({
                controllers: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
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

    /*//////////////////////////////////////////////////////////////
                        ALLOCATE TESTS
    //////////////////////////////////////////////////////////////*/

    struct RebalanceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 totalAssets;
        uint256 targetFluidVaultAssets;
        uint256 targetAaveVaultAssets;
        uint256 currentFluidVaultAssets;
        uint256 currentAaveVaultAssets;
        uint256 assetsToMove;
        uint256 sharesToRedeem;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalFluidVaultAssets;
        uint256 finalAaveVaultAssets;
        uint256 finalTotalAssets;
        uint256 fluidVaultPercentage;
        uint256 aaveVaultPercentage;
        uint256 initialTotalValue;
    }

    function test_Allocate_Rebalance() public executeWithoutHookRestrictions {
        RebalanceVars memory vars;
        vars.depositAmount = 1000e6;

        //60/40 initial allo
        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        vars.totalAssets = vault.totalAssets();
        console2.log("vars.totalAssets", vars.totalAssets);
        vars.targetFluidVaultAssets = vars.totalAssets * 70 / 100;
        vars.targetAaveVaultAssets = vars.totalAssets * 30 / 100;
        console2.log("vars.targetFluidVaultAssets", vars.targetFluidVaultAssets);
        console2.log("vars.targetAaveVaultAssets", vars.targetAaveVaultAssets);

        vars.currentFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);
        vars.currentAaveVaultAssets = aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        console2.log("vars.currentFluidVaultAssets", vars.currentFluidVaultAssets);
        console2.log("vars.currentAaveVaultAssets", vars.currentAaveVaultAssets);

        console2.log("Current FluidVault assets:", vars.currentFluidVaultAssets);
        console2.log("Current AaveVault assets:", vars.currentAaveVaultAssets);
        console2.log("Target FluidVault assets:", vars.targetFluidVaultAssets);
        console2.log("Target AaveVault assets:", vars.targetAaveVaultAssets);

        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](2);

        // Determine which way to rebalance
        if (vars.currentFluidVaultAssets < vars.targetFluidVaultAssets) {
            _rebalanceFromAaveToFluid(vars, hooksAddresses, hooksData);
        } else {
            _rebalanceFromFluidToAave(vars, hooksAddresses, hooksData);
        }

        // final balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        vars.finalAaveVaultAssets = aaveVault.convertToAssets(vars.finalAaveVaultBalance);
        vars.finalTotalAssets = vars.finalFluidVaultAssets + vars.finalAaveVaultAssets;
        vars.fluidVaultPercentage = vars.finalFluidVaultAssets * 10_000 / vars.finalTotalAssets;
        vars.aaveVaultPercentage = vars.finalAaveVaultAssets * 10_000 / vars.finalTotalAssets;

        console2.log("Final FluidVault assets:", vars.finalFluidVaultAssets);
        console2.log("Final AaveVault assets:", vars.finalAaveVaultAssets);
        console2.log("Final FluidVault percentage:", vars.fluidVaultPercentage, "%");
        console2.log("Final AaveVault percentage:", vars.aaveVaultPercentage, "%");

        // checks
        assertApproxEqRel(vars.fluidVaultPercentage, 7000, 0.02e18, "FluidVault should have ~70% allocation");
        assertApproxEqRel(vars.aaveVaultPercentage, 3000, 0.02e18, "AaveVault should have ~30% allocation");

        // check total vcalue
        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalAssets, vars.initialTotalValue, 0.01e18, "Total value should be preserved during rebalancing"
        );
    }

    function test_Allocate_SmallAmounts() public executeWithoutHookRestrictions {
        RebalanceVars memory vars;
        vars.depositAmount = 5e5; //0.5 usd

        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);

        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        vars.currentFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);
        vars.currentAaveVaultAssets = aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.totalAssets = vars.currentFluidVaultAssets + vars.currentAaveVaultAssets;

        vars.targetFluidVaultAssets = (vars.totalAssets * 7000) / 10_000;
        vars.targetAaveVaultAssets = (vars.totalAssets * 3000) / 10_000;

        console2.log("Current FluidVault assets:", vars.currentFluidVaultAssets);
        console2.log("Target FluidVault assets:", vars.targetFluidVaultAssets);
        console2.log("Current AaveVault assets:", vars.currentAaveVaultAssets);
        console2.log("Target AaveVault assets:", vars.targetAaveVaultAssets);

        vm.startPrank(STRATEGIST);
        if (vars.currentFluidVaultAssets < vars.targetFluidVaultAssets) {
            _rebalanceFromAaveToFluid(vars, hooksAddresses, hooksData);
        } else {
            _rebalanceFromFluidToAave(vars, hooksAddresses, hooksData);
        }
        vm.stopPrank();

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        vars.finalAaveVaultAssets = aaveVault.convertToAssets(vars.finalAaveVaultBalance);
        vars.finalTotalAssets = vars.finalFluidVaultAssets + vars.finalAaveVaultAssets;
        vars.fluidVaultPercentage = (vars.finalFluidVaultAssets * 10_000) / vars.finalTotalAssets;
        vars.aaveVaultPercentage = (vars.finalAaveVaultAssets * 10_000) / vars.finalTotalAssets;

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("FluidVault percentage:", vars.fluidVaultPercentage);
        console2.log("AaveVault percentage:", vars.aaveVaultPercentage);

        assertApproxEqRel(
            vars.fluidVaultPercentage, 7000, 0.05e18, "FluidVault allocation should be ~70% even for small amounts"
        );
        assertApproxEqRel(
            vars.aaveVaultPercentage, 3000, 0.05e18, "AaveVault allocation should be ~30% even for small amounts"
        );

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalAssets,
            vars.initialTotalValue,
            0.02e18,
            "Total value should be preserved even with small amounts"
        );
    }

    function test_Allocate_LargeAmounts() public executeWithoutHookRestrictions {
        RebalanceVars memory vars;
        vars.depositAmount = 10_000_000e6; // 10M USD * 30

        _completeDepositFlow(vars.depositAmount);

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);

        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        vars.currentFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);
        vars.currentAaveVaultAssets = aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.totalAssets = vars.currentFluidVaultAssets + vars.currentAaveVaultAssets;

        vars.targetFluidVaultAssets = (vars.totalAssets * 7000) / 10_000;
        vars.targetAaveVaultAssets = (vars.totalAssets * 3000) / 10_000;

        console2.log("Current FluidVault assets:", vars.currentFluidVaultAssets);
        console2.log("Target FluidVault assets:", vars.targetFluidVaultAssets);
        console2.log("Current AaveVault assets:", vars.currentAaveVaultAssets);
        console2.log("Target AaveVault assets:", vars.targetAaveVaultAssets);

        vm.startPrank(STRATEGIST);
        if (vars.currentFluidVaultAssets < vars.targetFluidVaultAssets) {
            _rebalanceFromAaveToFluid(vars, hooksAddresses, hooksData);
        } else {
            _rebalanceFromFluidToAave(vars, hooksAddresses, hooksData);
        }
        vm.stopPrank();

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        vars.finalAaveVaultAssets = aaveVault.convertToAssets(vars.finalAaveVaultBalance);
        vars.finalTotalAssets = vars.finalFluidVaultAssets + vars.finalAaveVaultAssets;
        vars.fluidVaultPercentage = (vars.finalFluidVaultAssets * 10_000) / vars.finalTotalAssets;
        vars.aaveVaultPercentage = (vars.finalAaveVaultAssets * 10_000) / vars.finalTotalAssets;

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("FluidVault percentage:", vars.fluidVaultPercentage);
        console2.log("AaveVault percentage:", vars.aaveVaultPercentage);

        assertApproxEqRel(
            vars.fluidVaultPercentage, 7000, 0.01e18, "FluidVault allocation should be ~70% for large amounts"
        );
        assertApproxEqRel(
            vars.aaveVaultPercentage, 3000, 0.01e18, "AaveVault allocation should be ~30% for large amounts"
        );

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalAssets,
            vars.initialTotalValue,
            0.01e18,
            "Total value should be preserved even with large amounts"
        );
    }

    struct AllocateNewYieldSourceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialNewVaultBalance;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalNewVaultBalance;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
    }

    function test_Allocate_NewYieldSource() public executeWithoutHookRestrictions {
        AllocateNewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        // do an initial allo
        _completeDepositFlow(vars.depositAmount);
        IERC4626 newVault = IERC4626(CHAIN_1_EulerVault);

        //  -- add funds to the newVault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(address(newVault), type(uint256).max);
        newVault.deposit(2 * LARGE_DEPOSIT, address(this));

        // -- add it as a new yield source
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial NewVault balance:", vars.initialNewVaultBalance);

        // 30/30/40
        // allocate 20% from each vault to the new one
        uint256 amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        uint256 amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        uint256 assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(amountToReallocateFluidVault);
        uint256 assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(amountToReallocateAaveVault);
        uint256 assetAmountToReallocateToNewVault =
            assetAmountToReallocateFromFluidVault + assetAmountToReallocateFromAaveVault;
        console2.log("Asset amount to reallocate from FluidVault:", assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", assetAmountToReallocateFromAaveVault);

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
            amountToReallocateFluidVault,
            false
        );
        // redeem from AaveVault
        hooksData[1] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            amountToReallocateAaveVault,
            false
        );
        // deposit to NewVault
        hooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(newVault),
            address(asset),
            assetAmountToReallocateToNewVault,
            false,
            address(0),
            0
        );
        bytes[] memory argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);
        argsForProofs[2] = ISuperHookInspector(hooksAddresses[2]).inspect(hooksData[2]);

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](3),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final NewVault balance:", vars.finalNewVaultBalance);

        assertApproxEqRel(
            vars.finalFluidVaultBalance,
            vars.initialFluidVaultBalance - amountToReallocateFluidVault,
            0.01e18,
            "FluidVault balance should decrease by the reallocated amount"
        );

        assertApproxEqRel(
            vars.finalAaveVaultBalance,
            vars.initialAaveVaultBalance - amountToReallocateAaveVault,
            0.01e18,
            "AaveVault balance should decrease by the reallocated amount"
        );

        assertGt(vars.finalNewVaultBalance, vars.initialNewVaultBalance, "NewVault balance should increase");

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + newVault.convertToAssets(vars.initialNewVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance) + newVault.convertToAssets(vars.finalNewVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );
    }

    function _rebalanceFromAaveToFluid(
        RebalanceVars memory vars,
        address[] memory hooksAddresses,
        bytes[] memory hooksData
    )
        private
    {
        _rebalanceFromVaultToVault(
            hooksAddresses,
            hooksData,
            address(aaveVault),
            address(fluidVault),
            vars.targetFluidVaultAssets,
            vars.currentFluidVaultAssets
        );
    }

    function _rebalanceFromFluidToAave(
        RebalanceVars memory vars,
        address[] memory hooksAddresses,
        bytes[] memory hooksData
    )
        private
    {
        _rebalanceFromVaultToVault(
            hooksAddresses,
            hooksData,
            address(fluidVault),
            address(aaveVault),
            vars.targetAaveVaultAssets,
            vars.currentAaveVaultAssets
        );
    }
    /*//////////////////////////////////////////////////////////////
                        SCENARIO TESTS
    //////////////////////////////////////////////////////////////*/

    struct MultipleOperationsVars {
        uint256 seed;
        uint256[] depositAmounts;
        address[] redeemUsers;
        uint256[] redeemAmounts;
        bool[] selected;
        uint256 selectedCount;
        uint256 totalRedeemShares;
        uint256 redeemSharesVault1;
        uint256 redeemSharesVault2;
        uint256 initialTimestamp;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
    }

    struct FinalBalanceVerificationVars {
        // Global vault state
        uint256 finalTotalAssets;
        uint256 finalTotalSupply;
        uint256 finalPricePerShare;
        uint256 totalValueLocked;
        // Strategy state
        uint256 fluidBalance;
        uint256 aaveBalance;
        // Escrow state
        uint256 escrowBalance;
        // Yield tracking
        uint256 totalYieldAccrued;
        uint256 yieldPerShare;
        // User accounting
        uint256 totalUserShares;
        uint256 totalUserAssets;
        uint256 totalPendingDeposits;
        uint256 totalPendingRedeems;
        // Per-user state
        uint256 currentShares;
        uint256 currentAssets;
        uint256 expectedShares;
        uint256 expectedAssets;
        uint256 userYieldAccrued;
        bool isRedeemer;
        uint256 redeemedShares;
    }

    struct ScenarioNewYieldSourceVars {
        uint256 depositAmount;
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialNewVaultBalance;
        uint256 amountToReallocateFluidVault;
        uint256 amountToReallocateAaveVault;
        uint256 assetAmountToReallocateFromFluidVault;
        uint256 assetAmountToReallocateFromAaveVault;
        uint256 assetAmountToReallocateToNewVault;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalNewVaultBalance;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        // Price per share tracking
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
    }

    struct VaultLifecycleVars {
        uint256[] userDepositAmounts;
        address[] users;
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        uint256[] userInitialShares;
        uint256[] userInitialAssets;
        uint256[] userFinalShares;
        uint256[] userFinalAssets;
        uint256[] userYields;
    }

    struct RugTestVarsDeposit {
        uint256 depositAmount;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
        uint256 rugPercentage;
        address[] depositUsers;
        uint256[] depositAmounts;
        uint256 initialTimestamp;
        RuggableVault ruggableVault;
    }

    struct RugTestVarsWithdraw {
        bool convertVault;
        uint256 depositAmount;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
        uint256 rugPercentage;
        address[] depositUsers;
        uint256[] depositAmounts;
        address[] redeemUsers;
        uint256[] redeemAmounts;
        uint256 totalRedeemShares;
        uint256 redeemSharesVault1;
        uint256 redeemSharesVault2;
        uint256 initialTimestamp;
        address ruggableVault;
        uint256 initialRuggableVaultBalance;
        uint256 initialFluidVaultBalance;
        uint256 initialRuggableVaultAssets;
        uint256 initialFluidVaultAssets;
        uint256 amountToReallocate;
        uint256 assetAmountToReallocate;
        uint256 finalRuggableVaultBalance;
        uint256 finalFluidVaultBalance;
        uint256 finalRuggableVaultAssets;
        uint256 finalFluidVaultAssets;
        uint256 initialTotalValue;
        uint256 finalTotalValue;
        uint256 vaultTotalAssetsAfterAllocation;
        uint256 pricePerShareAfterAllocation;
        uint256 ppsBeforeWarp;
        uint256 ppsAfterWarp;
        uint256[] expectedAssetsOrSharesOut;
        uint256 assetsVault1;
        uint256 assetsVault2;
        // Added to avoid stack too deep errors
        uint256 finalTotalAssets;
        uint256 finalTotalSupply;
        uint256 totalAssetsPreClaimTaintedAssets;
        uint256 totalSupplyPreClaimTaintedAssets;
        uint256 pricePerSharePreClaimTaintedAssets;
    }

    struct VaultCapTestVars {
        address withdrawHookAddress;
        address depositHookAddress;
        address[] hooksAddresses;
        bytes[] hooksData;
        // Initial setup
        uint256 depositAmount;
        uint256 initialFluidVaultPPS;
        uint256 initialAaveVaultPPS;
        uint256 totalInitialBalance;
        uint256 initialFluidRatio;
        uint256 initialAaveRatio;
        uint256 initialEulerRatio;
        // Vault balances
        uint256 initialFluidVaultBalance;
        uint256 initialAaveVaultBalance;
        uint256 initialEulerVaultBalance;
        // First reallocation (50/25/25)
        uint256 assetsToMove;
        uint256 finalFluidVaultBalance;
        uint256 finalAaveVaultBalance;
        uint256 finalEulerVaultBalance;
        uint256 totalFinalBalance;
        uint256 finalFluidRatio;
        uint256 finalAaveRatio;
        uint256 finalEulerRatio;
        // Second reallocation (40/30/30)
        uint256 newVaultCap;
        uint256 targetFluidAssets2;
        uint256 targetAaveAssets2;
        uint256 targetEulerAssets2;
        uint256 finalFluidVaultBalance2;
        uint256 finalAaveVaultBalance2;
        uint256 finalEulerVaultBalance2;
        uint256 finalFluidRatio2;
        uint256 finalAaveRatio2;
        uint256 finalEulerRatio2;
        uint256 finalTotalValue;
        // misc
        uint256 newSuperVaultCap;
    }

    struct TestVars {
        uint256 initialTimestamp;
        uint256 totalDeposited;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
        uint256 finalTotalAssets;
        uint256 finalTotalSupply;
        uint256 finalPricePerShare;
        uint256 fluidVaultBalance;
        uint256 aaveVaultBalance;
        uint256[] depositAmounts;
        address[] depositUsers;
    }

    struct YieldTestVars {
        uint256 depositAmount;
        uint256 initialTimestamp;
        Mock4626Vault vault1; // 3% yield
        Mock4626Vault vault2; // 5% yield
        Mock4626Vault vault3; // 10% yield
        uint256 initialVault1Balance;
        uint256 initialVault2Balance;
        uint256 initialVault3Balance;
        uint256 initialVault1Assets;
        uint256 initialVault2Assets;
        uint256 initialVault3Assets;
        uint256 finalVault1Assets;
        uint256 finalVault2Assets;
        uint256 finalVault3Assets;
        uint256 initialTotalAssets;
        uint256 initialTotalSupply;
        uint256 initialPricePerShare;
    }

    function test_1_DynamicAllocation() public executeWithoutHookRestrictions {
        ScenarioNewYieldSourceVars memory vars;
        vars.depositAmount = 100e6;

        Mock4626Vault newVault = new Mock4626Vault(address(asset), "New Vault", "NV");
        _updateAndRegenerateMerkleTree("test_1Mock4626Vault", address(newVault), ETH);

        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(address(newVault), type(uint256).max);
        newVault.deposit(2 * LARGE_DEPOSIT, address(this));

        // warp before adding a new vault;
        vm.warp(block.timestamp + 20 days);

        // -- add it as a new yield source
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // warp again
        vm.warp(block.timestamp + 20 days);

        // create deposit requests for all users
        _depositForAllUsers(vars.depositAmount);

        // create fullfillment data
        uint256 totalAmount = vars.depositAmount * ACCOUNT_COUNT;
        uint256 allocationAmountVault1 = totalAmount * 40 / 100;
        uint256 allocationAmountVault2 = totalAmount * 30 / 100;
        uint256 allocationAmountVault3 = totalAmount * 30 / 100;

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        // fulfill deposits
        _depositFreeAssets(
            address(fluidVault),
            address(aaveVault),
            address(newVault),
            allocationAmountVault1,
            allocationAmountVault2,
            allocationAmountVault3
        );

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial NewVault balance:", vars.initialNewVaultBalance);

        _test_1_performReallocation(vars, newVault);

        console2.log("\n=== Enhanced Vault Metrics ===");
        uint256 fluidVaultFinalPPS = fluidVault.convertToAssets(1e18);
        uint256 aaveVaultFinalPPS = aaveVault.convertToAssets(1e18);
        uint256 newVaultFinalPPS = newVault.convertToAssets(1e18);

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
        assertGe(newVaultFinalPPS, 1e18, "NewVault should not lose value");

        uint256 totalFinalBalance = vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalNewVaultBalance;
        uint256 fluidRatio = (vars.finalFluidVaultBalance * 100) / totalFinalBalance;
        uint256 aaveRatio = (vars.finalAaveVaultBalance * 100) / totalFinalBalance;
        uint256 newRatio = (vars.finalNewVaultBalance * 100) / totalFinalBalance;

        console2.log("\nFinal Allocation Ratios:");
        console2.log("Fluid Vault:", fluidRatio, "%");
        console2.log("Aave Vault:", aaveRatio, "%");
        console2.log("NewVault:", newRatio, "%");
    }

    function _test_1_performReallocation(ScenarioNewYieldSourceVars memory vars, Mock4626Vault newVault) private {
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        vars.amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        vars.assetAmountToReallocateToNewVault =
            vars.assetAmountToReallocateFromFluidVault + vars.assetAmountToReallocateFromAaveVault;

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);
        console2.log("Asset amount to reallocate from MocmVault:", vars.assetAmountToReallocateToNewVault);

        address withdrawHookAddress = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](3);
        bytes[] memory hooksData = new bytes[](3);

        // Setup hooks
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = withdrawHookAddress;
        hooksAddresses[2] = depositHookAddress;

        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false
        );

        hooksData[1] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false
        );

        hooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(newVault),
            address(asset),
            vars.assetAmountToReallocateToNewVault,
            false,
            address(0),
            0
        );

        bytes[] memory argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);
        argsForProofs[2] = ISuperHookInspector(hooksAddresses[2]).inspect(hooksData[2]);

        // Perform allocation
        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](3),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](3)
            })
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 20 days);

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("NewVault balance:", vars.finalNewVaultBalance);

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + newVault.convertToAssets(vars.initialNewVaultBalance);
        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance) + newVault.convertToAssets(vars.finalNewVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total value should be preserved during allocation - after first reallocation"
        );

        // Verify balance changes
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

        assertGt(vars.finalNewVaultBalance, vars.initialNewVaultBalance, "NewVault balance should increase");

        vars.initialNewVaultBalance = newVault.balanceOf(address(strategy));
        vars.assetAmountToReallocateToNewVault = newVault.convertToAssets(vars.initialNewVaultBalance);
        vars.assetAmountToReallocateFromFluidVault = vars.assetAmountToReallocateToNewVault * 30 / 100;
        vars.assetAmountToReallocateFromAaveVault =
            vars.initialNewVaultBalance - vars.assetAmountToReallocateFromFluidVault; // the rest goes here

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);
        console2.log("Asset amount to reallocate from MocmVault:", vars.assetAmountToReallocateToNewVault);

        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;
        hooksAddresses[2] = depositHookAddress;

        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(newVault),
            address(strategy),
            vars.assetAmountToReallocateToNewVault,
            false
        );

        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(asset),
            vars.assetAmountToReallocateFromFluidVault,
            false,
            address(0),
            0
        );

        hooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(asset),
            vars.assetAmountToReallocateFromAaveVault,
            false,
            address(0),
            0
        );
        argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);
        argsForProofs[2] = ISuperHookInspector(hooksAddresses[2]).inspect(hooksData[2]);

        // Perform allocation
        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](3),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](3)
            })
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 20 days);

        _updateSuperVaultPPS(address(strategy), address(vault));

        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("NewVault balance:", vars.finalNewVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance) + newVault.convertToAssets(vars.finalNewVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total value should be preserved during allocation - after second reallocation"
        );
    }

    function test_2_MultipleOperations_RandomAmounts(uint256 seed) public executeWithoutHookRestrictions {
        MultipleOperationsVars memory vars;
        // Setup random seed and initial timestamp
        vars.initialTimestamp = block.timestamp;
        vars.seed = seed;
        // Generate random deposit amounts for all users (20 users)
        vars.depositAmounts = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            // Use the seed to generate random amounts
            // 50% chance for large amount (1M-2M), 50% chance for small amount (100-1000)
            uint256 rand = uint256(keccak256(abi.encodePacked(vars.seed, i)));
            if (rand % 2 == 0) {
                // Large amount: 1M-2M USDC
                vars.depositAmounts[i] = 1_000_000e6 + (rand % 1_000_000e6);
            } else {
                // Small amount: 100-1000 USDC
                vars.depositAmounts[i] = 100e6 + (rand % 900e6);
            }
        }

        _completeDepositFlowWithVaryingAmounts(vars.depositAmounts);

        _updateSuperVaultPPS(address(strategy), address(vault));

        // Store initial state for yield verification
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        //vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Verify initial balances and shares
        _verifyInitialBalances(vars.depositAmounts);

        // Simulate time passing (1 day) to accumulate some yield
        vm.warp(vars.initialTimestamp + 1 days);
        console2.log("\n=== After 1 day ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Setup redemption arrays
        vars.redeemUsers = new address[](15);
        vars.redeemAmounts = new uint256[](15);
        vars.selected = new bool[](ACCOUNT_COUNT);

        // Select random users for redemption
        vars = _selectRandomUsersForRedemption(vars);

        // Simulate some more time passing (12 days) before redemption requests
        vm.warp(vars.initialTimestamp + 10 days);
        _updateSuperVaultPPS(address(strategy), address(vault));
        vars.initialPricePerShare = strategy.getStoredPPS();
        console2.log("\n=== After 10 days ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Request redemptions
        _processRedemptionRequests(vars);

        // Calculate total redemption amount for allocation
        for (uint256 i; i < 15; i++) {
            vars.totalRedeemShares += vars.redeemAmounts[i];
        }

        // Simulate time passing (6 hours) before fulfilling redemptions
        vm.warp(vars.initialTimestamp + 10 days + 6 hours);
        console2.log("\n=== After 10 days and 6 hours ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Fulfill redemptions
        vars.redeemSharesVault1 = vars.totalRedeemShares / 2;
        vars.redeemSharesVault2 = vars.totalRedeemShares - vars.redeemSharesVault1;
        _fulfillRedeemForUsers(
            vars.redeemUsers, vars.redeemSharesVault1, vars.redeemSharesVault2, address(fluidVault), address(aaveVault)
        );
        
        // Simulate final time passing before final verification
        vm.warp(vars.initialTimestamp + 11 days);
        // Process claims for redeemed users
        _claimRedeemForUsers(vars.redeemUsers);

        console2.log("\n=== After 11 days ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", vault.totalAssets().mulDiv(1e18, vault.totalSupply(), Math.Rounding.Floor));

        // Verify final balances and shares
        _verifyFinalBalances(vars);
    }

    function test_3_UnderlyingVaults_StressTest() public {
        RugTestVarsWithdraw memory vars;

        // A vault that is rugged on deposit and on withdraw; 10% rug
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 10;
        vars.initialTimestamp = block.timestamp;

        vars.ruggableVault = address(
            new RuggableVault(
                IERC20(address(asset)),
                "Ruggable Vault",
                "RUG",
                true, // rug on deposit
                true, // rug on withdraw
                vars.rugPercentage
            )
        );

        _updateAndRegenerateMerkleTree("RuggableVault", vars.ruggableVault, ETH);

        vm.label(vars.ruggableVault, "Ruggable Vault");
        vm.label(address(fluidVault), "Fluid Vault");

        console2.log("ruggable vault", vars.ruggableVault);
        console2.log("fluid vault", address(fluidVault));

        // add some funds to the vault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(address(vars.ruggableVault), type(uint256).max);
        RuggableVault(vars.ruggableVault).deposit(2 * LARGE_DEPOSIT, address(this));

        // create SV with fluid and this ruggable vault
        _deployNewSuperVaultWithRuggableVault(address(vars.ruggableVault));

        // users to deposit and withdraw
        vars.depositUsers = new address[](2);
        vars.depositAmounts = new uint256[](2);

        for (uint256 i; i < 2; ++i) {
            vars.depositUsers[i] = accInstances[i].account;
            vars.depositAmounts[i] = vars.depositAmount;
        }

        // perform deposit operations
        for (uint256 i; i < 2; ++i) {
            _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
            vm.startPrank(vars.depositUsers[i]);
            asset.approve(address(vault), vars.depositAmounts[i]);
            vault.deposit(vars.depositAmounts[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        vm.warp(vars.initialTimestamp + 1 days);

        uint256 totalAmount = vars.depositAmount * 2;
        uint256 allocationAmountVault1 = totalAmount / 2;
        uint256 allocationAmountVault2 = totalAmount - allocationAmountVault1;

        // put 50-50 in each vault
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = fluidVault.previewDeposit(allocationAmountVault1);
        expectedAssetsOrSharesOut[1] = IERC4626(vars.ruggableVault).previewDeposit(allocationAmountVault2);

        _depositFreeAssets(
            allocationAmountVault1,
            allocationAmountVault2,
            address(fluidVault),
            address(vars.ruggableVault),
            expectedAssetsOrSharesOut,
            bytes4(0)
        );
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", RuggableVault(vars.ruggableVault).balanceOf(address(strategy)));

        vm.warp(block.timestamp + 12 weeks);

        uint256 prevPps = vars.initialPricePerShare;
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", RuggableVault(vars.ruggableVault).balanceOf(address(strategy)));

        assertApproxEqRel(vars.initialPricePerShare, prevPps, 0.1e18, "Price per share should be preserved");

        // redeem from 1 user
        vars.redeemUsers = new address[](1);
        vars.redeemAmounts = new uint256[](1);
        vars.totalRedeemShares = 0;

        vars.redeemUsers[0] = vars.depositUsers[0];
        vars.redeemAmounts[0] = vault.balanceOf(vars.redeemUsers[0]);
        assertGt(vars.redeemAmounts[0], 0, "Redeem amount should be greater than 0");
        vars.totalRedeemShares += vars.redeemAmounts[0];

        vm.startPrank(vars.redeemUsers[0]);
        vault.requestRedeem(vars.redeemAmounts[0], vars.redeemUsers[0], vars.redeemUsers[0]);
        vm.stopPrank();

        vars.redeemSharesVault1 = vars.totalRedeemShares / 2;
        vars.redeemSharesVault2 = vars.totalRedeemShares - vars.redeemSharesVault1;

        vars.assetsVault1 = vault.convertToAssets(vars.redeemSharesVault1);
        vars.assetsVault2 = vault.convertToAssets(vars.redeemSharesVault2);

        vars.expectedAssetsOrSharesOut = new uint256[](2);
        vars.expectedAssetsOrSharesOut[0] = vars.assetsVault1;
        vars.expectedAssetsOrSharesOut[1] = vars.assetsVault2;
        _fulfillRedeemForUsers(
            vars.redeemUsers,
            vars.redeemSharesVault1,
            vars.redeemSharesVault2,
            address(fluidVault),
            vars.ruggableVault,
            vars.expectedAssetsOrSharesOut,
            bytes4(0)
        );

        vm.warp(block.timestamp + 12 weeks);
        prevPps = vars.initialPricePerShare;
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", RuggableVault(vars.ruggableVault).balanceOf(address(strategy)));

        assertApproxEqRel(vars.initialPricePerShare, prevPps, 0.1e18, "Price per share should be preserved");
    }

    function test_4_Rebalance_Test() public executeWithoutHookRestrictions {
        VaultCapTestVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // Initial allocation - this will put the first two vaults at ~50/50
        _completeDepositFlow(vars.depositAmount);

        // Add Euler vault as a new yield source
        address eulerVaultAddr = CHAIN_1_EulerVault;
        vm.label(eulerVaultAddr, "EulerVault");
        IERC4626 eulerVault = IERC4626(eulerVaultAddr);

        // Add funds to the Euler vault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(eulerVaultAddr, type(uint256).max);
        eulerVault.deposit(2 * LARGE_DEPOSIT, address(this));

        vm.warp(block.timestamp + 20 days);

        // Add Euler vault as a new yield source
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(eulerVaultAddr, _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        // Get initial balances
        vars.initialFluidVaultBalance = fluidVault.convertToAssets(fluidVault.balanceOf(address(strategy)));
        vars.initialAaveVaultBalance = aaveVault.convertToAssets(aaveVault.balanceOf(address(strategy)));
        vars.initialEulerVaultBalance = eulerVault.convertToAssets(eulerVault.balanceOf(address(strategy)));

        console2.log("\n=== Initial Balances ===");
        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial EulerVault balance:", vars.initialEulerVaultBalance);

        // Calculate initial allocation percentages
        vars.totalInitialBalance =
            vars.initialFluidVaultBalance + vars.initialAaveVaultBalance + vars.initialEulerVaultBalance;
        vars.initialFluidRatio = (vars.initialFluidVaultBalance * 10_000) / vars.totalInitialBalance;
        vars.initialAaveRatio = (vars.initialAaveVaultBalance * 10_000) / vars.totalInitialBalance;
        vars.initialEulerRatio = (vars.initialEulerVaultBalance * 10_000) / vars.totalInitialBalance;

        console2.log("\n=== Initial Allocation Ratios ===");
        console2.log("Fluid Vault:", vars.initialFluidRatio / 100, "%");
        console2.log("Aave Vault:", vars.initialAaveRatio / 100, "%");
        console2.log("Euler Vault:", vars.initialEulerRatio / 100, "%");

        // First reallocation: Change to 50/25/25 (fluid/aave/euler)
        console2.log("\n=== First Reallocation: Target 50/25/25 ===");

        // Set up hooks for reallocation
        vars.withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        vars.depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        // Perform first reallocation to 50/25/25
        (
            vars.finalFluidVaultBalance,
            vars.finalAaveVaultBalance,
            vars.finalEulerVaultBalance,
            vars.finalFluidRatio,
            vars.finalAaveRatio,
            vars.finalEulerRatio
        ) = _reallocate(
            ReallocateArgs({
                vault1: fluidVault,
                vault2: aaveVault,
                vault3: eulerVault,
                targetVault1Percentage: 5000, // 50%
                targetVault2Percentage: 2500, // 25%
                targetVault3Percentage: 2500, // 25%
                withdrawHookAddress: vars.withdrawHookAddress,
                depositHookAddress: vars.depositHookAddress
            })
        );

        // Verify the allocation is close to 50/25/25
        assertApproxEqRel(vars.finalFluidRatio, 5000, 0.05e18, "Fluid allocation should be close to 50%");
        assertApproxEqRel(vars.finalAaveRatio, 2500, 0.05e18, "Aave allocation should be close to 25%");
        assertApproxEqRel(vars.finalEulerRatio, 2500, 0.05e18, "Euler allocation should be close to 25%");

        // Second reallocation: Change to 40/30/30 (fluid/aave/euler)
        console2.log("\n=== Second Reallocation: Target 40/30/30 ===");

        // Calculate target balances for 40/30/30 allocation
        vars.totalFinalBalance = vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalEulerVaultBalance;
        vars.targetFluidAssets2 = vars.totalFinalBalance * 4000 / 10_000;
        vars.targetAaveAssets2 = vars.totalFinalBalance * 3000 / 10_000;
        vars.targetEulerAssets2 = vars.totalFinalBalance * 3000 / 10_000;

        console2.log("Total Assets:", vars.totalFinalBalance);
        console2.log("Target Fluid Assets:", vars.targetFluidAssets2);
        console2.log("Target Aave Assets:", vars.targetAaveAssets2);
        console2.log("Target Euler Assets:", vars.targetEulerAssets2);

        console2.log("Target Aave assets would exceed vault cap!");
        console2.log("Vault Cap:", vars.newSuperVaultCap);
        console2.log("Target Aave Assets:", vars.targetAaveAssets2);
    }

    function test_5_EdgeCases_Small_Amounts() public executeWithoutHookRestrictions {
        uint256 depositAmount = 100; // very small

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

    function test_5_EdgeCases_SmallAmounts_WithAllocation() public executeWithoutHookRestrictions {
        uint256 depositAmount = 100; // very small

        _completeDepositFlow(depositAmount);

        uint256 fluidShares = fluidVault.balanceOf(address(strategy));
        uint256 aaveShares = aaveVault.balanceOf(address(strategy));

        uint256 currentFluidVaultAssets = fluidVault.convertToAssets(fluidShares);
        uint256 currentAaveVaultAssets = aaveVault.convertToAssets(aaveShares);
        uint256 totalAssets = currentFluidVaultAssets + currentAaveVaultAssets;

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);

        uint256 amountToReallocate = fluidShares.mulDiv(3000, 10_000);
        uint256 assetAmountToReallocate = fluidVault.convertToAssets(amountToReallocate);

        _rebalanceFromVaultToVault(
            hooksAddresses,
            hooksData,
            address(fluidVault),
            address(aaveVault),
            currentFluidVaultAssets + assetAmountToReallocate,
            currentAaveVaultAssets
        );

        uint256 finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        uint256 finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        uint256 finalFluidVaultAssets = fluidVault.previewRedeem(finalFluidVaultBalance);
        uint256 finalAaveVaultAssets = aaveVault.previewRedeem(finalAaveVaultBalance);

        uint256 finalTotalAssets = finalFluidVaultAssets + finalAaveVaultAssets;

        assertApproxEqRel(finalTotalAssets, totalAssets, 0.05e18, "Total value should be preserved");

        _requestRedeemForAllUsers(0);

        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }
        
        _fulfillRedeemForUsers(
            requestingUsers, finalFluidVaultAssets, finalAaveVaultAssets, address(fluidVault), address(aaveVault)
        );

        // check that all pending requests are cleared
        for (uint256 i; i < ACCOUNT_COUNT; ++i) {
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0);
            assertGt(strategy.claimableWithdraw(accInstances[i].account), 0);
        }
    }

    function test_5_EdgeCases_Large_Amounts() public executeWithoutHookRestrictions {
        uint256 depositAmount = 2_000_000e6; // very big

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

    function test_6_yieldAccumulation() public executeWithoutHookRestrictions {
        YieldTestVars memory vars;
        vars.depositAmount = 1000e6; // 100,000 USDC
        vars.initialTimestamp = block.timestamp;

        // create yield testing vaults
        vars.vault1 = new Mock4626Vault(address(asset), "Mock4626Vault 3%", "MV3");
        vars.vault2 = new Mock4626Vault(address(asset), "Mock4626Vault 5%", "MV5");
        vars.vault3 = new Mock4626Vault(address(asset), "Mock4626Vault 10%", "MV10");
        string[] memory vaultNames = new string[](3);
        vaultNames[0] = "test6YA_Mock4626Vault1";
        vaultNames[1] = "test6YA_Mock4626Vault2";
        vaultNames[2] = "test6YA_Mock4626Vault3";
        address[] memory vaultAddresses = new address[](3);
        vaultAddresses[0] = address(vars.vault1);
        vaultAddresses[1] = address(vars.vault2);
        vaultAddresses[2] = address(vars.vault3);

        _updateAndRegenerateMerkleTreeBatch(vaultNames, vaultAddresses, ETH);
        vars.vault1.setYield(3000); // 3%
        vars.vault2.setYield(5000); // 5%
        vars.vault3.setYield(10_000); // 10%

        // add some funds to each vault to bypass the VAULT_THRESHOLD_EXCEEDED error
        _getTokens(address(asset), address(this), 10 * LARGE_DEPOSIT);
        asset.approve(address(vars.vault1), type(uint256).max);
        asset.approve(address(vars.vault2), type(uint256).max);
        asset.approve(address(vars.vault3), type(uint256).max);
        vars.vault1.deposit(2 * LARGE_DEPOSIT, address(this));
        vars.vault2.deposit(2 * LARGE_DEPOSIT, address(this));
        vars.vault3.deposit(2 * LARGE_DEPOSIT, address(this));

        // add vaults to SV
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(vars.vault1), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        strategy.manageYieldSource(address(vars.vault2), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        strategy.manageYieldSource(address(vars.vault3), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        // use 3 users to perform deposits
        for (uint256 i; i < 3; ++i) {
            _getTokens(address(asset), accInstances[i].account, vars.depositAmount);
            _depositForAccount(accInstances[i], vars.depositAmount);
        }

        // fulfill deposits
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](3);
        fulfillHooksAddresses[0] = depositHookAddress;
        fulfillHooksAddresses[1] = depositHookAddress;
        fulfillHooksAddresses[2] = depositHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](3);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.vault1),
            address(asset),
            vars.depositAmount,
            false,
            address(0),
            0
        );
        fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.vault2),
            address(asset),
            vars.depositAmount,
            false,
            address(0),
            0
        );
        fulfillHooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(vars.vault3),
            address(asset),
            vars.depositAmount,
            false,
            address(0),
            0
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](3);
        expectedAssetsOrSharesOut[0] = IERC4626(address(vars.vault1)).convertToShares(vars.depositAmount);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vars.vault2)).convertToShares(vars.depositAmount);
        expectedAssetsOrSharesOut[2] = IERC4626(address(vars.vault3)).convertToShares(vars.depositAmount);

        address[] memory requestingUsers = new address[](3);
        for (uint256 i; i < 3; ++i) {
            requestingUsers[i] = accInstances[i].account;
        }

        bytes[] memory argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
        argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);
        argsForProofs[2] = ISuperHookInspector(fulfillHooksAddresses[2]).inspect(fulfillHooksData[2]);

        vm.startPrank(STRATEGIST);
        console2.log("Executing hooks");
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](fulfillHooksAddresses.length)
            })
        );
        console2.log("Hooks executed");
        vm.stopPrank();

        vars.initialVault1Balance = vars.vault1.balanceOf(address(strategy));
        vars.initialVault2Balance = vars.vault2.balanceOf(address(strategy));
        vars.initialVault3Balance = vars.vault3.balanceOf(address(strategy));

        vars.initialVault1Assets = vars.vault1.convertToAssets(vars.initialVault1Balance);
        vars.initialVault2Assets = vars.vault2.convertToAssets(vars.initialVault2Balance);
        vars.initialVault3Assets = vars.vault3.convertToAssets(vars.initialVault3Balance);

        // fast forward time to simulate yield accumulation
        vm.warp(vars.initialTimestamp + 1 weeks);

        vars.initialVault1Balance = vars.vault1.balanceOf(address(strategy));
        vars.initialVault2Balance = vars.vault2.balanceOf(address(strategy));
        vars.initialVault3Balance = vars.vault3.balanceOf(address(strategy));

        vars.finalVault1Assets = vars.vault1.convertToAssets(vars.initialVault1Balance);
        vars.finalVault2Assets = vars.vault2.convertToAssets(vars.initialVault2Balance);
        vars.finalVault3Assets = vars.vault3.convertToAssets(vars.initialVault3Balance);

        console2.log("initialVault1Assets", vars.initialVault1Assets);
        console2.log("finalVault1Assets  ", vars.finalVault1Assets);
        console2.log("initialVault2Assets", vars.initialVault2Assets);
        console2.log("finalVault2Assets  ", vars.finalVault2Assets);
        console2.log("initialVault3Assets", vars.initialVault3Assets);
        console2.log("finalVault3Assets  ", vars.finalVault3Assets);

        assertGt(vars.finalVault1Assets, vars.initialVault1Assets, "Vault 1 should have gained assets");
        assertGt(vars.finalVault2Assets, vars.initialVault2Assets, "Vault 2 should have gained assets");
        assertGt(vars.finalVault3Assets, vars.initialVault3Assets, "Vault 3 should have gained assets");

        uint256 vault1Yield = vars.finalVault1Assets - vars.initialVault1Assets;
        uint256 vault2Yield = vars.finalVault2Assets - vars.initialVault2Assets;
        uint256 vault3Yield = vars.finalVault3Assets - vars.initialVault3Assets;
        console2.log("vault1Yield", vault1Yield);
        console2.log("vault2Yield", vault2Yield);
        console2.log("vault3Yield", vault3Yield);

        assertGt(vault1Yield, 0, "Vault 1 should have gained assets");
        assertGt(vault2Yield, vault1Yield, "Vault 2 should have gained more assets than vault 1");
        assertGt(vault3Yield, vault2Yield, "Vault 3 should have gained more assets than vault 2");
    }

    function test_6_yieldAccumulation_WithRebalancing() public executeWithoutHookRestrictions {
        YieldTestVars memory vars;
        vars.depositAmount = 1000e6; // 100,000 USDC
        vars.initialTimestamp = block.timestamp;

        // create yield testing vaults
        vars.vault1 = new Mock4626Vault(address(asset), "Mock Vault 3%", "MV3");
        vars.vault2 = new Mock4626Vault(address(asset), "Mock Vault 5%", "MV5");
        vars.vault3 = new Mock4626Vault(address(asset), "Mock Vault 10%", "MV10");
        string[] memory vaultNames = new string[](3);
        vaultNames[0] = "test6YAREB_Mock4626Vault1";
        vaultNames[1] = "test6YAREB_Mock4626Vault2";
        vaultNames[2] = "test6YAREB_Mock4626Vault3";
        address[] memory vaultAddresses = new address[](3);
        vaultAddresses[0] = address(vars.vault1);
        vaultAddresses[1] = address(vars.vault2);
        vaultAddresses[2] = address(vars.vault3);

        _updateAndRegenerateMerkleTreeBatch(vaultNames, vaultAddresses, ETH);
        vars.vault1.setYield(3000); // 3%
        vars.vault2.setYield(5000); // 5%
        vars.vault3.setYield(10_000); // 10%

        // add some funds to each vault to bypass the VAULT_THRESHOLD_EXCEEDED error
        _getTokens(address(asset), address(this), 10 * LARGE_DEPOSIT);
        asset.approve(address(vars.vault1), type(uint256).max);
        asset.approve(address(vars.vault2), type(uint256).max);
        asset.approve(address(vars.vault3), type(uint256).max);
        vars.vault1.deposit(2 * LARGE_DEPOSIT, address(this));
        vars.vault2.deposit(2 * LARGE_DEPOSIT, address(this));
        vars.vault3.deposit(2 * LARGE_DEPOSIT, address(this));

        // add vaults to SV
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(vars.vault1), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        strategy.manageYieldSource(address(vars.vault2), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        strategy.manageYieldSource(address(vars.vault3), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        // use 3 users to perform deposits
        for (uint256 i; i < 3; ++i) {
            _getTokens(address(asset), accInstances[i].account, vars.depositAmount);
            _depositForAccount(accInstances[i], vars.depositAmount);
        }

        // fulfill deposits
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
                address(vars.vault1),
                address(asset),
                vars.depositAmount,
                false,
                address(0),
                0
            );
            fulfillHooksData[1] = _createApproveAndDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                address(vars.vault2),
                address(asset),
                vars.depositAmount,
                false,
                address(0),
                0
            );
            fulfillHooksData[2] = _createApproveAndDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                address(vars.vault3),
                address(asset),
                vars.depositAmount,
                false,
                address(0),
                0
            );

            uint256[] memory expectedAssetsOrSharesOut = new uint256[](3);
            expectedAssetsOrSharesOut[0] = IERC4626(address(vars.vault1)).convertToShares(vars.depositAmount);
            expectedAssetsOrSharesOut[1] = IERC4626(address(vars.vault2)).convertToShares(vars.depositAmount);
            expectedAssetsOrSharesOut[2] = IERC4626(address(vars.vault3)).convertToShares(vars.depositAmount);

            address[] memory requestingUsers = new address[](3);
            for (uint256 i; i < 3; ++i) {
                requestingUsers[i] = accInstances[i].account;
            }

            bytes[] memory argsForProofs = new bytes[](3);
            argsForProofs[0] = ISuperHookInspector(fulfillHooksAddresses[0]).inspect(fulfillHooksData[0]);
            argsForProofs[1] = ISuperHookInspector(fulfillHooksAddresses[1]).inspect(fulfillHooksData[1]);
            argsForProofs[2] = ISuperHookInspector(fulfillHooksAddresses[2]).inspect(fulfillHooksData[2]);

            vm.startPrank(STRATEGIST);
            strategy.executeHooks(
                ISuperVaultStrategy.ExecuteArgs({
                    hooks: fulfillHooksAddresses,
                    hookCalldata: fulfillHooksData,
                    expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
                    globalProofs: _getMerkleProofsForHooks(fulfillHooksAddresses, argsForProofs),
                    strategyProofs: new bytes32[][](fulfillHooksAddresses.length)
                })
            );
            vm.stopPrank();
        }

        {
            vars.initialVault1Balance = vars.vault1.balanceOf(address(strategy));
            vars.initialVault2Balance = vars.vault2.balanceOf(address(strategy));
            vars.initialVault3Balance = vars.vault3.balanceOf(address(strategy));
            vars.initialVault1Assets = vars.vault1.convertToAssets(vars.initialVault1Balance);
            vars.initialVault2Assets = vars.vault2.convertToAssets(vars.initialVault2Balance);
            vars.initialVault3Assets = vars.vault3.convertToAssets(vars.initialVault3Balance);

            address[] memory hooksAddresses = new address[](2);
            hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);
            hooksAddresses[1] = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);
            bytes[] memory hooksData = new bytes[](2);

            uint256 amountToReallocate = vars.initialVault2Balance * 10 / 100; //10%
            uint256 assetAmountToReallocate = vars.vault2.convertToAssets(amountToReallocate);

            _rebalanceFixedAmountFromVaultToVault(
                hooksAddresses, hooksData, address(vars.vault2), address(vars.vault1), assetAmountToReallocate
            );

            // fast forward time to simulate yield accumulation
            vm.warp(vars.initialTimestamp + 1 weeks);
            _updateSuperVaultPPS(address(strategy), address(vault));
            vars.initialVault1Balance = vars.vault1.balanceOf(address(strategy));
            vars.initialVault2Balance = vars.vault2.balanceOf(address(strategy));
            vars.initialVault3Balance = vars.vault3.balanceOf(address(strategy));
            vars.finalVault1Assets = vars.vault1.convertToAssets(vars.initialVault1Balance);
            vars.finalVault2Assets = vars.vault2.convertToAssets(vars.initialVault2Balance);
            vars.finalVault3Assets = vars.vault3.convertToAssets(vars.initialVault3Balance);

            assertGt(
                vars.finalVault1Assets + vars.finalVault2Assets + vars.finalVault3Assets,
                vars.initialVault1Assets + vars.initialVault2Assets + vars.initialVault3Assets,
                "Total assets should have increased"
            );
        }
    }

    function test_9_VaultLifecycle_FullAlocateOverTime_() public executeWithoutHookRestrictions {
        ScenarioNewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // do an initial allocation
        _completeDepositFlow(vars.depositAmount);

        uint256[] memory initialUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory initialUserShares = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            initialUserShares[i] = vault.balanceOf(accInstances[i].account);
        }

        vm.warp(block.timestamp + 20 days);

        _updateSuperVaultPPS(address(strategy), address(vault));

        uint256[] memory midUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory midUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            midUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            midUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(midUserAssets[i], initialUserAssets[i], "User assets should increase after 20 days");
            assertEq(midUserShares[i], initialUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Yield after 20 days ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Current Assets:", midUserAssets[i]);
            console2.log("Yield:", midUserAssets[i] - initialUserAssets[i]);
            console2.log("Yield %:", ((midUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]);
        }

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        // 100% to aave allocation
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);

        vm.warp(block.timestamp + 20 days);

        _updateSuperVaultPPS(address(strategy), address(vault));

        uint256[] memory finalUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory finalUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }

        // allocation; fluid -> aave
        address withdrawHookAddress = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](2);
        // redeem from fluid entirely
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false
        );
        // deposit to aave
        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(asset),
            vars.assetAmountToReallocateFromFluidVault,
            false,
            address(0),
            0
        );
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](2),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();
        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        assertEq(vars.finalFluidVaultBalance, 0, "FluidVault balance should be 0");
        assertGt(vars.finalAaveVaultBalance, vars.initialAaveVaultBalance, "AaveVault balance should increase");

        vm.warp(block.timestamp + 20 days);

        // 80% to aave allocation
        vars.amountToReallocateAaveVault = vars.finalAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        // re-allocate back to fluid; withdraw from aave (20%)
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false
        );
        // deposit to fluid
        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(asset),
            vars.assetAmountToReallocateFromAaveVault,
            false,
            address(0),
            0
        );
        argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](2),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();
        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total final value should be preserved during allocation"
        );

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }
    }

    function test_9_VaultLifecycle_AddAndRemoveOverTime() public executeWithoutHookRestrictions {
        ScenarioNewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // do an initial allocation
        _completeDepositFlow(vars.depositAmount);

        uint256[] memory initialUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory initialUserShares = new uint256[](ACCOUNT_COUNT);
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            initialUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            initialUserShares[i] = vault.balanceOf(accInstances[i].account);
        }

        vm.warp(block.timestamp + 20 days);

        _updateSuperVaultPPS(address(strategy), address(vault));

        uint256[] memory midUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory midUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            midUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            midUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(midUserAssets[i], initialUserAssets[i], "User assets should increase after 20 days");
            assertEq(midUserShares[i], initialUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Yield after 20 days ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Current Assets:", midUserAssets[i]);
            console2.log("Yield:", midUserAssets[i] - initialUserAssets[i]);
            console2.log("Yield %:", ((midUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]);
        }

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);

        // 100% to aave allocation
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);

        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);

        vm.warp(block.timestamp + 20 days);

        _updateSuperVaultPPS(address(strategy), address(vault));

        uint256[] memory finalUserAssets = new uint256[](ACCOUNT_COUNT);
        uint256[] memory finalUserShares = new uint256[](ACCOUNT_COUNT);

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }

        // allocation; fluid -> aave
        address withdrawHookAddress = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = withdrawHookAddress;
        hooksAddresses[1] = depositHookAddress;

        bytes[] memory hooksData = new bytes[](2);
        // redeem from fluid entirely
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(strategy),
            vars.amountToReallocateFluidVault,
            false
        );
        // deposit to aave
        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(asset),
            vars.assetAmountToReallocateFromFluidVault,
            false,
            address(0),
            0
        );
        bytes[] memory argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](2),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();

        // disable fluid vault entirely
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(fluidVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 2, false);
        vm.stopPrank();

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance);
        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance);

        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        assertEq(vars.finalFluidVaultBalance, 0, "FluidVault balance should be 0");
        assertGt(vars.finalAaveVaultBalance, vars.initialAaveVaultBalance, "AaveVault balance should increase");

        vm.warp(block.timestamp + 20 days);

        // 80% to aave allocation
        vars.amountToReallocateAaveVault = vars.finalAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        // re-allocate back to fluid; withdraw from aave (20%)
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(aaveVault),
            address(strategy),
            vars.amountToReallocateAaveVault,
            false
        );
        // deposit to fluid
        hooksData[1] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(fluidVault),
            address(asset),
            vars.assetAmountToReallocateFromAaveVault,
            false,
            address(0),
            0
        );
        argsForProofs = new bytes[](2);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);
        vm.startPrank(STRATEGIST);
        vm.expectRevert(ISuperVaultStrategy.YIELD_SOURCE_NOT_ACTIVE.selector);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](2),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();

        // re-enable fluid vault
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(fluidVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 2, true);
        vm.stopPrank();

        // try allocate again
        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](2),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();
        vars.finalTotalValue = aaveVault.convertToAssets(vars.finalAaveVaultBalance)
            + fluidVault.convertToAssets(vars.finalFluidVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue,
            vars.initialTotalValue,
            0.01e18,
            "Total final value should be preserved during allocation"
        );

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            finalUserAssets[i] = vault.convertToAssets(vault.balanceOf(accInstances[i].account));
            finalUserShares[i] = vault.balanceOf(accInstances[i].account);

            assertGt(finalUserAssets[i], midUserAssets[i], "User assets should increase after reallocation");
            assertEq(finalUserShares[i], midUserShares[i], "User shares should remain constant");

            console2.log(string.concat("\n=== User ", Strings.toString(i), " Final Yield ==="));
            console2.log("Initial Assets:", initialUserAssets[i]);
            console2.log("Mid Assets:", midUserAssets[i]);
            console2.log("Final Assets:", finalUserAssets[i]);
            console2.log("Total Yield:", finalUserAssets[i] - initialUserAssets[i]);
            console2.log(
                "Total Yield %:", ((finalUserAssets[i] - initialUserAssets[i]) * 10_000) / initialUserAssets[i]
            );
            console2.log("Post-Reallocation Yield:", finalUserAssets[i] - midUserAssets[i]);
            console2.log(
                "Post-Reallocation Yield %:", ((finalUserAssets[i] - midUserAssets[i]) * 10_000) / midUserAssets[i]
            );
        }
    }

    // function test_10_RuggableVault_Deposit_No_ExpectedAssetsOrSharesOut() public {
    //     RugTestVarsDeposit memory vars;
    //     vars.depositAmount = 1000e6;
    //     vars.rugPercentage = 10; // 0.1% rug
    //     vars.initialTimestamp = block.timestamp;

    //     // Deploy a ruggable vault that rugs on deposit
    //     vars.ruggableVault = new RuggableVault(
    //         IERC20(address(asset)),
    //         "Ruggable Vault",
    //         "RUG",
    //         true, // rug on deposit
    //         false, // don't rug on withdraw
    //         vars.rugPercentage
    //     );

    //     // Add funds to the ruggable vault to respect LARGE_DEPOSIT
    //     _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
    //     asset.approve(address(vars.ruggableVault), type(uint256).max);
    //     vars.ruggableVault.deposit(2 * LARGE_DEPOSIT, address(this));

    //     // Deploy a new SuperVault with the ruggable vault
    //     _deployNewSuperVaultWithRuggableVault(address(vars.ruggableVault));

    //     // Setup deposit users and amounts
    //     vars.depositUsers = new address[](5);
    //     vars.depositAmounts = new uint256[](5);
    //     for (uint256 i = 0; i < 5; i++) {
    //         vars.depositUsers[i] = accInstances[i].account;
    //         vars.depositAmounts[i] = vars.depositAmount;
    //     }

    //     // Perform deposits
    //     for (uint256 i = 0; i < 5; i++) {
    //         _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
    //         vm.startPrank(vars.depositUsers[i]);
    //         asset.approve(address(vault), vars.depositAmounts[i]);
    //         vault.deposit(vars.depositAmounts[i], vars.depositUsers[i]);
    //         vm.stopPrank();
    //     }

    //     // Simulate time passing
    //     vm.warp(vars.initialTimestamp + 1 days);

    //     uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
    //     expectedAssetsOrSharesOut[0] = 1; //99% slippage
    //     expectedAssetsOrSharesOut[1] = 1; // 99% slippage
    //     _depositFreeAssets(
    //         vars.depositAmount * 5 / 2,
    //         vars.depositAmount * 5 / 2,
    //         address(fluidVault),
    //         address(vars.ruggableVault),
    //         expectedAssetsOrSharesOut,
    //         bytes4(0)
    //     );
    // }

    function test_10_RuggableVault_Deposit() public {
        RugTestVarsDeposit memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 5000; // 50% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs on deposit
        vars.ruggableVault = new RuggableVault(
            IERC20(address(asset)),
            "Ruggable Vault",
            "RUG",
            true, // rug on deposit
            false, // don't rug on withdraw
            vars.rugPercentage
        );
        _updateAndRegenerateMerkleTree("test_10RuggableVaultOnDeposit", address(vars.ruggableVault), ETH);

        // Add funds to the ruggable vault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(address(vars.ruggableVault), type(uint256).max);
        vars.ruggableVault.deposit(2 * LARGE_DEPOSIT, address(this));

        // Deploy a new SuperVault with the ruggable vault
        _deployNewSuperVaultWithRuggableVault(address(vars.ruggableVault));

        // Setup deposit users and amounts
        vars.depositUsers = new address[](5);
        vars.depositAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            vars.depositUsers[i] = accInstances[i].account;
            vars.depositAmounts[i] = vars.depositAmount;
        }

        // Perform deposits
        for (uint256 i = 0; i < 5; i++) {
            _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
            vm.startPrank(vars.depositUsers[i]);
            asset.approve(address(vault), vars.depositAmounts[i]);
            vault.deposit(vars.depositAmounts[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        // Simulate time passing
        vm.warp(vars.initialTimestamp + 1 days);

        uint256 sharesVault1 = IERC4626(address(fluidVault)).convertToShares(vars.depositAmount * 5 / 2);
        uint256 sharesVault2 = IERC4626(address(vars.ruggableVault)).convertToShares(vars.depositAmount * 5 / 2);

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = sharesVault1 - (sharesVault1 * 1e2 / 1e5); // 1% slippage
        expectedAssetsOrSharesOut[1] = (sharesVault2 - sharesVault2 * vars.rugPercentage / 10_000) * 2; // Should revert

        // expect revert on this call and try again after
        _depositFreeAssets(
            (vars.depositAmount * 5) / 2,
            (vars.depositAmount * 5) / 2,
            address(fluidVault),
            address(vars.ruggableVault),
            expectedAssetsOrSharesOut,
            ISuperVaultStrategy.MINIMUM_OUTPUT_AMOUNT_ASSETS_NOT_MET.selector
        );
        expectedAssetsOrSharesOut[1] = sharesVault2 - sharesVault2 *vars.rugPercentage / 10_000; // 50% rug
        _depositFreeAssets(
            vars.depositAmount * 5 / 2,
            vars.depositAmount * 5 / 2,
            address(fluidVault),
            address(vars.ruggableVault),
            expectedAssetsOrSharesOut,
            bytes4(0)
        );
    }

    function test_10_RuggableVault_Withdraw() public {
        RugTestVarsWithdraw memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 5000; // 50% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs on withdraw
        RuggableVault ruggableVault = new RuggableVault(
            IERC20(address(asset)),
            "Ruggable Vault",
            "RUG",
            false, // don't rug on deposit
            true, // rug on withdraw
            vars.rugPercentage
        );
        _updateAndRegenerateMerkleTree("test_10RuggableVault", address(ruggableVault), ETH);

        vars.ruggableVault = address(ruggableVault);
        vars.convertVault = false;
        // Log the rug configuration
        console2.log("\n=== RuggableVault Configuration ===");
        console2.log("Rug on deposit:", ruggableVault.rugOnDeposit());
        console2.log("Rug on withdraw:", ruggableVault.rugOnWithdraw());
        console2.log("Rug percentage:", ruggableVault.rugPercentage());

        // Calculate how much would be rugged for a sample amount
        uint256 sampleAmount = 1000e6;
        uint256 ruggedAmount = ruggableVault.calculateRuggedAmount(sampleAmount);
        console2.log("For a sample amount of", sampleAmount, "the rugged amount would be", ruggedAmount);

        // Verify the rug calculation is correct
        assertEq(
            ruggedAmount,
            sampleAmount * vars.rugPercentage / 10_000,
            "Rugged amount calculation should match expected value"
        );

        _testRuggableVaultWithdraw(vars);
    }

    function test_10_RuggableVault_Withdraw_ConvertDistortion() public {
        RugTestVarsWithdraw memory vars;
        vars.depositAmount = 1000e6;
        vars.rugPercentage = 5000; // 50% rug
        vars.initialTimestamp = block.timestamp;

        // Deploy a ruggable vault that rugs via convert functions
        RuggableConvertVault ruggableConvertVault = new RuggableConvertVault(
            IERC20(address(asset)),
            "Ruggable Convert Vault",
            "RUGC",
            vars.rugPercentage,
            true // rug enabled
        );
        _updateAndRegenerateMerkleTree("test_10RuggableConvertVault", address(ruggableConvertVault), ETH);

        vars.ruggableVault = address(ruggableConvertVault);
        vars.convertVault = true;
        _testRuggableVaultWithdraw(vars);

        // Verify that the SuperVault's totalAssets was affected by the inflated reporting
        uint256 vaultTotalAssets = ruggableConvertVault.totalAssets();
        console2.log("Ruggable vault total assets:", vaultTotalAssets);

        // Disable the rug to see the true value
        ruggableConvertVault.setRugEnabled(false);
        uint256 vaultTotalAssetsWithoutRug = ruggableConvertVault.totalAssets();
        console2.log("Ruggable total assets (rug disabled):", vaultTotalAssetsWithoutRug);
        console2.log("Difference:", vaultTotalAssets - vaultTotalAssetsWithoutRug);

        // The difference should be significant if there are still assets in the ruggable vault
        assertGt(
            vaultTotalAssets, vaultTotalAssetsWithoutRug, "SuperVault total assets should be higher with rug enabled"
        );
    }

    function test_11_Allocate_NewYieldSource() public executeWithoutHookRestrictions {
        ScenarioNewYieldSourceVars memory vars;
        vars.depositAmount = 1000e6;

        vars.initialFluidVaultPPS = fluidVault.convertToAssets(1e18);
        vars.initialAaveVaultPPS = aaveVault.convertToAssets(1e18);

        // do an initial allo
        _completeDepositFlow(vars.depositAmount);

        // add new vault as yield source
        Mock4626Vault newVault = new Mock4626Vault(address(asset), "New Vault", "NV");
        _updateAndRegenerateMerkleTree("New Vault", address(newVault), ETH);

        //  -- add funds to the newVault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(address(newVault), type(uint256).max);
        newVault.deposit(2 * LARGE_DEPOSIT, address(this));

        vm.warp(block.timestamp + 20 days);

        _updateSuperVaultPPS(address(strategy), address(vault));

        // -- add it as a new yield source
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(newVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true);
        vm.stopPrank();

        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.initialAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.initialNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Initial FluidVault balance:", vars.initialFluidVaultBalance);
        console2.log("Initial AaveVault balance:", vars.initialAaveVaultBalance);
        console2.log("Initial NewVault balance:", vars.initialNewVaultBalance);

        // 30/30/40
        // allocate 20% from each vault to the new one
        vars.amountToReallocateFluidVault = vars.initialFluidVaultBalance * 20 / 100;
        vars.amountToReallocateAaveVault = vars.initialAaveVaultBalance * 20 / 100;
        vars.assetAmountToReallocateFromFluidVault = fluidVault.convertToAssets(vars.amountToReallocateFluidVault);
        vars.assetAmountToReallocateFromAaveVault = aaveVault.convertToAssets(vars.amountToReallocateAaveVault);
        vars.assetAmountToReallocateToNewVault =
            vars.assetAmountToReallocateFromFluidVault + vars.assetAmountToReallocateFromAaveVault;
        console2.log("Asset amount to reallocate from FluidVault:", vars.assetAmountToReallocateFromFluidVault);
        console2.log("Asset amount to reallocate from AaveVault:", vars.assetAmountToReallocateFromAaveVault);

        vm.warp(block.timestamp + 20 days);
        _updateSuperVaultPPS(address(strategy), address(vault));

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
        // deposit to NewVault
        hooksData[2] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(newVault),
            address(asset),
            vars.assetAmountToReallocateToNewVault,
            false,
            address(0),
            0
        );
        bytes[] memory argsForProofs = new bytes[](3);
        argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
        argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);
        argsForProofs[2] = ISuperHookInspector(hooksAddresses[2]).inspect(hooksData[2]);

        vm.startPrank(STRATEGIST);
        strategy.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                expectedAssetsOrSharesOut: new uint256[](3),
                globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                strategyProofs: new bytes32[][](hooksAddresses.length)
            })
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 20 days);
        _updateSuperVaultPPS(address(strategy), address(vault));

        // check new balances
        vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.finalAaveVaultBalance = aaveVault.balanceOf(address(strategy));
        vars.finalNewVaultBalance = newVault.balanceOf(address(strategy));

        console2.log("Final FluidVault balance:", vars.finalFluidVaultBalance);
        console2.log("Final AaveVault balance:", vars.finalAaveVaultBalance);
        console2.log("Final NewVault balance:", vars.finalNewVaultBalance);

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

        assertGt(vars.finalNewVaultBalance, vars.initialNewVaultBalance, "NewVault balance should increase");

        vars.initialTotalValue = fluidVault.convertToAssets(vars.initialFluidVaultBalance)
            + aaveVault.convertToAssets(vars.initialAaveVaultBalance)
            + newVault.convertToAssets(vars.initialNewVaultBalance);

        vars.finalTotalValue = fluidVault.convertToAssets(vars.finalFluidVaultBalance)
            + aaveVault.convertToAssets(vars.finalAaveVaultBalance) + newVault.convertToAssets(vars.finalNewVaultBalance);
        assertApproxEqRel(
            vars.finalTotalValue, vars.initialTotalValue, 0.01e18, "Total value should be preserved during allocation"
        );

        // Enhanced checks for price per share and yield
        console2.log("\n=== Enhanced Vault Metrics ===");

        // Price per share comparison
        uint256 fluidVaultFinalPPS = fluidVault.convertToAssets(1e18);
        uint256 aaveVaultFinalPPS = aaveVault.convertToAssets(1e18);
        uint256 newVaultFinalPPS = newVault.convertToAssets(1e18);

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
        assertGe(newVaultFinalPPS, 1e18, "NewVault should not lose value");

        uint256 totalFinalBalance = vars.finalFluidVaultBalance + vars.finalAaveVaultBalance + vars.finalNewVaultBalance;

        uint256 fluidRatio = (vars.finalFluidVaultBalance * 100) / totalFinalBalance;
        uint256 aaveRatio = (vars.finalAaveVaultBalance * 100) / totalFinalBalance;
        uint256 newRatio = (vars.finalNewVaultBalance * 100) / totalFinalBalance;

        console2.log("\nFinal Allocation Ratios:");
        console2.log("Fluid Vault:", fluidRatio, "%");
        console2.log("Aave Vault:", aaveRatio, "%");
        console2.log("NewVault:", newRatio, "%");
    }

    function test_12_multiMillionDeposits() public executeWithoutHookRestrictions {
        TestVars memory vars;
        vars.initialTimestamp = block.timestamp;

        // Set up deposit amounts for multiple rounds
        // We'll do 3 rounds of deposits to reach 10M+ USDC
        uint256 depositRounds = 3;
        uint256 targetTotalDeposits = 9_000_000e6; // 10M USDC
        uint256 depositPerRound = targetTotalDeposits / depositRounds;
        uint256 depositPerUser = depositPerRound / ACCOUNT_COUNT;

        console2.log("\n=== Starting multi-million deposit test ===");
        console2.log("Target total deposits:", targetTotalDeposits / 1e6, "M USDC");
        console2.log("Deposit rounds:", depositRounds);
        console2.log("Deposit per round:", depositPerRound / 1e6, "M USDC");
        console2.log("Deposit per user per round:", depositPerUser / 1e6, "M USDC");

        // Round 1: Initial deposits
        console2.log("\n=== Round 1 Deposits ===");
        vars.depositAmounts = new uint256[](ACCOUNT_COUNT);
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            vars.depositAmounts[i] = depositPerUser;
        }
        _completeDepositFlowWithVaryingAmounts(vars.depositAmounts);
        vars.totalDeposited += depositPerRound;
        console2.log("balance of vault", IERC20(address(asset)).balanceOf(address(strategy)));
        console2.log("total deposited", vars.totalDeposited);
        console2.log("Total Assets:", vault.totalAssets());

        // Wait 1 week
        vm.warp(vars.initialTimestamp + 1 weeks);
        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("\n=== After 1 week ===");
        console2.log("Total Assets:", vault.totalAssets());
        console2.log("Price per share:", aggregator.getPPS(address(strategy)));

        // Round 2: More deposits after 1 week
        console2.log("\n=== Round 2 Deposits ===");
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            _getTokens(address(asset), accInstances[i].account, depositPerUser);
            __deposit(accInstances[i], depositPerUser);
        }

        // Prepare for fulfillment
        address[] memory requestingUsers = new address[](ACCOUNT_COUNT);
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            requestingUsers[i] = accInstances[i].account;
        }

        // Fulfill deposits with 60/40 split between vaults
        console2.log("deposit per round", depositPerRound);

        uint256 allocationAmountVault1 = (depositPerRound * 6000) / 10_000; // 60% to fluid vault
        uint256 allocationAmountVault2 = depositPerRound - allocationAmountVault1; // 40% to aave vault
        console2.log("\n=== Round 2 Fulfill Requests ===");

        console2.log("allocation vault 1", allocationAmountVault1);
        console2.log("allocation vault 2", allocationAmountVault2);
        console2.log("balance of vault", IERC20(address(asset)).balanceOf(address(strategy)));
        // TVL fluid 1669215723572
        // tvl aave 1668059877911
        _depositFreeAssets(allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault));

        vars.totalDeposited += depositPerRound;

        // Wait 2 more weeks
        vm.warp(vars.initialTimestamp + 3 weeks);
        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("\n=== After 3 weeks ===");
        console2.log("Total Assets:", vault.totalAssets() / 1e6, "M USDC");
        console2.log("Price per share:", aggregator.getPPS(address(strategy)));

        // Round 3: Final deposits after 3 weeks
        console2.log("\n=== Round 3 Deposits ===");
        for (uint256 i = 0; i < ACCOUNT_COUNT; i++) {
            _getTokens(address(asset), accInstances[i].account, depositPerUser);
            __deposit(accInstances[i], depositPerUser);
        }

        // Wait 2 more weeks before fulfilling final deposits
        vm.warp(vars.initialTimestamp + 5 weeks);
        _updateSuperVaultPPS(address(strategy), address(vault));

        console2.log("\n=== After 5 weeks (before final fulfillment) ===");
        console2.log("Total Assets:", vault.totalAssets() / 1e6, "M USDC");
        console2.log("Price per share:", aggregator.getPPS(address(strategy)));

        // Store state before final fulfillment
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Fulfill final deposits with 70/30 split
        allocationAmountVault1 = (depositPerRound * 70) / 100; // 70% to fluid vault
        allocationAmountVault2 = depositPerRound - allocationAmountVault1; // 30% to aave vault

        _depositFreeAssets(allocationAmountVault1, allocationAmountVault2, address(fluidVault), address(aaveVault));

        vars.totalDeposited += depositPerRound;

        // Final verification after all deposits
        console2.log("\n=== Final state after all deposits ===");
        vars.finalTotalAssets = vault.totalAssets();
        vars.finalTotalSupply = vault.totalSupply();
        vars.finalPricePerShare = vars.finalTotalAssets.mulDiv(1e18, vars.finalTotalSupply, Math.Rounding.Floor);

        console2.log("Total deposited:", vars.totalDeposited / 1e6, "M USDC");
        console2.log("Final total assets:", vars.finalTotalAssets / 1e6, "M USDC");
        console2.log("Final price per share:", vars.finalPricePerShare);

        // Check underlying vault balances
        vars.fluidVaultBalance = fluidVault.balanceOf(address(strategy));
        vars.aaveVaultBalance = aaveVault.balanceOf(address(strategy));

        uint256 fluidVaultAssets = fluidVault.convertToAssets(vars.fluidVaultBalance);
        uint256 aaveVaultAssets = aaveVault.convertToAssets(vars.aaveVaultBalance);

        console2.log("\n=== Underlying vault balances ===");
        console2.log("Fluid vault shares:", vars.fluidVaultBalance);
        console2.log("Fluid vault assets:", fluidVaultAssets / 1e6, "M USDC");
        console2.log("Aave vault shares:", vars.aaveVaultBalance);
        console2.log("Aave vault assets:", aaveVaultAssets / 1e6, "M USDC");
        console2.log("Total underlying assets:", (fluidVaultAssets + aaveVaultAssets) / 1e6, "M USDC");

        // Verify total assets matches the sum of underlying vault assets
        assertApproxEqRel(vars.finalTotalAssets, fluidVaultAssets + aaveVaultAssets, 0.01e18); // 1% tolerance

        // Verify price per share increased over time (yield accrual)
        assertGt(vars.finalPricePerShare, 1e18, "Price per share should be greater than 1e18 after yield accrual");

        // Verify total deposits reached target
        assertGe(
            vars.finalTotalAssets, targetTotalDeposits, "Total assets should be at least the target deposit amount"
        );
    }

    // function test_13_TransferOfShares() public executeWithoutHookRestrictions {
    //     _getTokens(address(asset), accInstances[0].account, 100e6);
    //     __deposit(accInstances[0], 100e6);

    //     uint256 shares = vault.balanceOf(accInstances[0].account);

    //     vm.prank(accInstances[0].account);
    //     IERC20(address(vault)).transfer(accInstances[1].account, shares);

    //     console2.log("share balance ofuser2", IERC20(address(vault)).balanceOf(accInstances[1].account));

    //     _depositFreeAssetsFromSingleAmount(100e6, address(fluidVault), address(aaveVault));

    //     _updateSuperVaultPPS(address(strategy), address(vault));

    //     _requestRedeemForAccount(accInstances[1], shares);

    //     address[] memory redeemUsers = new address[](1);
    //     redeemUsers[0] = accInstances[1].account;

    //     _fulfillRedeemForUsers(redeemUsers, shares / 2, shares / 2, address(fluidVault), address(aaveVault));

    //     // console2.log("asset balance ofuser2", IERC20(address(asset)).balanceOf(accInstances[1].account));

    //     // _claimRedeemForUsers(redeemUsers);

    //     // console2.log("asset balance ofuser2", IERC20(address(asset)).balanceOf(accInstances[1].account));
    // }

    function _verifyInitialBalances(uint256[] memory depositAmounts) internal view {
        console2.log("\n=== Initial State ===");
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 pricePerShare = totalAssets.mulDiv(1e18, totalSupply, Math.Rounding.Floor);

        console2.log("Total Assets:", totalAssets);
        console2.log("Total Supply:", totalSupply);
        console2.log("Price per share:", pricePerShare);

        // Verify vault invariants
        assertGt(totalSupply, 0, "Total supply should be positive");
        assertGt(totalAssets, 0, "Total assets should be positive");

        // Verify underlying balances
        uint256 totalUnderlyingInVaults =
            fluidVault.balanceOf(address(strategy)) + aaveVault.balanceOf(address(strategy));
        assertGt(totalUnderlyingInVaults, 0, "Should have balance in underlying vaults");

        // Verify total deposits match total assets (accounting for bootstrap amount)
        uint256 expectedTotalDeposits;
        for (uint256 i; i < depositAmounts.length; i++) {
            expectedTotalDeposits += depositAmounts[i];
        }
        assertApproxEqRel(totalAssets, expectedTotalDeposits, 0.01e18, "Total assets should match deposits");

        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            uint256 shares = vault.balanceOf(accInstances[i].account);
            uint256 assets = vault.convertToAssets(shares);
            assertApproxEqRel(assets, depositAmounts[i], 0.01e18);
            console2.log("\nUser", i);
            console2.log("deposited:", depositAmounts[i]);
            console2.log("got shares:", shares);
            console2.log("got assets:", assets);

            // Verify share-asset conversion consistency
            uint256 sharesFromAssets = vault.convertToShares(assets);
            assertApproxEqRel(sharesFromAssets, shares, 0.01e18, "Share-asset conversion should be consistent");
        }
    }

    function _selectRandomUsersForRedemption(MultipleOperationsVars memory vars)
        internal
        view
        returns (MultipleOperationsVars memory)
    {
        uint256 i;
        while (vars.selectedCount < 15) {
            uint256 randIndex = uint256(keccak256(abi.encodePacked(vars.seed, "redeem", i))) % ACCOUNT_COUNT;

            if (!vars.selected[randIndex]) {
                vars.redeemUsers[vars.selectedCount] = accInstances[randIndex].account;
                // Redeem 25-75% of their balance
                uint256 randPercent = 2500 + (uint256(keccak256(abi.encodePacked(vars.seed, "percent", i))) % 5100);
                uint256 shares = vault.balanceOf(accInstances[randIndex].account);

                vars.redeemAmounts[vars.selectedCount] = (shares * randPercent) / 10_000;
                vars.selected[randIndex] = true;
                vars.selectedCount++;
            }
            i++;
        }
        return vars;
    }

    function _processRedemptionRequests(MultipleOperationsVars memory vars) internal {
        for (uint256 i; i < vars.selectedCount; i++) {
            vm.startPrank(vars.redeemUsers[i]);
            vault.requestRedeem(vars.redeemAmounts[i], vars.redeemUsers[i], vars.redeemUsers[i]);
            vm.stopPrank();
        }
    }

    function _claimRedeemForUsers(address[] memory redeemUsers) internal {
        for (uint256 i; i < redeemUsers.length; i++) {
            address user = redeemUsers[i];
            uint256 maxWithdrawAmount = vault.maxWithdraw(user);
            if (maxWithdrawAmount > 0) {
                vm.startPrank(user);
                console2.log("withdrawing", maxWithdrawAmount, "for user", user);
                vault.withdraw(maxWithdrawAmount, user, user);
                vm.stopPrank();
            }
        }
    }

    function _verifyFinalBalances(MultipleOperationsVars memory vars) internal view {
        FinalBalanceVerificationVars memory v;

        // Calculate global vault state
        v.finalTotalAssets = vault.totalAssets();
        v.finalTotalSupply = vault.totalSupply();
        //v.finalPricePerShare = v.finalTotalAssets.mulDiv(1e18, v.finalTotalSupply, Math.Rounding.Floor);
        v.finalPricePerShare = strategy.getStoredPPS();
        v.totalValueLocked = v.finalTotalAssets;

        // Get escrow balance
        v.escrowBalance = vault.balanceOf(address(escrow));

        // Log final state
        console2.log("\n=== Final State ===");
        console2.log("Final Total Assets:", v.finalTotalAssets);
        console2.log("Final Total Supply:", v.finalTotalSupply);
        console2.log("Final Price per share:", v.finalPricePerShare);
        console2.log("Total Value Locked:", v.totalValueLocked);
        console2.log("Escrow Balance:", v.escrowBalance);

        // Verify escrow state
        assertEq(v.escrowBalance, 0, "Escrow should have no shares after all claims are processed");

        // Calculate yield metrics
        v.totalYieldAccrued =
            v.finalTotalAssets > vars.initialTotalAssets ? v.finalTotalAssets - vars.initialTotalAssets : 0;
        v.yieldPerShare = v.totalYieldAccrued.mulDiv(1e18, v.finalTotalSupply, Math.Rounding.Floor);

        console2.log("\n=== Yield Metrics ===");
        console2.log("Total Yield Accrued:", v.totalYieldAccrued);
        console2.log("Yield Per Share:", v.yieldPerShare);

        // Verify yield accrual
        assertGe(
            v.finalPricePerShare,
            vars.initialPricePerShare,
            "Price per share should not decrease over time due to yield"
        );
        assertGt(v.totalValueLocked, 0, "TVL should be positive");

        // Verify strategy state
        v.fluidBalance = fluidVault.balanceOf(address(strategy));
        v.aaveBalance = aaveVault.balanceOf(address(strategy));

        console2.log("\n=== Strategy State ===");
        console2.log("Fluid Vault Balance:", v.fluidBalance);
        console2.log("Aave Vault Balance:", v.aaveBalance);

        // Strategy invariant checks
        assertGt(v.fluidBalance, 0, "Should maintain minimum fluid vault allocation");
        assertGt(v.aaveBalance, 0, "Should maintain minimum aave vault allocation");

        // Verify user states and accumulate totals
        for (uint256 i; i < ACCOUNT_COUNT; i++) {
            v.currentShares = vault.balanceOf(accInstances[i].account);
            v.currentAssets = vault.convertToAssets(v.currentShares);
            v.totalUserShares += v.currentShares;
            v.totalUserAssets += v.currentAssets;

            // Check if user is a redeemer
            v.isRedeemer = false;
            v.redeemedShares = 0;
            for (uint256 j; j < 15; j++) {
                if (accInstances[i].account == vars.redeemUsers[j]) {
                    v.isRedeemer = true;
                    v.redeemedShares = vars.redeemAmounts[j];
                    break;
                }
            }

            // Calculate user's yield
            v.userYieldAccrued = v.currentAssets > vars.depositAmounts[i] ? v.currentAssets - vars.depositAmounts[i] : 0;

            console2.log(string.concat("\n=== User ", Strings.toString(i), " State ==="));
            console2.log("Current Shares:", v.currentShares);
            console2.log("Current Assets:", v.currentAssets);
            console2.log("Yield Accrued:", v.userYieldAccrued);

            if (v.isRedeemer) {
                v.expectedShares = vault.convertToShares(vars.depositAmounts[i]) - v.redeemedShares;
                assertApproxEqRel(v.currentShares, v.expectedShares, 0.01e18, "Redeemer shares mismatch");

                // Verify redeemer's remaining position if they still have shares
                if (v.currentShares > 0) {
                    assertGt(
                        v.currentAssets.mulDiv(v.finalTotalSupply, v.currentShares, Math.Rounding.Floor),
                        vars.depositAmounts[i],
                        "Redeemer's remaining position should be worth more due to yield"
                    );
                }
            } else {
                v.expectedAssets = vars.depositAmounts[i];
                assertApproxEqRel(v.currentAssets, v.expectedAssets, 0.01e18, "Non-redeemer assets mismatch");
                assertGt(v.currentAssets, vars.depositAmounts[i], "Non-redeemer should have more assets due to yield");
            }

            // Verify no pending operations
            v.totalPendingRedeems += strategy.pendingRedeemRequest(accInstances[i].account);
            assertEq(strategy.pendingRedeemRequest(accInstances[i].account), 0, "Should have no pending redemptions");
        }

        // Final global state verification
        console2.log("\n=== Final Verification ===");
        console2.log("Total User Shares:", v.totalUserShares);
        console2.log("Total User Assets:", v.totalUserAssets);
        console2.log("Total Pending Deposits:", v.totalPendingDeposits);
        console2.log("Total Pending Redeems:", v.totalPendingRedeems);

        assertApproxEqRel(v.totalUserShares, v.finalTotalSupply, 0.01e18, "Total shares should match supply");
        assertApproxEqRel(v.totalUserAssets, v.finalTotalAssets, 0.01e18, "Total assets should match TVL");
        assertEq(v.totalPendingDeposits, 0, "Should have no pending deposits globally");
        assertEq(v.totalPendingRedeems, 0, "Should have no pending redeems globally");
    }

    function _testRuggableVaultWithdraw(RugTestVarsWithdraw memory vars) internal {
        // Add funds to the ruggable vault to respect LARGE_DEPOSIT
        _getTokens(address(asset), address(this), 2 * LARGE_DEPOSIT);
        asset.approve(vars.ruggableVault, type(uint256).max);
        IERC4626(vars.ruggableVault).deposit(2 * LARGE_DEPOSIT, address(this));

        // Deploy a new SuperVault with the ruggable vault
        _deployNewSuperVaultWithRuggableVault(vars.ruggableVault);

        // Setup deposit users and amounts
        vars.depositUsers = new address[](5);
        vars.depositAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            vars.depositUsers[i] = accInstances[i].account;
            vars.depositAmounts[i] = vars.depositAmount;
        }

        // Perform deposits
        for (uint256 i = 0; i < 5; i++) {
            _getTokens(address(asset), vars.depositUsers[i], vars.depositAmounts[i]);
            vm.startPrank(vars.depositUsers[i]);
            asset.approve(address(vault), vars.depositAmounts[i]);
            vault.deposit(vars.depositAmounts[i], vars.depositUsers[i]);
            vm.stopPrank();
        }

        // Fulfill deposit requests
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](2);
        expectedAssetsOrSharesOut[0] = IERC4626(address(fluidVault)).convertToShares(vars.depositAmount * 5 / 2);
        expectedAssetsOrSharesOut[1] = IERC4626(address(vars.ruggableVault)).convertToShares(vars.depositAmount * 5 / 2);
        _depositFreeAssets(
            vars.depositAmount * 5 / 2, vars.depositAmount * 5 / 2, address(fluidVault), vars.ruggableVault
        );
        console2.log("\n=== TIME WARPING ===");
        vars.ppsBeforeWarp = aggregator.getPPS(address(strategy));
        console2.log("PPS BEFORE WARP", vars.ppsBeforeWarp);

        vm.warp(block.timestamp + 10 weeks);

        _updateSuperVaultPPS(address(strategy), address(vault));
        vars.ppsAfterWarp = aggregator.getPPS(address(strategy));
        console2.log("PPS AFTER WARP", vars.ppsAfterWarp);

        // Store initial state
        vars.initialTotalAssets = vault.totalAssets();
        vars.initialTotalSupply = vault.totalSupply();
        vars.initialPricePerShare = vars.initialTotalAssets.mulDiv(1e18, vars.initialTotalSupply, Math.Rounding.Floor);

        // Log initial state
        console2.log("\n=== Initial State Before Redemption ===");
        console2.log("Initial Total Assets:", vars.initialTotalAssets);
        console2.log("Initial Total Supply:", vars.initialTotalSupply);
        console2.log("Initial Price per share:", vars.initialPricePerShare);
        console2.log("Ruggable Vault Balance:", IERC4626(vars.ruggableVault).balanceOf(address(strategy)));
        console2.log("Fluid Vault Balance:", fluidVault.balanceOf(address(strategy)));

        // Verify the initial state
        assertGt(vars.initialTotalAssets, 0, "Initial total assets should be positive");
        assertGt(vars.initialTotalSupply, 0, "Initial total supply should be positive");

        // Setup redeem users and amounts
        vars.redeemUsers = new address[](3);
        vars.redeemAmounts = new uint256[](3);
        vars.totalRedeemShares = 0;

        for (uint256 i = 0; i < 3; i++) {
            vars.redeemUsers[i] = vars.depositUsers[i];
            uint256 userShares = vault.balanceOf(vars.redeemUsers[i]);
            vars.redeemAmounts[i] = userShares; // Redeem all of their shares
            vars.totalRedeemShares += vars.redeemAmounts[i];
        }

        // Request redemptions
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(vars.redeemUsers[i]);
            vault.requestRedeem(vars.redeemAmounts[i], vars.redeemUsers[i], vars.redeemUsers[i]);
            vm.stopPrank();
        }

        // Simulate time passing
        console2.log("\n=== TIME WARPING ===");
        vars.ppsBeforeWarp = aggregator.getPPS(address(strategy));
        console2.log("PPS BEFORE WARP", vars.ppsBeforeWarp);

        vm.warp(block.timestamp + 12 weeks);

        _updateSuperVaultPPS(address(strategy), address(vault));
        vars.ppsAfterWarp = aggregator.getPPS(address(strategy));
        console2.log("PPS AFTER WARP", vars.ppsAfterWarp);

        // Fulfill redemption requests
        vars.redeemSharesVault1 = vars.totalRedeemShares / 2;
        vars.redeemSharesVault2 = vars.totalRedeemShares - vars.redeemSharesVault1;

        vars.assetsVault1 = IERC4626(address(fluidVault)).convertToAssets(vars.redeemSharesVault1);
        vars.assetsVault2 = IERC4626(address(vars.ruggableVault)).convertToAssets(vars.redeemSharesVault2);

        vars.expectedAssetsOrSharesOut = new uint256[](2);
        vars.expectedAssetsOrSharesOut[0] = vars.assetsVault1;
        vars.expectedAssetsOrSharesOut[1] = !vars.convertVault ? 1 : vars.assetsVault2; // this should make the call
            // revert

        // this should revert
        _fulfillRedeemForUsers(
            vars.redeemUsers,
            vars.redeemSharesVault1,
            vars.redeemSharesVault2,
            address(fluidVault),
            vars.ruggableVault,
            vars.expectedAssetsOrSharesOut,
            ISuperVaultStrategy.MINIMUM_OUTPUT_AMOUNT_ASSETS_NOT_MET.selector
        );

        vars.expectedAssetsOrSharesOut[0] = vars.assetsVault1 / 2;
        vars.expectedAssetsOrSharesOut[1] = vars.assetsVault2 / 2;
        _fulfillRedeemForUsers(
            vars.redeemUsers,
            vars.redeemSharesVault1,
            vars.redeemSharesVault2,
            address(fluidVault),
            vars.ruggableVault,
            vars.expectedAssetsOrSharesOut,
            bytes4(0)
        );

        // Log post-fulfillment state
        console2.log("\n=== Post-Fulfillment State ===");
        vars.totalAssetsPreClaimTaintedAssets = vault.totalAssets();
        vars.totalSupplyPreClaimTaintedAssets = vault.totalSupply();
        console2.log("Total Assets:", vars.totalAssetsPreClaimTaintedAssets);
        console2.log("Total Supply:", vars.totalSupplyPreClaimTaintedAssets);
        vars.pricePerSharePreClaimTaintedAssets = vars.totalAssetsPreClaimTaintedAssets.mulDiv(
            1e18, vars.totalSupplyPreClaimTaintedAssets, Math.Rounding.Floor
        );
        console2.log("Price per share:", vars.pricePerSharePreClaimTaintedAssets);
        console2.log("Ruggable Vault Balance:", IERC4626(vars.ruggableVault).balanceOf(address(strategy)));
        console2.log("Fluid Vault Balance:", fluidVault.balanceOf(address(strategy)));

        // Process claims for redeemed users, this will burn all tainted shares
        //_claimRedeemForUsers(vars.redeemUsers);

        // Verify global state
        vars.finalTotalAssets = vault.totalAssets();
        vars.finalTotalSupply = vault.totalSupply();
        uint256 finalPricePerShare = vars.finalTotalAssets.mulDiv(1e18, vars.finalTotalSupply, Math.Rounding.Floor);

        console2.log("\n=== Final State ===");
        console2.log("Final Total Assets:", vars.finalTotalAssets);
        console2.log("Final Total Supply:", vars.finalTotalSupply);
        console2.log("Final Price per share:", finalPricePerShare);

        // CONTINUATION: Allocate from rugged vault back to fluid vault
        console2.log("\n=== Allocating from Rugged Vault back to Fluid Vault ===");

        // Get initial balances
        vars.initialRuggableVaultBalance = IERC4626(vars.ruggableVault).balanceOf(address(strategy));
        vars.initialFluidVaultBalance = fluidVault.balanceOf(address(strategy));

        console2.log("Initial Ruggable Vault balance:", vars.initialRuggableVaultBalance);
        console2.log("Initial Fluid Vault balance:", vars.initialFluidVaultBalance);

        // Calculate asset amounts
        vars.initialRuggableVaultAssets = IERC4626(vars.ruggableVault).convertToAssets(vars.initialRuggableVaultBalance);
        vars.initialFluidVaultAssets = fluidVault.convertToAssets(vars.initialFluidVaultBalance);

        console2.log("Initial Ruggable Vault assets:", vars.initialRuggableVaultAssets);
        console2.log("Initial Fluid Vault assets:", vars.initialFluidVaultAssets);

        vars.amountToReallocate = vars.initialRuggableVaultBalance;
        vars.assetAmountToReallocate =
            IERC4626(vars.ruggableVault).convertToAssets(vars.amountToReallocate) * 5000 / 10_000;

        console2.log("Shares to reallocate from Ruggable Vault:", vars.amountToReallocate);
        console2.log("Asset amount to reallocate:", vars.assetAmountToReallocate);

        // Skip reallocation if there are no shares to reallocate
        if (vars.amountToReallocate > 0) {
            // Prepare allocation hooks
            address withdrawHookAddress = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
            address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

            address[] memory hooksAddresses = new address[](2);
            hooksAddresses[0] = withdrawHookAddress;
            hooksAddresses[1] = depositHookAddress;

            bytes[] memory hooksData = new bytes[](2);

            // Redeem from Ruggable Vault
            hooksData[0] = _createRedeem4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                vars.ruggableVault,
                address(strategy),
                vars.amountToReallocate,
                false
            );

            // Deposit to Fluid Vault
            hooksData[1] = _createApproveAndDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                address(fluidVault),
                address(asset),
                vars.assetAmountToReallocate,
                false,
                address(0),
                0
            );
            bytes[] memory argsForProofs = new bytes[](2);
            argsForProofs[0] = ISuperHookInspector(hooksAddresses[0]).inspect(hooksData[0]);
            argsForProofs[1] = ISuperHookInspector(hooksAddresses[1]).inspect(hooksData[1]);

            // Execute allocation
            vm.startPrank(STRATEGIST);
            strategy.executeHooks(
                ISuperVaultStrategy.ExecuteArgs({
                    hooks: hooksAddresses,
                    hookCalldata: hooksData,
                    expectedAssetsOrSharesOut: new uint256[](2),
                    globalProofs: _getMerkleProofsForHooks(hooksAddresses, argsForProofs),
                    strategyProofs: new bytes32[][](hooksAddresses.length)
                })
            );
            vm.stopPrank();

            // Check final balances
            vars.finalRuggableVaultBalance = IERC4626(vars.ruggableVault).balanceOf(address(strategy));
            vars.finalFluidVaultBalance = fluidVault.balanceOf(address(strategy));

            console2.log("Final Ruggable Vault balance:", vars.finalRuggableVaultBalance);
            console2.log("Final Fluid Vault balance:", vars.finalFluidVaultBalance);

            // Calculate asset amounts after reallocation
            vars.finalRuggableVaultAssets = IERC4626(vars.ruggableVault).convertToAssets(vars.finalRuggableVaultBalance);
            vars.finalFluidVaultAssets = fluidVault.convertToAssets(vars.finalFluidVaultBalance);

            console2.log("Final Ruggable Vault assets:", vars.finalRuggableVaultAssets);
            console2.log("Final Fluid Vault assets:", vars.finalFluidVaultAssets);

            // Verify reallocation
            assertApproxEqRel(
                vars.finalRuggableVaultBalance,
                vars.initialRuggableVaultBalance - vars.amountToReallocate,
                0.01e18,
                "Ruggable Vault balance should decrease by the reallocated amount"
            );

            assertGt(vars.finalFluidVaultBalance, vars.initialFluidVaultBalance, "Fluid Vault balance should increase");

            // Check total value preservation
            vars.initialTotalValue = vars.initialRuggableVaultAssets + vars.initialFluidVaultAssets;
            vars.finalTotalValue = vars.finalRuggableVaultAssets + vars.finalFluidVaultAssets;

            console2.log("Initial total value:", vars.initialTotalValue);
            console2.log("Final total value:", vars.finalTotalValue);

            // Check final vault state
            vars.vaultTotalAssetsAfterAllocation = vault.totalAssets();
            vars.pricePerShareAfterAllocation =
                vars.vaultTotalAssetsAfterAllocation.mulDiv(1e18, vars.finalTotalSupply, Math.Rounding.Floor);

            console2.log("Vault total assets after allocation:", vars.vaultTotalAssetsAfterAllocation);
            console2.log("Price per share after allocation:", vars.pricePerShareAfterAllocation);
        } else {
            console2.log("Skipping reallocation as there are no shares to reallocate");
        }
    }

    function _deployNewSuperVaultWithRuggableVault(address ruggableVault) internal {
        // Deploy a new SuperVault with the ruggable vault
        address vaultAddr;
        address strategyAddr;
        address escrowAddr;
        (vaultAddr, strategyAddr, escrowAddr) = _deployVault("SV_USDC_RUG");

        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Replace aaveVault with ruggableVault in the strategy
        vm.startPrank(STRATEGIST);
        strategy.manageYieldSource(address(fluidVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true); // Add

        strategy.manageYieldSource(ruggableVault, _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY), 0, true); // Add
            // ruggableVault
        vm.stopPrank();
    }
}
