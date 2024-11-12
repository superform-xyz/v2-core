// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ICallProxy } from "src/interfaces/vendors/ICallProxy.sol";
import { IDeBridgeGate } from "src/interfaces/vendors/IDeBridgeGate.sol";

contract CounterMock {
    uint256 public counter;
    IDeBridgeGate public deBridgeGate;
    mapping(uint256 => ChainInfo) public supportedChains;

    struct ChainInfo {
        bool isSupported;
        bytes callerAddress;
    }

    error CHAIN_NOT_SUPPORTED();
    error CALLER_NOT_AUTHORIZED();
    error INITIATOR_NOT_AUTHORIZED();

    modifier onlyCrossChainIncrementor() {
        ICallProxy callProxy = ICallProxy(deBridgeGate.callProxy());
        if (address(callProxy) != msg.sender) revert CALLER_NOT_AUTHORIZED();

        uint256 chainIdFrom = callProxy.submissionChainIdFrom();
        if (supportedChains[chainIdFrom].callerAddress.length == 0) revert CHAIN_NOT_SUPPORTED();

        bytes memory nativeSender = callProxy.submissionNativeSender();
        if (keccak256(supportedChains[chainIdFrom].callerAddress) != keccak256(nativeSender)) {
            revert INITIATOR_NOT_AUTHORIZED();
        }

        _;
    }

    function setGate(address _deBridgeGate) external {
        deBridgeGate = IDeBridgeGate(_deBridgeGate);
    }

    function receiveIncrement(uint256 _increment) external onlyCrossChainIncrementor {
        counter += _increment;
    }
}
