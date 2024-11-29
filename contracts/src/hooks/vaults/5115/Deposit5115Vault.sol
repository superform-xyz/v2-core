// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

// Superform
import { IERC5115 } from "src/interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "src/utils/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";

contract Deposit5115Vault is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    /// @inheritdoc ISuperHook
    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (
            address vault,
            address receiver,
            address tokenIn,
            uint256 amount,
            uint256 minSharesOut,
            bool depositFromInternalBalance
        ) = abi.decode(data, (address, address, address, uint256, uint256, bool));

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (vault == address(0) || receiver == address(0) || tokenIn == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IERC5115.redeem, (receiver, amount, tokenIn, minSharesOut, depositFromInternalBalance))
        });
    }
}
