// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperPositions } from "../interfaces/accounting/ISuperPositions.sol";
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract SuperPositionsMock is ISuperPositions, ERC20, SuperRegistryImplementer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint8 private _decimals;

    constructor(address registry_, uint8 decimals_) ERC20("SuperPosition", "SP") SuperRegistryImplementer(registry_) {
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

    /// @inheritdoc ISuperPositions
    function mint(address to_, uint256 amount_) external override {
        _mint(to_, amount_);
    }
}
