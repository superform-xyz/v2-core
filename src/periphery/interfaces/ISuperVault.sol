// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

/// @title ISuperVault
/// @notice Interface for SuperVault contract that manages multiple yield sources
/// @author SuperForm Labs
interface ISuperVault {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_AMOUNT();
    error ZERO_ADDRESS();
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
    error INVALID_OWNER_OR_OPERATOR();
    error INVALID_CONTROLLER_OR_OPERATOR();
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
    error CANCELLATION_IS_PENDING();
    error INVALID_DEPOSIT_CLAIM();
    error NOT_IMPLEMENTED();
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event YieldSourceAdded(address indexed source, address indexed oracle);
    event YieldSourceRemoved(address indexed source);
    event YieldSourceProposed(address indexed source, address indexed oracle, uint256 effectiveTime);
    event YieldSourceOracleUpdated(address indexed source, address indexed oldOracle, address indexed newOracle);
    event YieldSourceReactivated(address indexed source);
    event GlobalConfigUpdated(
        uint256 vaultCap, uint256 superVaultCap, uint256 maxAllocationRate, uint256 vaultThreshold
    );
    event HookRootUpdated(bytes32 newRoot);
    event HookRootProposed(bytes32 proposedRoot, uint256 effectiveTime);
    event FeeConfigUpdated(uint256 feeBps, address indexed recipient);
    /// @notice Event emitted when a deposit request is fulfilled
    event DepositFulfilled(address indexed controller, address indexed owner, uint256 shares);
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ProposedYieldSource {
        address source; // Address of the yield source
        address oracle; // Address of the oracle
        uint256 effectiveTime; // Timestamp when proposal can be executed
        bool isPending; // Whether proposal is pending
    }

    struct FulfillmentVars {
        uint256 totalRequestedAssets;
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 pricePerShare;
        uint256 vaultDecimals;
        address prevHook;
        uint256 spentAssets;
    }

    struct SharePricePoint {
        /// @notice Number of shares at this price point
        uint256 shares;
        /// @notice Price per share in asset decimals when these shares were minted
        uint256 pricePerShare;
    }

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

    struct SuperVaultState {
        /// @dev Shares that can be claimed using `mint()`
        uint256 maxMint;
        /// @dev Assets that can be claimed using `withdraw()`
        uint256 maxWithdraw;
        /// @dev Remaining deposit request in assets
        uint256 pendingDepositRequest;
        /// @dev Remaining redeem request in shares
        uint256 pendingRedeemRequest;
        /// @dev Assets that can be claimed using `claimCancelDepositRequest()`
        uint256 claimableCancelDepositRequest;
        /// @dev Shares that can be claimed using `claimCancelRedeemRequest()`
        uint256 claimableCancelRedeemRequest;
        /// @dev Indicates whether the depositRequest was requested to be cancelled
        bool pendingCancelDepositRequest;
        /// @dev Indicates whether the redeemRequest was requested to be cancelled
        bool pendingCancelRedeemRequest;
        /// @dev FIFO queue of share price points for tracking entry prices
        SharePricePoint[] sharePricePoints;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
    /// @notice Propose a new yield source with timelock
    /// @param source Address of the yield source
    /// @param oracle Address of the yield source oracle
    function proposeYieldSource(address source, address oracle) external;

    /// @notice Execute a proposed yield source addition after timelock
    /// @param source Address of the yield source to execute proposal for
    function executeYieldSourceProposal(address source) external;

    /// @notice Update oracle for an existing yield source
    /// @param source Address of the yield source
    /// @param newOracle Address of the new oracle
    function updateYieldSourceOracle(address source, address newOracle) external;

    /// @notice Remove a yield source
    /// @param source Address of the yield source to remove
    function removeYieldSource(address source) external;

    /// @notice Reactivate a previously removed yield source
    /// @param source Address of the yield source to reactivate
    function reactivateYieldSource(address source) external;

    /// @notice Update global configuration
    /// @param config New global configuration
    function updateGlobalConfig(GlobalConfig calldata config) external;

    /// @notice Propose a new hook root
    /// @param newRoot New hook root to propose
    function proposeHookRoot(bytes32 newRoot) external;

    /// @notice Execute hook root update after timelock
    function executeHookRootUpdate() external;

    /// @notice Update fee configuration
    /// @param feeBps New fee in basis points
    /// @param recipient New fee recipient address
    function updateFeeConfig(uint256 feeBps, address recipient) external;
}
