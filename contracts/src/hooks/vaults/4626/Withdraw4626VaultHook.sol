// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";

contract Withdraw4626VaultHook is BaseHook, ISuperHook {
    uint256 public transient obtainedAmount;

    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address vault, address receiver, address owner, uint256 shares) =
            abi.decode(data, (address, address, address, uint256));

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (vault == address(0) || owner == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] =
            Execution({ target: vault, value: 0, callData: abi.encodeCall(IERC4626.redeem, (shares, receiver, owner)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        obtainedAmount = _getBalance(data);
        return _returnDefaultTransientStorage();
    }

    /// @inheritdoc ISuperHook
    function postExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        obtainedAmount = _getBalance(data) - obtainedAmount;
        return (address(0), _getBalance(data), bytes32(0), false);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        (address vault, address receiver,) = abi.decode(data, (address, address, uint256));
        address asset = IERC4626(vault).asset();
        return IERC20(asset).balanceOf(receiver);
    }
}
