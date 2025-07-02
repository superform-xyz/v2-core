// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVaultBank } from "../../src/periphery/interfaces/VaultBank/IVaultBank.sol";
import { MockERC20 } from "./MockERC20.sol";

/**
 * @title MockVaultBank
 * @notice Mock implementation of VaultBank for testing
 * @author Superform Labs
 */
contract MockVaultBank {
    struct LockInfo {
        bytes32 yieldSourceOracleId;
        address account;
        address spToken;
        address hook;
        uint256 amount;
        uint64 dstChainId;
    }

    uint256 public lockCount;
    mapping(uint256 => LockInfo) public locks;
    
    // Cross-chain nonce tracking
    mapping(uint64 => uint256) public chainNonces;
    
    // Mock SuperPositions token
    MockERC20 public superPositions;
    
    event AssetLocked(
        bytes32 indexed yieldSourceOracleId,
        address indexed account,
        address indexed spToken,
        address hook,
        uint256 amount,
        uint64 dstChainId,
        uint256 nonce
    );
    
    constructor(string memory name, string memory symbol, uint8 decimals) {
        superPositions = new MockERC20(name, symbol, decimals);
    }
    
    /**
     * @notice Mock implementation of lockAsset
     * @param yieldSourceOracleId_ The yield source oracle ID
     * @param account_ The account to lock assets for
     * @param spToken_ The token to lock
     * @param hook_ The hook that initiated the lock
     * @param amount_ The amount to lock
     * @param dstChainId_ The destination chain ID
     * @return The cross-chain nonce
     */
    function lockAsset(
        bytes32 yieldSourceOracleId_,
        address account_,
        address spToken_,
        address hook_,
        uint256 amount_,
        uint64 dstChainId_
    ) external returns (uint256) {
        // Transfer tokens from caller to VaultBank
        require(IERC20(spToken_).transferFrom(msg.sender, address(this), amount_), "Token transfer failed");
        
        // Record lock information
        locks[lockCount] = LockInfo({
            yieldSourceOracleId: yieldSourceOracleId_,
            account: account_,
            spToken: spToken_,
            hook: hook_,
            amount: amount_,
            dstChainId: dstChainId_
        });
        
        // Increase nonce for destination chain
        uint256 nonce = chainNonces[dstChainId_];
        chainNonces[dstChainId_] = nonce + 1;
        
        // Mint SuperPositions to the user
        superPositions.mint(account_, amount_);
        
        // Emit event
        emit AssetLocked(
            yieldSourceOracleId_,
            account_,
            spToken_,
            hook_,
            amount_,
            dstChainId_,
            nonce
        );
        
        lockCount++;
        return nonce;
    }
}
