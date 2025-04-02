// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { ISuperHook } from "../../interfaces/ISuperHook.sol";
import { ISuperHookResult } from "../../interfaces/ISuperHook.sol";
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
    IMorphoBase public morphoInterface;

    uint256 private constant AMOUNT_POSITION = 80;

    struct BuildHookLocalVars {
      address loanToken;
      address collateralToken;
      address oracle;
      address irm;
      uint256 amount;
      uint256 lltv;
      bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address morpho_) BaseHook(registry_, HookType.NONACCOUNTING) {
        if (morpho_ == address(0)) revert ZERO_ADDRESS();
        morpho = morpho_;
        morphoInterface = IMorphoBase(morpho_);
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
        BuildHookLocalVars memory vars = _decodeHookData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).outAmount();
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();
        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        MarketParams memory marketParams = _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        uint256 collateralAmount = _deriveCollateralAmount(vars.amount);

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] =
            Execution({ target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount)) });
        executions[2] =
            Execution({ target: morpho , value: 0, callData: abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, collateralAmount, account, "")) });
        executions[3] =
            Execution({ target: morpho, value: 0, callData: abi.encodeCall(IMorphoBase.borrow, (marketParams, vars.amount, 0, account, account)) });    
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHook
    function preExecute(address, address account, bytes memory data) external {
        // store current balance
        outAmount = _getBalance(account, data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address account, bytes memory data) external {
        outAmount = _getBalance(account, data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _decodeHookData(bytes memory data) internal pure returns (BuildHookLocalVars memory vars) {
        address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
        address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
        uint256 amount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
        bool usePrevHookAmount = _decodeBool(BytesLib.slice(data, 144, 1), 0);
        vars = BuildHookLocalVars({ 
            loanToken: loanToken, 
            collateralToken: collateralToken, 
            oracle: oracle, 
            irm: irm, 
            amount: amount, 
            lltv: lltv, 
            usePrevHookAmount: usePrevHookAmount 
        });
    }

    function _deriveCollateralAmount(uint256 amount) internal view returns (uint256) {
        // TODO: Implement this
        //return amount * marketParams.lltv / 10000;
    }

    function _generateMarketParams(address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }
    
    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(BytesLib.slice(data, AMOUNT_POSITION, 32), 0);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        return IERC20(collateralToken).balanceOf(account);
    }
}
