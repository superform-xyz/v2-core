// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { IAcrossSpokePoolV3 } from "src/interfaces/vendors/bridges/across/IAcrossSpokePoolV3.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

contract AcrossExecuteOnDestinationHook is BaseHook, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable spokePoolV3;

    struct AcrossV3DepositData {
        uint256 value;
        address recipient;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 quoteTimestamp;
        uint32 fillDeadline;
        uint32 exclusivityDeadline;
        IAcrossV3Interpreter.Instruction[] instructions;
    }

    constructor(address registry_, address author_, address spokePoolV3_) BaseHook(registry_, author_) {
        if (spokePoolV3_ == address(0)) revert ADDRESS_NOT_VALID();
        spokePoolV3 = spokePoolV3_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(bytes memory data) external view override returns (Execution[] memory executions) {
        AcrossV3DepositData memory acrossV3DepositData = abi.decode(data, (AcrossV3DepositData));

        // checks
        if (acrossV3DepositData.value == 0) revert AMOUNT_NOT_VALID();
        address _dstContract = _getAcrossGatewayExecutor();
        if (acrossV3DepositData.recipient == address(0) || _dstContract == address(0)) revert ADDRESS_NOT_VALID();

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: spokePoolV3,
            value: acrossV3DepositData.value,
            callData: abi.encodeCall(
                IAcrossSpokePoolV3.depositV3,
                (
                    _dstContract, // TODO: assume it has the same address on all chains
                    acrossV3DepositData.recipient,
                    acrossV3DepositData.inputToken,
                    acrossV3DepositData.outputToken,
                    acrossV3DepositData.inputAmount,
                    acrossV3DepositData.outputAmount,
                    acrossV3DepositData.destinationChainId,
                    acrossV3DepositData.exclusiveRelayer,
                    acrossV3DepositData.quoteTimestamp,
                    acrossV3DepositData.fillDeadline,
                    acrossV3DepositData.exclusivityDeadline,
                    abi.encode(acrossV3DepositData.instructions)
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(bytes memory)
        external
        pure
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return _returnDefaultTransientStorage();
    }

    /// @inheritdoc ISuperHook
    function postExecute(bytes memory)
        external
        pure
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return _returnDefaultTransientStorage();
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getAcrossGatewayExecutor() private view returns (address) {
        return superRegistry.getAddress(superRegistry.ACROSS_GATEWAY_ID());
    }
}
