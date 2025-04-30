// contracts/ReplaceBenchmark.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

contract ReplaceBenchmark {
    /// @notice Naïve byte‐by‐byte replacement of a 65‐byte signature segment
    function naiveReplace(
        bytes calldata data,
        uint256 start,
        uint256 length,
        bytes calldata signature
    )
        external
        pure
        returns (bytes memory result)
    {
        require(length == signature.length, "length mismatch");
        uint256 readPtr = 0;
        uint256 sigPtr = 0;
        uint256 writePtr = 0;
        result = new bytes(data.length);

        // byte‐by‐byte copy with replacement
        for (; readPtr < start; readPtr++) {
            result[writePtr++] = data[readPtr];
        }
        for (; sigPtr < length; sigPtr++) {
            result[writePtr++] = signature[sigPtr];
            readPtr++;
        }
        for (; readPtr < data.length; readPtr++) {
            result[writePtr++] = data[readPtr];
        }
    }

    /// @notice Optimized chunk‐copies using assembly
    function optimizedReplace(
        bytes calldata data,
        uint256 start,
        uint256 length,
        bytes calldata signature
    )
        external
        pure
        returns (bytes memory result)
    {
        require(length == signature.length, "length mismatch");
        result = new bytes(data.length);

        assembly {
            let dataOffset := data.offset
            let sigOffset := signature.offset
            let resultPtr := add(result, 0x20)

            // 1) copy prefix [0 .. start)
            calldatacopy(resultPtr, dataOffset, start)
            // 2) copy signature in one go
            calldatacopy(add(resultPtr, start), sigOffset, length)
            // 3) copy suffix [start+length .. end)
            let suffixOffset := add(dataOffset, add(start, length))
            let suffixLen := sub(sub(data.length, start), length)
            calldatacopy(add(resultPtr, add(start, length)), suffixOffset, suffixLen)
        }
    }
}
