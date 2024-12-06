// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ISentinelData {
    /// @dev Entry struct.
    struct Entry {
        address target;
        bytes4 selector;
        bool processInput;
        bytes input;
        address inputProcessor;
        bytes output;
        address outputProcessor;
    }
}
