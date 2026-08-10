# Relay Protocol (relay.link) — On-Chain Contracts & API Research Report

**For:** Superform v2-core relay-bridge-integration spec
**Researched:** 2026-08-07, against docs.relay.link, github.com/relayprotocol source, and the live `api.relay.link/chains` API. All Solidity snippets were copied from actual contract source, not reconstructed. Scratchpad copies of all verified sources were saved during research (RelayDepository.sol, RelayReceiver.sol, RelayRouterV3.sol, RelayApprovalProxyV3.sol, Multicall3.sol, depository-addresses.json, chains.json, quote API docs).

---

## 1. Origin-side deposit contracts

Relay has **two generations of origin-side surfaces** that coexist today:

| Contract | Generation | Role |
|---|---|---|
| `RelayDepository` | Protocol v2 (current, "Relay Settlement Protocol") | Escrow. Funds held in the depository, tagged with an `orderId`; released only via Allocator-signed requests. **Recommended surface for programmatic/contract depositors.** |
| `RelayReceiver` | v1 (legacy, still live, returned by the API for native flows) | Pass-through forwarder. Immediately forwards `msg.value` to the solver EOA; calldata (the request id) only emitted in an event. |
| `RelayRouter` (aka `erc20Router`) + `RelayApprovalProxy` | v1/v3 periphery | Origin-side swap+deposit multicalls, and **destination-side fill execution** (see §3). |

### 1.1 RelayDepository (current escrow, protocol v2)

- Source: `relay-depository/packages/ethereum-vm/src/RelayDepository.sol` — Solidity `^0.8.23`, Solady (`Ownable`, `EIP712`, `SafeTransferLib`, `SignatureCheckerLib`). Non-upgradable, no owner backdoor to withdraw funds.
- Docs: docs.relay.link → EVM Depository Reference, Depository component.

**Exact function signatures (verbatim from source):**

```solidity
// Deposit native tokens. `depositor` = address credited with the deposit;
// pass address(0) to credit msg.sender. `id` = the orderId (bytes32).
// Emits RelayNativeDeposit. NOTE: it does nothing else — no storage writes.
function depositNative(address depositor, bytes32 id) external payable;

// Deposit ERC20. Pulls `amount` of `token` from msg.sender via
// safeTransferFrom (requires prior approval to the depository).
// Emits RelayErc20Deposit.
function depositErc20(address depositor, address token, uint256 amount, bytes32 id) public;

// Overload: uses the FULL allowance msg.sender has granted the depository.
function depositErc20(address depositor, address token, bytes32 id) external;

// Withdrawal path (solver-facing, not integrator-facing): executes an
// Allocator-signed EIP-712 CallRequest. Replay-protected via callRequests mapping.
function execute(CallRequest calldata request, bytes memory signature)
    external returns (CallResult[] memory results);

function setAllocator(address _allocator) external; // onlyOwner
address public allocator;
mapping(bytes32 => bool) public callRequests; // used request hashes
```

**Structs & events (verbatim):**

```solidity
struct Call        { address to; bytes data; uint256 value; bool allowFailure; }
struct CallRequest { Call[] calls; uint256 nonce; uint256 expiration; }
struct CallResult  { bool success; bytes returnData; }

event RelayNativeDeposit(address from, uint256 amount, bytes32 id);
event RelayErc20Deposit(address from, address token, uint256 amount, bytes32 id);
event RelayCallExecuted(bytes32 id, Call call);
```

EIP-712 domain: `name = "RelayDepository"`, `version = "1"`.

**Critical observation:** the deposit functions are *event-only* — they do **not** record the `id` on-chain, do not check id uniqueness, and do not track per-depositor balances. All accounting (deposit→order matching, replay handling) happens off-chain in the Oracle/Hub. Depositing with a bogus or reused `id` simply strands funds pending off-chain resolution. On-chain replay protection exists only on the *withdrawal* side (`callRequests` + nonce + expiration).

