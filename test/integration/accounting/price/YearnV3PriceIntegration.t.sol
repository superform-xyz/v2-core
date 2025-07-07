// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { MinimalBaseNexusIntegrationTest } from "../../MinimalBaseNexusIntegrationTest.t.sol";
import { MockRegistry } from "../../../mocks/MockRegistry.sol";
import { ISuperExecutor } from "../../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";

import { ERC4626YieldSourceOracle } from "../../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";

// 4626 vault
contract YearnV3PriceIntegration is MinimalBaseNexusIntegrationTest {
    MockRegistry public nexusRegistry;
    address[] public attesters;
    uint8 public threshold;

    ERC4626YieldSourceOracle public oracle;

    IERC4626 public yearnVault;
    address public underlying;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        nexusRegistry = new MockRegistry();
        attesters = new address[](1);

        attesters[0] = address(MANAGER);
        threshold = 1;

        oracle = new ERC4626YieldSourceOracle(address(ledgerConfig));

        yearnVault = IERC4626(CHAIN_1_YearnVault);
        underlying = yearnVault.asset();
    }

    function test_ValidateDeposit_Yearn_PricePerShare(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        vm.deal(nexusAccount, LARGE);

        // add tokens to account
        _getTokens(underlying, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        bytes[] memory hooksData = new bytes[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        hooksData[0] = _createApproveHookData(underlying, address(yearnVault), amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(yearnVault), amount, false, address(0), 0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        // re-execute the same entrypoint
        _getTokens(underlying, nexusAccount, amount);

        _executeThroughEntrypoint(nexusAccount, entry);
    }

    function test_ValidateFees_ForPartialWithdrawal_Yearn() public {
        uint256 amount = SMALL; // fixed amount to test the fee and consumed entries easily

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            ledgerConfig.getYieldSourceOracleConfig(_getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)));
        assertEq(config.feePercent, 100); //1%

        // create and fund
        address nexusAccount = _setupNexusAccount(amount);

        // prepare execution entry
        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        // execute and validate first deposit
        _executeThroughEntrypoint(nexusAccount, entry);

        // execute and validate second deposit
        _getTokens(underlying, nexusAccount, amount);
        _executeThroughEntrypoint(nexusAccount, entry);

        // Check before withdrawal fees
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        // time passing won't change anything as the vault needs deposits; let's mock the call
        // double the price per share
        uint256 pricePerShareTwo = oracle.getPricePerShare(address(yearnVault));
        vm.mockCall(
            address(yearnVault),
            abi.encodeWithSelector(IERC4626.convertToAssets.selector, 10 ** yearnVault.decimals()),
            abi.encode(pricePerShareTwo * 2)
        );
        // add funds for accounting fees (as `convertToAssets` result is mocked above)
        _getTokens(underlying, nexusAccount, amount);

        // withdraw 2/3 first
        uint256 availableShares = yearnVault.convertToShares(amount);
        uint256 withdrawShares = availableShares * 2 / 3;
        entry = _prepareWithdrawExecutorEntry(withdrawShares, nexusAccount);
        // it should still have 2 entries in the ledger and unconsumed entries index should be 0
        _executeThroughEntrypoint(nexusAccount, entry);
    }

    function test_ValidateFees_TwoEntries_And_FullWithdrawalWithOneTx_WithDoublePricePerShare_Yearn() public {
        uint256 amount = SMALL; // fixed amount to test the fee and consumed entries easily

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            ledgerConfig.getYieldSourceOracleConfig(_getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)));
        assertEq(config.feePercent, 100); //1%

        // create and fund
        address nexusAccount = _setupNexusAccount(amount);

        // prepare execution entry
        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        // execute and validate first deposit
        _executeThroughEntrypoint(nexusAccount, entry);

        // execute and validate second deposit
        _getTokens(underlying, nexusAccount, amount);
        _executeThroughEntrypoint(nexusAccount, entry);

        // Check before withdrawal fees
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        // time passing won't change anything as the vault needs deposits; let's mock the call
        // double the price per share
        uint256 pricePerShareTwo = oracle.getPricePerShare(address(yearnVault));
        vm.mockCall(
            address(yearnVault),
            abi.encodeWithSelector(IERC4626.convertToAssets.selector, 10 ** yearnVault.decimals()),
            abi.encode(pricePerShareTwo * 2)
        );

        // add funds for accounting fees (as `convertToAssets` result is mocked above)
        _getTokens(underlying, nexusAccount, amount);

        // withdraw everything
        uint256 availableShares = yearnVault.balanceOf(nexusAccount);
        entry = _prepareWithdrawExecutorEntry(availableShares, nexusAccount);

        // it should still have 2 entries in the ledger and unconsumed entries index should be 1
        // in a real case scenario, the `redeem` call would have returned amount * 4 (since pps is doubled now)
        // however, in this case, it returns ~amount * 2 (as pps for real Yearn is 1.06$), so we're left with 1
        // unconsumed entry
        _executeThroughEntrypoint(nexusAccount, entry);
    }

    function test_ValidateFees_TwoEntries_And_FullWithdrawalWithOneTx_Yearn() public {
        uint256 amount = SMALL; // fixed amount to test the fee and consumed entries easily

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            ledgerConfig.getYieldSourceOracleConfig(_getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)));
        assertEq(config.feePercent, 100); //1%

        // create and fund
        address nexusAccount = _setupNexusAccount(amount);

        // prepare execution entry
        ISuperExecutor.ExecutorEntry memory entry = _prepareDepositExecutorEntry(amount);

        // execute and validate first deposit
        _executeThroughEntrypoint(nexusAccount, entry);

        // execute and validate second deposit
        _getTokens(underlying, nexusAccount, amount);
        _executeThroughEntrypoint(nexusAccount, entry);

        // Check before withdrawal fees
        uint256 feeBalanceBefore = IERC20(underlying).balanceOf(config.feeRecipient);
        assertEq(feeBalanceBefore, 0);

        // add funds for accounting fees (as `convertToAssets` result is mocked above)
        _getTokens(underlying, nexusAccount, amount);

        // withdraw everything
        uint256 availableShares = yearnVault.balanceOf(nexusAccount);
        entry = _prepareWithdrawExecutorEntry(availableShares, nexusAccount);

        // execute and validate
        // it should still have 2 entries in the ledger and unconsumed entries index should be 1
        // in a real case scenario, the `redeem` call would have returned amount * 4 (since pps is doubled now)
        // however, in this case, it returns ~amount * 2 (as pps for real Yearn is 1.06$), so we're left with 1
        // unconsumed entry
        _executeThroughEntrypoint(nexusAccount, entry);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _setupNexusAccount(uint256 amount) private returns (address nexusAccount) {
        nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
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
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        hooksData[0] = _createApproveHookData(underlying, address(yearnVault), amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(yearnVault), amount, false, address(0), 0
        );
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }

    function _prepareWithdrawExecutorEntry(
        uint256 amount,
        address account
    )
        private
        view
        returns (ISuperExecutor.ExecutorEntry memory entry)
    {
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = redeem4626Hook;
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(yearnVault), account, amount, false
        );
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }

    function _mockPricePerShareDouble() private {
        uint256 pricePerShareTwo = oracle.getPricePerShare(address(yearnVault));
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ERC4626YieldSourceOracle.getPricePerShare.selector, address(yearnVault)),
            abi.encode(pricePerShareTwo * 2)
        );
    }
}
