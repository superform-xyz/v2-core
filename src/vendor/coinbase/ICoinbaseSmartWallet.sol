// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @notice The owner-set surface of a Coinbase Smart Wallet ("Base Smart Wallet").
/// @dev Selectors verified against the live implementation `0x000100abaad02f1cfC8Bbe32bD5a564817339E72`
///      (reached through the factory `0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a`) on 2026-10-06:
///      `nextOwnerIndex()` 0xd948fd2e, `ownerAtIndex(uint256)` 0x8ea69029, `isOwnerBytes(bytes)` 0x1ca5393f,
///      `isOwnerAddress(address)` 0xa2e1a8d8, `isOwnerPublicKey(bytes32,bytes32)` 0x066a1eb7.
///      `ownerAtIndex` returns `abi.encode(address)` (32 bytes) for an ECDSA owner and `abi.encode(x, y)`
///      (64 bytes) for a passkey owner, and empty bytes for an index whose owner was removed.
/// @dev `replaySafeHash` and `isValidSignature` are deliberately NOT declared: the wallet's own ERC-1271 is
///      bound to `chainId` and `verifyingContract`, which is precisely why
///      `ChainAgnosticCoinbaseSmartWalletValidation` verifies against a fixed domain instead of delegating.
interface ICoinbaseSmartWallet {
    /// @notice Next index to be assigned to a new owner; also the upper bound of occupied indices
    function nextOwnerIndex() external view returns (uint256);

    /// @notice Number of CURRENT owners (removals decrement this but do not reindex)
    function ownerCount() external view returns (uint256);

    /// @notice The owner registered at `index`, or empty bytes if it was removed
    function ownerAtIndex(uint256 index) external view returns (bytes memory);

    /// @notice Whether `account` is a registered ECDSA owner
    function isOwnerAddress(address account) external view returns (bool);

    /// @notice Whether the P-256 public key `(x, y)` is a registered owner
    function isOwnerPublicKey(bytes32 x, bytes32 y) external view returns (bool);
}
