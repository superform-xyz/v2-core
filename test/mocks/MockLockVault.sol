// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLockVault  {
    function lock(address account, address token, uint256 amount) external {
        ERC20(token).transferFrom(account, address(this), amount);
    }

    function unlock(address account, address token, uint256 amount) external {
        ERC20(token).transfer(account, amount);
    }
}
