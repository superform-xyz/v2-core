
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import {IComposabilityStackWriter} from "src/interfaces/composability/IComposabilityStackWriter.sol";

contract ComposabilityStackMock is IComposabilityStackWriter {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => bytes) public stored;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event DataStored(bytes32 key, bytes data);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_KEY();

    /// @inheritdoc IComposabilityStackWriter
    function store(bytes32 key, bytes memory data) external {
        if (key == bytes32(0)) revert INVALID_KEY();

        stored[key] = data;
        emit DataStored(key, data);
    }
}

