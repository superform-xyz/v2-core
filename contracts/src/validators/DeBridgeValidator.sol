// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccountInstance } from "modulekit/ModuleKit.sol";
import { DlnOrderLib } from "src/libraries/vendors/deBridge/DlnOrderLib.sol";
import { DlnExternalCallLib } from "src/libraries/vendors/deBridge/DlnExternalCallLib.sol";

import { IDlnDestination } from "src/interfaces/vendors/deBridge/IDlnDestination.sol";

// Superform
import { BytesLib } from "src/libraries/BytesLib.sol";

import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperRegistry } from "src/interfaces/ISuperRegistry.sol";
import { IBridgeValidator } from "src/interfaces/IBridgeValidator.sol";
import { ISuperExecutor } from "src/interfaces/executors/ISuperExecutor.sol";

contract DeBridgeValidator is IBridgeValidator {
    using BytesLib for bytes;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ISuperRegistry public superRegistry;
    ISuperExecutor public superExecutor;

    mapping(uint256 => mapping(address => bool)) public whitelistedSenders;

    address public constant DLN_DESTINATION = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ACCOUNT();
    error INVALID_EXECUTOR();
    error INVALID_RECEIVER();
    error ADDRESS_NOT_VALID();
    error INVALID_EXTERNAL_CALL();
    error NOT_BRIDGE_VALIDATOR_CONFIGURATOR();

    //error INVALID_DST_CHAIN();

    constructor(address registry_) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();

        superRegistry = ISuperRegistry(registry_);
    }

    modifier onlyBridgesValidatorConfigurator() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_VALIDATOR_CONFIGURATOR())) revert NOT_BRIDGE_VALIDATOR_CONFIGURATOR();
        _;
    }
    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /**
     * function addChain(uint256 chain_, address callerAddress_) external onlyBridgesValidatorConfigurator {
     *     if (callerAddress_ == address(0)) revert ADDRESS_NOT_VALID();
     *     whitelistedSenders[chain_][callerAddress_] = true;
     * }
     *
     * function removeChain(uint256 chain_, address callerAddress_) external onlyBridgesValidatorConfigurator {
     *     if (callerAddress_ == address(0)) revert ADDRESS_NOT_VALID();
     *     delete whitelistedSenders[chain_][callerAddress_];
     * }
     */

    function setSuperExecutor(address executor_) external onlyBridgesValidatorConfigurator {
        if (executor_ == address(0)) revert ADDRESS_NOT_VALID();
        superExecutor = ISuperExecutor(executor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IBridgeValidator
    function validateOrder(bytes memory txData_, address account_) external view override {
        (DlnOrderLib.OrderCreation memory order_,,,) =
            abi.decode(txData_, (DlnOrderLib.OrderCreation, bytes, uint32, bytes));

        // make sure token receiver is the same account
        // TODO: TBD
        if (account_ != _bytesToAddress(order_.receiverDst)) revert INVALID_RECEIVER();

        // decode `externalCall` envelope
        (bytes memory payload, address executorAddress) = _getPayload(order_.externalCall);
        if (executorAddress != address(superExecutor)) revert INVALID_EXECUTOR();

        // decode payload.callData
        DlnExternalCallLib.ExternalCallPayload memory externalPayload =
            abi.decode(payload, (DlnExternalCallLib.ExternalCallPayload));
        (AccountInstance memory instance,,,) =
            abi.decode(externalPayload.callData, (AccountInstance, address[], bytes[], uint256[]));
        if (instance.account != account_) revert INVALID_ACCOUNT();
    }

    /// @inheritdoc IBridgeValidator
    function validateReceiver(bytes memory, address) external view override {
        // get external call adapter
        IDlnDestination dlnDestination = IDlnDestination(DLN_DESTINATION);
        address externalCallAdapter = dlnDestination.externalCallAdapter();

        if (msg.sender != externalCallAdapter) revert INVALID_EXTERNAL_CALL();
    }

    /**
     * function createDispatchData(address receiver_, uint256 chainId_) external pure returns (bytes memory) {
     *     DlnOrderLib.OrderCreation memory deBridgeQuote_ = DlnOrderLib.OrderCreation({
     *         receiverDst: abi.encodePacked(receiver_),
     *         giveChainId: chainId_,
     *         takeChainId: block.chainid
     *     });
     *     return abi.encode(deBridgeQuote_);
     * }
     * function validateSender(bytes calldata txData_) external pure override {
     *     DlnOrderLib.OrderCreation memory deBridgeQuote_ = _decodeTxData(txData_);
     *     if (receiver != _bytesToAddress(deBridgeQuote_.receiverDst)) revert INVALID_RECEIVER();
     * }
     *
     * function validateReceiver(bytes calldata txData_, address receiver) external pure override {
     *     DlnOrderLib.Order memory receivedOrder_ = _decodeTxData(txData_);
     *
     *     // validate caller
     *     if (!whitelistedSenders[receivedOrder_.giveChainId][receivedOrder_.makerSrc]) revert INVALID_CALLER();
     *
     *     // verify chainId
     *     if (receivedOrder_.takeChainId != block.chainid) revert INVALID_DST_CHAIN();
     *
     *     // verify receiver
     *     if (receiver != _bytesToAddress(receivedOrder_.receiverDst)) revert INVALID_RECEIVER();
     * }
     */
    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _bytesToAddress(bytes memory b_) private pure returns (address) {
        address decodedAddress;
        assembly {
            decodedAddress := mload(add(b_, 20))
        }
        return decodedAddress;
    }

    /// @dev Get envelope data
    ///      See
    /// {https://github.com/debridge-finance/dln-contracts/blob/main/contracts/adapters/DlnExternalCallAdapter.sol}
    function _getEnvelopeData(bytes memory _externalCall)
        internal
        pure
        returns (uint8 envelopeVersion, bytes memory envelopData)
    {
        envelopeVersion = BytesLib.toUint8(_externalCall, 0);
        // Remove first byte from data
        envelopData = BytesLib.slice(_externalCall, 1, _externalCall.length - 1);
    }

    function _getPayload(bytes memory externalCall) internal pure returns (bytes memory, address) {
        (uint8 envelopeVersion, bytes memory envelopData) = _getEnvelopeData(externalCall);
        if (envelopeVersion != 1) revert INVALID_EXTERNAL_CALL();

        DlnExternalCallLib.ExternalCallEnvelopV1 memory decodedEnvelope =
            abi.decode(envelopData, (DlnExternalCallLib.ExternalCallEnvelopV1));

        return (decodedEnvelope.payload, decodedEnvelope.executorAddress);
    }
}
