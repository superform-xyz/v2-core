// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IDlnSource } from "../../src/vendor/bridges/debridge/IDlnSource.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import "modulekit/test/RhinestoneModuleKit.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { BytesLib } from "../../src/vendor/BytesLib.sol";
import { ModeLib, ModeCode } from "modulekit/accounts/common/lib/ModeLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { IPermit2 } from "../../src/vendor/uniswap/permit2/IPermit2.sol";
import { IPermit2Batch } from "../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperLedger, ISuperLedgerData } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperDestinationExecutor } from "../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../src/interfaces/ISuperValidator.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutorBase } from "../../src/executors/SuperExecutorBase.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { AcrossV3Adapter } from "../../src/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../../src/adapters/DebridgeAdapter.sol";
import { SuperValidatorBase } from "../../src/validators/SuperValidatorBase.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { BaseLedger } from "../../src/accounting/BaseLedger.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { SwapOdosV2Hook } from "../../src/hooks/swappers/odos/SwapOdosV2Hook.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// -- mock Odos Router that checks output min
import { MockOdosSwap } from "../mocks/MockOdosSwap.sol";

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

    IAllowanceTransfer public permit2;
    IPermit2Batch public permit2Batch;
    bytes32 public permit2DomainSeparator;

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
    IERC4626 public vaultInstanceEth;
    IERC4626 public vaultInstanceMorphoBase;
    address public yieldSource4626AddressOP_USDCe;
    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;
    address public yieldSourceUsdcAddressEth;
    address public yieldSourceMorphoUsdcAddressBase;
    address public yieldSourceSparkUsdcAddressBase;

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

    bytes32 constant PERMIT2_BATCH_TYPE_HASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)"
        "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );
    bytes32 constant PERMIT2_DETAILS_TYPE_HASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

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

    // -- mock Odos Router that checks output min
    MockOdosSwap public mockOdosSwapOutputMin;

    // STACK-TOO-DEEP structs
    /// @notice Struct to hold test parameters for test_Bridge_Deposit4626_UsedRoot_Because_Frontrunning test to avoid
    /// stack too deep
    struct BridgeDeposit4626UsedRootParams {
        uint256 amount;
        bytes targetExecutorMessage;
        address accountToUse;
        ISuperExecutor.ExecutorEntry entry;
        UserOpData srcUserOpData;
        bytes signatureData;
    }

    struct BridgeTestHooksData {
        address[] srcHooksAddresses;
        bytes[] srcHooksData;
        address[] dstHooksAddresses;
        bytes[] dstHooksData;
    }
    // for test `test_CrossChain_SignatureReplay_Prevention`

    struct SignatureReplayTestData {
        uint256 amountPerVault;
        bytes targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage messageData;
        address[] srcHooksAddresses;
        bytes[] srcHooksData;
        bytes signatureData;
    }

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
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
        underlyingOP_USDCe = existingUnderlyingTokens[OP][USDCE_KEY];
        vm.label(underlyingOP_USDCe, "underlyingOP_USDCe");

        yieldSource7540AddressETH_USDC =
            realVaultAddresses[ETH][ERC7540_FULLY_ASYNC_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSource7540AddressETH_USDC, YIELD_SOURCE_7540_ETH_USDC_KEY);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressETH_USDC);

        yieldSource4626AddressOP_USDCe = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCE_KEY];
        vaultInstance4626OP = IERC4626(yieldSource4626AddressOP_USDCe);
        vm.label(yieldSource4626AddressOP_USDCe, YIELD_SOURCE_4626_OP_USDCe_KEY);

        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);

        yieldSource4626AddressBase_WETH = realVaultAddresses[BASE][ERC4626_VAULT_KEY][AAVE_BASE_WETH][WETH_KEY];
        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);

        yieldSourceUsdcAddressEth = realVaultAddresses[ETH][ERC4626_VAULT_KEY][EULER_VAULT_KEY][USDC_KEY];
        vaultInstanceEth = IERC4626(yieldSourceUsdcAddressEth);
        vm.label(yieldSourceUsdcAddressEth, "YIELD_SOURCE_EULER_USDC_ETH");

        yieldSourceMorphoUsdcAddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSourceMorphoUsdcAddressBase);
        vm.label(yieldSourceMorphoUsdcAddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        yieldSourceSparkUsdcAddressBase = realVaultAddresses[BASE][ERC4626_VAULT_KEY][SPARK_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSourceSparkUsdcAddressBase, "YIELD_SOURCE_SPARK_USDC_BASE");

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

        // -- mock Odos Router that checks output min
        mockOdosSwapOutputMin = new MockOdosSwap();

        // CUSTOM DEAL SETUP
        vm.selectFork(FORKS[OP]);
        deal(underlyingOP_USDC, mockOdosRouters[OP], 1e18);

        vm.selectFork(FORKS[BASE]);
        deal(underlyingBase_WETH, mockOdosRouters[BASE], 1e12);
    }

    receive() external payable { }
    /*//////////////////////////////////////////////////////////////
                          TESTS
    //////////////////////////////////////////////////////////////*/
    // --- THROUGH PAYMASTER ---
    //  >>>> ACCOUNT MUTABILITY TESTS

    function test_HaveAnAccount_Uninstall_MidExecutionUnistallUnrelatedModule() public {
        // create an account using cross chain flow
        // - use NexusFactory and NexustBootstrap to create a real account
        address accountCreated = _createAccountCrossChainFlow();

        uint256 usageTimestamp = WARP_START_TIME + 100 days;
        SELECT_FORK_AND_WARP(ETH, usageTimestamp);
        assertGt(accountCreated.code.length, 0);
        deal(accountCreated, 10 ether);

        // check installed modules
        // -- check executor
        // -- check destination validator on chain
        // -- check source validator on
        assertTrue(
            SuperExecutorBase(address(superExecutorOnETH)).isInitialized(accountCreated), "super executor not installed"
        );
        assertTrue(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor not installed"
        );
        assertTrue(
            SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(accountCreated),
            "super merkle validator not installed"
        );
        assertTrue(
            SuperValidatorBase(address(destinationValidatorOnETH)).isInitialized(accountCreated),
            "super destinatioin validator not installed"
        );

        // perform defi operations
        // -- 4626 deposit
        uint256 obtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, true);
        assertGt(obtainedShares, 0, "no shares were obtained");
        obtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, false);
        assertGt(obtainedShares, 0, "no shares were obtained");

        _executeRedeemFromAccount(accountCreated, obtainedShares, 1000e6, false);

        // perform deposit with uninstall during execution
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, 1000e6, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            1000e6,
            false,
            address(0),
            0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        bytes memory uninstallData = abi.encode(address(superExecutorOnETH), bytes(""));
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: accountCreated,
            value: 0,
            callData: abi.encodeCall(
                IERC7579Account.uninstallModule, (MODULE_TYPE_EXECUTOR, address(superTargetExecutorOnETH), uninstallData)
            )
        });
        executions[1] = Execution({
            target: address(superExecutorOnETH),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)))
        });

        PackedUserOperation memory userOp = _createPackedUserOperation(
            accountCreated,
            _prepareNonceWithValidator(accountCreated, address(sourceValidatorOnETH)),
            _prepareExecutionCalldata(executions)
        );

        _signAndSendUserOp(userOp, address(sourceValidatorOnETH), accountCreated, true, false);

        // assert obtained shares
        obtainedShares = IERC20(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
        assertGt(obtainedShares, 0, "no final shares were obtained");
    }

    function test_HaveAnAccount_Uninstall_MidExecutionUnistallValidatorModule_ValidatorReverts() public {
        // create an account using cross chain flow
        // - use NexusFactory and NexustBootstrap to create a real account
        address accountCreated = _createAccountCrossChainFlow();

        uint256 usageTimestamp = WARP_START_TIME + 100 days;
        SELECT_FORK_AND_WARP(ETH, usageTimestamp);
        assertGt(accountCreated.code.length, 0);
        deal(accountCreated, 10 ether);

        // check installed modules
        // -- check executor
        // -- check destination validator on chain
        // -- check source validator on
        assertTrue(
            SuperExecutorBase(address(superExecutorOnETH)).isInitialized(accountCreated), "super executor not installed"
        );
        assertTrue(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor not installed"
        );
        assertTrue(
            SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(accountCreated),
            "super merkle validator not installed"
        );
        assertTrue(
            SuperValidatorBase(address(destinationValidatorOnETH)).isInitialized(accountCreated),
            "super destinatioin validator not installed"
        );

        // perform defi operations
        // -- 4626 deposit
        uint256 obtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, true);
        assertGt(obtainedShares, 0, "no shares were obtained");
        obtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, false);
        assertGt(obtainedShares, 0, "no shares were obtained");

        _executeRedeemFromAccount(accountCreated, obtainedShares, 1000e6, false);

        // perform deposit with uninstall during execution
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, 1000e6, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            1000e6,
            false,
            address(0),
            0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        bytes memory uninstallData = abi.encode(address(destinationValidatorOnETH), bytes(""));
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: accountCreated,
            value: 0,
            callData: abi.encodeCall(
                IERC7579Account.uninstallModule, (MODULE_TYPE_VALIDATOR, address(sourceValidatorOnETH), uninstallData)
            )
        });
        executions[1] = Execution({
            target: address(superExecutorOnETH),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)))
        });

        PackedUserOperation memory userOp = _createPackedUserOperation(
            accountCreated,
            _prepareNonceWithValidator(accountCreated, address(sourceValidatorOnETH)),
            _prepareExecutionCalldata(executions)
        );

        _signAndSendUserOp(userOp, address(sourceValidatorOnETH), accountCreated, true, false);

        // assert obtained shares
        obtainedShares = IERC20(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
        assertEq(obtainedShares, 0, "should have reverted");
    }

    function test_HaveAnAccount_Uninstall_ReinstallCore_CrossChain() public {
        // create an account using cross chain flow
        // - use NexusFactory and NexustBootstrap to create a real account
        address accountCreated = _createAccountCrossChainFlow();

        uint256 usageTimestamp = WARP_START_TIME + 100 days;
        SELECT_FORK_AND_WARP(ETH, usageTimestamp);
        assertGt(accountCreated.code.length, 0);
        deal(accountCreated, 10 ether);

        // check installed modules
        // -- check executor
        // -- check destination validator on chain
        // -- check source validator on
        assertTrue(
            SuperExecutorBase(address(superExecutorOnETH)).isInitialized(accountCreated), "super executor not installed"
        );
        assertTrue(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor not installed"
        );
        assertTrue(
            SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(accountCreated),
            "super merkle validator not installed"
        );
        assertTrue(
            SuperValidatorBase(address(destinationValidatorOnETH)).isInitialized(accountCreated),
            "super destinatioin validator not installed"
        );

        // perform defi operations
        // -- 4626 deposit
        uint256 obtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, true);
        assertGt(obtainedShares, 0, "no shares were obtained");

        // uninstall executor
        bytes memory uninstallData = abi.encode(address(superExecutorOnETH), bytes(""));
        _uninstallModuleOnAccount(
            accountCreated,
            MODULE_TYPE_EXECUTOR,
            address(superTargetExecutorOnETH),
            uninstallData,
            address(sourceValidatorOnETH)
        );
        assertFalse(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor still installed"
        );

        // assert account still has obtained shares
        uint256 midTestObtainedShares = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
        assertEq(obtainedShares, midTestObtainedShares, "shares should be the same after uninstall");

        // re-install executor
        _installModuleOnAccount(
            accountCreated, MODULE_TYPE_EXECUTOR, address(superTargetExecutorOnETH), "", address(sourceValidatorOnETH)
        );
        assertTrue(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor not installed"
        );

        // assert account still has obtained shares
        midTestObtainedShares = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
        assertEq(obtainedShares, midTestObtainedShares, "shares should be the same after re-install");

        // perform defi operations
        // -- 4626 deposit
        uint256 lastObtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, false);
        assertGt(lastObtainedShares, midTestObtainedShares, "shares should increase after deposit");
        assertApproxEqRel(lastObtainedShares, midTestObtainedShares * 2, 0.00001e18);
    }

    function test_HaveAnAccount_Uninstall_ReinstallDifferentCore_CrossChain_CheckSuperLedger() public {
        // create an account using cross chain flow
        // - use NexusFactory and NexustBootstrap to create a real account
        address accountCreated = _createAccountCrossChainFlow();

        uint256 usageTimestamp = WARP_START_TIME + 100 days;
        SELECT_FORK_AND_WARP(ETH, usageTimestamp);
        assertGt(accountCreated.code.length, 0);
        deal(accountCreated, 10 ether);

        // check installed modules
        // -- check executor
        // -- check destination validator on chain
        // -- check source validator on
        assertTrue(
            SuperExecutorBase(address(superExecutorOnETH)).isInitialized(accountCreated), "super executor not installed"
        );
        assertTrue(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor not installed"
        );
        assertTrue(
            SuperValidatorBase(address(sourceValidatorOnETH)).isInitialized(accountCreated),
            "super merkle validator not installed"
        );
        assertTrue(
            SuperValidatorBase(address(destinationValidatorOnETH)).isInitialized(accountCreated),
            "super destinatioin validator not installed"
        );

        // perform defi operations
        // -- 4626 deposit
        uint256 obtainedShares = _performAndAssert4626DepositOnETH(accountCreated, 1000e6, true);
        assertGt(obtainedShares, 0, "no shares were obtained");

        // install a new SuperExecutor (so we can uninstall the old one)
        // -- create
        ISuperLedgerConfiguration superLedgerConfigurationNew =
            ISuperLedgerConfiguration(address(new SuperLedgerConfiguration{ salt: "Test123" }()));
        vm.label(address(superLedgerConfigurationNew), "NewSuperLedgerConfiguration");
        ISuperExecutor superExecutorNew =
            ISuperExecutor(address(new SuperExecutor{ salt: "Test123" }(address(superLedgerConfigurationNew))));
        vm.label(address(superExecutorNew), "NewSuperExecutor");

        // -- configure ledger
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorNew);
        ISuperLedger superLedgerNew = ISuperLedger(
            address(new SuperLedger{ salt: "Test123" }(address(superLedgerConfigurationNew), allowedExecutors))
        );

        address ledgerFeeReceiver = makeAddr("LedgerFeeReceiver");
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 100,
            feeRecipient: ledgerFeeReceiver,
            ledger: address(superLedgerNew)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        vm.startPrank(MANAGER);
        superLedgerConfigurationNew.setYieldSourceOracles(salts, configs);
        vm.stopPrank();

        // -- install
        _installModuleOnAccount(
            accountCreated, MODULE_TYPE_EXECUTOR, address(superExecutorNew), "", address(sourceValidatorOnETH)
        );

        // assert accumulators
        BaseLedger superLedgerOld = BaseLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        assertApproxEqRel(
            superLedgerOld.usersAccumulatorShares(accountCreated, yieldSourceUsdcAddressEth),
            obtainedShares,
            0.0001e18,
            "old ledger acc shares is wrong"
        );
        assertApproxEqRel(
            superLedgerOld.usersAccumulatorCostBasis(accountCreated, yieldSourceUsdcAddressEth),
            1000e6,
            0.0001e18,
            "old ledger acc cost basis is wrong"
        );
        assertEq(
            BaseLedger(address(superLedgerNew)).usersAccumulatorShares(accountCreated, yieldSourceUsdcAddressEth),
            0,
            "new ledger acc shares is wrong (initial)"
        );
        assertEq(
            BaseLedger(address(superLedgerNew)).usersAccumulatorCostBasis(accountCreated, yieldSourceUsdcAddressEth),
            0,
            "new ledger acc cost basis is wrong (initial)"
        );

        // uninstall old executor
        bytes memory uninstallData = abi.encode(address(superExecutorOnETH), bytes(""));
        _uninstallModuleOnAccount(
            accountCreated,
            MODULE_TYPE_EXECUTOR,
            address(superTargetExecutorOnETH),
            uninstallData,
            address(sourceValidatorOnETH)
        );
        assertFalse(
            SuperExecutorBase(address(superTargetExecutorOnETH)).isInitialized(accountCreated),
            "super destination executor still installed"
        );

        // assert account still has obtained shares
        uint256 midTestObtainedShares = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
        assertEq(obtainedShares, midTestObtainedShares, "shares should be the same after uninstall");

        // assert account still has obtained shares
        midTestObtainedShares = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
        assertEq(obtainedShares, midTestObtainedShares, "shares should be the same after re-install");

        uint256 feeRecipientBefore = IERC20(underlyingETH_USDC).balanceOf(address(ledgerFeeReceiver));
        assertEq(feeRecipientBefore, 0, "fee recipient should have no fee before redeem");

        // redeem 4626
        _performAndAssert4626RedeemOnETH(accountCreated, address(superExecutorNew), obtainedShares, true);

        feeRecipientBefore = IERC20(underlyingETH_USDC).balanceOf(address(ledgerFeeReceiver));
        assertEq(
            feeRecipientBefore,
            0,
            "fee recipient should have no fee as well after redeem (because deposit was done in another ledger)"
        );
    }

    //  >>>> ACCOUNT CREATION TESTS
    function test_CrossChainCreateAccount_OnRamp_Offramp_Flow() public {
        // create an account that will be later used to test Onramp-offramp flow
        address accountCreated = _createAccountCrossChainFlow();
        vm.label(accountCreated, "The account");
        uint256 usageTimestamp = WARP_START_TIME + 100 days;
        SELECT_FORK_AND_WARP(ETH, usageTimestamp);
        assertGt(accountCreated.code.length, 0);
        deal(accountCreated, 10 ether);

        {
            // permit2 setup
            permit2 = IAllowanceTransfer(PERMIT2);
            permit2Batch = IPermit2Batch(PERMIT2);
            try IPermit2(PERMIT2).DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
                console2.log("retrieved from permit2");
                console2.logBytes32(domainSeparator);
                permit2DomainSeparator = domainSeparator;
            } catch {
                console2.log("using hardcoded");
                permit2DomainSeparator = 0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28;
            }
        }

        // create execution flow
        // -- batchTransferFrom EOA to contract
        // -- perform defi logic
        // -- batchTransfer back to EOA unused funds + vault shares obtained
        // -- Test scenario:
        // ---- Transfer 2000e6 tokens (BatchTransferFrom hook)
        // ---- Use 1000e6 to deposit to 4626 vault
        // ---- Transfer everything back to EOA (OfframpTokensHook)
        // setup
        uint256 amount = 2000e6;
        _getTokens(underlyingETH_USDC, validatorSigner, amount);

        // check initial balances
        uint256 tokenBalanceAccountCreatedBefore = IERC20(underlyingETH_USDC).balanceOf(accountCreated);
        if (tokenBalanceAccountCreatedBefore > 0) {
            // make sure account state is clean
            // tokens exist because of cross chain transfers
            vm.prank(accountCreated);
            IERC20(underlyingETH_USDC).transfer(address(0x1), tokenBalanceAccountCreatedBefore);
        }
        {
            uint256 tokenBalanceEOABefore = IERC20(underlyingETH_USDC).balanceOf(validatorSigner);
            assertEq(tokenBalanceEOABefore, amount, "initial token balance for EOA is wrong");
            uint256 vaultBalanceEOABefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(validatorSigner);
            assertEq(vaultBalanceEOABefore, 0, "initial vault balance for EOA is wrong");

            uint256 vaultTokenBalanceAccountBefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
            assertEq(vaultTokenBalanceAccountBefore, 0, "initial vault balance for account is wrong");
        }

        PackedUserOperation[] memory ops;
        {
            ISuperExecutor.ExecutorEntry memory entry = _prepareDepositOnOffRampExecution(accountCreated, amount);
            Execution[] memory executions = new Execution[](1);
            executions[0] = Execution({
                target: address(superExecutorOnETH),
                value: 0,
                callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
            });
            PackedUserOperation memory userOp = _createPackedUserOperation(
                accountCreated,
                _prepareNonceWithValidator(accountCreated, address(sourceValidatorOnETH)),
                _prepareExecutionCalldata(executions)
            );
            ops = _signAndSendUserOp(userOp, address(sourceValidatorOnETH), accountCreated, false, false);
        }

        superNativePaymasterOnETH.handleOps{ value: 1 ether }(ops);

        {
            // check final balances
            uint256 tokenBalanceEOAAfter = IERC20(underlyingETH_USDC).balanceOf(validatorSigner);
            assertEq(tokenBalanceEOAAfter, amount / 2, "final token balance for EOA is wrong");
            uint256 vaultBalanceEOAAfter = IERC4626(yieldSourceUsdcAddressEth).balanceOf(validatorSigner);
            assertGt(vaultBalanceEOAAfter, 0, "final vault balance for EOA is wrong");

            uint256 tokenBalanceAccountAfter = IERC20(underlyingETH_USDC).balanceOf(accountCreated);
            assertEq(tokenBalanceAccountAfter, 0, "final token balance for account is wrong");
            uint256 vaultTokenBalanceAccountAfter = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
            assertEq(vaultTokenBalanceAccountAfter, 0, "final vault balance for account is wrong");
        }
    }

    function test_CrossChainCreateAccount_OnRamp_Offramp_Fees_Flow() public {
        // create an account that will be later used to test Onramp-offramp flow
        address accountCreated = _createAccountCrossChainFlow();
        vm.label(accountCreated, "The account");
        uint256 usageTimestamp = WARP_START_TIME + 100 days;
        SELECT_FORK_AND_WARP(ETH, usageTimestamp);
        assertGt(accountCreated.code.length, 0);
        deal(accountCreated, 10 ether);

        {
            // permit2 setup
            permit2 = IAllowanceTransfer(PERMIT2);
            permit2Batch = IPermit2Batch(PERMIT2);
            try IPermit2(PERMIT2).DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
                console2.log("retrieved from permit2");
                console2.logBytes32(domainSeparator);
                permit2DomainSeparator = domainSeparator;
            } catch {
                console2.log("using hardcoded");
                permit2DomainSeparator = 0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28;
            }
        }

        address feeRecipient = makeAddr("newFeeRecipient");
        // update fee to 1.5%
        {
            ISuperLedgerConfiguration configSuperLedger =
                ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY));
            // Propose and accept a new config with fee = 150 (1.5%)
            ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
                new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
            configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
                yieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 150, // 1.5%
                feeRecipient: feeRecipient,
                ledger: _getContract(ETH, SUPER_LEDGER_KEY)
            });
            bytes32[] memory ids = new bytes32[](1);
            ids[0] = _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER);
            vm.prank(MANAGER);
            configSuperLedger.proposeYieldSourceOracleConfig(ids, configs);

            // Fast forward timelock
            vm.warp(block.timestamp + 1 weeks);
            vm.prank(MANAGER);
            configSuperLedger.acceptYieldSourceOracleConfigProposal(ids);
        }

        // create execution flow
        // -- batchTransferFrom EOA to contract
        // -- perform deposit
        // -- perform withdraw and test fee
        // -- batchTransfer back to EOA unused funds
        // -- Test scenario:
        // ---- Transfer 2000e6 tokens (BatchTransferFrom hook)
        // ---- Use 1000e6 to deposit to 4626 vault
        // ---- Transfer everything back to EOA (OfframpTokensHook)
        // setup
        uint256 amount = 2000e6;
        _getTokens(underlyingETH_USDC, validatorSigner, amount);

        // check initial balances
        uint256 tokenBalanceAccountCreatedBefore = IERC20(underlyingETH_USDC).balanceOf(accountCreated);
        if (tokenBalanceAccountCreatedBefore > 0) {
            // make sure account state is clean
            // tokens exist because of cross chain transfers
            vm.prank(accountCreated);
            IERC20(underlyingETH_USDC).transfer(address(0x1), tokenBalanceAccountCreatedBefore);
        }
        {
            uint256 tokenBalanceEOABefore = IERC20(underlyingETH_USDC).balanceOf(validatorSigner);
            assertEq(tokenBalanceEOABefore, amount, "initial token balance for EOA is wrong");
            uint256 vaultBalanceEOABefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(validatorSigner);
            assertEq(vaultBalanceEOABefore, 0, "initial vault balance for EOA is wrong");

            uint256 vaultTokenBalanceAccountBefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
            assertEq(vaultTokenBalanceAccountBefore, 0, "initial vault balance for account is wrong");

            uint256 feeRecipientTokenBalance = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);
            assertEq(feeRecipientTokenBalance, 0, "initial fee recipient token balance is wrong");
            uint256 feeRecipientVaultBalance = IERC4626(yieldSourceUsdcAddressEth).balanceOf(feeRecipient);
            assertEq(feeRecipientVaultBalance, 0, "initial fee recipient vault balance is wrong");
        }

        PackedUserOperation[] memory ops;
        {
            ISuperExecutor.ExecutorEntry memory entry =
                _prepareDepositAndRedeemOnOffRampExecution(accountCreated, amount);
            Execution[] memory executions = new Execution[](1);
            executions[0] = Execution({
                target: address(superExecutorOnETH),
                value: 0,
                callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
            });
            PackedUserOperation memory userOp = _createPackedUserOperation(
                accountCreated,
                _prepareNonceWithValidator(accountCreated, address(sourceValidatorOnETH)),
                _prepareExecutionCalldata(executions)
            );
            ops = _signAndSendUserOp(userOp, address(sourceValidatorOnETH), accountCreated, false, false);
        }

        superNativePaymasterOnETH.handleOps{ value: 1 ether }(ops);

        {
            // check final balances
            uint256 tokenBalanceEOAAfter = IERC20(underlyingETH_USDC).balanceOf(validatorSigner);
            assertLt(tokenBalanceEOAAfter, amount, "final token balance for EOA is wrong 1");
            assertGt(tokenBalanceEOAAfter, amount / 2, "final token balance for EOA is wrong 2");
            uint256 vaultBalanceEOAAfter = IERC4626(yieldSourceUsdcAddressEth).balanceOf(validatorSigner);
            assertEq(vaultBalanceEOAAfter, 0, "final vault balance for EOA is wrong");

            uint256 tokenBalanceAccountAfter = IERC20(underlyingETH_USDC).balanceOf(accountCreated);
            assertEq(tokenBalanceAccountAfter, 0, "final token balance for account is wrong");
            uint256 vaultTokenBalanceAccountAfter = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountCreated);
            assertEq(vaultTokenBalanceAccountAfter, 0, "final vault balance for account is wrong");

            uint256 feeRecipientTokenBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);
            assertGt(feeRecipientTokenBalanceAfter, 0, "final fee recipient token balance is wrong");
            uint256 feeRecipientVaultBalanceAfter = IERC4626(yieldSourceUsdcAddressEth).balanceOf(feeRecipient);
            assertEq(feeRecipientVaultBalanceAfter, 0, "final fee recipient vault balance is wrong");
        }
    }

    function test_Create_ETH_Account_And_Use_As_Source() public {
        uint256 ethAccountCreationTimestamp = WARP_START_TIME;
        SELECT_FORK_AND_WARP(ETH, ethAccountCreationTimestamp);

        address ethAccountCreated = _createAccountCrossChainFlow();
        vm.label(ethAccountCreated, "ETH Nexus Account");

        SELECT_FORK_AND_WARP(ETH, ethAccountCreationTimestamp + 31 days);
        assertGt(ethAccountCreated.code.length, 0, "ETH account creation failed");
        deal(ethAccountCreated, 10 ether);
        deal(underlyingETH_USDC, ethAccountCreated, 1e8);

        uint256 depositAmount = 5e7;
        uint256 vaultBalanceAfter = _executeDepositFromAccount(ethAccountCreated, depositAmount);
        _executeRedeemFromAccount(ethAccountCreated, vaultBalanceAfter, depositAmount, true);
    }

    function test_Create_ETHandBASE_accounts() public {
        uint256 startTimestamp = WARP_START_TIME;

        // create ETH account
        SELECT_FORK_AND_WARP(ETH, startTimestamp);
        address ethAccountCreated = _createAccountCrossChainFlow();
        vm.label(ethAccountCreated, "ETH Nexus Account");

        // assert ETH
        SELECT_FORK_AND_WARP(ETH, startTimestamp + 31 days);
        assertGt(ethAccountCreated.code.length, 0, "ETH account creation failed");
        deal(ethAccountCreated, 10 ether);
        deal(underlyingETH_USDC, ethAccountCreated, 1e8);

        // try base - sig is already stored
        SELECT_FORK_AND_WARP(BASE, startTimestamp + 60 days);
        address baseAccountCreated = _createAccountOnBASECrossChainFlow(true);
        vm.label(baseAccountCreated, "BASE Nexus Account");
    }

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
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
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
        _processDebridgeDlnMessage(BASE, ETH, executionData);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        _execute7540DepositFlow(amountPerVault);

        vm.selectFork(FORKS[ETH]);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
    }

    function test_ETH_Bridge_With_Debridge_NoExecution() public {
        uint256 amountPerVault = 1e8;

        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);
        uint256 balanceOnDestinationBefore = IERC20(underlyingETH_USDC).balanceOf(accountETH);

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
                executorAddress: address(accountETH), //envelope.executorAddress
                executionFee: uint160(0), //envelope.executionFee
                allowDelayedExecution: false, //envelope.allowDelayedExecution
                requireSuccessfulExecution: true, //envelope.requireSuccessfulExecution
                payload: "", //envelope.payload
                takeTokenAddress: underlyingETH_USDC, //takeTokenAddress
                takeAmount: amountPerVault - amountPerVault * 1e4 / 1e5, //takeAmount
                takeChainId: ETH, //takeChainId
                // receiverDst must be the Debridge Adapter on the destination chain
                receiverDst: address(accountETH),
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

        bytes memory signatureData = _createNoDestinationExecutionMerkleRootAndSignature(
            validatorSigners[BASE],
            validatorSignerPrivateKeys[BASE],
            srcUserOpData.userOpHash,
            address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        // EXECUTE BASE
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
        _processDebridgeDlnMessage(BASE, ETH, executionData);

        // check destination
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME + 50 days);
        uint256 balanceOnDestination = IERC20(underlyingETH_USDC).balanceOf(accountETH);
        assertEq(balanceOnDestination - balanceOnDestinationBefore, amountPerVault * 9e4 / 1e5, "AAA");
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

    function test_DeBridgeCancelOrderHook_AndMarkRootAsUsed() public {
        uint256 amountPerVault = 1e8;

        bytes memory sigData = _sendDeBridgeOrder();

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

        {
            bytes32 merkleRoot = BytesLib.toBytes32(BytesLib.slice(sigData, 64, 32), 0);
            bool rootStatusBefore =
                ISuperDestinationExecutor(superTargetExecutorOnETH).isMerkleRootUsed(accountETH, merkleRoot);
            assertFalse(rootStatusBefore, "root is not marked here");

            cancelOrderHooksAddresses = new address[](1);
            cancelOrderHooksAddresses[0] = _getHookAddress(ETH, MARK_ROOT_AS_USED_HOOK_KEY);

            cancelData = new bytes[](1);
            bytes32[] memory roots = new bytes32[](1);
            roots[0] = merkleRoot;
            cancelData[0] = _createMarkRootAsUsedHookData(address(superTargetExecutorOnETH), abi.encode(roots));

            cancelOrderUserOpData = _createUserOpData(cancelOrderHooksAddresses, cancelData, ETH, false);

            executeOpsThroughPaymaster(cancelOrderUserOpData, superNativePaymasterOnETH, 1e18);

            bool rootStatusAfter =
                ISuperDestinationExecutor(superTargetExecutorOnETH).isMerkleRootUsed(accountETH, merkleRoot);
            assertTrue(rootStatusAfter, "root is marked here");
        }
    }

    //  >>>> ACROSS
    function test_CrossChain_SignatureReplay_Prevention() public {
        SignatureReplayTestData memory testData = _prepareSignatureReplayTest();

        // same chain replay
        _testSameChainReplayAttack(testData);
        // cross chain replay
        _testCrossChainReplayAttack(testData);
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
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpDataOP, superNativePaymasterOnBase, 1e18);
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

    function test_bridge_To_OP_NoExecution() public {
        uint256 amount = 1e8 / 2;

        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);
        uint256 balanceOPBefore = IERC20(underlyingOP_USDCe).balanceOf(accountBase);
        assertEq(balanceOPBefore, 0);

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        uint256 userBalanceBaseUSDCBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // PREPARE BASE DATA
        address[] memory srcHooksAddressesOP = new address[](2);
        srcHooksAddressesOP[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddressesOP[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksDataOP = new bytes[](2);
        srcHooksDataOP[0] = _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amount, false);
        srcHooksDataOP[1] = _createAcrossV3ReceiveFundsNoExecution(
            accountBase, underlyingBase_USDC, underlyingOP_USDCe, amount, amount, OP, true, bytes("")
        );

        UserOpData memory srcUserOpDataOP = _createUserOpData(srcHooksAddressesOP, srcHooksDataOP, BASE, true);

        bytes memory signatureData = _createNoDestinationExecutionMerkleRootAndSignature(
            validatorSigners[BASE],
            validatorSignerPrivateKeys[BASE],
            srcUserOpDataOP.userOpHash,
            address(sourceValidatorOnBase)
        );
        srcUserOpDataOP.userOp.signature = signatureData;

        // EXECUTE OP
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpDataOP, superNativePaymasterOnBase, 1e18);
        _processAcrossV3MessageWithoutDestinationAccount(BASE, OP, WARP_START_TIME, executionData);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), userBalanceBaseUSDCBefore - amount, "A");

        SELECT_FORK_AND_WARP(OP, WARP_START_TIME + 10 days);
        assertEq(IERC20(underlyingOP_USDCe).balanceOf(accountBase), amount, "B");
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
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
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
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
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
        uint256 previewRedeemAmount = vaultInstanceEth.previewRedeem(vaultInstanceEth.previewDeposit(amount));

        // Setup destination chain data - reuse existing helper but with different amount param
        (bytes memory targetExecutorMessage, address accountToUse, TargetExecutorMessage memory messageData) =
            _setupDestinationForRebalance(previewRedeemAmount, amount);

        // Setup and execute source chain for rebalance
        ExecutionReturnData memory executionData =
            _executeRebalanceSourceChain(amount, previewRedeemAmount, targetExecutorMessage, accountToUse, messageData);
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

        // Setup destination chain data and get target executor message
        (params.targetExecutorMessage, params.accountToUse) = _setupDestinationForUsedRoot(params.amount);

        _getTokens(underlyingBase_USDC, params.accountToUse, params.amount);

        // Setup source chain execution
        _setupSourceAndExecuteUsedRoot(params);
        params.srcUserOpData.userOp.signature = params.signatureData;

        // Frontrun the actual call
        SELECT_FORK_AND_WARP(BASE, block.timestamp + 1 days);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = underlyingBase_USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = params.amount;
        (bytes memory accountCreationData, bytes memory executionData,,,) =
            abi.decode(params.targetExecutorMessage, (bytes, bytes, address, address[], uint256[]));

        uint256 tokensAmountBeforeProcessing = IERC20(underlyingBase_USDC).balanceOf(params.accountToUse);
        assertEq(tokensAmountBeforeProcessing, params.amount);
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
        bytes32 _merkleRoot = bytes32(BytesLib.slice(params.signatureData, 96, 32));
        ExecutionReturnData memory _paymasterExecutionData =
            executeOpsThroughPaymaster(params.srcUserOpData, superNativePaymasterOnETH, 1e18);
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
        assertEq(tokensAmountAfterBridgeMessage, params.amount);
    }

    function test_DOS_ProcessBridgedExecution_WithInvalidSignatures() public {
        BridgeDeposit4626UsedRootParams memory params;

        // Initialize test parameters
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        params.amount = 1e8;

        // Setup destination chain data and get target executor message
        (params.targetExecutorMessage, params.accountToUse) = _setupDestinationForUsedRoot(params.amount);

        _getTokens(underlyingBase_USDC, params.accountToUse, params.amount);

        // Setup source chain execution
        _setupSourceAndExecuteUsedRoot(params);
        params.srcUserOpData.userOp.signature = params.signatureData;

        // Frontrun the actual call
        SELECT_FORK_AND_WARP(BASE, block.timestamp + 1 days);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = underlyingBase_USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = params.amount;
        (bytes memory accountCreationData, bytes memory executionData,,,) =
            abi.decode(params.targetExecutorMessage, (bytes, bytes, address, address[], uint256[]));

        // Replay test - different chain
        TargetExecutorMessage memory messageDataForSig =
            _createDestinationMessageDataForUsedRoot(params.amount, params.accountToUse);
        params.signatureData = _createMerkleRootAndSignature(
            messageDataForSig, params.srcUserOpData.userOpHash, params.accountToUse, ETH, address(sourceValidatorOnETH)
        );
        vm.expectRevert(ISuperValidator.PROOF_NOT_FOUND.selector);
        superTargetExecutorOnBase.processBridgedExecution(
            address(this),
            params.accountToUse,
            dstTokens,
            intentAmounts,
            accountCreationData,
            executionData,
            params.signatureData
        );

        // Bad signature test - updated signature but for the correct chain
        address originalTargetExecutor = messageDataForSig.targetExecutor;
        messageDataForSig.targetExecutor = address(0);
        params.signatureData = _createMerkleRootAndSignature(
            messageDataForSig, params.srcUserOpData.userOpHash, params.accountToUse, BASE, address(sourceValidatorOnETH)
        );
        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        superTargetExecutorOnBase.processBridgedExecution(
            address(this),
            params.accountToUse,
            dstTokens,
            intentAmounts,
            accountCreationData,
            executionData,
            params.signatureData
        );

        // Totally fake signature
        params.signatureData = _createFakeSignatureData(keccak256(abi.encode("fake root")), 1, BASE);
        vm.expectRevert();
        superTargetExecutorOnBase.processBridgedExecution(
            address(this),
            params.accountToUse,
            dstTokens,
            intentAmounts,
            accountCreationData,
            executionData,
            params.signatureData
        );

        // everything should still be valid
        bool isRootUsed = ISuperDestinationExecutor(originalTargetExecutor).isMerkleRootUsed(
            params.accountToUse, params.srcUserOpData.userOpHash
        );
        assertEq(isRootUsed, false);
    }

    function test_InvalidDestinationFlow() public {
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        uint256 amount = 1e8;
        uint256 previewRedeemAmount = vaultInstanceEth.previewRedeem(vaultInstanceEth.previewDeposit(amount));

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
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
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

        ExecutionReturnData memory _paymasterExecutionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnETH, 1e18);
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
            uint64[] memory chainsWithDestinationExecution,
            uint48 validUntil,
            uint48 validAfter,
            bytes32 merkleRoot,
            bytes32[] memory merkleProofSrc,
            , // This will be replaced
            bytes memory signature
        ) = abi.decode(signatureData, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

        ISuperValidator.DstProof[] memory emptyMerkleProofDst = new ISuperValidator.DstProof[](0);

        bytes memory tamperedSig = abi.encode(
            chainsWithDestinationExecution,
            validUntil,
            validAfter,
            merkleRoot,
            merkleProofSrc,
            emptyMerkleProofDst,
            signature
        );

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

    function test_FAILS_ETH_Bridge_And_Deposit_Calldata_Tamper() public {
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

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        uint256 msgValue = IDlnSource(DEBRIDGE_DLN_ADDRESSES[BASE]).globalFixedNativeFee();

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amountPerVault, false);

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

        // MALICIOUS BUNDLER TAMPERS WITH CALLDATA
        // Tamper with the calldata in the debridge hook
        // This simulates a malicious bundler modifying the execution payload to redirect funds
        // Create a malicious payload that changes the destination account

        // Extract the original payload from the debridge data
        // The payload is located after the fixed fields in the debridge data
        bytes memory originalPayload = innerExecutorPayload;

        // Recreate user operation with tampered calldata
        srcUserOpData = _createUserOpDataWithCalldataTamper(
            amountPerVault, msgValue, srcHooksAddresses, srcHooksData, originalPayload
        );

        // Execute op on src chain - this should fail due to calldata tampering
        // The validation should detect that the calldata doesn't match the signed data
        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        instanceOnBase.expect4337Revert();
        executeOp(srcUserOpData);
        // ^ This should fail because the calldata has been tampered with

        // Verify that user funds remain intact - no actual execution should occur
        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before);
    }

    function test_BridgeThroughDifferentAdapters() public {
        uint256 amount = 1e8;

        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        address accountToUse;
        TargetExecutorMessage memory messageData;
        bytes memory targetExecutorMessage;

        // create bridge data
        {
            address[] memory dstHooksAddresses = new address[](2);
            dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

            bytes[] memory dstHooksData = new bytes[](2);
            dstHooksData[0] =
                _createApproveHookData(underlyingBase_WETH, yieldSource4626AddressBase_WETH, amount, false);
            dstHooksData[1] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource4626AddressBase_WETH,
                amount,
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
                amount: amount,
                account: address(0),
                tokenSent: underlyingBase_WETH
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME + 1 days);

        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amount / 2, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, underlyingBase_WETH, amount / 2, amount / 2, BASE, true, targetExecutorMessage
        );
        srcHooksData[2] = _createApproveHookData(underlyingETH_USDC, DEBRIDGE_DLN_ADDRESSES[ETH], amount / 2, false);

        bytes memory debridgeData = _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false, //usePrevHookAmount
                value: IDlnSource(DEBRIDGE_DLN_ADDRESSES[ETH]).globalFixedNativeFee(), //value
                giveTokenAddress: underlyingETH_USDC, //giveTokenAddress
                giveAmount: amount / 2, //giveAmount
                version: 1, //envelope.version
                fallbackAddress: accountETH, //envelope.fallbackAddress
                executorAddress: address(debridgeAdapterOnETH), //envelope.executorAddress
                executionFee: uint160(0), //envelope.executionFee
                allowDelayedExecution: false, //envelope.allowDelayedExecution
                requireSuccessfulExecution: true, //envelope.requireSuccessfulExecution
                payload: targetExecutorMessage, //envelope.payload
                takeTokenAddress: underlyingBase_WETH, //takeTokenAddress
                takeAmount: amount / 2, //takeAmount
                takeChainId: BASE, //takeChainId
                // receiverDst must be the Debridge Adapter on the destination chain
                receiverDst: address(debridgeAdapterOnBase),
                givePatchAuthoritySrc: address(0), //givePatchAuthoritySrc
                orderAuthorityAddressDst: abi.encodePacked(accountToUse), //orderAuthorityAddressDst
                allowedTakerDst: "", //allowedTakerDst
                allowedCancelBeneficiarySrc: "", //allowedCancelBeneficiarySrc
                affiliateFee: "", //affiliateFee
                referralCode: 0 //referralCode
             })
        );
        srcHooksData[3] = debridgeData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        UserOpData memory srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(entry), address(sourceValidatorOnETH)
        );

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        srcUserOpData.userOp.signature = signatureData;
        ExecutionReturnData memory executionData = executeOp(srcUserOpData);

        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: executionData,
                relayerType: RELAYER_TYPE.NOT_ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                account: accountToUse,
                root: bytes32(0),
                relayerGas: 0
            })
        );

        _processDebridgeDlnMessage(ETH, BASE, executionData);

        // Verify that accountToUse received vault shares from the deposit
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 2 days);
        uint256 vaultShares = IERC20(yieldSource4626AddressBase_WETH).balanceOf(accountToUse);
        assertGt(vaultShares, 0, "Account should have received vault shares from deposit");

        // Verify the shares can be converted back to approximately the deposited amount
        uint256 assetsFromShares = IERC4626(yieldSource4626AddressBase_WETH).convertToAssets(vaultShares);
        assertApproxEqRel(
            assetsFromShares, amount, 0.01e18, "Vault shares should convert to approximately the deposited amount"
        );
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
                relayerGas: 700_000
            })
        );
        // the signatures don't match due to wrong decoding
        (,,,,,, bytes memory destinationChainSignature) =
            abi.decode(signatureData, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

        (,,,,, bytes memory sourceChainSignature) =
            abi.decode(signatureData, (uint64[], uint48, uint48, bytes32, bytes32[], bytes));

        assert(keccak256(destinationChainSignature) != keccak256(sourceChainSignature));
    }

    function test_FAILS_CrossChain_Execution_Replay() public {
        uint256 amountToDeposit = 1e18;
        uint256 amountPerVault = amountToDeposit / 2;

        // OP IS DST - Prepare target executor message for OP chain
        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);
        uint256 previewDepositAmount = IERC4626(yieldSource4626AddressOP_USDCe).convertToShares(amountToDeposit);

        (bytes memory targetExecutorMessage, address accountToUse, TargetExecutorMessage memory messageData) =
            _prepareOPDeposit4626Message(amountPerVault); // Generalize this

        // ETH IS SRC - First execution from ETH to OP
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME + 1 days);

        UserOpData memory ethUserOpData =
            _prepareETHUserOpData(amountPerVault, accountToUse, messageData, targetExecutorMessage);

        // EXECUTE ETH - First execution should not proceed yet
        ExecutionReturnData memory ethExecutionData =
            executeOpsThroughPaymaster(ethUserOpData, superNativePaymasterOnETH, 1e18);
        _processDebridgeDlnMessage(ETH, OP, ethExecutionData);

        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 2 days);

        // PREPARE BASE DATA - Source hooks that will bridge from BASE to OP
        address[] memory baseHooksAddresses = new address[](2);
        baseHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        baseHooksAddresses[1] = _getHookAddress(BASE, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory baseHooksData = new bytes[](2);
        baseHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amountPerVault, false);

        // Create and execute user operation from BASE
        UserOpData memory baseUserOpData = _createBaseUserOp(amountPerVault, accountToUse, targetExecutorMessage);
        bytes memory baseSignatureData = _createMerkleRootAndSignature(
            messageData, baseUserOpData.userOpHash, accountToUse, OP, address(sourceValidatorOnBase)
        );
        baseUserOpData.userOp.signature = baseSignatureData;

        // EXECUTE BASE - This execution should succeed
        ExecutionReturnData memory baseExecutionData =
            executeOpsThroughPaymaster(baseUserOpData, superNativePaymasterOnBase, 1e18);

        _processDebridgeDlnMessage(BASE, OP, baseExecutionData);

        // This execution should have succeed
        SELECT_FORK_AND_WARP(OP, WARP_START_TIME);
        assertApproxEqRel(
            IERC20(yieldSource4626AddressOP_USDCe).balanceOf(accountToUse),
            previewDepositAmount - 1,
            0.001e18, // 0.1% tolerance for vault precision
            "Vault balance should approximately match expected shares"
        );

        // BASE IS SRC - Second execution from BASE to OP (replay attack)
        baseUserOpData = _createBaseUserOp(amountPerVault, accountToUse, targetExecutorMessage);

        // Use the same signature from ETH execution - this should fail due to replay protection
        baseUserOpData.userOp.signature = baseSignatureData;

        // EXECUTE BASE - This should fail due to replay attack
        vm.expectRevert();
        baseExecutionData = executeOpsThroughPaymaster(baseUserOpData, superNativePaymasterOnBase, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL CROSS-CHAIN TRANSFERS
    //////////////////////////////////////////////////////////////*/
    function _prepareSignatureReplayTest() private returns (SignatureReplayTestData memory) {
        SignatureReplayTestData memory testData;
        testData.amountPerVault = 1e8 / 2;

        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA
        {
            address[] memory dstHookAddresses = new address[](0);
            bytes[] memory dstHookData = new bytes[](0);

            testData.messageData = TargetExecutorMessage({
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
                amount: testData.amountPerVault,
                account: address(0),
                tokenSent: underlyingETH_USDC
            });

            (testData.targetExecutorMessage, testData.accountToUse) =
                _createTargetExecutorMessage(testData.messageData, false);
        }

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        // PREPARE BASE DATA
        testData.srcHooksAddresses = new address[](2);
        testData.srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        testData.srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        testData.srcHooksData = new bytes[](2);
        testData.srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], testData.amountPerVault, false);
        testData.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            underlyingETH_USDC,
            testData.amountPerVault,
            testData.amountPerVault,
            ETH,
            true,
            testData.targetExecutorMessage
        );

        // Create the original user operation
        UserOpData memory srcUserOpData =
            _createUserOpData(testData.srcHooksAddresses, testData.srcHooksData, BASE, true);

        // Generate valid signature for the operation
        testData.signatureData = _createMerkleRootAndSignature(
            testData.messageData, srcUserOpData.userOpHash, testData.accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = testData.signatureData;

        // EXECUTE BASE - First execution should succeed
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
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
                account: testData.accountToUse,
                relayerGas: 0
            })
        );

        return testData;
    }

    function _testSameChainReplayAttack(SignatureReplayTestData memory testData) private {
        // EDGE CASE: Attempt to replay the same signature with a new nonce
        // This creates a new user operation with same data but different nonce
        UserOpData memory replayUserOpData =
            _createUserOpData(testData.srcHooksAddresses, testData.srcHooksData, BASE, true);

        // Use the original signature - simulating a replay attack
        replayUserOpData.userOp.signature = testData.signatureData;

        // The replay should be rejected
        vm.expectRevert();
        executeOpsThroughPaymaster(replayUserOpData, superNativePaymasterOnBase, 1e18);
    }

    function _testCrossChainReplayAttack(SignatureReplayTestData memory testData) private {
        // CROSS-CHAIN REPLAY: Attempt to replay the signature on a different chain (OP)
        SELECT_FORK_AND_WARP(OP, WARP_START_TIME + 30 days);

        // Setup for OP chain replay attempt
        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] =
            _createApproveHookData(underlyingOP_USDC, SPOKE_POOL_V3_ADDRESSES[OP], testData.amountPerVault, false);
        opHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC,
            underlyingETH_USDC,
            testData.amountPerVault,
            testData.amountPerVault,
            ETH,
            true,
            testData.targetExecutorMessage
        );

        // Create operation on OP chain with Base chain signature
        UserOpData memory crossChainReplayUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP, true);
        crossChainReplayUserOpData.userOp.signature = testData.signatureData;

        // This should also be rejected due to chain ID mismatch in signature
        vm.expectRevert();
        executeOpsThroughPaymaster(crossChainReplayUserOpData, superNativePaymasterOnOP, 1e18);
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
        SuperLedgerConfiguration.YieldSourceOracleConfig memory config = configSuperLedger.getYieldSourceOracleConfig(_getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER));
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

        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(opUserOpData, superNativePaymasterOnOP, 1e18);

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
            accountOP, yieldSource4626AddressOP_USDCe, expectedAssetOutAmount, userExpectedShareDelta, 100, 0, 0
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
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(src1UserOpData, superNativePaymasterOnOP, 1e18);
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

        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(src1UserOpData, superNativePaymasterOnETH, 1e18);
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

    function _sendDeBridgeOrder() internal returns (bytes memory) {
        uint256 amountPerVault = 1e8;

        // Base is src
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        bytes memory signatureData = _executeDeBridgeOrder(amountPerVault);

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

        return signatureData;
    }

    // Sandwich scenario on a cross-chain swap. Have an attacker front-run a user's swap to inflate price so the
    // user's minAmount fails. Ensure the user's original operation reverts safely and the user is refunded on the
    // source chain
    function test_CrossChain_SandwhichAttack_Handling() public {
        // We do not need to simulate the attacker price manipulation, as the mock Odos Router will revert if the
        // output min is not met.

        // Base is dst
        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP + 2 days);

        uint256 accountBaseBalanceBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        address accountToUse;
        bytes memory targetExecutorMessage;
        TargetExecutorMessage memory messageData;
        // Prepare dst data
        {
            // Prepare swap data
            address[] memory swapHookAddresses = new address[](2);
            swapHookAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
            swapHookAddresses[1] = address(new SwapOdosV2Hook(address(mockOdosSwapOutputMin)));

            bytes[] memory swapHookData = new bytes[](2);
            swapHookData[0] = _createApproveHookData(underlyingBase_USDC, address(mockOdosSwapOutputMin), 1e8, false);
            swapHookData[1] = _createOdosSwapHookData(
                underlyingBase_USDC,
                1e8,
                address(this),
                underlyingBase_WETH,
                1e8,
                1e10,
                bytes(""),
                address(mockOdosSwapOutputMin),
                0,
                false
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: swapHookAddresses,
                hooksData: swapHookData,
                validator: address(destinationValidatorOnBase),
                signer: validatorSigners[BASE],
                signerPrivateKey: validatorSignerPrivateKeys[BASE],
                targetAdapter: address(acrossV3AdapterOnBase),
                targetExecutor: address(superTargetExecutorOnBase),
                nexusFactory: CHAIN_8453_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
                chainId: uint64(BASE),
                amount: 1e8,
                account: accountBase,
                tokenSent: underlyingBase_USDC
            });

            (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }

        // ETH is src
        SELECT_FORK_AND_WARP(ETH, CHAIN_1_TIMESTAMP + 2 days);

        uint256 accountETHBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(accountETH);

        // Prepare src data
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], 1e8, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, underlyingBase_USDC, 1e4, 1e4, BASE, false, targetExecutorMessage
        );

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, ETH, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        srcUserOpData.userOp.signature = signatureData;

        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnETH, 1e8);

        // a revert occurs on dst chain
        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: ETH,
                dstChainId: BASE,
                warpTimestamp: block.timestamp,
                executionData: executionData,
                relayerType: RELAYER_TYPE.REVERT,
                errorMessage: bytes4(0),
                errorReason: "MockOdosSwap: output min not met",
                account: accountBase,
                root: bytes32(0),
                relayerGas: 0
            })
        );

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), accountBaseBalanceBefore);

        vm.stopBroadcast();
        vm.selectFork(FORKS[ETH]);
        assertEq(IERC20(underlyingETH_USDC).balanceOf(accountETH), accountETHBalanceBefore - 1e4);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL LOGIC HELPERS
    //////////////////////////////////////////////////////////////*/
    function _createAccountOnBASECrossChainFlow(bool shouldRevert) private returns (address) {
        uint256 amountPerVault = 1e8 / 2;

        // First prepare on ETH as the destination
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        TargetExecutorMessage memory messageData = TargetExecutorMessage({
            hooksAddresses: new address[](0),
            hooksData: new bytes[](0),
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

        bytes memory targetExecutorMessage;
        address accountToUse;
        (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);

        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

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

        if (shouldRevert) {
            vm.expectRevert();
        }
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);

        if (!shouldRevert) {
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

        return accountToUse;
    }

    function _createBaseMsgData()
        private
        returns (address accountToUse, bytes memory targetExecutorMessage, TargetExecutorMessage memory messageData)
    {
        SELECT_FORK_AND_WARP(BASE, CHAIN_8453_TIMESTAMP);
        uint256 amount = 1000e6;

        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);
        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, amount, false);
        dstHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressBase,
            amount,
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

    function _createOPMsgData(bytes memory targetExecutorMessageBase)
        private
        returns (address accountToUse, bytes memory targetExecutorMessage, TargetExecutorMessage memory messageData)
    {
        SELECT_FORK_AND_WARP(OP, CHAIN_10_TIMESTAMP);

        uint256 amount = 1000e6;

        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] = _createApproveHookData(underlyingOP_USDC, address(mockOdosSwapOutputMin), amount, false);
        opHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC, underlyingBase_USDC, amount, amount, BASE, false, targetExecutorMessageBase
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
            amount: amount,
            account: accountOP,
            tokenSent: underlyingOP_USDC
        });

        (targetExecutorMessage, accountToUse) = _createTargetExecutorMessage(messageData, false);
    }

    function _executeDepositFromAccountOnBASE(address account, uint256 depositAmount) private returns (uint256) {
        address[] memory depositHooksAddresses = new address[](2);
        depositHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        depositHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory depositHooksData = new bytes[](2);
        depositHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, depositAmount, false);
        depositHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressBase,
            depositAmount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory depositEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: depositHooksAddresses, hooksData: depositHooksData });

        uint256 tokenBalanceBefore = IERC20(underlyingBase_USDC).balanceOf(account);
        assertEq(tokenBalanceBefore, 1e8);
        uint256 vaultBalanceBefore = IERC4626(yieldSourceMorphoUsdcAddressBase).balanceOf(account);
        assertEq(vaultBalanceBefore, 0);

        _executeHooksThroughEntrypoint(
            account, address(superExecutorOnBase), address(sourceValidatorOnBase), depositEntry
        );

        uint256 tokenBalanceAfter = IERC20(underlyingBase_USDC).balanceOf(account);
        assertEq(tokenBalanceAfter, 1e8 - depositAmount);

        uint256 vaultBalanceAfter = IERC4626(yieldSourceMorphoUsdcAddressBase).balanceOf(account);
        assertGt(vaultBalanceAfter, 0);

        return vaultBalanceAfter;
    }

    function _executeRedeemFromAccountOnBASE(
        address account,
        uint256 redeemShares,
        uint256 originalDepositAmount
    )
        private
    {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(BASE, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressBase,
            account,
            redeemShares,
            false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });

        _executeHooksThroughEntrypoint(
            account, address(superExecutorOnBase), address(sourceValidatorOnBase), redeemEntry
        );

        uint256 vaultBalanceAfterRedeem = IERC4626(yieldSourceMorphoUsdcAddressBase).balanceOf(account);
        assertEq(vaultBalanceAfterRedeem, 0, "no vault shares after redeem");
        uint256 tokenBalanceAfterRedeem = IERC20(underlyingBase_USDC).balanceOf(account);
        assertGt(tokenBalanceAfterRedeem, 1e8 - originalDepositAmount, "received tokens back");
    }

    function _executeDepositFromAccount(address account, uint256 depositAmount) private returns (uint256) {
        address[] memory depositHooksAddresses = new address[](2);
        depositHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        depositHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory depositHooksData = new bytes[](2);
        depositHooksData[0] =
            _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, depositAmount, false);
        depositHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            depositAmount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory depositEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: depositHooksAddresses, hooksData: depositHooksData });

        uint256 tokenBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(account);
        assertEq(tokenBalanceBefore, 1e8);
        uint256 vaultBalanceBefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(account);
        assertEq(vaultBalanceBefore, 0);

        _executeHooksThroughEntrypoint(
            account, address(superExecutorOnETH), address(sourceValidatorOnETH), depositEntry
        );

        uint256 tokenBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(account);
        assertEq(tokenBalanceAfter, 1e8 - depositAmount);

        uint256 vaultBalanceAfter = IERC4626(yieldSourceUsdcAddressEth).balanceOf(account);
        assertGt(vaultBalanceAfter, 0);

        return vaultBalanceAfter;
    }

    function _executeRedeemFromAccount(
        address account,
        uint256 redeemShares,
        uint256 originalDepositAmount,
        bool asserts
    )
        private
    {
        address[] memory redeemHooksAddresses = new address[](1);
        redeemHooksAddresses[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            account,
            redeemShares,
            false
        );

        ISuperExecutor.ExecutorEntry memory redeemEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: redeemHooksAddresses, hooksData: redeemHooksData });

        _executeHooksThroughEntrypoint(account, address(superExecutorOnETH), address(sourceValidatorOnETH), redeemEntry);

        uint256 vaultBalanceAfterRedeem = IERC4626(yieldSourceUsdcAddressEth).balanceOf(account);
        assertEq(vaultBalanceAfterRedeem, 0, "no vault shares after redeem");
        if (asserts) {
            uint256 tokenBalanceAfterRedeem = IERC20(underlyingETH_USDC).balanceOf(account);
            assertGt(tokenBalanceAfterRedeem, 1e8 - originalDepositAmount, "received tokens back");
        }
    }

    function _prepareDepositOnOffRampExecution(
        address accountCreated,
        uint256 amount
    )
        private
        returns (ISuperExecutor.ExecutorEntry memory entry)
    {
        // permit2 setup
        address[] memory _tokens = new address[](1);
        _tokens[0] = underlyingETH_USDC;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = amount;
        uint48[] memory _nonces = new uint48[](1);
        _nonces[0] = 0;
        uint256 sigDeadline = block.timestamp + 10 days;
        IAllowanceTransfer.PermitBatch memory permitBatch =
            _createPermitBatchData(accountCreated, _tokens, _amounts, uint48(sigDeadline), _nonces);
        bytes memory permit2Sig = _getPermitBatchSignature(permitBatch, permit2DomainSeparator, PERMIT2_BATCH_TYPE_HASH);

        vm.prank(validatorSigner);
        IERC20(underlyingETH_USDC).approve(PERMIT2, amount);

        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, BATCH_TRANSFER_FROM_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, OFFRAMP_TOKENS_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] =
            _createBatchTransferFromHookData(validatorSigner, 1, sigDeadline, _tokens, _amounts, _nonces, permit2Sig);
        srcHooksData[1] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, amount / 2, false);
        srcHooksData[2] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            amount / 2,
            false,
            address(0),
            0
        );
        address[] memory offRampTokens = new address[](2);
        offRampTokens[0] = underlyingETH_USDC;
        offRampTokens[1] = yieldSourceUsdcAddressEth;
        srcHooksData[3] = _createOfframpTokensHookData(validatorSigner, offRampTokens);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });
    }

    function _prepareDepositAndRedeemOnOffRampExecution(
        address accountCreated,
        uint256 amount
    )
        private
        returns (ISuperExecutor.ExecutorEntry memory entry)
    {
        // permit2 setup
        address[] memory _tokens = new address[](1);
        _tokens[0] = underlyingETH_USDC;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = amount;
        uint48[] memory _nonces = new uint48[](1);
        _nonces[0] = 0;
        uint256 sigDeadline = block.timestamp + 10 days;
        IAllowanceTransfer.PermitBatch memory permitBatch =
            _createPermitBatchData(accountCreated, _tokens, _amounts, uint48(sigDeadline), _nonces);
        bytes memory permit2Sig = _getPermitBatchSignature(permitBatch, permit2DomainSeparator, PERMIT2_BATCH_TYPE_HASH);

        vm.prank(validatorSigner);
        IERC20(underlyingETH_USDC).approve(PERMIT2, amount);

        uint256 previewDepositAmount = IERC4626(yieldSourceUsdcAddressEth).previewDeposit(amount / 2);

        address[] memory srcHooksAddresses = new address[](5);
        srcHooksAddresses[0] = _getHookAddress(ETH, BATCH_TRANSFER_FROM_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[4] = _getHookAddress(ETH, OFFRAMP_TOKENS_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](5);
        srcHooksData[0] =
            _createBatchTransferFromHookData(validatorSigner, 1, sigDeadline, _tokens, _amounts, _nonces, permit2Sig);
        srcHooksData[1] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, amount / 2, false);
        srcHooksData[2] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            amount / 2,
            false,
            address(0),
            0
        );
        srcHooksData[3] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            accountCreated,
            previewDepositAmount,
            false
        );
        address[] memory offRampTokens = new address[](1);
        offRampTokens[0] = underlyingETH_USDC;
        srcHooksData[4] = _createOfframpTokensHookData(validatorSigner, offRampTokens);

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });
    }

    function _createPermitBatchData(
        address spender,
        address[] memory tokens,
        uint256[] memory amounts,
        uint48 expiration,
        uint48[] memory _nonces
    )
        private
        pure
        returns (IAllowanceTransfer.PermitBatch memory)
    {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](tokens.length);
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens[i],
                amount: uint160(amounts[i]),
                expiration: expiration,
                nonce: _nonces[i]
            });
        }

        return IAllowanceTransfer.PermitBatch({ details: details, spender: spender, sigDeadline: expiration });
    }

    function _getPermitBatchSignature(
        IAllowanceTransfer.PermitBatch memory permit,
        bytes32 domain,
        bytes32 typeHash
    )
        private
        view
        returns (bytes memory sig)
    {
        uint256 len = permit.details.length;
        bytes32[] memory permitHashes = new bytes32[](len);
        for (uint256 i; i < len; ++i) {
            permitHashes[i] = keccak256(abi.encode(PERMIT2_DETAILS_TYPE_HASH, permit.details[i]));
        }
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domain,
                keccak256(
                    abi.encode(typeHash, keccak256(abi.encodePacked(permitHashes)), permit.spender, permit.sigDeadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorSignerPrivateKey, messageHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function _createAccountCrossChainFlow() private returns (address) {
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
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);
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

        return accountToUse;
    }

    function _performAndAssert4626DepositOnETH(
        address acc,
        uint256 amount,
        bool validateBeforeBalance
    )
        private
        returns (uint256 obtainedShares)
    {
        _getTokens(underlyingETH_USDC, acc, amount);

        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            amount,
            false,
            address(0),
            0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        // before op asserts
        if (validateBeforeBalance) {
            uint256 accBalanceBefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(acc);
            assertEq(accBalanceBefore, 0);
        }

        // deposit
        _executeHooksThroughEntrypoint(acc, address(superExecutorOnETH), address(sourceValidatorOnETH), entry);

        // after op asserts
        obtainedShares = IERC4626(yieldSourceUsdcAddressEth).balanceOf(acc);
        assertGt(obtainedShares, 0);
    }

    function _performAndAssert4626RedeemOnETH(
        address acc,
        address exec,
        uint256 shares,
        bool validateBeforeBalance
    )
        private
        returns (uint256 obtainedShares)
    {
        address[] memory srcHooksAddresses = new address[](1);
        srcHooksAddresses[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](1);
        srcHooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
            acc,
            shares,
            false
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        // before op asserts
        if (validateBeforeBalance) {
            uint256 accBalanceBefore = IERC4626(yieldSourceUsdcAddressEth).balanceOf(acc);
            assertEq(accBalanceBefore, shares);
        }

        // redeem
        _executeHooksThroughEntrypoint(acc, address(exec), address(sourceValidatorOnETH), entry);

        // after op asserts
        obtainedShares = IERC4626(yieldSourceUsdcAddressEth).balanceOf(acc);
        assertEq(obtainedShares, 0);
    }

    function _installModuleOnAccount(
        address acc,
        uint256 moduleType,
        address module,
        bytes memory initData,
        address validatorToUse
    )
        private
    {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: acc,
            value: 0,
            callData: abi.encodeCall(IERC7579Account.installModule, (moduleType, module, initData))
        });

        PackedUserOperation memory userOp = _createPackedUserOperation(
            acc, _prepareNonceWithValidator(acc, validatorToUse), _prepareExecutionCalldata(executions)
        );

        _signAndSendUserOp(userOp, validatorToUse, acc, true, false);
    }

    function _uninstallModuleOnAccount(
        address acc,
        uint256 moduleType,
        address module,
        bytes memory initData,
        address validatorToUse
    )
        private
    {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: acc,
            value: 0,
            callData: abi.encodeCall(IERC7579Account.uninstallModule, (moduleType, module, initData))
        });

        PackedUserOperation memory userOp = _createPackedUserOperation(
            acc, _prepareNonceWithValidator(acc, validatorToUse), _prepareExecutionCalldata(executions)
        );

        _signAndSendUserOp(userOp, validatorToUse, acc, true, false);
    }

    function _executeHooksThroughEntrypoint(
        address account,
        address executor,
        address validator,
        ISuperExecutor.ExecutorEntry memory entry
    )
        internal
    {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        PackedUserOperation memory userOp = _createPackedUserOperation(
            account, _prepareNonceWithValidator(account, validator), _prepareExecutionCalldata(executions)
        );

        _signAndSendUserOp(userOp, validator, account, true, false);
    }

    function _signAndSendUserOp(
        PackedUserOperation memory userOp,
        address validator,
        address beneficiary,
        bool execute,
        bool shouldRevert
    )
        private
        returns (PackedUserOperation[] memory userOps)
    {
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(
            IEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOp), validUntil, 0, new uint64[](0), address(validator)
        );
        (bytes32[][] memory _proof, bytes32 _root) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSignature(_root);

        bytes memory sigData =
            abi.encode(new uint64[](0), validUntil, 0, _root, _proof[0], new ISuperValidator.DstProof[](0), signature);

        userOp.signature = sigData;

        userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        if (execute) {
            if (shouldRevert) {
                vm.expectRevert();
            }
            IEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(beneficiary));
        }
    }

    function _prepareExecutionCalldata(Execution[] memory executions)
        internal
        pure
        returns (bytes memory executionCalldata)
    {
        ModeCode mode;
        uint256 length = executions.length;

        if (length == 1) {
            mode = ModeLib.encodeSimpleSingle();
            executionCalldata = abi.encodeCall(
                INexus.execute,
                (mode, ExecutionLib.encodeSingle(executions[0].target, executions[0].value, executions[0].callData))
            );
        } else if (length > 1) {
            mode = ModeLib.encodeSimpleBatch();
            executionCalldata = abi.encodeCall(INexus.execute, (mode, ExecutionLib.encodeBatch(executions)));
        } else {
            revert("Executions array cannot be empty");
        }
    }

    function _prepareNonceWithValidator(address account, address validator) internal view returns (uint256 nonce) {
        uint192 nonceKey;
        bytes32 batchId = bytes3(0);
        bytes1 vMode = MODE_VALIDATION;
        assembly {
            nonceKey := or(shr(88, vMode), validator)
            nonceKey := or(shr(64, batchId), nonceKey)
        }
        nonce = IEntryPoint(ENTRYPOINT_ADDR).getNonce(account, nonceKey);
    }

    function _createPackedUserOperation(
        address account,
        uint256 nonce,
        bytes memory callData
    )
        internal
        pure
        returns (PackedUserOperation memory)
    {
        return PackedUserOperation({
            sender: account,
            nonce: nonce,
            initCode: "", //we assume contract is already deployed (following the Bundler flow)
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: "",
            signature: hex"1234"
        });
    }

    function _getSignature(bytes32 _root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode("SuperValidator", _root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorSignerPrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
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

    function _prepareOPDeposit4626Message(uint256 amountPerVault)
        internal
        returns (bytes memory message, address accountToUse, TargetExecutorMessage memory messageData)
    {
        {
            // PREPARE OP DATA - Target hooks that will be executed on OP
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
                targetAdapter: address(debridgeAdapterOnOP),
                targetExecutor: address(superTargetExecutorOnOP),
                nexusFactory: CHAIN_10_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_10_NEXUS_BOOTSTRAP,
                chainId: uint64(OP),
                amount: amountPerVault,
                account: address(0),
                tokenSent: underlyingOP_USDCe
            });

            (message, accountToUse) = _createTargetExecutorMessage(messageData, false);
        }
    }

    function _prepareETHUserOpData(
        uint256 amountPerVault,
        address accountToUse,
        TargetExecutorMessage memory messageData,
        bytes memory targetExecutorMessage
    )
        internal
        returns (UserOpData memory)
    {
        // PREPARE ETH DATA - Source hooks that will bridge from ETH to OP
        address[] memory ethHooksAddresses = new address[](2);
        ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[1] = _getHookAddress(ETH, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory ethHooksData = new bytes[](2);
        ethHooksData[0] = _createApproveHookData(underlyingETH_USDC, DEBRIDGE_DLN_ADDRESSES[ETH], amountPerVault, false);

        uint256 msgValue = IDlnSource(DEBRIDGE_DLN_ADDRESSES[ETH]).globalFixedNativeFee();

        bytes memory debridgeData = _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false,
                value: msgValue,
                giveTokenAddress: underlyingETH_USDC,
                giveAmount: amountPerVault,
                version: 1,
                fallbackAddress: accountToUse,
                executorAddress: address(debridgeAdapterOnOP),
                executionFee: uint160(0),
                allowDelayedExecution: false,
                requireSuccessfulExecution: true,
                payload: targetExecutorMessage,
                takeTokenAddress: underlyingOP_USDCe,
                takeAmount: amountPerVault,
                takeChainId: OP,
                receiverDst: address(debridgeAdapterOnOP),
                givePatchAuthoritySrc: address(0),
                orderAuthorityAddressDst: abi.encodePacked(accountToUse),
                allowedTakerDst: "",
                allowedCancelBeneficiarySrc: "",
                affiliateFee: "",
                referralCode: 0
            })
        );
        ethHooksData[1] = debridgeData;

        // Create and execute first user operation from ETH
        UserOpData memory ethUserOpData = _createUserOpData(ethHooksAddresses, ethHooksData, ETH, true);
        bytes memory ethSignatureData = _createMerkleRootAndSignature(
            messageData, ethUserOpData.userOpHash, accountToUse, OP, address(sourceValidatorOnETH)
        );
        ethUserOpData.userOp.signature = ethSignatureData;

        return ethUserOpData;
    }

    function _createBaseUserOp(
        uint256 amountPerVault,
        address accountToUse,
        bytes memory targetExecutorMessage
    )
        internal
        returns (UserOpData memory baseUserOpData)
    {
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        uint256 msgValue = IDlnSource(DEBRIDGE_DLN_ADDRESSES[BASE]).globalFixedNativeFee();

        // PREPARE BASE DATA - Source hooks that will bridge from BASE to OP
        address[] memory baseHooksAddressesReplay = new address[](2);
        baseHooksAddressesReplay[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        baseHooksAddressesReplay[1] = _getHookAddress(BASE, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory baseHooksDataReplay = new bytes[](2);
        baseHooksDataReplay[0] =
            _createApproveHookData(underlyingBase_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amountPerVault, false);

        bytes memory debridgeData = _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false,
                value: msgValue,
                giveTokenAddress: underlyingBase_USDC,
                giveAmount: amountPerVault,
                version: 1,
                fallbackAddress: accountToUse,
                executorAddress: address(debridgeAdapterOnOP),
                executionFee: uint160(0),
                allowDelayedExecution: false,
                requireSuccessfulExecution: true,
                payload: targetExecutorMessage,
                takeTokenAddress: underlyingOP_USDCe,
                takeAmount: amountPerVault,
                takeChainId: OP,
                receiverDst: address(debridgeAdapterOnOP),
                givePatchAuthoritySrc: address(0),
                orderAuthorityAddressDst: abi.encodePacked(accountToUse),
                allowedTakerDst: "",
                allowedCancelBeneficiarySrc: "",
                affiliateFee: "",
                referralCode: 0
            })
        );
        baseHooksDataReplay[1] = debridgeData;

        // Create user operation from BASE with same target message (replay attack)
        baseUserOpData = _createUserOpData(baseHooksAddressesReplay, baseHooksDataReplay, BASE, true);
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

    function _createUserOpDataWithCalldataTamper(
        uint256 amountPerVault,
        uint256 msgValue,
        address[] memory srcHooksAddresses,
        bytes[] memory srcHooksData,
        bytes memory originalPayload
    )
        internal
        returns (UserOpData memory)
    {
        bytes memory maliciousPayload = _createMaliciousPayload(originalPayload);

        // Create new debridge data with malicious payload
        bytes memory maliciousDebridgeData = _createDebridgeSendFundsAndExecuteHookData(
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
                payload: maliciousPayload, // Use malicious payload instead of original
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

        // Update the hooks data with malicious calldata
        srcHooksData[1] = maliciousDebridgeData;

        // Recreate user operation with tampered calldata
        return _createUserOpData(srcHooksAddresses, srcHooksData, BASE, true);
    }

    function _createMaliciousPayload(bytes memory originalPayload)
        internal
        pure
        returns (bytes memory maliciousPayload)
    {
        (
            bytes memory accountCreationData,
            bytes memory executionData,
            , // originalAccount
            address[] memory dstTokens,
            uint256[] memory intentAmounts
        ) = abi.decode(originalPayload, (bytes, bytes, address, address[], uint256[]));

        // Change the account to a malicious address (attacker's address)
        address maliciousAccount = address(0xDEADBEEF);
        maliciousPayload = abi.encode(
            accountCreationData,
            executionData,
            maliciousAccount, // Changed from originalAccount
            dstTokens,
            intentAmounts
        );
    }

    /// @notice Helper function to create destination message data for used root test
    /// @param amount Amount to use for destination setup
    /// @param accountToUse The account address to use (if known)
    /// @return messageData The target executor message data
    function _createDestinationMessageDataForUsedRoot(
        uint256 amount,
        address accountToUse
    )
        internal
        view
        returns (TargetExecutorMessage memory messageData)
    {
        // Set up destination hooks and data
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, amount, false);
        dstHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressBase,
            amount,
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
            account: accountToUse,
            tokenSent: underlyingBase_USDC
        });
    }

    /// @notice Helper function to setup destination chain for used root test
    /// @param amount Amount to use for destination setup
    /// @return targetExecutorMessage The encoded target executor message
    /// @return accountToUse The account address to use
    function _setupDestinationForUsedRoot(uint256 amount)
        internal
        returns (bytes memory targetExecutorMessage, address accountToUse)
    {
        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        TargetExecutorMessage memory messageData = _createDestinationMessageDataForUsedRoot(amount, accountBase);
        return _createTargetExecutorMessage(messageData, false);
    }

    /// @notice Helper function to setup source chain and execute for used root test
    /// @param params The test parameters containing amounts and target message
    function _setupSourceAndExecuteUsedRoot(BridgeDeposit4626UsedRootParams memory params) internal {
        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        // Set up source hooks and data
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);

        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], params.amount, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            existingUnderlyingTokens[ETH][USDC_KEY],
            existingUnderlyingTokens[BASE][USDC_KEY],
            params.amount,
            params.amount,
            BASE,
            false,
            params.targetExecutorMessage
        );

        params.entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: srcHooksAddresses, hooksData: srcHooksData });

        params.srcUserOpData = _getExecOpsWithValidator(
            instanceOnETH, superExecutorOnETH, abi.encode(params.entry), address(sourceValidatorOnETH)
        );

        // Use the same message data creation logic to ensure consistency
        TargetExecutorMessage memory messageDataForSig =
            _createDestinationMessageDataForUsedRoot(params.amount, params.accountToUse);

        params.signatureData = _createMerkleRootAndSignature(
            messageDataForSig, params.srcUserOpData.userOpHash, params.accountToUse, BASE, address(sourceValidatorOnETH)
        );
    }

    /// @notice Helper function to setup destination chain for rebalance test
    /// @param previewRedeemAmount Amount to use for destination setup
    /// @param srcAmount The source amount (used in messageData)
    /// @return targetExecutorMessage The encoded target executor message
    /// @return accountToUse The account address to use
    function _setupDestinationForRebalance(
        uint256 previewRedeemAmount,
        uint256 srcAmount
    )
        internal
        returns (bytes memory targetExecutorMessage, address accountToUse, TargetExecutorMessage memory messageData)
    {
        // BASE IS DST
        SELECT_FORK_AND_WARP(BASE, block.timestamp);

        TargetExecutorMessage memory msgData = TargetExecutorMessage({
            hooksAddresses: _createRebalanceDestinationHooksAddresses(),
            hooksData: _createRebalanceDestinationHooksData(previewRedeemAmount),
            validator: address(destinationValidatorOnBase),
            signer: validatorSigners[BASE],
            signerPrivateKey: validatorSignerPrivateKeys[BASE],
            targetAdapter: address(acrossV3AdapterOnBase),
            targetExecutor: address(superTargetExecutorOnBase),
            nexusFactory: CHAIN_8453_NEXUS_FACTORY,
            nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
            chainId: uint64(BASE),
            amount: srcAmount,
            account: accountBase,
            tokenSent: underlyingBase_USDC
        });

        (bytes memory targetMsg, address account) = _createTargetExecutorMessage(msgData, false);
        return (targetMsg, account, msgData);
    }

    /// @notice Create destination hooks addresses for rebalance test
    function _createRebalanceDestinationHooksAddresses() internal view returns (address[] memory) {
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);
        return dstHooksAddresses;
    }

    /// @notice Create destination hooks data for rebalance test
    function _createRebalanceDestinationHooksData(uint256 previewRedeemAmount) internal view returns (bytes[] memory) {
        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, yieldSourceMorphoUsdcAddressBase, previewRedeemAmount, false);
        dstHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceMorphoUsdcAddressBase,
            previewRedeemAmount,
            false,
            address(0),
            0
        );
        return dstHooksData;
    }

    /// @notice Execute rebalance on source chain
    /// @param amount Source amount for deposit
    /// @param previewRedeemAmount Amount for cross-chain transfer
    /// @param targetExecutorMessage Target executor message for cross-chain
    /// @param accountToUse Account to use for execution
    /// @return executionData The execution return data
    function _executeRebalanceSourceChain(
        uint256 amount,
        uint256 previewRedeemAmount,
        bytes memory targetExecutorMessage,
        address accountToUse,
        TargetExecutorMessage memory messageData
    )
        internal
        returns (ExecutionReturnData memory executionData)
    {
        // ETH is SRC
        SELECT_FORK_AND_WARP(ETH, block.timestamp);

        address[] memory srcHooksAddresses = new address[](4);
        srcHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        srcHooksAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[3] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](4);
        srcHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSourceUsdcAddressEth, amount, false);
        srcHooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
            yieldSourceUsdcAddressEth,
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

        // Use the messageData passed from destination setup to ensure signature matches
        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, BASE, address(sourceValidatorOnETH)
        );
        srcUserOpData.userOp.signature = signatureData;

        return executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnETH, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    COMPREHENSIVE HELPER FUNCTIONS FOR STACK OPTIMIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Create empty target executor message for account creation
    /// @param chainId Target chain ID
    /// @param account Target account address
    /// @param validatorAddr Validator address
    /// @param signerAddr Signer address
    /// @param signerPrivKey Signer private key
    /// @param targetAdapter Target adapter address
    /// @param targetExecutor Target executor address
    /// @param nexusFactory Nexus factory address
    /// @param nexusBootstrapAddr Nexus bootstrap address
    /// @param amount Amount for the operation
    /// @param tokenSent Token being sent
    /// @return The target executor message
    function _createEmptyTargetExecutorMessage(
        uint64 chainId,
        address account,
        address validatorAddr,
        address signerAddr,
        uint256 signerPrivKey,
        address targetAdapter,
        address targetExecutor,
        address nexusFactory,
        address nexusBootstrapAddr,
        uint256 amount,
        address tokenSent
    )
        internal
        pure
        returns (TargetExecutorMessage memory)
    {
        return TargetExecutorMessage({
            hooksAddresses: new address[](0),
            hooksData: new bytes[](0),
            validator: validatorAddr,
            signer: signerAddr,
            signerPrivateKey: signerPrivKey,
            targetAdapter: targetAdapter,
            targetExecutor: targetExecutor,
            nexusFactory: nexusFactory,
            nexusBootstrap: nexusBootstrapAddr,
            chainId: chainId,
            amount: amount,
            account: account,
            tokenSent: tokenSent
        });
    }

    /// @notice Create target executor message for ERC4626 deposit on BASE
    /// @param amount Amount for the operation
    /// @param account Target account address
    /// @return The target executor message
    function _createERC4626DepositTargetMessage(
        uint256 amount,
        address account
    )
        internal
        view
        returns (TargetExecutorMessage memory)
    {
        return TargetExecutorMessage({
            hooksAddresses: _createRebalanceDestinationHooksAddresses(),
            hooksData: _createRebalanceDestinationHooksData(amount),
            validator: address(destinationValidatorOnBase),
            signer: validatorSigners[BASE],
            signerPrivateKey: validatorSignerPrivateKeys[BASE],
            targetAdapter: address(acrossV3AdapterOnBase),
            targetExecutor: address(superTargetExecutorOnBase),
            nexusFactory: CHAIN_8453_NEXUS_FACTORY,
            nexusBootstrap: CHAIN_8453_NEXUS_BOOTSTRAP,
            chainId: uint64(BASE),
            amount: amount,
            account: account,
            tokenSent: underlyingBase_USDC
        });
    }

    /// @notice Create target executor message for ERC7540 operations on ETH
    /// @param amount Amount for the operation
    /// @param account Target account address
    /// @param isRequestDeposit Whether this is a request deposit operation
    /// @return The target executor message
    function _createERC7540TargetMessage(
        uint256 amount,
        address account,
        bool isRequestDeposit
    )
        internal
        view
        returns (TargetExecutorMessage memory)
    {
        address[] memory eth7540HooksAddresses = new address[](2);
        eth7540HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        eth7540HooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory eth7540HooksData = new bytes[](2);
        eth7540HooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressETH_USDC, amount, false);

        if (isRequestDeposit) {
            eth7540HooksData[1] = _createRequestDeposit7540VaultHookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER), address(0), 0, false
            );
        } else {
            eth7540HooksData[1] = _createRequestDeposit7540VaultHookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSource7540AddressETH_USDC,
                amount,
                true
            );
        }

        return TargetExecutorMessage({
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
            amount: amount,
            account: account,
            tokenSent: underlyingETH_USDC
        });
    }

    /// @notice Optimize _sendDeBridgeOrder function by extracting complex struct creation
    function _createDeBridgeTargetMessage(uint256 amountPerVault)
        internal
        view
        returns (TargetExecutorMessage memory)
    {
        return _createEmptyTargetExecutorMessage(
            uint64(ETH),
            accountETH,
            address(destinationValidatorOnETH),
            validatorSigners[ETH],
            validatorSignerPrivateKeys[ETH],
            address(debridgeAdapterOnETH),
            address(superTargetExecutorOnETH),
            CHAIN_1_NEXUS_FACTORY,
            CHAIN_1_NEXUS_BOOTSTRAP,
            amountPerVault,
            underlyingETH_USDC
        );
    }

    /// @notice Optimized _sendDeBridgeOrder function with extracted helpers
    function _sendDeBridgeOrderOptimized() internal returns (bytes memory) {
        uint256 amountPerVault = 1e8;

        // Base is src
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME + 30 days);

        return _executeDeBridgeOrder(amountPerVault);
    }

    /// @notice Execute DeBridge order with optimized structure
    function _executeDeBridgeOrder(uint256 amountPerVault) internal returns (bytes memory) {
        // PREPARE BASE DATA
        address[] memory baseHooksAddresses = new address[](2);
        baseHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        baseHooksAddresses[1] = _getHookAddress(BASE, DEBRIDGE_SEND_ORDER_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory baseHooksData = new bytes[](2);
        baseHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, DEBRIDGE_DLN_ADDRESSES[BASE], amountPerVault, false);

        uint256 msgValue = IDlnSource(DEBRIDGE_DLN_ADDRESSES[BASE]).globalFixedNativeFee();

        // Create optimized target message
        TargetExecutorMessage memory messageData = _createDeBridgeTargetMessage(amountPerVault);
        (bytes memory innerExecutorPayload, address accountToUse) = _createTargetExecutorMessage(messageData, false);

        // Create DeBridge data
        bytes memory debridgeData = _createDebridgeOrderData(amountPerVault, msgValue, innerExecutorPayload);
        baseHooksData[1] = debridgeData;

        UserOpData memory baseUserOpData = _createUserOpData(baseHooksAddresses, baseHooksData, BASE, true);

        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, baseUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        baseUserOpData.userOp.signature = signatureData;

        executeOpsThroughPaymaster(baseUserOpData, superNativePaymasterOnBase, 1e18);
        return signatureData;
    }

    /// @notice Create DeBridge order data with extracted structure
    function _createDebridgeOrderData(
        uint256 amountPerVault,
        uint256 msgValue,
        bytes memory innerExecutorPayload
    )
        internal
        view
        returns (bytes memory)
    {
        return _createDebridgeSendFundsAndExecuteHookData(
            DebridgeOrderData({
                usePrevHookAmount: false,
                value: msgValue,
                giveTokenAddress: underlyingBase_USDC,
                giveAmount: amountPerVault,
                version: 1,
                fallbackAddress: address(0),
                executorAddress: address(debridgeAdapterOnETH),
                executionFee: uint160(0),
                allowDelayedExecution: false,
                requireSuccessfulExecution: true,
                payload: innerExecutorPayload,
                takeTokenAddress: underlyingETH_USDC,
                takeAmount: amountPerVault - amountPerVault * 1e4 / 1e5,
                takeChainId: ETH,
                receiverDst: address(debridgeAdapterOnETH),
                givePatchAuthoritySrc: address(0),
                orderAuthorityAddressDst: abi.encodePacked(accountETH),
                allowedTakerDst: abi.encodePacked(accountETH),
                allowedCancelBeneficiarySrc: abi.encodePacked(accountBase),
                affiliateFee: "",
                referralCode: 0
            })
        );
    }

    function _createFakeSignatureData(
        bytes32 fakeRoot,
        uint256 seed,
        uint64 dstChain
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32[] memory emptyProof = new bytes32[](0);

        bytes32 r = bytes32(uint256(keccak256(abi.encode("r", seed))));
        bytes32 s = bytes32(uint256(keccak256(abi.encode("s", seed))));
        uint8 v = uint8(27 + (seed % 2)); // Either 27 or 28

        bytes memory signature = abi.encodePacked(r, s, v);

        uint64[] memory chainsWithDestExecutionCtx = new uint64[](1);
        chainsWithDestExecutionCtx[0] = dstChain;
        return abi.encode(
            chainsWithDestExecutionCtx,
            uint48(block.timestamp + 1 days), // validUntil
            fakeRoot,
            emptyProof,
            new ISuperValidator.DstProof[](0), // Empty proof
            signature
        );
    }
}
