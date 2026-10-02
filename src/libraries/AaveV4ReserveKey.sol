// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title AaveV4ReserveKey
/// @author Superform Labs
/// @notice Reserve-key derivation shared by every Aave V4 LOAN hook: the 20-byte pseudo-address that identifies
///         one (spoke, reserveId) pair as a Superform yield source.
/// @dev Single definition: `AaveV4ReserveRegistryV2.computeReserveKey` (the `public pure` off-chain indexers call),
///      the idle `BaseAaveV4MoneyMarketHook` decoder and both LOAN bases all delegate here. The literal formula
///      `address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))` is what off-chain consumers derive;
///      it is pinned independently of this library by `testFuzz_ReserveKey_MatchesLiteralFormula` (LOAN unit
///      suite) and `test/unit/accounting/oracles/AaveV4Oracles.t.sol`.
///      Collision surface: forging a key equal to a specific registered reserve's is a 160-bit second preimage
///      (~2^160 keccak evaluations; 2^160 / N against N registered reserves) — the 2^80 birthday figure does not
///      apply because the target is fixed. A collision could only block a second registration in the registry;
///      hooks never call or approve the key (the Spoke in calldata is the sole call target), so it is identity only.
library AaveV4ReserveKey {
    /// @notice Thrown when a hook's header yield source (offset 32) is not the reserve key of the op's primary
    ///         reserve on the calldata Spoke
    error RESERVE_KEY_MISMATCH();

    /// @notice Domain separator mixed into the DEBT key preimage
    /// @dev FROZEN. This literal MUST NOT change once any registry is seeded with debt keys: it is baked
    ///      into every debt key ever derived, so editing it silently repoints every registered debt leg
    ///      while leaving every test that pins it passing. It names `AaveV4ReserveRegistryV2` because that
    ///      is the contract whose key space it defines (V1 has no debt leg);
    ///      `AaveV4ReserveRegistryV2.DEBT_KEY_DOMAIN` re-exports this value, and
    ///      `AaveV4ReserveOracleDispatch.t.sol` pins the two equal.
    bytes32 internal constant DEBT_KEY_DOMAIN = keccak256("AaveV4ReserveRegistryV2.DEBT");

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

    /// @notice Header pin shared by every Aave V4 hook: the header yield source must equal the reserve key of the
    ///         op's primary reserve on the calldata Spoke, so a crafted header can never name a different reserve
    ///         than the one the body acts on. Pure — safe inside pure decoders (build, preExecute, inspect, sizing).
    /// @param headerKey The header yield source (offset 32)
    /// @param spoke The calldata Spoke
    /// @param reserveId The op's primary reserve id
    function requireHeaderKey(address headerKey, address spoke, uint256 reserveId) internal pure {
        if (headerKey != computeReserveKey(spoke, reserveId)) revert RESERVE_KEY_MISMATCH();
    }
}
