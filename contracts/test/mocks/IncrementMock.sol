// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Flags } from "src/libraries/vendors/deBridge/Flags.sol";
import { IDeBridgeGate } from "src/interfaces/vendors/deBridge/IDeBridgeGate.sol";

import { CounterMock } from "./CounterMock.sol";

contract IncrementMock {
    IDeBridgeGate public deBridgeGate;

    uint256 counterChainId;
    address counterAddress;

    error INSUFFICIENT_FEE();

    function setGate(address _deBridgeGate) external {
        deBridgeGate = IDeBridgeGate(_deBridgeGate);
    }

    function registerCounter(uint256 _chainId, address _counterAddress) external {
        counterChainId = _chainId;
        counterAddress = _counterAddress;
    }

    function increment(uint8 _amount) external payable {
        bytes memory dstTxCall = abi.encodeWithSelector(CounterMock.receiveIncrement.selector, _amount);

        uint256 protocolFee = deBridgeGate.globalFixedNativeFee();
        if (msg.value < protocolFee) revert INSUFFICIENT_FEE();

        IDeBridgeGate.SubmissionAutoParamsTo memory autoParams;
        autoParams.executionFee = 0;
        autoParams.flags = Flags.setFlag(autoParams.flags, Flags.PROXY_WITH_SENDER, true);
        autoParams.flags = Flags.setFlag(autoParams.flags, Flags.REVERT_IF_EXTERNAL_FAIL, true);
        autoParams.data = dstTxCall;
        autoParams.fallbackAddress = abi.encodePacked(msg.sender);

        deBridgeGate.send{ value: msg.value }(
            address(0), 0, counterChainId, abi.encodePacked(counterAddress), "", true, 0, abi.encode(autoParams)
        );
    }
}
