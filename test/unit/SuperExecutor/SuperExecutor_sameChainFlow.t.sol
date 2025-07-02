// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { Swap1InchHook } from "../../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/core/interfaces/ISuperValidator.sol";
import { SuperExecutor } from "../../../src/core/executors/SuperExecutor.sol";
import "../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";

import { Mock1InchRouter, MockDex } from "../../mocks/Mock1InchRouter.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { MockSuperPositionFactory } from "../../mocks/MockSuperPositionFactory.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import "forge-std/console2.sol";

import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { ERC7579Precompiles } from "modulekit/deployment/precompiles/ERC7579Precompiles.sol";
import "modulekit/accounts/erc7579/ERC7579Factory.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { SignatureHelper } from "../../utils/SignatureHelper.sol";

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData,
    PackedUserOperation
} from "modulekit/ModuleKit.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { ERC4626YieldSourceOracle } from "../../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ApproveERC20Hook } from "../../../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../../src/core/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { MintSuperPositionsHook } from "../../../src/core/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";
import { Redeem4626VaultHook } from "../../../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { SuperLedger } from "../../../src/core/accounting/SuperLedger.sol";
import { MockSwapOdosHook } from "../../mocks/unused-hooks/MockSwapOdosHook.sol";
import { MockOdosRouterV2 } from "../../mocks/MockOdosRouterV2.sol";
import { SuperMerkleValidator } from "../../../src/core/validators/SuperMerkleValidator.sol";
import { SuperValidatorBase } from "../../../src/core/validators/SuperValidatorBase.sol";
import { VaultBank } from "../../../src/periphery/VaultBank/VaultBank.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";

