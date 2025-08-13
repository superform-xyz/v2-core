// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import "modulekit/accounts/common/lib/ModeLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Helpers } from "../utils/Helpers.sol";
import { MerkleTreeHelper } from "../utils/MerkleTreeHelper.sol";
import { InternalHelpers } from "../utils/InternalHelpers.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { INexusFactory } from "../../src/vendor/nexus/INexusFactory.sol";
import { BootstrapConfig, INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { IERC7484 } from "../../src/vendor/nexus/IERC7484.sol";
import { IMinimalEntryPoint, PackedUserOperation } from "../../src/vendor/account-abstraction/IMinimalEntryPoint.sol";
import { Vm } from "forge-std/Vm.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../src/interfaces/ISuperValidator.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { SuperValidator } from "../../src/validators/SuperValidator.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { ERC4626YieldSourceOracle } from "../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { FlatFeeLedger } from "../../src/accounting/FlatFeeLedger.sol";
import { ApproveERC20Hook } from "../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../src/hooks/vaults/4626/Redeem4626VaultHook.sol";

abstract contract MinimalBaseNexusIntegrationTest is Helpers, MerkleTreeHelper, InternalHelpers {
    SuperValidator public superMerkleValidator;
    INexusFactory public nexusFactory;
    INexusBootstrap public nexusBootstrap;
    SuperExecutor public superExecutorModule;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;
    bytes32 public initSalt;

    address public signer;
    uint256 public signerPrvKey;
    uint256 public blockNumber;
    address public approveHook;
    address public deposit4626Hook;
    address public redeem4626Hook;
    address public yieldSourceOracle4626;
    address public yieldSourceOracle5115;
    address public yieldSourceOracle7540;

    function setUp() public virtual {
        blockNumber != 0
            ? vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), blockNumber)
            : vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        (signer, signerPrvKey) = makeAddrAndKey("signer");

        initSalt = keccak256(abi.encode("test"));

        superMerkleValidator = new SuperValidator();
        vm.label(address(superMerkleValidator), "SuperValidator");
        nexusFactory = INexusFactory(CHAIN_1_NEXUS_FACTORY);
        vm.label(address(nexusFactory), "NexusFactory");
        nexusBootstrap = INexusBootstrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");
        ledgerConfig = ISuperLedgerConfiguration(new SuperLedgerConfiguration());

        superExecutorModule = new SuperExecutor(address(ledgerConfig));

        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutorModule);

        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](3);
        yieldSourceOracle4626 = address(new ERC4626YieldSourceOracle(address(ledgerConfig)));
        yieldSourceOracle5115 = address(new ERC5115YieldSourceOracle(address(ledgerConfig)));
        yieldSourceOracle7540 = address(new ERC7540YieldSourceOracle(address(ledgerConfig)));
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle4626,
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle7540,
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });

        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle5115,
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(new FlatFeeLedger(address(ledgerConfig), allowedExecutors))
        });
        bytes32[] memory salts = new bytes32[](3);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        salts[1] = bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        salts[2] = bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
        ledgerConfig.setYieldSourceOracles(salts, configs);

        approveHook = address(new ApproveERC20Hook());
        deposit4626Hook = address(new Deposit4626VaultHook());
        redeem4626Hook = address(new Redeem4626VaultHook());
    }

    /*//////////////////////////////////////////////////////////////
                                 ACCOUNT CREATION METHODS
    //////////////////////////////////////////////////////////////*/
    function _createWithNexus(address[] memory attesters, uint8 threshold, uint256 value) internal returns (address) {
        bytes memory initData = _getNexusInitData(attesters, threshold);

        address computedAddress = nexusFactory.computeAccountAddress(initData, initSalt);
        address deployedAddress = nexusFactory.createAccount{ value: value }(initData, initSalt);

        if (deployedAddress != computedAddress) revert("Nexus SCA addresses mismatch");
        return computedAddress;
    }

    function _getNexusInitData(address[] memory attesters, uint8 threshold) internal view returns (bytes memory) {
        // create validators
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: address(superMerkleValidator), data: abi.encode(signer) });

        // create executors
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: address(superExecutorModule), data: "" });

        // create hooks
        BootstrapConfig memory hook = BootstrapConfig({ module: address(0), data: "" });

        // create fallbacks
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);

        return nexusBootstrap.getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(address(0)), attesters, threshold
        );
    }

    /*//////////////////////////////////////////////////////////////
                                USER OPERATION METHODS
    //////////////////////////////////////////////////////////////*/
    function _executeThroughEntrypoint(address account, ISuperExecutor.ExecutorEntry memory entry) internal {
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        bytes memory callData = _prepareExecutionCalldata(executions);
        uint256 nonce = _prepareNonce(account);
        PackedUserOperation memory userOp = _createPackedUserOperation(account, nonce, callData);

        // create validator merkle tree & get signature data
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createSourceValidatorLeaf(
            IMinimalEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOp),
            validUntil,
            new uint64[](0),
            address(superMerkleValidator)
        );
        (bytes32[][] memory proof, bytes32 root) = _createValidatorMerkleTree(leaves);
        bytes memory signature = _getSignature(root);

        bytes memory sigData =
            abi.encode(new uint64[](0), validUntil, root, proof[0], new ISuperValidator.DstProof[](0), signature);
        // -- replace signature with validator signature
        userOp.signature = sigData;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Record logs before execution for error detection
        vm.recordLogs();

        // Execute the user operation
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(userOps, payable(account));
    }

    struct MaliciousHookExecution {
        Execution[] executions;
        bytes callData;
        uint256 nonce;
        PackedUserOperation userOp;
        uint48 validUntil;
        bytes32[] leaves;
        bytes32[][] proof;
        bytes32 root;
        bytes signature;
        uint64[] chainsWithDestExecution;
        bytes sigData;
        PackedUserOperation[] userOps;
    }

    function _executeThroughEntrypointWithMaliciousHook(
        address account,
        ISuperExecutor.ExecutorEntry memory entry
    )
        internal
    {
        MaliciousHookExecution memory vars;

        vars.executions = new Execution[](1);
        vars.executions[0] = Execution({
            target: address(superExecutorModule),
            value: 0,
            callData: abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entry))
        });

        vars.callData = _prepareExecutionCalldata(vars.executions);
        vars.nonce = _prepareNonce(account);
        vars.userOp = _createPackedUserOperation(account, vars.nonce, vars.callData);

        // create validator merkle tree & get signature data
        vars.validUntil = uint48(block.timestamp + 1 hours);
        vars.leaves = new bytes32[](1);
        vars.leaves[0] = _createSourceValidatorLeaf(
            IMinimalEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(vars.userOp),
            vars.validUntil,
            new uint64[](0),
            address(superMerkleValidator)
        );
        (vars.proof, vars.root) = _createValidatorMerkleTree(vars.leaves);
        vars.signature = _getSignature(vars.root);
        vars.chainsWithDestExecution = new uint64[](0);
        vars.sigData = abi.encode(
            vars.chainsWithDestExecution, vars.validUntil, vars.root, vars.proof[0], vars.proof[0], vars.signature
        );
        // -- replace signature with validator signature
        vars.userOp.signature = vars.sigData;

        vars.userOps = new PackedUserOperation[](1);
        vars.userOps[0] = vars.userOp;

        // Record logs before execution for error detection
        vm.recordLogs();

        // Execute the user operation
        IMinimalEntryPoint(ENTRYPOINT_ADDR).handleOps(vars.userOps, payable(account));

        // Check logs for failed UserOperations
        _checkUserOperationResults(ISuperExecutor.INSUFFICIENT_BALANCE_FOR_FEE.selector);
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

    function _prepareNonce(address account) internal view returns (uint256 nonce) {
        uint192 nonceKey;
        address validator = address(superMerkleValidator);
        bytes32 batchId = bytes3(0);
        bytes1 vMode = MODE_VALIDATION;
        assembly {
            nonceKey := or(shr(88, vMode), validator)
            nonceKey := or(shr(64, batchId), nonceKey)
        }
        nonce = IMinimalEntryPoint(ENTRYPOINT_ADDR).getNonce(account, nonceKey);
    }

    function _prepareNonceWithValidator(address account, address validator) internal view returns (uint256 nonce) {
        uint192 nonceKey;
        bytes32 batchId = bytes3(0);
        bytes1 vMode = MODE_VALIDATION;
        assembly {
            nonceKey := or(shr(88, vMode), validator)
            nonceKey := or(shr(64, batchId), nonceKey)
        }
        nonce = IMinimalEntryPoint(ENTRYPOINT_ADDR).getNonce(account, nonceKey);
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
            accountGasLimits: bytes32(abi.encodePacked(uint128(3e6), uint128(1e6))),
            preVerificationGas: 3e5,
            gasFees: bytes32(abi.encodePacked(uint128(3e5), uint128(1e7))),
            paymasterAndData: "",
            signature: hex"1234"
        });
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATOR HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    function _getSignature(bytes32 root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(superMerkleValidator.namespace(), root));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrvKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR DETECTION METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Custom error for UserOperation failures
    error UserOperationReverted(bytes32 userOpHash, address sender, uint256 nonce, bytes revertReason);

    /// @dev Check logs for failed UserOperations and revert with detailed error info
    function _checkUserOperationResults(bytes4 selector) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i; i < logs.length; i++) {
            // Match UserOperationEvent topic
            if (
                logs[i].topics[0]
                    == keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)")
            ) {
                (, bool success,,) = abi.decode(logs[i].data, (uint256, bool, uint256, uint256));

                if (!success) {
                    bytes32 userOpHash = logs[i].topics[1];
                    bytes memory revertReason = _getUserOpRevertReason(logs, userOpHash);

                    // Extract selector
                    bytes4 actualSelector;
                    if (revertReason.length >= 4) {
                        assembly {
                            actualSelector := mload(add(revertReason, 32))
                        }
                    }

                    // Log and check
                    if (actualSelector != selector) {
                        revert("Unexpected revert selector");
                    }

                    return; // success, matched expected revert
                }
            }
        }

        revert("No reverted UserOperationEvent found");
    }

    function _checkValidateUserOperationResults(bytes4 selector) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i; i < logs.length; i++) {
            // Match UserOperationEvent topic
            if (
                logs[i].topics[0]
                    == keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)")
            ) {
                (, bool success,,) = abi.decode(logs[i].data, (uint256, bool, uint256, uint256));

                if (!success) {
                    bytes32 userOpHash = logs[i].topics[1];
                    bytes memory revertReason = _getUserOpRevertReason(logs, userOpHash);

                    // Extract selector
                    bytes4 actualSelector;
                    if (revertReason.length >= 4) {
                        assembly {
                            actualSelector := mload(add(revertReason, 32))
                        }
                    }

                    // Log and check
                    if (actualSelector != selector) {
                        revert("Unexpected revert selector");
                    }

                    return; // success, matched expected revert
                }
            }
        }

        revert("No reverted UserOperationEvent found");
    }

    /// @dev Extract revert reason from logs for a specific UserOperation
    function _getUserOpRevertReason(
        Vm.Log[] memory logs,
        bytes32 userOpHash
    )
        internal
        pure
        returns (bytes memory revertReason)
    {
        for (uint256 i; i < logs.length; i++) {
            // Check for UserOperationRevertReason event (topic:
            // keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)"))
            if (
                logs[i].topics[0] == 0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201
                    && logs[i].topics[1] == userOpHash
            ) {
                (, revertReason) = abi.decode(logs[i].data, (uint256, bytes));
                break;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                      MALICIOUS HOOK TESTING METHODS
    //////////////////////////////////////////////////////////////*/
    function _createWithNexusWithMaliciousHook(
        address[] memory attesters,
        uint8 threshold,
        uint256 value,
        address maliciousHook
    )
        internal
        returns (address)
    {
        bytes memory initData = _getNexusInitDataWithMaliciousHook(attesters, threshold, maliciousHook);

        address computedAddress = nexusFactory.computeAccountAddress(initData, initSalt);
        address deployedAddress = nexusFactory.createAccount{ value: value }(initData, initSalt);

        if (deployedAddress != computedAddress) revert("Nexus SCA addresses mismatch");
        return computedAddress;
    }

    function _getNexusInitDataWithMaliciousHook(
        address[] memory attesters,
        uint8 threshold,
        address maliciousHook
    )
        internal
        view
        returns (bytes memory)
    {
        // create validators
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        validators[0] = BootstrapConfig({ module: address(superMerkleValidator), data: abi.encode(signer) });

        // create executors
        BootstrapConfig[] memory executors = new BootstrapConfig[](1);
        executors[0] = BootstrapConfig({ module: address(superExecutorModule), data: "" });

        // create hooks
        BootstrapConfig memory hook = BootstrapConfig({ module: maliciousHook, data: "" });

        // create fallbacks
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);

        return nexusBootstrap.getInitNexusCalldata(
            validators, executors, hook, fallbacks, IERC7484(address(0)), attesters, threshold
        );
    }
}
