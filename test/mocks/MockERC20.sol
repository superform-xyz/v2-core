// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    // when used as a yield source, the asset is the token itself
    function asset() external view returns (address) {
        return address(this);
    }

    // when used as a yield source, the share is the token itself
    function share() external view returns (address) {
        return address(this);
    }

    function claimableRedeemRequest(uint256, address) external pure returns (uint256) {
        return 0;
    }

    function previewWithdraw(uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function pyIndexStored() external pure returns (uint256) {
        return 1e18;
    }

    function doCacheIndexSameBlock() external pure returns (bool) {
        return true;
    }
    
    function pyIndexLastUpdatedBlock() external pure returns (uint256) {
        return 1e18;
    }

    function exchangeRate() external pure returns (uint256) {
        return 1e18;
    }
    
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the number of decimals for the token

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mint tokens to an address
    /// @param to_ The address to mint tokens to
    /// @param amount_ The amount of tokens to mint

    function mint(address to_, uint256 amount_) public {
        _mint(to_, amount_);
    }

    /// @notice Burn tokens from an address
    /// @param from_ The address to burn tokens from
    /// @param amount_ The amount of tokens to burn
    function burn(address from_, uint256 amount_) public {
        _burn(from_, amount_);
    }
}
