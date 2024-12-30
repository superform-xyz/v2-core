// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC5115 } from "src/interfaces/vendors/vaults/5115/IERC5115.sol";

// Superform
import { BaseHook } from "src/hooks/BaseHook.sol";

import { ISuperHook } from "src/interfaces/ISuperHook.sol";

contract Withdraw5115VaultHook is BaseHook, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public transient outAmount;

    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        (
            address vault,
            address receiver,
            address tokenOut,
            uint256 shares,
            uint256 minTokenOut,
            bool burnFromInternalBalance
        ) = abi.decode(data, (address, address, address, uint256, uint256, bool));

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (vault == address(0) || tokenOut == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IERC5115.redeem, (receiver, shares, tokenOut, minTokenOut, burnFromInternalBalance))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data)
        external
        view
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return (address(0), _getBalance(data), bytes32(0), false);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data)
        external
        view
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        return (address(0), _getBalance(data), bytes32(0), false);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        (address vault, address receiver,) = abi.decode(data, (address, address, uint256));
        address asset = IERC5115(vault).asset();
        return IERC20(asset).balanceOf(receiver);
    }
}
