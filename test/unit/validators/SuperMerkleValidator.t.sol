// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperMerkleValidator } from "../../../src/core/validators/SuperMerkleValidator.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { console2 } from "forge-std/console2.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";


contract SuperMerkleValidatorTest is BaseTest, MerkleReader {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;


    IERC4626 public vaultInstance;
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;
    address public underlying;
    address public yieldSourceAddress;

    SuperMerkleValidator public validator;
    bytes public dummyData;
    UserOpData public dummyUserOp;
    bytes public dummySigData;
    bytes public validSigData;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        underlying = existingUnderlyingTokens[1][USDC_KEY];
        yieldSourceAddress = realVaultAddresses[1][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        vaultInstance = IERC4626(yieldSourceAddress);
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        validator = SuperMerkleValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));

        instance = accountInstances[ETH];
        account = instance.account;
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });

        dummyData = abi.encode(address(this));
        dummyUserOp = instance.getExecOps(
            address(this),
            0,
            abi.encodeWithSelector(IERC20.approve.selector, address(this), 1e18),
            address(instance.defaultValidator)
        );
        dummySigData = bytes("1234");
    }

    function test_Dummy_SuperVaultsMerkleRoot() public {
        bytes32 hookRoot = _getMerkleRoot();
        address hookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        bytes32[] memory proof = _getMerkleProof(hookAddress);

        bytes32 leaf = keccak256(abi.encodePacked(hookAddress));

        bool isValid = MerkleProof.verify(proof, hookRoot, leaf);
        assertTrue(isValid, "Merkle proof should be valid");
    }
}
