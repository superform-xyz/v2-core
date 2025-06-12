// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SuperExecutor } from "../../../src/core/executors/SuperExecutor.sol";
import { SuperDestinationExecutor } from "../../../src/core/executors/SuperDestinationExecutor.sol";
import { SuperDestinationValidator } from "../../../src/core/validators/SuperDestinationValidator.sol";
import { SuperValidatorBase } from "../../../src/core/validators/SuperValidatorBase.sol";
import { MaliciousToken } from "../../mocks/MaliciousToken.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { MockNexusFactory } from "../../mocks/MockNexusFactory.sol";
import { MockLedger, MockLedgerConfiguration } from "../../mocks/MockLedger.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";

import { Helpers } from "../../utils/Helpers.sol";

import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { SignatureHelper } from "../../utils/SignatureHelper.sol";

import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";

import "forge-std/console2.sol";

contract SuperExecutorTest is Helpers, RhinestoneModuleKit, InternalHelpers, SignatureHelper, MerkleTreeHelper {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    SuperExecutor public superSourceExecutor;
    SuperDestinationExecutor public superDestinationExecutor;
    SuperDestinationValidator public superDestinationValidator;
    address public account;
    MockERC20 public token;
    MockHook public inflowHook;
    MockHook public outflowHook;
    MockLedger public ledger;
    MockNexusFactory public nexusFactory;
    MockLedgerConfiguration public ledgerConfig;
    address public feeRecipient;
    AccountInstance public instance;
    address public signer;
    uint256 public signerPrvKey;

    function setUp() public {
        (signer, signerPrvKey) = makeAddrAndKey("signer");

        instance = makeAccountInstance(keccak256(abi.encode("TEST")));
        account = instance.account;

        token = new MockERC20("Mock Token", "MTK", 18);
        feeRecipient = makeAddr("feeRecipient");

        inflowHook = new MockHook(ISuperHook.HookType.INFLOW, address(token));
        outflowHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(token));

        ledger = new MockLedger();
        ledgerConfig = new MockLedgerConfiguration(address(ledger), feeRecipient, address(token), 100, account);
        nexusFactory = new MockNexusFactory(account);

        superDestinationValidator = new SuperDestinationValidator();
        superSourceExecutor = new SuperExecutor(address(ledgerConfig));
        superDestinationExecutor = new SuperDestinationExecutor(
            address(ledgerConfig), address(superDestinationValidator), address(nexusFactory)
        );

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superSourceExecutor), data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(superDestinationExecutor),
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(superDestinationValidator),
            data: abi.encode(signer)
        });
    }

    // ---------------- SOURCE EXECUTOR ------------------
    function test_SourceExecutor_Name() public view {
        assertEq(superSourceExecutor.name(), "SuperExecutor");
    }

    function test_SourceExecutor_Version() public view {
        assertEq(superSourceExecutor.version(), "0.0.1");
    }

    function test_SourceExecutor_IsModuleType() public view {
        assertTrue(superSourceExecutor.isModuleType(MODULE_TYPE_EXECUTOR));
        assertFalse(superSourceExecutor.isModuleType(1234));
    }

    function test_SourceExecutor_OnInstall() public view {
        assertTrue(superSourceExecutor.isInitialized(account));
    }

    function test_SourceExecutor_OnInstall_RevertIf_AlreadyInitialized() public {
        AccountInstance memory newInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address newAccount = newInstance.account;

        vm.startPrank(newAccount);

        vm.expectRevert(ISuperExecutor.ALREADY_INITIALIZED.selector);
        superSourceExecutor.onInstall("");
        vm.stopPrank();
    }

    function test_SourceExecutor_OnUninstall() public {
        vm.startPrank(account);
        superSourceExecutor.onUninstall("");
        vm.stopPrank();

        assertFalse(superSourceExecutor.isInitialized(account));
    }

    function test_SourceExecutor_OnUninstall_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperExecutor.NOT_INITIALIZED.selector);
        superSourceExecutor.onUninstall("");
        vm.stopPrank();
    }

    function test_SourceExecutor_Execute_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperExecutor.NOT_INITIALIZED.selector);
        superSourceExecutor.execute("");
        vm.stopPrank();
    }

    function test_SourceExecutor_Execute_WithHooks() public {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(inflowHook);
        hooksAddresses[1] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), 1, false, address(0), 0
        );
        hooksData[1] =
            _createRedeem4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false);

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();

        assertTrue(inflowHook.preExecuteCalled());
        assertTrue(inflowHook.postExecuteCalled());
        assertTrue(outflowHook.preExecuteCalled());
        assertTrue(outflowHook.postExecuteCalled());
    }

    function test_SourceExecutor_UpdateAccounting_Inflow() public {
        inflowHook.setOutAmount(1000);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), 1, false, address(0), 0
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_WithFee() public {
        vm.startPrank(account);

        outflowHook.setOutAmount(1000);
        outflowHook.setUsedShares(500);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createRedeem4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false);

        _getTokens(address(token), account, 1000);

        assertGt(token.balanceOf(account), 0, "Account should have tokens");

        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();

        assertEq(token.balanceOf(feeRecipient), 100);
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_RevertIf_InvalidAsset() public {
        MockHook invalidHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(0));
        invalidHook.setOutAmount(1000);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(invalidHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createRedeem4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false);

        vm.startPrank(makeAddr("account"));
        superSourceExecutor.onInstall("");

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert();
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_RevertIf_InsufficientBalance() public {
        outflowHook.setOutAmount(1000);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createRedeem4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false);

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.INSUFFICIENT_BALANCE_FOR_FEE.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_RevertIf_FeeNotTransferred() public {
        MaliciousToken maliciousToken = new MaliciousToken();

        maliciousToken.blacklist(feeRecipient);

        MockHook maliciousHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(maliciousToken));
        maliciousHook.setOutAmount(910);
        maliciousHook.setUsedShares(500);

        ledger.setFeeAmount(100);

        MockLedgerConfiguration maliciousConfig =
            new MockLedgerConfiguration(address(ledger), feeRecipient, address(maliciousToken), 100, account);
        superSourceExecutor = new SuperExecutor(address(maliciousConfig));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superSourceExecutor), data: "" });

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(maliciousHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createRedeem4626HookData(bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), account, 1, false);

        vm.startPrank(address(this));
        maliciousToken.transfer(account, 1000);
        vm.stopPrank();

        assertGt(maliciousToken.balanceOf(account), 0, "Account should have tokens");

        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.FEE_NOT_TRANSFERRED.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_VaultBank() public {
        inflowHook.setOutAmount(1000);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), 1, false, address(0), 0
        );

        vm.mockCall(address(inflowHook), abi.encodeWithSignature("vaultBank()"), abi.encode(address(this)));
        vm.mockCall(address(inflowHook), abi.encodeWithSignature("spToken()"), abi.encode(address(token)));
        vm.mockCall(address(inflowHook), abi.encodeWithSignature("dstChainId()"), abi.encode(1));
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("lockAsset(address,address,address,uint256,uint64)"),
            abi.encode(address(account), address(token), address(inflowHook), 1000, 1)
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_VaultBank_InvalidDestinationChainId() public {
        inflowHook.setOutAmount(1000);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(token), 1, false, address(0), 0
        );

        vm.mockCall(address(inflowHook), abi.encodeWithSignature("vaultBank()"), abi.encode(address(this)));
        vm.mockCall(address(inflowHook), abi.encodeWithSignature("spToken()"), abi.encode(address(token)));
        vm.mockCall(address(inflowHook), abi.encodeWithSignature("dstChainId()"), abi.encode(uint64(block.chainid)));
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("lockAsset(address,address,uint256,uint64)"),
            abi.encode(address(account), address(token), 1000, uint64(block.chainid))
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.INVALID_CHAIN_ID.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    // ---------------- DESTINATION EXECUTOR ------------------
    function test_DestinationExecutor_Name() public view {
        assertEq(superDestinationExecutor.name(), "SuperDestinationExecutor");
    }

    function test_DestinationExecutor_Version() public view {
        assertEq(superDestinationExecutor.version(), "0.0.1");
    }

    function test_DestinationExecutor_IsModuleType() public view {
        assertTrue(superDestinationExecutor.isModuleType(MODULE_TYPE_EXECUTOR));
        assertFalse(superDestinationExecutor.isModuleType(1234));
    }

    function test_DestinationExecutor_OnInstall() public view {
        assertTrue(superDestinationExecutor.isInitialized(account));
    }

    function test_DestinationExecutor_Constructor() public {
        vm.expectRevert(ISuperExecutor.ADDRESS_NOT_VALID.selector);
        new SuperDestinationExecutor(address(this), address(0), address(this));

        vm.expectRevert(ISuperExecutor.ADDRESS_NOT_VALID.selector);
        new SuperDestinationExecutor(address(this), address(this), address(0));
    }

    function test_DestinationExecutor_IsMerkleTreeUsed() public view {
        assertFalse(superDestinationExecutor.isMerkleRootUsed(address(this), bytes32(0)));
    }

    function test_DestinationExecutor_OnInstall_RevertIf_AlreadyInitialized() public {
        AccountInstance memory newInstance = makeAccountInstance(keccak256(abi.encode("TEST")));
        address newAccount = newInstance.account;

        vm.startPrank(newAccount);

        vm.expectRevert(ISuperExecutor.ALREADY_INITIALIZED.selector);
        superDestinationExecutor.onInstall("");
        vm.stopPrank();
    }

    function test_DestinationExecutor_OnUninstall() public {
        vm.startPrank(account);
        superDestinationExecutor.onUninstall("");
        vm.stopPrank();

        assertFalse(superDestinationExecutor.isInitialized(account));
    }

    function test_DestinationExecutor_OnUninstall_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperExecutor.NOT_INITIALIZED.selector);
        superDestinationExecutor.onUninstall("");
        vm.stopPrank();
    }

    function test_DestinationExecutor_Execute_RevertIf_NotInitialized() public {
        vm.startPrank(makeAddr("account"));
        vm.expectRevert(ISuperExecutor.NOT_INITIALIZED.selector);
        superDestinationExecutor.execute("");
        vm.stopPrank();
    }

    function _getDstTokensAndIntents() public view returns (address[] memory, uint256[] memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(token);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        return (dstTokens, intentAmounts);
    }

    function test_DestinationExecutor_ProcessBridgedExecution_InvalidAccount() public {
        vm.expectRevert();
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        superDestinationExecutor.processBridgedExecution(
            address(token), address(this), dstTokens, intentAmounts, "", "", ""
        );

        vm.mockCall(address(this), abi.encodeWithSignature("accountId()"), abi.encode(""));
        vm.expectRevert(SuperDestinationExecutor.ADDRESS_NOT_ACCOUNT.selector);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(this), dstTokens, intentAmounts, "", "", ""
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_InvalidLengths() public {
        vm.expectRevert();
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(token);
        uint256[] memory intentAmounts = new uint256[](0);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(this), dstTokens, intentAmounts, "", "", ""
        );

        vm.mockCall(address(this), abi.encodeWithSignature("accountId()"), abi.encode(""));
        vm.expectRevert(SuperDestinationExecutor.ARRAY_LENGTH_MISMATCH.selector);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(this), dstTokens, intentAmounts, "", "", ""
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_Revert_AccountCreated() public {
        vm.expectRevert(SuperDestinationExecutor.ACCOUNT_NOT_CREATED.selector);
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        superDestinationExecutor.processBridgedExecution(
            address(token), address(0), dstTokens, intentAmounts, "", "", ""
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_InvalidSignature() public {
        vm.expectRevert();
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens, intentAmounts, "", "", ""
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_InvalidExecutionData() public {
        bytes memory signatureData = abi.encode(uint48(1), bytes32(abi.encodePacked("account")), new bytes32[](0), "");
        vm.expectRevert();
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens, intentAmounts, "", "", signatureData
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_InvalidProof() public {
        bytes memory initData = ""; // no initData
        (bytes memory signatureData, bytes memory executorCalldata,,) = _createDestinationValidData(false);
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens, intentAmounts, initData, executorCalldata, signatureData
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_Erc20_BalanceNotMet() public {
        bytes memory initData = ""; // no initData
        (bytes memory signatureData,, bytes memory executionDataForLeaf,) = _createDestinationValidData(true);
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens, intentAmounts, initData, executionDataForLeaf, signatureData
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_Erc20_BalanceMet() public {
        bytes memory initData = ""; // no initData
        (bytes memory signatureData,, bytes memory executionDataForLeaf,) = _createDestinationValidData(true);
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        _getTokens(address(token), address(account), 1);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens, intentAmounts, initData, executionDataForLeaf, signatureData
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_Eth_BalanceNotMet() public {
        bytes memory initData = ""; // no initData
        (bytes memory signatureData,, bytes memory executionDataForLeaf,) = _createDestinationValidData(true);
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        deal(address(account), 0);
        superDestinationExecutor.processBridgedExecution(
            address(0), address(account), dstTokens, intentAmounts, initData, executionDataForLeaf, signatureData
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_Eth_BalanceMet() public {
        bytes memory initData = ""; // no initData
        (bytes memory signatureData,, bytes memory executionDataForLeaf,) = _createDestinationValidData(true);
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _getDstTokensAndIntents();
        deal(address(account), 1);
        superDestinationExecutor.processBridgedExecution(
            address(0), address(account), dstTokens, intentAmounts, initData, executionDataForLeaf, signatureData
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_UsedRoot() public {
        bytes memory initData = ""; // no initData
        (bytes memory signatureData,, bytes memory executionDataForLeaf,) = _createDestinationValidData(true);
        address[] memory dstTokens2 = new address[](1);
        dstTokens2[0] = address(token);
        uint256[] memory intentAmounts2 = new uint256[](1);
        intentAmounts2[0] = 1;
        _getTokens(address(token), address(account), 1);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens2, intentAmounts2, initData, executionDataForLeaf, signatureData
        );

        vm.expectRevert(SuperDestinationExecutor.MERKLE_ROOT_ALREADY_USED.selector);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens2, intentAmounts2, initData, executionDataForLeaf, signatureData
        );
    }

    function _createDestinationValidData(bool validSignature)
        private
        returns (
            bytes memory signatureData,
            bytes memory executorCalldata,
            bytes memory executionDataForLeaf,
            uint48 validUntil
        )
    {
        address[] memory dstHookAddresses = new address[](0);
        bytes[] memory dstHookData = new bytes[](0);
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: dstHookAddresses, hooksData: dstHookData });
        executorCalldata = abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute));

        validUntil = uint48(block.timestamp + 100 days);
        executionDataForLeaf =
            abi.encode(executorCalldata, uint64(block.chainid), account, address(superDestinationExecutor), 1);
        bytes32[] memory leaves = new bytes32[](1);
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(token);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        leaves[0] = _createDestinationValidatorLeaf(
            executionDataForLeaf,
            uint64(block.chainid),
            account,
            address(superDestinationExecutor),
            dstTokens,
            intentAmounts,
            validUntil
        );

        (bytes32[][] memory merkleProof, bytes32 merkleRoot) = _createValidatorMerkleTree(leaves);

        bytes memory signature;
        if (validSignature) {
            signature = _createSignature(
                SuperValidatorBase(address(superDestinationValidator)).namespace(), merkleRoot, signer, signerPrvKey
            );
        } else {
            (address signerInvalid, uint256 signerPrvKeyInvalid) = makeAddrAndKey("signerInvalid");
            signature = _createSignature(
                SuperValidatorBase(address(superDestinationValidator)).namespace(),
                merkleRoot,
                signerInvalid,
                signerPrvKeyInvalid
            );
        }
        signatureData = abi.encode(validUntil, merkleRoot, merkleProof[0], merkleProof[0], signature);
    }
}
