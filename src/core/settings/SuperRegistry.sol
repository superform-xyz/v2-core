// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IModule, MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";

/// @title SuperRegistry
/// @author Superform Labs
/// @notice A registry for storing addresses of contracts
contract SuperRegistry is Ownable2Step, ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;
    mapping(address => bool) public isExecutorAllowed;

    constructor(address owner_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRegistry
    function setAddress(bytes32 id_, address address_) external override onlyOwner {
        if (address_ == address(0)) revert INVALID_ADDRESS();
        addresses[id_] = address_;
        emit AddressSet(id_, address_);

        if (address_.code.length > 0) {
            try IModule(address_).isModuleType(MODULE_TYPE_EXECUTOR) returns (bool isExecutor) {
                if (isExecutor) {
                    isExecutorAllowed[address_] = true;
            }
            } catch {
                // do nothing
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperRegistry
    function getAddress(bytes32 id_) external view override returns (address address_) {
        address_ = addresses[id_];
        if (address_ == address(0)) revert INVALID_ADDRESS();
    }
}
