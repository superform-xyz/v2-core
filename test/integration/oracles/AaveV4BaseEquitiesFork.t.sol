// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { AaveV4ReserveRegistry } from "../../../src/accounting/oracles/AaveV4ReserveRegistry.sol";
import { AaveV4SupplyYieldSourceOracle } from "../../../src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol";
import { AaveV4DebtOracle } from "../../../src/accounting/oracles/AaveV4DebtOracle.sol";
import { IAaveV4Spoke } from "../../../src/vendor/aave-v4/IAaveV4Spoke.sol";

/// @title AaveV4BaseEquitiesFork
/// @notice Compatibility review of both Aave V4 oracles against the LIVE Base equities deployment
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

    AaveV4ReserveRegistry internal registry;
    AaveV4SupplyYieldSourceOracle internal supplyOracle;
    AaveV4DebtOracle internal debtOracle;

    address internal aaplKey;
    address internal tslaKey;
    address internal usdcKey;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);
        registry = new AaveV4ReserveRegistry(address(this));
        // a non-zero SuperLedgerConfiguration is all the constructors require
        supplyOracle = new AaveV4SupplyYieldSourceOracle(address(0xC0FFEE), address(registry));
        debtOracle = new AaveV4DebtOracle(address(0xC0FFEE), address(registry));

        aaplKey = registry.registerReserve(MAG7_SPOKE, AAPL_ID);
        tslaKey = registry.registerReserve(MAG7_SPOKE, TSLA_ID);
        usdcKey = registry.registerReserve(MAG7_SPOKE, USDC_ID);
    }

    /*//////////////////////////////////////////////////////////////
                              REGISTRY
    //////////////////////////////////////////////////////////////*/

    /// @notice The vendored Reserve struct decodes the live equities spoke; bindings match the address book.
    function test_Registry_BindsEquitiesReserves() public view {
        (address spoke, uint256 id, address underlying, uint8 dec) = registry.getReserveInfo(aaplKey);
        assertEq(spoke, MAG7_SPOKE);
        assertEq(id, AAPL_ID);
        assertEq(underlying, AAPLc, "AAPLc underlying");
        assertEq(dec, 8, "tokenized stocks are 8 decimals");

        (,, address u7, uint8 d7) = registry.getReserveInfo(usdcKey);
        assertEq(u7, USDC, "USDC underlying");
        assertEq(d7, 6, "USDC is 6 decimals");

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

    /*//////////////////////////////////////////////////////////////
                            SUPPLY ORACLE
    //////////////////////////////////////////////////////////////*/

    /// @notice decimals + PPS are the 8-decimal identity for stocks, 6 for USDC.
    function test_Supply_DecimalsAndPps() public view {
        assertEq(supplyOracle.decimals(aaplKey), 8);
        assertEq(supplyOracle.getPricePerShare(aaplKey), 1e8, "identity PPS at 8 decimals");
        assertEq(supplyOracle.decimals(usdcKey), 6);
        assertEq(supplyOracle.getPricePerShare(usdcKey), 1e6);
    }

    /// @notice Live balances and TVL match the spoke reads exactly, for a real equities position.
    function test_Supply_LiveBalancesMatchSpoke() public view {
        uint256 oracleBal = supplyOracle.getBalanceOfOwner(aaplKey, WHALE);
        uint256 spokeBal = IAaveV4Spoke(MAG7_SPOKE).getUserSuppliedAssets(AAPL_ID, WHALE);
        assertEq(oracleBal, spokeBal, "AAPLc supplied balance");
        assertGt(oracleBal, 0, "whale has a live AAPLc position");
        assertEq(supplyOracle.getTVLByOwnerOfShares(aaplKey, WHALE), spokeBal, "identity: TVL == balance");

        assertEq(
            supplyOracle.getTVL(aaplKey),
            IAaveV4Spoke(MAG7_SPOKE).getReserveSuppliedAssets(AAPL_ID),
            "reserve-level AAPLc TVL"
        );
        assertGt(supplyOracle.getTVL(aaplKey), 0);
        // the borrower's collateral leg is visible too
        assertEq(
            supplyOracle.getBalanceOfOwner(tslaKey, BORROWER),
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
        assertEq(supplyOracle.decimals(aaplKey), 8);
        assertEq(supplyOracle.getPricePerShare(aaplKey), 1e8);
        assertGt(supplyOracle.getBalanceOfOwner(aaplKey, WHALE), 0);
        assertGt(supplyOracle.getTVL(aaplKey), 0);
    }

    /// @notice With a normal ERC20 etched at the equity address, a REAL withdrawal moves the oracle by exactly the
    ///         spoke-reported delta — isolating oracle correctness at 8 decimals from the token's node-native form.
    function test_Supply_TracksRealWithdrawal_EquityTokenEtched() public {
        MockERC20 mock = new MockERC20("Apple Inc.", "AAPLc", 8);
        vm.etch(AAPLc, address(mock).code);
        deal(AAPLc, MAG7_SPOKE, 1_000_000e8);
        deal(AAPLc, EQUITIES_HUB, 1_000_000e8);

        uint256 before_ = supplyOracle.getBalanceOfOwner(aaplKey, WHALE);
        uint256 tvlBefore = supplyOracle.getTVL(aaplKey);

        vm.prank(WHALE);
        (, uint256 assets) = IAaveV4Spoke(MAG7_SPOKE).withdraw(AAPL_ID, 1e8, WHALE);
        assertEq(assets, 1e8, "withdrew 1 AAPLc (8 decimals)");

        assertEq(supplyOracle.getBalanceOfOwner(aaplKey, WHALE), before_ - assets, "owner balance delta");
        assertEq(supplyOracle.getTVL(aaplKey), tvlBefore - assets, "reserve TVL delta");
        assertEq(IERC20(AAPLc).balanceOf(WHALE), assets, "assets really left in token units");
    }

    /// @notice The USDC leg is an ordinary contract, so a real supply is fully fork-executable and the oracle
    ///         tracks it at 6 decimals.
    function test_Supply_TracksRealSupply_Usdc() public {
        address user = makeAddr("supplier");
        uint256 amount = 1000e6;
        deal(USDC, user, amount);

        uint256 tvlBefore = supplyOracle.getTVL(usdcKey);
        vm.startPrank(user);
        IERC20(USDC).approve(MAG7_SPOKE, amount);
        (, uint256 assets) = IAaveV4Spoke(MAG7_SPOKE).supply(USDC_ID, amount, user);
        vm.stopPrank();

        assertEq(assets, amount, "supply() reports the full amount");

        // ROUNDING: Aave V4 converts assets->shares->assets rounding DOWN (toAddedAssetsDown), so the position
        // view reads 1 wei BELOW what supply() returned. The oracle passes the source value through unmodified
        // (documented in its NatSpec); consumers must not assume supply() return == subsequent balance read.
        uint256 seen = supplyOracle.getBalanceOfOwner(usdcKey, user);
        assertLe(seen, amount, "never over-reports what the supplier can claim");
        assertApproxEqAbs(seen, amount, 1, "within source rounding");
        assertEq(seen, 999_999_999, "exact observed value: 1 wei round-down");
        assertApproxEqAbs(supplyOracle.getTVL(usdcKey), tvlBefore + amount, 1, "reserve TVL grew");
        assertEq(supplyOracle.getPricePerShare(usdcKey), 1e6);
    }

    /// @notice Identity converters are unit-preserving at 8 decimals (no 18-decimal assumption anywhere).
    function test_Supply_IdentityConvertersAt8Decimals() public view {
        uint256 amt = 12_345_678; // 0.12345678 AAPLc
        assertEq(supplyOracle.getShareOutput(aaplKey, AAPLc, amt), amt);
        assertEq(supplyOracle.getAssetOutput(aaplKey, AAPLc, amt), amt);
        assertEq(supplyOracle.getWithdrawalShareOutput(aaplKey, AAPLc, amt), amt);
        assertEq(supplyOracle.getAssetOutputWithFees(bytes32(0), aaplKey, AAPLc, address(0), amt), amt);
    }

    /*//////////////////////////////////////////////////////////////
                             DEBT ORACLE
    //////////////////////////////////////////////////////////////*/

    /// @notice The live USDC borrow against equities collateral reads correctly.
    function test_Debt_LiveBorrowMatchesSpoke() public view {
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(MAG7_SPOKE).getUserDebt(USDC_ID, BORROWER);
        assertEq(debtOracle.getBalanceOfOwner(usdcKey, BORROWER), drawn + premium, "drawn + premium");
        assertGt(drawn, 0, "borrower has live USDC debt");
        assertEq(debtOracle.decimals(usdcKey), 6);
        assertEq(debtOracle.getPricePerShare(usdcKey), 1e6);

        (uint256 rd, uint256 rp) = IAaveV4Spoke(MAG7_SPOKE).getReserveDebt(USDC_ID);
        assertEq(debtOracle.getTVL(usdcKey), rd + rp, "reserve-level debt");
    }

    /// @notice Equity reserves carry no debt on this spoke — the debt oracle reads a clean zero, not a revert.
    function test_Debt_EquityReservesReadZero() public view {
        assertEq(debtOracle.getBalanceOfOwner(aaplKey, BORROWER), 0);
        assertEq(debtOracle.getTVL(aaplKey), 0, "stocks are collateral-only here");
    }

    /// @notice Debt accrues in-view over time on the equities spoke (hub index is live).
    function test_Debt_AccruesOverTime() public {
        uint256 before_ = debtOracle.getBalanceOfOwner(usdcKey, BORROWER);
        vm.warp(block.timestamp + 30 days);
        assertGt(debtOracle.getBalanceOfOwner(usdcKey, BORROWER), before_, "debt grows without any action");
    }

    /*//////////////////////////////////////////////////////////////
                      CROSS-ASSET DENOMINATION
    //////////////////////////////////////////////////////////////*/

    /// @notice DOCUMENTS the denomination gap: for one leveraged position the two oracles return values in
    ///         two different assets and two different decimal bases (AAPLc 8dp vs USDC 6dp). Neither oracle
    ///         converts; a consumer naively subtracting them gets a meaningless number.
    function test_CrossAsset_UnitsAreNotComparable() public view {
        uint256 collateral = supplyOracle.getBalanceOfOwner(tslaKey, BORROWER); // TSLAc, 8 decimals
        uint256 debt = debtOracle.getBalanceOfOwner(usdcKey, BORROWER); // USDC, 6 decimals
        assertGt(collateral, 0);
        assertGt(debt, 0);
        assertEq(supplyOracle.decimals(tslaKey), 8);
        assertEq(debtOracle.decimals(usdcKey), 6);
        // no price feed exists in either oracle: equity price must come from MAG7_SPOKE_ORACLE externally
    }

    /// @notice Unregistered keys revert rather than returning zero, on both oracles.
    function test_UnregisteredKeyReverts() public {
        address ghost = registry.computeReserveKey(MAG7_SPOKE, UNLISTED_ID);
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        supplyOracle.getBalanceOfOwner(ghost, WHALE);
        vm.expectRevert(AaveV4ReserveRegistry.RESERVE_NOT_REGISTERED.selector);
        debtOracle.getTVL(ghost);
    }
}
