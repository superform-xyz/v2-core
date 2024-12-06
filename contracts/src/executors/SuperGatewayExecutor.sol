// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
// modulekit
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";
import { ISuperGatewayExecutor } from "src/interfaces/ISuperGatewayExecutor.sol";
import { SuperRegistryImplementer } from "src/utils/SuperRegistryImplementer.sol";
import { IEntryPoint } from "src/interfaces/vendors/standards/erc4337/IEntryPoint.sol";
import { IUserOperation } from "src/interfaces/vendors/standards/erc4337/IUserOperation.sol";
import { IAcrossV3Interpreter } from "src/interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

contract SuperGatewayExecutor is ISuperGatewayExecutor, SuperRegistryImplementer {
    IEntryPoint public immutable entryPoint;
    uint192 public immutable SUPER_GATEWAY_ENTRY_POINT_KEY; // for nonce calculation; TODO: what key?

    constructor(address registry_, address entryPoint_) SuperRegistryImplementer(registry_) {
        if (entryPoint_ == address(0)) revert ADDRESS_NOT_VALID();
        entryPoint = IEntryPoint(entryPoint_);

        SUPER_GATEWAY_ENTRY_POINT_KEY = uint192(bytes24(bytes20(address(this))));
    }

    modifier onlyBridgeGateway() {
        ISuperRbac rbac = ISuperRbac(superRegistry.getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.BRIDGE_GATEWAY())) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGatewayExecutor
    function execute(
        Execution[] memory executions,
        IAcrossV3Interpreter.EntryPointData memory entryPointData
    )
        external
        onlyBridgeGateway
    {
        if (executions.length == 0) revert NO_EXECUTIONS();

        // execute calls
        // @dev EntryPoint https://etherscan.io/address/0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789#code
        IUserOperation.UserOperation[] memory userOps = _createPackedUserOps(entryPointData, executions);
        entryPoint.handleOps(userOps, entryPointData.beneficiary);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _createPackedUserOps(
        IAcrossV3Interpreter.EntryPointData memory entryPointData,
        Execution[] memory executions
    )
        private
        view
        returns (IUserOperation.UserOperation[] memory userOps)
    {
        uint256 nonce = entryPoint.getNonce(entryPointData.account, SUPER_GATEWAY_ENTRY_POINT_KEY);

        uint256 opsLength = executions.length;
        userOps = new IUserOperation.UserOperation[](opsLength);
        for (uint256 i; i < opsLength;) {
            userOps[i] = IUserOperation.UserOperation({
                sender: entryPointData.account,
                nonce: nonce, // current nonce
                initCode: "", // no need to create account here; it should be available
                callData: executions[i].callData,
                // TODO: do we need a dynamic gas limit?
                callGasLimit: entryPointData.callGasLimit,
                verificationGasLimit: entryPointData.verificationGasLimit,
                preVerificationGas: entryPointData.preVerificationGas,
                maxFeePerGas: entryPointData.maxFeePerGas,
                maxPriorityFeePerGas: entryPointData.maxPriorityFeePerGas,
                //
                paymasterAndData: entryPointData.paymasterAndData,
                signature: entryPointData.signature
            });
            //TODO: add flag to wait for other userOps to be executed

            // increment nonce for next call
            unchecked {
                ++i;
                nonce++;
            }
        }
    }
}
