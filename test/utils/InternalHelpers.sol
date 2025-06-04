// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {UserOpData} from "modulekit/ModuleKit.sol";
import "../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import {SpectraCommands} from "../../src/vendor/spectra/SpectraCommands.sol";
import {console2} from "forge-std/console2.sol";
import {ISuperExecutor} from "../../src/core/interfaces/ISuperExecutor.sol";
import {UserOpData, AccountInstance, ModuleKitHelpers} from "modulekit/ModuleKit.sol";
import {ISuperExecutor} from "../../src/core/interfaces/ISuperExecutor.sol";
import {ExecutionReturnData} from "modulekit/test/RhinestoneModuleKit.sol";

abstract contract InternalHelpers {
    using ModuleKitHelpers for *;

    // -- Rhinestone

    function executeOp(UserOpData memory userOpData) public returns (ExecutionReturnData memory) {
        return userOpData.execUserOps();
    }

    function _getExecOpsWithValidator(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data,
        address validator
    ) internal returns (UserOpData memory userOpData) {
        return instance.getExecOps(address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), validator);
    }

    function _getExecOps(AccountInstance memory instance, ISuperExecutor superExecutor, bytes memory data)
        internal
        returns (UserOpData memory userOpData)
    {
        return instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
    }

    function _getExecOps(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data,
        address paymaster
    ) internal returns (UserOpData memory userOpData) {
        if (paymaster == address(0)) revert("NO_PAYMASTER_SUPPLIED");
        userOpData = instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
        uint128 paymasterVerificationGasLimit = 2e6;
        uint128 postOpGasLimit = 1e6;
        bytes memory paymasterData = abi.encode(uint128(2e6), uint128(10), uint256(1e5)); // paymasterData {
            // maxGasLimit = 200000, nodeOperatorPremium = 10 %, postOpGas = 100000 }
        userOpData.userOp.paymasterAndData =
            abi.encodePacked(paymaster, paymasterVerificationGasLimit, postOpGasLimit, paymasterData);
        return userOpData;
    }

    /*//////////////////////////////////////////////////////////////
                                 SWAPPERS
    //////////////////////////////////////////////////////////////*/

    function _create1InchGenericRouterSwapHookData(
        address dstReceiver,
        address dstToken,
        address executor,
        I1InchAggregationRouterV6.SwapDescription memory desc,
        bytes memory data,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        bytes memory _calldata =
            abi.encodeWithSelector(I1InchAggregationRouterV6.swap.selector, IAggregationExecutor(executor), desc, data);

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, _calldata);
    }

    function _create1InchUnoswapToHookData(
        address dstReceiver,
        address dstToken,
        Address receiverUint256,
        Address fromTokenUint256,
        uint256 decodedFromAmount,
        uint256 minReturn,
        Address dex,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        bytes memory _calldata = abi.encodeWithSelector(
            I1InchAggregationRouterV6.unoswapTo.selector,
            receiverUint256,
            fromTokenUint256,
            decodedFromAmount,
            minReturn,
            dex
        );

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, _calldata);
    }

    function _create1InchClipperSwapToHookData(
        address dstReceiver,
        address dstToken,
        address exchange,
        Address srcToken,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        bytes memory _calldata = abi.encodeWithSelector(
            I1InchAggregationRouterV6.clipperSwapTo.selector,
            exchange,
            payable(dstReceiver),
            srcToken,
            dstToken,
            amount,
            amount,
            0,
            bytes32(0),
            bytes32(0)
        );

        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, _calldata);
    }

    function _createOdosSwapHookData(
        address inputToken,
        uint256 inputAmount,
        address inputReceiver,
        address outputToken,
        uint256 outputQuote,
        uint256 outputMin,
        bytes memory pathDefinition,
        address executor,
        uint32 referralCode,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(
            inputToken,
            inputAmount,
            inputReceiver,
            outputToken,
            outputQuote,
            outputMin,
            usePrevHookAmount,
            pathDefinition.length,
            pathDefinition,
            executor,
            referralCode
        );
    }

    function _createSpectraExchangeSwapHookData(
        bool usePrevHookAmount,
        uint256 value,
        address ptToken,
        address tokenIn,
        uint256 amount,
        address account
    ) internal pure returns (bytes memory) {
        bytes memory txData = _createSpectraExchangeSimpleCommandTxData(ptToken, tokenIn, amount, account);
        return abi.encodePacked(
            /**
             * yieldSourceOracleId
             */
            bytes4(bytes("")),
            /**
             * yieldSource
             */
            ptToken,
            usePrevHookAmount,
            value,
            txData
        );
    }

    function _createSpectraExchangeSimpleCommandTxData(
        address ptToken_,
        address tokenIn_,
        uint256 amount_,
        address account_
    ) internal pure returns (bytes memory) {
        bytes memory commandsData = new bytes(2);
        commandsData[0] = bytes1(uint8(SpectraCommands.TRANSFER_FROM));
        commandsData[1] = bytes1(uint8(SpectraCommands.DEPOSIT_ASSET_IN_PT));

        /// https://dev.spectra.finance/technical-reference/contract-functions/router#deposit_asset_in_pt-command
        // ptToken
        // amount
        // ptRecipient
        // ytRecipient
        // minShares
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(tokenIn_, amount_);
        inputs[1] = abi.encode(ptToken_, amount_, account_, account_, 1);

        return abi.encodeWithSelector(bytes4(keccak256("execute(bytes,bytes[])")), commandsData, inputs);
    }

    function _createMockOdosSwapHookData(
        address inputToken,
        uint256 inputAmount,
        address inputReceiver,
        address outputToken,
        uint256 outputQuote,
        uint256 outputMin,
        bytes memory pathDefinition,
        address executor,
        uint32 referralCode,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            inputToken,
            inputAmount,
            inputReceiver,
            outputToken,
            outputQuote,
            outputMin,
            usePrevHookAmount,
            pathDefinition.length,
            pathDefinition,
            executor,
            referralCode
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 HOOK DATA CREATORS
    //////////////////////////////////////////////////////////////*/

    function _createApproveHookData(address token, address spender, uint256 amount, bool usePrevHookAmount)
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(token, spender, amount, usePrevHookAmount);
    }

    function _createDeposit4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _createApproveAndDeposit4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _create5115DepositHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(
            yieldSourceOracleId, vault, tokenIn, amount, minSharesOut, usePrevHookAmount, vaultBank, dstChainId
        );
    }

    function _createRedeem4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address owner,
        uint256 shares,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, owner, shares, usePrevHookAmount);
    }

    function _createApproveAndRedeem4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address token,
        address owner,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, owner, amount, usePrevHookAmount);
    }

    function _create5115RedeemHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, tokenOut, shares, minTokenOut, false, usePrevHookAmount);
    }

    function _createApproveAndRedeem5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenIn,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool burnFromInternalBalance,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory hookData) {
        hookData = abi.encodePacked(
            yieldSourceOracleId,
            vault,
            tokenIn,
            tokenOut,
            shares,
            minTokenOut,
            burnFromInternalBalance,
            usePrevHookAmount
        );
    }

    function _createRequestDeposit7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createDeposit7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _createRequestRedeem7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createWithdraw7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createApproveAndWithdraw7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount);
    }

    function _createApproveAndRedeem7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 shares,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, shares, usePrevHookAmount);
    }

    function _createDeposit5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, vaultBank, dstChainId
        );
    }

    function _createApproveAndGearboxStakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount);
    }

    function _createGearboxStakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createGearboxUnstakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createApproveAndDeposit5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, vaultBank, dstChainId
        );
    }

    function _createApproveAndRequestDeposit7540HookData(
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(bytes("")), yieldSource, token, amount, usePrevHookAmount);
    }

    function _createCancelHookData(address yieldSource) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(bytes("")), yieldSource);
    }

    function _createClaimCancelHookData(address yieldSource, address receiver) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(bytes("")), yieldSource, receiver);
    }

    function _createMorphoBorrowHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 ltvRatio,
        bool usePrevHookAmount,
        uint256 lltv
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(loanToken, collateralToken, oracle, irm, amount, ltvRatio, usePrevHookAmount, lltv, false);
    }

    function _createMorphoRepayHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 lltv,
        bool usePrevHookAmount,
        bool isFullRepayment
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(loanToken, collateralToken, oracle, irm, amount, lltv, usePrevHookAmount, isFullRepayment);
    }

    function _createMorphoRepayAndWithdrawHookData(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 amount,
        uint256 lltv,
        bool usePrevHookAmount,
        bool isFullRepayment
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(loanToken, collateralToken, oracle, irm, amount, lltv, usePrevHookAmount, isFullRepayment);
    }

    function _createBatchTransferFromHookData(
        address from,
        uint256 arrayLength,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory sig
    ) internal view returns (bytes memory data) {
        return _createBatchTransferFromHookData(from, arrayLength, block.timestamp + 2 weeks, tokens, amounts, sig);
    }

    function _createBatchTransferFromHookData(
        address from,
        uint256 arrayLength,
        uint256 sigDeadline,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory sig
    ) internal pure returns (bytes memory data) {
        data = abi.encodePacked(from, arrayLength, sigDeadline);

        // Directly encode the token addresses as bytes
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, bytes20(tokens[i]));
        }

        // Directly encode the amounts as bytes
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, abi.encodePacked(amounts[i]));
        }

        data = bytes.concat(data, sig);
    }

    function _createTransferERC20HookData(address token, address to, uint256 amount, bool usePrevHookAmount)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(token, to, amount, usePrevHookAmount);
    }
}
