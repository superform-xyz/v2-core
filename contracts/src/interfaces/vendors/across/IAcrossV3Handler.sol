// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface IAcrossV3Handler {
    /**
     * @notice Main entrypoint for the handler called by the SpokePool contract.
     * @dev This will execute all calls encoded in the msg. The caller is responsible for making sure all tokens are
     * drained from this contract by the end of the series of calls. If not, they can be stolen.
     * A drainLeftoverTokens call can be included as a way to drain any remaining tokens from this contract.
     * @param message abi encoded array of Call structs, containing a target, callData, and value for each call that
     * the contract should make.
     */
    function handleV3AcrossMessage(address token, uint256, address, bytes memory message) external;
}
