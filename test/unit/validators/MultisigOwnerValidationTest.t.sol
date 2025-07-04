// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { SafeFactory } from "modulekit/accounts/safe/SafeFactory.sol";
import { ISafe7579Launchpad, ModuleInit } from "modulekit/accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { ISafe7579 } from "modulekit/accounts/safe/interfaces/ISafe7579.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { Safe } from "@safe/Safe.sol";

// Superform
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { ISuperValidator } from "../../../src/core/interfaces/ISuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/core/validators/SuperDestinationValidator.sol";
import { SuperValidatorBase } from "../../../src/core/validators/SuperValidatorBase.sol";

contract MultisigOwnerValidationTest is MerkleTreeHelper, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    struct DestinationData {
        uint256 nonce;
        bytes callData;
        uint64 chainId;
        address sender;
        address executor;
        address adapter;
        address tokenSent;
        address[] dstTokens;
        uint256[] intentAmounts;
    }

    struct SignatureData {
        uint48 validUntil;
        bytes32 merkleRoot;
        bytes32[] proof;
        bytes signature;
    }

    IERC4626 public vaultInstance;

    AccountInstance public instance;
    address public companionAccount;

    ISafe7579 public safe7579;
    address public safeAccount;
    address public safeMultisig;

    SafeFactory public factory;

    SuperDestinationValidator public validator;
    bytes public validSigData;

    DestinationData approveDestinationData;
    DestinationData transferDestinationData;
    DestinationData depositDestinationData;

    uint256 privateKey1;
    uint256 privateKey2;

    address owner1;
    address owner2;

    uint256 executorNonce;

    bytes4 constant VALID_SIGNATURE = bytes4(0x5c2ec0f3);

    function setUp() public {
        validator = new SuperDestinationValidator();

        (owner1, privateKey1) = makeAddrAndKey("alice");
        (owner2, privateKey2) = makeAddrAndKey("bob");

        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        safeAccount = _deploySafeSmartAccount(owners);

        
    }

    function _deploySafeSmartAccount(address[] memory owners) internal returns (address account) {
        factory = new SafeFactory();
        factory.init(); // deploys singleton + proxy-factory

        ModuleInit[] memory validators = new ModuleInit[](1);

        validators[0] = ModuleInit({
            module: address(validator),
            initData: ""
        });

        ISafe7579Launchpad.InitData memory initData = ISafe7579Launchpad.InitData({
            singleton: address(0),
            owners: owners,
            threshold: 2,
            setupTo: address(0),
            setupData: "",
            safe7579: ISafe7579(address(0)),
            validators: validators,
            callData: ""
        });

        bytes memory initCode = abi.encode(initData);
        bytes32 salt = keccak256("SAFE-1279-TEST");

        account = factory.createAccount(salt, initCode);
    }
}
