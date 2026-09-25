// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { ERC20YieldSourceOracle } from "../../../../src/accounting/oracles/ERC20YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../../src/accounting/SuperLedger.sol";
import { FlatFeeLedger } from "../../../../src/accounting/FlatFeeLedger.sol";
import { ISuperLedgerConfiguration } from "../../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { IYieldSourceOracle } from "../../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";

/// @dev Ledger mock modeling the misconfiguration hazard: plain ERC20 holdings never snapshot
///      cost basis, so a fee-charging ledger sees the entire amount as profit.
contract MockZeroCostBasisLedger {
    function previewFees(
        address,
        address,
        uint256 amountAssets,
        uint256,
        uint256 feePercent,
        uint256,
        uint256
    )
        external
        pure
        returns (uint256)
    {
        return amountAssets * feePercent / 10_000;
    }
}

/// @dev Minimal rebasing token: balances scale with a settable multiplier. Used only to make the
///      "rebasing tokens are OUT of scope" declaration executable — the oracle passes the drift
///      through faithfully.
contract MockRebasingERC20 {
    uint256 public multiplierBps = 10_000;
    mapping(address holder => uint256 shares) internal _shares;
    uint256 internal _totalShares;

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function setMultiplierBps(uint256 bps) external {
        multiplierBps = bps;
    }

    function mintShares(address to, uint256 shares) external {
        _shares[to] += shares;
        _totalShares += shares;
    }

    function balanceOf(address holder) external view returns (uint256) {
        return _shares[holder] * multiplierBps / 10_000;
    }

    function totalSupply() external view returns (uint256) {
        return _totalShares * multiplierBps / 10_000;
    }
}

