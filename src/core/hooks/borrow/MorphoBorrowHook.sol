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

/// @title MorphoBorrowHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// TODO: Does user specify oracle or we always use the same one?
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
contract MorphoBorrowHook is BaseHook, ISuperHook {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorpho public morphoInterface;
    MarketParams public marketParams;

    uint256 private constant AMOUNT_POSITION = 80;

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

    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        uint256 amount = _decodeAmount(data);
        uint256 lltv = _decodeLltv(data);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (loanToken == address(0) || collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });

        uint256 collateralAmount = _deriveCollateralAmount(amount);

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] =
            Execution({ target: collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, amount)) });
        executions[2] =
            Execution({ target: morpho_ , value: 0, callData: abi.encodeCall(IMorpho.supplyCollateral, (loanToken, collateralToken, oracle, irm, lltv), collateralAmount, account, "") });
        executions[3] =
            Execution({ target: loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, amount)) });
            
            
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _deriveCollateralAmount(uint256 amount) internal view returns (uint256) {
        // TODO: Implement this
        //return amount * marketParams.lltv / 10000;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(collateralToken).balanceOf(account);
    }
}
