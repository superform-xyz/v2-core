// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { BaseE2ETest } from "../../../BaseE2ETest.t.sol";
import { MockRegistry } from "../../../mocks/MockRegistry.sol";
import { SuperLedger } from "../../../../src/core/accounting/SuperLedger.sol";
import { ERC1155Ledger } from "../../../../src/core/accounting/ERC1155Ledger.sol";
import { SuperExecutor } from "../../../../src/core/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperExecutor } from "../../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { IStandardizedYield } from "../../../../src/vendor/pendle/IStandardizedYield.sol";

import { ERC5115YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";

import { console2 } from "forge-std/console2.sol";
// 5115 vault

contract PendlePriceIntegration is BaseE2ETest {
    MockRegistry nexusRegistry;
    address[] attesters;
    uint8 threshold;

    ERC5115YieldSourceOracle oracle;
    SuperExecutor superExecutor;
    ERC1155Ledger pendleLedger;
    SuperLedgerConfiguration superLedgerConfiguration;
    bytes mockSignature;

    IStandardizedYield pendleVault;
    address underlying;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        nexusRegistry = new MockRegistry();
        attesters = new address[](1);

        attesters[0] = address(MANAGER);
        threshold = 1;

        mockSignature = abi.encodePacked(hex"41414141");

        oracle = new ERC5115YieldSourceOracle(_getContract(ETH, SUPER_ORACLE_KEY));

        superExecutor = SuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superLedgerConfiguration = SuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY));
        pendleLedger = ERC1155Ledger(_getContract(ETH, ERC1155_LEDGER_KEY));

        pendleVault = IStandardizedYield(CHAIN_1_PendleEthena);
        underlying = CHAIN_1_SUSDE;
    }

    function test_ValidateDeposit_Pendle_PricePerShare(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        vm.deal(nexusAccount, LARGE);

        // add tokens to account
        _getTokens(underlying, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);
        hooksData[0] = _createApproveHookData(underlying, address(pendleVault), amount, false);
        hooksData[1] = _create5115DepositHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(pendleVault), underlying, amount, 0, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        uint256 pricePerShareOne = oracle.getPricePerShare(address(pendleVault));
        uint256 sharesOne = pendleVault.previewDeposit(underlying, amount);

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

        // assert price per share
        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            pendleLedger.getLedger(nexusAccount, address(pendleVault));
        assertEq(entries.length, 1);
        assertEq(entries[0].price, pricePerShareOne);
        assertEq(entries[0].amountSharesAvailableToConsume, sharesOne);
        assertEq(unconsumedEntries, 0);

        // re-execute the same entrypoint
        _getTokens(underlying, nexusAccount, amount);
        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

        uint256 pricePerShareTwo = oracle.getPricePerShare(address(pendleVault));
        uint256 sharesTwo = pendleVault.previewDeposit(underlying, amount);

        // assert price per share
        (entries, unconsumedEntries) = pendleLedger.getLedger(nexusAccount, address(pendleVault));
        assertEq(entries.length, 2);
        assertEq(entries[0].price, pricePerShareOne);
        assertEq(entries[0].amountSharesAvailableToConsume, sharesOne);
        assertEq(entries[1].price, pricePerShareTwo);

        assertEq(entries[1].amountSharesAvailableToConsume, sharesTwo);
        assertEq(unconsumedEntries, 0);
    }

    function test_ValidateFees_ForPartialWithdrawal_NoExtraFees_Pendle() public {
        uint256 amount = SMALL; // fixed amount to test the fee and consumed entries easily

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            superLedgerConfiguration.getYieldSourceOracleConfig(bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)));
        assertEq(config.feePercent, 100); //1%

        // create and fund
        address nexusAccount = _setupNexusAccount(amount);

        // prepare execution entry
        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        // execute and validate first deposit
        _executeAndValidateDeposit(nexusAccount, entry, amount, 1);

        // execute and validate second deposit
        _getTokens(underlying, nexusAccount, amount);
        _executeAndValidateDeposit(nexusAccount, entry, amount, 2);

        // Check before withdrawal fees
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        // add funds for accounting fees (as `convertToAssets` result is mocked above)
        _getTokens(underlying, nexusAccount, amount);

        // withdraw 2/3 first
        uint256 availableShares = pendleVault.balanceOf(nexusAccount);
        uint256 withdrawShares = availableShares * 2 / 3;
        entry = _prepareWithdrawExecutorEntry(withdrawShares);
        // it should still have 2 entries in the ledger and unconsumed entries index should be 0
        _executeAndValidateWithdraw(nexusAccount, entry, 2, 1);

        assertEq(IERC20(underlying).balanceOf(config.feeRecipient), 0);
    }

    function test_ValidateFees_ForFullWithdrawal_AccumulatedFees_Pendle() public {
        uint256 amount = 1e18; 

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            superLedgerConfiguration.getYieldSourceOracleConfig(bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)));
        assertEq(config.feePercent, 100); 

        address nexusAccount = _setupNexusAccount(amount);

        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        _executeAndValidateDeposit(nexusAccount, entry, amount, 1);

        _getTokens(underlying, nexusAccount, amount);
        _executeAndValidateDeposit(nexusAccount, entry, amount, 2);

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        uint256 ppsBefore = oracle.getPricePerShare(address(pendleVault));
        _performMultipleDeposits(underlying, IERC4626(underlying).asset(), 50, SMALL);
        uint256 ppsAfter = oracle.getPricePerShare(address(pendleVault));
        assertGt(ppsAfter, ppsBefore, "pps after should be higher"); 

        uint256 availableShares = pendleVault.balanceOf(nexusAccount);
        entry = _prepareWithdrawExecutorEntry(availableShares);
        _executeAndValidateWithdraw(nexusAccount, entry, 2, 2);

        assertGt(IERC20(underlying).balanceOf(config.feeRecipient), 0);
    }
     
    function test_ValidateFees_ForFullWithdrawal_NonYieldToken_AccumulatedFees_Pendle() public {
        uint256 amount = 1e18; 

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            superLedgerConfiguration.getYieldSourceOracleConfig(bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)));
        assertEq(config.feePercent, 100); 

        address nexusAccount = _setupNexusAccount(amount);

        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        _executeAndValidateDeposit(nexusAccount, entry, amount, 1);

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        uint256 ppsBefore = oracle.getPricePerShare(address(pendleVault));
        for (uint256 i; i < 50;) {
            _getTokens(CHAIN_1_USDE, address(this), SMALL);
            IERC20(CHAIN_1_USDE).approve(address(pendleVault), SMALL);
            IStandardizedYield(address(pendleVault)).deposit(address(this), CHAIN_1_USDE, SMALL, 0);
            unchecked {
                ++i;
            }
        }
        vm.warp(block.timestamp + (86_400 * 365));

        uint256 ppsAfter = oracle.getPricePerShare(address(pendleVault));

        assertGt(ppsAfter, ppsBefore); 

        uint256 availableShares = pendleVault.balanceOf(nexusAccount);
        entry = _prepareWithdrawExecutorEntry(availableShares);
        _executeAndValidateWithdraw(nexusAccount, entry, 1, 1);

        assertGt(IERC20(underlying).balanceOf(config.feeRecipient), 0);
    }


    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _performMultipleDeposits(address vault, address asset, uint256 count, uint256 amountPerDeposit) private {
        /**
         * function exchangeRate() public view virtual override returns (uint256) {
         *         uint256 totalAssets = IERC4626(yieldToken).totalAssets();  -> balanceOf
         *         uint256 totalSupply = IERC4626(yieldToken).totalSupply();
         *         return totalAssets.divDown(totalSupply);
         *     }
         *     function totalAssets() public view override returns (uint256) {
         *         return IERC20(asset()).balanceOf(address(this)) - getUnvestedAmount();
         *     }
         */
        for (uint256 i; i < count;) {
            _getTokens(asset, address(this), amountPerDeposit);
            IERC20(asset).approve(vault, amountPerDeposit);
            IERC4626(vault).deposit(amountPerDeposit, address(this));
            unchecked {
                ++i;
            }
        }
        vm.warp(block.timestamp + (86_400 * 365));
    }

    function _setupNexusAccount(uint256 amount) private returns (address nexusAccount) {
        nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        vm.deal(nexusAccount, LARGE);
        _getTokens(underlying, nexusAccount, amount);
    }

    function _prepareDepositExecutorEntry(uint256 amount)
        private
        view
        returns (ISuperExecutor.ExecutorEntry memory entry)
    {
        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);
        hooksData[0] = _createApproveHookData(underlying, address(pendleVault), amount, false);
        hooksData[1] = _create5115DepositHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(pendleVault), underlying, amount, 0, false, false
        );
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }

    function _prepareWithdrawExecutorEntry(uint256 amount)
        private
        view
        returns (ISuperExecutor.ExecutorEntry memory entry)
    {
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_5115_VAULT_HOOK_KEY);
        hooksData[0] = _create5115WithdrawHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(pendleVault), underlying, amount, 0, false, false, false
        );

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }

    function _executeAndValidateDeposit(
        address nexusAccount,
        ISuperExecutor.ExecutorEntry memory entry,
        uint256 amount,
        uint256 expectedEntriesCount
    )
        private
    {
        uint256 pricePerShare = oracle.getPricePerShare(address(pendleVault));
        uint256 shares = pendleVault.previewDeposit(underlying, amount);

        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            pendleLedger.getLedger(nexusAccount, address(pendleVault));

        assertEq(entries.length, expectedEntriesCount);
        assertEq(entries[entries.length - 1].price, pricePerShare);
        assertEq(entries[entries.length - 1].amountSharesAvailableToConsume, shares);
        assertEq(unconsumedEntries, 0);
    }

    function _executeAndValidateWithdraw(
        address nexusAccount,
        ISuperExecutor.ExecutorEntry memory entry,
        uint256 expectedEntriesCount,
        uint256 expectedUnconsumedEntries
    )
        private
    {
        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            pendleLedger.getLedger(nexusAccount, address(pendleVault));

        assertEq(entries.length, expectedEntriesCount, "Entries count mismatch");
        assertEq(unconsumedEntries, expectedUnconsumedEntries, "Unconsumed entries mismatch");
    }
}
