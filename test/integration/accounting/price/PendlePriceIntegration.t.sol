// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IStandardizedYield } from "../../../../src/vendor/pendle/IStandardizedYield.sol";

// Superform
import { MinimalBaseNexusIntegrationTest } from "../../MinimalBaseNexusIntegrationTest.t.sol";
import { ISuperExecutor } from "../../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";

import { ERC5115YieldSourceOracle } from "../../../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { Deposit5115VaultHook } from "../../../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../../../../src/hooks/vaults/5115/Redeem5115VaultHook.sol";

contract PendlePriceIntegration is MinimalBaseNexusIntegrationTest {
    address[] public attesters;
    uint8 public threshold;

    IStandardizedYield public pendleVault;
    address public underlying;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        attesters = new address[](1);

        attesters[0] = address(MANAGER);
        threshold = 1;

        pendleVault = IStandardizedYield(CHAIN_1_PENDLE_ETHENA);
        underlying = CHAIN_1_SUSDE;
    }

    function test_ValidateDeposit_Pendle_PricePerShare(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(attesters, threshold, 0);
        vm.deal(nexusAccount, LARGE);

        // add tokens to account
        _getTokens(underlying, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(new Deposit5115VaultHook());
        hooksData[0] = _createApproveHookData(underlying, address(pendleVault), amount, false);
        hooksData[1] = _create5115DepositHookData(
            bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
            address(pendleVault),
            underlying,
            amount,
            0,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        // re-execute the same entrypoint
        _getTokens(underlying, nexusAccount, amount);

        _executeThroughEntrypoint(nexusAccount, entry);
    }

    function test_ValidateFees_ForFullWithdrawal_AccumulatedFees_Pendle() public {
        uint256 amount = 1e18;

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config = ledgerConfig.getYieldSourceOracleConfig(
            _getYieldSourceOracleId(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(this))
        );
        assertEq(config.feePercent, 100);

        address nexusAccount = _setupNexusAccount(amount);

        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        _executeThroughEntrypoint(nexusAccount, entry);

        _getTokens(underlying, nexusAccount, amount);
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        uint256 ppsBefore = ERC5115YieldSourceOracle(yieldSourceOracle5115).getPricePerShare(address(pendleVault));
        _performMultipleDeposits(underlying, IERC4626(underlying).asset(), 50, SMALL);
        uint256 ppsAfter = ERC5115YieldSourceOracle(yieldSourceOracle5115).getPricePerShare(address(pendleVault));
        assertGt(ppsAfter, ppsBefore, "pps after should be higher");

        uint256 availableShares = pendleVault.balanceOf(nexusAccount);
        entry = _prepareWithdrawExecutorEntry(availableShares);
        _executeThroughEntrypoint(nexusAccount, entry);

        assertGt(IERC20(underlying).balanceOf(config.feeRecipient), 0);
    }

    function test_ValidateFees_ForFullWithdrawal_NonYieldToken_AccumulatedFees_Pendle() public {
        uint256 amount = 1e18;

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config = ledgerConfig.getYieldSourceOracleConfig(
            _getYieldSourceOracleId(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(this))
        );
        assertEq(config.feePercent, 100);

        address nexusAccount = _setupNexusAccount(amount);

        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        uint256 ppsBefore = ERC5115YieldSourceOracle(yieldSourceOracle5115).getPricePerShare(address(pendleVault));
        for (uint256 i; i < 50; ++i) {
            _getTokens(CHAIN_1_USDE, address(this), SMALL);
            IERC20(CHAIN_1_USDE).approve(address(pendleVault), SMALL);
            IStandardizedYield(address(pendleVault)).deposit(address(this), CHAIN_1_USDE, SMALL, 0);
        }
        vm.warp(block.timestamp + (86_400 * 365));

        uint256 ppsAfter = ERC5115YieldSourceOracle(yieldSourceOracle5115).getPricePerShare(address(pendleVault));

        assertGt(ppsAfter, ppsBefore);

        uint256 availableShares = pendleVault.balanceOf(nexusAccount);
        entry = _prepareWithdrawExecutorEntry(availableShares);
        _executeThroughEntrypoint(nexusAccount, entry);

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
        for (uint256 i; i < count; ++i) {
            _getTokens(asset, address(this), amountPerDeposit);
            IERC20(asset).approve(vault, amountPerDeposit);
            IERC4626(vault).deposit(amountPerDeposit, address(this));
        }
        vm.warp(block.timestamp + (86_400 * 365));
    }

    function _setupNexusAccount(uint256 amount) private returns (address nexusAccount) {
        nexusAccount = _createWithNexus(attesters, threshold, 0);
        vm.deal(nexusAccount, LARGE);
        _getTokens(underlying, nexusAccount, amount);
    }

    function _prepareDepositExecutorEntry(uint256 amount) private returns (ISuperExecutor.ExecutorEntry memory entry) {
        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(new Deposit5115VaultHook());
        hooksData[0] = _createApproveHookData(underlying, address(pendleVault), amount, false);
        hooksData[1] = _create5115DepositHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(pendleVault),
            underlying,
            amount,
            0,
            false,
            address(0),
            0
        );
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }

    function _prepareWithdrawExecutorEntry(uint256 amount)
        private
        returns (ISuperExecutor.ExecutorEntry memory entry)
    {
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = address(new Redeem5115VaultHook());
        hooksData[0] = _create5115RedeemHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(pendleVault),
            underlying,
            amount,
            0,
            false
        );

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }
}
