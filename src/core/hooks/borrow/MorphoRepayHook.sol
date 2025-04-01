// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMorpho, MarketParams } from "../../../vendor/morpho/IMorpho.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { ISuperHook } from "../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";

/// @title MorphoRepayHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 112);
contract MorphoRepayHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorpho public morphoInterface;
    MarketParams public marketParams;

    uint256 private constant ASSETS_POSITION = 80;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address morpho_) BaseHook(registry_, HookType.NONACCOUNTING) {
        if (morpho_ == address(0)) revert ZERO_ADDRESS();
        morpho = morpho_;
        morphoInterface = IMorpho(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
}