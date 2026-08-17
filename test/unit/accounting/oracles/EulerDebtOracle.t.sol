// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { EulerDebtOracle } from "../../../../src/accounting/oracles/EulerDebtOracle.sol";
import { IEVault } from "../../../../src/vendor/euler/IEVault.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";

contract EulerDebtOracleTest is Test {
    EulerDebtOracle public oracle;
    address public ledgerConfig;

    address public vault6 = makeAddr("eulerVault6");
    address public vault18 = makeAddr("eulerVault18");
    address public account1 = makeAddr("account1");
    address public account2 = makeAddr("account2");

    function setUp() public {
        ledgerConfig = address(new SuperLedgerConfiguration());
        oracle = new EulerDebtOracle(ledgerConfig);

        // Default mocks for 6-decimal vault (e.g. USDC)
        vm.mockCall(vault6, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(6)));
        vm.mockCall(vault6, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(uint256(500e6)));
        vm.mockCall(vault6, abi.encodeCall(IEVault.debtOf, (account2)), abi.encode(uint256(1200e6)));
        vm.mockCall(vault6, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(uint256(1_000_000e6)));

        // Default mocks for 18-decimal vault (e.g. WETH)
        vm.mockCall(vault18, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(18)));
        vm.mockCall(vault18, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(uint256(2 ether)));
        vm.mockCall(vault18, abi.encodeCall(IEVault.debtOf, (account2)), abi.encode(uint256(0)));
        vm.mockCall(vault18, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(uint256(50_000 ether)));
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsSuperLedgerConfiguration() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_6decimals() public view {
        assertEq(oracle.decimals(vault6), 6);
    }

    function test_decimals_18decimals() public view {
        assertEq(oracle.decimals(vault18), 18);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE PER SHARE
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_6decimals() public view {
        assertEq(oracle.getPricePerShare(vault6), 1e6);
    }

    function test_getPricePerShare_18decimals() public view {
        assertEq(oracle.getPricePerShare(vault18), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    IDENTITY CONVERSIONS
    //////////////////////////////////////////////////////////////*/

    function test_getShareOutput_identity() public view {
        uint256 amount = 1000e6;
        assertEq(oracle.getShareOutput(vault6, address(0), amount), amount);
    }

    function test_getWithdrawalShareOutput_identity() public view {
        uint256 amount = 5 ether;
        assertEq(oracle.getWithdrawalShareOutput(vault18, address(0), amount), amount);
    }

    function test_getAssetOutput_identity() public view {
        uint256 amount = 777e6;
        assertEq(oracle.getAssetOutput(vault6, address(0), amount), amount);
    }

    /*//////////////////////////////////////////////////////////////
                    BALANCE / DEBT TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner_returnsDebtOf() public view {
        assertEq(oracle.getBalanceOfOwner(vault6, account1), 500e6);
    }

    function test_getBalanceOfOwner_zeroDebt() public view {
        assertEq(oracle.getBalanceOfOwner(vault18, account2), 0);
    }

    function test_getBalanceOfOwner_multipleAccounts() public view {
        assertEq(oracle.getBalanceOfOwner(vault6, account1), 500e6);
        assertEq(oracle.getBalanceOfOwner(vault6, account2), 1200e6);
    }

    /*//////////////////////////////////////////////////////////////
                    TVL BY OWNER
    //////////////////////////////////////////////////////////////*/

    function test_getTVLByOwnerOfShares_returnsDebtOf() public view {
        assertEq(oracle.getTVLByOwnerOfShares(vault6, account1), 500e6);
    }

    function test_getTVLByOwnerOfShares_zeroDebt() public view {
        assertEq(oracle.getTVLByOwnerOfShares(vault18, account2), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            TVL
    //////////////////////////////////////////////////////////////*/

    function test_getTVL_returnsTotalBorrows() public view {
        assertEq(oracle.getTVL(vault6), 1_000_000e6);
    }

    function test_getTVL_18decimals() public view {
        assertEq(oracle.getTVL(vault18), 50_000 ether);
    }

    function test_getTVL_zeroTotalBorrows() public {
        address emptyVault = makeAddr("emptyVault");
        vm.mockCall(emptyVault, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(uint256(0)));
        assertEq(oracle.getTVL(emptyVault), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShareMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = vault6;
        vaults[1] = vault18;

        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices[0], 1e6);
        assertEq(prices[1], 1e18);
    }

    function test_getTVLByOwnerOfSharesMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = vault6;
        vaults[1] = vault18;

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](2);
        owners[0][0] = account1;
        owners[0][1] = account2;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);

        assertEq(tvls[0][0], 500e6);
        assertTrue(succeeded[0][0]);
        assertEq(tvls[0][1], 1200e6);
        assertTrue(succeeded[0][1]);
        assertEq(tvls[1][0], 2 ether);
        assertTrue(succeeded[1][0]);
    }

    function test_getTVLMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = vault6;
        vaults[1] = vault18;

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls[0], 1_000_000e6);
        assertEq(tvls[1], 50_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fuzz_getShareOutput_identity(uint256 amount) public view {
        assertEq(oracle.getShareOutput(vault6, address(0), amount), amount);
    }

    function test_fuzz_getAssetOutput_identity(uint256 amount) public view {
        assertEq(oracle.getAssetOutput(vault6, address(0), amount), amount);
    }

    function test_fuzz_getWithdrawalShareOutput_identity(uint256 amount) public view {
        assertEq(oracle.getWithdrawalShareOutput(vault18, address(0), amount), amount);
    }
}
