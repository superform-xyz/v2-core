// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title Up
 * @author Superform Foundation
 */
contract Up is ERC20, ERC20Permit, Ownable2Step {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant MINT_CAP_BPS = 200; // 2%
    uint256 public constant DAYS_PER_YEAR = 365 days;
    uint256 public constant INITIAL_MINT_LOCK = 3 * 365 days; // 3 years

    uint256 public lastMintTimestamp;
    uint256 public immutable initialMintTimestamp;

    event TokensMinted(address indexed to, uint256 amount);

    error MintingTooEarly();
    error MintAmountTooHigh();
    error InitialLockPeriodNotOver();

    constructor(address initialOwner) ERC20("Superform", "UP") ERC20Permit("Superform") Ownable(initialOwner) {
        _mint(initialOwner, INITIAL_SUPPLY);
        lastMintTimestamp = block.timestamp;
        initialMintTimestamp = block.timestamp;
    }

    /**
     * @dev Allows owner to mint new tokens once per year after 3 years, up to 2% of total supply
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        // Check if 3 years have passed since initial mint
        if (block.timestamp < initialMintTimestamp + INITIAL_MINT_LOCK) {
            revert InitialLockPeriodNotOver();
        }

        // Check if enough time has passed since last mint
        if (block.timestamp < lastMintTimestamp + DAYS_PER_YEAR) {
            revert MintingTooEarly();
        }

        // Calculate maximum mint amount (2% of total supply)
        uint256 maxMintAmount = (totalSupply() * MINT_CAP_BPS) / 10_000;
        if (amount > maxMintAmount) {
            revert MintAmountTooHigh();
        }

        lastMintTimestamp = block.timestamp;
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}
