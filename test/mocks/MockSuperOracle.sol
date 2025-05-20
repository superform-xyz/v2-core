// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { IOracle } from "../../src/vendor/awesome-oracles/IOracle.sol";

// Mock SuperOracle implementation for testing
contract MockSuperOracle is IOracle {
    uint256 public quoteAmount;

    constructor(uint256 _quoteAmount) {
        quoteAmount = _quoteAmount;
    }

    function setQuoteAmount(uint256 _quoteAmount) external {
        quoteAmount = _quoteAmount;
    }

    function getQuote(uint256, address, address) external view returns (uint256) {
        return quoteAmount;
    }
}
