// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// superform
import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";
import { ISuperVault } from "../../../src/periphery/interfaces/ISuperVault.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ERC7540YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";

contract SuperVaultE2EFlow is BaseSuperVaultTest {
    ERC7540YieldSourceOracle public oracle;
    ISuperLedger public superLedgerETH;
    SuperRegistry public superRegistry;

    address public feeRecipientETH;

    uint256 amountPerVault;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superRegistry = SuperRegistry(_getContract(ETH, SUPER_REGISTRY_KEY));
        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));

        feeRecipientETH = superRegistry.getTreasury();

        oracle = ERC7540YieldSourceOracle(_getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY));

        _setUpSuperLedgerForVault();

        amountPerVault = 1000e6; // 1000 USDC
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SuperVault_E2E_Flow() public {
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);
        uint256 initialVaultAssets = asset.balanceOf(address(vault));

        // Step 1: Request Deposit
        _requestDeposit(amountPerVault);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth),
            initialUserAssets - amountPerVault,
            "User assets not reduced after deposit request"
        );
        assertEq(
            asset.balanceOf(address(strategy)),
            initialVaultAssets + amountPerVault,
            "Vault assets not increased after deposit request"
        );

        uint256 expectedUserShares = vault.convertToShares(amountPerVault);

        // Step 2: Fulfill Deposit
        _fulfillDeposit(amountPerVault);

        // Step 3: Claim Deposit
        _claimDeposit(amountPerVault);

        // Verify shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);
        assertEq(userShares, expectedUserShares, "User shares not minted correctly");
        console2.log("userShares", userShares);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 2 weeks);

        uint256 feeBalanceBefore = asset.balanceOf(feeRecipientETH);

        // Step 4: Request Redeem
        _requestRedeem(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(vault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(IERC20(vault.share()).balanceOf(address(escrow)), userShares, "Shares not transferred to escrow");

        // Step 5: Fulfill Redeem
        _fulfillRedeem(userShares);

        // Calculate expected assets based on shares
        uint256 claimableAssets = vault.maxWithdraw(accountEth);

        (ISuperLedger.LedgerEntry[] memory entries, 
        uint256 unconsumedEntries) = superLedgerETH.getLedger(accountEth, address(vault));

        // Calculate expected fee
        uint256 expectedCoreFee = _deriveExpectedFee(
            FeeParams({
                entries: entries,
                unconsumedEntries: unconsumedEntries,
                amountAssets: claimableAssets,
                usedShares: userShares,
                feePercent: 100,
                decimals: 6
            })
        );

        // (uint256 superformFee, uint256 recipientFee) = _deriveSuperVaultFees(
        //     userShares,
        //     oracle.getPricePerShare(address(vault))
        // );

        //uint256 totalFee = superformFee + recipientFee + expectedCoreFee;

        // Step 6: Claim Withdraw
        // vm.expectEmit(true, true, true, true);
        // emit ISuperLedgerData.AccountingOutflow(
        //     accountEth,
        //     oracle,
        //     address(vault),
        //     assets,
        //     expectedFee // add SV fee
        // );
        _claimWithdraw(claimableAssets);

        // Final balance assertions
        assertGt(asset.balanceOf(accountEth), preRedeemUserAssets, "User assets not increased after redeem");

        // Verify fee was taken
        //_assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(feeRecipientETH));

        // Check final ledger state
        (entries, unconsumedEntries) = superLedgerETH.getLedger(accountEth, address(vault));
        assertEq(entries.length, 1, "Should have one ledger entry");
        assertEq(
          entries[0].amountSharesAvailableToConsume, 
          0, 
          "Shares not consumed correctly"
        );
        assertEq(unconsumedEntries, 1, "Should have one unconsumed entry");
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setUpSuperLedgerForVault() internal {
        vm.selectFork(FORKS[ETH]);
        vm.startPrank(MANAGER);
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0, // 0% fee is required for Ledger entries where the SuperVault is the target so that we don't double charge fees
            feeRecipient: feeRecipientETH,
            ledger: _getContract(ETH, SUPER_LEDGER_KEY)
        });
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY)).setYieldSourceOracles(configs);
        vm.stopPrank();
    }
}
