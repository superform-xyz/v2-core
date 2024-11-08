// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

interface IRelayer {
    /// @notice Send a message to the destination chain.
    /// @param dstChainId_ The destination chain ID.
    /// @param addr_ The destination address.
    /// @param data_ The data to send.
    function send(uint256 dstChainId_, address addr_, bytes memory data_) external;
}
