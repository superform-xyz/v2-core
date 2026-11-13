// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRouteProcessor7
/// @author Superform Labs
/// @notice The nested executor SushiSwap's v7 API places inside `RedSnwapper.snwap` on Katana
///         (0xC10eE9031F2a0B84766A86B55a8D90F357910fb4).
/// @dev SOURCE NOT VERIFIED. At the time of writing this executor has no verified source on Katanascan, Etherscan v2
///      (any chain), Sourcify or public Blockscout instances, and Sushi removed `protocols/route-processor` from its
///      public monorepo in September 2024 (the last public release is RouteProcessor6). What IS established:
///        - the ABI SHAPE below was recovered from the deployed runtime bytecode (`cast selectors`), and the Katana
///          bytecode is byte-identical to the same address on Base;
///        - parameter names come from RouteProcessor6 plus the Sushi v7 API fields (`takeSurplus`, `referralCode`);
///        - the scaling semantics were validated empirically on a pinned Katana fork (block 47,724,900, live Sushi
///          v7 calldata at 80-150% of the quoted input; see test/integration/sushiswap/): the route bytes are
///          amount-agnostic (the executor swaps whatever RedSnwapper pre-funded it with and splits by `uint16`
///          shares), and with
///          `takeSurplus == true` the nested `amountOutMin` acts as a recipient CAP (output above it stays with the
///          executor), while the outer RedSnwapper `amountOutMin` is the real floor.
///      The Ethereum executor (0xB365…9091) exposes a DIFFERENT `processRoute(...,uint16,uint32)` (0x01a8a270) and is
///      NOT compatible with the hooks; the executor is a per-chain constructor argument and any new chain needs the
///      same selector/ABI check before deployment.
///
///      Rejected by the hooks (they carry an absolute `amountValueTransfer` and cannot be resized):
///        0x9cbd7f62 / 0xba3f2165 / 0xe9406cf4 — the three `*TransferValue*` variants
///        `(address,uint256,address,uint256,address,uint256,address,bytes,bool,uint32)`.
interface IRouteProcessor7 {
    /// @notice processRoute(address,uint256,address,uint256,address,bytes,bool,uint32) == 0x6be92b89
    /// @param tokenIn Input token (0xEeee… for native)
    /// @param amountIn Nominal input; in the RedSnwapper flow the executor actually swaps its pre-funded balance
    /// @param tokenOut Output token (0xEeee… for native)
    /// @param amountOutMin With `takeSurplus` true: the recipient cap / surplus threshold. Otherwise a hard floor.
    /// @param to Output recipient (must equal RedSnwapper's `recipient`)
    /// @param route Opaque route program (amount-agnostic; never parsed by the hooks)
    /// @param takeSurplus Whether output above `amountOutMin` is kept by the executor
    /// @param referralCode Sushi referral code (informational)
    function processRoute(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address to,
        bytes memory route,
        bool takeSurplus,
        uint32 referralCode
    )
        external
        payable
        returns (uint256 amountOut);
}
