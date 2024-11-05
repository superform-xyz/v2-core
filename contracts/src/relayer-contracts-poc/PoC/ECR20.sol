// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ECR20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Mint an initial supply of tokens for testing purposes
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}
