// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract SuperVault is ERC4626 {
    address public bridge;  // Address of the SuperBridge contract

    constructor(IERC20 asset, address _bridge)
        ERC4626(asset)  // This is the underlying asset (ERC20 token) that the vault will hold
        ERC20("SuperVaultPoC", "SVPOC")  // Pass name and symbol to ERC20 constructor
    {
        bridge = _bridge;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only the SuperBridge can trigger minting");
        _;
    }

    // This function can only be called by the SuperBridge contract to mint shares
    function mintShares(address receiver, uint256 shares) public onlyBridge {
        _mint(receiver, shares);  // Mint shares to the receiver
    }
}
