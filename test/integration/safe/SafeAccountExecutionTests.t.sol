// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import {
    UserOpData, AccountType, AccountInstance, ModuleKitHelpers, PackedUserOperation
} from "modulekit/ModuleKit.sol";
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
import { IERC7579Account, Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";

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
        bytes32 r1;
        bytes32 r2;
        bytes32 s1;
        bytes32 s2;
        address recovered1;
        address recovered2;
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
    bytes4 public constant ERC1271_MAGICVALUE = 0x1626ba7e;

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

    ISuperExecutor public superExecutorETH;
    ISuperExecutor public superExecutorBase;

    AcrossV3Adapter public acrossAdapterETH;
    AcrossV3Adapter public acrossAdapterBase;

    IERC4626 public vaultInstanceMorphoETH;
    IERC4626 public vaultInstanceMorphoBase;

    address public yieldSource4626AddressETH;
    address public yieldSource4626AddressBase;

    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleBase;

    ISuperDestinationExecutor public targetExecutorETH;
    ISuperDestinationExecutor public targetExecutorBase;

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
        threshold = 1;

        vm.selectFork(FORKS[ETH]);

        accountSalt = keccak256(abi.encode("acc1"));

        instanceETH = accountInstances[ETH];
        accountETH = instanceETH.account;

        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];

        yieldSource4626AddressETH = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstanceMorphoETH = IERC4626(yieldSource4626AddressETH);
        vm.label(yieldSource4626AddressETH, "YIELD_SOURCE_MORPHO_USDC_ETH");

        yieldSourceOracleETH = new ERC4626YieldSourceOracle(yieldSource4626AddressETH);
        addressOracleETH = address(yieldSourceOracleETH);

        validator = new SuperValidator();

        superExecutorETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        targetExecutorETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        validatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));

        acrossAdapterETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));

        vm.selectFork(FORKS[BASE]);

        instanceBase = accountInstances[BASE];
        accountBase = instanceBase.account;

        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];

        yieldSource4626AddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSource4626AddressBase);
        vm.label(yieldSource4626AddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        yieldSourceOracleBase = new ERC4626YieldSourceOracle(yieldSource4626AddressBase);
        addressOracleBase = address(yieldSourceOracleBase);

        superExecutorBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        targetExecutorBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));

        validatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));

        acrossAdapterBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
    }

    function test_SameChain_Execution_Signers_3_Threshold_1()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        vm.selectFork(FORKS[ETH]);

        // setup SafeERC7579
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instanceETH = makeAccountInstance(accountSalt, predictedAddress, initCode);
        accountETH = instanceETH.account;
        assertEq(uint256(instanceETH.accountType), uint256(AccountType.SAFE), "not safe");

        instanceETH.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorETH), data: "" });
        instanceETH.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });

        // setup execution data
        uint256 amount = 1000e6;
    }

    function test_SameChain_Execution_Signers_3_Threshold_3()
        public
        initializeModuleKit
        usingAccountEnv(AccountType.SAFE)
    {
        // setup SafeERC7579
        // bytes memory initData = _getInitData();
        // address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);
        // bytes memory initCode = abi.encodePacked(
        //     address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        // );
        // instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        // account = instance.account;
        // assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
    }

    function test_SafeAccount_SameChain_Execution() public {
        // address[] memory hooksAddresses = new address[](2);
        // hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        // hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        // bytes[] memory hooksData = new bytes[](2);
        // hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource4626AddressETH, depositAmount, false);
        // hooksData[1] = _createDeposit4626HookData(
        //     yieldSourceOracleId, yieldSource4626AddressETH, depositAmount, false, address(0), 0
        // );

        // ISuperExecutor.ExecutorEntry memory entry =
        //     ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }

    function test_SafeAccount_CrossChain_Execution() public {
        // TODO: Implement test
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

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

        // Sign the chain-agnostic hash
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);

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

        // Sign the native Safe hash
        (sigData.v1, sigData.r1, sigData.s1) = vm.sign(privateKey1, messageHash);
        (sigData.v2, sigData.r2, sigData.s2) = vm.sign(privateKey2, messageHash);

        // Verify recovery
        sigData.recovered1 = ecrecover(messageHash, sigData.v1, sigData.r1, sigData.s1);
        sigData.recovered2 = ecrecover(messageHash, sigData.v2, sigData.r2, sigData.s2);

        return _buildAndValidateSignature(sigData);
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

    function _buildAndValidateSignature(SignatureData memory sigData) internal view returns (bytes memory) {
        bytes memory sig1 = abi.encodePacked(sigData.r1, sigData.s1, sigData.v1);
        bytes memory sig2 = abi.encodePacked(sigData.r2, sigData.s2, sigData.v2);

        bytes memory signature;
        if (owner1 < owner2) {
            signature = bytes.concat(sig1, sig2);
        } else {
            signature = bytes.concat(sig2, sig1);
        }

        bytes memory dataWithValidator = abi.encodePacked(address(0), signature);
        return dataWithValidator;
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
}
