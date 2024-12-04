// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { ISentinelProcessor } from "src/interfaces/sentinel/ISentinelProcessor.sol";
import { IComposabilityStackReader } from "src/interfaces/composability/IComposabilityStackReader.sol";

// The following decoder uses provided data or fetches it from the composability stack in case it's empty
contract Processor4626Deposit is ISentinelProcessor {
    IComposabilityStackReader public immutable reader;

    constructor(address reader_) {
        if (reader_ == address(0)) revert ADDRESS_NOT_VALID();
        reader = IComposabilityStackReader(reader_);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinelProcessor
    function process(address target_, bytes4 selector_, bytes memory data_) external view {
        if (data_.length == 0) {
            data_ = reader.get(target_, selector_);
        }
        if (data_.length == 0) revert NO_DATA_FOUND();

        if (selector_ == IERC4626.deposit.selector) {
            _processDeposit(target_, data_);
        } else if (selector_ == IERC4626.withdraw.selector) {
            _processWithdraw(target_, data_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    // target, data (to avoid warning)
    function _processDeposit(address, bytes memory) private pure {
        //selector is IERC4626.deposit.selector
    }

    // target, data (to avoid warning)
    function _processWithdraw(address, bytes memory) private pure {
        //selector is IERC4626.withdraw.selector
    }
}
