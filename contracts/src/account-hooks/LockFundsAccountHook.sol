// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { ERC7579HookDestruct } from "modulekit/Modules.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { ISuperExecutor } from "../interfaces/ISuperExecutor.sol";
import { ISuperHook, ISuperHookMinimal } from "../interfaces/ISuperHook.sol";

import { console2 } from "forge-std/console2.sol";

contract LockFundsAccountHook is ERC7579HookDestruct, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address account => mapping(address asset => uint256 lockedAmount)) private lockedAmounts; 
      
    address constant ENTRYPOINT_0_7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_ENTRYPOINT();
    error NOT_AUTHORIZED();
    error NOT_INITIALIZED();
    error NOT_IMPLEMENTED();
    error ALREADY_INITIALIZED();
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
        emit UnlockFunds(account, asset, amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL METHODS
    //////////////////////////////////////////////////////////////////////////*/
    function onExecute(
        address account,
        address msgSender,
        address target,
        uint256, //value
        bytes calldata callData
    )
        internal
        view
        override
        returns (bytes memory hookData)
    { 
        console2.log("----onExecute");
        _checkSender(msgSender);
        return _preCheckSingleToken(account, target, callData);
    }

    function onExecuteBatch(
        address account,
        address msgSender,
        Execution[] calldata executions
    )
        internal
        view
        override
        returns (bytes memory hookData)
    { 
        console2.log("----onExecuteBatch");
        _checkSender(msgSender);
        return _preCheckMultipleTokens(account, executions);
    }

    function onExecuteDelegateCall(
        address account,
        address msgSender,
        address target,
        bytes calldata callData
    )
        internal
        view
        override
        returns (bytes memory hookData)
    { 
        console2.log("----onExecuteDelegateCall");
        _checkSender(msgSender);
        return _preCheckSingleToken(account, target, callData);
    }

    function onExecuteFromExecutor(
        address account,
        address msgSender,
        address target,
        uint256, //value
        bytes calldata callData
    )
        internal
        view
        override
        returns (bytes memory hookData)
    {
        console2.log("----onExecuteFromExecutor");
        _checkSender(msgSender);
        return _preCheckSingleToken(account, target, callData);
    }

    function onExecuteBatchFromExecutor(
        address account,
        address msgSender,
        Execution[] calldata executions
    )
        internal
        view
        override
        returns (bytes memory hookData)
    { 
        console2.log("----onExecuteBatchFromExecutor");
        _checkSender(msgSender);
        return _preCheckMultipleTokens(account, executions);
    }

    function onExecuteDelegateCallFromExecutor(
        address account,
        address msgSender,
        address target,
        bytes calldata callData
    )
        internal
        view
        override
        returns (bytes memory hookData)
    {
        console2.log("----onExecuteDelegateCallFromExecutor");
        _checkSender(msgSender);
        return _preCheckSingleToken(account, target, callData);
    }


    /// @dev `hookData` is the data returned from the onExecute methods
    function onPostCheck(address account, bytes calldata hookData) internal view override { 
        console2.log("----onPostCheck A");
        (address[] memory assets, uint256[] memory initialBalances) = abi.decode(hookData, (address[], uint256[]));
        console2.log("----onPostCheck B");

        for (uint256 i = 0; i < assets.length;) {
            address asset = assets[i];
            uint256 initialBalance = initialBalances[i];
            uint256 currentBalance = IERC20(asset).balanceOf(account);
            if (currentBalance < initialBalance) {
                uint256 usedAmount = initialBalance - currentBalance;
                if (lockedAmounts[account][asset] < usedAmount) revert USED_MORE_FUNDS_THAN_ALLOWED();
            }
            unchecked {
                ++i;
            }
        }

    }



    /*//////////////////////////////////////////////////////////////////////////
                                     PRIVATE METHODS
    //////////////////////////////////////////////////////////////////////////*/
    function _getAddress(bytes32 id_) private view returns (address) {
        return superRegistry.getAddress(id_);
    }

    function _checkSender(address msgSender) private pure {
        if (msgSender != ENTRYPOINT_0_7) revert NOT_ENTRYPOINT();
    }

    function _isErc20(address target) private view returns (bool) {
        (bool success, bytes memory data) = target.staticcall(abi.encodeCall(IERC20.balanceOf, (address(this))));
        return success && data.length > 0;
    }
    
    //TODO: discuss about this; I feel it's not protective enough
    function _extractTokens(address target, bytes calldata callData) internal view returns (address[] memory assets) {
        bytes4 selector = bytes4(callData[:4]);
        if (selector == IERC20.transfer.selector) {
            console2.log("----IERC20.transfer");
            assets = new address[](1);
            assets[0] = target;
            return assets;
        } 
        if (selector == IERC20.transferFrom.selector) {
            console2.log("----IERC20.transferFrom");
            assets = new address[](1);
            assets[0] = target;
            return assets;
        } 
        if (selector == ISuperExecutor.execute.selector) {
            console2.log("----ISuperExecutor.execute");

            ISuperExecutor.ExecutorEntry memory entry = abi.decode(callData, (ISuperExecutor.ExecutorEntry));
            uint256 hooksLen = entry.hooksAddresses.length;

            address[] memory tempAssets = new address[](hooksLen);
            uint256 countOfTokens;

            for (uint256 i = 0; i < hooksLen; ) {
                address _transferredToken = ISuperHookMinimal(entry.hooksAddresses[i]).transferredToken();
                if (_transferredToken != address(0)) {
                    tempAssets[countOfTokens] = _transferredToken;
                    ++countOfTokens;
                }
                unchecked { ++i; }
            }

            assets = new address[](countOfTokens);
            for (uint256 i = 0; i < countOfTokens; ) {
                assets[i] = tempAssets[i];
                unchecked { ++i; }
            }

            return assets;
        }
    }

    function _preCheckSingleToken(address account, address target, bytes calldata callData) private view returns (bytes memory) {
        address[] memory assets = _extractTokens(target, callData);
        uint256 len = assets.length;
        uint256[] memory initialBalances = new uint256[](len);

        for (uint256 i = 0; i < len;) {
            initialBalances[i] = IERC20(assets[i]).balanceOf(account);
            unchecked {
                ++i;
            }
        }
        return abi.encode(assets, initialBalances);
    }   

    function _preCheckMultipleTokens(address account, Execution[] calldata executions) private view returns (bytes memory) {
        // Temporary array to store extracted tokens for exact allocation
        address[][] memory tokenResults = new address[][](executions.length);
        uint256 totalTokens = 0;

        // First loop: Extract tokens and count total required slots
        for (uint256 i = 0; i < executions.length; ) {
            address[] memory assets = _extractTokens(executions[i].target, executions[i].callData);
            tokenResults[i] = assets;
            totalTokens += assets.length;
            unchecked { ++i; }
        }

        // Allocate final arrays with the exact required size
        address[] memory finalAssets = new address[](totalTokens);
        uint256[] memory finalInitialBalances = new uint256[](totalTokens);
        
        uint256 index = 0;

        // Second loop: Populate final arrays
        for (uint256 i = 0; i < executions.length; ) {
            address[] memory assets = tokenResults[i];
            uint256 len = assets.length;

            for (uint256 j = 0; j < len; ) {
                address asset = assets[j];
                finalAssets[index] = asset;
                finalInitialBalances[index] = IERC20(asset).balanceOf(account);
                unchecked { ++index; }
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }

        return abi.encode(finalAssets, finalInitialBalances);
    }

}
