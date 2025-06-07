// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract VaultBankSuperPosition is ERC20, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint8 private _decimals;

    /// @dev `msg.sender` is VaultBank
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the number of decimals for the token
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mint tokens to the specified address
    /// @param to_ The address to mint tokens to
    /// @param amount_ The amount of tokens to mint
    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    /// @notice Burn tokens from the specified address
    /// @param from_ The address to burn tokens from
    /// @param amount_ The amount of tokens to burn
    function burn(address from_, uint256 amount_) external onlyOwner {
        _burn(from_, amount_);
    }
}