**Deployed addresses** (from `deployments/addresses.prod.json`, 80 EVM deployments, CREATE2-deterministic):
- **`0x4cD00E387622C35bDDB9b4c962C136462338BC31`** on almost all chains, incl. Ethereum (1), Optimism (10), BSC (56), Polygon (137), Base (8453), Arbitrum (42161), Avalanche (43114), Scroll, Blast, Berachain, Zora. Verified on Etherscan.
- Exceptions: `0x59916da825d2d2ec1bf878d71c88826f6633ecca` on Cronos (25), Metis (1088), Polygon zkEVM (1101), Hychain, Mantle (5000), Linea (59144), Taiko (167000); `0xa88cf7864951147a08707ed732237eaa9b1c3b9b` on Zero (543210).
- Production allocator at deployment: `0x51203c6be98052fb6d7fe1333ee6859b90d21cdf` (rotatable via `setAllocator`).

### 1.2 RelayReceiver (legacy v1, native-only)

Source: `relay-periphery/src/receiver/RelayReceiver.sol` — 80 lines:

```solidity
contract RelayReceiver {
    event FundsForwardedWithData(bytes data);
    address private immutable SOLVER;
    fallback() external payable;              // send(SOLVER, msg.value); emit FundsForwardedWithData(msg.data)
    function forward(bytes calldata data) external payable; // same, explicit
    function makeCalls(Call[] calldata calls) external payable; // onlySolver
}
```

- v1 flow for native deposits — funds go **straight to the solver**, nothing escrowed. ERC20 v1 deposits go as direct `transfer()` to the solver EOA (`0xf70da97812cb96acdf810712aa562db8dfa3dbef` on all EVM chains) with requestId appended to calldata.
- **Addresses vary per chain** (immutable solver arg ⇒ different init code); always read from the chains API.

### 1.3 Which surface to integrate

- Recommended: **quote API + the deposit step it returns**. For protocol v2 with `explicitDeposit: true` (default, and **required for smart-contract wallets**), the deposit step is `approve` + **`RelayDepository.depositErc20(user, token, amount, orderId)`** (or `depositNative(user, orderId)`).
- "Implicit deposits" (bare transfer to solver) "only work reliably for EOAs" — Superform's smart-account/hook flow must use **explicit deposits to the RelayDepository**.
- Depository is escrow (refundable if unfilled); RelayReceiver is fire-and-forget to the solver. Depository is strictly safer for programmatic depositors.

---

## 2. The deposit `id`

- **Format:** `bytes32`. Two distinct identifiers:
  - **`requestId`** — API-level intent id, on every quote step (`steps[].requestId`). Used for status polling (`/intents/status/v3?requestId=...`) and webhooks.
  - **`orderId`** — protocol-level id, in the v2 quote response under `protocol.v2.orderId`, with `protocol.v2.paymentDetails { chainId, depository, currency, amount }`. **This is the `id` passed to `depositNative`/`depositErc20`.**
- **Who generates it:** the quote API / solver, at quote time. Treat `orderId` as an opaque correlation key. With `includeProtocolData: true` the quote also returns `protocol.v2.orderSignature` — solver's ECDSA signature over the orderId, verifiable via ecrecover on-chain. The attestation API additionally signs over `keccak256(abi.encode(requestId, originChainId, originUser, originCurrency, originAmount, destinationChainId, destinationUser))` by solver EOA `0xf70da97812cb96acdf810712aa562db8dfa3dbef`.
- **Uniqueness / replay:** not enforced on-chain for deposits. The Oracle matches the deposit event (amount + id) on origin against the fill (or refund) on destination before settling on the Hub. Duplicate attestations rejected idempotently at the Hub. Deposit → fill → refund all correlated by this one `orderId`.
- Quotes have deadlines; late deposits handled via `latePaymentSlippageTolerance` or refunded.

---

## 3. Destination-side execution (the decisive question)

