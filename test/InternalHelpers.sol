// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { UserOpData } from "modulekit/ModuleKit.sol";
import "../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { IOdosRouterV2 } from "../src/vendor/odos/IOdosRouterV2.sol";
import { SpectraCommands } from "../src/vendor/spectra/SpectraCommands.sol";
import { DlnExternalCallLib } from "../lib/pigeon/src/debridge/libraries/DlnExternalCallLib.sol";
import { console2 } from "forge-std/console2.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ISuperExecutor } from "../src/core/interfaces/ISuperExecutor.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";

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
    )
        internal
        returns (UserOpData memory userOpData)
    {
        return instance.getExecOps(address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), validator);
    }

    function _getExecOps(
        AccountInstance memory instance,
        ISuperExecutor superExecutor,
        bytes memory data
    )
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
    )
        internal
        returns (UserOpData memory userOpData)
    {
        if (paymaster == address(0)) revert("NO_PAYMASTER_SUPPLIED");
        userOpData = instance.getExecOps(
            address(superExecutor), 0, abi.encodeCall(superExecutor.execute, (data)), address(instance.defaultValidator)
        );
        uint128 paymasterVerificationGasLimit = 2e6;
        uint128 postOpGasLimit = 1e6;
        bytes memory paymasterData = abi.encode(uint128(2e6), uint128(10)); // paymasterData {
            // maxGasLimit = 200000, nodeOperatorPremium = 10 % }
        userOpData.userOp.paymasterAndData =
            abi.encodePacked(paymaster, paymasterVerificationGasLimit, postOpGasLimit, paymasterData);
        return userOpData;
    }

    // -- Hooks
    function _createSignatureData_AcrossTargetExecutor(
        uint48 validUntil,
        bytes32 merkleRoot,
        bytes32[] memory merkleProof,
        bytes memory signature
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(validUntil, merkleRoot, merkleProof, signature);
    }

    function _createExecutionData_AcrossTargetExecutor(
        address[] memory hooksAddresses,
        bytes[] memory hooksData
    )
        internal
        pure
        returns (bytes memory)
    {
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        console2.log(
            "length of execution ",
            (abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute))).length
        );
        return abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute));
    }

    /*//////////////////////////////////////////////////////////////
                                 HOOK DATA CREATORS
    //////////////////////////////////////////////////////////////*/

    function _createApproveHookData(
        address token,
        address spender,
        uint256 amount,
        bool usePrevHookAmount
    )
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
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, amount, usePrevHookAmount, lockSP);
    }

    function _createApproveAndDeposit4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, amount, usePrevHookAmount, lockForSP);
    }

    function _create5115DepositHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData =
            abi.encodePacked(yieldSourceOracleId, vault, tokenIn, amount, minSharesOut, usePrevHookAmount, lockSP);
    }

    function _createRedeem4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address owner,
        uint256 shares,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, owner, shares, usePrevHookAmount, lockSP);
    }

    function _createApproveAndRedeem4626HookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address token,
        address owner,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, owner, amount, usePrevHookAmount, lockForSP);
    }

    function _create5115RedeemHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool usePrevHookAmount,
        bool lockSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            yieldSourceOracleId, vault, tokenOut, shares, minTokenOut, false, usePrevHookAmount, lockSP
        );
    }

    function _createApproveAndRedeem5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address vault,
        address tokenIn,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool burnFromInternalBalance,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            yieldSourceOracleId,
            vault,
            tokenIn,
            tokenOut,
            shares,
            minTokenOut,
            burnFromInternalBalance,
            usePrevHookAmount,
            lockForSP
        );
    }

    struct DebridgeOrderData {
        bool usePrevHookAmount;
        uint256 value;
        address giveTokenAddress;
        uint256 giveAmount;
        address takeTokenAddress;
        uint256 takeAmount;
        uint256 takeChainId;
        address receiverDst;
        address givePatchAuthoritySrc;
        bytes orderAuthorityAddressDst;
        bytes allowedTakerDst;
        bytes externalCall;
        bytes allowedCancelBeneficiarySrc;
        bytes affiliateFee;
        uint32 referralCode;
    }

    function _createDebridgeSendFundsAndExecuteHookData(DebridgeOrderData memory d)
        internal
        pure
        returns (bytes memory hookData)
    {
        bytes memory part1 = _encodeDebridgePart1(d);
        bytes memory part2 = _encodeDebridgePart2(d);
        hookData = bytes.concat(part1, part2);
    }

    function _encodeDebridgePart1(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        bytes memory takeTokenAddressBytes = abi.encodePacked(d.takeTokenAddress);
        bytes memory receiverDstBytes = abi.encodePacked(d.receiverDst);

        return abi.encodePacked(
            d.usePrevHookAmount,
            d.value,
            d.giveTokenAddress,
            d.giveAmount,
            takeTokenAddressBytes.length,
            takeTokenAddressBytes,
            d.takeAmount,
            d.takeChainId,
            receiverDstBytes.length,
            receiverDstBytes,
            d.givePatchAuthoritySrc,
            d.orderAuthorityAddressDst.length,
            d.orderAuthorityAddressDst
        );
    }

    function _encodeDebridgePart2(DebridgeOrderData memory d) internal pure returns (bytes memory) {
        return abi.encodePacked(
            d.allowedTakerDst.length,
            d.allowedTakerDst,
            d.externalCall.length,
            d.externalCall,
            d.allowedCancelBeneficiarySrc.length,
            d.allowedCancelBeneficiarySrc,
            d.affiliateFee.length,
            d.affiliateFee,
            d.referralCode
        );
    }

    function _encodeUserOp(UserOpData memory userOpData, uint256 intentAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(
            userOpData.userOp.sender, // account
            intentAmount,
            userOpData.userOp.sender, // sender
            userOpData.userOp.nonce,
            userOpData.userOp.initCode.length,
            userOpData.userOp.initCode,
            userOpData.userOp.callData.length,
            userOpData.userOp.callData,
            userOpData.userOp.accountGasLimits,
            userOpData.userOp.preVerificationGas,
            userOpData.userOp.gasFees,
            userOpData.userOp.paymasterAndData.length,
            userOpData.userOp.paymasterAndData,
            userOpData.userOp.signature
        );
    }

    function _createRequestDeposit7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createDeposit7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createRequestRedeem7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount);
    }

    function _createWithdraw7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createApproveAndWithdraw7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount, lockForSP);
    }

    function _createApproveAndRedeem7540VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 shares,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, shares, usePrevHookAmount, lockForSP);
    }

    function _createDeposit5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, lockForSP
        );
    }

    function _createPermitHookData(
        address token,
        address spender,
        uint256 amount,
        uint256 expiration,
        uint256 sigDeadline,
        uint256 nonce
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(token, uint160(amount), uint48(expiration), uint48(nonce), spender, sigDeadline);
    }

    function _create1InchGenericRouterSwapHookData(
        address dstReceiver,
        address dstToken,
        address executor,
        I1InchAggregationRouterV6.SwapDescription memory desc,
        bytes memory data,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
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
    )
        internal
        pure
        returns (bytes memory)
    {
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
    )
        internal
        pure
        returns (bytes memory)
    {
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

    function _createOdosSwap(
        address inputToken,
        uint256 inputAmount,
        address inputReceiver,
        address outputToken,
        uint256 outputQuote,
        uint256 outputMin,
        address account
    )
        internal
        pure
        returns (IOdosRouterV2.swapTokenInfo memory)
    {
        return IOdosRouterV2.swapTokenInfo(
            inputToken, inputAmount, inputReceiver, outputToken, outputQuote, outputMin, account
        );
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
    )
        internal
        pure
        returns (bytes memory hookData)
    {
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

    function _createApproveAndGearboxStakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount, lockForSP);
    }

    function _createGearboxStakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createGearboxUnstakeHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, lockForSP);
    }

    function _createApproveAndDeposit5115VaultHookData(
        bytes4 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        bool lockForSP
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, lockForSP
        );
    }

    function _createApproveAndRequestDeposit7540HookData(
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
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
    )
        internal
        pure
        returns (bytes memory)
    {
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
    )
        internal
        pure
        returns (bytes memory)
    {
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
    )
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(loanToken, collateralToken, oracle, irm, amount, lltv, usePrevHookAmount, isFullRepayment);
    }

    function _createSpectraExchangeSwapHookData(
        bool usePrevHookAmount,
        uint256 value,
        address ptToken,
        address tokenIn,
        uint256 amount,
        address account
    )
        internal
        pure
        returns (bytes memory)
    {
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
    )
        internal
        pure
        returns (bytes memory)
    {
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

    function _createApproveAndSwapOdosHookData(
        address inputToken,
        uint256 inputAmount,
        address inputReceiver,
        address outputToken,
        uint256 outputQuote,
        uint256 outputMin,
        bytes memory pathDefinition,
        address executor,
        uint32 referralCode,
        bool usePrevHookAmount,
        address approveSpender
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            inputToken,
            inputAmount,
            inputReceiver,
            outputToken,
            outputQuote,
            outputMin,
            usePrevHookAmount,
            approveSpender,
            pathDefinition.length,
            pathDefinition,
            executor,
            referralCode
        );
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
    )
        internal
        pure
        returns (bytes memory)
    {
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

    /**
     * @notice Creates the external call envelope for Debridge DLN V1.
     * @param executorAddress The address of the contract to execute the payload on the destination chain.
     * @param executionFee Fee for the executor.
     * @param fallbackAddress Address to receive funds if execution fails.
     * @param payload The actual data to be executed by the executorAddress.
     * @param allowDelayedExecution Whether delayed execution is allowed.
     * @param requireSuccessfulExecution Whether the external call must succeed.
     * @return The encoded external call envelope V1, prefixed with version byte.
     */
    function _createDebridgeExternalCallEnvelope(
        address executorAddress,
        uint160 executionFee,
        address fallbackAddress,
        bytes memory payload,
        bool allowDelayedExecution,
        bool requireSuccessfulExecution // Note: Keep typo from library 'requireSuccessfullExecution'
    )
        internal
        pure
        returns (bytes memory)
    {
        DlnExternalCallLib.ExternalCallEnvelopV1 memory dataEnvelope = DlnExternalCallLib.ExternalCallEnvelopV1({
            executorAddress: executorAddress,
            executionFee: executionFee,
            fallbackAddress: fallbackAddress,
            payload: payload,
            allowDelayedExecution: allowDelayedExecution,
            requireSuccessfullExecution: requireSuccessfulExecution
        });

        // Prepend version byte (1) to the encoded envelope
        return abi.encodePacked(uint8(1), abi.encode(dataEnvelope));
    }

    function _createBatchTransferFromHookData(
        address from,
        uint256 arrayLength,
        address[] memory tokens,
        uint256[] memory amounts
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(from, arrayLength);
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, bytes20(tokens[i]));
        }
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, abi.encodePacked(amounts[i]));
        }
    }

    function _createTransferERC20HookData(
        address token,
        address to,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(token, to, amount, usePrevHookAmount);
    }
}
