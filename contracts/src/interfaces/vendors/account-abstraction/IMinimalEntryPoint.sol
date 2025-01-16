/**
 * Account-Abstraction (EIP-4337) singleton EntryPoint implementation.
 * Only one instance required on each chain.
 *
 */
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.5;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

interface IMinimalEntryPoint {
    /**
     * Execute a batch of UserOperations.
     * No signature aggregator is used.
     * If any account requires an aggregator (that is, it returned an aggregator when
     * performing simulateValidation), then handleAggregatedOps() must be used instead.
     * @param ops         - The operations to execute.
     * @param beneficiary - The address to receive the fees.
     */
    function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external;
}
