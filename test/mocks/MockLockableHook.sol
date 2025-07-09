// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISuperHook, ISuperLockableHook, ISuperHookResult } from "../../src/interfaces/ISuperHook.sol";

/**
 * @title MockLockableHook
 * @notice Mock implementation of a hook that implements ISuperLockableHook for testing
 * @author Superform Labs
 */
contract MockLockableHook {
    ISuperHook.HookType private _hookType;
    address private _token;
    address private _vaultBank;
    uint256 private _dstChainId;
    bytes32 private _yieldSourceOracleId;
    mapping(address => uint256) private _outAmounts;

    /**
     * @notice Constructor for the mock lockable hook
     * @param hookType_ The type of the hook
     * @param token_ The token address
     * @param vaultBank_ The vault bank address
     * @param dstChainId_ The destination chain ID
     * @param yieldSourceOracleId_ The yield source oracle ID
     */
    constructor(
        ISuperHook.HookType hookType_,
        address token_,
        address vaultBank_,
        uint256 dstChainId_,
        bytes32 yieldSourceOracleId_
    ) {
        _hookType = hookType_;
        _token = token_;
        _vaultBank = vaultBank_;
        _dstChainId = dstChainId_;
        _yieldSourceOracleId = yieldSourceOracleId_;
    }

    /**
     * @notice Sets the output amount for a specific account
     * @param amount_ The amount to set
     * @param account_ The account to set the amount for
     */
    function setOutAmount(uint256 amount_, address account_) external {
        _outAmounts[account_] = amount_;
    }

    /**
     * @notice Gets the output amount for a specific account
     * @param account_ The account to get the amount for
     * @return The output amount for the account
     */
    function getOutAmount(address account_) external view returns (uint256) {
        return _outAmounts[account_];
    }

    /**
     * @notice Returns the vault bank address
     * @return The vault bank address
     */
    function vaultBank() external view returns (address) {
        return _vaultBank;
    }

    /**
     * @notice Returns the destination chain ID
     * @return The destination chain ID
     */
    function dstChainId() external view returns (uint256) {
        return _dstChainId;
    }

    /**
     * @notice Returns the hook type
     * @return The hook type
     */
    function hookType() external view returns (ISuperHook.HookType) {
        return _hookType;
    }
}
