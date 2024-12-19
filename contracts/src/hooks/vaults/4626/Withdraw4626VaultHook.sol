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
    // forgefmt: disable-start
    uint256 public transient shareDifference;
    // forgefmt: disable-end

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
        shareDifference = _getShareBalance(data);
        return _returnDefaultTransientStorage();
    }

    /// @inheritdoc ISuperHook
    function postExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        shareDifference = shareDifference - _getShareBalance(data);
        return (address(0), shareDifference, bytes32(keccak256("WITHDRAW")), false);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getShareBalance(bytes memory data) private view returns (uint256) {
        (address vault, address receiver,) = abi.decode(data, (address, address, uint256));
        return IERC4626(vault).balanceOf(receiver);
    }
}
