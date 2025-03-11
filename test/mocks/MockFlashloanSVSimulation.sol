// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;


import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";

interface ICancelDeposit {
    function cancelDeposit(address controller) external;
}
contract MockFlashloanSVSimulation {
    // @dev the following contract assumes it has USDC in its balance
    //    Similar to a flashloan this obtained USDC
    //    A real flashloan would not work without paying back + interest and
    //      in case of SV, requestDeposit & cancelDeposit doesn't earn any yield
    function performSuperVaultOperations(address superVault, uint256 amount) public {
        IERC7540 sv = IERC7540(superVault);
        
        address asset = IERC4626(superVault).asset();
        IERC20(asset).approve(superVault, amount);
        
        sv.requestDeposit(amount, address(this), address(this));
        
        ICancelDeposit(superVault).cancelDeposit(address(this));
    }
}


