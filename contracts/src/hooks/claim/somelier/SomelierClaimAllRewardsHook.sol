// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { ISomelierCellarStaking } from "../../../interfaces/vendors/somelier/ISomelierCellarStaking.sol";

//TODO: We might need to add a non-transient option
//      The following hook claims an array of rewards tokens
//      How we store those to be used in the `postExecute` is the question?
contract SomelierClaimAllRewardsHook is BaseHook, BaseClaimRewardHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address vault) = abi.decode(data, (address));
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        return _build(vault, abi.encodeCall(ISomelierCellarStaking.claimAll, ()));
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