contract SuperExecutor_sameChainFlow is
    Helpers,
    RhinestoneModuleKit,
    InternalHelpers,
    ERC7579Precompiles,
    SignatureHelper,
    MerkleTreeHelper
{
    using BytesLib for bytes;
    using AddressLib for Address;
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;
    address public account;
    AccountInstance public instance;
    ISuperExecutor public superExecutor;
    ISuperExecutor public newSuperExecutor;
    address ledgerConfig;
    ISuperLedger public ledger;
    MockSuperPositionFactory public mockSuperPositionFactory;
    SuperGovernor public superGovernor;
    VaultBank public vaultBank;

    uint256 eoaKey;
    address account7702;
    ERC7579Factory erc7579factory;
    IERC7579Account erc7579account;
    IERC7579Bootstrap bootstrapDefault;

    address approveHook;
    address deposit4626Hook;
    address redeem4626Hook;
    address mockSwapOdosHook;
    address mockOdosRouter;
    address mintSuperPositionsHook;
    SuperMerkleValidator public validator;

    address public signer;
    uint256 public signerPrvKey;

    address feeRecipient;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);
        underlying = CHAIN_1_USDC;
        ledgerConfig = address(new SuperLedgerConfiguration());

        yieldSourceAddress = CHAIN_1_MorphoVault;
        yieldSourceOracle = address(new ERC4626YieldSourceOracle(address(ledgerConfig)));
        vaultInstance = IERC4626(yieldSourceAddress);
        instance = makeAccountInstance(keccak256(abi.encode("acc1")));
        account = instance.account;

        validator = new SuperMerkleValidator();
        vm.label(address(validator), "Validator source");

        _getTokens(underlying, account, 1e18);

        (signer, signerPrvKey) = makeAddrAndKey("signer");

        superExecutor = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        newSuperExecutor = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(signer)
        });

        address[] memory allowedExecutors = new address[](2);
        allowedExecutors[0] = address(superExecutor);
        allowedExecutors[1] = address(newSuperExecutor);
        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        feeRecipient = makeAddr("feeRecipient");
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: 100,
            feeRecipient: feeRecipient,
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        ISuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);

        eoaKey = uint256(8);
        account7702 = vm.addr(eoaKey);
        vm.label(account7702, "7702CompliantAccount");
        vm.deal(account7702, LARGE);

        erc7579factory = new ERC7579Factory();
        erc7579account = deployERC7579Account();
        assertGt(address(erc7579account).code.length, 0);
        vm.label(address(erc7579account), "ERC7579Account");

        bootstrapDefault = deployERC7579Bootstrap();
        vm.label(address(bootstrapDefault), "ERC7579Bootstrap");

        approveHook = address(new ApproveERC20Hook());
        deposit4626Hook = address(new Deposit4626VaultHook());
        redeem4626Hook = address(new Redeem4626VaultHook());
        mintSuperPositionsHook = address(new MintSuperPositionsHook());

        // mocks
        mockSuperPositionFactory = new MockSuperPositionFactory(address(this));
        vm.label(address(mockSuperPositionFactory), "MockSuperPositionFactory");

        mockOdosRouter = address(new MockOdosRouterV2());
        mockSwapOdosHook = address(new MockSwapOdosHook(mockOdosRouter));

        superGovernor = new SuperGovernor(address(this), address(this), address(this), address(this), address(this));
        superGovernor.addExecutor(address(superExecutor));
        superGovernor.addExecutor(address(newSuperExecutor));
        vaultBank = new VaultBank(address(superGovernor));
        superGovernor.addVaultBank(uint64(block.chainid), address(vaultBank));
        superGovernor.registerHook(address(approveHook), false);
        superGovernor.registerHook(address(deposit4626Hook), false);
        superGovernor.registerHook(address(redeem4626Hook), false);
        superGovernor.registerHook(address(mintSuperPositionsHook), false);
    }

    /*//////////////////////////////////////////////////////////////
                            MAIN TESTS
    //////////////////////////////////////////////////////////////*/
    function test_ExecuteWithUpdateAccounting_Native() external {
        uint256 amount = 1e18;

        MockHook _depositHook = new MockHook(ISuperHook.HookType.INFLOW, address(underlying));
        vm.label(address(_depositHook), "_depositHook");
        MockHook _redeemHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(underlying));
        vm.label(address(_redeemHook), "_redeemHook");
        Mock4626Vault vault = new Mock4626Vault(underlying, "Mock4626Vault", "Mock4626Vault");
        vm.label(address(vault), "_vault");

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(_depositHook);
        hooksAddresses[2] = address(_redeemHook);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlying, address(vault), amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(vault), amount, false, address(0), 0
        );
        hooksData[2] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(vault), account, amount, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        Execution[] memory depositExecutions = new Execution[](1);
        depositExecutions[0] = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.deposit, (amount, account))
        });
        _depositHook.setExecutions(depositExecutions);
        _depositHook.setOutAmount(amount, address(this));

        Execution[] memory redeemExecutions = new Execution[](1);
        redeemExecutions[0] = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.redeem, (amount, account, account))
        });
        _redeemHook.setExecutions(redeemExecutions);
        _redeemHook.setUsedShares(amount);
        _redeemHook.setOutAmount(amount * 2, address(this));
        _redeemHook.setAsset(address(0));

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(feeRecipient.balance, amount * 1e2 / 1e4);
    }

    function test_ExecuteWithUpdateAccounting_NewExecutor() external {
        uint256 amount = 1e18;

        MockHook _depositHook = new MockHook(ISuperHook.HookType.INFLOW, address(underlying));
        vm.label(address(_depositHook), "_depositHook");
        MockHook _redeemHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(underlying));
        vm.label(address(_redeemHook), "_redeemHook");
        Mock4626Vault vault = new Mock4626Vault(underlying, "Mock4626Vault", "Mock4626Vault");
        vm.label(address(vault), "_vault");

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(_depositHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, address(vault), amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(vault), amount, false, address(0), 0
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        Execution[] memory depositExecutions = new Execution[](1);
        depositExecutions[0] = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.deposit, (amount, account))
        });
        _depositHook.setExecutions(depositExecutions);
        _depositHook.setOutAmount(amount, address(this));

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        // install new executor
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(newSuperExecutor), data: "" });

        hooksAddresses = new address[](1);
        hooksAddresses[0] = address(_redeemHook);

        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), address(vault), account, amount, false
        );

        Execution[] memory redeemExecutions = new Execution[](1);
        redeemExecutions[0] = Execution({
            target: address(vault),
            value: 0,
            callData: abi.encodeCall(IERC4626.redeem, (amount, account, account))
        });
        _redeemHook.setExecutions(redeemExecutions);
        _redeemHook.setUsedShares(amount);
        _redeemHook.setOutAmount(amount * 2, address(this));
        _redeemHook.setAsset(address(0));

        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOpsWithValidator(instance, newSuperExecutor, abi.encode(entry), address(validator));
        validUntil = uint48(block.timestamp + 100 days);
        sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);

        assertEq(feeRecipient.balance, amount * 1e2 / 1e4);
    }

    function test_ShouldExecuteAll_AndLockAssetsInVaultBank_Test2HookChaining(uint256 amount) external {
        AccountInstance memory testInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address testAccount = testInstance.account;

        testInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        testInstance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(signer)
        });

        amount = _bound(amount);

        superGovernor.addVaultBank(8453, address(vaultBank));

        _getTokens(underlying, testAccount, amount);

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(deposit4626Hook);
        hooksAddresses[2] = address(mintSuperPositionsHook);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, false, address(vaultBank), 8453
        );

        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);
        hooksData[2] = _createApproveAndLockVaultBankHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, sharesPreviewed, false, address(vaultBank), 8453
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(testInstance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(address(vaultBank));
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_ShouldExecuteAll_AndLockAssetsInVaultBank_Test1ExistingShares(uint256 amount) external {
        AccountInstance memory testInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address testAccount = testInstance.account;

        testInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        testInstance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(signer)
        });

        amount = _bound(amount);

        superGovernor.addVaultBank(8453, address(vaultBank));

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(mintSuperPositionsHook);

        bytes[] memory hooksData = new bytes[](1);
        _getTokens(yieldSourceAddress, testAccount, amount);
        hooksData[0] = _createApproveAndLockVaultBankHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, false, address(vaultBank), 8453
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(testInstance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(address(vaultBank));
        assertEq(accSharesAfter, amount);
    }

    function test_ShouldExecuteAll_MerkleValidator(uint256 amount) external {
        AccountInstance memory testInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address testAccount = testInstance.account;

        testInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        testInstance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(signer)
        });

        amount = _bound(amount);

        _getTokens(underlying, testAccount, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(deposit4626Hook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, false, address(0), 0
        );
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(testInstance, superExecutor, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(testAccount);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
    {
        amount = _bound(amount);
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(deposit4626Hook);
        hooksAddresses[2] = address(redeem4626Hook);

        console2.log("--- setter", address(this));
        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, false, address(0), 0
        );
        hooksData[2] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, account, amount, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);
    }

    function test_SwapThrough1InchHook_GenericRouterCall() public {
        uint256 amount = SMALL;

        address executor = address(new Mock1InchRouter());
        vm.label(executor, "Mock1InchRouter");

        Swap1InchHook hook = new Swap1InchHook(executor);
        vm.label(address(hook), SWAP_1INCH_HOOK_KEY);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);

        I1InchAggregationRouterV6.SwapDescription memory desc = I1InchAggregationRouterV6.SwapDescription({
            srcToken: IERC20(underlying),
            dstToken: IERC20(underlying),
            srcReceiver: payable(account),
            dstReceiver: payable(account),
            amount: amount,
            minReturnAmount: amount,
            flags: 0
        });
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _create1InchGenericRouterSwapHookData(account, underlying, executor, desc, "", false);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThrough1InchHook_UnoswapToCall() public {
        uint256 amount = SMALL;

        address executor = address(new Mock1InchRouter());
        vm.label(executor, "Mock1InchRouter");

        Swap1InchHook hook = new Swap1InchHook(executor);
        vm.label(address(hook), SWAP_1INCH_HOOK_KEY);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);

        MockDex mockDex = new MockDex(underlying, underlying);
        vm.label(address(mockDex), "MockDex");

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _create1InchUnoswapToHookData(
            account,
            underlying,
            Address.wrap(uint256(uint160(account))),
            Address.wrap(uint256(uint160(underlying))),
            amount,
            amount,
            Address.wrap(uint256(uint160(address(mockDex)))),
            false
        );

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThrough1InchHook_ClipperSwapToCall() public {
        uint256 amount = SMALL;

        address executor = address(new Mock1InchRouter());
        vm.label(executor, "Mock1InchRouter");

        Swap1InchHook hook = new Swap1InchHook(executor);
        vm.label(address(hook), SWAP_1INCH_HOOK_KEY);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _create1InchClipperSwapToHookData(
            account, underlying, executor, Address.wrap(uint256(uint160(underlying))), amount, false
        );

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThroughOdosRouter(uint256 amount) external {
        amount = _bound(amount);

        MockERC20 inputToken = new MockERC20("A", "A", 18);
        MockERC20 outputToken = new MockERC20("B", "B", 18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = mockSwapOdosHook;

        _getTokens(address(inputToken), account, amount);
        _getTokens(address(outputToken), mockOdosRouter, amount);

        bytes memory approveData = _createApproveHookData(address(inputToken), mockOdosRouter, amount, false);

        bytes memory odosCallData;
        odosCallData = _createMockOdosSwapHookData(
            address(inputToken),
            amount,
            account,
            address(outputToken),
            amount,
            amount,
            "",
            address(this),
            uint32(0),
            false
        );

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = approveData;
        hooksData[1] = odosCallData;

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);
    }

    function test_SwapNativeThroughOdosAndDeposit4626() external {
        uint256 amount = 1 ether;

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = address(mockSwapOdosHook);
        hooksAddresses[1] = address(approveHook);
        hooksAddresses[2] = address(deposit4626Hook);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createOdosSwapHookData(
            address(0), // ETH
            amount,
            account,
            address(underlying),
            amount,
            amount,
            "",
            address(this),
            uint32(0),
            false
        );
        hooksData[1] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[2] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, false, address(0), 0
        );
        uint256 routerEthBalanceBefore = address(mockOdosRouter).balance;
        _getTokens(address(underlying), mockOdosRouter, amount);

        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);

        uint256 routerEthBalanceAfter = address(mockOdosRouter).balance;
        assertEq(routerEthBalanceAfter, routerEthBalanceBefore + amount);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_SwapUnderlyingToNativeAndThenUnderlying() external {
        uint256 amount = 1 ether;

        _getTokens(address(underlying), mockOdosRouter, amount);
        vm.deal(address(mockOdosRouter), amount);

        address[] memory hooksAddresses = new address[](5);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = mockSwapOdosHook;
        hooksAddresses[2] = mockSwapOdosHook;
        hooksAddresses[3] = address(approveHook);
        hooksAddresses[4] = address(deposit4626Hook);

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, mockOdosRouter, amount, false);
        hooksData[1] = _createOdosSwapHookData(
            address(underlying),
            amount,
            account,
            address(0), // ETH
            amount,
            amount,
            "",
            address(this),
            uint32(0),
            false
        );
        hooksData[2] = _createOdosSwapHookData(
            address(0), // ETH
            amount,
            account,
            address(underlying), // ETH
            amount,
            amount,
            "",
            address(this),
            uint32(0),
            false
        );
        hooksData[3] = _createApproveHookData(underlying, yieldSourceAddress, amount, true);
        hooksData[4] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, true, address(0), 0
        );

        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceData(validUntil, userOpData);
        userOpData.userOp.signature = sigData;
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertApproxEqRel(accSharesAfter, sharesPreviewed, 0.05e18);
    }

    /*//////////////////////////////////////////////////////////////
                            EXPERIMENTAL TESTS
    //////////////////////////////////////////////////////////////*/
    struct Test7579MethodsVars {
        uint256 amount;
        AccountInstance instance;
        bytes setValueCalldata;
        bytes userOpCalldata;
        uint192 key;
        uint256 nonce;
        bytes signature;
        PackedUserOperation[] userOps;
        bool success;
        bytes result;
        bool opsSuccess;
        bytes opsResult;
    }

    function test_7702_SuperExecutor(uint256 amount)
        external
        add7702Precompile(account7702, address(erc7579account).code)
    {
        Test7579MethodsVars memory vars;
        vars.instance = instance;
        amount = _bound(amount);

        // prepare useOp
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(approveHook);
        hooksAddresses[1] = address(deposit4626Hook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSourceAddress, amount, false, address(0), 0
        );

        // assure account has tokens
        _getTokens(underlying, account7702, amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Question: is this just a getter method or does it have side effects?
        // Since it is not defined as view I assume it has side effects so I did not remove it but the `get` in the name
        // is misleading since it suggests it is just a getter, so better to check this
        _getExecOps(instance, superExecutor, abi.encode(entry));

        //bytes memory initData = _get7702InitDataWithExecutor(address(_defaultValidator), "");
        bytes memory initData = _get7702InitData();
        Execution[] memory executions = new Execution[](3);
        executions[0] =
            Execution({ target: account7702, value: 0, callData: abi.encodeCall(IMSA.initializeAccount, initData) });
        executions[1] = Execution({
            target: account7702,
            value: 0,
            callData: abi.encodeCall(IERC7579Account.installModule, (MODULE_TYPE_EXECUTOR, address(superExecutor), ""))
        });
        executions[2] = Execution({
            target: address(superExecutor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)))
        });

        vars.userOpCalldata =
            abi.encodeCall(IERC7579Account.execute, (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)));

        vars.key = uint192(bytes24(bytes20(address(_defaultValidator))));
        vars.nonce = vars.instance.aux.entrypoint.getNonce(address(account7702), vars.key);

        // prepare PackedUserOperation
        vars.userOps = new PackedUserOperation[](1);
        vars.userOps[0] = _getDefaultUserOp();
        vars.userOps[0].sender = account7702;
        vars.userOps[0].nonce = vars.nonce;
        vars.userOps[0].callData = vars.userOpCalldata;
        vars.userOps[0].signature = _getSignature(vars.userOps[0], vars.instance.aux.entrypoint);

        assertGt(account7702.code.length, 0);

        vars.instance.aux.entrypoint.handleOps(vars.userOps, payable(address(0x69)));

        uint256 accSharesAfter = vaultInstance.balanceOf(account7702);
        assertGt(accSharesAfter, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _createSourceData(
        uint48 validUntil,
        UserOpData memory userOpData
    )
        private
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpData.userOpHash, validUntil, false, address(validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);

        bytes memory signature =
            _createSignature(SuperValidatorBase(address(validator)).namespace(), merkleRoot, signer, signerPrvKey);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _get7702InitData() internal view returns (bytes memory) {
        bytes memory initData = erc7579factory.getInitData(address(_defaultValidator), "");
        return initData;
    }

    function _get7702InitDataWithExecutor(
        address _validator,
        bytes memory initData
    )
        public
        view
        returns (bytes memory _init)
    {
        ERC7579BootstrapConfig[] memory _validators = new ERC7579BootstrapConfig[](1);
        _validators[0].module = _validator;
        _validators[0].data = initData;
        ERC7579BootstrapConfig[] memory _executors = new ERC7579BootstrapConfig[](1);
        _executors[0].module = address(superExecutor);

        ERC7579BootstrapConfig memory _hook;

        ERC7579BootstrapConfig[] memory _fallBacks = new ERC7579BootstrapConfig[](0);
        _init = abi.encode(
            address(bootstrapDefault),
            abi.encodeCall(IERC7579Bootstrap.initMSA, (_validators, _executors, _hook, _fallBacks))
        );
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

    function _getSignature(
        PackedUserOperation memory userOp,
        IEntryPoint entrypoint
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 hash = entrypoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaKey, _toEthSignedMessageHash(hash));
        return abi.encodePacked(r, s, v);
    }
}
