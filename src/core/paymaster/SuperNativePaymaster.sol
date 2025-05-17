// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IEntryPointSimulations } from "modulekit/external/ERC4337.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { UserOperationLib } from "../../vendor/account-abstraction/UserOperationLib.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
// superform
import { BasePaymaster } from "../../vendor/account-abstraction/BasePaymaster.sol";
import { ISuperNativePaymaster } from "../interfaces/ISuperNativePaymaster.sol";

/// @title SuperNativePaymaster
/// @author Superform Labs
/// @notice A paymaster contract that allows users to pay for their operations with native tokens.
/// @dev Inspired by https://github.com/0xPolycode/klaster-smart-contracts/blob/master/contracts/KlasterPaymasterV7.so
contract SuperNativePaymaster is BasePaymaster, ISuperNativePaymaster {
    using UserOperationLib for PackedUserOperation;

    uint256 internal constant UINT128_BYTES = 16;
    uint256 internal constant MAX_NODE_OPERATOR_PREMIUM = 10_000;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    constructor(IEntryPoint _entryPoint) payable BasePaymaster(_entryPoint) {
        if (address(_entryPoint).code.length == 0) revert ZERO_ADDRESS();
    }
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperNativePaymaster
    function calculateRefund(
        uint256 maxGasLimit,
        uint256 maxFeePerGas,
        uint256 actualGasCost,
        uint256 nodeOperatorPremium
    )
        public
        pure
        returns (uint256 refund)
    {
        if (nodeOperatorPremium > MAX_NODE_OPERATOR_PREMIUM) revert INVALID_NODE_OPERATOR_PREMIUM();
        uint256 costWithPremium =
            Math.mulDiv(actualGasCost, MAX_NODE_OPERATOR_PREMIUM + nodeOperatorPremium, MAX_NODE_OPERATOR_PREMIUM);

        uint256 maxCost = maxGasLimit * maxFeePerGas;
        if (costWithPremium < maxCost) {
            refund = maxCost - costWithPremium;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperNativePaymaster
    function handleOps(PackedUserOperation[] calldata ops) public payable {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success,) = payable(address(entryPoint)).call{ value: balance }("");
            if (!success) revert INSUFFICIENT_BALANCE();
        }
        // note: msg.sender is the SuperBundler on same chain, or a cross-chain Gateway contract on the destination
        // chain
        entryPoint.handleOps(ops, payable(msg.sender));
        entryPoint.withdrawTo(payable(msg.sender), entryPoint.getDepositInfo(address(this)).deposit);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32,
        uint256
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        (uint256 maxGasLimit, uint256 nodeOperatorPremium) =
            abi.decode(userOp.paymasterAndData[PAYMASTER_DATA_OFFSET:], (uint256, uint256));

        if (nodeOperatorPremium > MAX_NODE_OPERATOR_PREMIUM) {
            revert INVALID_NODE_OPERATOR_PREMIUM();
        }
        return (abi.encode(userOp.sender, userOp.unpackMaxFeePerGas(), maxGasLimit, nodeOperatorPremium), 0);
    }

    /// @notice Handle the post-operation logic.
    ///         Executes userOp and gives back refund to the userOp.sender if userOp.sender has overpaid for execution.
    /// @dev Verified to be called only through the entryPoint.
    ///      If subclass returns a non-empty context from validatePaymasterUserOp, it must also implement this method.
    ///                                    Now this is the 2nd call, after user's op was deliberately reverted.
    /// @param context The context value returned by validatePaymasterUserOp.
    /// @param actualGasCost The actual gas used so far (without this postOp call).
    function _postOp(
        PostOpMode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256
    )
        /**
         * actualUserOpFeePerGas
         */
        internal
        virtual
        override
    {
        (address sender, uint256 maxFeePerGas, uint256 maxGasLimit, uint256 nodeOperatorPremium) =
            abi.decode(context, (address, uint256, uint256, uint256));

        uint256 refund = calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium);
        if (refund > 0) {
            entryPoint.withdrawTo(payable(sender), refund);
            emit SuperNativePaymsterRefund(sender, refund);
        }

        emit SuperNativePaymasterPostOp(context);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getEntryPointWithSimulations() private view returns (IEntryPointSimulations) {
        return IEntryPointSimulations(address(entryPoint));
    }
}
