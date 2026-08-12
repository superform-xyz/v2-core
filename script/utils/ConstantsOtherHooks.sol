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

    // NOTE: Odos V3 hook keys and ODOS_ROUTER_V3 moved to Constants.sol (deployed via DeployV2Core)
}
