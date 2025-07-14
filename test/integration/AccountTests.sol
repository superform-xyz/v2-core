// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { AcrossV3Adapter } from "../../src/adapters/AcrossV3Adapter.sol";

// Vault Interfaces
import { ISuperDestinationExecutor } from "../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../src/interfaces/ISuperValidator.sol";

// External
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { BootstrapConfig, INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { INexusFactory } from "../../src/vendor/nexus/INexusFactory.sol";
import { IERC7484 } from "../../src/vendor/nexus/IERC7484.sol";

import { ExecutionLib, Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import "modulekit/test/RhinestoneModuleKit.sol";
import "modulekit/accounts/erc7579/ERC7579Factory.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";

import { BaseHook } from "../../src/hooks/BaseHook.sol";

contract AccountTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    address public underlyingETH_USDC;
    address public underlyingBase_USDC;


    address public accountBase;
    address public accountETH;


    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;

    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;

    AcrossV3Adapter public acrossV3AdapterOnBase;
    AcrossV3Adapter public acrossV3AdapterOnETH;

    ISuperDestinationExecutor public superTargetExecutorOnBase;
    ISuperDestinationExecutor public superTargetExecutorOnETH;

    IValidator public validatorOnBase;
    IValidator public validatorOnETH;

    IValidator public sourceValidatorOnBase;
    IValidator public sourceValidatorOnETH;

    INexusBootstrap nexusBootstrap;

    uint256 public constant WARP_START_TIME = 1_740_559_708;

    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;


    function setUp() public override {
        super.setUp();

        // Set up the underlying tokens
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];

        // Set up the accounts
        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];

        // Set up the super executors
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
     
        // Set up the super target executors
        superTargetExecutorOnBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));

        acrossV3AdapterOnBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));
        // Set up the destination validators
        validatorOnBase = IValidator(_getContract(BASE, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));

        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));

        (validatorSigner, validatorSignerPrivateKey) = makeAddrAndKey("The signer");
        vm.label(validatorSigner, "The signer");
    }

    /*//////////////////////////////////////////////////////////////
                            TESTS
    //////////////////////////////////////////////////////////////*/
    function test_CreateNexusAccount_Through_SuperDestinationExecutor_7702_no_hooks() public {
        uint256 amountPerVault = 1e8 / 2;
        address randomAllowanceReceiver = makeAddr("randomAllowanceReceiver");

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        {
            address[] memory dstHookAddresses = new address[](1);
            dstHookAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            bytes[] memory dstHookData = new bytes[](1);
            dstHookData[0] = _createApproveHookData(underlyingETH_USDC, randomAllowanceReceiver, amountPerVault, false);

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHookAddresses,
                hooksData: dstHookData,
                validator: address(validatorOnETH),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: amountPerVault,
                account: validatorSigner,
                tokenSent: underlyingETH_USDC
            });

            (targetExecutorMessage, accountToUse) = _create7702TargetExecutorMessage(messageData, address(this), validatorSigner);
        }

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amountPerVault, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC, underlyingETH_USDC, amountPerVault, amountPerVault, ETH, true, targetExecutorMessage
        );

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, messageData.account, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE BASE
        _directAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 30 days,
                executionData: executeOp(srcUserOpData),
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: validatorSigner,
                relayerGas: 0
            })
        );

        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME + 30 days);
        uint256 allowance = IERC20(underlyingETH_USDC).allowance(messageData.account, randomAllowanceReceiver);
        assertEq(allowance, amountPerVault, "Allowance not set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC HELPERS
    //////////////////////////////////////////////////////////////*/
    // Simulates the `SuperSenderCreator`
    function createSender(bytes calldata initCode, address computedAddress) external returns (address sender, address delegatee) {
        address initAddress = address(bytes20(initCode[0 : 20]));
        bytes memory initCallData = initCode[20:];

        bool success;
        bytes memory returnData = new bytes(32);
        (success, returnData) = initAddress.call{value: 0}(initCallData);
        if (!success) {
            revert("Failed to create sender account");  
        }
        delegatee = abi.decode(returnData, (address));
        assertGt(delegatee.code.length, 0, "Sender account not created");
        vm.etch(computedAddress, delegatee.code);


        /**   
        vm.deal(sender, 1 ether);

        Execution[] memory executions = new Execution[](1);
        executions[0] =
            Execution({target: sender, value: 0, callData: abi.encodeCall(IMSA.initializeAccount, initCallData)});
        //bytes memory callData = abi.encodeCall(IERC7579Account.nstallModule, (MODULE_TYPE_VALIDATOR, address(sourceValidatorOnETH), abi.encode(validatorSigner)));
        //executions[0] =
        //    Execution({target: sender, value: 0, callData: callData});

        bytes memory userOpCalldata =
            abi.encodeCall(IERC7579Account.execute, (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)));

        uint192 key = _makeNonceKey(MODE_VALIDATION, address(sourceValidatorOnETH));
        uint256 nonce = IEntryPoint(ENTRYPOINT_ADDR).getNonce(sender, key);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getDefaultUserOp();
        userOps[0].sender = sender;
        userOps[0].nonce = nonce;
        userOps[0].callData = userOpCalldata;
        
        // since this is an `etch` test, only available in a test, we are ok with generating the sigData her
        //  - if we need this in a real scenario, this would be passed in the initData
        {
            uint48 validUntil = uint48(block.timestamp + 1 hours);
            bytes32[] memory leaves = new bytes32[](1);
            leaves[0] = _createSourceValidatorLeaf(
                IEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOps[0]), validUntil, false, address(sourceValidatorOnETH)
            );
            (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);
            bytes memory signature = _getSignature(root);
            ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
            bytes memory sigData = abi.encode(false, validUntil, root, proof[0], proofDst, signature);
            // -- replace signature with validator signature
            userOps[0].signature = sigData;
        }
        IEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(address(0x69)));
        */ 
        sender = computedAddress;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    function _makeNonceKey(bytes1 vMode, address validator) internal pure returns (uint192 key) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            key := or(shr(88, vMode), validator)
        }
    }

    function _getSignature(bytes32 root) private view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode("SuperValidator", root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorSignerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function _getDefaultUserOp() internal pure returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }

    function _create7702TargetExecutorMessage(TargetExecutorMessage memory messageData, address senderCreator, address eoa)
        internal
        override
        returns (bytes memory, address)
    {
        bytes memory executionData =
            _createCrosschainExecutionData_DestinationExecutor(messageData.hooksAddresses, messageData.hooksData);

        address accountToUse;
        bytes memory accountCreationData;
        (accountCreationData, accountToUse) = _createAccountCreationData_DestinationExecutor(
            AccountCreationParams({
                senderCreatorOnDestinationChain: senderCreator,
                dstValidatorOnChain: messageData.validator,
                srcValidatorOnChain: address(sourceValidatorOnETH),
                theSigner: messageData.signer,
                executorOnDestinationChain: _getContract(messageData.chainId, SUPER_DESTINATION_EXECUTOR_KEY),
                nexusFactory: messageData.nexusFactory,
                nexusBootstrap: messageData.nexusBootstrap
            })
        );
        messageData.account = accountToUse; // prefill the account to use
    
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = messageData.tokenSent;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = messageData.amount;
        return (
            abi.encode(accountCreationData, executionData, accountToUse, dstTokens, intentAmounts), eoa
        );
    }

    function _createAccountCreationData_DestinationExecutor(
        AccountCreationParams memory p
    )
        internal
        override
        returns (bytes memory, address)
    {
        BootstrapConfig[] memory validators;
        if (p.srcValidatorOnChain == address(0)) {
            validators = new BootstrapConfig[](1);
            validators[0] = BootstrapConfig({ module: p.dstValidatorOnChain, data: abi.encode(p.theSigner) });
        } else {
            validators = new BootstrapConfig[](2);
            validators[0] = BootstrapConfig({ module: p.dstValidatorOnChain, data: abi.encode(p.theSigner) });
            validators[1] = BootstrapConfig({ module: p.srcValidatorOnChain, data: abi.encode(p.theSigner) });
        }
       
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: p.executorOnDestinationChain, data: "" });
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);

        address[] memory attesters = new address[](1);
        attesters[0] = address(MANAGER);
        uint8 threshold = 1;

        bytes memory initData = INexusBootstrap(p.nexusBootstrap).getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(address(0)), attesters, threshold
        );

        bytes32 initSalt = bytes32(keccak256("SIGNER_SALT"));
        
        address precomputedAddress = INexusFactory(p.nexusFactory).computeAccountAddress(initData, initSalt);
        console2.log("-------------------------- precomputedAddress", precomputedAddress);
        bytes memory initFactoryCalldata = abi.encodeWithSelector(INexusFactory.createAccount.selector, initData, initSalt);

        return (abi.encodePacked(p.senderCreatorOnDestinationChain, address(p.nexusFactory), initFactoryCalldata), precomputedAddress);
    }

    // Creates userOpData for the given chainId
    function _createUserOpData(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        uint64 chainId,
        bool withValidator
    )
        internal
        returns (UserOpData memory)
    {
        if (chainId == ETH) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(
                    instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute), address(sourceValidatorOnETH)
                );
            }
            return _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));
        } else{
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(
                    instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute), address(sourceValidatorOnBase)
                );
            }
            return _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        }
    }
}