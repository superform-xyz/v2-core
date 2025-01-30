// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IERC7540 } from "./IERC7540.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

/// @title ISuperVault
/// @notice Interface for SuperVault contract that manages multiple yield sources
/// @author SuperForm Labs
interface ISuperVault is IERC7540 {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
    enum RequestStatus {
        PENDING,
        CANCELLED,
        CLAIMABLE
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error YIELD_SOURCE_ALREADY_EXISTS();
    error YIELD_SOURCE_NOT_FOUND();
    error INVALID_ALLOCATION();
    error INVALID_VAULT_CAP();
    error INVALID_SUPER_VAULT_CAP();
    error INVALID_MAX_ALLOCATION_RATE();
    error INVALID_VAULT_THRESHOLD();
    error INVALID_FEE();
    error INVALID_FEE_RECIPIENT();
    error INVALID_ORACLE();
    error TIMELOCK_NOT_EXPIRED();
    error INVALID_HOOK_ROOT();
    error INVALID_HOOK_PROOF();
    error UNAUTHORIZED();
    error INVALID_ASSET();
    error INVALID_STRATEGIST();
    error INVALID_KEEPER();
    error INVALID_AMOUNT();
    error INVALID_OWNER();
    error INVALID_CONTROLLER();
    error INVALID_YIELD_SOURCE();
    error REQUEST_NOT_FOUND();
    error REQUEST_ALREADY_CANCELLED();
    error REQUEST_ALREADY_CLAIMED();
    error INVALID_SIGNATURE();
    error INVALID_HOOK();
    error INVALID_TARGET();
    error EXECUTION_FAILED();
    error VAULT_CAP_EXCEEDED();
    error MAX_ALLOCATION_RATE_EXCEEDED();
    error VAULT_THRESHOLD_NOT_MET();
    error ARRAY_LENGTH_MISMATCH();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event YieldSourceAdded(address indexed source, address indexed oracle);
    event YieldSourceRemoved(address indexed source);
    event GlobalConfigUpdated(
        uint256 vaultCap, uint256 superVaultCap, uint256 maxAllocationRate, uint256 vaultThreshold
    );
    event HookRootUpdated(bytes32 newRoot);
    event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime);
    event FeeConfigUpdated(uint256 feeBps, address indexed recipient);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct YieldSource {
        address oracle; // Associated yield source oracle address
        bool isActive; // Whether the source is active
    }

    struct GlobalConfig {
        uint256 vaultCap; // Maximum assets per individual yield source
        uint256 superVaultCap; // Maximum total assets across all yield sources
        uint256 maxAllocationRate; // Maximum allocation percentage per yield source (in basis points)
        uint256 vaultThreshold; // Minimum TVL of a yield source that can be interacted with
    }

    struct FeeConfig {
        uint256 feeBps; // Fee in basis points
        address recipient; // Fee recipient address
    }

    struct DepositRequestInfo {
        address controller; // Address that can control the request
        address owner; // Address that will own the shares
        uint256 assets; // Amount of assets to deposit
        uint256 requestId; // Unique identifier for the request
        RequestStatus status; // Status of the request
    }

    struct RedeemRequestInfo {
        address controller; // Address that can control the request
        address owner; // Address that owns the shares
        uint256 shares; // Amount of shares to redeem
        uint256 requestId; // Unique identifier for the request
        RequestStatus status; // Status of the request
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the address of the underlying token used for the Vault for accounting, depositing, and
    /// withdrawing
    function asset() external view returns (address);
    function getYieldSource(address source) external view returns (YieldSource memory);
    function getGlobalConfig() external view returns (GlobalConfig memory);
    function getFeeConfig() external view returns (FeeConfig memory);
    function getHookRoot() external view returns (bytes32);
    function getProposedHookRoot() external view returns (bytes32);
    function getHookRootEffectiveTime() external view returns (uint256);
    function getYieldSourcesList() external view returns (address[] memory);
    function isHookAllowed(address hook, bytes32[] calldata proof) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function addYieldSource(address source, address oracle) external;
    function removeYieldSource(address source) external;
    function updateGlobalConfig(GlobalConfig calldata config) external;
    function proposeHookRoot(bytes32 newRoot) external;
    function executeHookRootUpdate() external;
    function updateFeeConfig(uint256 feeBps, address recipient) external;
}