**How the solver fills:**
- **Simple bridge (no `txs[]`):** solver transfers funds **directly** to the recipient — no router involved.
- **Swap and/or `txs[]` execution:** solver routes through a multicall contract:
  - **`RelayRouterV3`** (API key `erc20Router`): `0xb92fe925dc43a0ecde6c8b1a2709c170ec4fff4f` on virtually every EVM chain (non-tstore variant `0x9ef6d3c2f60d7b9008d74cab1fc0f899c957c819` on Cronos/Metis/Mantle/Linea).
  - Vectorized's **Multicaller** (`0x0000000000002bdbf1bf3279983603ec279cc6df`) in older docs.

**Atomicity and ordering — verified from router source:** `RelayRouterV3.multicall(Call3Value[] calls, address refundTo, address nftRecipient, bytes metadata)` executes the calls **in array order, within one transaction** (Multicall3 fork, `_aggregate3Value`). Each `Call3Value { address target; bool allowFailure; uint256 value; bytes callData; }` executes sequentially; **reverts bubble up unless `allowFailure` is set** — a fill through the router is a single atomic tx: all destination `txs[]` succeed together or the whole fill reverts (order falls into the refund path). Caveat: this atomicity is a property of how solvers execute, not a protocol-level on-chain guarantee visible to contracts; simple bridges bypass the router entirely.

**`msg.sender` on destination calls is the router/multicaller — never the user.** Verbatim from Contract Compatibility docs: "Because transactions are executed via the Relayer / Multicaller, you can't rely on `msg.sender` for authentication." Pass the beneficiary as a parameter, use signature-based auth. This matches Superform's `SuperDestinationExecutor` pattern exactly.

