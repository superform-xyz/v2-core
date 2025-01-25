// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IHookDataEncoder } from "../interfaces/IHookDataEncoder.sol";
import { IHookDataEncoderRegistry } from "../interfaces/IHookDataEncoderRegistry.sol";

contract HookDataEncoderRegistry is IHookDataEncoderRegistry, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Role for managing encoders
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Mapping of vault type to encoder
    mapping(string => IHookDataEncoder) public override encoders;

    /// @notice List of supported types
    string[] public override types;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event EncoderRegistered(string type_, address encoder);
    event EncoderRemoved(string type_);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error INVALID_ENCODER();
    error TYPE_NOT_FOUND();
    error TYPE_ALREADY_EXISTS();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address manager_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, manager_);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHookDataEncoderRegistry
    function registerEncoder(IHookDataEncoder encoder) external override onlyRole(MANAGER_ROLE) {
        if (address(encoder) == address(0)) revert INVALID_ENCODER();
        string memory vaultType = encoder.getType();
        if (address(encoders[vaultType]) != address(0)) revert TYPE_ALREADY_EXISTS();

        encoders[vaultType] = encoder;
        types.push(vaultType);
        emit EncoderRegistered(vaultType, address(encoder));
    }

    /// @inheritdoc IHookDataEncoderRegistry
    function removeEncoder(string calldata type_) external override onlyRole(MANAGER_ROLE) {
        if (address(encoders[type_]) == address(0)) revert TYPE_NOT_FOUND();

        delete encoders[type_];
        emit EncoderRemoved(type_);
    }

    /// @inheritdoc IHookDataEncoderRegistry
    function getEncoder(string calldata type_) external view override returns (IHookDataEncoder) {
        IHookDataEncoder encoder = encoders[type_];
        if (address(encoder) == address(0)) revert TYPE_NOT_FOUND();
        return encoder;
    }

    /// @inheritdoc IHookDataEncoderRegistry
    function getSupportedTypes() external view override returns (string[] memory) {
        return types;
    }
} 