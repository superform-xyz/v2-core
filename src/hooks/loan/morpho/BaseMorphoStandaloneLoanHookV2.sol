// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Superform
import { BaseMorphoLoanHookV2 } from "./BaseMorphoLoanHookV2.sol";
import { ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseMorphoStandaloneLoanHookV2
/// @author Superform Labs
/// @notice Shared machinery for the standalone Morpho V2 borrower hooks (pledge / borrow /
///         release): single exact-primary resolution and single-leg settles.
/// @dev Deliberately a SEPARATE abstract inherited only by the standalone hooks: adding these
///      helpers to BaseLoanHookV2 changes the compiled bytecode of the already-deployed V2 loan
///      hooks (legacy solc codegen embeds inherited internal functions even when unreferenced),
///      which the locked-bytecode system forbids. Existing contracts never import this file, so
///      their bytecode is untouched by construction.
abstract contract BaseMorphoStandaloneLoanHookV2 is BaseMorphoLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    /// @param hookSubtype_ Hook subtype identifier
    constructor(address morpho_, bytes32 hookSubtype_) BaseMorphoLoanHookV2(morpho_, hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves the single exact primary amount shared by the standalone pledge/borrow
    ///      hooks. When usePrevHookAmount is set the calldata word is ignored and the previous
    ///      hook's output (which must be denominated in `expectedToken`) becomes the amount.
    ///      Zero and type(uint256).max are rejected on both paths — the standalone primary is
    ///      always exact, never a cap or sentinel — all before any provider call is emitted.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param expectedToken The token the primary slot is denominated in
    /// @param amountWord The calldata amount word (ignored when usePrevHookAmount is set)
    /// @param usePrevHookAmount True to source the amount from the previous hook's output
    /// @return resolved The exact amount the provider call will move
    function _resolveExactPrimary(
        address prevHook,
        address account,
        address expectedToken,
        uint256 amountWord,
        bool usePrevHookAmount
    )
        internal
        view
        returns (uint256 resolved)
    {
        resolved = usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, expectedToken) : amountWord;
        if (resolved == 0 || resolved == type(uint256).max) revert AMOUNT_NOT_VALID();
    }

    /// @dev Standalone supply-collateral (pledge) settle: collateral spent must equal
    ///      expectedPrimaryAmount. A pledge hook is terminal — it consumes the collateral asset
    ///      and produces nothing — so it publishes outAmount = 0 while keeping outToken =
    ///      collateralToken for off-chain classification, mirroring _settleRepay: publishing the
    ///      spend as an output would let a downstream usePrevHookAmount consumer mistake it for
    ///      produced tokens; zero makes any such chaining fail closed.
    function _settleSupplyCollateral(address account, bytes memory data) internal {
        uint256 collateralSpent = _balanceDecrease(preCollateralTokenBalance, getCollateralTokenBalance(account, data));
        if (collateralSpent != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, collateralSpent);

        _setOutAmount(0, account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }

    /// @dev Standalone-borrow settle: loan tokens received must equal expectedPrimaryAmount.
    ///      Publishes the measured loan-token wallet delta so downstream usePrevHookAmount
    ///      consumers receive the token actually produced.
    function _settleBorrow(address account, bytes memory data) internal {
        uint256 loanReceived = _balanceIncrease(preLoanTokenBalance, getLoanTokenBalance(account, data));
        if (loanReceived != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, loanReceived);

        _setOutAmount(loanReceived, account);
        _setOutToken(getLoanTokenAddress(data), account);
    }

    /// @dev Standalone withdraw-collateral (release) settle: collateral received must equal
    ///      expectedPrimaryAmount. Publishes the measured collateral-token wallet delta.
    function _settleWithdrawCollateral(address account, bytes memory data) internal {
        uint256 collateralReceived =
            _balanceIncrease(preCollateralTokenBalance, getCollateralTokenBalance(account, data));
        if (collateralReceived != expectedPrimaryAmount) {
            revert DELTA_MISMATCH(expectedPrimaryAmount, collateralReceived);
        }

        _setOutAmount(collateralReceived, account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }

    /// @dev Roles for single-slot produced-token layouts (standalone borrow/release): [OUT/TOKEN]
    function _oneOutTokenRole() internal pure returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }
}
