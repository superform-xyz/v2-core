// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { ISharedStateReader } from "src/interfaces/state/ISharedStateReader.sol";
import { ISentinelProcessor } from "src/interfaces/sentinel/ISentinelProcessor.sol";

// The following decoder uses provided data or fetches it from the shared state in case it's empty
contract Processor4626Deposit is ISentinelProcessor {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    ISharedStateReader public immutable reader;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error AMOUNT_EXCEEDS_BALANCE();

    constructor(address reader_) {
        if (reader_ == address(0)) revert ADDRESS_NOT_VALID();
        reader = ISharedStateReader(reader_);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinelProcessor
    function process(
        bytes32 key_, //shared state key
        address target_,
        bytes4 selector_,
        bytes memory data_
    )
        external
        view
        override
        returns (bytes memory eventOutput_)
    {
        uint256 amount_;

        if (data_.length == 0) {
            // TODO: check if this is the correct sender
            amount_ = reader.getUint(key_, msg.sender);
        } else {
            amount_ = abi.decode(data_, (uint256));
        }

        if (selector_ == IERC4626.deposit.selector) {
            _processDeposit(target_, data_, key_);
        } else if (selector_ == IERC4626.withdraw.selector) {
            _processWithdraw(target_, data_, key_);
        }

        // valid for both cases
        eventOutput_ = abi.encode(amount_);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _processDeposit(address target_, bytes memory data_, bytes32 key_) private view {
        (uint256 obtainedShares_, bool readFromSharedState_) = abi.decode(data_, (uint256, bool));
        if (readFromSharedState_) {
            obtainedShares_ = reader.getUint(key_, msg.sender);
        }
        
        //selector is IERC4626.deposit.selector
        uint256 balanceOfAccount = IERC4626(target_).balanceOf(msg.sender);
        if (obtainedShares_ > balanceOfAccount) revert AMOUNT_EXCEEDS_BALANCE();

        //TODO: what else should be done here? Maybe pricing updates
    }

    // target, data (to avoid warning)
    function _processWithdraw(address, bytes memory, bytes32) private pure {
        //selector is IERC4626.withdraw.selector
        //TODO: what else should be done here? Maybe pricing updates
    }
}
