// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.30;

abstract contract ConstantsOtherHooks {

    address internal constant OKX_ROUTER_MAINNET = 0x1Ef032a3c471a99CC31578c8007F256D95E89896;
    address internal constant OKX_ROUTER_BASE = 0x6b2C0c7be2048Daa9b5527982C29f48062B34D58;
    address internal constant OKX_ROUTER_OPTIMISM = 0xf332761c673b59B21fF6dfa8adA44d78c12dEF09;
    address internal constant OKX_ROUTER_ARBITRUM = address(0); // TODO: Research Arbitrum OKX router address
    address internal constant OKX_ROUTER_BNB = address(0); // TODO: Research BNB OKX router address

     // Spectra Router addresses per chain
    address internal constant SPECTRA_ROUTER_MAINNET = 0xC03309DE321A4D3df734F5609B80cC731ae28e6D;
    address internal constant SPECTRA_ROUTER_BASE = 0xC03309DE321A4D3df734F5609B80cC731ae28e6D;
    address internal constant SPECTRA_ROUTER_OPTIMISM = 0x8A92294ffCFe469a3DF4A85c76a0B0d2B3292119;
    address internal constant SPECTRA_ROUTER_ARBITRUM = 0x38b9B4884a5581E96eD3882AA2f7449BC321786C; 
    address internal constant SPECTRA_ROUTER_BNB = 0x8A92294ffCFe469a3DF4A85c76a0B0d2B3292119;

    // Pendle Router addresses per chain
    address internal constant PENDLE_ROUTER_MAINNET = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address internal constant PENDLE_ROUTER_BASE = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address internal constant PENDLE_ROUTER_OPTIMISM = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address internal constant PENDLE_ROUTER_ARBITRUM = 0x888888888889758F76e7103c6CbF23ABbF58F946; // Standard Pendle
    address internal constant PENDLE_ROUTER_BNB = 0x888888888889758F76e7103c6CbF23ABbF58F946; // Standard Pendle router


    // Hook Keys
    string internal constant SWAP_OKX_HOOK_KEY = "SwapOkxHook";
    string internal constant PENDLE_ROUTER_SWAP_HOOK_KEY = "PendleRouterSwapHook";
    string internal constant PENDLE_ROUTER_REDEEM_HOOK_KEY = "PendleRouterRedeemHook";
    string internal constant SPECTRA_EXCHANGE_DEPOSIT_HOOK_KEY = "SpectraExchangeDepositHook";
    string internal constant SPECTRA_EXCHANGE_REDEEM_HOOK_KEY = "SpectraExchangeRedeemHook";

}