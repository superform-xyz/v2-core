// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

import { IAcrossV3Handler } from "src/interfaces/vendors/across/IAcrossV3Handler.sol";

library HandleV3AcrossMessage {
    error ADDRESS_NOT_VALID();

    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    struct Instructions {
        //  Calls that will be attempted.
        Call[] calls;
        // Where the tokens go if any part of the call fails.
        // Leftover tokens are sent here as well if the action succeeds.
        address fallbackRecipient;
    }

    /// @dev creates Across instruction
    function hook(
        address token,
        address acrossV3Handler,
        uint256 acrossValue,
        bytes memory data,
        address fallbackRecipient
    )
        internal
        pure
        returns (Execution[] memory executions)
    {
        // create Instructions
        Call[] memory calls = abi.decode(data, (Call[]));
        Instructions memory instructions = Instructions({ calls: calls, fallbackRecipient: fallbackRecipient });

        // create Execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(acrossV3Handler),
            value: acrossValue,
            callData: abi.encodeCall(
                IAcrossV3Handler.handleV3AcrossMessage, (token, 0, address(0), abi.encode(instructions))
            )
        });
    }
}
