// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IDlnSource } from "src/interfaces/vendors/deBridge/IDlnSource.sol";
import { DlnOrderLib } from "src/libraries/vendors/deBridge/DlnOrderLib.sol";

library CreateDebridgeOrder {
    function hook(
        bytes memory data,
        address dlnSource,
        uint256 value
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        (
            DlnOrderLib.OrderCreation memory orderCreation,
            bytes memory affiliateFee,
            uint32 referralCode,
            bytes memory permitEnvelope
        ) = abi.decode(data, (DlnOrderLib.OrderCreation, bytes, uint32, bytes));

        executions = new Execution[](1);
        executions[0] = Execution({
            target: dlnSource,
            value: value,
            callData: abi.encodeCall(IDlnSource.createOrder, (orderCreation, affiliateFee, referralCode, permitEnvelope))
        });
    }
}
