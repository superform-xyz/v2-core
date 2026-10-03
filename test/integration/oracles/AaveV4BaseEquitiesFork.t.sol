// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { AaveV4ReserveRegistryV2 } from "../../../src/accounting/oracles/AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveOracle } from "../../../src/accounting/oracles/AaveV4ReserveOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4BaseEquitiesFork
/// @notice Compatibility review of both legs of the Aave V4 reserve oracle against the LIVE Base equities deployment
///         (aave-address-book AaveV4Base: MAG7_SPOKE + 7 tokenized stocks at 8 decimals + USDC at 6).
///         The PR's existing fork tests target the Ethereum spoke (WETH/USDC, 18/6 decimals); this
///         file re-runs the same surface against the equities spoke.
contract AaveV4BaseEquitiesFork is Test {
    // aave-address-book / AaveV4Base.sol
    address internal constant MAG7_SPOKE = 0x17905Db0e4A3514467539956c084180616AE7B8D;
    address internal constant EQUITIES_HUB = 0xa4d5947Eb727A052bae69C593FfC84247EC9864E;
    address internal constant TOKENIZATION_SPOKE = 0x7081CE7EB1282c53CF38EA9B622f6269cb8FeFDc;
    address internal constant AAPLc = 0xb200000000000000000000C2e324d24d7eEcd1fb;
    address internal constant TSLAc = 0xb2000000000000000000001e800a7f5189430cD0;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal constant AAPL_ID = 0;
    uint256 internal constant TSLA_ID = 6;
    uint256 internal constant USDC_ID = 7;
    uint256 internal constant UNLISTED_ID = 8;

    /// @dev live positions on the MAG7 spoke at the pinned block
    address internal constant BORROWER = 0x26D595DdDbAd81Bf976eF6f24686a12A800b141F; // equities + USDC debt
    address internal constant WHALE = 0x9e3787f9f7f0fF7Eea9e36628BecA431B61AE647; // large equity supplier

    uint256 internal constant FORK_BLOCK = 51_778_000;

    AaveV4ReserveRegistryV2 internal registry;
    AaveV4ReserveOracle internal oracle;

    address internal aaplKey;
    address internal aaplDebtKey;
    address internal tslaKey;
    address internal usdcKey;
    address internal usdcDebtKey;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);
        registry = new AaveV4ReserveRegistryV2(address(this));
        // a non-zero SuperLedgerConfiguration is all the constructor requires
        oracle = new AaveV4ReserveOracle(address(0xC0FFEE), address(registry));

        (aaplKey, aaplDebtKey) = registry.registerReserve(MAG7_SPOKE, AAPL_ID);
        (tslaKey,) = registry.registerReserve(MAG7_SPOKE, TSLA_ID);
        (usdcKey, usdcDebtKey) = registry.registerReserve(MAG7_SPOKE, USDC_ID);
    }

    /*//////////////////////////////////////////////////////////////
                              REGISTRY
    //////////////////////////////////////////////////////////////*/

    /// @notice The vendored Reserve struct decodes the live equities spoke; bindings match the address book.
    function test_Registry_BindsEquitiesReserves() public view {
        (address spoke, uint256 id, address underlying, uint8 dec, AaveV4ReserveRegistryV2.Side side) =
            registry.getReserveInfo(aaplKey);
        assertEq(spoke, MAG7_SPOKE);
        assertEq(id, AAPL_ID);
        assertEq(underlying, AAPLc, "AAPLc underlying");
        assertEq(dec, 8, "tokenized stocks are 8 decimals");
        assertTrue(side == AaveV4ReserveRegistryV2.Side.SUPPLY, "legacy key is the supply leg");

        (,, address u7, uint8 d7,) = registry.getReserveInfo(usdcKey);
        assertEq(u7, USDC, "USDC underlying");
        assertEq(d7, 6, "USDC is 6 decimals");

        // the debt leg of the same reserve shares the binding and differs only in its side
        (address dSpoke, uint256 dId, address dU, uint8 dDec, AaveV4ReserveRegistryV2.Side dSide) =
            registry.getReserveInfo(usdcDebtKey);
        assertEq(dSpoke, MAG7_SPOKE);
        assertEq(dId, USDC_ID);
        assertEq(dU, USDC);
        assertEq(dDec, 6);
        assertTrue(dSide == AaveV4ReserveRegistryV2.Side.DEBT, "domain-separated key is the debt leg");

        // every reserve on this spoke shares one hub
        assertEq(IAaveV4Spoke(MAG7_SPOKE).getReserve(AAPL_ID).hub, EQUITIES_HUB);
    }

    /// @notice Registration validation still works: an unlisted id reverts inside the spoke.
    function test_Registry_UnlistedReserveReverts() public {
        vm.expectRevert();
        registry.registerReserve(MAG7_SPOKE, UNLISTED_ID);
    }

    /// @notice The tokenization spoke (waEquitiesUSDC) is NOT a plain spoke: registration reverts.
    function test_Registry_TokenizationSpokeUnsupported() public {
        vm.expectRevert();
        registry.registerReserve(TOKENIZATION_SPOKE, 0);
    }

    /// @notice Proves the other half of that claim (review R3 N5): the tokenization spoke IS covered by the
    ///         existing `ERC4626YieldSourceOracle`. It is a live ERC4626 over USDC, so the whole view surface
    ///         works on it — including after a real deposit, which is fully fork-executable because USDC is an
    ///         ordinary contract. This is the SuperStocksUSDC lending route; no new oracle is needed for it.
    function test_TokenizationSpoke_CoveredByErc4626Oracle() public {
        ERC4626YieldSourceOracle erc4626Oracle = new ERC4626YieldSourceOracle(address(0xC0FFEE));
        IERC4626 vault = IERC4626(TOKENIZATION_SPOKE);

        assertEq(vault.asset(), USDC, "wrapper over USDC");
        assertEq(erc4626Oracle.decimals(TOKENIZATION_SPOKE), 6);
        assertEq(
            erc4626Oracle.getPricePerShare(TOKENIZATION_SPOKE), vault.convertToAssets(1e6), "PPS via convertToAssets"
        );
        assertEq(erc4626Oracle.getTVL(TOKENIZATION_SPOKE), vault.totalAssets(), "TVL == totalAssets");

        address user = makeAddr("stocksUsdcLender");
        uint256 amount = 1000e6;
        assertEq(erc4626Oracle.getBalanceOfOwner(TOKENIZATION_SPOKE, user), 0, "no position yet");

        uint256 tvlBefore = erc4626Oracle.getTVL(TOKENIZATION_SPOKE);
        deal(USDC, user, amount);
        vm.startPrank(user);
        IERC20(USDC).approve(TOKENIZATION_SPOKE, amount);
        uint256 shares = vault.deposit(amount, user);
        vm.stopPrank();

        assertGt(shares, 0, "real deposit minted shares");
        assertEq(erc4626Oracle.getBalanceOfOwner(TOKENIZATION_SPOKE, user), shares, "oracle sees the share balance");
        assertApproxEqAbs(
            erc4626Oracle.getTVLByOwnerOfShares(TOKENIZATION_SPOKE, user), amount, 1, "owner TVL in USDC terms"
        );
        assertApproxEqAbs(erc4626Oracle.getTVL(TOKENIZATION_SPOKE), tvlBefore + amount, 1, "reserve TVL grew");

        // and the Aave registry still refuses it, so the two routes can never be confused
        vm.expectRevert();
        registry.registerReserve(TOKENIZATION_SPOKE, 0);
    }

    /*//////////////////////////////////////////////////////////////
                             SUPPLY LEG
    //////////////////////////////////////////////////////////////*/

    /// @notice decimals + PPS are the 8-decimal identity for stocks, 6 for USDC.
    function test_Supply_DecimalsAndPps() public view {
        assertEq(oracle.decimals(aaplKey), 8);
        assertEq(oracle.getPricePerShare(aaplKey), 1e8, "identity PPS at 8 decimals");
        assertEq(oracle.decimals(usdcKey), 6);
        assertEq(oracle.getPricePerShare(usdcKey), 1e6);
    }

    /// @notice Live balances and TVL match the spoke reads exactly, for a real equities position.
    function test_Supply_LiveBalancesMatchSpoke() public view {
        uint256 oracleBal = oracle.getBalanceOfOwner(aaplKey, WHALE);
        uint256 spokeBal = IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(AAPL_ID, WHALE);
        assertEq(oracleBal, spokeBal, "AAPLc supplied balance");
        assertGt(oracleBal, 0, "whale has a live AAPLc position");
        assertEq(oracle.getTVLByOwnerOfShares(aaplKey, WHALE), spokeBal, "identity: TVL == balance");

        assertEq(
            oracle.getTVL(aaplKey),
            IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(AAPL_ID),
            "reserve-level AAPLc TVL"
        );
        assertGt(oracle.getTVL(aaplKey), 0);
        // the borrower's collateral leg is visible too
        assertEq(
            oracle.getBalanceOfOwner(tslaKey, BORROWER),
            IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(TSLA_ID, BORROWER)
        );
    }

    /// @notice THE EQUITY TOKENS ARE NODE-NATIVE: their account code on Base is a single 0xEF byte, so the live
    ///         chain answers ERC20 calls but a standard EVM cannot execute them. Any direct token call reverts
    ///         in-fork. The oracles are unaffected because they never touch the underlying — decimals come from
    ///         the spoke's Reserve struct at registration, balances from spoke views.
    function test_EquityTokenIsNodeNative_OraclesUnaffected() public {
        assertEq(AAPLc.code.length, 1, "1 byte of code");
        assertEq(AAPLc.code[0], bytes1(0xEF), "0xEF: reserved by EIP-3541, not executable");

        (bool ok,) = AAPLc.staticcall(abi.encodeWithSignature("decimals()"));
        assertFalse(ok, "direct ERC20 call is not fork-executable");

        // yet the whole oracle surface works, because it never calls the token
        assertEq(oracle.decimals(aaplKey), 8);
        assertEq(oracle.getPricePerShare(aaplKey), 1e8);
        assertGt(oracle.getBalanceOfOwner(aaplKey, WHALE), 0);
        assertGt(oracle.getTVL(aaplKey), 0);
    }

    /// @notice With a normal ERC20 etched at the equity address, a REAL withdrawal moves the oracle by exactly the
    ///         spoke-reported delta — isolating oracle correctness at 8 decimals from the token's node-native form.
    function test_Supply_TracksRealWithdrawal_EquityTokenEtched() public {
        MockERC20 mock = new MockERC20("Apple Inc.", "AAPLc", 8);
        vm.etch(AAPLc, address(mock).code);
        deal(AAPLc, MAG7_SPOKE, 1_000_000e8);
        deal(AAPLc, EQUITIES_HUB, 1_000_000e8);

        uint256 before_ = oracle.getBalanceOfOwner(aaplKey, WHALE);
        uint256 tvlBefore = oracle.getTVL(aaplKey);

        vm.prank(WHALE);
        (, uint256 assets) = IAaveV4Spoke(MAG7_SPOKE).withdraw(AAPL_ID, 1e8, WHALE);
        assertEq(assets, 1e8, "withdrew 1 AAPLc (8 decimals)");

        assertEq(oracle.getBalanceOfOwner(aaplKey, WHALE), before_ - assets, "owner balance delta");
        assertEq(oracle.getTVL(aaplKey), tvlBefore - assets, "reserve TVL delta");
        assertEq(IERC20(AAPLc).balanceOf(WHALE), assets, "assets really left in token units");
    }

    /// @notice The USDC leg is an ordinary contract, so a real supply is fully fork-executable and the oracle
    ///         tracks it at 6 decimals.
    function test_Supply_TracksRealSupply_Usdc() public {
        address user = makeAddr("supplier");
        uint256 amount = 1000e6;
        deal(USDC, user, amount);

        uint256 tvlBefore = oracle.getTVL(usdcKey);
        vm.startPrank(user);
        IERC20(USDC).approve(MAG7_SPOKE, amount);
        (, uint256 assets) = IAaveV4Spoke(MAG7_SPOKE).supply(USDC_ID, amount, user);
        vm.stopPrank();

        assertEq(assets, amount, "supply() reports the full amount");

        // ROUNDING: Aave V4 converts assets->shares->assets rounding DOWN (toAddedAssetsDown), so the position
        // view reads 1 wei BELOW what supply() returned. The oracle passes the source value through unmodified
        // (documented in its NatSpec); consumers must not assume supply() return == subsequent balance read.
        uint256 seen = oracle.getBalanceOfOwner(usdcKey, user);
        assertLe(seen, amount, "never over-reports what the supplier can claim");
        assertApproxEqAbs(seen, amount, 1, "within source rounding");
        assertEq(seen, 999_999_999, "exact observed value: 1 wei round-down");
        assertApproxEqAbs(oracle.getTVL(usdcKey), tvlBefore + amount, 1, "reserve TVL grew");
        assertEq(oracle.getPricePerShare(usdcKey), 1e6);
    }

    /// @notice Identity converters are unit-preserving at 8 decimals (no 18-decimal assumption anywhere).
    function test_Supply_IdentityConvertersAt8Decimals() public view {
        uint256 amt = 12_345_678; // 0.12345678 AAPLc
        assertEq(oracle.getShareOutput(aaplKey, AAPLc, amt), amt);
        assertEq(oracle.getAssetOutput(aaplKey, AAPLc, amt), amt);
        assertEq(oracle.getWithdrawalShareOutput(aaplKey, AAPLc, amt), amt);
        assertEq(oracle.getAssetOutputWithFees(bytes32(0), aaplKey, AAPLc, address(0), amt), amt);
    }

    /*//////////////////////////////////////////////////////////////
                              DEBT LEG
    //////////////////////////////////////////////////////////////*/

    /// @notice The live USDC borrow against equities collateral reads correctly.
    function test_Debt_LiveBorrowMatchesSpoke() public view {
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(oracle.getBalanceOfOwner(usdcDebtKey, BORROWER), drawn + premium, "drawn + premium");
        assertGt(drawn, 0, "borrower has live USDC debt");
        assertEq(oracle.decimals(usdcDebtKey), 6);
        assertEq(oracle.getPricePerShare(usdcDebtKey), 1e6);

        (uint256 rd, uint256 rp) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(USDC_ID);
        assertEq(oracle.getTVL(usdcDebtKey), rd + rp, "reserve-level debt");
    }

    /// @notice Equity reserves carry no debt on this spoke — the debt key reads a clean zero, not a revert.
    function test_Debt_EquityReservesReadZero() public view {
        assertEq(oracle.getBalanceOfOwner(aaplDebtKey, BORROWER), 0);
        assertEq(oracle.getTVL(aaplDebtKey), 0, "stocks are collateral-only here");
    }

    /// @notice Debt accrues in-view over time on the equities spoke (hub index is live).
    function test_Debt_AccruesOverTime() public {
        uint256 before_ = oracle.getBalanceOfOwner(usdcDebtKey, BORROWER);
        vm.warp(block.timestamp + 30 days);
        assertGt(oracle.getBalanceOfOwner(usdcDebtKey, BORROWER), before_, "debt grows without any action");
    }

    /*//////////////////////////////////////////////////////////////
                      CROSS-ASSET DENOMINATION
    //////////////////////////////////////////////////////////////*/

    /// @notice DOCUMENTS the denomination gap: for one leveraged position the two legs return values in
    ///         two different assets and two different decimal bases (AAPLc 8dp vs USDC 6dp). The oracle never
    ///         converts; a consumer naively subtracting them gets a meaningless number.
    function test_CrossAsset_UnitsAreNotComparable() public view {
        uint256 collateral = oracle.getBalanceOfOwner(tslaKey, BORROWER); // TSLAc, 8 decimals
        uint256 debt = oracle.getBalanceOfOwner(usdcDebtKey, BORROWER); // USDC, 6 decimals
        assertGt(collateral, 0);
        assertGt(debt, 0);
        assertEq(oracle.decimals(tslaKey), 8);
        assertEq(oracle.decimals(usdcDebtKey), 6);
        // no price feed exists in the oracle: equity price must come from MAG7_SPOKE_ORACLE externally
    }

    /// @notice Unregistered keys revert rather than returning zero, on both legs' derivations.
    function test_UnregisteredKeyReverts() public {
        address ghost = registry.computeReserveKey(MAG7_SPOKE, UNLISTED_ID);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getBalanceOfOwner(ghost, WHALE);
        address ghostDebt = registry.computeDebtKey(MAG7_SPOKE, UNLISTED_ID);
        vm.expectRevert(AaveV4ReserveRegistryV2.RESERVE_NOT_REGISTERED.selector);
        oracle.getTVL(ghostDebt);
    }
}
