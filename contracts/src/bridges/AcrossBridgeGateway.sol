// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";

import { ISuperExecutorV2 } from "src/interfaces/ISuperExecutorV2.sol";
import { IAcrossV3Receiver } from "src/interfaces/vendors/bridges/across/IAcrossV3Receiver.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

contract AcrossBridgeGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable acrossSpokePool;


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event InstructionProcessed(address indexed account, uint256 amount);


    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address acrossSpokePool_) SuperRegistryImplementer(registry_) {
        acrossSpokePool = acrossSpokePool_;
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
    {
        if (msg.sender != acrossSpokePool) revert INVALID_SENDER();

        // decode instruction
        IAcrossV3Interpreter.Instruction memory instruction = abi.decode(message, (IAcrossV3Interpreter.Instruction));

        // send tokens to the smart account
        IERC20(tokenSent).transferFrom(address(this), instruction.account, instruction.amount);

        // execute the strategy
        ISuperExecutorV2(_getSuperExecutor()).executeFromGateway(instruction.account, instruction.strategyData);

        emit InstructionProcessed(instruction.account, instruction.amount);
    }


    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the super gateway executor
    function _getSuperExecutor() internal view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_EXECUTOR_ID());
    }
}
