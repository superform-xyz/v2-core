// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { EulerDebtOracle } from "../../../../src/accounting/oracles/EulerDebtOracle.sol";
import { IYieldSourceOracle } from "../../../../src/interfaces/accounting/IYieldSourceOracle.sol";
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

    function test_constructor_zeroAddressLedgerConfig() public {
        EulerDebtOracle zeroOracle = new EulerDebtOracle(address(0));
        assertEq(zeroOracle.SUPER_LEDGER_CONFIGURATION(), address(0));
    }

    function test_constructor_multipleInstances_independentConfig() public {
        address config2 = address(new SuperLedgerConfiguration());
        EulerDebtOracle oracle2 = new EulerDebtOracle(config2);
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
        assertEq(oracle2.SUPER_LEDGER_CONFIGURATION(), config2);
        assertTrue(ledgerConfig != config2);
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

    function test_decimals_0decimals() public {
        address vault0 = makeAddr("vault0dec");
        vm.mockCall(vault0, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(0)));
        assertEq(oracle.decimals(vault0), 0);
    }

    function test_decimals_8decimals() public {
        address vault8 = makeAddr("vault8dec");
        vm.mockCall(vault8, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(8)));
        assertEq(oracle.decimals(vault8), 8);
    }

    function test_decimals_24decimals() public {
        address vault24 = makeAddr("vault24dec");
        vm.mockCall(vault24, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(24)));
        assertEq(oracle.decimals(vault24), 24);
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

    function test_getPricePerShare_0decimals() public {
        address vault0 = makeAddr("vault0dec");
        vm.mockCall(vault0, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(0)));
        assertEq(oracle.getPricePerShare(vault0), 1); // 10^0 = 1
    }

    function test_getPricePerShare_8decimals() public {
        address vault8 = makeAddr("vault8dec");
        vm.mockCall(vault8, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(8)));
        assertEq(oracle.getPricePerShare(vault8), 1e8);
    }

    function test_getPricePerShare_24decimals() public {
        address vault24 = makeAddr("vault24dec");
        vm.mockCall(vault24, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(24)));
        assertEq(oracle.getPricePerShare(vault24), 1e24);
    }

    /// @notice 10^77 fits in uint256, 10^78 overflows — verify revert
    function test_getPricePerShare_revertsAt78Decimals() public {
        address vaultBig = makeAddr("vault78dec");
        vm.mockCall(vaultBig, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(78)));
        vm.expectRevert(); // arithmetic overflow
        oracle.getPricePerShare(vaultBig);
    }

    function test_getPricePerShare_77decimals_maxSafe() public {
        address vault77 = makeAddr("vault77dec");
        vm.mockCall(vault77, abi.encodeCall(IEVault.decimals, ()), abi.encode(uint8(77)));
        assertEq(oracle.getPricePerShare(vault77), 10 ** 77);
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

    function test_getShareOutput_zero() public view {
        assertEq(oracle.getShareOutput(vault6, address(0), 0), 0);
    }

    function test_getWithdrawalShareOutput_zero() public view {
        assertEq(oracle.getWithdrawalShareOutput(vault6, address(0), 0), 0);
    }

    function test_getAssetOutput_zero() public view {
        assertEq(oracle.getAssetOutput(vault6, address(0), 0), 0);
    }

    function test_getShareOutput_maxUint256() public view {
        assertEq(oracle.getShareOutput(vault6, address(0), type(uint256).max), type(uint256).max);
    }

    function test_getAssetOutput_maxUint256() public view {
        assertEq(oracle.getAssetOutput(vault6, address(0), type(uint256).max), type(uint256).max);
    }

    function test_getWithdrawalShareOutput_maxUint256() public view {
        assertEq(oracle.getWithdrawalShareOutput(vault6, address(0), type(uint256).max), type(uint256).max);
    }

    function test_getShareOutput_1wei() public view {
        assertEq(oracle.getShareOutput(vault6, address(0), 1), 1);
    }

    function test_getAssetOutput_1wei() public view {
        assertEq(oracle.getAssetOutput(vault6, address(0), 1), 1);
    }

    /// @notice Identity round-trip: getShareOutput(getAssetOutput(x)) == x
    function test_identity_roundTrip() public view {
        uint256 amount = 12345e6;
        uint256 shares = oracle.getShareOutput(vault6, address(0), amount);
        uint256 back = oracle.getAssetOutput(vault6, address(0), shares);
        assertEq(back, amount, "Round-trip should be exact for identity mapping");
    }

    /// @notice getAssetOutput(1 unit) == getPricePerShare for identity oracle
    function test_identity_assetOutput_equalsPPS() public view {
        uint256 pps = oracle.getPricePerShare(vault6);
        uint256 oneUnit = 10 ** uint256(oracle.decimals(vault6));
        uint256 assetOut = oracle.getAssetOutput(vault6, address(0), oneUnit);
        assertEq(assetOut, pps, "getAssetOutput(1 unit) should equal PPS for identity oracle");
    }

    /// @notice getWithdrawalShareOutput == getShareOutput for identity oracle (no rounding diff)
    function test_identity_withdrawalShareOutput_equalsShareOutput() public view {
        uint256 amount = 999e6;
        uint256 shareOut = oracle.getShareOutput(vault6, address(0), amount);
        uint256 withdrawalShareOut = oracle.getWithdrawalShareOutput(vault6, address(0), amount);
        assertEq(withdrawalShareOut, shareOut, "No rounding difference for identity mapping");
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

    function test_getBalanceOfOwner_maxUint256Debt() public {
        address vaultMax = makeAddr("vaultMax");
        vm.mockCall(vaultMax, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(type(uint256).max));
        assertEq(oracle.getBalanceOfOwner(vaultMax, account1), type(uint256).max);
    }

    function test_getBalanceOfOwner_1weiDebt() public {
        address vaultMin = makeAddr("vaultMin");
        vm.mockCall(vaultMin, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(uint256(1)));
        assertEq(oracle.getBalanceOfOwner(vaultMin, account1), 1);
    }

    function test_getBalanceOfOwner_addressZeroOwner() public {
        vm.mockCall(vault6, abi.encodeCall(IEVault.debtOf, (address(0))), abi.encode(uint256(0)));
        assertEq(oracle.getBalanceOfOwner(vault6, address(0)), 0);
    }

    /// @notice getBalanceOfOwner == getTVLByOwnerOfShares for same inputs (identity PPS invariant)
    function test_getBalanceOfOwner_equalsTVLByOwner() public view {
        uint256 balance = oracle.getBalanceOfOwner(vault6, account1);
        uint256 tvl = oracle.getTVLByOwnerOfShares(vault6, account1);
        assertEq(balance, tvl, "getBalanceOfOwner should equal getTVLByOwnerOfShares");
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

    function test_getTVLByOwnerOfShares_maxUint256() public {
        address vaultMax = makeAddr("vaultMax2");
        vm.mockCall(vaultMax, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(type(uint256).max));
        assertEq(oracle.getTVLByOwnerOfShares(vaultMax, account1), type(uint256).max);
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

    function test_getTVL_maxUint256() public {
        address vaultMax = makeAddr("vaultMaxTVL");
        vm.mockCall(vaultMax, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(type(uint256).max));
        assertEq(oracle.getTVL(vaultMax), type(uint256).max);
    }

    function test_getTVL_1wei() public {
        address vaultMin = makeAddr("vaultMinTVL");
        vm.mockCall(vaultMin, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(uint256(1)));
        assertEq(oracle.getTVL(vaultMin), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    REVERT ON INVALID VAULT
    //////////////////////////////////////////////////////////////*/

    /// @notice Calling decimals with address(0) reverts (no code at zero address)
    function test_decimals_revertsOnZeroAddress() public {
        vm.expectRevert();
        oracle.decimals(address(0));
    }

    /// @notice Calling getPricePerShare with address(0) reverts
    function test_getPricePerShare_revertsOnZeroAddress() public {
        vm.expectRevert();
        oracle.getPricePerShare(address(0));
    }

    /// @notice Calling getBalanceOfOwner with zero vault reverts
    function test_getBalanceOfOwner_revertsOnZeroVault() public {
        vm.expectRevert();
        oracle.getBalanceOfOwner(address(0), account1);
    }

    /// @notice Calling getTVLByOwnerOfShares with zero vault reverts
    function test_getTVLByOwnerOfShares_revertsOnZeroVault() public {
        vm.expectRevert();
        oracle.getTVLByOwnerOfShares(address(0), account1);
    }

    /// @notice Calling getTVL with zero vault reverts
    function test_getTVL_revertsOnZeroVault() public {
        vm.expectRevert();
        oracle.getTVL(address(0));
    }

    /// @notice Calling decimals on an EOA (no code) reverts
    function test_decimals_revertsOnEOA() public {
        vm.expectRevert();
        oracle.decimals(address(0xdead));
    }

    /// @notice Calling getBalanceOfOwner on an EOA reverts
    function test_getBalanceOfOwner_revertsOnEOA() public {
        vm.expectRevert();
        oracle.getBalanceOfOwner(address(0xdead), account1);
    }

    /// @notice Calling getTVL on an EOA reverts
    function test_getTVL_revertsOnEOA() public {
        vm.expectRevert();
        oracle.getTVL(address(0xdead));
    }

    /*//////////////////////////////////////////////////////////////
                    getAssetOutputWithFees (INHERITED)
    //////////////////////////////////////////////////////////////*/

    /// @notice Without oracle config, getAssetOutputWithFees returns identity (no fee)
    function test_getAssetOutputWithFees_noConfig_returnsIdentity() public view {
        bytes32 fakeOracleId = keccak256("nonexistent");
        uint256 amount = 500e6;
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, vault6, address(0), account1, amount);
        assertEq(result, amount, "Should return identity when no config exists");
    }

    /// @notice getAssetOutputWithFees with zero shares returns 0
    function test_getAssetOutputWithFees_zeroShares() public view {
        bytes32 fakeOracleId = keccak256("nonexistent");
        uint256 result = oracle.getAssetOutputWithFees(fakeOracleId, vault6, address(0), account1, 0);
        assertEq(result, 0);
    }

    /// @notice getAssetOutputWithFees with max uint256 returns max (identity, no config)
    function test_getAssetOutputWithFees_maxUint256() public view {
        bytes32 fakeOracleId = keccak256("nonexistent");
        uint256 result =
            oracle.getAssetOutputWithFees(fakeOracleId, vault6, address(0), account1, type(uint256).max);
        assertEq(result, type(uint256).max);
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

    function test_getPricePerShareMultiple_emptyArray() public view {
        address[] memory vaults = new address[](0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 0);
    }

    function test_getPricePerShareMultiple_singleElement() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = vault6;
        uint256[] memory prices = oracle.getPricePerShareMultiple(vaults);
        assertEq(prices.length, 1);
        assertEq(prices[0], 1e6);
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

    /// @notice Mismatched array lengths should revert
    function test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch() public {
        address[] memory vaults = new address[](2);
        vaults[0] = vault6;
        vaults[1] = vault18;

        address[][] memory owners = new address[][](1); // only 1, should be 2
        owners[0] = new address[](1);
        owners[0][0] = account1;

        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
    }

    function test_getTVLByOwnerOfSharesMultiple_emptyArrays() public view {
        address[] memory vaults = new address[](0);
        address[][] memory owners = new address[][](0);

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);
        assertEq(tvls.length, 0);
        assertEq(succeeded.length, 0);
    }

    /// @notice Batch TVL by owner where one vault is invalid — should isolate failure via try/catch
    function test_getTVLByOwnerOfSharesMultiple_failureIsolation() public {
        address invalidVault = address(0xdead); // EOA, no code

        address[] memory vaults = new address[](2);
        vaults[0] = vault6; // valid
        vaults[1] = invalidVault; // invalid

        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = account1;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(vaults, owners);

        // Valid vault succeeds
        assertEq(tvls[0][0], 500e6);
        assertTrue(succeeded[0][0]);

        // Invalid vault fails gracefully
        assertEq(tvls[1][0], 0);
        assertFalse(succeeded[1][0]);
    }

    function test_getTVLMultiple() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = vault6;
        vaults[1] = vault18;

        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls[0], 1_000_000e6);
        assertEq(tvls[1], 50_000 ether);
    }

    function test_getTVLMultiple_emptyArray() public view {
        address[] memory vaults = new address[](0);
        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 0);
    }

    function test_getTVLMultiple_singleElement() public view {
        address[] memory vaults = new address[](1);
        vaults[0] = vault18;
        uint256[] memory tvls = oracle.getTVLMultiple(vaults);
        assertEq(tvls.length, 1);
        assertEq(tvls[0], 50_000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-VAULT CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice Same account can have different debt on different vaults
    function test_crossVault_differentDebts() public view {
        uint256 debt6 = oracle.getBalanceOfOwner(vault6, account1);
        uint256 debt18 = oracle.getBalanceOfOwner(vault18, account1);
        assertEq(debt6, 500e6);
        assertEq(debt18, 2 ether);
        assertTrue(debt6 != debt18, "Different vaults should return different debts");
    }

    /// @notice PPS is vault-specific (depends on decimals)
    function test_crossVault_differentPPS() public view {
        uint256 pps6 = oracle.getPricePerShare(vault6);
        uint256 pps18 = oracle.getPricePerShare(vault18);
        assertEq(pps6, 1e6);
        assertEq(pps18, 1e18);
        assertTrue(pps6 != pps18);
    }

    /*//////////////////////////////////////////////////////////////
                    MOCK STATE CHANGES
    //////////////////////////////////////////////////////////////*/

    /// @notice Simulate debt increasing (interest accrual) by updating mock
    function test_mockStateChange_debtIncrease() public {
        uint256 debtBefore = oracle.getBalanceOfOwner(vault6, account1);
        assertEq(debtBefore, 500e6);

        // Simulate interest accrual
        vm.mockCall(vault6, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(uint256(505e6)));
        uint256 debtAfter = oracle.getBalanceOfOwner(vault6, account1);
        assertEq(debtAfter, 505e6);
        assertGt(debtAfter, debtBefore);
    }

    /// @notice Simulate debt decreasing (repayment) by updating mock
    function test_mockStateChange_debtDecrease() public {
        // Repay half
        vm.mockCall(vault6, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(uint256(250e6)));
        assertEq(oracle.getBalanceOfOwner(vault6, account1), 250e6);
    }

    /// @notice Simulate debt going to zero (full repay) by updating mock
    function test_mockStateChange_debtCleared() public {
        vm.mockCall(vault6, abi.encodeCall(IEVault.debtOf, (account1)), abi.encode(uint256(0)));
        assertEq(oracle.getBalanceOfOwner(vault6, account1), 0);
        assertEq(oracle.getTVLByOwnerOfShares(vault6, account1), 0);
    }

    /// @notice Simulate totalBorrows change
    function test_mockStateChange_totalBorrowsChange() public {
        uint256 tvlBefore = oracle.getTVL(vault6);

        // Increase total borrows (new borrow)
        vm.mockCall(vault6, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(uint256(2_000_000e6)));
        uint256 tvlAfter = oracle.getTVL(vault6);

        assertGt(tvlAfter, tvlBefore);
        assertEq(tvlAfter, 2_000_000e6);
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

    /// @notice Fuzz: round-trip is always exact for identity
    function test_fuzz_identity_roundTrip(uint256 amount) public view {
        uint256 shares = oracle.getShareOutput(vault6, address(0), amount);
        uint256 back = oracle.getAssetOutput(vault6, address(0), shares);
        assertEq(back, amount);
    }

    /// @notice Fuzz: getBalanceOfOwner for any debt amount
    function test_fuzz_getBalanceOfOwner(uint256 debtAmount) public {
        address fuzzVault = makeAddr("fuzzVault");
        address fuzzAccount = makeAddr("fuzzAccount");
        vm.mockCall(fuzzVault, abi.encodeCall(IEVault.debtOf, (fuzzAccount)), abi.encode(debtAmount));
        assertEq(oracle.getBalanceOfOwner(fuzzVault, fuzzAccount), debtAmount);
    }

    /// @notice Fuzz: getTVLByOwnerOfShares == getBalanceOfOwner for any amount
    function test_fuzz_tvlByOwner_equalsBalance(uint256 debtAmount) public {
        address fuzzVault = makeAddr("fuzzVault2");
        address fuzzAccount = makeAddr("fuzzAccount2");
        vm.mockCall(fuzzVault, abi.encodeCall(IEVault.debtOf, (fuzzAccount)), abi.encode(debtAmount));
        assertEq(
            oracle.getBalanceOfOwner(fuzzVault, fuzzAccount),
            oracle.getTVLByOwnerOfShares(fuzzVault, fuzzAccount)
        );
    }

    /// @notice Fuzz: getTVL for any totalBorrows amount
    function test_fuzz_getTVL(uint256 borrows) public {
        address fuzzVault = makeAddr("fuzzVault3");
        vm.mockCall(fuzzVault, abi.encodeCall(IEVault.totalBorrows, ()), abi.encode(borrows));
        assertEq(oracle.getTVL(fuzzVault), borrows);
    }

    /// @notice Fuzz: getPricePerShare for all valid decimals 0..77
    function test_fuzz_getPricePerShare_validDecimals(uint8 decimals) public {
        vm.assume(decimals <= 77);
        address fuzzVault = makeAddr("fuzzVault4");
        vm.mockCall(fuzzVault, abi.encodeCall(IEVault.decimals, ()), abi.encode(decimals));
        assertEq(oracle.getPricePerShare(fuzzVault), 10 ** uint256(decimals));
    }

    /// @notice Fuzz: getAssetOutputWithFees returns identity when no config
    function test_fuzz_getAssetOutputWithFees_identity(uint256 amount) public view {
        bytes32 fakeId = keccak256("nope");
        assertEq(oracle.getAssetOutputWithFees(fakeId, vault6, address(0), account1, amount), amount);
    }

    /// @notice Fuzz: withdrawal and deposit share outputs are equal (identity)
    function test_fuzz_withdrawalShareOutput_equalsShareOutput(uint256 amount) public view {
        assertEq(
            oracle.getShareOutput(vault6, address(0), amount),
            oracle.getWithdrawalShareOutput(vault6, address(0), amount)
        );
    }
}
