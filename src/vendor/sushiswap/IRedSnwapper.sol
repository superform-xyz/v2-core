// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRedSnwapper
/// @author Superform Labs
/// @notice Minimal interface of SushiSwap's RedSnwapper, the facade the Sushi v7 swap API targets.
/// @dev Source VERIFIED on Katanascan (0.8.10 build) and on Etherscan (0.8.24 build); the two differ only in the
///      pragma. Deployed at the same address (0xAC4c6e212A361c968F1725b4d055b47E63F80b75) on Katana and most
///      chains; Arc uses a different address.
///
///      `snwap` semantics (from the verified source):
///        1. snapshot `tokenOut` balance of `recipient` (native sentinel 0xEeee… reads `.balance`)
///        2. if `tokenIn` is not native: `amountIn > 0` → `safeTransferFrom(msg.sender, executor, amountIn)`
///           (so the approval spender is RedSnwapper and the tokens land on the EXECUTOR);
///           `amountIn == 0` → spends RedSnwapper's own balance − 1 (balance mode; rejected by the hooks)
///        3. `safeExecutor.execute{value: msg.value}(executor, executorData)` — an arbitrary executor address is
///           called from a helper that holds no approvals; from the caller's side the executor MUST be pinned
///        4. revert `MinimalOutputBalanceViolation` unless the recipient's `tokenOut` delta ≥ `amountOutMin`
///
///      NOT supported by the hooks (selector-gated): `snwapMultiple(...)` == 0xd33721a5.
interface IRedSnwapper {
    /// @dev Free-floating error in the vendor source; surfaces as the revert reason on a floor violation.
    error MinimalOutputBalanceViolation(address tokenOut, uint256 amountOut);

    /// @notice snwap(address,uint256,address,address,uint256,address,bytes) == 0x5f3bd1c8
    /// @param tokenIn Input token (0xEeee… for native, in which case msg.value must carry the input)
    /// @param amountIn Amount pulled from msg.sender and forwarded to `executor` (0 = balance mode, rejected)
    /// @param recipient Address whose `tokenOut` balance delta is checked against `amountOutMin`
    /// @param tokenOut Output token (0xEeee… for native)
    /// @param amountOutMin Hard floor on the recipient's output delta
    /// @param executor Contract that receives the input and is called with `executorData`
    /// @param executorData Opaque call forwarded to `executor` (a RouteProcessor `processRoute` in practice)
    function snwap(
        address tokenIn,
        uint256 amountIn,
        address recipient,
        address tokenOut,
        uint256 amountOutMin,
        address executor,
        bytes calldata executorData
    )
        external
        payable
        returns (uint256 amountOut);

    /// @notice The approval-less helper RedSnwapper uses to call the executor
    function safeExecutor() external view returns (address);
}
