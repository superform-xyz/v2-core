// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperGatewayExecutorV2 } from "../interfaces/ISuperGatewayExecutorV2.sol";
import { IAcrossV3Receiver } from "../interfaces/vendors/bridges/across/IAcrossV3Receiver.sol";
import { IAcrossV3Interpreter } from "../interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

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

        // decode instructions
        IAcrossV3Interpreter.Instruction[] memory instructions = decodeInstructions(message);

        uint256 len = instructions.length; 
        if (len == 0) return;

        for (uint256 i = 0; i < len;) {
            IAcrossV3Interpreter.Instruction memory _instruction = instructions[i];
            IERC20(tokenSent).transferFrom(address(this), _instruction.account, _instruction.amount);

            ISuperGatewayExecutorV2(_getSuperGatewayExecutor()).execute(_instruction.strategyData);

            emit InstructionProcessed(_instruction.account, _instruction.amount);
            unchecked {
                ++i;
            }
        }
    }


    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function decodeInstructions(bytes memory message) private pure returns (IAcrossV3Interpreter.Instruction[] memory) {
        return abi.decode(message, (IAcrossV3Interpreter.Instruction[]));
    }

    /// @notice Get the super gateway executor
    function _getSuperGatewayExecutor() internal view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_GATEWAY_EXECUTOR_ID());
    }
}
