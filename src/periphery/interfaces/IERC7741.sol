// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// @title IERC7741
interface IERC7741 {
    /**
     * @dev Grants or revokes permissions for `operator` to manage Requests on behalf of the
     *      `msg.sender`, using an [EIP-712](./eip-712.md) signature.
     */
    function authorizeOperator(
        address controller,
        address operator,
        bool approved,
        bytes32 nonce,
        uint256 deadline,
        bytes memory signature
    )
        external
        returns (bool);

    /**
     * @dev Revokes the given `nonce` for `msg.sender` as the `owner`.
     */
    function invalidateNonce(bytes32 nonce) external;

    /**
     * @dev Returns whether the given `nonce` has been used for the `controller`.
     */
    function authorizations(address controller, bytes32 nonce) external view returns (bool used);

    /**
     * @dev Returns the `DOMAIN_SEPARATOR` as defined according to EIP-712. The `DOMAIN_SEPARATOR
     *      should be unique to the contract and chain to prevent replay attacks from other domains,
     *      and satisfy the requirements of EIP-712, but is otherwise unconstrained.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
