// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

abstract contract ConstantsOtherHooks {
    // Morpho addresses per chain
    address internal constant MORPHO_MAINNET = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant MORPHO_BASE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant MORPHO_OPTIMISM = 0xce95AfbB8EA029495c66020883F87aaE8864AF92;
    address internal constant MORPHO_ARBITRUM = 0x6c247b1F6182318877311737BaC0844bAa518F5e;
    address internal constant MORPHO_ROBINHOOD = 0x9D53d5E3bd5E8d4Cbfa6DB1ca238AEA02E651010;
    address internal constant MORPHO_BNB = 0x01b0Bd309AA75547f7a37Ad7B1219A898E67a83a;

    // Euler EVK singletons per chain (source: euler-xyz/euler-interfaces CoreAddresses.json, verified).
    // One canonical EVC and one canonical GenericFactory (eVaultFactory) per chain; both are
    // constructor-pinned in the Euler loan hooks so only genuine factory-deployed EVK vaults are
    // accepted. Presence gates Euler hook deployment.
    address internal constant EULER_EVC_BASE = 0x5301c7dD20bD945D2013b48ed0DEE3A284ca8989;
    address internal constant EULER_EVAULT_FACTORY_BASE = 0x7F321498A801A191a93C840750ed637149dDf8D0;

    // Aave V3 Pool addresses per chain (source: bgd-labs/aave-address-book, verified). Presence gates
    // Aave V3 hook deployment — hooks are only deployed on chains where Aave V3 is live.
    address internal constant AAVE_V3_POOL_MAINNET = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant AAVE_V3_POOL_BASE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address internal constant AAVE_V3_POOL_BNB = 0x6807dc923806fE8Fd134338EABCA509979a7e0cB;
    address internal constant AAVE_V3_POOL_ARBITRUM = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant AAVE_V3_POOL_OPTIMISM = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant AAVE_V3_POOL_POLYGON = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant AAVE_V3_POOL_AVALANCHE = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant AAVE_V3_POOL_GNOSIS = 0xb50201558B00496A145fE76f7424749556E326D8;
    address internal constant AAVE_V3_POOL_LINEA = 0xc47b8C00b0f69a36fa203Ffeac0334874574a8Ac;
    address internal constant AAVE_V3_POOL_SONIC = 0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3;

    // DETH hook keys
    string internal constant REQUEST_REDEEM_DETH_HOOK_KEY = "RequestRedeemDETHHook";
    string internal constant APPROVE_AND_REQUEST_REDEEM_DETH_HOOK_KEY = "ApproveAndRequestRedeemDETHHook";
    string internal constant CLAIM_ASSETS_DETH_HOOK_KEY = "ClaimAssetsDETHHook";

    // Native Fee Sponsorship keys
    string internal constant NATIVE_FEE_SPONSORSHIP_KEY = "NativeFeeSponsorship";
    string internal constant FETCH_NATIVE_FEE_HOOK_KEY = "FetchNativeFeeHook";

    // SuperVault cap-bridge hook keys
    string internal constant SUPERVAULT_ACROSS_CAP_BRIDGE_HOOK_KEY = "SuperVaultAcrossCapBridgeHook";
    string internal constant SUPERVAULT_DEBRIDGE_CAP_BRIDGE_HOOK_KEY = "SuperVaultDeBridgeCapBridgeHook";
    string internal constant SUPERVAULT_STARGATE_CAP_BRIDGE_HOOK_KEY = "SuperVaultStargateCapBridgeHook";

    // Fee splitting hook key
    string internal constant FEE_SPLITTING_HOOK_KEY = "FeeSplittingHook";

    // rFLR hook keys
    string internal constant CLAIM_RFLR_HOOK_KEY = "ClaimRFLRHook";
    string internal constant CLAIM_RFLRV2_HOOK_KEY = "ClaimRFLRV2Hook";
    string internal constant CLAIM_RFLRV3_HOOK_KEY = "ClaimRFLRV3Hook";
    string internal constant WITHDRAW_RFLR_HOOK_KEY = "WithdrawRFLRHook";
    string internal constant WITHDRAW_VESTED_RFLR_HOOK_KEY = "WithdrawVestedRFLRHook";
    string internal constant WITHDRAW_RFLR_HOOK_V2_KEY = "WithdrawRFLRHookV2";
    string internal constant WITHDRAW_VESTED_RFLR_HOOK_V2_KEY = "WithdrawVestedRFLRHookV2";

    // WrappedNativeHook key (deployed with chain-specific wrapped native address, e.g. WFLR on Flare)
    string internal constant WRAPPED_NATIVE_HOOK_KEY = "WrappedNativeHook";

    // Wrapped native token addresses
    address internal constant WETH_ETHEREUM = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WFLR_FLARE = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d;

    // rFLR contract addresses (Flare mainnet)
    address internal constant RNAT_FLARE = 0x26d460c3Cf931Fb2014FA436a49e3Af08619810e;

    // Spectra Exchange hook keys
    string internal constant SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY = "SpectraExchangeDepositHook";
    string internal constant SPECTRA_EXCHANGE_REDEEM_HOOK_KEY = "SpectraExchangeRedeemHook";

    // ── HyperCore hooks (HyperEVM / Hyperliquid)
    // ──────────────────────────────────
    // Deployed only where CORE_WRITER is configured — see ConfigOtherHooks.

    /// @notice Hyperliquid's CoreWriter system contract. Same address on 999 and testnet 998.
    /// @dev Performs no validation and has no revert path — a malformed payload is silently
    ///      accepted. Payload correctness lives entirely in the hooks.
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;

    /// @notice The real USDC ERC-20 on HyperEVM
    /// @dev NOT the address the HyperCore `tokenInfo` precompile returns as `evmContract` — that is
    ///      the deposit gateway below, whose `transfer` reverts and which implements no ERC-20 views.
    address internal constant HYPERCORE_USDC_HYPEREVM = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;

    /// @notice Per-token HyperCore deposit gateway for USDC on HyperEVM
    /// @dev Credits msg.sender on HyperCore. WHICH balance is chosen by the destinationDex argument
    ///      below — it is not fixed by the gateway. Gateways are per-token.
    address internal constant HYPERCORE_USDC_GATEWAY_HYPEREVM = 0x6B9E773128f453f5c2C60935Ee2DE2CBc5390A24;

    /// @notice CoreWriter action 13 destinationDex values, as forwarded by a deposit gateway
    /// @dev `0` is perp dex 0 (perp margin); `type(uint32).max` is spot — per Hyperliquid's action 13
    ///      docs, "Specify uint32::MAX for the source_dex or destination_dex for spot".
    /// @dev Corroborated by Circle, who wrote a HyperCore forwarder against the same field:
    ///      "By default (when hyperCoreDestinationDex is 0), deposits credit the perps balance on
    ///      HyperCore. To deposit to the spot balance, set hyperCoreDestinationDex to 4294967295."
    ///      (Arbitrum-to-HyperCore howto; the concepts page does not carry it.)
    /// @dev The USDC perps-funding instance uses PERP: the deposit credits perp margin directly, so
    ///      no spot landing and no follow-up usdClassTransfer. Spot tokens use SPOT.
    uint32 internal constant HYPERCORE_DESTINATION_DEX_PERP = 0;
    uint32 internal constant HYPERCORE_DESTINATION_DEX_SPOT = type(uint32).max;

    /// @notice Upper bounds on an approvable builder fee, in decibps (tenths of a basis point)
    /// @dev A value of 10 is one basis point, so 100 == 0.1% and 1000 == 1%. Hyperliquid caps builder
    ///      fees at 0.1% on perps and 1% on spot, so these are the two protocol maxima.
    /// @dev Both are defined because the unit is easy to get wrong in exactly one direction: an
    ///      over-permissive cap is silently accepted by CoreWriter, which never reverts. Deployments
    ///      pass the one matching their market.
    uint64 internal constant HYPERCORE_MAX_BUILDER_FEE_RATE_PERPS = 100;
    uint64 internal constant HYPERCORE_MAX_BUILDER_FEE_RATE_SPOT = 1000;

    // HyperCore hook keys
    //
    // A hook key is the DEPLOYMENT RECORD name, not the contract name. For the four CoreWriter
    // leaves the two coincide: each is deployed once per chain, so one contract is one instance.
    //
    // ApproveAndHyperCoreDepositHook is the first hook in this library that is NOT one-per-chain.
    // It pins TOKEN, GATEWAY and DESTINATION_DEX as immutables, so a second collateral token or a
    // spot destination means a second deployment of the same contract. Two facts make a shared key
    // unworkable rather than merely untidy:
    //
    //   1. __deployContract writes contractAddresses[chainId][name] and exports keyed by name, so
    //      two instances under one name overwrite each other in the deployment output before any
    //      consumer sees them.
    //   2. Hook resolution selects on (ActionType, chain) and has no token dimension. Instances
    //      sharing a key tie on every field it sorts by, so the winner is arbitrary — and picking
    //      the wrong one does not revert. The USDC instance handed a USDT0 funding intent approves
    //      and deposits USDC in an amount computed for USDT0, leaving the USDT0 on HyperEVM. Wrong
    //      asset moved, green receipt, no error. CoreWriter cannot revert and neither can this.
    //
    // So each instance gets its own key naming what it is pinned to: <Contract><Token><Destination>.
    // The key is also the CREATE2 salt, so distinct keys give distinct addresses for free.
    // Registering a new token means a new key here, a new deploy entry, and a new ActionType — the
    // token dimension lives in the key rather than in a tag matched at resolution time, because the
    // hook pins an ADDRESS and a symbol tag would be a second identity for it that nothing verifies.
    string internal constant HYPERCORE_ADD_API_WALLET_HOOK_KEY = "HyperCoreAddApiWalletHook";
    string internal constant HYPERCORE_USD_CLASS_TRANSFER_HOOK_KEY = "HyperCoreUsdClassTransferHook";
    string internal constant HYPERCORE_SEND_ASSET_HOOK_KEY = "HyperCoreSendAssetHook";
    string internal constant HYPERCORE_APPROVE_BUILDER_FEE_HOOK_KEY = "HyperCoreApproveBuilderFeeHook";
    string internal constant APPROVE_AND_HYPERCORE_DEPOSIT_USDC_PERP_HOOK_KEY =
        "ApproveAndHyperCoreDepositUsdcPerpHook";
    /// @notice Read-only perp position oracle over the HyperCore read precompiles (0x800+).
    /// @dev Not a hook and not an IYieldSourceOracle (no SuperLedger registration), but it ships with the
    ///      HyperCore family because it shares the family's gate: the precompiles exist only where CoreWriter
    ///      does (999 / 998). No constructor args; the precompile addresses are protocol constants.
    string internal constant HYPERCORE_PERP_POSITION_ORACLE_KEY = "HyperCorePerpPositionOracle";

    // ── Binance Web3 Trading API DEX router (SUP-21203)
    // ─────────────────────────────────
    /// @dev LiquidMesh router: an EIP-2535 diamond (owner 0x1c6F8a6D1011Ca0334F6f8F5E2f9222eF1b68Fa9,
    ///      6 facets, swap facet 0xa9fA1b56…9603 at selector 0xad43f73d; unknown selectors revert).
    ///      Confirmed by us on-chain 2026-10-12 (SUP-21203): within a ~2h window at BSC block ~127.19M
    ///      the diamond emitted events in 366 txs, at least 10 of which moved USDT against AAPLB/NVDAB,
    ///      including a direct 0xad43f73d call (tx 0xa618621b…f6f1d4cd). Public integrations
    ///      (binance-web3-connector-js#7, ottopus#55) show the same address as the /swap `to`/`approveTarget`,
    ///      and the live E2E test asserts API `to` == this constant whenever API credentials are present.
    ///      The spec's earlier candidate 0xb300000b72DEAEb607a12d5f54773D1C19c7028d is the generic
    ///      "Binance: DEX Router" dispatcher (different owner) and is NOT what LiquidMesh returns.
    ///      Pinning the address does not pin the code (mutable diamond; see hook NatSpec).
    address internal constant BINANCE_DEX_ROUTER_BNB = 0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5;
    /// @dev Per-execution inputAmount ceiling, RAW units of the expected input token. The SuperMAG7 input
    ///      asset is Binance-Peg USDT on BSC (`0x55d398326f99059fF775485246999027B3197955`, 18 dec), so this
    ///      is 10,000,000 USDT per execution — a fat-finger guard, not a risk limit (set 2026-10-12).
    ///      Immutable: changing it is a redeploy + strategy root update. The cap is token-agnostic on-chain;
    ///      a leaf for a 6-decimal input token would make it 1e12x looser.
    uint256 internal constant BINANCE_MAX_INPUT_AMOUNT_BNB = 10_000_000e18;

    string internal constant APPROVE_AND_SWAP_BINANCE_HOOK_KEY = "ApproveAndSwapBinanceHook";

    // ── Gyld tokenized bonds (Katana)
    // ─────────────────────────────────
    /// @notice The approved-instrument list. Keyed by bond token; one configuration per instrument.
    /// @dev Deployed with DEPLOYER as admin, then handed to governance by
    ///      `TransferGyldBondRegistryRoles`. Nothing values a Gyld bond until an instrument is registered
    ///      in it, so deploying it is safe and inert.
    string internal constant GYLD_BOND_REGISTRY_KEY = "GyldBondRegistry";
    /// @notice Values a registered bond at complete NAV, in the instrument's cash denomination.
    /// @dev MUST be registered in `SuperLedgerConfiguration` with `feePercent = 0`, and `FlatFeeLedger` is
    ///      categorically forbidden: a bond's coupon accrual is not performance yield. See the oracle's
    ///      NatSpec. Registration is a separate governance step, not part of this deploy.
    string internal constant GYLD_BOND_YIELD_SOURCE_ORACLE_KEY = "GyldBondYieldSourceOracle";
    /// @notice Refuses a trade unless the named instrument is registered, unsuspended and freshly priced.
    /// @dev MANDATORY in every Gyld leaf, not optional hardening: `ApproveAndTradeGyldBondHook` gates only on
    ///      the registry's approved pair, and `isApprovedPair` stays true while an instrument is suspended.
    string internal constant GYLD_TRADE_GUARD_HOOK_KEY = "GyldTradeGuardHook";
    /// @notice F1: the tradability policy the two trade instances pin in an immutable
    string internal constant GYLD_TRADE_POLICY_KEY = "GyldTradePolicy";
    /// @notice Max age of the aggregator's price-per-share observation the policy will accept.
    /// @dev Deliberately NOT the strategy's own `ppsExpiration`, which the manager sets. 1 day is a
    ///      starting value: tighten once the real PPS publication cadence is known.
    /// @dev SEEDED POST-DEPLOY via `GyldBondRegistry.setMaxPpsAge`, not a constructor argument — the policy
    ///      reads it live so retuning it costs one role-gated transaction instead of a hook redeploy. The
    ///      policy REFUSES to trade while the registry still holds zero.
    uint256 internal constant GYLD_MAX_PPS_AGE = 1 days;

    // TWO trade instances per pair, one per direction, and that is MANDATORY rather than preferable.
    // `MAX_INPUT_AMOUNT` is a single immutable in RAW input-token units and applies to whichever token is
    // the input. A cap sized for a 6-decimal stablecoin caps an 18-decimal bond leg at 1e-8 bonds; a cap
    // sized for the bond leg makes the cash leg's cap vacuous by a factor of 1e12. One instance cannot
    // serve both directions of a pair whose decimals differ, so each direction gets its own key (and
    // therefore its own CREATE2 salt and address) with its cap denominated in that direction's input token.
    // Same key-names-the-instance, bytecode-names-the-contract split as the HyperCore deposit hook above.
    /// @notice BUY leg: cash in, bond out. Cap denominated in the cash token.
    string internal constant APPROVE_AND_TRADE_GYLD_BOND_CASH_IN_HOOK_KEY = "ApproveAndTradeGyldBondCashInHook";
    /// @notice SELL leg: bond in, cash out. Cap denominated in the bond token.
    string internal constant APPROVE_AND_TRADE_GYLD_BOND_BOND_IN_HOOK_KEY = "ApproveAndTradeGyldBondBondInHook";

    /// @notice Per-transaction cash-side ceiling, RAW units of the cash token (vbUSDC, 6 decimals), so this
    ///         is 500,000 vbUSDC per transaction.
    /// @dev THIS IS A LOSS BOUND, NOT A FAT-FINGER GUARD, and it is PROVISIONAL pending a position-size
    ///      sign-off. `outputMin` is caller-chosen and is NOT committed into the Merkle leaf, so a
    ///      compromised manager key can accept one wei of output for a full authorised input: the worst case
    ///      is 100% of this number per transaction, repeatable, since the accumulator is transient and
    ///      resets at every transaction boundary.
    /// @dev DERIVATION, and why it is not larger. Measured on Katana mainnet 2026-11-02 at block 46,871,544:
    ///      vbUSDC total supply was 5,723,187.41. An earlier draft of this constant was 10,000,000 vbUSDC,
    ///      i.e. 1.75x the ENTIRE supply of the token on that chain, which bounds nothing at all. 500,000 is
    ///      about 8.7% of that supply. It must be re-derived from the intended Gyld allocation before any
    ///      mainnet use; `GyldBondKatanaFork` asserts it stays below the live supply.
    uint256 internal constant GYLD_MAX_CASH_INPUT_AMOUNT_KATANA = 500_000e6;
    /// @notice Per-transaction bond-side ceiling, RAW units of the bond token.
    /// @dev ASSUMES AN 18-DECIMAL BOND TOKEN, WHICH IS UNVERIFIED. Gyld's bond tokens are not deployed on
    ///      Katana mainnet, so their decimals are unknown: their Bokuto testnet stack uses a 6-decimal
    ///      MockUSDC for cash, and the bond series tokens' decimals were not readable. If a bond token turns
    ///      out to be 6-decimal, this cap is 1e12 too large and bounds nothing. CONFIRM `decimals()` on the
    ///      real bond token before configuring this.
    /// @dev Sized to the same 500,000 WHOLE units as the cash cap, so at a near-par NAV the two directions
    ///      carry a comparable economic bound rather than two unrelated numbers.
    uint256 internal constant GYLD_MAX_BOND_INPUT_AMOUNT_KATANA = 500_000e18;

    address internal constant GYLD_CASH_TOKEN_KATANA = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36;

    // NOTE: Odos V3 hook keys and ODOS_ROUTER_V3 moved to Constants.sol (deployed via DeployV2Core)
}
