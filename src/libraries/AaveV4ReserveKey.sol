// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title AaveV4ReserveKey
/// @author Superform Labs
/// @notice Every Aave V4 key derivation, in one place. Aave V4 has TWO key namespaces with disjoint consumers:
///         1. ACCOUNTING / NAV — one key per reserve LEG: `computeReserveKey` (SUPPLY) and `computeDebtKey`
///            (DEBT). Consumed by `AaveV4ReserveOracle`, `AaveV4ReserveRegistryV2._reserves`, and SuperLedger
///            via the idle INFLOW / OUTFLOW pair. These are oracle-resolvable and can be ledger keys.
///         2. INTENT / IDENTITY — one key per market PAIR: `computeMarketKey(spoke, supplyReserveId,
///            borrowReserveId)` (SUP-21239). Consumed by the header `yieldSource` of the V2 LOAN hooks, and
///            hence by merkle leaves, vault whitelists and off-chain indexing. The V2 LOAN hooks are
///            NONACCOUNTING, so the executor never reads their header and a market key is never a ledger
///            key for them. `AaveV4ReserveOracle` DOES resolve a market key (SUP-21255), but
///            one-directionally and to one thing only: its COLLATERAL (supply) leg, so the sideless
///            `IYieldSourceOracle` surface still returns one number in one asset. Debt is never reachable
///            through a market key, the legs are never netted, and portfolio valuation belongs in the
///            batched `getOwnerSnapshot`, which de-duplicates legs across the whole requested set.
/// @dev Single definition: `AaveV4ReserveRegistryV2.computeReserveKey` / `.computeMarketKey` (the `public pure`
///      ones off-chain indexers call), the idle `BaseAaveV4MoneyMarketHook` decoder and both LOAN bases all
///      delegate here. The literal formulas are what off-chain consumers derive; each is pinned independently
///      of this library against the written-out expression — the reserve formula by
///      `testFuzz_ReserveKey_MatchesLiteralFormula` (LOAN unit suites) and
///      `test/unit/accounting/oracles/AaveV4Oracles.t.sol`, the market formula by
///      `testFuzz_MarketKey_MatchesLiteralFormula` and
///      `AaveV4ReserveKeyDerivation.testFuzz_ComputeMarketKey_MatchesLiteralFormula`.
///      Collision surface: forging a key equal to a specific registered reserve's or market's is a 160-bit
///      second preimage (~2^160 keccak evaluations; 2^160 / N against N registered entries) — the 2^80
///      birthday figure does not apply because the target is fixed. A collision could only block a second
///      registration in the registry; hooks never call or approve the key (the Spoke in calldata is the sole
///      call target), so it is identity only.
///      Cross-namespace collision: the three derivations take 2-, 3- and 4-word preimages, but differing
///      preimage LENGTH is structural separation and NOT a proof — keccak256 is not injective across lengths
///      and all three truncate to 160 bits. The domain constants are what make the separation intentional and
///      auditable. On-chain a cross-namespace collision is harmless anyway: the two namespaces live in
///      separate registry mappings with disjoint consumers.
library AaveV4ReserveKey {
    /// @notice Thrown when a hook's header yield source (offset 32) is not the reserve key of the op's primary
    ///         reserve on the calldata Spoke
    error RESERVE_KEY_MISMATCH();

    /// @notice Thrown when a V2 LOAN hook's header yield source (offset 32) is not the market key of the
    ///         (spoke, supplyReserveId, borrowReserveId) triple the body acts on
    error MARKET_KEY_MISMATCH();

    /// @notice Domain separator mixed into the DEBT key preimage
    /// @dev FROZEN. This literal MUST NOT change once any registry is seeded with debt keys: it is baked
    ///      into every debt key ever derived, so editing it silently repoints every registered debt leg
    ///      while leaving every test that pins it passing. It names `AaveV4ReserveRegistryV2` because that
    ///      is the contract whose key space it defines (V1 has no debt leg);
    ///      `AaveV4ReserveRegistryV2.DEBT_KEY_DOMAIN` re-exports this value, and
    ///      `AaveV4ReserveOracleDispatch.t.sol` pins the two equal.
    bytes32 internal constant DEBT_KEY_DOMAIN = keccak256("AaveV4ReserveRegistryV2.DEBT");

    /// @notice Domain separator mixed into the MARKET key preimage
    /// @dev FROZEN once any market key is signed into a merkle root: it is baked into every market key ever
    ///      derived, so editing it silently repoints every registered market and every signed intent that
    ///      names one, while leaving every test that pins it passing.
    ///      Named after THIS LIBRARY, not after a registry — deliberately unlike its `DEBT_KEY_DOMAIN`
    ///      sibling, which baked a registry VERSION into a frozen constant and can never be corrected. Do
    ///      NOT "align" `DEBT_KEY_DOMAIN` to this convention: that literal is frozen and already baked into
    ///      live debt keys.
    bytes32 internal constant MARKET_KEY_DOMAIN = keccak256("AaveV4ReserveKey.MARKET");

    /// @notice Lower 20 bytes of keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN))
    /// @dev The DEBT counterpart to `computeReserveKey`. Lives here, beside the supply derivation, so Aave
    ///      V4 key derivation has exactly ONE home — the reason this library exists. Being `internal` and
    ///      unused by the hooks, it is dead-code-eliminated from their creation code: verified by
    ///      `AaveV4LoanBytecodeUnchanged.t.sol`, which pins all 14 deployed hooks' freshly compiled
    ///      creation code against their locked artifacts and still passes with this present.
    ///      A future accounting-typed debt hook needs this derivation; it must call this and never
    ///      re-implement the hash.
    /// @param spoke The Aave V4 spoke address
    /// @param reserveId The reserve identifier within the spoke
    /// @return The pseudo-address debt key
    function computeDebtKey(address spoke, uint256 reserveId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN)))));
    }

    /// @notice Lower 20 bytes of keccak256(abi.encode(spoke, reserveId))
    /// @param spoke The Aave V4 spoke address
    /// @param reserveId The reserve identifier within the spoke
    /// @return The pseudo-address reserve key
    function computeReserveKey(address spoke, uint256 reserveId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))));
    }

    /// @notice Lower 20 bytes of keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))
    /// @dev The INTENT-namespace derivation (SUP-21239): one key per Aave V4 market pair, so one economic
    ///      market is one yield source in merkle leaves, whitelists and the UI instead of two unrelated
    ///      reserve keys. Aave V4 has no market object on-chain (positions are reserve-granular), so a market
    ///      is a Superform curation decision: this key names one, `AaveV4ReserveRegistryV2.registerMarket`
    ///      records its bindings, and nothing on-chain enumerates markets.
    ///      ORDER IS SIGNIFICANT and MUST NOT be sorted: the legs are asymmetric — "equity collateral, borrow
    ///      USDC" and "USDC collateral, borrow equity" are different strategies with different risk, so
    ///      `computeMarketKey(s, a, b) != computeMarketKey(s, b, a)` and that asymmetry is pinned by test.
    ///      Tokens are NOT in the preimage: `loanToken` / `collateralToken` are a function of
    ///      `(spoke, reserveId)` and are already bound per call by the hooks' `_validateReserves` and at
    ///      registration by the registry, so including them would create a second source of truth and let two
    ///      keys name one market.
    ///      Being `internal` and unused by the V1 LOAN six, it is dead-code-eliminated from THEIR creation
    ///      code — `AaveV4LoanBytecodeUnchanged.t.sol` pins that empirically. The idle pair DOES reach it
    ///      since SUP-21263, through `requireHeaderIsMarketKey` in `_requireTargetIsMarketLeg` (and reaches
    ///      `computeReserveKey` too, for the lend hook's leg-exact `outToken`).
    /// @param spoke The Aave V4 spoke address
    /// @param supplyReserveId The collateral (supply) reserve identifier within the spoke
    /// @param borrowReserveId The loan (borrow) reserve identifier within the spoke
    /// @return The pseudo-address market key
    function computeMarketKey(
        address spoke,
        uint256 supplyReserveId,
        uint256 borrowReserveId
    )
        internal
        pure
        returns (address)
    {
        return
            address(uint160(uint256(keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN)))));
    }

    /// @notice Header pin shared by the V1 LOAN six and the idle pair: the header yield source must equal the
    ///         reserve key of the op's primary reserve on the calldata Spoke, so a crafted header can never name
    ///         a different reserve than the one the body acts on. Pure — safe inside pure decoders (build,
    ///         preExecute, inspect, sizing).
    /// @param headerKey The header yield source (offset 32)
    /// @param spoke The calldata Spoke
    /// @param reserveId The op's primary reserve id
    function requireHeaderKey(address headerKey, address spoke, uint256 reserveId) internal pure {
        if (headerKey != computeReserveKey(spoke, reserveId)) revert RESERVE_KEY_MISMATCH();
    }

    /// @notice Header pin for the V2 LOAN hooks (SUP-21239): the header yield source must equal the market key of
    ///         the (Spoke, supply reserve, borrow reserve) triple the body acts on, so a crafted header can never
    ///         name a different market — nor either leg's reserve key — than the one the body acts on. Pure, so
    ///         build, preExecute, inspect and — for the V2 LOAN hooks only — decodeAmounts and
    ///         replaceCalldataAmounts all fail closed. The idle pair deliberately leaves its three sizing
    ///         views length-and-bool-only (they are transformation APIs a bundler calls before
    ///         authentication); its resize window at offsets 124-155 is disjoint from every identity field,
    ///         so a resize can never turn a mis-keyed payload into a well-keyed one.
    ///         FOR THE IDLE PAIR the key is additionally a SuperLedger key and an oracle argument, and the
    ///         oracle resolves it to the market's SUPPLY leg. CAUTION, CHANGED BY SUP-21263: that leg is no
    ///         longer necessarily the reserve the op moved. The idle body now carries one `targetReserveId`
    ///         which may be EITHER leg, so when it is the BORROW leg the oracle's scalar read describes the
    ///         collateral reserve instead. Nothing in this library can detect that — membership is a registry
    ///         read in the hook. See SECURITY.md §16 and `BaseAaveV4MoneyMarketHook`'s contract docblock.
    /// @dev Replaces the per-hook `_primaryReserveId` selection the reserve-key pin needed: the market key is a
    ///      function of the WHOLE body, so there is no leg left to choose and the "override picked the wrong leg"
    ///      bug class is closed by construction rather than by convention.
    /// @param headerKey The header yield source (offset 32)
    /// @param spoke The calldata Spoke
    /// @param supplyReserveId The body's collateral (supply) reserve id
    /// @param borrowReserveId The body's loan (borrow) reserve id
    function requireHeaderIsMarketKey(
        address headerKey,
        address spoke,
        uint256 supplyReserveId,
        uint256 borrowReserveId
    )
        internal
        pure
    {
        if (headerKey != computeMarketKey(spoke, supplyReserveId, borrowReserveId)) revert MARKET_KEY_MISMATCH();
    }
}
