// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ISuperHookSwap
/// @author Superform Labs
/// @notice Interface for the Layer 1 standard swap calldata layout
/// @dev All SWAP-subtype hooks must implement this interface
/// @dev Layout (absolute byte offsets within full hook data):
///      [0:52]   Layer 0: zero-filled 52-byte strategy header
///      [52:72]  inputToken  (address, 20 bytes)
///      [72:92]  outputToken (address, 20 bytes)
///      [92:124] inputAmount (uint256, 32 bytes)
///      [124:156] outputQuote (uint256, 32 bytes)
///      [156:188] outputMin  (uint256, 32 bytes)
///      [188:189] usePrevHookAmount (bool, 1 byte)
///      [189:221] payloadLength (uint256, 32 bytes)
///      [221+]   payload — protocol-specific Layer 2 bytes (variable)
interface ISuperHookSwap {
    /// @notice Packed Layer 1 header fields for encoding swap hook data
    struct SwapHeader {
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputQuote;
        uint256 outputMin;
        bool usePrevHookAmount;
    }

    /// @notice Encode the full hook calldata from a Layer 1 header and a protocol-specific payload
    /// @param header The standardised Layer 1 fields
    /// @param payload Protocol-specific Layer 2 bytes (may be empty)
    /// @return data The complete encoded calldata: 52-byte zero prefix + Layer 1 + Layer 2
    function encodeSwapData(SwapHeader calldata header, bytes calldata payload) external pure returns (bytes memory data);

    /// @notice Decode the input token address from hook calldata (offset 52)
    function decodeInputToken(bytes calldata data) external pure returns (address);

    /// @notice Decode the output token address from hook calldata (offset 72)
    function decodeOutputToken(bytes calldata data) external pure returns (address);

    /// @notice Decode the input amount from hook calldata (offset 92)
    function decodeInputAmount(bytes calldata data) external pure returns (uint256);

    /// @notice Decode the output quote from hook calldata (offset 124)
    /// @dev Represents the aggregator-quoted expected output; equals outputMin for AMM hooks
    function decodeOutputQuote(bytes calldata data) external pure returns (uint256);

    /// @notice Decode the minimum acceptable output from hook calldata (offset 156)
    function decodeOutputMin(bytes calldata data) external pure returns (uint256);

    /// @notice Decode the protocol-specific payload from hook calldata (starting at offset 221)
    /// @dev payloadLength is read from offset 189 to know how many bytes to return
    function decodePayload(bytes calldata data) external pure returns (bytes memory);
}
