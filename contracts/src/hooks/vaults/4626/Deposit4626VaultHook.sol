// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";

contract Deposit4626VaultHook is BaseHook, ISuperHook {
    // forgefmt: disable-start
    uint256 public transient obtainedShares;
    // forgefmt: disable-end

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
        executions[0] =
            Execution({ target: vault, value: 0, callData: abi.encodeCall(IERC4626.deposit, (amount, receiver)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {   
        // store current balance
        obtainedShares = _getBalance(data);
        return _returnDefaultTransientStorage();
    }

    /// @inheritdoc ISuperHook
    function postExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        obtainedShares = _getBalance(data) - obtainedShares;
        return (address(0), obtainedShares, bytes32(keccak256("DEPOSIT")), true);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        (address vault, address receiver,) = abi.decode(data, (address, address, uint256));
        return IERC4626(vault).balanceOf(receiver);
    }
}
