// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;


import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    AccountInstance,
    UserOpData,
    PackedUserOperation,
    AccountType
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { Safe7579Precompiles } from "modulekit/deployment/precompiles/Safe7579Precompiles.sol";
import { ISafe7579 } from "modulekit/accounts/safe/interfaces/ISafe7579.sol";
import { ISafe7579Launchpad, ModuleInit } from "modulekit/accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { ISafeProxyFactory } from "modulekit/accounts/safe/interfaces/ISafeProxyFactory.sol";
import { SafeFactory } from "modulekit/accounts/safe/SafeFactory.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { ModeLib } from "modulekit/accounts/common/lib/ModeLib.sol";
import { IAccountFactory } from "modulekit/accounts/factory/interface/IAccountFactory.sol";

// --safe
import { Safe } from "@safe/Safe.sol";
import { SafeProxyFactory } from "@safe/proxies/SafeProxyFactory.sol";
import { SafeProxy } from "@safe/proxies/SafeProxy.sol";
import { ISafe } from "@safe/interfaces/ISafe.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";


// Superform
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { SignatureHelper } from "../../utils/SignatureHelper.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { SuperMerkleValidator } from "../../../src/validators/SuperMerkleValidator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

import "forge-std/console2.sol";

contract SafeAccountExecution is
    RhinestoneModuleKit,
    InternalHelpers,
    SignatureHelper,
    MerkleTreeHelper,
    Safe7579Precompiles
{
    using BytesLib for bytes;
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    // SafeERC7579
    // -- erc7579 account
    AccountInstance instance;
    address account;
    bytes32 accountSalt;
    address safeErc7579Account;
    // -- singletons
    ISafe7579 safe7579;
    ISafe7579Launchpad launchpad;
    address safeSingleton;
    ISafeProxyFactory safeProxyFactory;
    SafeFactory safeFactory;

    // -- owners
    uint256 privateKey1;
    uint256 privateKey2;
    address owner1;
    address owner2;
    address[] owners;
    // -- multisig safe
    uint256 threshold = 2;
    SafeProxy safeProxy;
    Safe safe;


    // Superform
    ApproveERC20Hook approveERC20Hook;
    SuperLedgerConfiguration superLedgerConfiguration;
    SuperExecutor superExecutor;
    MockERC20 mockERC20;
    SuperMerkleValidator validator;

    function setUp() public virtual {
        accountSalt = keccak256(abi.encode("acc1"));

        approveERC20Hook = new ApproveERC20Hook();
        mockERC20 = new MockERC20("MockERC20", "MOCK", 18);
        superLedgerConfiguration = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(superLedgerConfiguration));
        validator = new SuperMerkleValidator();

        vm.label(address(superLedgerConfiguration), "Superform ledger config");
        vm.label(address(superExecutor), "Superform executor");
        vm.label(address(validator), "Superform validator");
        vm.label(address(approveERC20Hook), "Superform ApproveERC20Hook");
        vm.label(address(mockERC20), "Superform MockERC20");

        // safe 
        privateKey1 = 1;
        owner1 = vm.addr(privateKey1);
        privateKey2 = 2;
        owner2 = vm.addr(privateKey2);

        owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        bytes memory initializer = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            threshold,
            address(0), // fallbackHandler
            bytes(""),
            address(0), address(0), 0, address(0)
        );

        // SafeERC7579 manual account creation
        safe7579 = deploySafe7579();
        launchpad = deploySafe7579Launchpad(ENTRYPOINT_ADDR, SAFE_REGISTRY_ADDR);
        safeSingleton = deploySafeSingleton();
        safeProxyFactory = deploySafeProxyFactory();
        safeFactory = new SafeFactory();
        safeFactory.init();

        //https://github.com/safe-global/safe-smart-account creation 
        Safe _safeSingleton = new Safe();
        SafeProxyFactory factory = new SafeProxyFactory();
        safeProxy = factory.createProxyWithNonce(address(_safeSingleton), initializer, 0);
        safe = Safe(payable(safeProxy));

    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    function test_SafeAccountType() public usingAccountEnv(AccountType.SAFE) {
        instance = makeAccountInstance(accountSalt);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
    }


    /**
    function test_SameChainTx_execution_ManualAccountCreation() public {
        console2.log("----- test_SameChainTx_execution_ManualAccountCreation");

        bytes memory initCode = _getInitData("");
        ISafe7579Launchpad.InitData memory initData =
            abi.decode(initCode, (ISafe7579Launchpad.InitData));
        bytes32 initHash = launchpad.hash(initData);

        bytes memory factoryInitializer =
            abi.encodeCall(ISafe7579Launchpad.preValidationSetup, (initHash, address(0), ""));

        safeErc7579Account = address(
            safeProxyFactory.createProxyWithNonce(
                address(launchpad), factoryInitializer, uint256(accountSalt)
            )
        );


        // setup execution data
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(this), address(account));

        // -- executor entry
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(safeErc7579Account), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // -- userOp calldata
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutor),
            value: 0,
            callData: abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)))
        });
        bytes memory userOpCalldata =
            abi.encodeCall(IERC7579Account.execute, (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions)));

        uint256 nonce = 1;//IEntryPoint(ENTRYPOINT_ADDR).getNonce(address(safeErc7579Account), _makeNonceKey(0x00));

        // prepare PackedUserOperatio
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getDefaultUserOp();
        userOps[0].sender = safeErc7579Account;
        userOps[0].nonce = nonce;
        userOps[0].callData = userOpCalldata;

        console2.log("---------------A");
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes32 userOpHash = bytes32("0x1");//IEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOps[0]);
        console2.log("---------------B");
        bytes memory sigData = _createSourceSigData(validUntil, userOpHash);
        userOps[0].signature = sigData;
    }
    */


    function test_SameChainTx_executionA() public initializeModuleKit usingAccountEnv(AccountType.SAFE) {
        console2.log("----- test_SameChainTx_execution");
        // setup SafeERC7579 
        safe7579 = SafeFactory(_getFactory("SAFE")).safe7579();
        bytes memory initData = _getInitData();
        address predictedAddress = IAccountFactory(_getFactory("SAFE")).getAddress(accountSalt, initData);

        bytes memory initCode = abi.encodePacked(
            address(_getFactory("SAFE")), abi.encodeCall(IAccountFactory.createAccount, (accountSalt, initData))
        );
        instance = makeAccountInstance(accountSalt, predictedAddress, initCode);
        account = instance.account;
        assertEq(uint256(instance.accountType), uint256(AccountType.SAFE), "not safe");
        console2.log("----- test_SameChainTx_execution installing custom 7579 modules A");
         
        console2.log("----- test_SameChainTx_execution installing custom 7579 modules B");
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(address(predictedAddress))
        });
        console2.log("----- test_SameChainTx_execution installed");

        // setup execution data
        uint256 amount = 1e8;
        uint256 allowanceBefore = mockERC20.allowance(address(this), address(account));

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveERC20Hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveHookData(address(mockERC20), address(this), amount, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData =
            _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(validator));

        console2.log("---------------A");
        uint48 validUntil = uint48(block.timestamp + 100 days);
        bytes memory sigData = _createSourceSigData(validUntil, userOpData.userOpHash);
        userOpData.userOp.signature = sigData;

        assertTrue(false);
        //executeOp(userOpData);

    }


    /*//////////////////////////////////////////////////////////////
                                INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    // -- modulekit helpers
    function _getFactory(string memory factoryType) internal view returns (address factory) {
        bytes32 slot = keccak256(abi.encode("ModuleKit.", factoryType, "FactorySlot"));
        assembly {
            factory := sload(slot)
        }
    }

    // -- SAFEERC7579 helper
    /**
    function _makeSafeERC7579Account() public returns (address, bytes memory) {
        ModuleInit[] memory modules = new ModuleInit[](1);
        modules[0] = ModuleInit({
            module: address(validator),
            initData: bytes(""),
            moduleType: MODULE_TYPE_VALIDATOR
        });

        bytes memory initializer = abi.encodeCall(
            Safe.setup,
            (
                owners,
                2,
                address(launchpad),
                abi.encodeCall(
                    Safe7579Launchpad.addSafe7579,
                    (
                        address(safe7579),
                        modules,
                        owners,
                        2
                    )
                ),
                address(safe7579),
                address(0),
                0,
                payable(address(0))
            )
        );

        uint256 saltNonce = 222;

        bytes memory deploymentData = abi.encodePacked(
            safeProxyFactory.proxyCreationCode(), uint256(uint160(address(safeSingleton)))
        );
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), // prefix
                address(safeProxyFactory), // deployer address
                salt, // salt
                keccak256(deploymentData) // bytecode hash
            )
        );

        address account = payable(address(uint160(uint256(hash))));

        vm.deal(address(account), 1 ether);
        bytes memory accountInitData = abi.encodePacked(
            safeProxyFactory,
            abi.encodeCall(
                SafeProxyFactory.createProxyWithNonce,
                (address(singleton), initializer, saltNonce)
            ));

        return (account, accountInitData);
    }
    */
    function _getInitData()
        internal
        view
        returns (bytes memory _init)
    {
        ModuleInit[] memory validators = new ModuleInit[](1);
        validators[0] = ModuleInit({ module: address(_defaultValidator), initData: "" });
        ModuleInit[] memory executors = new ModuleInit[](0);
        ModuleInit[] memory fallbacks = new ModuleInit[](0);
        ModuleInit[] memory hooks = new ModuleInit[](0);

        ISafe7579Launchpad.InitData memory initDataSafe = ISafe7579Launchpad.InitData({
            singleton: address(SafeFactory(_getFactory("SAFE")).safeSingleton()),
            owners: owners,
            threshold: 1,
            setupTo: address(SafeFactory(_getFactory("SAFE")).launchpad()),
            setupData: abi.encodeCall(
                ISafe7579Launchpad.initSafe7579,
                (
                    address(SafeFactory(_getFactory("SAFE")).safe7579()),
                    executors,
                    fallbacks,
                    hooks,
                    owners,
                    2
                )
            ),
            safe7579: ISafe7579(SafeFactory(_getFactory("SAFE")).safe7579()),
            validators: validators,
            callData: ""
        });
        _init = abi.encode(initDataSafe);
    }


    // -- 1271 signature helper
    function _createSourceSigData(
        uint48 validUntil,
        bytes32 userOpHash
    )
        internal
        view
        returns (bytes memory signatureData)
    {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(userOpHash, validUntil, false, address(validator));

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSafeSignature(merkleRoot);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        signatureData = abi.encode(false, validUntil, merkleRoot, merkleProof[0], proofDst, signature);
    }
    function _getSafeSignature(bytes32 merkleRoot)
        internal
        view
        returns (bytes memory)
    {
        bytes32 rawHash = keccak256(abi.encode(validator.namespace(), merkleRoot));
        bytes32 safeMessageHash = _getSafeMessageHash(rawHash); 

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKey1, safeMessageHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKey2, safeMessageHash);

        bytes memory sig1 = abi.encodePacked(r1, s1, v1);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);
        console2.log("--------v1", v1);
        console2.log("--------v2", v2);
        bytes memory signature;
        if (owner1 < owner2) {
            signature = bytes.concat(sig1, sig2);
        } else {
            signature = bytes.concat(sig2, sig1);
        }
        //GS020
        //GS026-> 
        console2.log("--------checking signature", signature.length);
        bytes4 rv = IERC1271(address(account)).isValidSignature(safeMessageHash, signature);
        console2.log("--------checked");

        return signature;
    }

    function _encodeSafeSignature(uint256 ownerIndex, uint8 v, bytes32 r, bytes32 s) internal pure returns (bytes memory) {
        // Encode v with index per Gnosis Safe spec
        uint256 vWithIndex = v + uint8(ownerIndex) * 0x100;
        return abi.encodePacked(r, s, uint8(vWithIndex));
    }

    /// @dev Replicates Safe.getMessageHash(bytes32)
    function _getSafeMessageHash(bytes32 dataHash) internal view returns (bytes32) {
        // Safe uses EIP-712 domain separator
        bytes32 domainSeparator = ISafe(payable(safe)).domainSeparator();

        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(
                    keccak256("SafeMessage(bytes32 message)"), // constant per Safe implementation
                    dataHash
                ))
            )
        );
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