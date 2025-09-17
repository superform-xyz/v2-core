// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IDlnSource } from "../../src/vendor/bridges/debridge/IDlnSource.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import "modulekit/test/RhinestoneModuleKit.sol";
import { IPermit2Batch } from "../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperLedger, ISuperLedgerData } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperDestinationExecutor } from "../../src/interfaces/ISuperDestinationExecutor.sol";
import { AcrossV3Adapter } from "../../src/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../../src/adapters/DebridgeAdapter.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";

// -- centrifuge mocks
import { RestrictionManagerLike } from "../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../mocks/centrifuge/ITranch.sol";
import { IRoot } from "../mocks/centrifuge/IRoot.sol";

contract CrosschainTestsCentrifuge is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    address public rootManager;

    INexusBootstrap nexusBootstrap;

    IAllowanceTransfer public permit2;
    IPermit2Batch public permit2Batch;
    bytes32 public permit2DomainSeparator;

    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;

    uint256 public WARP_START_TIME;

    // ACCOUNTS PER CHAIN
    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;
    address public accountBase;
    address public accountETH;
    address public accountOP;

    // VAULTS/LOGIC related contracts
    address public underlyingETH_USDC;
    address public underlyingBase_USDC;
    address public underlyingOP_USDC;

    address public underlyingOP_USDCe;

    address public underlyingBase_WETH;

    IERC4626 public vaultInstance4626OP;
    IERC4626 public vaultInstance4626Base_USDC;
    IERC4626 public vaultInstance4626Base_WETH;
    IERC4626 public vaultInstanceEth;
    IERC4626 public vaultInstanceMorphoBase;

    IERC7540 public vaultInstance7540ETH;
    address public yieldSource7540AddressETH_USDC;

    address public addressOracleETH;
    IYieldSourceOracle public yieldSourceOracleETH;

    IRoot public root;
    IPoolManager public poolManager;
    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;

    RestrictionManagerLike public restrictionManager;
    IInvestmentManager public investmentManager;

    uint256 public balance_Base_USDC_Before;

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "Centrifuge_7540_ETH_USDC";
    string public constant YIELD_SOURCE_ORACLE_7540_KEY = "YieldSourceOracle_7540";

    // SUPERFORM CONTRACTS PER CHAIN
    // -- executors
    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;
    ISuperDestinationExecutor public superTargetExecutorOnBase;
    ISuperDestinationExecutor public superTargetExecutorOnETH;
    ISuperDestinationExecutor public superTargetExecutorOnOP;

    // -- crosschain adapter
    AcrossV3Adapter public acrossV3AdapterOnBase;
    AcrossV3Adapter public acrossV3AdapterOnETH;
    AcrossV3Adapter public acrossV3AdapterOnOP;
    DebridgeAdapter public debridgeAdapterOnBase;
    DebridgeAdapter public debridgeAdapterOnETH;
    DebridgeAdapter public debridgeAdapterOnOP;

    // -- validators
    IValidator public destinationValidatorOnBase;
    IValidator public destinationValidatorOnETH;
    IValidator public destinationValidatorOnOP;
    IValidator public sourceValidatorOnBase;
    IValidator public sourceValidatorOnETH;
    IValidator public sourceValidatorOnOP;

    // -- ledgers
    ISuperLedger public superLedgerETH;
    ISuperLedger public superLedgerOP;

    // -- paymasters
    ISuperNativePaymaster public superNativePaymasterOnBase;
    ISuperNativePaymaster public superNativePaymasterOnETH;
    ISuperNativePaymaster public superNativePaymasterOnOP;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        super.setUp();

        WARP_START_TIME = 1_740_559_708;

        vm.selectFork(FORKS[ETH]);

        // ROOT/NEXUS/SIGNER
        nexusBootstrap = INexusBootstrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");

        (validatorSigner, validatorSignerPrivateKey) = makeAddrAndKey("The signer");
        vm.label(validatorSigner, "The signer");

        rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        // ACCOUNTS PER CHAIN
        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;
        accountOP = accountInstances[OP].account;

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];
        instanceOnOP = accountInstances[OP];

        // VAULTS/LOGIC related contracts
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];
        vm.label(underlyingOP_USDC, "underlyingOP_USDC");
        underlyingOP_USDCe = existingUnderlyingTokens[OP][USDCE_KEY];
        vm.label(underlyingOP_USDCe, "underlyingOP_USDCe");

        yieldSource7540AddressETH_USDC =
            realVaultAddresses[ETH][ERC7540_FULLY_ASYNC_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSource7540AddressETH_USDC, YIELD_SOURCE_7540_ETH_USDC_KEY);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressETH_USDC);

        // ORACLES
        addressOracleETH = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleETH, YIELD_SOURCE_ORACLE_7540_KEY);
        yieldSourceOracleETH = IYieldSourceOracle(addressOracleETH);

        // ROOT / POOL / TRANCHE SETUP
        address share = IERC7540(yieldSource7540AddressETH_USDC).share();
        address mngr = ITranche(share).hook();

        restrictionManager = RestrictionManagerLike(mngr);
        vm.startPrank(RestrictionManagerLike(mngr).root());
        restrictionManager.updateMember(share, accountETH, type(uint64).max);
        vm.stopPrank();

        poolId = vaultInstance7540ETH.poolId();
        assertEq(poolId, 4_139_607_887);
        trancheId = vaultInstance7540ETH.trancheId();
        assertEq(trancheId, bytes16(0x97aa65f23e7be09fcd62d0554d2e9273));

        poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);
        assetId = poolManager.assetToId(underlyingETH_USDC);
        assertEq(assetId, uint128(242_333_941_209_166_991_950_178_742_833_476_896_417));

        // SUPERFORM CONTRACTS PER CHAIN
        // -- executors
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));

        superTargetExecutorOnBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));

        // -- crosschain adapter
        acrossV3AdapterOnBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnOP = AcrossV3Adapter(_getContract(OP, ACROSS_V3_ADAPTER_KEY));

        debridgeAdapterOnBase = DebridgeAdapter(_getContract(BASE, DEBRIDGE_ADAPTER_KEY));
        debridgeAdapterOnETH = DebridgeAdapter(_getContract(ETH, DEBRIDGE_ADAPTER_KEY));
        debridgeAdapterOnOP = DebridgeAdapter(_getContract(OP, DEBRIDGE_ADAPTER_KEY));

        // -- validators
        destinationValidatorOnBase = IValidator(_getContract(BASE, SUPER_DESTINATION_VALIDATOR_KEY));
        destinationValidatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        destinationValidatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));

        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnOP = IValidator(_getContract(OP, SUPER_MERKLE_VALIDATOR_KEY));

        // -- paymasters
        superNativePaymasterOnBase = ISuperNativePaymaster(_getContract(BASE, SUPER_NATIVE_PAYMASTER_KEY));
        superNativePaymasterOnETH = ISuperNativePaymaster(_getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY));
        superNativePaymasterOnOP = ISuperNativePaymaster(_getContract(OP, SUPER_NATIVE_PAYMASTER_KEY));

        // BALANCES
        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);
    }

    receive() external payable { }
    /*//////////////////////////////////////////////////////////////
                          TESTS
    //////////////////////////////////////////////////////////////*/
    //  >>>> DEBRIDGE

    function test_ETH_Bridge_With_Debridge_And_Deposit() public {
        uint256 amountPerVault = 1e8;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA (This becomes the *payload* for the Debridge external call)
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
                account: accountETH,
                tokenSent: underlyingETH_USDC
            });

            (innerExecutorPayload, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

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
        _processDebridgeDlnMessage(BASE, ETH, executionData);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        _execute7540DepositFlow(amountPerVault);

        vm.selectFork(FORKS[ETH]);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }

    function test_BASE_to_ETH_And_7540RequestDeposit() public {
        uint256 amountPerVault = 1e8 / 2;
        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        {
            address[] memory eth7540HooksAddresses = new address[](2);
            eth7540HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            eth7540HooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

            bytes[] memory eth7540HooksData = new bytes[](2);
            eth7540HooksData[0] =
                _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressETH_USDC, amountPerVault / 2, false);
            eth7540HooksData[1] = _createRequestDeposit7540VaultHookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource7540AddressETH_USDC,
                amountPerVault / 2,
                true
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: eth7540HooksAddresses,
                hooksData: eth7540HooksData,
                validator: address(destinationValidatorOnETH),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: amountPerVault / 2,
                account: address(0),
                tokenSent: underlyingETH_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }
        {
            address share = IERC7540(yieldSource7540AddressETH_USDC).share();

            ITranche(share).hook();

            address mngr = ITranche(share).hook();

            restrictionManager = RestrictionManagerLike(mngr);

            vm.startPrank(RestrictionManagerLike(mngr).root());

            restrictionManager.updateMember(share, accountToUse, type(uint64).max);

            vm.stopPrank();
        }
        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amountPerVault / 2, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            underlyingETH_USDC,
            amountPerVault / 2,
            amountPerVault / 2,
            ETH,
            true,
            targetExecutorMessage
        );

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE, true);

        console2.log(srcUserOpData.userOp.sender);
        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 1 minutes,
                executionData: executionData,
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountToUse,
                relayerGas: 0
            })
        );

        // DEPOSIT
        _fulfill7540DepositRequest(amountPerVault / 2, accountToUse);
        vm.selectFork(FORKS[ETH]);
        uint256 maxDeposit = vaultInstance7540ETH.maxDeposit(accountToUse);
        assertEq(maxDeposit, amountPerVault / 2 - 1, "Max deposit is not as expected");
    }

    function test_Bridge_To_ETH_And_Deposit_Helper_And_Test() public {
        uint256 amountPerVault = 1e8 / 2;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA
        bytes memory targetExecutorMessage;
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
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: amountPerVault,
                account: accountETH,
                tokenSent: underlyingETH_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
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
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 30 days,
                executionData: executionData,
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountETH,
                relayerGas: 0
            })
        );

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        _execute7540DepositFlow(amountPerVault);

        vm.selectFork(FORKS[ETH]);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }

    function test_ETH_Bridge_Deposit_Redeem_Bridge_Back_Flow() public {
        test_Bridge_To_ETH_And_Deposit_Helper_And_Test();
        _redeem_From_ETH_And_Bridge_Back_To_Base(true);
    }

    function test_ETH_Bridge_Deposit_Partial_Redeem_Bridge_Flow() public {
        test_Bridge_To_ETH_And_Deposit_Helper_And_Test();
        _redeem_From_ETH_And_Bridge_Back_To_Base(false);
    }

    function test_ETH_Bridge_Deposit_Redeem_Flow_With_Warping() public {
        test_Bridge_To_ETH_And_Deposit_Helper_And_Test();
        _warped_Redeem_From_ETH_And_Bridge_Back_To_Base();
    }

    function _redeem_From_ETH_And_Bridge_Back_To_Base(bool isFullRedeem) internal {
        uint256 amountPerVault = 1e8 / 2;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        TargetExecutorMessage memory messageData = TargetExecutorMessage({
            hooksAddresses: new address[](0),
            hooksData: new bytes[](0),
            validator: address(destinationValidatorOnBase),
            signer: validatorSigners[BASE],
            signerPrivateKey: validatorSignerPrivateKeys[BASE],
            targetAdapter: address(acrossV3AdapterOnBase),
            targetExecutor: address(superTargetExecutorOnBase),
            nexusFactory: CHAIN_8453_NEXUS_FACTORY,
            nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
            chainId: uint64(BASE),
            amount: amountPerVault,
            account: accountBase,
            tokenSent: underlyingBase_USDC
        });
        (bytes memory targetExecutorMessage, address accountToUse) = _createTargetExecutorMessage(messageData, false);

        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        uint256 userAssetsBefore = IERC20(underlyingETH_USDC).balanceOf(accountETH);

        uint256 userAssetsAfter;

        // REDEEM
        if (isFullRedeem) {
            userAssetsAfter = _execute7540RedeemFlow();
        } else {
            userAssetsAfter = _execute7540PartialRedeemFlow();
        }

        assertGt(userAssetsAfter, userAssetsBefore);

        // BRIDGE BACK
        address[] memory ethHooksAddresses = new address[](2);
        ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory ethHooksData = new bytes[](2);

        if (isFullRedeem) {
            ethHooksData[0] =
                _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amountPerVault, false);
            ethHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
                underlyingETH_USDC,
                underlyingBase_USDC,
                amountPerVault,
                amountPerVault,
                BASE,
                true,
                targetExecutorMessage
            );
        } else {
            ethHooksData[0] =
                _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amountPerVault / 2, false);
            ethHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
                underlyingETH_USDC,
                underlyingBase_USDC,
                amountPerVault / 2,
                amountPerVault / 2,
                BASE,
                true,
                targetExecutorMessage
            );
        }

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);

        UserOpData memory ethUserOpData = _createUserOpData(ethHooksAddresses, ethHooksData, ETH, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, ethUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        ethUserOpData.userOp.signature = signatureData;

        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(ethUserOpData, superNativePaymasterOnETH, 1e18);

        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: WARP_START_TIME + 10 seconds,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NO_HOOKS,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountBase,
                relayerGas: 0
            })
        );
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 10 seconds);

        if (isFullRedeem) {
            assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault);
        } else {
            assertEq(
                IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault / 2
            );
        }
    }

    function _warped_Redeem_From_ETH_And_Bridge_Back_To_Base() internal returns (uint256 userAssets) {
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        uint256 userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);

        uint256 userExpectedAssets = vaultInstance7540ETH.convertToAssets(userShares);

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(userShares, accountETH, accountETH);

        uint256 assetsOut = userExpectedAssets + 20_000;

        // FULFILL REDEEM
        vm.startPrank(rootManager);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(assetsOut), uint128(userShares)
        );

        vm.stopPrank();

        uint256 expectedSharesAvailableToConsume = vaultInstance7540ETH.maxRedeem(accountETH);

        userExpectedAssets = vaultInstance7540ETH.convertToAssets(expectedSharesAvailableToConsume);

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7540VaultHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource7540AddressETH_USDC,
            userExpectedAssets,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH, false);

        ISuperLedger ledger = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        ISuperLedgerConfiguration configSuperLedger =
            ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY));
        SuperLedgerConfiguration.YieldSourceOracleConfig memory config = configSuperLedger.getYieldSourceOracleConfig(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER)
        );
        uint256 pps = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource7540AddressETH_USDC);
        uint8 decimals = IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource7540AddressETH_USDC);
        uint256 expectedFee = ledger.previewFees(
            accountETH, yieldSource7540AddressETH_USDC, assetsOut, expectedSharesAvailableToConsume, 100, pps, decimals
        );

        uint256 feeBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(TREASURY);

        executeOpsThroughPaymaster(redeemOpData, superNativePaymasterOnETH, 1e18);

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingETH_USDC).balanceOf(TREASURY));

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    // Redeems all of the user 7540 vault shares on ETH
    function _execute7540RedeemFlow() internal returns (uint256 userAssets) {
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        uint256 userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);

        uint256 userExpectedAssets = vaultInstance7540ETH.convertToAssets(userShares);

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(userShares, accountETH, accountETH);

        // FULFILL REDEEM
        vm.prank(rootManager);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(userExpectedAssets), uint128(userShares)
        );

        uint256 maxRedeemAmount = vaultInstance7540ETH.maxRedeem(accountETH);

        userExpectedAssets = vaultInstance7540ETH.convertToAssets(maxRedeemAmount);

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7540VaultHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource7540AddressETH_USDC,
            userExpectedAssets,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH, false);

        uint256 feeBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(TREASURY);

        ISuperLedger ledger = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        uint256 expectedFee =
            ledger.previewFees(accountETH, yieldSource7540AddressETH_USDC, userExpectedAssets, userShares, 100, 0, 0);

        console2.log("Expected Fees = ", expectedFee);

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingOutflow(
            accountETH, addressOracleETH, yieldSource7540AddressETH_USDC, userExpectedAssets, expectedFee
        );
        executeOp(redeemOpData);

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingETH_USDC).balanceOf(TREASURY));

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    // Redeems half of the user 7540 vault shares on ETH
    function _execute7540PartialRedeemFlow() internal returns (uint256 userAssets) {
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        uint256 redeemAmount = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH) / 2;

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(redeemAmount, accountETH, accountETH);

        uint256 userExpectedAssets = vaultInstance7540ETH.convertToAssets(redeemAmount);

        // FULFILL REDEEM
        vm.prank(rootManager);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(userExpectedAssets), uint128(redeemAmount)
        );

        uint256 maxRedeemAmount = vaultInstance7540ETH.maxRedeem(accountETH);

        userExpectedAssets = vaultInstance7540ETH.convertToAssets(maxRedeemAmount);

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7540VaultHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource7540AddressETH_USDC,
            userExpectedAssets,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH, false);

        uint256 feeBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(TREASURY);

        ISuperLedger ledger = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        uint256 expectedFee =
            ledger.previewFees(accountETH, yieldSource7540AddressETH_USDC, userExpectedAssets, redeemAmount, 100, 0, 0);

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingOutflow(
            accountETH, addressOracleETH, yieldSource7540AddressETH_USDC, userExpectedAssets, expectedFee
        );
        executeOp(redeemOpData);

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingETH_USDC).balanceOf(TREASURY));

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    // Deposits the given amount of ETH into the 7540 vault
    function _execute7540DepositFlow(uint256 amountPerVault) internal returns (uint256 userShares) {
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        vm.startPrank(rootManager);

        uint256 userExpectedShares = vaultInstance7540ETH.convertToShares(amountPerVault);

        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountETH, assetId, uint128(amountPerVault), uint128(userExpectedShares)
        );

        uint256 maxDeposit = vaultInstance7540ETH.maxDeposit(accountETH);
        userExpectedShares = vaultInstance7540ETH.convertToShares(maxDeposit);

        vm.stopPrank();

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit7540VaultHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource7540AddressETH_USDC,
            maxDeposit,
            false,
            address(0),
            0
        );

        UserOpData memory depositOpData = _createUserOpData(hooksAddresses, hooksData, ETH, false);

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingInflow(
            accountETH,
            addressOracleETH,
            yieldSource7540AddressETH_USDC,
            userExpectedShares,
            yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH))
        );
        executeOp(depositOpData);

        assertEq(
            IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH),
            userExpectedShares,
            "User shares are not as expected"
        );

        userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);
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
        } else if (chainId == OP) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(
                    instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute), address(sourceValidatorOnOP)
                );
            }
            return _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute));
        } else {
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

    function _fulfill7540DepositRequest(uint256 amountPerVault, address accountToUse) internal {
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        vm.startPrank(rootManager);

        uint256 userExpectedShares = vaultInstance7540ETH.convertToShares(amountPerVault);

        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountToUse, assetId, uint128(amountPerVault), uint128(userExpectedShares)
        );

        vm.stopPrank();
    }
}
