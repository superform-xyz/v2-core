// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { SuperPositions } from "src/superpositions/SuperPositions.sol";
import { ComposabilityStorageMock } from "src/mee-example/ComposabilityStorageMock.sol";

contract SuperPositionHelper {
    ComposabilityStorageMock public immutable composabilityStorage;

    error ADDRESS_NOT_VALID();

    constructor(address composabilityStorage_) {
        if (composabilityStorage_ == address(0)) revert ADDRESS_NOT_VALID();
        composabilityStorage = ComposabilityStorageMock(composabilityStorage_);
    }

    function retrieveAmountAndMint(address superPositions, address receiver) external {
        uint256 obtained = composabilityStorage.obtained();

        SuperPositions(superPositions).mint(receiver, obtained);
    }
}
