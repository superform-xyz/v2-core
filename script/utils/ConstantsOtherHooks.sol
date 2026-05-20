// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

abstract contract ConstantsOtherHooks {
    // Morpho addresses per chain
    address internal constant MORPHO_MAINNET = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant MORPHO_BASE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal constant MORPHO_OPTIMISM = 0xce95AfbB8EA029495c66020883F87aaE8864AF92;
    address internal constant MORPHO_ARBITRUM = 0x6c247b1F6182318877311737BaC0844bAa518F5e;
    address internal constant MORPHO_BNB = 0x01b0Bd309AA75547f7a37Ad7B1219A898E67a83a;

    // DETH hook keys
    string internal constant REQUEST_REDEEM_DETH_HOOK_KEY = "RequestRedeemDETHHook";
    string internal constant APPROVE_AND_REQUEST_REDEEM_DETH_HOOK_KEY = "ApproveAndRequestRedeemDETHHook";
    string internal constant CLAIM_ASSETS_DETH_HOOK_KEY = "ClaimAssetsDETHHook";

    // Native Fee Sponsorship keys
    string internal constant NATIVE_FEE_SPONSORSHIP_KEY = "NativeFeeSponsorship";
    string internal constant FETCH_NATIVE_FEE_HOOK_KEY = "FetchNativeFeeHook";
}
