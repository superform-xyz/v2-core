// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenWithTransferControl
 * @notice Mock token that allows controlling the exact amount that gets transferred
 * @dev Used for testing fee tolerance in SuperExecutor
 */
import "forge-std/console2.sol";

contract TokenWithTransferControl is ERC20 {
    bool public useCustomTransferAmount;
    uint256 public customTransferAmount;
    address public feeRecipient;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals_);
    }

    /**
     * @notice Enables/disables the custom transfer amount override
     * @param enable Set to true to use customTransferAmount during transfers
     */
    function setTransferOverride(bool enable) external {
        useCustomTransferAmount = enable;
    }

    /**
     * @notice Sets the exact amount that will be transferred
     * @param amount The amount that will be credited to recipient regardless of transfer amount
     */
    function setCustomTransferAmount(uint256 amount) external {
        customTransferAmount = amount;
    }

    /**
     * @notice Sets the fee recipient address for custom transfer behavior
     * @param recipient The address to apply custom transfer behavior to
     */
    function setFeeRecipient(address recipient) external {
        feeRecipient = recipient;
    }

    /**
     * @notice Mint tokens to an address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Override transfer function to apply custom transfer amounts
     * @param to Recipient of the transfer
     * @param amount Amount to transfer (or attempt to transfer)
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        console2.log("Transfer called with:");
        console2.log(" - To B:", to);
        console2.log(" - To A:", feeRecipient);
        console2.log(" - Amount:", amount);
        console2.log(" - useCustomTransferAmount:", useCustomTransferAmount);
        if (useCustomTransferAmount && to == feeRecipient) {
            // Burn the full amount from sender
            _burn(_msgSender(), amount);

            // Mint the custom amount to recipient
            _mint(to, customTransferAmount);

            return true;
        }

        // Regular transfer behavior
        return super.transfer(to, amount);
    }

    /**
     * @notice Override transferFrom to apply custom transfer amounts
     * @param from Address to transfer from
     * @param to Recipient of the transfer
     * @param amount Amount to transfer (or attempt to transfer)
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (useCustomTransferAmount && to == feeRecipient) {
            // Use up allowance
            _spendAllowance(from, _msgSender(), amount);

            // Burn the full amount from sender
            _burn(from, amount);

            // Mint the custom amount to recipient
            _mint(to, customTransferAmount);

            return true;
        }

        // Regular transferFrom behavior
        return super.transferFrom(from, to, amount);
    }
}
