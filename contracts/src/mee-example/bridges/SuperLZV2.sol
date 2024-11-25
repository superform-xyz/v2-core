// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

// Superform
import { IBridge } from "src/mee-example/interfaces/IBridge.sol";
import { IStrategyExecutor } from "src/mee-example/interfaces/IStrategyExecutor.sol";
import "forge-std/console.sol";

contract SuperLZV2 is OApp, IBridge {
    IStrategyExecutor public immutable strategyExecutor;

    Execution[] public executions;

    constructor(address strategyExecutor_, address endpoint_, address delegatee_) OApp(endpoint_, delegatee_) {
        strategyExecutor = IStrategyExecutor(strategyExecutor_);
    }

    function getExecutions() external view returns (Execution[] memory) {
        return executions;
    }

    /// @notice Sends a message from the source to destination chain.
    /// @param data The message to send. {dstEid, payload, options}
    function send(bytes memory data) external payable {
        (uint32 dstEid, bytes memory payload, bytes memory options) = abi.decode(data, (uint32, bytes, bytes));

        // send would look like this
        /**
         * _lzSend(
         *         dstEid,
         *         payload,
         *         options,
         *         // Fee in native gas and ZRO token.
         *         MessagingFee(msg.value, 0),
         *         // Refund address in case of failed source message.
         *         payable(msg.sender)
         *     );
         */
    }

    function receiveMock(bytes memory data) external {
        Execution[] memory executions_ = strategyExecutor.executeStrategy(data);

        delete executions;
        for (uint256 i; i < executions_.length; i++) {
            executions.push(executions_[i]);
        }
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata _message, address, bytes calldata) internal override {
        // payload should have the following format:
        //       (uint256 strategyId, bytes[] memory encodedCalls)

        Execution[] memory executions_ = strategyExecutor.executeStrategy(_message);

        delete executions;
        for (uint256 i; i < executions_.length; i++) {
            executions.push(executions_[i]);
        }

        // TBD: ideally here we should emit an event and execute ?
        //   or use the Composability stack, store the execution flow in a queue and execute it?
        //               is this a possible use case for the composability stack?
    }
}
