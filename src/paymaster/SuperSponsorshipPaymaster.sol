// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@ERC4337/account-abstraction/contracts/interfaces/IPaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { BasePaymaster } from "../vendor/account-abstraction/BasePaymaster.sol";
import { ISuperSponsorshipPaymaster } from "../interfaces/ISuperSponsorshipPaymaster.sol";

/// @title SuperSponsorshipPaymaster
/// @author Superform Labs
/// @notice Paymaster with per-strategy gas sponsorship budgets.
///         Treasury funds the paymaster per chain, managers credit strategy buckets,
///         and gas costs are debited from the relevant strategy's budget.
///
/// @dev Accounting model (pre-charge / refund):
///      - `_validatePaymasterUserOp` reserves `maxCost` from the strategy balance upfront,
///        preventing over-commitment when multiple UserOps target the same strategy in a bundle.
///      - `_postOp` computes the actual cost (including `postOpGasOverhead`), caps it to
///        `maxCost`, and refunds the unused portion back to the strategy balance.
///      - `_postOp` is guaranteed to never revert (the cap ensures no underflow), which is
///        critical because in ERC-4337 v0.7 a postOp revert still charges the paymaster
///        deposit without updating internal accounting.
contract SuperSponsorshipPaymaster is BasePaymaster, AccessControl, ISuperSponsorshipPaymaster {
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant FUNDING_ROLE = keccak256("FUNDING_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Offset into paymasterAndData where the strategy address begins.
    ///         Layout: [0:20] paymaster, [20:36] verificationGasLimit, [36:52] postOpGasLimit, [52:72] strategy
    uint256 internal constant STRATEGY_DATA_OFFSET = 52;

    /// @notice Minimum gas overhead to compensate for postOp gas not included in actualGasCost.
    ///         The ERC-4337 EntryPoint charges the paymaster for postOp execution gas, but the
    ///         `actualGasCost` parameter passed to `_postOp` excludes it. Without this minimum,
    ///         every UserOp would under-debit by ~40-60k gas units, causing `totalAllocated` to
    ///         drift above the real EntryPoint deposit over time.
    uint256 public constant MIN_POST_OP_OVERHEAD = 40_000;

    /// @notice Maximum allowed gas overhead to prevent a compromised admin from setting an
    ///         astronomically high value that would cause every _postOp to cap at maxCost.
    uint256 public constant MAX_POST_OP_GAS_OVERHEAD = 500_000;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    mapping(address strategy => StrategyBudget) internal _budgets;

    /// @notice Sum of all strategy balances
    uint256 public totalAllocated;

    /// @notice Gas units added to actualGasCost in postOp to account for postOp execution cost.
    /// @dev The ERC-4337 v0.7 EntryPoint charges the full gas cost (including postOp execution)
    ///      from the paymaster deposit, but the `actualGasCost` parameter passed to `_postOp`
    ///      does NOT include the gas consumed by postOp itself (see BasePaymaster.sol:94:
    ///      "actualGasCost - Actual gas used so far (without this postOp call)").
    ///      This overhead parameter compensates for that gap. Additionally, ERC-4337 v0.7 imposes
    ///      a 10% penalty on unused gas (when unused >= 40,000 units) that is also not included
    ///      in actualGasCost. Setting this value appropriately minimizes accounting drift.
    uint256 public postOpGasOverhead;

    /// @notice Global pause flag
    bool public globalPaused;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IEntryPoint entryPoint_, address admin_) payable BasePaymaster(entryPoint_) {
        if (admin_ == address(0)) revert ZERO_ADDRESS();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(FUNDING_ROLE, admin_);
        _grantRole(MANAGER_ROLE, admin_);

        postOpGasOverhead = MIN_POST_OP_OVERHEAD;
    }

    /*//////////////////////////////////////////////////////////////
                        FUNDING (FUNDING_ROLE)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperSponsorshipPaymaster
    function fundStrategy(address strategy) external payable onlyRole(FUNDING_ROLE) {
        if (strategy == address(0)) revert ZERO_ADDRESS();
        if (msg.value == 0) revert ZERO_AMOUNT();

        _budgets[strategy].balance += msg.value;
        totalAllocated += msg.value;

        // Deposit to EntryPoint so the paymaster has sufficient deposit for UserOps
        entryPoint.depositTo{ value: msg.value }(address(this));

        emit StrategyFunded(strategy, msg.value);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function creditStrategy(address strategy, uint256 amount) external onlyRole(FUNDING_ROLE) {
        if (strategy == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
        if (amount > unallocatedBalance()) revert INSUFFICIENT_UNALLOCATED_BALANCE();

        _budgets[strategy].balance += amount;
        totalAllocated += amount;

        emit StrategyCredited(strategy, amount);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function withdrawStrategyFunds(address strategy, address to, uint256 amount) external onlyRole(FUNDING_ROLE) {
        if (to == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
        if (amount > _budgets[strategy].balance) revert WITHDRAW_EXCEEDS_BALANCE();
        if (amount > entryPoint.balanceOf(address(this))) revert INSUFFICIENT_ENTRYPOINT_DEPOSIT();

        _budgets[strategy].balance -= amount;
        totalAllocated -= amount;

        entryPoint.withdrawTo(payable(to), amount);

        emit StrategyWithdrawn(strategy, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT (MANAGER_ROLE)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperSponsorshipPaymaster
    function setMaxSingleOpCost(address strategy, uint256 maxCost) external onlyRole(MANAGER_ROLE) {
        if (strategy == address(0)) revert ZERO_ADDRESS();
        _budgets[strategy].maxSingleOpCost = maxCost;
        emit MaxSingleOpCostSet(strategy, maxCost);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function pauseStrategy(address strategy) external onlyRole(MANAGER_ROLE) {
        if (strategy == address(0)) revert ZERO_ADDRESS();
        _budgets[strategy].paused = true;
        emit StrategyPaused(strategy);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function unpauseStrategy(address strategy) external onlyRole(MANAGER_ROLE) {
        if (strategy == address(0)) revert ZERO_ADDRESS();
        _budgets[strategy].paused = false;
        emit StrategyUnpaused(strategy);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN (DEFAULT_ADMIN_ROLE)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperSponsorshipPaymaster
    function setPostOpGasOverhead(uint256 overhead) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (overhead < MIN_POST_OP_OVERHEAD) revert POST_OP_OVERHEAD_BELOW_MINIMUM();
        if (overhead > MAX_POST_OP_GAS_OVERHEAD) revert EXCEEDS_MAX_POST_OP_OVERHEAD();
        postOpGasOverhead = overhead;
        emit PostOpGasOverheadSet(overhead);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function setGlobalPause(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        globalPaused = paused;
        emit GlobalPauseSet(paused);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function sweepETH(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ZERO_ADDRESS();
        uint256 bal = address(this).balance;
        if (bal == 0) return;
        (bool success,) = to.call{ value: bal }("");
        if (!success) revert ETH_TRANSFER_FAILED();
        emit ETHSwept(to, bal);
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    /// @dev Under normal operation, the EntryPoint deposit can drift below `totalAllocated` due to
    ///      three compounding factors in ERC-4337 v0.7:
    ///
    ///      1. **postOp gas exclusion**: The `actualGasCost` passed to `_postOp` by the EntryPoint
    ///         does NOT include the gas consumed by `_postOp` itself. The EntryPoint charges the
    ///         full cost (including postOp execution) from the paymaster deposit, but our internal
    ///         accounting only sees `actualGasCost`. The `postOpGasOverhead` parameter mitigates
    ///         this, but may not perfectly match actual postOp gas usage across different chains
    ///         and EVM upgrades.
    ///
    ///      2. **Unused gas penalty**: ERC-4337 v0.7 imposes a 10% penalty on unused gas (when
    ///         unused gas >= 40,000 units). This penalty is charged from the paymaster deposit but
    ///         is NOT included in `actualGasCost`, creating invisible drift per UserOp.
    ///
    ///      3. **totalCost capping**: When `_postOp` caps `totalCost` to `maxCost` (to prevent
    ///         postOp reverts that would cause untracked deposit drain), the actual EntryPoint
    ///         charge may exceed what we debit internally.
    ///
    ///      Over many UserOps, these factors cause `totalAllocated` to exceed the real EntryPoint
    ///      deposit. This function allows an admin to correct the drift by snapping `totalAllocated`
    ///      down to the actual deposit value.
    ///
    ///      **Note**: This only adjusts the aggregate `totalAllocated` counter. Individual strategy
    ///      balances are NOT modified. After reconciliation, the sum of all strategy balances may
    ///      exceed `totalAllocated`. Admins should adjust individual strategy budgets separately
    ///      if precise per-strategy accounting is needed.
    function reconcile() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 deposit = entryPoint.balanceOf(address(this));
        if (totalAllocated > deposit) {
            uint256 drift = totalAllocated - deposit;
            totalAllocated = deposit;
            emit Reconciled(drift);
        }
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    /// @dev Bypasses per-strategy accounting. Use when `withdrawStrategyFunds` fails because the
    ///      real EntryPoint deposit is below the internal `totalAllocated` due to accounting drift.
    ///      Reduces `totalAllocated` by the withdrawn amount (capped at current value to prevent
    ///      underflow). Does NOT adjust individual strategy balances — call `reconcile()` or adjust
    ///      budgets manually after using this function.
    function emergencyWithdrawFromEntryPoint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();

        if (amount >= totalAllocated) {
            totalAllocated = 0;
        } else {
            totalAllocated -= amount;
        }

        entryPoint.withdrawTo(payable(to), amount);
        emit EmergencyWithdrawn(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperSponsorshipPaymaster
    function getStrategyBudget(address strategy) external view returns (StrategyBudget memory) {
        return _budgets[strategy];
    }

    /// @inheritdoc ISuperSponsorshipPaymaster
    function unallocatedBalance() public view returns (uint256) {
        uint256 deposit = entryPoint.balanceOf(address(this));
        if (deposit <= totalAllocated) return 0;
        return deposit - totalAllocated;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev Validates the UserOp against the strategy's sponsorship budget and pre-charges maxCost.
    ///      Strategy address is encoded in paymasterAndData[52:72].
    ///
    ///      Pre-charge model: The full `maxCost` is reserved (debited) from the strategy balance
    ///      during validation. This prevents over-commitment when the EntryPoint validates multiple
    ///      UserOps targeting the same strategy within a single bundle (all validations run before
    ///      any execution). The excess is refunded in `_postOp` after the actual cost is known.
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32,
        uint256 maxCost
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        if (globalPaused) revert GLOBAL_PAUSED();

        address strategy =
            address(bytes20(userOp.paymasterAndData[STRATEGY_DATA_OFFSET:STRATEGY_DATA_OFFSET + 20]));

        StrategyBudget storage budget = _budgets[strategy];

        if (budget.paused) revert STRATEGY_PAUSED();
        if (budget.maxSingleOpCost != 0 && maxCost > budget.maxSingleOpCost) revert EXCEEDS_SINGLE_OP_CAP();
        if (budget.balance < maxCost) revert INSUFFICIENT_STRATEGY_BUDGET();

        // Pre-charge: reserve maxCost to prevent over-commitment in bundled UserOps.
        // The excess will be refunded in _postOp after actual gas cost is known.
        budget.balance -= maxCost;
        totalAllocated -= maxCost;

        return (abi.encode(strategy, maxCost), 0);
    }

    /// @dev Debits the actual gas cost from the strategy's budget and refunds the excess.
    ///
    ///      The actual cost includes `postOpGasOverhead` to compensate for gas consumed by this
    ///      postOp call that the EntryPoint does not include in `actualGasCost`.
    ///
    ///      CRITICAL: `totalCost` is capped to `maxCost` to guarantee this function never reverts.
    ///      In ERC-4337 v0.7, if postOp reverts, the EntryPoint still charges the paymaster deposit
    ///      but does NOT retry postOp (the `postOpReverted` mode is never used — see
    ///      BasePaymaster.sol:92). This would cause untracked deposit drain where the EntryPoint
    ///      deposit decreases but internal accounting (`totalAllocated`, strategy balances) is
    ///      never updated. The cap prevents this scenario entirely.
    function _postOp(
        PostOpMode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    )
        internal
        virtual
        override
    {
        (address strategy, uint256 maxCost) = abi.decode(context, (address, uint256));

        uint256 totalCost = actualGasCost + (postOpGasOverhead * actualUserOpFeePerGas);

        // Cap totalCost to maxCost to prevent underflow. _postOp must never revert.
        if (totalCost > maxCost) {
            totalCost = maxCost;
        }

        StrategyBudget storage budget = _budgets[strategy];

        // Refund unused portion back to strategy balance
        uint256 refund = maxCost - totalCost;
        budget.balance += refund;
        budget.totalDebited += totalCost;
        totalAllocated += refund;

        emit StrategyDebited(strategy, totalCost);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-165 SUPPORT
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the diamond inheritance between AccessControl (which provides supportsInterface)
    ///      and IPaymaster (which extends IERC165 via BasePaymaster). Without this override,
    ///      `type(IPaymaster).interfaceId` would not be reported.
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return interfaceId == type(IPaymaster).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @dev Accept ETH directly. This ETH sits on the contract, NOT in the EntryPoint deposit,
    ///      and therefore cannot be used for gas sponsorship. To make it usable:
    ///      - Admin calls `sweepETH` to send it to a recipient, OR
    ///      - A FUNDING_ROLE holder calls `fundStrategy` to deposit it into a strategy budget
    ///        (requires the ETH to be at the sender's address, not on this contract).
    ///      ETH received here does NOT appear in `unallocatedBalance()` (which only tracks
    ///      the EntryPoint deposit).
    receive() external payable { }
}
