// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger, ISuperLedgerData } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { AcrossV3Adapter } from "../../src/core/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../../src/core/adapters/DebridgeAdapter.sol";
import { MockTargetExecutor } from "../mocks/MockTargetExecutor.sol";
import { MockAcrossHook } from "../mocks/MockAcrossHook.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";

// Vault Interfaces
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IDlnSource } from "../../src/vendor/bridges/debridge/IDlnSource.sol";

import { RestrictionManagerLike } from "../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../mocks/centrifuge/ITranch.sol";
import { IRoot } from "../mocks/centrifuge/IRoot.sol";
import { ISuperDestinationExecutor } from "../../src/core/interfaces/ISuperDestinationExecutor.sol";
import { IERC7484 } from "../../src/vendor/nexus/IERC7484.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { BootstrapConfig, INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";

contract CrosschainTests is BaseTest {
    IERC7540 public vaultInstance7540ETH;
    IERC4626 public vaultInstance4626OP;

    address public underlyingETH_USDC;
    address public underlyingOP_USDC;
    address public underlyingOP_USDCe;

    address public underlyingBase_USDC;
    address public underlyingBase_WETH;

    address public addressOracleOP;
    address public addressOracleETH;
    address public addressOracleBase;

    address public yieldSource7540AddressETH_USDC;
    address public yieldSource4626AddressOP_USDCe;

    address public accountBase;
    address public accountETH;
    address public accountOP;

    address public rootManager;

    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;

    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;

    AcrossV3Adapter public acrossV3AdapterOnBase;
    AcrossV3Adapter public acrossV3AdapterOnETH;
    AcrossV3Adapter public acrossV3AdapterOnOP;

    DebridgeAdapter public debridgeAdapterOnBase;
    DebridgeAdapter public debridgeAdapterOnETH;
    DebridgeAdapter public debridgeAdapterOnOP;

    ISuperDestinationExecutor public superTargetExecutorOnBase;
    ISuperDestinationExecutor public superTargetExecutorOnETH;
    ISuperDestinationExecutor public superTargetExecutorOnOP;

    IValidator public validatorOnBase;
    IValidator public validatorOnETH;
    IValidator public validatorOnOP;

    IValidator public sourceValidatorOnBase;
    IValidator public sourceValidatorOnETH;
    IValidator public sourceValidatorOnOP;

    INexusBootstrap nexusBootstrap;

    MockAcrossHook public mockAcrossHook;

    address public yieldSourceMorphoUsdcAddressEth;
    IERC4626 public vaultInstanceMorphoEth;

    address public yieldSourceMorphoUsdcAddressBase;
    IERC4626 public vaultInstanceMorphoBase;

    IRoot public root;
    IPoolManager public poolManager;

    ISuperLedger public superLedgerETH;
    ISuperLedger public superLedgerOP;

    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleOP;

    RestrictionManagerLike public restrictionManager;
    IInvestmentManager public investmentManager;

    MockTargetExecutor public mockTargetExecutorOnETH;

    IERC4626 public vaultInstance4626Base_USDC;
    IERC4626 public vaultInstance4626Base_WETH;
    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;

    uint256 public balance_Base_USDC_Before;

    uint256 public constant WARP_START_TIME = 1_740_559_708;

    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;

    string public constant YIELD_SOURCE_4626_BASE_USDC_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_BASE_WETH_KEY = "ERC4626_BASE_WETH";

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "Centrifuge_7540_ETH_USDC";
    string public constant YIELD_SOURCE_ORACLE_7540_KEY = "YieldSourceOracle_7540";

    string public constant YIELD_SOURCE_4626_OP_USDCe_KEY = "YieldSource_4626_OP_USDCe";
    string public constant YIELD_SOURCE_ORACLE_4626_KEY = "YieldSourceOracle_4626";

    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    uint256 public CHAIN_1_TIMESTAMP;
    uint256 public CHAIN_10_TIMESTAMP;
    uint256 public CHAIN_8453_TIMESTAMP;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        CHAIN_1_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[OP]);
        CHAIN_10_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[BASE]);
        CHAIN_8453_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[ETH]);

        // Set up the underlying tokens
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];
        vm.label(underlyingOP_USDC, "underlyingOP_USDC");
        underlyingOP_USDCe = existingUnderlyingTokens[OP][USDCe_KEY];
        vm.label(underlyingOP_USDCe, "underlyingOP_USDCe");

        // Set up the 7540 yield source
        yieldSource7540AddressETH_USDC =
            realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSource7540AddressETH_USDC, YIELD_SOURCE_7540_ETH_USDC_KEY);

        vaultInstance7540ETH = IERC7540(yieldSource7540AddressETH_USDC);

        addressOracleETH = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleETH, YIELD_SOURCE_ORACLE_7540_KEY);
        yieldSourceOracleETH = IYieldSourceOracle(addressOracleETH);

        // Set up the 4626 yield source
        yieldSource4626AddressOP_USDCe = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY];

        vaultInstance4626OP = IERC4626(yieldSource4626AddressOP_USDCe);
        vm.label(yieldSource4626AddressOP_USDCe, YIELD_SOURCE_4626_OP_USDCe_KEY);

        addressOracleOP = _getContract(OP, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleOP, YIELD_SOURCE_ORACLE_4626_KEY);
        yieldSourceOracleOP = IYieldSourceOracle(addressOracleOP);

        // Set up the accounts
        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;
        accountOP = accountInstances[OP].account;

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];
        instanceOnOP = accountInstances[OP];

        // Set up the super executors
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));

        // Set up the super target executors
        superTargetExecutorOnBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));

        acrossV3AdapterOnBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnOP = AcrossV3Adapter(_getContract(OP, ACROSS_V3_ADAPTER_KEY));

        debridgeAdapterOnBase = DebridgeAdapter(_getContract(BASE, DEBRIDGE_ADAPTER_KEY));
        debridgeAdapterOnETH = DebridgeAdapter(_getContract(ETH, DEBRIDGE_ADAPTER_KEY));
        debridgeAdapterOnOP = DebridgeAdapter(_getContract(OP, DEBRIDGE_ADAPTER_KEY));

        // Set up the destination validators
        validatorOnBase = IValidator(_getContract(BASE, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        validatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));

        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnOP = IValidator(_getContract(OP, SUPER_MERKLE_VALIDATOR_KEY));

        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        superLedgerOP = ISuperLedger(_getContract(OP, SUPER_LEDGER_KEY));

        mockTargetExecutorOnETH = MockTargetExecutor(_getContract(ETH, MOCK_TARGET_EXECUTOR_KEY));
        vm.label(address(mockTargetExecutorOnETH), "MockTargetExecutorOnETH");

        nexusBootstrap = INexusBootstrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");

        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];

        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);

        yieldSource4626AddressBase_WETH = realVaultAddresses[BASE][ERC4626_VAULT_KEY][AAVE_BASE_WETH][WETH_KEY];

        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);

        yieldSourceMorphoUsdcAddressEth = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoEth = IERC4626(yieldSourceMorphoUsdcAddressEth);
        vm.label(yieldSourceMorphoUsdcAddressEth, "YIELD_SOURCE_MORPHO_USDC_ETH");

        yieldSourceMorphoUsdcAddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSourceMorphoUsdcAddressBase);
        vm.label(yieldSourceMorphoUsdcAddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        vm.selectFork(FORKS[ETH]);

        address share = IERC7540(yieldSource7540AddressETH_USDC).share();

        ITranche(share).hook();

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

        rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        assetId = poolManager.assetToId(underlyingETH_USDC);
        assertEq(assetId, uint128(242_333_941_209_166_991_950_178_742_833_476_896_417));

        vm.selectFork(FORKS[OP]);
        deal(underlyingOP_USDC, mockOdosRouters[OP], 1e18);

        (validatorSigner, validatorSignerPrivateKey) = makeAddrAndKey("The signer");
        vm.label(validatorSigner, "The signer");

        vm.selectFork(FORKS[BASE]);
        deal(underlyingBase_WETH, mockOdosRouters[BASE], 1e12);
    }

    /*//////////////////////////////////////////////////////////////
                          ACCOUNT CREATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Bridge_To_ETH_And_Create_Nexus_Account() public {
        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        mockTargetExecutorOnETH.setNexusFactory(CHAIN_1_NEXUS_FACTORY);

        // PREPARE ETH DATA
        // create validators
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: address(validatorOnETH), data: abi.encode(this) });
        // create executors
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: address(superExecutorOnETH), data: "" });
        // create hooks
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });
        // create fallbacks
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);
        address[] memory attesters = new address[](1);
        attesters[0] = address(MANAGER);
        uint8 threshold = 1;
        MockRegistry nexusRegistry = new MockRegistry();
        bytes memory initData = nexusBootstrap.getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(nexusRegistry), attesters, threshold
        );
        bytes memory destinationMessage = abi.encode(initData, bytes32(keccak256("SomeSaltForAccountCreation")));

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        mockAcrossHook =
            new MockAcrossHook(SPOKE_POOL_V3_ADDRESSES[BASE], _getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        vm.label(address(mockAcrossHook), "MockAcrossHook");

        deal(underlyingBase_USDC, accountBase, 1e18);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = address(mockAcrossHook);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], 1e18, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndCreateAccount(
            underlyingBase_USDC, underlyingETH_USDC, 1e18, 1e18, ETH, false, destinationMessage
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });
        UserOpData memory srcUserOpData = _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));

        // EXECUTE ETH
        _processAcrossV3MessageWithoutDestinationAccount(BASE, ETH, WARP_START_TIME + 30 days, executeOp(srcUserOpData));

        // check account
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        address createdAccount = mockTargetExecutorOnETH.nexusCreatedAccount();
        uint256 tokenBalanceOfCreatedAccount = IERC20(underlyingETH_USDC).balanceOf(createdAccount);
        assertEq(tokenBalanceOfCreatedAccount, 1e18);

        assertEq(
            IERC7579Account(createdAccount).isModuleInstalled(MODULE_TYPE_EXECUTOR, address(superExecutorOnETH), ""),
            true
        );
        assertEq(
            IERC7579Account(createdAccount).isModuleInstalled(MODULE_TYPE_VALIDATOR, address(validatorOnETH), ""), true
        );
        assertEq(
            IERC7579Account(createdAccount).isModuleInstalled(
                MODULE_TYPE_EXECUTOR, address(mockTargetExecutorOnETH), ""
            ),
            false
        );
    }

    /*//////////////////////////////////////////////////////////////
                          FULL FLOW TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ETH_Bridge_With_Debridge_And_Deposit() public executeWithoutHookRestrictions {
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
                bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressETH_USDC, amountPerVault, true
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: eth7540HooksAddresses,
                hooksData: eth7540HooksData,
                validator: address(validatorOnETH),
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE BASE
        _processDebridgeDlnMessage(BASE, ETH, executeOp(srcUserOpData));

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        _execute7540DepositFlow(amountPerVault);

        vm.selectFork(FORKS[ETH]);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }

    function test_ETH_Bridge_Deposit_Redeem_Bridge_Back_Flow() public executeWithoutHookRestrictions {
        test_Bridge_To_ETH_And_Deposit();
        _redeem_From_ETH_And_Bridge_Back_To_Base(true);
    }

    function test_ETH_Bridge_Deposit_Partial_Redeem_Bridge_Flow() public executeWithoutHookRestrictions {
        test_Bridge_To_ETH_And_Deposit();
        _redeem_From_ETH_And_Bridge_Back_To_Base(false);
    }

    function test_ETH_Bridge_Deposit_Redeem_Flow_With_Warping() public {
        test_Bridge_To_ETH_And_Deposit();
        _warped_Redeem_From_ETH_And_Bridge_Back_To_Base();
    }

    function test_OP_Bridge_Deposit_Redeem_Flow() public executeWithoutHookRestrictions {
        test_bridge_To_OP_And_Deposit();
        _redeem_From_OP();
    }

    function test_OP_Bridge_Deposit_Redeem_Bridge_Back_Flow() public executeWithoutHookRestrictions {
        test_bridge_To_OP_And_Deposit();
        _redeem_From_OP_And_Bridge_Back_To_Base();
    }

    function test_OP_Bridge_Deposit_Redeem_Flow_With_Warping() public {
        test_bridge_To_OP_And_Deposit();
        _warped_Redeem_From_OP();
    }

    function test_CrossChainDepositWithSlippage() public {
        SELECT_FORK_AND_WARP(ETH, CHAIN_1_TIMESTAMP + 1 days);
        _sendFundsFromOpToBase();
        _sendFundsFromEthToBase();
    }

    /*//////////////////////////////////////////////////////////////
                          INDIVIDUAL TESTS
    //////////////////////////////////////////////////////////////*/
    function test_CreateNexusAccount_Through_SuperDestinationExecutor() public {
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
                validator: address(validatorOnETH),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE BASE
        _processAcrossV3Message(
            BASE, ETH, WARP_START_TIME + 30 days, executeOp(srcUserOpData), RELAYER_TYPE.NO_HOOKS, accountToUse
        );
    }

    function test_RevertFrom_AcrossTargetExecutor() public {
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
                bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(0), 0, false
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: eth7540HooksAddresses,
                hooksData: eth7540HooksData,
                validator: address(validatorOnETH),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        _processAcrossV3Message(
            BASE, ETH, WARP_START_TIME + 30 days, executeOp(srcUserOpData), RELAYER_TYPE.LOW_LEVEL_FAILED, accountToUse
        );
    }

    function test_Bridge_To_ETH_And_Deposit_With_AcrossTargetExecutor() public {
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
                bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressETH_USDC, amountPerVault / 2, true
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: eth7540HooksAddresses,
                hooksData: eth7540HooksData,
                validator: address(validatorOnETH),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        _processAcrossV3Message(
            BASE, ETH, WARP_START_TIME + 30 days, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountToUse
        );

        // DEPOSIT
        _fulfill7540DepositRequest(amountPerVault / 2, accountToUse);
        vm.selectFork(FORKS[ETH]);
        uint256 maxDeposit = vaultInstance7540ETH.maxDeposit(accountToUse);
        assertEq(maxDeposit, amountPerVault / 2 - 1, "Max deposit is not as expected");
    }

    function test_Bridge_To_ETH_And_Deposit() public {
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
                bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressETH_USDC, amountPerVault, true
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: eth7540HooksAddresses,
                hooksData: eth7540HooksData,
                validator: address(validatorOnETH),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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
        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE ETH
        _processAcrossV3Message(
            BASE, ETH, WARP_START_TIME + 30 days, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountETH
        );

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        _execute7540DepositFlow(amountPerVault);

        vm.selectFork(FORKS[ETH]);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }

    function _redeem_From_ETH_And_Bridge_Back_To_Base(bool isFullRedeem) internal {
        uint256 amountPerVault = 1e8 / 2;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        TargetExecutorMessage memory messageData = TargetExecutorMessage({
            hooksAddresses: new address[](0),
            hooksData: new bytes[](0),
            validator: address(validatorOnBase),
            signer: validatorSigners[BASE],
            signerPrivateKey: validatorSignerPrivateKeys[BASE],
            targetAdapter: address(acrossV3AdapterOnBase),
            targetExecutor: address(superTargetExecutorOnBase),
            nexusFactory: CHAIN_8453_NEXUS_FACTORY,
            nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
            chainId: uint64(BASE),
            amount: 0,
            account: accountBase,
            tokenSent: underlyingBase_USDC
        });
        (bytes memory targetExecutorMessage, address accountToUse) = _createTargetExecutorMessage(messageData);

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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, ethUserOpData.userOpHash, accountToUse);
        ethUserOpData.userOp.signature = signatureData;

        _processAcrossV3Message(
            ETH, BASE, WARP_START_TIME + 10 seconds, executeOp(ethUserOpData), RELAYER_TYPE.NO_HOOKS, accountBase
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

    // OP TESTS
    function test_bridge_To_OP_And_Deposit() public {
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
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSource4626AddressOP_USDCe,
                amountPerVault,
                true,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: opHooksAddresses,
                hooksData: opHooksData,
                validator: address(validatorOnOP),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData =
            _createMerkleRootAndSignature(messageData, srcUserOpDataOP.userOpHash, accountToUse);
        srcUserOpDataOP.userOp.signature = signatureData;

        // EXECUTE OP
        _processAcrossV3Message(
            BASE, OP, WARP_START_TIME, executeOp(srcUserOpDataOP), RELAYER_TYPE.ENOUGH_BALANCE, accountOP
        );

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), userBalanceBaseUSDCBefore - amountPerVault, "A");

        vm.selectFork(FORKS[OP]);
        assertEq(vaultInstance4626OP.balanceOf(accountOP), previewDepositAmountOP, "B");
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
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceMorphoUsdcAddressBase,
                previewRedeemAmount,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
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
        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        _processAcrossV3Message(
            ETH, BASE, block.timestamp, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase
        );
    }

    function test_BridgeThroughDifferentAdapters() public {
        uint256 amount = 1e8;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP);

        address accountToUse;
        TargetExecutorMessage memory messageData;

        bytes memory targetAcrossExecutorMessage;
        bytes memory targetDebridgeExecutorMessage;
        // create across data
        {
            address[] memory dstHooksAddresses = new address[](1);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](1);
            dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, 123, false);

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: amount,
                account: address(0),
                tokenSent: underlyingBase_USDC
            });

            (targetAcrossExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
        }

        vm.deal(accountToUse, 0);
        assertEq(accountToUse.balance, 0);

        // create debridgeData
        {
            address[] memory dstHooksAddresses = new address[](1);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](1);
            dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, 123, false);

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(debridgeAdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: amount,
                account: accountToUse,
                tokenSent: underlyingBase_USDC
            });

            (targetDebridgeExecutorMessage,) = _createTargetExecutorMessage(messageData);
        }

        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, CHAIN_1_TIMESTAMP + 1 days);

        address[] memory srcHooksAddresses = new address[](6);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[4] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);
        srcHooksAddresses[5] = _getHookAddress(ETH, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](6);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceMorphoUsdcAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceMorphoUsdcAddressEth,
            amount,
            false,
            address(0),
            0
        );
        srcHooksData[2] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amount / 2, true);
        srcHooksData[3] = _createApproveHookData(underlyingETH_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amount / 2, true);

        srcHooksData[4] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            amount / 2,
            amount / 2,
            BASE,
            true,
            targetAcrossExecutorMessage
        );

        bytes memory debridgeData = _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false, //usePrevHookAmount
                value: IDlnSource(DEBRIDGE_DLN_ADDRESSES[BASE]).globalFixedNativeFee(), //value
                giveTokenAddress: existingUnderlyingTokens[ETH][USDC_KEY], //giveTokenAddress
                giveAmount: amount / 2, //giveAmount
                version: 1, //envelope.version
                fallbackAddress: accountBase, //envelope.fallbackAddress
                executorAddress: address(debridgeAdapterOnBase), //envelope.executorAddress
                executionFee: uint160(0), //envelope.executionFee
                allowDelayedExecution: false, //envelope.allowDelayedExecution
                requireSuccessfulExecution: true, //envelope.requireSuccessfulExecution
                payload: targetDebridgeExecutorMessage, //envelope.payload
                takeTokenAddress: existingUnderlyingTokens[BASE][USDC_KEY], //takeTokenAddress
                takeAmount: amount / 2, //takeAmount
                takeChainId: BASE, //takeChainId
                // receiverDst must be the Debridge Adapter on the destination chain
                receiverDst: address(debridgeAdapterOnBase),
                givePatchAuthoritySrc: address(0), //givePatchAuthoritySrc
                orderAuthorityAddressDst: abi.encodePacked(accountBase), //orderAuthorityAddressDst
                allowedTakerDst: "", //allowedTakerDst
                allowedCancelBeneficiarySrc: "", //allowedCancelBeneficiarySrc
                affiliateFee: "", //affiliateFee
                referralCode: 0 //referralCode
             })
        );
        srcHooksData[5] = debridgeData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(entry), address(sourceValidatorOnETH)
        );
        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;
        _processAcrossV3Message(
            ETH, BASE, block.timestamp, executeOp(srcUserOpData), RELAYER_TYPE.NOT_ENOUGH_BALANCE, accountToUse
        );
        srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(entry), address(sourceValidatorOnETH)
        );
        signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;
        _processDebridgeDlnMessage(ETH, BASE, executeOp(srcUserOpData));

        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP + 2 days);
        uint256 allowance =
            IERC20(underlyingBase_USDC).allowance(accountToUse, address(yieldSourceMorphoUsdcAddressBase));
        assertEq(allowance, 123);
    }

    function test_InvalidDestinationFLow() public {
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
            address[] memory dstHooksAddresses = new address[](1);
            dstHooksAddresses[0] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](1);
            dstHooksData[0] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceMorphoUsdcAddressBase,
                previewRedeemAmount,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
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
        bytes memory signatureData = _createMerkleRootAndSignature(messageData, srcUserOpData.userOpHash, accountToUse);
        srcUserOpData.userOp.signature = signatureData;

        _processAcrossV3Message(ETH, BASE, block.timestamp, executeOp(srcUserOpData), RELAYER_TYPE.FAILED, accountBase);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressOP_USDCe,
            accountOP,
            userBalanceSharesBefore,
            false
        );
        opHooksData[1] = _createApproveHookData(underlyingOP_USDCe, SPOKE_POOL_V3_ADDRESSES[OP], amountPerVault, true);

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP, false);

        executeOp(opUserOpData);

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
                validator: address(validatorOnBase),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, opUserOpData.userOpHash, accountToUse);
        opUserOpData.userOp.signature = signatureData;

        _processAcrossV3Message(OP, BASE, WARP_START_TIME, executeOp(opUserOpData), RELAYER_TYPE.NO_HOOKS, accountBase);

        vm.selectFork(FORKS[BASE]);

        uint256 user_Base_USDC_Balance_After = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        uint256 expected_Base_USDC_BalanceIncrease = amountAfterSlippage;

        assertApproxEqRel(user_Base_USDC_Balance_After, user_Base_USDC_Balance_Before + expected_Base_USDC_BalanceIncrease, 0.04e18);
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
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
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
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressETH_USDC, userExpectedAssets, false
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
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressETH_USDC, userExpectedAssets, false
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
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressETH_USDC, userExpectedAssets, false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH, false);

        ISuperLedger ledger = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        uint256 expectedFee = ledger.previewFees(
            accountETH, yieldSource7540AddressETH_USDC, assetsOut, expectedSharesAvailableToConsume, 100
        );

        uint256 feeBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(TREASURY);

        executeOp(redeemOpData);

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingETH_USDC).balanceOf(TREASURY));

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    // OP WARPED REDEEM
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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
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
        executeOp(opUserOpData);

        _assertFeeDerivation(expectedFee, feeBalanceBefore, IERC20(underlyingOP_USDCe).balanceOf(TREASURY));

        assertEq(vaultInstance4626OP.balanceOf(accountOP), 0);
        assertEq(
            IERC20(underlyingOP_USDCe).balanceOf(accountOP),
            userBalanceUnderlyingBefore + expectedAssetOutAmount - expectedFee
        );
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
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSource4626AddressBase_USDC,
                intentAmount / 2,
                false,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, src1UserOpData.userOpHash, accountToUse);
        src1UserOpData.userOp.signature = signatureData;

        console2.log("sending from op to base");
        // not enough balance is received
        _processAcrossV3Message(
            OP, BASE, block.timestamp, executeOp(src1UserOpData), RELAYER_TYPE.NOT_ENOUGH_BALANCE, accountBase
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
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSource4626AddressBase_WETH,
                intentAmount,
                true,
                address(0),
                0
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHooksAddresses,
                hooksData: dstHooksData,
                validator: address(validatorOnBase),
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

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData);
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

        bytes memory signatureData = _createMerkleRootAndSignature(messageData, src1UserOpData.userOpHash, accountToUse);
        src1UserOpData.userOp.signature = signatureData;

        // enough balance is received
        _processAcrossV3Message(
            ETH, BASE, block.timestamp, executeOp(src1UserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase
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
}
