// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { IERC7540 } from "src/interfaces/vendors/vaults/7540/IERC7540.sol";

contract RequestDeposit7540VaultHook is BaseHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address vault, address receiver, uint256 amount) = abi.decode(data, (address, address, uint256));

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (vault == address(0) || receiver == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IERC7540.requestDeposit, (amount, receiver))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(bytes memory)
        external
        pure
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return _returnDefaultTransientStorage();
    }

    /// @inheritdoc ISuperHook
    function postExecute(bytes memory)
        external
        pure
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return _returnDefaultTransientStorage();
    }
}
