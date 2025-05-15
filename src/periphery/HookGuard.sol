// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// Superform
import { IHookGuard } from "./interfaces/IHookGuard.sol";
import { ISuperHookInspector } from "../core/interfaces/ISuperHookInspector.sol";

/// @title HookGuard
/// @author Superform Labs
/// @notice Abstract contract to implement a list of calldata enforcement for hooks for periphery usage
abstract contract HookGuard is IHookGuard {
    /*//////////////////////////////////////////////////////////////
                         ALLOW-LIST STORAGE
    //////////////////////////////////////////////////////////////*/
    uint40 public constant MIN_DELAY = 15 minutes;
    uint40 public constant MAX_DELAY = 2 days;

    // hook → index → Record[]
    mapping(address hook => mapping(uint8 idx => Record[])) public targetRecords;
    mapping(address hook => mapping(uint8 idx => Record[])) public argRecords;

    /*//////////////////////////////////////////////////////////////
                    VETOING AND HOOK GUARD
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHookGuard
    function vetoTarget(address strategy, address hook, uint8 idx, address target, bool vetoed) external {
        _hookGuardGuardianRoleCheck();
        Record[] storage recs = targetRecords[hook][idx];
        uint256 recLen = recs.length;
        for (uint256 i; i < recLen; i++) {
            if (recs[i].addr == target) {
                recs[i].vetoed = vetoed;
                emit TargetVetoStatusChanged(strategy, hook, idx, target, vetoed);
                return;
            }
        }
        revert TARGET_NOT_FOUND();
    }

    /// @inheritdoc IHookGuard
    function vetoArg(address strategy, address hook, uint8 idx, address arg, bool vetoed) external {
        _hookGuardGuardianRoleCheck();
        Record[] storage recs = argRecords[hook][idx];
        uint256 recLen = recs.length;
        for (uint256 i; i < recLen; i++) {
            if (recs[i].addr == arg) {
                recs[i].vetoed = vetoed;
                emit ArgVetoStatusChanged(strategy, hook, idx, arg, vetoed);
                return;
            }
        }
        revert ARG_NOT_FOUND();
    }

    /// @inheritdoc IHookGuard
    function enforceGlobalGuardedHookExecution(address hook, address[] calldata all) external view {
        _enforceGlobalGuardedHookExecution(hook, all);
    }

    /*//////////////////////////////////////////////////////////////
                    LIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal implementation of manageTarget that derived contracts can call
    /// @param strategy Strategy address requesting the change
    /// @param hook Hook contract address
    /// @param idx Index for the target in the hook
    /// @param target Target address to manage
    function _manageTarget(address strategy, address hook, uint8 idx, address target) internal {
        _hookGuardListManagerRoleCheck();

        Record[] storage recs = targetRecords[hook][idx];
        uint256 recLen = recs.length;
        // find existing
        for (uint256 i; i < recLen; i++) {
            Record storage r = recs[i];
            if (r.addr == target) {
                if (r.vetoed) revert VETOED_ENTRY();
                if (!r.live && r.eta != 0 && block.timestamp >= r.eta && block.timestamp <= r.eta + MAX_DELAY) {
                    // activate
                    r.live = true;
                    r.eta = 0;
                    emit TargetActivated(strategy, hook, idx, target);
                    return;
                }
                if (r.live) {
                    // revoke
                    r.live = false;
                    emit TargetRevoked(strategy, hook, idx, target);
                    return;
                }
                revert BAD_STATE();
            }
        }

        recs.push(Record({ addr: target, eta: uint40(block.timestamp + MIN_DELAY), live: false, vetoed: false }));
        emit TargetStaged(strategy, hook, idx, target, uint40(block.timestamp + MIN_DELAY));
    }

    /// @notice Internal implementation of manageArg that derived contracts can call
    /// @param strategy Strategy address requesting the change
    /// @param hook Hook contract address
    /// @param idx Index for the argument in the hook
    /// @param arg Argument address to manage
    function _manageArg(address strategy, address hook, uint8 idx, address arg) internal {
        _hookGuardListManagerRoleCheck();

        Record[] storage recs = argRecords[hook][idx];
        uint256 recLen = recs.length;

        for (uint256 i; i < recLen; i++) {
            Record storage r = recs[i];
            if (r.addr == arg) {
                if (r.vetoed) revert VETOED_ENTRY();
                if (!r.live && r.eta != 0 && block.timestamp >= r.eta && block.timestamp <= r.eta + MAX_DELAY) {
                    r.live = true;
                    r.eta = 0;
                    emit ArgActivated(strategy, hook, idx, arg);
                    return;
                }
                if (r.live) {
                    r.live = false;
                    emit ArgRevoked(strategy, hook, idx, arg);
                    return;
                }
                revert BAD_STATE();
            }
        }

        recs.push(Record({ addr: arg, eta: uint40(block.timestamp + MIN_DELAY), live: false, vetoed: false }));
        emit ArgStaged(strategy, hook, idx, arg, uint40(block.timestamp + MIN_DELAY));
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _hookGuardListManagerRoleCheck() internal view virtual { }
    function _hookGuardGuardianRoleCheck() internal view virtual { }

    function _enforceGlobalGuardedHookExecution(
        address hook,
        bytes memory hookCalldata,
        address beneficiary
    )
        internal
        view
    {
        if (hookCalldata.length == 0) revert NO_DATA();

        (
            address[] memory targets,
            uint256[] memory targetIndexes,
            address[] memory nonBeneficiaryArgs,
            uint256[] memory nonBeneficiaryArgIndexes,
            address[] memory beneficiaryArgs,
            uint256[] memory beneficiaryArgIndexes
        ) = IHookStaticInfo(hook).inspect(hookCalldata);
        uint256 targetLen = targets.length;
        uint256 nonBeneficiaryArgsLen = nonBeneficiaryArgs.length;
        uint256 beneficiaryArgsLen = beneficiaryArgs.length;
        if (targetLen == 0 || nonBeneficiaryArgsLen == 0 || beneficiaryArgsLen == 0) revert ZERO_LENGTH();
        if (targetLen != targetIndexes.length) revert INDEX_LENGTH_MISMATCH();
        if (nonBeneficiaryArgsLen != nonBeneficiaryArgIndexes.length) revert INDEX_LENGTH_MISMATCH();
        if (beneficiaryArgsLen != beneficiaryArgIndexes.length) revert INDEX_LENGTH_MISMATCH();

        for (uint8 i = 0; i < targetLen; i++) {
            _check(targets[i], targetRecords[hook][targetIndexes[i]]);
        }
        for (uint8 i = 0; i < nonBeneficiaryArgsLen; i++) {
            _check(nonBeneficiaryArgs[i], argRecords[hook][nonBeneficiaryArgIndexes[i]]);
        }
        for (uint8 i = 0; i < beneficiaryArgsLen; i++) {
            _check(beneficiaryArgs[i], argRecords[hook][beneficiaryArgIndexes[i]]);
        }
    }

    /// @notice Internal helper to check if an address is in the allow-list
    /// @param a Address to check
    /// @param recs Array of Records to check against
    function _check(address a, Record[] storage recs) internal view {
        uint256 recsLen = recs.length;
        for (uint256 i; i < recsLen; i++) {
            Record memory r = recs[i];
            if (r.addr == a && r.live && !r.vetoed) {
                return;
            }
        }
        revert NOT_ALLOWED();
    }
}
