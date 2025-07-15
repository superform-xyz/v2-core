// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";
import "../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { SpectraCommands } from "../../src/vendor/spectra/SpectraCommands.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";

abstract contract InternalHelpers is Test {
    using ModuleKitHelpers for *;

    bytes1 public constant REDEEM_IBT_FOR_ASSET = bytes1(uint8(SpectraCommands.REDEEM_IBT_FOR_ASSET));
    bytes1 public constant REDEEM_PT_FOR_ASSET = bytes1(uint8(SpectraCommands.REDEEM_PT_FOR_ASSET));

    // -- Rhinestone
    function executeOpsThroughPaymaster(
        UserOpData memory userOpData,
        ISuperNativePaymaster superNativePaymaster,
        uint256 val
    )
        internal
        returns (ExecutionReturnData memory executionData)
    {
        vm.recordLogs();

        // execute 
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOpData.userOp;
        superNativePaymaster.handleOps{value: val}(ops);

        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        executionData = ExecutionReturnData({
            logs: logs
        });
    }

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
        bytes memory paymasterData = abi.encode(uint128(2e6), uint128(10), uint256(1e5)); // paymasterData {
            // maxGasLimit = 200000, nodeOperatorPremium = 10 %, postOpGas = 100000 }
        userOpData.userOp.paymasterAndData =
            abi.encodePacked(paymaster, paymasterVerificationGasLimit, postOpGasLimit, paymasterData);
        return userOpData;
    }

    function _getYieldSourceOracleId(bytes32 id, address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, sender));
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

    function _createSpectraExchangeDepositHookData(
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
            bytes32(bytes("")),
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

    function _createSpectraExchangeRedeemHookData(
        address asset,
        address pt,
        address recipient,
        uint256 minAssets,
        uint256 sharesToBurn,
        bool usePrevHookAmount,
        bool redeemPtForAsset
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes1 command = redeemPtForAsset ? REDEEM_PT_FOR_ASSET : REDEEM_IBT_FOR_ASSET;

        return abi.encodePacked(
            bytes32(bytes("")), asset, pt, recipient, minAssets, sharesToBurn, usePrevHookAmount, command
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



    function _createApproveAndLockVaultBankHookData(
        bytes32 yieldSourceOracleId,
        address spToken,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, spToken, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _createDeposit4626HookData(
        bytes32 yieldSourceOracleId,
        address vault,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _createApproveAndDeposit4626HookData(
        bytes32 yieldSourceOracleId,
        address vault,
        address token,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, token, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _create5115DepositHookData(
        bytes32 yieldSourceOracleId,
        address vault,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            yieldSourceOracleId, vault, tokenIn, amount, minSharesOut, usePrevHookAmount, vaultBank, dstChainId
        );
    }

    function _createRedeem4626HookData(
        bytes32 yieldSourceOracleId,
        address vault,
        address owner,
        uint256 shares,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, owner, shares, usePrevHookAmount);
    }

    function _create5115RedeemHookData(
        bytes32 yieldSourceOracleId,
        address vault,
        address tokenOut,
        uint256 shares,
        uint256 minTokenOut,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(yieldSourceOracleId, vault, tokenOut, shares, minTokenOut, false, usePrevHookAmount);
    }

    function _createRequestDeposit7540VaultHookData(
        bytes32 yieldSourceOracleId,
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
        bytes32 yieldSourceOracleId,
        address yieldSource,
        uint256 amount,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHookAmount, vaultBank, dstChainId);
    }

    function _createRequestRedeem7540VaultHookData(
        bytes32 yieldSourceOracleId,
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
        bytes32 yieldSourceOracleId,
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

    function _createRedeem7540VaultHookData(
        bytes32 yieldSourceOracleId,
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

    function _createApproveAndRequestRedeem7540VaultHookData(
        bytes32 yieldSourceOracleId,
        address yieldSource,
        uint256 shares,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, shares, usePrevHookAmount);
    }

    function _createDeposit5115VaultHookData(
        bytes32 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, vaultBank, dstChainId
        );
    }

    function _createApproveAndGearboxStakeHookData(
        bytes32 yieldSourceOracleId,
        address yieldSource,
        address token,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, token, amount, usePrevHookAmount);
    }

    function _createGearboxStakeHookData(
        bytes32 yieldSourceOracleId,
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

    function _createGearboxUnstakeHookData(
        bytes32 yieldSourceOracleId,
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

    function _createApproveAndDeposit5115VaultHookData(
        bytes32 yieldSourceOracleId,
        address yieldSource,
        address tokenIn,
        uint256 amount,
        uint256 minSharesOut,
        bool usePrevHookAmount,
        address vaultBank,
        uint256 dstChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, tokenIn, amount, minSharesOut, usePrevHookAmount, vaultBank, dstChainId
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
        return abi.encodePacked(bytes32(bytes("")), yieldSource, token, amount, usePrevHookAmount);
    }

    function _createCancelHookData(address yieldSource) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(bytes("")), yieldSource);
    }

    function _createClaimCancelHookData(address yieldSource, address receiver) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(bytes("")), yieldSource, receiver);
    }

    function _createMorphoSupplyAndBorrowHookData(
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

    function _createBatchTransferFromHookData(
        address from,
        uint256 arrayLength,
        address[] memory tokens,
        uint256[] memory amounts,
        uint48[] memory nonces,
        bytes memory sig
    )
        internal
        view
        returns (bytes memory data)
    {
        return
            _createBatchTransferFromHookData(from, arrayLength, block.timestamp + 2 weeks, tokens, amounts, nonces, sig);
    }

    function _createBatchTransferFromHookData(
        address from,
        uint256 arrayLength,
        uint256 sigDeadline,
        address[] memory tokens,
        uint256[] memory amounts,
        uint48[] memory nonces,
        bytes memory sig
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(from, arrayLength, sigDeadline);

        // Directly encode the token addresses as bytes
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, bytes20(tokens[i]));
        }

        // Directly encode the amounts as bytes
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, abi.encodePacked(amounts[i]));
        }

        // Directly encode the nonces as bytes
        for (uint256 i = 0; i < arrayLength; i++) {
            data = bytes.concat(data, abi.encodePacked(nonces[i]));
        }

        data = bytes.concat(data, sig);
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

    function _createOfframpTokensHookData(
        address to,
        address[] memory tokens
    )
        internal
        pure
        returns (bytes memory data)
    {
        // First 20 bytes: to address
        // Rest: abi encoded tokens array
        data = abi.encodePacked(to, abi.encode(tokens));
    }

    function _createDebrigeCancelOrderData(
        address account,
        address receiver,
        address givePatchAuthority,
        address orderAuthorityAddress,
        address allowedTaker,
        address allowedCancelBeneficiary,
        address inputToken,
        address outputToken,
        uint256 value,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 giveChainId,
        uint256 destinationChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        return _combineOrderCancellationData(
            _createOrderCancellationPart1(
                account, inputToken, outputToken, value, inputAmount, outputAmount, giveChainId, destinationChainId
            ),
            _createOrderCancellationPart2(
                receiver, givePatchAuthority, orderAuthorityAddress, allowedTaker, allowedCancelBeneficiary
            )
        );
    }

    // First part of the cancellation data
    function _createOrderCancellationPart1(
        address account,
        address inputToken,
        address outputToken,
        uint256 value,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 giveChainId,
        uint256 destinationChainId
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory makerSrc = abi.encodePacked(account);
        bytes memory giveTokenAddress = abi.encodePacked(inputToken);
        bytes memory takeTokenAddress = abi.encodePacked(outputToken);

        uint64 makerOrderNonce = 123_456;
        uint256 giveAmount = inputAmount;
        uint256 takeAmount = outputAmount;

        return abi.encodePacked(
            value, // value
            makerOrderNonce, // makerOrderNonce
            uint256(makerSrc.length), // makerSrc length
            makerSrc, // makerSrc
            uint256(giveTokenAddress.length), // giveTokenAddress length
            giveTokenAddress, // giveTokenAddress
            giveAmount, // giveAmount
            giveChainId, // giveChainId
            destinationChainId, // takeChainId
            uint256(takeTokenAddress.length), // takeTokenAddress length
            takeTokenAddress, // takeTokenAddress
            takeAmount // takeAmount
        );
    }

    // Second part of the cancellation data
    function _createOrderCancellationPart2(
        address receiver,
        address givePatchAuthority,
        address orderAuthorityAddress,
        address allowedTaker,
        address allowedCancelBeneficiary
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory receiverDst = abi.encodePacked(receiver);
        bytes memory givePatchAuthoritySrc = abi.encodePacked(givePatchAuthority);
        bytes memory orderAuthorityAddressDst = abi.encodePacked(orderAuthorityAddress);
        bytes memory allowedTakerDst = abi.encodePacked(allowedTaker);
        bytes memory allowedCancelBeneficiarySrc = abi.encodePacked(allowedCancelBeneficiary);

        uint256 executionFee = 0.01 ether;

        return abi.encodePacked(
            uint256(receiverDst.length), // receiverDst length
            receiverDst, // receiverDst
            uint256(givePatchAuthoritySrc.length), // givePatchAuthoritySrc length
            givePatchAuthoritySrc, // givePatchAuthoritySrc
            uint256(orderAuthorityAddressDst.length), // orderAuthorityAddressDst length
            orderAuthorityAddressDst, // orderAuthorityAddressDst
            uint256(allowedTakerDst.length), // allowedTakerDst length
            allowedTakerDst, // allowedTakerDst
            uint256(allowedCancelBeneficiarySrc.length), // allowedCancelBeneficiarySrc length
            allowedCancelBeneficiarySrc, // allowedCancelBeneficiarySrc
            executionFee // executionFee
        );
    }

    // Helper function to combine the data parts
    function _combineOrderCancellationData(
        bytes memory part1,
        bytes memory part2
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(part1, part2);
    }
}
