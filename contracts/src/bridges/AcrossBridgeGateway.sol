// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

import { ISuperGatewayExecutor } from "src/interfaces/ISuperGatewayExecutor.sol";
import { IAcrossV3Receiver } from "src/interfaces/vendors/bridges/across/IAcrossV3Receiver.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

contract AcrossBridgeGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable acrossSpokePool;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address acrossSpokePool_) SuperRegistryImplementer(registry_) {
        acrossSpokePool = acrossSpokePool_;
    }

    modifier onlyAcrossSpokePool() {
        if (msg.sender != acrossSpokePool) revert INVALID_SENDER();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAcrossV3Receiver
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, //relayer; not used
        bytes memory message
    )
        external
        onlyAcrossSpokePool
    {
        // decode instructions
        IAcrossV3Interpreter.Instructions memory instructions = abi.decode(message, (IAcrossV3Interpreter.Instructions));

        // transfer funds to the smart account
        IERC20(tokenSent).transferFrom(address(this), instructions.entryPointData.account, amount);

        // execute the instructions
        ISuperGatewayExecutor(_getSuperGatewayExecutor()).execute(
            _getExecution(instructions), instructions.entryPointData
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the execution
    /// @param instructions The instructions
    function _getExecution(IAcrossV3Interpreter.Instructions memory instructions)
        internal
        pure
        returns (Execution[] memory executions)
    {
        executions = new Execution[](instructions.calls.length);
        for (uint256 i = 0; i < instructions.calls.length; i++) {
            executions[i] = Execution({
                target: instructions.calls[i].target,
                value: instructions.calls[i].value,
                callData: instructions.calls[i].callData
            });
        }
    }

    /// @notice Get the super gateway executor
    function _getSuperGatewayExecutor() internal view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_GATEWAY_EXECUTOR_ID());
    }
}
