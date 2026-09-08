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

    // NOTE: Odos V3 hook keys and ODOS_ROUTER_V3 moved to Constants.sol (deployed via DeployV2Core)
}
