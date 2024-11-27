// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISentinel } from "src/interfaces/sentinel/ISentinel.sol";
import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";
import { ISentinelDecoder } from "src/interfaces/sentinel/ISentinelDecoder.sol";
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

contract SuperSentinel is ISentinel, SuperRegistryImplementer, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public decoders;

    constructor(address registry_, address owner_) SuperRegistryImplementer(registry_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel
    function updateDecoderStatus(address decoder_, bool status_) external onlyOwner {
        if (decoder_ == address(0)) revert ADDRESS_NOT_VALID();
        decoders[decoder_] = status_;
        emit DecoderStatusUpdated(decoder_, status_);
    }

    /// @inheritdoc ISentinel
    function notify(ISentinelData.Entry memory entry_) external {
        if (entry_.inputDecoder != address(0)) {
            if (!decoders[entry_.inputDecoder]) revert DECODER_NOT_WHITELISTED();
        }
        if (entry_.outputDecoder != address(0)) {
            if (!decoders[entry_.outputDecoder]) revert DECODER_NOT_WHITELISTED();
        }

        // act on the input
        ISentinelDecoder(entry_.inputDecoder).decode(entry_.target, entry_.input);

        // act on the output
        ISentinelDecoder(entry_.outputDecoder).decode(entry_.target, entry_.output);
    }
}
