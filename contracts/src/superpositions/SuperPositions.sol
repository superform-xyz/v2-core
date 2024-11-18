// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { ISuperPositions } from "../interfaces/ISuperPositions.sol";

import "forge-std/console.sol";

contract SuperPositions is ISuperPositions, ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint8 private _decimals;
    ISuperRegistry public superRegistry;

    modifier onlyRelayerSentinel() {
        if (msg.sender != superRegistry.getAddress(superRegistry.RELAYER_SENTINEL_ID())) {
            revert NOT_RELAYER_SENTINEL();
        }
        _;
    }

    constructor(address registry_, uint8 decimals_) ERC20("SuperPosition", "SP") {
        _decimals = decimals_;
        superRegistry = ISuperRegistry(registry_);
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
    function mint(address to_, uint256 amount_) external override onlyRelayerSentinel {
        _mint(to_, amount_);
    }
}
