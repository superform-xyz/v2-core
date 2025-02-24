// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

contract SuperRegistry is AccessControlEnumerable, ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;

    // Fee split configuration
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant MAX_FEE_SPLIT = 10_000;

    uint256 private feeSplit;
    uint256 private proposedFeeSplit;
    uint256 private feeSplitEffectiveTime;

    constructor(address owner) {
        if (owner == address(0)) revert INVALID_ACCOUNT();
        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        // Initialize with a default fee split of 20% (2000 basis points)
        feeSplit = 2000;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRegistry
    function setRole(address account_, bytes32 role_, bool allowed_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account_ == address(0)) revert INVALID_ACCOUNT();
        if (role_ == bytes32(0)) revert INVALID_ROLE();
        if (allowed_) {
            _grantRole(role_, account_);
        } else {
            _revokeRole(role_, account_);
        }
        emit RoleUpdated(account_, role_, allowed_);
    }

    /// @inheritdoc ISuperRegistry
    function setAddress(bytes32 id_, address address_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address_ == address(0)) revert INVALID_ADDRESS();
        addresses[id_] = address_;
        emit AddressSet(id_, address_);
    }

    /// @inheritdoc ISuperRegistry
    function proposeFeeSplit(uint256 feeSplit_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (feeSplit_ > MAX_FEE_SPLIT) revert INVALID_FEE_SPLIT();

        proposedFeeSplit = feeSplit_;
        feeSplitEffectiveTime = block.timestamp + ONE_WEEK;

        emit FeeSplitProposed(feeSplit_, feeSplitEffectiveTime);
    }

    /// @inheritdoc ISuperRegistry
    function executeFeeSplitUpdate() external {
        if (block.timestamp < feeSplitEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        feeSplit = proposedFeeSplit;
        proposedFeeSplit = 0;
        feeSplitEffectiveTime = 0;

        emit FeeSplitUpdated(feeSplit);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRegistry
    function getAddress(bytes32 id_) public view override returns (address address_) {
        address_ = addresses[id_];
        if (address_ == address(0)) revert INVALID_ADDRESS();
    }

    /// @inheritdoc ISuperRegistry
    function getSuperformFeeSplit() external view returns (uint256) {
        return feeSplit;
    }

    /// @inheritdoc ISuperRegistry
    function getTreasury() external view returns (address) {
        return getAddress(keccak256("TREASURY_ID"));
    }
}
