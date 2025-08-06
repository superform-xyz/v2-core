// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import {
    UserOpData, AccountType, AccountInstance, ModuleKitHelpers, PackedUserOperation
} from "modulekit/ModuleKit.sol";
import { IStakeManager } from "modulekit/external/ERC4337.sol";
import { SafeFactory } from "modulekit/accounts/safe/SafeFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISafe7579 } from "modulekit/accounts/safe/interfaces/ISafe7579.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { ISafe7579Launchpad, ModuleInit } from "modulekit/accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { Safe7579Precompiles } from "modulekit/deployment/precompiles/Safe7579Precompiles.sol";
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

contract SafeAccountExecutionTests is BaseTest, Safe7579Precompiles {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;
    using BytesLib for bytes;

    struct SignatureData {
        bytes32 rawHash;
        bytes32 domainSeparator;
        bytes32 finalHash;
        uint8 v1;
        uint8 v2;
        uint8 v3;
        bytes32 r1;
        bytes32 r2;
        bytes32 r3;
        bytes32 s1;
        bytes32 s2;
        bytes32 s3;
        address recovered1;
        address recovered2;
        address recovered3;
    }

    address public owner1;
    address public owner2;
    address public owner3;
    address[] public owners;

    bytes32 public accountSalt;

    uint256 public privateKey1;
    uint256 public privateKey2;
    uint256 public privateKey3;

    uint256 public threshold;

    uint256 public amount = 1000e6;

    uint256 public timestampETH;
    uint256 public timestampBase;
    uint256 public warpStartTime;

    address public accountETH;
    address public accountBase;

    AccountInstance public instanceETH;
    AccountInstance public instanceBase;

    address public addressOracleETH;
    address public addressOracleBase;

    address public underlyingETH_USDC;
    address public underlyingBase_USDC;

    SuperValidator public validator;
    IValidator public validatorOnETH;
    IValidator public validatorOnBase;

    SuperLedger public superLedgerETH;
    SuperLedger public superLedgerBase;

    SuperExecutor public superExecutorETH;
    SuperExecutor public superExecutorBase;
    ISuperExecutor public superExecutorETHInterface;
    ISuperExecutor public superExecutorBaseInterface;

    AcrossV3Adapter public acrossAdapterETH;
    AcrossV3Adapter public acrossAdapterBase;

    IERC4626 public vaultInstanceMorphoETH;
    IERC4626 public vaultInstanceMorphoBase;

    address public yieldSource4626AddressETH;
    address public yieldSource4626AddressBase;

    bytes32 public yieldSourceOracleId;

    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleBase;

    ISuperDestinationExecutor public targetExecutorETH;
    ISuperDestinationExecutor public targetExecutorBase;

    bytes4 public constant ERC1271_MAGICVALUE = 0x1626ba7e;

    struct CrossChainVars {
        uint256 warpStartTime;
        bytes initData;
        address predictedAddress;
        bytes initCode;
        // Account instances
        AccountInstance instanceETH;
        AccountInstance instanceBase;
        address accountETH;
        address accountBase;
        // Message data
        bytes targetExecutorMessage;
        TargetExecutorMessage messageData;
        address accountToUse;
        // Target chain (ETH) data
        address[] ethHooksAddresses;
        bytes[] ethHooksData;
        uint256 previewDepositAmountETH;
        // Source chain (BASE) data
        address[] srcHooksAddresses;
        bytes[] srcHooksData;
        uint256 userBalanceBaseUSDCBefore;
        ISuperExecutor.ExecutorEntry entryToExecute;
        UserOpData srcUserOpData;
        // Proof data
        MerkleContext ctx;
        ISuperValidator.DstProof[] proofDst;
        bytes signature;
        bytes signatureData;
    }

    function setUp() public override {
        skipAccountsCreation = true;
        super.setUp();

        privateKey1 = 1;
        owner1 = vm.addr(privateKey1);
        privateKey2 = 2;
        owner2 = vm.addr(privateKey2);
        privateKey3 = 3;
        owner3 = vm.addr(privateKey3);

        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        accountSalt = keccak256(abi.encode("acc1"));

        vm.selectFork(FORKS[ETH]);
        timestampETH = block.timestamp;

        instanceETH = accountInstances[ETH];
        accountETH = instanceETH.account;

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];

        yieldSource4626AddressETH = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoETH = IERC4626(yieldSource4626AddressETH);
        vm.label(yieldSource4626AddressETH, "YIELD_SOURCE_MORPHO_USDC_ETH");

        yieldSourceOracleETH = IYieldSourceOracle(_getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        addressOracleETH = address(yieldSourceOracleETH);

        SuperLedgerConfiguration configSuperLedgerETH = new SuperLedgerConfiguration();

        superExecutorETH = new SuperExecutor(address(configSuperLedgerETH));
        superExecutorETHInterface = ISuperExecutor(address(superExecutorETH));

        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorETH);

        superLedgerETH = new SuperLedger(address(configSuperLedgerETH), allowedExecutors);

        yieldSourceOracleId =
            keccak256(abi.encodePacked(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)));

        bytes32[] memory yieldSourceOracleSalts = new bytes32[](1);
        yieldSourceOracleSalts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: addressOracleETH,
            feePercent: 100,
            feeRecipient: address(this),
            ledger: _getContract(ETH, SUPER_LEDGER_KEY)
        });
        configSuperLedgerETH.setYieldSourceOracles(yieldSourceOracleSalts, configs);

        targetExecutorETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));

        acrossAdapterETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));

        vm.selectFork(FORKS[BASE]);
        timestampBase = block.timestamp;

        instanceBase = accountInstances[BASE];
        accountBase = instanceBase.account;

        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];

        yieldSource4626AddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSource4626AddressBase);
        vm.label(yieldSource4626AddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        SuperLedgerConfiguration configSuperLedgerBase = new SuperLedgerConfiguration();

        superExecutorBase = new SuperExecutor(address(configSuperLedgerBase));
        superExecutorBaseInterface = ISuperExecutor(address(superExecutorBase));

        address[] memory allowedExecutorsBase = new address[](1);
        allowedExecutorsBase[0] = address(superExecutorBase);

        superLedgerBase = new SuperLedger(address(configSuperLedgerBase), allowedExecutorsBase);

        yieldSourceOracleBase = IYieldSourceOracle(_getContract(BASE, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        addressOracleBase = address(yieldSourceOracleBase);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configsBase =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configsBase[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: addressOracleBase,
            feePercent: 100,
            feeRecipient: address(this),
            ledger: address(superLedgerBase)
        });
        configSuperLedgerBase.setYieldSourceOracles(yieldSourceOracleSalts, configsBase);

        validator = new SuperValidator();

        targetExecutorBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));

        validatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));

        acrossAdapterBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
    }

    function test_SameChain_Execution_Signers_3_Threshold_1()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        threshold = 1;
        vm.selectFork(FORKS[BASE]);

        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instanceBase = makeAccountInstance(accountSalt, predictedAddress, initCode);
        accountBase = instanceBase.account;
        assertEq(uint256(instanceBase.accountType), uint256(AccountType.SAFE), "not safe");

        instanceBase.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorBase), data: "" });
        instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });

        deal(underlyingBase_USDC, accountBase, amount);

        uint256 balanceBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);
        uint256 shareBalanceBefore = vaultInstanceMorphoBase.balanceOf(accountBase);

        uint256 expectedShares = vaultInstanceMorphoBase.convertToShares(amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase, amount, false);
        hooksData[1] =
            _createDeposit4626HookData(yieldSourceOracleId, yieldSource4626AddressBase, amount, false, address(0), 0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instanceBase, superExecutorBase, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSafeSigDataSingleOwner(
            validUntil, address(validator), userOpData.userOpHash, address(accountBase), 0
        );
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 shareBalanceAfter = vaultInstanceMorphoBase.balanceOf(accountBase);
        uint256 balanceAfter = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        assertEq(shareBalanceAfter, shareBalanceBefore + expectedShares, "share balance not increased");
        assertEq(balanceAfter, balanceBefore - amount, "balance not increased");
    }

    function test_SameChain_Execution_Signers_3_Threshold_3()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        threshold = 3;

        vm.selectFork(FORKS[BASE]);

        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instanceBase = makeAccountInstance(accountSalt, predictedAddress, initCode);
        accountBase = instanceBase.account;
        assertEq(uint256(instanceBase.accountType), uint256(AccountType.SAFE), "not safe");

        instanceBase.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorBase), data: "" });
        instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });

        deal(underlyingBase_USDC, accountBase, amount);

        uint256 balanceBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);
        uint256 shareBalanceBefore = vaultInstanceMorphoBase.balanceOf(accountBase);

        uint256 expectedShares = vaultInstanceMorphoBase.convertToShares(amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase, amount, false);
        hooksData[1] =
            _createDeposit4626HookData(yieldSourceOracleId, yieldSource4626AddressBase, amount, false, address(0), 0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instanceBase, superExecutorBase, abi.encode(entry), address(validator));

        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData =
            _createSafeSigData(validUntil, address(validator), userOpData.userOpHash, address(accountBase));
        userOpData.userOp.signature = sigData;

        executeOp(userOpData);

        uint256 shareBalanceAfter = vaultInstanceMorphoBase.balanceOf(accountBase);
        uint256 balanceAfter = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        assertEq(shareBalanceAfter, shareBalanceBefore + expectedShares, "share balance not increased");
        assertEq(balanceAfter, balanceBefore - amount, "balance not increased");
    }

    function test_SafeAccount_CrossChain_Execution_3Owners_Threshold_1()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        threshold = 1;
        CrossChainVars memory vars;
        vars.warpStartTime = 1_740_559_708;

        // setup SafeERC7579
        _createAccountsAndCode(vars);

        // setup dst chain execution data
        vm.selectFork(FORKS[ETH]);

        _createDstChainData(vars);

        // setup src chain execution data
        _createSrcChainData(vars);

        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: vars.warpStartTime,
                executionData: executeOp(vars.srcUserOpData),
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: vars.accountETH,
                relayerGas: 0
            })
        );

        // Verify source chain: tokens should be sent via Across bridge
        uint256 currentBaseBalance = IERC20(underlyingBase_USDC).balanceOf(vars.accountBase);
        uint256 expectedBaseBalance = vars.userBalanceBaseUSDCBefore - amount;

        assertEq(
            currentBaseBalance, expectedBaseBalance, "Source chain BASE USDC balance incorrect after cross-chain send"
        );

        // Verify destination chain: tokens should be deposited into vault
        vm.selectFork(FORKS[ETH]);
        uint256 currentOpShares = vaultInstanceMorphoETH.balanceOf(vars.accountETH);

        assertEq(
            currentOpShares, vars.previewDepositAmountETH, "Destination chain OP vault shares incorrect after deposit"
        );
    }
    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    // -- Single owner signature helpers
    function _createSafeSigDataSingleOwner(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        address _account,
        uint256 _ownerIndex
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, false, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSafeSignatureSingleOwner(merkleRoot, _account, _validator, _ownerIndex);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _createNativeSafeSigDataSingleOwner(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        address _account,
        uint256 _ownerIndex
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, false, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);

        // 🔥 KEY: Use native Safe signature format (like Safe UI would produce)
        bytes memory signature = _getNativeSafeSignatureSingleOwner(merkleRoot, _account, _validator, _ownerIndex);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _getSafeSignatureSingleOwner(
        bytes32 merkleRoot,
        address _account,
        address _validator,
        uint256 _ownerIndex
    )
        internal
        view
        returns (bytes memory)
    {
        SignatureData memory sigData;
        sigData.rawHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), merkleRoot));

        // Use chain-agnostic domain separator instead of Safe's native one
        sigData.domainSeparator = _getChainAgnosticDomainSeparator(_account);

        // Create the final hash using the same logic as SuperValidatorBase
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                sigData.domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(sigData.rawHash))))
            )
        );

        // Sign the chain-agnostic hash with the specified owner
        uint256 privateKey;
        if (_ownerIndex == 0) {
            privateKey = privateKey1;
            (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey, messageHash);
            sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        } else if (_ownerIndex == 1) {
            privateKey = privateKey2;
            (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey, messageHash);
            sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);
        } else if (_ownerIndex == 2) {
            privateKey = privateKey3;
            (sigData.v3, sigData.r3, sigData.s3) = vm.sign(privateKey, messageHash);
            sigData.recovered3 = ecrecover(messageHash, sigData.v3, sigData.r3, sigData.s3);
        } else {
            revert("Invalid owner index");
        }

        return _buildAndValidateSignatureSingleOwner(sigData, _ownerIndex);
    }

    function _getNativeSafeSignatureSingleOwner(
        bytes32 merkleRoot,
        address _account,
        address _validator,
        uint256 _ownerIndex
    )
        internal
        view
        returns (bytes memory)
    {
        SignatureData memory sigData;

        // Create the message hash that the validator expects: namespace + merkleRoot
        sigData.rawHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), merkleRoot));

        // Use Safe's native domain separator (with actual chainid) - this is what Safe UI would use
        sigData.domainSeparator = _getNativeSafeDomainSeparator(_account);

        // Create Safe message hash using Safe's format:
        // keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)))
        bytes32 SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(abi.encode(sigData.rawHash))));

        // Create the final EIP-712 hash using Safe's native domain separator
        bytes32 messageHash =
            keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), sigData.domainSeparator, safeMessageHash));

        // Sign the native Safe hash with the specified owner
        uint256 privateKey;
        if (_ownerIndex == 0) {
            privateKey = privateKey1;
            (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey, messageHash);
            sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        } else if (_ownerIndex == 1) {
            privateKey = privateKey2;
            (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey, messageHash);
            sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);
        } else if (_ownerIndex == 2) {
            privateKey = privateKey3;
            (sigData.v3, sigData.r3, sigData.s3) = vm.sign(privateKey, messageHash);
            sigData.recovered3 = ecrecover(messageHash, sigData.v3, sigData.r3, sigData.s3);
        } else {
            revert("Invalid owner index");
        }

        return _buildAndValidateSignatureSingleOwner(sigData, _ownerIndex);
    }

    function _buildAndValidateSignature(SignatureData memory sigData) internal view returns (bytes memory) {
        bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
        bytes memory sig2 = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);
        bytes memory sig3 = abi.encodePacked(sigData.r3, sigData.s3, sigData.v3);

        bytes memory signature;
        if (owner1 < owner2 && owner2 < owner3) {
            signature = bytes.concat(sig1, sig2, sig3);
        } else if (owner1 < owner3 && owner3 < owner2) {
            signature = bytes.concat(sig1, sig3, sig2);
        } else if (owner2 < owner1 && owner1 < owner3) {
            signature = bytes.concat(sig2, sig1, sig3);
        } else if (owner2 < owner3 && owner3 < owner1) {
            signature = bytes.concat(sig2, sig3, sig1);
        } else if (owner3 < owner1 && owner1 < owner2) {
            signature = bytes.concat(sig3, sig1, sig2);
        } else {
            // owner3 < owner2 && owner2 < owner1
            signature = bytes.concat(sig3, sig2, sig1);
        }

        bytes memory dataWithValidator = abi.encodePacked(address(0), signature);
        return dataWithValidator;
    }

    function _buildAndValidateSignatureSingleOwner(
        SignatureData memory sigData,
        uint256 _ownerIndex
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory signature;

        if (_ownerIndex == 0) {
            signature = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
        } else if (_ownerIndex == 1) {
            signature = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);
        } else if (_ownerIndex == 2) {
            signature = abi.encodePacked(sigData.r3, sigData.s3, sigData.v3);
        } else {
            revert("Invalid owner index");
        }

        bytes memory dataWithValidator = abi.encodePacked(address(0), signature);
        return dataWithValidator;
    }

    // -- SAFEERC7579 helper
    function _getInitData() internal view returns (bytes memory _init) {
        ModuleInit[] memory validators = new ModuleInit[](1);
        validators[0] = ModuleInit({ module: address(_defaultValidator), initData: "" });
        ModuleInit[] memory executors = new ModuleInit[](0);
        ModuleInit[] memory fallbacks = new ModuleInit[](0);
        ModuleInit[] memory hooks = new ModuleInit[](0);

        ISafe7579Launchpad.InitData memory initDataSafe = ISafe7579Launchpad.InitData({
            singleton: address(SafeFactory(_getFactory("SAFE")).safeSingleton()),
            owners: owners,
            threshold: threshold,
            setupTo: address(SafeFactory(_getFactory("SAFE")).launchpad()),
            setupData: abi.encodeCall(
                ISafe7579Launchpad.initSafe7579,
                (address(SafeFactory(_getFactory("SAFE")).safe7579()), executors, fallbacks, hooks, owners, 2)
            ),
            safe7579: ISafe7579(SafeFactory(_getFactory("SAFE")).safe7579()),
            validators: validators,
            callData: ""
        });
        _init = abi.encode(initDataSafe);
    }

    // -- modulekit helpers
    function _getFactory(string memory factoryType) internal view returns (address factory) {
        bytes32 slot = keccak256(abi.encode("ModuleKit.", factoryType, "FactorySlot"));
        assembly {
            factory := sload(slot)
        }
    }

    // -- 1271 signature helper
    function _createSafeSigData(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        address _account
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, false, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSafeSignature(merkleRoot, _account, _validator);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _createNativeSafeSigData(
        uint48 validUntil,
        address _validator,
        bytes32 userOpHash,
        address _account
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, false, address(_validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);

        // 🔥 KEY: Use native Safe signature format (like Safe UI would produce)
        bytes memory signature = _getNativeSafeSignature(merkleRoot, _account, _validator);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function _getSafeSignature(
        bytes32 merkleRoot,
        address _account,
        address _validator
    )
        internal
        view
        returns (bytes memory)
    {
        SignatureData memory sigData;
        sigData.rawHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), merkleRoot));

        // Use chain-agnostic domain separator instead of Safe's native one
        sigData.domainSeparator = _getChainAgnosticDomainSeparator(_account);

        // Create the final hash using the same logic as SuperValidatorBase
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                sigData.domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(sigData.rawHash))))
            )
        );

        // Sign the chain-agnostic hash with all three owners
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);
        (sigData.v3, sigData.r3, sigData.s3) = vm.sign(privateKey3, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);
        sigData.recovered3 = ecrecover(messageHash, sigData.v3, sigData.r3, sigData.s3);

        return _buildAndValidateSignature(sigData);
    }

    function _getNativeSafeSignature(
        bytes32 merkleRoot,
        address _account,
        address _validator
    )
        internal
        view
        returns (bytes memory)
    {
        SignatureData memory sigData;

        // Create the message hash that the validator expects: namespace + merkleRoot
        sigData.rawHash = keccak256(abi.encode(SuperValidator(_validator).namespace(), merkleRoot));

        // Use Safe's native domain separator (with actual chainid) - this is what Safe UI would use
        sigData.domainSeparator = _getNativeSafeDomainSeparator(_account);

        // Create Safe message hash using Safe's format:
        // keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)))
        bytes32 SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(abi.encode(sigData.rawHash))));

        // Create the final EIP-712 hash using Safe's native domain separator
        bytes32 messageHash =
            keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), sigData.domainSeparator, safeMessageHash));

        // Sign the native Safe hash with all three owners
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);
        (sigData.v3, sigData.r3, sigData.s3) = vm.sign(privateKey3, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);
        sigData.recovered3 = ecrecover(messageHash, sigData.v3, sigData.r3, sigData.s3);

        return _buildAndValidateSignature(sigData);
    }

    // -- UserOps helpers
    function _makeNonceKey(bytes1 vMode) internal view returns (uint192 key) {
        key = (uint192(uint8(vMode)) << 160) | uint192(uint160(address(validator)));
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

    /// @notice Helper function to create chain-agnostic domain separator
    /// @dev Must match the logic in SuperValidatorBase
    function _getChainAgnosticDomainSeparator(address _account) internal pure returns (bytes32) {
        bytes32 CHAIN_AGNOSTIC_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
        uint256 FIXED_CHAIN_ID = 1;
        string memory DOMAIN_NAME = "SuperformSafe";
        string memory DOMAIN_VERSION = "1.0.0";

        return keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                _account
            )
        );
    }

    /// @notice Helper function to create Safe's native domain separator
    /// @dev Uses actual chain ID - this is what Safe UI would use
    function _getNativeSafeDomainSeparator(address _account) internal view returns (bytes32) {
        // Safe's native domain separator typehash:
        // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
        bytes32 DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

        return keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                block.chainid, // 🔥 KEY: Use actual chain ID (not fixed like chain-agnostic)
                _account
            )
        );
    }

    function _createAccountsAndCode(CrossChainVars memory vars) internal {
        // src account
        vm.selectFork(FORKS[BASE]);
        _initializeModuleKit("SAFE", keccak256("123"));

        address safeFactory = _getFactory("SAFE");
        vars.initData = _getInitData();
        vars.predictedAddress = IAccountFactory(safeFactory).getAddress(accountSalt, vars.initData);
        vars.initCode = abi.encodePacked(
            address(safeFactory), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, vars.initData))
        );
        vars.instanceBase = makeAccountInstance(accountSalt, vars.predictedAddress, vars.initCode);
        vars.accountBase = vars.instanceBase.account;

        deal(vars.accountBase, 1 ether);
        deal(underlyingBase_USDC, vars.accountBase, amount);

        // install modules
        vars.instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superExecutorBase),
            data: ""
        });
        vars.instanceBase.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(vars.predictedAddress))
        });
        assertEq(uint256(vars.instanceBase.accountType), uint256(AccountType.SAFE), "not safe on base");

        // dst account
        vm.selectFork(FORKS[ETH]);
        _initializeModuleKit("SAFE", keccak256("123"));

        deal(safeFactory, 10 ether);

        vm.prank(safeFactory);
        IStakeManager(ENTRYPOINT_ADDR).addStake{ value: 10 ether }(100_000);
        vars.instanceETH = makeAccountInstance(accountSalt, vars.predictedAddress, vars.initCode);
        vars.accountETH = vars.instanceETH.account;

        deal(vars.accountETH, 1 ether);
        deal(underlyingETH_USDC, vars.accountETH, amount);

        vars.instanceETH.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superExecutorETH),
            data: ""
        });
        vars.instanceETH.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validatorOnETH),
            data: abi.encode(address(vars.predictedAddress))
        });

        assertEq(uint256(vars.instanceETH.accountType), uint256(AccountType.SAFE), "not safe on eth");
    }

    function _createDstChainData(CrossChainVars memory vars) internal {
        vars.ethHooksAddresses = new address[](2);
        vars.ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        vars.ethHooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        vars.ethHooksData = new bytes[](2);
        vars.ethHooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource4626AddressETH, amount, false);
        vars.ethHooksData[1] =
            _createDeposit4626HookData(yieldSourceOracleId, yieldSource4626AddressETH, amount, false, address(0), 0);

        vars.messageData = TargetExecutorMessage({
            hooksAddresses: vars.ethHooksAddresses,
            hooksData: vars.ethHooksData,
            validator: address(validatorOnETH),
            signer: address(0),
            signerPrivateKey: 0,
            targetAdapter: address(acrossAdapterETH),
            targetExecutor: address(superExecutorETH),
            nexusFactory: CHAIN_1_NEXUS_FACTORY,
            nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
            chainId: uint64(ETH),
            amount: amount,
            account: address(0),
            tokenSent: underlyingETH_USDC
        });

        (vars.targetExecutorMessage, vars.accountToUse) = _createTargetExecutorMessage(vars.messageData, false);

        vars.previewDepositAmountETH = vaultInstanceMorphoETH.previewDeposit(amount);
    }

    function _createSrcChainData(CrossChainVars memory vars) internal {
        vm.selectFork(FORKS[BASE]);

        vars.srcHooksAddresses = new address[](2);
        vars.srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        vars.srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        vars.srcHooksData = new bytes[](2);
        vars.srcHooksData[0] = _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase, amount, false);
        vars.srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC, underlyingETH_USDC, amount, amount, ETH, true, vars.targetExecutorMessage
        );

        vars.entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: vars.srcHooksAddresses, hooksData: vars.srcHooksData });

        vars.srcUserOpData = _getExecOpsWithValidator(
            vars.instanceBase, superExecutorBase, abi.encode(vars.entryToExecute), address(validator)
        );

        deal(underlyingBase_USDC, vars.accountBase, amount);
        vars.userBalanceBaseUSDCBefore = IERC20(underlyingBase_USDC).balanceOf(vars.accountBase);

        _prepareMerkleRootAndSignature(vars);
    }

    function _prepareMerkleRootAndSignature(CrossChainVars memory vars) internal view {
        (vars.ctx, vars.proofDst) = _createMerkleRootWithoutSignature(
            vars.messageData, vars.srcUserOpData.userOpHash, vars.accountToUse, ETH, address(validator)
        );

        vars.signature = _getSafeSignatureSingleOwner(vars.ctx.merkleRoot, vars.accountToUse, address(validator), 0);
        vars.signatureData = abi.encode(
            true, vars.ctx.validUntil, vars.ctx.merkleRoot, vars.ctx.merkleProof[1], vars.proofDst, vars.signature
        );
        vars.srcUserOpData.userOp.signature = vars.signatureData;
    }
}
