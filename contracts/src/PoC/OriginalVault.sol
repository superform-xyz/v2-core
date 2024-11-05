// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "./SuperBridge.sol";

contract OriginalVault is ERC4626 {
    SuperBridge public bridge;
    uint256 superformChainId;
    address supervaultAddr;

    constructor(
        IERC20 asset, // This is the underlying asset (ERC20 token) that the vault will hold
        address _bridge,
        uint256 _superformChainId,
        address _supervaultAddr
    )
        ERC4626(asset) // This is the underlying asset (ERC20 token) that the vault will hold
        ERC20("SuperVaultPoC", "SVPOC") // Pass name and symbol to ERC20 constructor
    {
        bridge = SuperBridge(_bridge);
        superformChainId = _superformChainId;
        supervaultAddr = _supervaultAddr;
    }

    // Override deposit function to send cross-chain message using SuperBridge
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        uint256 shares = super.deposit(assets, address(this));

        // Prepare calldata for the destination vault's mintShares function
        bytes memory data = abi.encodeWithSignature("mintShares(address,uint256)", receiver, shares);

        // Send message through SuperBridge to destination chain vault
        bridge.send(superformChainId, supervaultAddr, data);

        return shares;
    }
}
