// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISentinel } from "../interfaces/ISentinel.sol";

contract SuperformSentinel is Ownable, ISentinel {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public superRegistry;

    mapping(address => bool) public whitelistedHooks;
    // hook -> entries
    mapping(address => ISentinel.Entry[]) public entries;
    // hook -> index -> inputs
    mapping(address => mapping(uint256 => ISentinel.Entry)) private _entry;

    constructor(address owner) Ownable(owner) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set the whitelisted status of a hook.
    /// @param hook_ The address of the hook.
    /// @param status_ Whether the hook is allowed.
    function setWhitelistedCaller(address hook_, bool status_) external onlyOwner {
        if (hook_ == address(0)) revert INVALID_HOOK();
        whitelistedHooks[hook_] = status_;
        emit WhitelistedHook(hook_, status_);
    }

    /// @notice Set the super registry.
    /// @param superRegistry_ The address of the super registry.
    function setSuperRegistry(address superRegistry_) external onlyOwner {
        if (superRegistry_ == address(0)) revert INVALID_SUPER_REGISTRY();
        superRegistry = superRegistry_;
        emit SuperRegistrySet(superRegistry_);
    }
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel

    function allowed(address hook_) external view override returns (bool) {
        return whitelistedHooks[hook_];
    }

    /// @inheritdoc ISentinel
    function entriesLength(address hook_) external view override returns (uint256) {
        return entries[hook_].length;
    }

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinel
    function notifyFromAccount(bytes calldata data_) external override {
        ISentinel.Entry memory newEntry = ISentinel.Entry(data_, "", true);
        entries[msg.sender].push(newEntry);
        _entry[msg.sender][entries[msg.sender].length - 1] = newEntry;
    }

    /// @inheritdoc ISentinel
    function notify(bytes calldata data_, bytes calldata output_, bool success_) external override {
        _notify(data_, output_, success_);
    }

    /// @inheritdoc ISentinel
    function batchNotify(
        bytes[] calldata data_,
        bytes[] calldata output_,
        bool[] calldata success_
    )
        external
        override
    {
        uint256 length = data_.length;
        for (uint256 i; i < length; i++) {
            _notify(data_[i], output_[i], success_[i]);
        }
    }

    /// @inheritdoc ISentinel
    function entry(address hook_, uint256 index_) external view override returns (ISentinel.Entry memory) {
        return _entry[hook_][index_];
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _notify(bytes calldata data_, bytes calldata output_, bool success_) private {
        if (!whitelistedHooks[msg.sender]) revert NOTIFIER_NOT_ALLOWED();

        ISentinel.Entry memory newEntry = ISentinel.Entry(data_, output_, success_);
        entries[msg.sender].push(newEntry);
        _entry[msg.sender][entries[msg.sender].length - 1] = newEntry;
    }
}
