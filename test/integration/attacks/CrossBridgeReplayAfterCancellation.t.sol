// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "test/integration/CrosschainTests.sol";
import { IAcrossV3Receiver } from "src/vendor/bridges/across/IAcrossV3Receiver.sol";

import "forge-std/console.sol";

contract CrossBridgeReplayAfterCancellation is CrosschainTests {
    function setUp() public override {
        super.setUp();
    }

    function test_crossBridgeReplay() external {
        uint256 amountPerVault = 1e8;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        bytes memory innerExecutorPayload;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            address[] memory eth7540HooksAddresses = new address[](2);
            eth7540HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            eth7540HooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

            bytes[] memory eth7540HooksData = new bytes[](2);
            eth7540HooksData[0] =
                _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressETH_USDC, amountPerVault, false);
            eth7540HooksData[1] = _createRequestDeposit7540VaultHookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource7540AddressETH_USDC,
                amountPerVault,
                true
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: eth7540HooksAddresses,
                hooksData: eth7540HooksData,
                validator: address(destinationValidatorOnETH),
                signer: validatorSigners[ETH],
                signerPrivateKey: validatorSignerPrivateKeys[ETH],
                targetAdapter: address(debridgeAdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: amountPerVault,
                account: address(0),
                tokenSent: underlyingETH_USDC
            });

            (innerExecutorPayload, accountToUse) = _createTargetExecutorMessage(messageData);
        }

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amountPerVault, false);

        uint256 msgValue = IDlnSource(DEBRIDGE_DLN_ADDRESSES[BASE]).globalFixedNativeFee();

        bytes memory debridgeData = _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false, //usePrevHookAmount
                value: msgValue, //value
                giveTokenAddress: underlyingBase_USDC, //giveTokenAddress
                giveAmount: amountPerVault, //giveAmount
                version: 1, //envelope.version
                fallbackAddress: accountETH, //envelope.fallbackAddress
                executorAddress: address(debridgeAdapterOnETH), //envelope.executorAddress
                executionFee: uint160(0), //envelope.executionFee
                allowDelayedExecution: false, //envelope.allowDelayedExecution
                requireSuccessfulExecution: true, //envelope.requireSuccessfulExecution
                payload: innerExecutorPayload, //envelope.payload
                takeTokenAddress: underlyingETH_USDC, //takeTokenAddress
                takeAmount: amountPerVault - amountPerVault * 1e4 / 1e5, //takeAmount
                takeChainId: ETH, //takeChainId
                // receiverDst must be the Debridge Adapter on the destination chain
                receiverDst: address(debridgeAdapterOnETH),
                givePatchAuthoritySrc: address(0), //givePatchAuthoritySrc
                orderAuthorityAddressDst: abi.encodePacked(accountETH), //orderAuthorityAddressDst
                allowedTakerDst: "", //allowedTakerDst
                allowedCancelBeneficiarySrc: "", //allowedCancelBeneficiarySrc
                affiliateFee: "", //affiliateFee
                referralCode: 0 //referralCode
             })
        );
        srcHooksData[1] = debridgeData;

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE BASE
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);

        vm.selectFork(FORKS[ETH]);
        // ASSUMPTION 1: A CANCELLATION HAPPENED ON DEBRIDGE
        bytes[] memory cancelData = new bytes[](1);
        {
            address[] memory cancelOrderHooksAddresses = new address[](1);
            cancelOrderHooksAddresses[0] = _getHookAddress(ETH, DEBRIDGE_CANCEL_ORDER_HOOK_KEY);

            cancelData[0] = _createDebrigeCancelOrderData(
                accountBase,
                address(debridgeAdapterOnETH),
                address(0),
                accountETH,
                address(0),
                accountETH, // ✅ Should match allowedCancelBeneficiarySrc from order creation (now accountETH)
                underlyingBase_USDC,
                underlyingETH_USDC,
                msgValue,
                1e8,
                1e8,
                BASE, // giveChainId - the chain where the order was created
                uint256(ETH) // takeChainId - the destination chain
            );

            _createUserOpData(cancelOrderHooksAddresses, cancelData, ETH, false);
        }

        // NOW TRYING TO ENTER VIA ACROSS USING THE SAME SIGNATURE DATA
        vm.startPrank(SPOKE_POOL_V3_ADDRESSES[ETH]);

        // ASSUMPTION 2: USER ACCOUNT ALREADY HAS NECESSARY FUNDS

        deal(underlyingETH_USDC, accountToUse, amountPerVault);

        /// @dev Generate the cross-chain message payload dynamically to match current test setup
        bytes memory payload = innerExecutorPayload;
        IAcrossV3Receiver(contractAddresses[ETH][ACROSS_V3_ADAPTER_KEY]).handleV3AcrossMessage(
            underlyingETH_USDC, 0, address(420), payload
        );

        _execute7540DepositFlow(amountPerVault);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }
}
