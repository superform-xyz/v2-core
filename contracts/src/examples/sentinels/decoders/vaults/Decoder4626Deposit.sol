// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { ISentinelDecoder } from "src/interfaces/sentinel/ISentinelDecoder.sol";
import { IComposabilityStackReader } from "src/interfaces/composability/IComposabilityStackReader.sol";

contract Decoder4626Deposit is ISentinelDecoder {
    IComposabilityStackReader public immutable reader;

    constructor(address reader_) {
        if (reader_ == address(0)) revert ADDRESS_NOT_VALID();
        reader = IComposabilityStackReader(reader_);
    }

    function decode(address target_, bytes memory data_) external {
        // if data is empty, get the stored data from the composability stack
        // TODO: decide if this makes sense; should we maybe let user decide (add a param) ?
        if (data_.length == 0) {
            data_ = reader.get(target_, IERC4626.deposit.selector);
        }
        if (data_.length == 0) revert NO_DATA_FOUND();

        // TODO: for example here we can have the pricing computation
    }
}