contract ERC20YieldSourceOracleTest is Test {
    ERC20YieldSourceOracle public oracle;
    address public ledgerConfig;

    MockERC20 public token6; // e.g. USDC-style
    MockERC20 public token18; // e.g. NVDAb-style (BSC B-tokens are 18 decimals)

    address public account1 = makeAddr("account1");
    address public account2 = makeAddr("account2");

    function setUp() public {
        ledgerConfig = address(new SuperLedgerConfiguration());
        oracle = new ERC20YieldSourceOracle(ledgerConfig);

        token6 = new MockERC20("USD Coin", "USDC", 6);
        token18 = new MockERC20("NVIDIA (tokenized)", "NVDAb", 18);

        token6.mint(account1, 500e6);
        token6.mint(account2, 1200e6);
        token18.mint(account1, 2 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsSuperLedgerConfiguration() public view {
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert(ERC20YieldSourceOracle.ZERO_ADDRESS.selector);
        new ERC20YieldSourceOracle(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                                DECIMALS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_passthrough() public view {
        assertEq(oracle.decimals(address(token6)), 6);
        assertEq(oracle.decimals(address(token18)), 18);
    }

    function test_decimals_8decimalToken() public {
        MockERC20 token8 = new MockERC20("Wrapped BTC", "WBTC", 8);
        assertEq(oracle.decimals(address(token8)), 8);
    }

    /*//////////////////////////////////////////////////////////////
                            getPricePerShare
    //////////////////////////////////////////////////////////////*/

    function test_getPricePerShare_identityInTokenDecimals() public view {
        assertEq(oracle.getPricePerShare(address(token6)), 1e6);
        assertEq(oracle.getPricePerShare(address(token18)), 1e18);
    }

    function test_getPricePerShare_77decimals_maxSafe() public {
        MockERC20 token77 = new MockERC20("Weird", "W77", 77);
        assertEq(oracle.getPricePerShare(address(token77)), 10 ** 77);
    }

    function test_getPricePerShare_revertsAt78Decimals() public {
        MockERC20 token78 = new MockERC20("Weird", "W78", 78);
        vm.expectRevert(); // checked-arithmetic overflow in 10 ** 78
        oracle.getPricePerShare(address(token78));
    }

    /*//////////////////////////////////////////////////////////////
                          IDENTITY CONVERTERS
    //////////////////////////////////////////////////////////////*/

    function test_identity_converters() public view {
        assertEq(oracle.getShareOutput(address(token6), address(0), 500e6), 500e6);
        assertEq(oracle.getWithdrawalShareOutput(address(token6), address(0), 500e6), 500e6);
        assertEq(oracle.getAssetOutput(address(token6), address(0), 500e6), 500e6);
    }

    function test_identity_convertersAnswerForAnyAddress() public {
        // Pure identity: even non-token addresses answer (documented — cannot probe validity)
        address notAToken = makeAddr("notAToken");
        assertEq(oracle.getShareOutput(notAToken, address(0), 1 ether), 1 ether);
        assertEq(oracle.getAssetOutput(notAToken, address(0), 1 ether), 1 ether);
    }

    function test_identity_roundTrip() public view {
        uint256 amount = 123_456e6;
        uint256 shares = oracle.getShareOutput(address(token6), address(0), amount);
        assertEq(oracle.getAssetOutput(address(token6), address(0), shares), amount);
    }

    function test_fuzz_identity_assetInIgnored(address token, address assetIn, uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);
        assertEq(oracle.getShareOutput(token, assetIn, amount), amount);
        assertEq(oracle.getWithdrawalShareOutput(token, assetIn, amount), amount);
        assertEq(oracle.getAssetOutput(token, assetIn, amount), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        BALANCE / TVL VIEWS
    //////////////////////////////////////////////////////////////*/

    function test_getBalanceOfOwner_tracksBalanceOf() public view {
        assertEq(oracle.getBalanceOfOwner(address(token6), account1), 500e6);
        assertEq(oracle.getBalanceOfOwner(address(token6), account2), 1200e6);
        assertEq(oracle.getBalanceOfOwner(address(token18), account2), 0);
    }

    function test_getTVLByOwnerOfShares_identicalToBalance() public view {
        assertEq(
            oracle.getTVLByOwnerOfShares(address(token6), account1), oracle.getBalanceOfOwner(address(token6), account1)
        );
    }

    function test_getTVL_isGlobalTotalSupply() public view {
        assertEq(oracle.getTVL(address(token6)), 1700e6);
        assertEq(oracle.getTVL(address(token18)), 2 ether);
    }

    function test_views_trackMintBurnTransfer() public {
        token6.mint(account1, 300e6);
        assertEq(oracle.getBalanceOfOwner(address(token6), account1), 800e6);
        assertEq(oracle.getTVL(address(token6)), 2000e6);

        vm.prank(account1);
        token6.transfer(account2, 100e6);
        assertEq(oracle.getBalanceOfOwner(address(token6), account1), 700e6);
        assertEq(oracle.getBalanceOfOwner(address(token6), account2), 1300e6);
        assertEq(oracle.getTVL(address(token6)), 2000e6, "transfers do not change totalSupply");
    }

    /// @dev Sanity pin on standard tokens; hostile/misreporting tokens can violate this —
    ///      it is a mock-level invariant, not an oracle guarantee.
    function test_fuzz_invariant_tvlGteOwnerBalance(uint256 mintA, uint256 mintB) public {
        mintA = bound(mintA, 0, type(uint128).max);
        mintB = bound(mintB, 0, type(uint128).max);
        MockERC20 t = new MockERC20("T", "T", 18);
        t.mint(account1, mintA);
        t.mint(account2, mintB);
        assertGe(oracle.getTVL(address(t)), oracle.getBalanceOfOwner(address(t), account1));
        assertGe(oracle.getTVL(address(t)), oracle.getBalanceOfOwner(address(t), account2));
    }

    /*//////////////////////////////////////////////////////////////
                    getAssetOutputWithFees (BYPASS)
    //////////////////////////////////////////////////////////////*/

    /// @dev Register a config in SuperLedgerConfiguration and return the derived oracle id
    ///      (keccak256(salt, msg.sender) — msg.sender is this test contract).
    function _registerConfig(bytes32 salt, uint256 feePercent, address ledger) internal returns (bytes32) {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: feePercent,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = salt;
        SuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);
        return keccak256(abi.encodePacked(salt, address(this)));
    }

    function test_getAssetOutputWithFees_noConfig_returnsIdentity() public view {
        assertEq(oracle.getAssetOutputWithFees(bytes32("missing"), address(token6), address(0), account1, 500e6), 500e6);
    }

    /// @notice THE F1 PIN: even with a registered 10% fee against a zero-cost-basis ledger, the
    ///         override bypasses fee computation entirely — output stays identity. (Contrast:
    ///         a non-overriding oracle would inflate the output by the fee on the whole amount.)
    function test_getAssetOutputWithFees_overrideBypassesConfiguredFee_mockLedger() public {
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("ERC20_FEE_MISCONFIG"), 1000, mockLedger); // 10%

        uint256 amount = 500e6;
        assertEq(
            oracle.getAssetOutputWithFees(id, address(token6), address(0), account1, amount),
            amount,
            "bypass override must ignore the configured fee"
        );
    }

    /// @notice Same bypass proof against the real FlatFeeLedger registration (the categorically
    ///         forbidden configuration): the VIEW path stays identity regardless.
    function test_getAssetOutputWithFees_overrideBypassesConfiguredFee_flatFeeLedger() public {
        address flatLedger = address(new FlatFeeLedger(ledgerConfig, new address[](0)));
        bytes32 id = _registerConfig(keccak256("ERC20_FLATFEE_MISCONFIG"), 1000, flatLedger);

        uint256 amount = 500e6;
        assertEq(oracle.getAssetOutputWithFees(id, address(token6), address(0), account1, amount), amount);
    }

    function test_fuzz_getAssetOutputWithFees_alwaysIdentity(uint256 amount, uint256 feePercent) public {
        amount = bound(amount, 0, type(uint128).max);
        feePercent = bound(feePercent, 1, 5000); // MAX_FEE_PERCENT
        address mockLedger = address(new MockZeroCostBasisLedger());
        bytes32 id = _registerConfig(keccak256("ERC20_FEE_FUZZ"), feePercent, mockLedger);

        assertEq(oracle.getAssetOutputWithFees(id, address(token6), address(0), account1, amount), amount);
    }

    /*//////////////////////////////////////////////////////////////
                LEDGER PATH (NOT GUARDED — HAZARD DOCS)
    //////////////////////////////////////////////////////////////*/

    /// @notice MISCONFIGURATION HAZARD (pinned, executable "why" of the feePercent = 0 invariant):
    ///         the ledger accounting path does NOT route through the oracle's bypass. Registering
    ///         this oracle with FlatFeeLedger + feePercent > 0 fees the ENTIRE principal on every
    ///         outflow (cost basis hardcoded to zero).
    function test_ledgerPath_flatFeeLedger_hazard_feesFullPrincipal() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        FlatFeeLedger flatLedger = new FlatFeeLedger(ledgerConfig, executors);
        bytes32 id = _registerConfig(keccak256("ERC20_FLATFEE_HAZARD"), 1000, address(flatLedger)); // 10%

        uint256 amount = 1000e6;
        uint256 feeAmount = flatLedger.updateAccounting(account1, address(token6), id, false, amount, amount);

        assertEq(feeAmount, amount * 1000 / 10_000, "FlatFeeLedger fees the FULL principal");
    }

    /// @notice With the REAL SuperLedger and no snapshots (plain ERC20 holdings never snapshot),
    ///         cost-basis shares truncate to zero and the outflow fee is zero — the ledger path
    ///         is benign only emergently, which is why the invariant must stay anchored.
    function test_ledgerPath_realSuperLedger_noSnapshot_zeroFee() public {
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        SuperLedger realLedger = new SuperLedger(ledgerConfig, executors);
        bytes32 id = _registerConfig(keccak256("ERC20_REAL_LEDGER"), 1000, address(realLedger));

        uint256 amount = 1000e6;
        uint256 feeAmount = realLedger.updateAccounting(account1, address(token6), id, false, amount, amount);

        assertEq(feeAmount, 0, "no snapshots -> zero cost-basis shares -> zero fee");
    }

    /*//////////////////////////////////////////////////////////////
                          NON-ERC20 INPUTS
    //////////////////////////////////////////////////////////////*/

    function test_decimals_revertsForEOA() public {
        vm.expectRevert();
        oracle.decimals(makeAddr("someEOA"));
    }

    function test_getPricePerShare_revertsForEOA() public {
        vm.expectRevert();
        oracle.getPricePerShare(makeAddr("someEOA"));
    }

    function test_getBalanceOfOwner_revertsForNonERC20Contract() public {
        // the ledger config contract implements none of the ERC20 surface
        vm.expectRevert();
        oracle.getBalanceOfOwner(ledgerConfig, account1);
    }

    function test_getTVL_revertsForNonERC20Contract() public {
        vm.expectRevert();
        oracle.getTVL(ledgerConfig);
    }

    /*//////////////////////////////////////////////////////////////
                            BATCH BEHAVIOR
    //////////////////////////////////////////////////////////////*/

    function test_getTVLByOwnerOfSharesMultiple_failureIsolation() public view {
        address[] memory sources = new address[](2);
        sources[0] = address(token6);
        sources[1] = address(0xdead); // EOA — balanceOf reverts
        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = account1;
        owners[1] = new address[](1);
        owners[1][0] = account1;

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);

        assertEq(tvls[0][0], 500e6, "valid entry unaffected");
        assertTrue(succeeded[0][0]);
        assertEq(tvls[1][0], 0);
        assertFalse(succeeded[1][0], "broken entry isolated");
    }

    function test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch() public {
        address[] memory sources = new address[](2);
        address[][] memory owners = new address[][](1);
        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
    }

    /// @notice KNOWN ISSUE (inherited): getPricePerShareMultiple / getTVLMultiple have no
    ///         per-entry isolation — one non-token entry aborts the whole batch.
    function test_batch_ppsAndTvlMultiple_knownIssue_abortOnNonToken() public {
        address[] memory sources = new address[](2);
        sources[0] = address(token6);
        sources[1] = makeAddr("nonToken");

        vm.expectRevert();
        oracle.getPricePerShareMultiple(sources);
        vm.expectRevert();
        oracle.getTVLMultiple(sources);
    }

    function test_batch_duplicateEntries_returnedDuplicated() public view {
        address[] memory sources = new address[](2);
        sources[0] = address(token6);
        sources[1] = address(token6);
        uint256[] memory tvls = oracle.getTVLMultiple(sources);
        assertEq(tvls[0], tvls[1], "dedup is the caller's job");
    }

    /*//////////////////////////////////////////////////////////////
                    REBASING (OUT OF SCOPE — DOCUMENTED)
    //////////////////////////////////////////////////////////////*/

    /// @notice Executable form of the out-of-scope declaration: the oracle passes rebases through
    ///         faithfully, so a rebase (e.g. a stock split implemented as balance redenomination)
    ///         shifts reported balances between off-chain price snapshots. Whitelisters must
    ///         confirm the issuer's corporate-action mechanism before adding a token.
    function test_rebasingToken_documentedDrift() public {
        MockRebasingERC20 rebasing = new MockRebasingERC20();
        rebasing.mintShares(account1, 100 ether);

        assertEq(oracle.getBalanceOfOwner(address(rebasing), account1), 100 ether);

        rebasing.setMultiplierBps(20_000); // 2x "split"
        assertEq(oracle.getBalanceOfOwner(address(rebasing), account1), 200 ether, "rebase passes through, undefended");
        assertEq(oracle.getTVL(address(rebasing)), 200 ether);
    }
}
