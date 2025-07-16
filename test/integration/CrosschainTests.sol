// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IDlnSource } from "../../src/vendor/bridges/debridge/IDlnSource.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../src/vendor/BytesLib.sol";


// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperLedger, ISuperLedgerData } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperDestinationExecutor } from "../../src/interfaces/ISuperDestinationExecutor.sol";
import { AcrossV3Adapter } from "../../src/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../../src/adapters/DebridgeAdapter.sol";
import { SuperValidatorBase } from "../../src/validators/SuperValidatorBase.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";
// -- centrifuge mocks
import { RestrictionManagerLike } from "../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../mocks/centrifuge/ITranch.sol";
import { IRoot } from "../mocks/centrifuge/IRoot.sol";



contract CrosschainTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    address public rootManager;
 
    INexusBootstrap nexusBootstrap;

    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;

    uint256 public CHAIN_1_TIMESTAMP;
    uint256 public CHAIN_10_TIMESTAMP;
    uint256 public CHAIN_8453_TIMESTAMP;
    uint256 public constant WARP_START_TIME = 1_740_559_708;


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
    IERC4626 public vaultInstanceMorphoEth;
    IERC4626 public vaultInstanceMorphoBase;
    address public yieldSource4626AddressOP_USDCe;
    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;
    address public yieldSourceMorphoUsdcAddressEth;
    address public yieldSourceMorphoUsdcAddressBase;

    IERC7540 public vaultInstance7540ETH;
    address public yieldSource7540AddressETH_USDC;

    address public addressOracleOP;
    address public addressOracleETH;
    address public addressOracleBase;
    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleOP;

    IRoot public root;
    IPoolManager public poolManager;
    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;
    
    RestrictionManagerLike public restrictionManager;
    IInvestmentManager public investmentManager;

    uint256 public balance_Base_USDC_Before;

    string public constant YIELD_SOURCE_4626_BASE_USDC_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_BASE_WETH_KEY = "ERC4626_BASE_WETH";

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "Centrifuge_7540_ETH_USDC";
    string public constant YIELD_SOURCE_ORACLE_7540_KEY = "YieldSourceOracle_7540";

    string public constant YIELD_SOURCE_4626_OP_USDCe_KEY = "YieldSource_4626_OP_USDCe";
    string public constant YIELD_SOURCE_ORACLE_4626_KEY = "YieldSourceOracle_4626";

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

    // STACK-TOO-DEEP structs
    /// @notice Struct to hold test parameters for test_Bridge_Deposit4626_UsedRoot_Because_Frontrunning test to avoid stack too deep
    struct BridgeDeposit4626UsedRootParams {
        uint256 amount;
        uint256 previewRedeemAmount;
        bytes targetExecutorMessage;
        TargetExecutorMessage messageData;
        address accountToUse;
        address[] srcHooksAddresses;
        bytes[] srcHooksData;
        address[] dstHooksAddresses;
        bytes[] dstHooksData;
        ISuperExecutor.ExecutorEntry entry;
        UserOpData srcUserOpData;
        bytes signatureData;
    }

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public override {
        super.setUp();

        // CORE CHAIN CONTEXT
        vm.selectFork(FORKS[ETH]);
        CHAIN_1_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[OP]);
        CHAIN_10_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[BASE]);
        CHAIN_8453_TIMESTAMP = block.timestamp;
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
        underlyingOP_USDCe = existingUnderlyingTokens[OP][USDCe_KEY];
        vm.label(underlyingOP_USDCe, "underlyingOP_USDCe");

        yieldSource7540AddressETH_USDC =
            realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSource7540AddressETH_USDC, YIELD_SOURCE_7540_ETH_USDC_KEY);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressETH_USDC);

        yieldSource4626AddressOP_USDCe =
            realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY];
        vaultInstance4626OP = IERC4626(yieldSource4626AddressOP_USDCe);
        vm.label(yieldSource4626AddressOP_USDCe, YIELD_SOURCE_4626_OP_USDCe_KEY);

        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);

        yieldSource4626AddressBase_WETH =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][AAVE_BASE_WETH][WETH_KEY];
        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);

        yieldSourceMorphoUsdcAddressEth =
            realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoEth = IERC4626(yieldSourceMorphoUsdcAddressEth);
        vm.label(yieldSourceMorphoUsdcAddressEth, "YIELD_SOURCE_MORPHO_USDC_ETH");

        yieldSourceMorphoUsdcAddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSourceMorphoUsdcAddressBase);
        vm.label(yieldSourceMorphoUsdcAddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        // ORACLES
        addressOracleETH = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleETH, YIELD_SOURCE_ORACLE_7540_KEY);
        yieldSourceOracleETH = IYieldSourceOracle(addressOracleETH);

        addressOracleOP = _getContract(OP, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleOP, YIELD_SOURCE_ORACLE_4626_KEY);
        yieldSourceOracleOP = IYieldSourceOracle(addressOracleOP);

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

        // -- ledgers
        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        superLedgerOP = ISuperLedger(_getContract(OP, SUPER_LEDGER_KEY));

        // BALANCES
        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // CUSTOM DEAL SETUP
        vm.selectFork(FORKS[OP]);
        deal(underlyingOP_USDC, mockOdosRouters[OP], 1e18);

        vm.selectFork(FORKS[BASE]);
        deal(underlyingBase_WETH, mockOdosRouters[BASE], 1e12);
    }

    receive() external payable {}
    /*//////////////////////////////////////////////////////////////
                          TESTS
    //////////////////////////////////////////////////////////////*/
    
    // --- THROUGH PAYMASTER ---

    //  >>>> ACCOUNT CREATION TESTS
    function test_Bridge_To_ETH_And_Create_Nexus_Account() public {
        uint256 amountPerVault = 1e8 / 2;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        {
            address[] memory dstHookAddresses = new address[](0);
            bytes[] memory dstHookData = new bytes[](0);

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHookAddresses,
                hooksData: dstHookData,
                validator: address(destinationValidatorOnETH),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: amountPerVault,
                account: address(0),
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

        // EXECUTE BASE
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 30 days,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NO_HOOKS,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountToUse,
                relayerGas: 0
            })
        );
    }

    function test_Bridge_To_ETH_And_Create_Nexus_Account_7702Flow() public {
        uint256 _warpStartTime = 1752648279;

        uint256 amountPerVault = 1e8 / 2;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, _warpStartTime);

        _doEIP7702(validatorSigner, address(0x0000000025a29E0598c88955fd00E256691A089c));

        // PREPARE ETH DATA
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        {
            address[] memory dstHookAddresses = new address[](0);
            bytes[] memory dstHookData = new bytes[](0);

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHookAddresses,
                hooksData: dstHookData,
                validator: address(destinationValidatorOnETH),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
                nexusFactory: 0x0000000025a29E0598c88955fd00E256691A089c,
                nexusBootstrap: 0x000000001aafD7ED3B8baf9f46cD592690A5BBE5,
                chainId: uint64(ETH),
                amount: amountPerVault,
                account: address(0),
                tokenSent: underlyingETH_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, true);
        }

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, _warpStartTime + 30 days);

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

        // EXECUTE BASE
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: _warpStartTime + 30 days,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NO_HOOKS,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountToUse,
                relayerGas: 0
            })
        );
    }

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
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER), yieldSource7540AddressETH_USDC, amountPerVault, true
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
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
        _processDebridgeDlnMessage(BASE, ETH, executionData);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        _execute7540DepositFlow(amountPerVault);

        vm.selectFork(FORKS[ETH]);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }

    function test_DeBridgeCancelOrderHook() public {
        uint256 amountPerVault = 1e8;

        _sendDeBridgeOrder();

        // Cancel order on ETH
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        address[] memory cancelOrderHooksAddresses = new address[](1);
        cancelOrderHooksAddresses[0] = _getHookAddress(ETH, DEBRIDGE_CANCEL_ORDER_HOOK_KEY);

        uint256 value = IDlnSource(DEBRIDGE_DLN_ADDRESSES[ETH]).globalFixedNativeFee();

        bytes[] memory cancelData = new bytes[](1);
        cancelData[0] = _createDebrigeCancelOrderData(
            accountBase,
            address(debridgeAdapterOnETH),
            address(0),
            accountETH,
            address(0),
            accountETH, // ✅ Should match allowedCancelBeneficiarySrc from order creation (now accountETH)
            underlyingBase_USDC,
            underlyingETH_USDC,
            value,
            amountPerVault,
            amountPerVault,
            BASE, // giveChainId - the chain where the order was created
            uint256(ETH) // takeChainId - the destination chain
        );

        UserOpData memory cancelOrderUserOpData = _createUserOpData(cancelOrderHooksAddresses, cancelData, ETH, false);

        // accountETH
        executeOpsThroughPaymaster(cancelOrderUserOpData, superNativePaymasterOnETH, 1e18);

        console2.log("CANCELLED ORDER");
        //console2.log(IERC20(underlyingBase_USDC).balanceOf(accountETH));
        // assertEq(IERC20(underlyingBase_USDC).balanceOf(accountETH), amountPerVault);
    }

    //  >>>> ACROSS
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
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER), yieldSource7540AddressETH_USDC, amountPerVault / 2, true
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
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

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
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
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
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER), yieldSource7540AddressETH_USDC, amountPerVault, true
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
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
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

    function test_bridge_To_OP_And_Deposit_Test_And_Helper() public {
        uint256 amountPerVault = 1e8 / 2;

        // OP IS DST
        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            // PREPARE OP DATA
            address[] memory opHooksAddresses = new address[](2);
            opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
            opHooksAddresses[1] = _getHookAddress(OP, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory opHooksData = new bytes[](2);
            opHooksData[0] =
                _createApproveHookData(underlyingOP_USDCe, yieldSource4626AddressOP_USDCe, amountPerVault, false);
            opHooksData[1] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource4626AddressOP_USDCe,
                amountPerVault,
                true,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: opHooksAddresses,
                hooksData: opHooksData,
                validator: address(destinationValidatorOnOP),
                signer: validatorSigners[OP],
                signerPrivateKey: validatorSignerPrivateKeys[OP],
                targetAdapter: address(acrossV3AdapterOnOP),
                targetExecutor: address(superTargetExecutorOnOP),
                nexusFactory: CHAIN_10_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_10_NEXUS_BOOTSTRAP,
                chainId: uint64(OP),
                amount: amountPerVault,
                account: accountOP,
                tokenSent: underlyingOP_USDCe
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        uint256 previewDepositAmountOP = vaultInstance4626OP.previewDeposit(amountPerVault);

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        uint256 userBalanceBaseUSDCBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // PREPARE BASE DATA
        address[] memory srcHooksAddressesOP = new address[](2);
        srcHooksAddressesOP[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddressesOP[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksDataOP = new bytes[](2);
        srcHooksDataOP[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amountPerVault, false);
        srcHooksDataOP[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC, underlyingOP_USDCe, amountPerVault, amountPerVault, OP, true, targetExecutorMessage
        );

        UserOpData memory srcUserOpDataOP = _createUserOpData(srcHooksAddressesOP, srcHooksDataOP, BASE, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpDataOP.userOpHash, accountToUse, OP, address(sourceValidatorOnBase)
        );
        srcUserOpDataOP.userOp.signature = signatureData;

        // EXECUTE OP
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpDataOP, superNativePaymasterOnBase, 1e18); 
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: OP,
                warpTimestamp: WARP_START_TIME,
                executionData: executionData,
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountOP,
                relayerGas: 0
            })
        );

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), userBalanceBaseUSDCBefore - amountPerVault, "A");

        vm.selectFork(FORKS[OP]);
        assertEq(vaultInstance4626OP.balanceOf(accountOP), previewDepositAmountOP, "B");
    }

    function test_OP_Bridge_Deposit_Redeem_Flow() public {
        test_bridge_To_OP_And_Deposit_Test_And_Helper();
        _redeem_From_OP();
    }

    function test_OP_Bridge_Deposit_Redeem_Bridge_Back_Flow() public {
        test_bridge_To_OP_And_Deposit_Test_And_Helper();
        _redeem_From_OP_And_Bridge_Back_To_Base();
    }

    function test_OP_Bridge_Deposit_Redeem_Flow_With_Warping() public {
        test_bridge_To_OP_And_Deposit_Test_And_Helper();
        _warped_Redeem_From_OP();
    }
    
    function test_CrossChainDepositWithSlippage() public {
        SELECT_FORK_AND_WARP(ETH, CHAIN_1_TIMESTAMP + 1 days);
        _sendFundsFromOpToBase();
        _sendFundsFromEthToBase();
    }

    function test_RevertFrom_SuperDestinationExecutor() public {
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
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER), address(0), 0, false
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
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

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

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 30 days,
                executionData: executionData,
                relayerType: RELAYER_TYPE.REVERT,
                errorMessage: BaseHook.AMOUNT_NOT_VALID.selector,
                errorReason: "",
                root: bytes32(0),
                account: accountToUse,
                relayerGas: 0
            })
        );
    }

    function test_Bridge_WithPrevHookAmount() public {
        uint256 amountPerVault = 1e8;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA
        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            address[] memory dstHooks = new address[](0);
            bytes[] memory dstHooksData = new bytes[](0);

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooks,
                hooksData: dstHooksData,
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

        uint256 initialOutputAmount = amountPerVault / 2;

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);
        uint256 balanceBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amountPerVault, false);
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

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18); 
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 30 days,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NO_HOOKS,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountETH,
                relayerGas: 0
            })
        );
        uint256 balanceAfter = IERC20(underlyingBase_USDC).balanceOf(accountBase);
        uint256 amountSent = balanceBefore - balanceAfter;
        assertEq(amountSent, initialOutputAmount * 2, "A");
    }

    function test_RebalanceCrossChain_4626_Mainnet_Flow() public {
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount =
            vaultInstanceMorphoEth.previewRedeem(vaultInstanceMorphoEth.previewDeposit(amount));

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            // PREPARE DST DATA
            address[] memory dstHooksAddresses = new address[](2);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](2);
            dstHooksData[0] = _createApproveHookData(
                underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, previewRedeemAmount, false
            );
            dstHooksData[1] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSourceMorphoUsdcAddressBase,
                previewRedeemAmount,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: amount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressEth,
            amount,
            false,
            address(0),
            0
        );
        srcHooksData[2] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        srcHooksData[3] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            previewRedeemAmount,
            previewRedeemAmount,
            BASE,
            true,
            targetExecutorMessage
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(entry), address(sourceValidatorOnETH)
        );
        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        srcUserOpData.userOp.signature = signatureData;

        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnETH, 1e18);
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: executionData,
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountBase,
                relayerGas: 0
            })
        );
    }

    function test_Bridge_Deposit4626_UsedRoot_Because_Frontrunning() public {
        BridgeDeposit4626UsedRootParams memory params;

        // Initialize test parameters
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        params.amount = 1e8;
        params.previewRedeemAmount =
            vaultInstanceMorphoEth.previewRedeem(vaultInstanceMorphoEth.previewDeposit(params.amount));

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        // Set up destination hooks and data
        {
            // PREPARE DST DATA
            params.dstHooksAddresses = new address[](2);
            params.dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            params.dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            params.dstHooksData = new bytes[](2);
            params.dstHooksData[0] = _createApproveHookData(
                underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, params.previewRedeemAmount, false
            );
            params.dstHooksData[1] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSourceMorphoUsdcAddressBase,
                params.previewRedeemAmount,
                false,
                address(0),
                0
            );

            params.messageData = TargetExecutorMessage({
                hooksAddresses: params.dstHooksAddresses,
                hooksData: params.dstHooksData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: params.previewRedeemAmount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (params.targetExecutorMessage, params.accountToUse) = _createTargetExecutorMessage(params.messageData, false);
        }

        _getTokens(underlyingBase_USDC, params.accountToUse, params.previewRedeemAmount);

        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        // Set up source hooks and data
        params.srcHooksAddresses = new address[](4);
        params.srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        params.srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        params.srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        params.srcHooksAddresses[3] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        params.srcHooksData = new bytes[](4);
        params.srcHooksData[0] =
            _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, params.amount, false);
        params.srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressEth,
            params.amount,
            false,
            address(0),
            0
        );
        params.srcHooksData[2] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        params.srcHooksData[3] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            params.previewRedeemAmount,
            params.previewRedeemAmount,
            BASE,
            false,
            params.targetExecutorMessage
        );

        params.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: params.srcHooksAddresses, hooksData: params.srcHooksData });

        params.srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(params.entry), address(sourceValidatorOnETH)
        );
        params.signatureData = _createMerkleRootAndSignature(
            params.messageData,
            params.srcUserOpData.userOpHash,
            params.accountToUse,
            BASE,
            address(sourceValidatorOnETH)
        );
        params.srcUserOpData.userOp.signature = params.signatureData;

        // Frontrun the actual call
        SELECT_FORK_AND_WARP(BASE, block.timestamp + 1 days);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = underlyingBase_USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = params.previewRedeemAmount;
        (bytes memory accountCreationData, bytes memory executionData,,,) =
            abi.decode(params.targetExecutorMessage, (bytes, bytes, address, address[], uint256[]));

        uint256 tokensAmountBeforeProcessing = IERC20(underlyingBase_USDC).balanceOf(params.accountToUse);
        assertEq(tokensAmountBeforeProcessing, params.previewRedeemAmount);
        superTargetExecutorOnBase.processBridgedExecution(
            address(this),
            params.accountToUse,
            dstTokens,
            intentAmounts,
            accountCreationData,
            executionData,
            params.signatureData
        );
        uint256 tokensAmountAfterProcessing = IERC20(underlyingBase_USDC).balanceOf(params.accountToUse);
        assertEq(tokensAmountAfterProcessing, 0);

        // now the actual bridge message arrives
        SELECT_FORK_AND_WARP(ETH, block.timestamp + 1 days);
        bytes32 _merkleRoot = bytes32(BytesLib.slice(params.signatureData, 64, 32));
        ExecutionReturnData memory _paymasterExecutionData = executeOpsThroughPaymaster(params.srcUserOpData, superNativePaymasterOnETH, 1e18);
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: _paymasterExecutionData,
                relayerType: RELAYER_TYPE.USED_ROOT,
                errorMessage: bytes4(0),
                errorReason: "",
                root: _merkleRoot,
                account: accountBase,
                relayerGas: 0
            })
        );

        // Verify results
        SELECT_FORK_AND_WARP(BASE, block.timestamp + 10 days);

        uint256 tokensAmountAfterBridgeMessage = IERC20(underlyingBase_USDC).balanceOf(params.accountToUse);
        // tokens should have been sent to the acount even when merkle root was marked as used
        assertEq(tokensAmountAfterBridgeMessage, params.previewRedeemAmount);
    }
     
    function test_InvalidDestinationFlow() public {
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount =
            vaultInstanceMorphoEth.previewRedeem(vaultInstanceMorphoEth.previewDeposit(amount));

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            /// @dev this test lacks an allowance hook, hence it will revert
            // PREPARE DST DATA
            address[] memory dstHooksAddresses = new address[](1);
            dstHooksAddresses[0] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](1);
            dstHooksData[0] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSourceMorphoUsdcAddressBase,
                previewRedeemAmount,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: amount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressEth,
            amount,
            false,
            address(0),
            0
        );
        srcHooksData[2] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 0, true);

        srcHooksData[3] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            previewRedeemAmount,
            previewRedeemAmount,
            BASE,
            true,
            targetExecutorMessage
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(entry), address(sourceValidatorOnETH)
        );
        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        srcUserOpData.userOp.signature = signatureData;

        ExecutionReturnData memory _paymasterExecutionData = executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnETH, 1e18);
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: _paymasterExecutionData,
                relayerType: RELAYER_TYPE.REVERT,
                errorMessage: bytes4(0),
                errorReason: "ERC20: transfer amount exceeds allowance",
                account: accountBase,
                root: bytes32(0),
                relayerGas: 0
            })
        );
    }


    // --- NO PAYMASTER ---
    function test_FAILS_ETH_Bridge_With_Debridge_And_Deposit() public {
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
        // attacker changes the dstProof in signature to empty bytes32[]
        (
            bool validateDstProof,
            uint48 validUntil,
            bytes32 merkleRoot,
            bytes32[] memory merkleProofSrc,
            , // This will be replaced
            bytes memory signature
        ) = abi.decode(signatureData, (bool, uint48, bytes32, bytes32[], bytes32[], bytes));

        bytes32[] memory emptyMerkleProofDst = new bytes32[](0);

        bytes memory tamperedSig =
            abi.encode(validateDstProof, validUntil, merkleRoot, merkleProofSrc, emptyMerkleProofDst, signature);

        srcUserOpData.userOp.signature = tamperedSig;

        // execute op on src chain, this will pass the validation even with tampered signature
        vm.expectRevert(SuperValidatorBase.INVALID_DESTINATION_PROOF.selector);
        instanceOnETH.expect4337Revert();
        executeOp(srcUserOpData);
        // ^ this now fails

        // EXECUTE BASE
        // execution fails on the call to SuperDestinationExecutor::processBridgedExecution
        //vm.expectRevert();
        //_processDebridgeDlnMessage(BASE, ETH, returnData);
    }

    function testOrion_maliciousRelayersDoSCrosschainExecution() public {
        uint256 amountPerVault = 1e8 / 2;

        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // 1. Prepare data for ETH (destination chain). On destination, we'll:
        // - Approve an ERC20
        // - Request a deposit in a 7540 vault
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        {
            // Create hook addresses
            address[] memory eth7540HooksAddresses = new address[](2);
            eth7540HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            eth7540HooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

            // Create hook data
            bytes[] memory eth7540HooksData = new bytes[](2);
            eth7540HooksData[0] =
                _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressETH_USDC, amountPerVault / 2, false);
            eth7540HooksData[1] = _createRequestDeposit7540VaultHookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource7540AddressETH_USDC,
                amountPerVault / 2,
                true
            );

            // Build the target executor message
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

        // 2. Update account in restriction manager
        {
            address share = IERC7540(yieldSource7540AddressETH_USDC).share();

            ITranche(share).hook();

            address mngr = ITranche(share).hook();

            restrictionManager = RestrictionManagerLike(mngr);

            vm.startPrank(RestrictionManagerLike(mngr).root());

            restrictionManager.updateMember(share, accountToUse, type(uint64).max);

            vm.stopPrank();
        }

        // 3. Prepare data for Base (source chain). On source, we'll:
        // - Approve an ERC20 to the accross bridge
        // - Send funds via across
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        // Prepare hooks addresses
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        // Prepare hooks data
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

        // Build userOp
        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // 4. Trigger execution with low gas.
        // `executeOp` will execute the source transaction, sending the message to destination via
        // across. It returns the userOp execution logs, which are later dissected the accross helper contract.

        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 30 days,
                executionData: executeOp(srcUserOpData),
                relayerType: RELAYER_TYPE.REVERT,
                errorMessage: bytes4(0),
                errorReason: "",
                account: accountToUse,
                root: bytes32(0),
                relayerGas: 600_000
            })
        );
        // the signatures don't match due to wrong decoding
        (,,,, bytes memory destinationChainSignature) =
            abi.decode(signatureData, (bool, uint48, bytes32, bytes32[], bytes));

        (,,,,, bytes memory sourceChainSignature) =
            abi.decode(signatureData, (bool, uint48, bytes32, bytes32[], bytes32[], bytes));

        assert(keccak256(destinationChainSignature) != keccak256(sourceChainSignature));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL CROSS-CHAIN TRANSFERS
    //////////////////////////////////////////////////////////////*/
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

        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(ethUserOpData, superNativePaymasterOnETH, 1e18); 

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
        uint256 expectedFee = ledger.previewFees(
            accountETH, yieldSource7540AddressETH_USDC, assetsOut, expectedSharesAvailableToConsume, 100
        );

        uint256 feeBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(TREASURY);

        executeOpsThroughPaymaster(redeemOpData, superNativePaymasterOnETH, 1e18); 

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingETH_USDC).balanceOf(TREASURY));

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

        function _redeem_From_OP() internal returns (uint256) {
        uint256 amountPerVault = 1e8 / 2;

        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);

        uint256 userBalanceSharesBefore = IERC20(yieldSource4626AddressOP_USDCe).balanceOf(accountOP);

        uint256 expectedAssetOutAmount = vaultInstance4626OP.previewRedeem(userBalanceSharesBefore);

        uint256 userBalanceUnderlyingBefore = IERC20(underlyingOP_USDCe).balanceOf(accountOP);

        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, REDEEM_4626_VAULT_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource4626AddressOP_USDCe,
            accountOP,
            userBalanceSharesBefore,
            false
        );
        opHooksData[1] = _createApproveHookData(underlyingOP_USDCe, SPOKE_POOL_V3_ADDRESSES[OP], amountPerVault, true);

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP, false);
        executeOpsThroughPaymaster(opUserOpData, superNativePaymasterOnOP, 1e18);

        assertEq(vaultInstance4626OP.balanceOf(accountOP), 0);
        assertEq(IERC20(underlyingOP_USDCe).balanceOf(accountOP), userBalanceUnderlyingBefore + expectedAssetOutAmount);

        return expectedAssetOutAmount;
    }

    function _redeem_From_OP_And_Bridge_Back_To_Base() internal {
        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);

        uint256 assetOutAmount = _redeem_From_OP();

        uint256 amountAfterSlippage = assetOutAmount - (assetOutAmount * 50 / 10_000);

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            // PREPARE BASE DATA
            address[] memory baseHooksAddresses = new address[](0);
            bytes[] memory baseHooksData = new bytes[](0);

            messageData = TargetExecutorMessage({
                hooksAddresses: baseHooksAddresses,
                hooksData: baseHooksData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: assetOutAmount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // OP IS SRC
        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);

        bytes memory odosCallData;
        odosCallData = _createMockOdosSwapHookData(
            underlyingOP_USDCe,
            assetOutAmount,
            address(this),
            underlyingOP_USDC,
            assetOutAmount,
            0,
            bytes(""),
            mockOdosRouters[OP],
            0,
            true
        );

        bytes memory approveOdosData;
        approveOdosData = _createApproveHookData(underlyingOP_USDCe, mockOdosRouters[OP], assetOutAmount, false);

        // PREPARE OP DATA
        address[] memory opHooksAddresses = new address[](4);
        opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, MOCK_SWAP_ODOS_HOOK_KEY);
        opHooksAddresses[2] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[3] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](4);
        opHooksData[0] = approveOdosData;
        opHooksData[1] = odosCallData;
        opHooksData[2] = _createApproveHookData(underlyingOP_USDC, SPOKE_POOL_V3_ADDRESSES[OP], assetOutAmount, true);
        opHooksData[3] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC,
            underlyingBase_USDC,
            assetOutAmount,
            amountAfterSlippage, // outputAmount = amountAfterSlippage so that mock AcrossHelper sends the correct
                // amount
            BASE,
            true,
            targetExecutorMessage
        );

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, opUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnOP)
        );
        opUserOpData.userOp.signature = signatureData;

        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(opUserOpData, superNativePaymasterOnOP, 1e18);
    
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: OP,
                dstChainId: BASE,
                warpTimestamp: WARP_START_TIME,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NO_HOOKS,
                errorMessage: bytes4(0),
                errorReason: "",
                account: accountBase,
                root: bytes32(0),
                relayerGas: 0
            })
        );

        vm.selectFork(FORKS[BASE]);

        uint256 user_Base_USDC_Balance_After = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        uint256 expected_Base_USDC_BalanceIncrease = amountAfterSlippage;

        assertApproxEqRel(
            user_Base_USDC_Balance_After, user_Base_USDC_Balance_Before + expected_Base_USDC_BalanceIncrease, 0.04e18
        );
    }

    function _warped_Redeem_From_OP() internal {
        vm.selectFork(FORKS[OP]);

        // Starting block was fixed on 1739809853 in deposit flow

        uint256 userBalanceSharesBefore = IERC20(yieldSource4626AddressOP_USDCe).balanceOf(accountOP);

        // Warp to increase yield by redemption
        vm.warp(block.timestamp + 150 days);

        uint256 expectedAssetOutAmount = vaultInstance4626OP.previewRedeem(userBalanceSharesBefore);

        uint256 userBalanceUnderlyingBefore = IERC20(underlyingOP_USDCe).balanceOf(accountOP);

        address[] memory opHooksAddresses = new address[](1);
        opHooksAddresses[0] = _getHookAddress(OP, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](1);
        opHooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSource4626AddressOP_USDCe,
            accountOP,
            userBalanceSharesBefore,
            false
        );

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP, false);

        // CHECK ACCOUNTING
        uint256 feeBalanceBefore = IERC20(underlyingOP_USDCe).balanceOf(TREASURY);

        uint256 userExpectedShareDelta = vaultInstance4626OP.convertToShares(expectedAssetOutAmount);

        ISuperLedger ledger = ISuperLedger(_getContract(OP, SUPER_LEDGER_KEY));
        uint256 expectedFee = ledger.previewFees(
            accountOP, yieldSource4626AddressOP_USDCe, expectedAssetOutAmount, userExpectedShareDelta, 100
        );

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingOutflow(
            accountOP, addressOracleOP, yieldSource4626AddressOP_USDCe, expectedAssetOutAmount, expectedFee
        );
        executeOpsThroughPaymaster(opUserOpData, superNativePaymasterOnOP, 1e18); 

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingOP_USDCe).balanceOf(TREASURY));

        assertEq(vaultInstance4626OP.balanceOf(accountOP), 0);
        assertEq(
            IERC20(underlyingOP_USDCe).balanceOf(accountOP),
            userBalanceUnderlyingBefore + expectedAssetOutAmount - expectedFee
        );
    }

    /// @notice Must be called before _sendFundsFromEthToBase
    function _sendFundsFromOpToBase() internal {
        uint256 intentAmount = 1e10;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP + 1 days);
        // Remove token from account for balance checks
        deal(underlyingBase_USDC, accountBase, 0);

        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        address accountToUse;
        {
            // PREPARE DST DATA
            address[] memory dstHooksAddresses = new address[](2);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](2);
            dstHooksData[0] =
                _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase_USDC, intentAmount / 2, false);
            dstHooksData[1] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource4626AddressBase_USDC,
                intentAmount / 2,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: intentAmount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // OP IS SRC1
        SELECT_FORK_AND_WARP(OP, CHAIN_10_TIMESTAMP + 1 days);

        // PREPARE SRC1 DATA
        address[] memory src1HooksAddresses = new address[](2);
        src1HooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        src1HooksAddresses[1] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory src1HooksData = new bytes[](2);
        src1HooksData[0] =
            _createApproveHookData(underlyingOP_USDC, SPOKE_POOL_V3_ADDRESSES[OP], intentAmount / 2, false);
        src1HooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC,
            underlyingBase_USDC,
            intentAmount / 2,
            intentAmount / 2,
            BASE,
            false,
            targetExecutorMessage
        );

        UserOpData memory src1UserOpData = _createUserOpData(src1HooksAddresses, src1HooksData, OP, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, src1UserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnOP)
        );
        src1UserOpData.userOp.signature = signatureData;

        console2.log("sending from op to base");
        // not enough balance is received
        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(src1UserOpData, superNativePaymasterOnOP, 1e18);
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: OP,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NOT_ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                account: accountBase,
                root: bytes32(0),
                relayerGas: 0
            })
        );
    }

    function _sendFundsFromEthToBase() internal {
        uint256 intentAmount = 1e10;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP + 2 days);

        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        // PREPARE DST DATA
        {
            address[] memory dstHooksAddresses = new address[](4);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, MOCK_SWAP_ODOS_HOOK_KEY);
            dstHooksAddresses[2] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[3] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](4);
            dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, mockOdosRouters[BASE], intentAmount, false);
            dstHooksData[1] = _createOdosSwapHookData(
                underlyingBase_USDC,
                intentAmount,
                address(this),
                underlyingBase_WETH,
                intentAmount,
                0,
                bytes(""),
                mockOdosRouters[BASE],
                0,
                true
            );
            dstHooksData[2] =
                _createApproveHookData(underlyingBase_WETH, yieldSource4626AddressBase_WETH, intentAmount, true);
            dstHooksData[3] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource4626AddressBase_WETH,
                intentAmount,
                true,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: intentAmount,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // ETH IS SRC1
        SELECT_FORK_AND_WARP(ETH, CHAIN_1_TIMESTAMP + 2 days);

        // PREPARE SRC1 DATA
        address[] memory src1HooksAddresses = new address[](2);
        src1HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        src1HooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory src1HooksData = new bytes[](2);
        src1HooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], intentAmount, false);
        src1HooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC,
            underlyingBase_USDC,
            intentAmount / 2,
            intentAmount / 2,
            BASE,
            false,
            targetExecutorMessage
        );

        UserOpData memory src1UserOpData = _createUserOpData(src1HooksAddresses, src1HooksData, ETH, true);
        console2.log("sending from eth to base");

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, src1UserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        src1UserOpData.userOp.signature = signatureData;

        ExecutionReturnData memory executionData = executeOpsThroughPaymaster(src1UserOpData, superNativePaymasterOnETH, 1e18);
        // enough balance is received
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: executionData,
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                account: accountBase,
                root: bytes32(0),
                relayerGas: 0
            })
        );

        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP + 2 days + 1 hours);

        uint256 sharesExpectedWETH;
        // `convertToShares` can fail due to the virtual timestamp
        try vaultInstance4626Base_WETH.convertToShares((intentAmount) - ((intentAmount) * 50 / 10_000)) returns (
            uint256 result
        ) {
            sharesExpectedWETH = result;
            uint256 sharesWETH = IERC4626(yieldSource4626AddressBase_WETH).balanceOf(accountBase);
            assertApproxEqRel(sharesWETH, sharesExpectedWETH, 0.02e18);
        } catch {
            uint256 sharesWETH = IERC4626(yieldSource4626AddressBase_WETH).balanceOf(accountBase);
            assertGt(sharesWETH, 0);
        }
    }

    function _sendDeBridgeOrder() internal {
        uint256 amountPerVault = 1e8;

        // Base is src
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        // PREPARE BASE DATA
        address[] memory baseHooksAddresses = new address[](2);
        baseHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        baseHooksAddresses[1] = _getHookAddress(BASE, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory baseHooksData = new bytes[](2);
        baseHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amountPerVault, false);

        uint256 msgValue = IDlnSource(DEBRIDGE_DLN_ADDRESSES[BASE]).globalFixedNativeFee();

        bytes memory innerExecutorPayload;
        TargetExecutorMessage memory messageData;
        address accountToUse;

        messageData = TargetExecutorMessage({
            hooksAddresses: new address[](0),
            hooksData: new bytes[](0),
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

        bytes memory debridgeData = _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false, //usePrevHookAmount
                value: msgValue, //value
                giveTokenAddress: underlyingBase_USDC, //giveTokenAddress
                giveAmount: amountPerVault, //giveAmount
                version: 1, //envelope.version
                fallbackAddress: address(0), //envelope.fallbackAddress
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
                allowedTakerDst: abi.encodePacked(accountETH), //allowedTakerDst
                allowedCancelBeneficiarySrc: abi.encodePacked(accountBase), //allowedCancelBeneficiarySrc
                affiliateFee: "", //affiliateFee
                referralCode: 0 //referralCode
             })
        );
        baseHooksData[1] = debridgeData;

        UserOpData memory baseUserOpData = _createUserOpData(baseHooksAddresses, baseHooksData, BASE, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, baseUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        baseUserOpData.userOp.signature = signatureData;

        executeOpsThroughPaymaster(baseUserOpData, superNativePaymasterOnBase, 1e18); 

        // =============== MOCK THE ORDER REGISTRATION ON DESTINATION CHAIN ===============
        // In real DeBridge, orders only get registered on destination when fulfilled
        // But for cancellation to work, we need to simulate an order that exists but wasn't fulfilled
        // This represents a failed fulfillment attempt that registered the order but didn't complete

        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // The cancel hook now correctly includes giveChainId = BASE in cancel data
        // We need to configure BASE chain as EVM in the DlnDestination contract
        // Since setDlnSourceAddress is not in the public interface, we'll use storage manipulation
        vm.store(
            DEBRIDGE_DLN_ADDRESSES[ETH],
            keccak256(abi.encode(uint256(BASE), uint256(2))), // chainEngines mapping at slot 2, key = BASE
            bytes32(uint256(1)) // DlnOrderLib.ChainEngine.EVM = 1
        );

        // Create order ID that matches exactly what the cancel hook will generate
        // The hook creates an order with specific structure - we need to calculate the same ID
        bytes32 orderId;
        {
            // Calculate order ID using the EXACT same algorithm as DlnOrderLib.getOrderId
            // This follows the exact encoding format from DlnOrderLib.encodeOrder
            bytes memory encoded;

            // Reconstruct the exact order parameters that the cancel hook creates
            uint64 makerOrderNonce = 123_456;
            bytes memory makerSrc = abi.encodePacked(accountBase);

            // Step 1: makerOrderNonce (8 bytes) + makerSrc.length (1 byte) + makerSrc
            encoded = abi.encodePacked(makerOrderNonce, uint8(makerSrc.length), makerSrc);
        }

        {
            // Continue with remaining order fields
            bytes memory giveTokenAddress = abi.encodePacked(underlyingBase_USDC);
            uint256 giveAmount = amountPerVault;
            uint256 takeChainId = ETH;
            bytes memory takeTokenAddress = abi.encodePacked(underlyingETH_USDC);
            uint256 takeAmount = amountPerVault;

            // Get the existing encoded data and continue building
            bytes memory encoded = abi.encodePacked(
                uint64(123_456), // makerOrderNonce
                uint8(20), // makerSrc.length (20 bytes for address)
                accountBase, // makerSrc
                uint256(BASE), // giveChainId - now correctly uses BASE
                uint8(giveTokenAddress.length),
                giveTokenAddress,
                giveAmount,
                takeChainId,
                uint8(takeTokenAddress.length),
                takeTokenAddress,
                takeAmount
            );

            // Add receiver and authority fields
            bytes memory receiverDst = abi.encodePacked(address(debridgeAdapterOnETH));
            bytes memory orderAuthorityAddressDst = abi.encodePacked(accountETH);
            bytes memory allowedCancelBeneficiarySrc = abi.encodePacked(accountETH); // ✅ Must match the account that
                // will call sendEvmOrderCancel

            encoded = abi.encodePacked(
                encoded,
                uint8(receiverDst.length),
                receiverDst,
                uint8(0), // givePatchAuthoritySrc.length (empty)
                uint8(orderAuthorityAddressDst.length),
                orderAuthorityAddressDst,
                uint8(0), // allowedTakerDst.length (empty)
                uint8(allowedCancelBeneficiarySrc.length),
                allowedCancelBeneficiarySrc,
                false // externalCall.length > 0 (false since empty)
            );

            // Finally calculate the order ID
            orderId = keccak256(encoded);
        }

        // Manually insert the order into takeOrders mapping with NotSet status
        // This simulates a failed fulfillment that registered the order but didn't complete
        vm.store(
            DEBRIDGE_DLN_ADDRESSES[ETH],
            keccak256(abi.encode(orderId, uint256(1))), // takeOrders mapping at slot 1
            bytes32(uint256(0)) // OrderTakeStatus.NotSet = 0
        );

        // Store the giveChainId (for validation in cancellation) - use BASE as that's what cancel hook now uses
        vm.store(
            DEBRIDGE_DLN_ADDRESSES[ETH],
            bytes32(uint256(keccak256(abi.encode(orderId, uint256(1)))) + 2), // next slot for giveChainId
            bytes32(uint256(BASE)) // giveChainId = BASE (what cancel hook now uses)
        );
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL LOGIC HELPERS
    //////////////////////////////////////////////////////////////*/
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
            ledger.previewFees(accountETH, yieldSource7540AddressETH_USDC, userExpectedAssets, userShares, 100);

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
            ledger.previewFees(accountETH, yieldSource7540AddressETH_USDC, userExpectedAssets, redeemAmount, 100);

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingOutflow(
            accountETH, addressOracleETH, yieldSource7540AddressETH_USDC, userExpectedAssets, expectedFee
        );
        executeOp(redeemOpData);

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingETH_USDC).balanceOf(TREASURY));

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
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

    function _doEIP7702(address account, address accImplementation) internal {
        if (accImplementation.code.length == 0) revert("NO ACCOUNT");
        vm.etch(account, abi.encodePacked(hex'ef0100', bytes20(address(accImplementation))));
        
    }
}
