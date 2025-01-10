// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { ERC7579HookBase } from "modulekit/Modules.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperRbac } from "../interfaces/ISuperRbac.sol";

contract LockFundsAccountHook is ERC7579HookBase, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address account => mapping(address asset => uint256 lockedAmount)) private lockedAmounts;
    mapping(address account => address[] tokens) private lockedTokens;
      
    address constant ENTRYPOINT_0_7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_ENTRYPOINT();
    error NOT_AUTHORIZED();
    error NOT_IMPLEMENTED();
    error NOT_ENOUGH_LOCKED_AMOUNT();
    error USED_MORE_FUNDS_THAN_ALLOWED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event LockFunds(address indexed account, address indexed asset, uint256 amount);
    event UnlockFunds(address indexed account, address indexed asset, uint256 amount);

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    modifier onlyExecutor() {
        if (_getAddress(superRegistry.SUPER_EXECUTOR_ID()) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

    modifier onlySuperPositionManager() {
        ISuperRbac rbac = ISuperRbac(_getAddress(superRegistry.SUPER_RBAC_ID()));
        if (!rbac.hasRole(msg.sender, rbac.SUPER_POSITION_MANAGER())) revert NOT_AUTHORIZED();
        _;
    }

    /// @notice Get the name of the module
    function name() external pure returns (string memory) {
        return "LockFundsAccountHook";
    }

    /// @notice Get the version of the module`1
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /// @notice Check if the module is of a given type
    /// @param typeID The type to check
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK;
    }

    /// @notice Check if the module is initialized
    function isInitialized(address) external pure returns (bool) { return true;}

    /*//////////////////////////////////////////////////////////////////////////
                                     EXTERNAL METHODS
    //////////////////////////////////////////////////////////////////////////*/
    /// @notice Initialize the module with the given data
    function onInstall(bytes calldata) external override { }

    /// @notice Uninstall the module
    /// @dev Not allowed to uninstall the module
    function onUninstall(bytes calldata) external pure override {
        revert NOT_IMPLEMENTED();
    }

    /// @notice Lock the given amount of funds for the given account
    /// @dev Only the executor can lock funds for an account which has this module installed
    /// @param account The account to lock the funds for
    /// @param asset The asset to lock the funds for
    /// @param amount The amount of funds to lock
    function lock(address account, address asset, uint256 amount) external onlyExecutor {
        lockedAmounts[account][asset] += amount;
        lockedTokens[account].push(asset);
        emit LockFunds(account, asset, amount);
    }

    /// @notice Unlock the given amount of funds for the given account
    /// @dev Only the executor can unlock funds for an account which has this module installed
    /// @param account The account to unlock the funds for
    /// @param asset The asset to unlock the funds for
    /// @param amount The amount of funds to unlock
    function unlock(address account, address asset, uint256 amount) external onlyExecutor {
        if (lockedAmounts[account][asset] < amount) revert NOT_ENOUGH_LOCKED_AMOUNT();
        lockedAmounts[account][asset] -= amount;

        // remove asset from lockedTokens if amount is 0    
        if (lockedAmounts[account][asset] == 0) {
            uint256 length = lockedTokens[account].length;
            for (uint256 i = 0; i < length;) {
                if (lockedTokens[account][i] == asset) {
                    lockedTokens[account][i] = lockedTokens[account][length - 1];
                    lockedTokens[account].pop();
                    break;
                }

                unchecked {
                    ++i;
                }
            }
        }
        emit UnlockFunds(account, asset, amount);
    }

    /// @notice Clean the locked funds for the given account
    /// @param account The account to clean the locked funds for    
    function clean(address account) external onlySuperPositionManager {
        uint256 length = lockedTokens[account].length;
        for (uint256 i = 0; i < length; ) {
            address asset = lockedTokens[account][i];
            delete lockedAmounts[account][asset];
            unchecked { ++i; }
        }
        delete lockedTokens[account];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL METHODS
    //////////////////////////////////////////////////////////////////////////*/
    /// @inheritdoc ERC7579HookBase
    function _preCheck(
        address,
        address,
        uint256,
        bytes calldata
    )
        internal
        override
        pure
        returns (bytes memory)
    {
        return bytes("");
    }

    /// @inheritdoc ERC7579HookBase
    function _postCheck(address account, bytes calldata) internal override view {
        // use storage to avoid copying the array
        address[] storage assets = lockedTokens[account]; 

        // @dev no need to check lockedAmounts here as
        //         lockedTokens is updated if lockedAmounts is 0

        for (uint256 i = 0; i < assets.length; ) {
            address asset = assets[i];
            uint256 lockedAmount = lockedAmounts[account][asset];
            uint256 currentBalance = IERC20(asset).balanceOf(account);
            if (lockedAmount > currentBalance) {
                revert USED_MORE_FUNDS_THAN_ALLOWED();
            }
            unchecked { ++i; }
        }

    }


    /*//////////////////////////////////////////////////////////////////////////
                                     PRIVATE METHODS
    //////////////////////////////////////////////////////////////////////////*/
    function _getAddress(bytes32 id_) private view returns (address) {
        return superRegistry.getAddress(id_);
    }
}