**Fund delivery relative to the calls:** output funds are delivered **within the same multicall tx, before your `txs[]` execute** — solver transfers output tokens to the router (or sends native `value` into the multicall), then the router executes `txs[]`. ERC20 spends need an in-`txs[]` `approve` preceding the spending call (approval executed *by the router*, over *the router's* balance). For `EXACT_INPUT` (variable output), Relay's calling guide recommends a proxy that "pull[s] the full approved token balance from the caller that initiated execution" then acts on the live balance — because final calldata can't be precomputed at quote time. Leftovers swept with `cleanupErc20s(...)` / `cleanupNative(...)` (amount 0 = full balance). The router is stateless.

**Origin-side ERC20 swap+deposit entry:** `RelayApprovalProxyV3` (`0xccc88a9d1b4ed6b0eaba998850414b24f1c315be`, non-tstore chains `0x8754bc615047de01228a7527b712806a71a8dc9a`): `transferAndMulticall(...)` + `permit*` variants (ERC-2612, Permit2, ERC-3009).

---

## 4. Quote API contract — `POST https://api.relay.link/quote` (and `/quote/v2`)

**Request (cross-chain swap + call):**

```jsonc
{
  "user": "0x...",                 // depositor on origin
  "recipient": "0x...",            // receiver on destination (defaults to user)
  "originChainId": 8453,
  "destinationChainId": 42161,
  "originCurrency": "0x...",       // 0x000...0 = native
  "destinationCurrency": "0x...",
  "amount": "100000000",           // smallest units; for calls: MUST equal sum of txs[].value
  "tradeType": "EXACT_INPUT",      // | EXACT_OUTPUT | EXPECTED_OUTPUT
  "txs": [                          // destination calls, executed in order
    { "to": "0x...", "value": "0", "data": "0x..." }
  ],
  "txsGasLimit": 500000,
  "slippageTolerance": "50",       // bps; auto-calculated if omitted
  "refundTo": "0x...",             // refund address on failure (defaults recipient→user)
  "explicitDeposit": true,         // default true; REQUIRED for smart wallets → approve + depositErc20 into RelayDepository
  "includeProtocolData": true,     // returns protocol.v2.orderSignature
  "appFees": [{ "recipient": "0x...", "fee": "25" }],
  "authorizationList": []          // EIP-7702
}
```

**Response:**
- `steps[]` — ordered executable steps; `id ∈ {deposit, approve, authorize, swap, send}`, `kind ∈ {transaction, signature}`, `requestId`, `items[].data` = ready-to-send tx, `items[].check` = status-poll endpoint. With `explicitDeposit`, the deposit step's `to` is the RelayDepository, `data` encodes `depositErc20/depositNative` with the orderId.
- `fees` — `gas`, `relayer`, `relayerGas`, `relayerService` (can be negative), `app`.
- `details` — `currencyIn/currencyOut`, `totalImpact`, `rate`, `timeEstimate`.
- `protocol.v2` — `orderId`, `orderData`, `orderSignature`, `paymentDetails`.

---

## 5. Refunds / liveness when no solver fills

- **Mechanism (v2):** if a solver can't fill (revert, slippage, destination down, under-deposit, dup id...), the solver performs a **fast refund** on the **origin chain**, then requests a refund attestation from the Oracle and settles on the Hub. Described as automatic and "almost instant."
- Refund goes to `refundTo` (fallback recipient → user) on the origin chain, in the currency sent (post-origin-swap currency if applicable), minus gas costs. If amount can't cover gas → marked failed, no refund. **If `refundTo` is not resolvable, automatic refunding is disabled** — always set it.
- **No user-side on-chain claim exists.** The Depository has no user withdrawal/timeout function — only Allocator-signed `execute()`. Refund liveness depends on solver+Oracle+Allocator. State this explicitly as a trust trade-off.
- Testing hook: pass `"referrer": "debug-force-refund"` to force the refund path.

---

## 6. Trust / security model & audits

- **Solvers:** fill with own capital; primary EVM solver EOA `0xf70da97812cb96acdf810712aa562db8dfa3dbef` (all EVM chains). Withdrawals gated by Hub balances; malicious solver can't extract more than owed; fill/refund *liveness* depends on solvers.
- **Oracle:** main trust bearer. Validator set signs threshold EIP-712 attestations per order; on-chain Oracle on the Relay Chain (Hub `0xDDD361727C22A01EB137880678A20b0BEaE69318`, Oracle `0xd4b9fdB83C723c096d7fBE72da252aa23f1387aa`, chain id 537713). Cannot touch Depository funds directly.
- **Allocator:** authorizes Depository withdrawals via **NEAR MPC chain signatures**, deployed on Aurora (`0x7EdA04920F22ba6A2b9f2573fd9a6F6F1946Ff9f`); no single party holds the key. Only up to a solver's Hub balance, only with valid Oracle signatures, every proof carries nonce + expiration.
- **Security Council:** multisig (`0xb538ee6515F9d16eBD0BACD0503733815c9b070c` on Aurora); any member can instantly suspend withdrawers; supermajority for structural changes.
- **Depository:** non-upgradable, no owner fund-withdrawal backdoor; owner can only rotate the allocator.

**Audits:** Feb 2025 Relay Depository (EVM) — Spearbit/Cantina; Jun 2025 Relay Depository (EVM) — Certora; Nov 2025 Settlement Protocol — Zellic; Apr 2026 Oracle — Zellic. Bug bounty: docs.relay.link/security/bounties.

---

## 7. EVM chain support

Live `GET https://api.relay.link/chains` (2026-08-07): **68 chains total, 60 EVM**; depository repo lists **80 EVM deployments**. Includes Ethereum (1), Optimism (10), BSC (56), Gnosis (100), Unichain (130), Polygon (137), Monad (143), Sonic (146), zkSync (324), World Chain (480), Flow EVM (747), HyperEVM (999), Sei (1329), Soneium (1868), Abstract (2741), **Robinhood (4663)**, Mantle (5000), **Base (8453)**, ApeChain (33139), Mode (34443), **Arbitrum (42161)**, Celo (42220), Avalanche (43114), Ink (57073), Linea (59144), BOB (60808), Berachain (80094), Blast (81457), Plume (98866), Scroll (534352), Katana (747474), Zora (7777777), and more. All Superform deployment targets (Ethereum, Base, BSC, Arbitrum) supported with the canonical depository address.

---

## 8. Ready-to-adapt Solidity interfaces

Derived 1:1 from verified source (`RelayDepository.sol`, `RelayRouterV3.sol`, `RelayReceiver.sol`):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for Relay Protocol's RelayDepository (protocol v2 escrow).
/// @dev Canonical address 0x4cD00E387622C35bDDB9b4c962C136462338BC31 on ETH/Base/BSC/Arbitrum
///      (differs on Cronos/Metis/Mantle/Linea/Taiko/zkEVM: 0x59916dA825d2d2EC1bF878d71c88826F6633EcCA).
/// @dev Source: github.com/relayprotocol/relay-depository packages/ethereum-vm/src/RelayDepository.sol
interface IRelayDepository {
    /// @notice Deposit native currency, credited to `depositor` (address(0) => msg.sender),
    ///         tagged with the Relay `orderId` (`id`) from the quote API (`protocol.v2.orderId`).
    ///         Emits RelayNativeDeposit only — no on-chain state.
    function depositNative(address depositor, bytes32 id) external payable;

    /// @notice Deposit `amount` of `token` (pulled from msg.sender; requires prior approval).
    function depositErc20(address depositor, address token, uint256 amount, bytes32 id) external;

    /// @notice Variant consuming the depositor's full current allowance to the depository.
    function depositErc20(address depositor, address token, bytes32 id) external;

    /// @notice Allocator-signed withdrawal execution (solver-facing).
    function execute(CallRequest calldata request, bytes calldata signature)
        external returns (CallResult[] memory results);

    function allocator() external view returns (address);
    function callRequests(bytes32 structHash) external view returns (bool used);

    struct Call        { address to; bytes data; uint256 value; bool allowFailure; }
    struct CallRequest { Call[] calls; uint256 nonce; uint256 expiration; }
    struct CallResult  { bool success; bytes returnData; }

    event RelayNativeDeposit(address from, uint256 amount, bytes32 id);
    event RelayErc20Deposit(address from, address token, uint256 amount, bytes32 id);
    event RelayCallExecuted(bytes32 id, Call call);
}

/// @notice Destination-side fill router (API `contracts.erc20Router`),
///         0xb92FE925dC43A0ECDe6C8B1a2709C170EC4FfF4F on most EVM chains.
///         msg.sender for all destination txs[] is THIS contract, executed
///         sequentially and atomically within multicall (reverts bubble unless allowFailure).
interface IRelayRouterV3 {
    struct Call3Value { address target; bool allowFailure; uint256 value; bytes callData; }
    struct Result     { bool success; bytes returnData; }

    function multicall(
        Call3Value[] calldata calls,
        address refundTo,
        address nftRecipient,
        bytes calldata metadata
    ) external payable returns (Result[] memory returnData);

    /// @dev amount == 0 sweeps full balance; recipient == address(0) => msg.sender.
    function cleanupErc20s(
        address[] calldata tokens, address[] calldata recipients,
        uint256[] calldata amounts, bytes calldata metadata
    ) external;
    function cleanupNative(uint256 amount, address recipient, bytes calldata metadata) external;
}

/// @notice Legacy v1 native-deposit forwarder (per-chain addresses from api.relay.link/chains).
///         Forwards msg.value straight to the solver EOA; requestId travels as calldata/event only.
interface IRelayReceiver {
    event FundsForwardedWithData(bytes data);
    function forward(bytes calldata data) external payable;
    // fallback() also accepts value with requestId as raw msg.data
}
```

### Key spec-relevant takeaways

1. **Integration surface:** quote API (`explicitDeposit: true`) → `IRelayDepository.depositErc20/depositNative` with the API-supplied `bytes32 orderId`. Don't integrate RelayReceiver for new work.
2. **Deposit is trust-forward:** deposits only emit events; no on-chain link between id and obligation, no user-side refund claim. Refund liveness = solver + Oracle + Allocator (MPC) + Security Council.
3. **Destination `txs[]`:** executed in order, in one atomic router multicall, `msg.sender = RelayRouterV3` — destination logic must not gate on sender identity; for `EXACT_INPUT`, read live balances (Relay's docs recommend exactly the proxy pattern `SuperDestinationExecutor` already implements).
4. **The `amount` of a call-quote must equal the sum of `txs[].value`; ERC20 spends need an in-`txs[]` `approve` preceding the spend.**
