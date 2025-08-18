// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Malicious token that pretends to transfer but doesn't actually do it
contract MaliciousToken is ERC20 {
    mapping(address => bool) public blacklisted;

    constructor() ERC20("Malicious Token", "MTKX") {
        _mint(msg.sender, 1000 ether);
    }

    function blacklist(address account) external {
        blacklisted[account] = true;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        // If recipient is blacklisted, reduce sender's balance but don't increase recipient's
        if (blacklisted[to]) {
            _burn(_msgSender(), amount);
            return true;
        }

        // Otherwise do a normal transfer
        return super.transfer(to, amount);
    }
}
