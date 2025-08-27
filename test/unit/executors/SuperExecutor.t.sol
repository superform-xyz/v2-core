// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperSenderCreator } from "../../../src/executors/helpers/SuperSenderCreator.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";
import { FluidClaimRewardHook } from "../../../src/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { BaseClaimRewardHook } from "../../../src/hooks/claim/BaseClaimRewardHook.sol";
import { MaliciousToken } from "../../mocks/MaliciousToken.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { TokenWithTransferControl } from "../../mocks/TokenWithTransferControl.sol";
import { MockStakingRewards } from "../../mocks/MockStakingRewards.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { MockNexusFactory } from "../../mocks/MockNexusFactory.sol";
import { MockLedger, MockLedgerConfiguration } from "../../mocks/MockLedger.sol";

import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook, Execution } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

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
    MockHook public mintSuperPositionHook;
    MockLedger public ledger;
    MockNexusFactory public nexusFactory;
    MockLedgerConfiguration public ledgerConfig;
    address public feeRecipient;
    AccountInstance public instance;
    address public signer;
    uint256 public signerPrvKey;
    SuperSenderCreator public senderCreator;

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
        superDestinationExecutor =
            new SuperDestinationExecutor(address(ledgerConfig), address(superDestinationValidator));

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

        senderCreator = new SuperSenderCreator();
        vm.label(address(senderCreator), "SuperSenderCreator");
    }

    // ---------------- SUPER SENDER CREATOR ------------------
    function test_superSenderCreator_InvalidCode() public {
        address returned = senderCreator.createSender("");
        assertEq(returned, address(0));
    }

    function test_superSenderCreator_FailedCall() public {
        bytes memory data =
            abi.encodePacked(address(this), abi.encodeWithSelector(this.superSenderCreatorCall.selector));
        address returned = senderCreator.createSender(data);
        assertEq(returned, address(0));
    }

    // ---------------- BASE EXECUTOR ------------------
    function test_BaseExecutor_Deploy() public {
        vm.expectRevert(ISuperExecutor.ADDRESS_NOT_VALID.selector);
        superSourceExecutor = new SuperExecutor(address(0));
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

    function test_SourceExecutor_Execute_WithNoHooks() public {
        address[] memory hooksAddresses = new address[](0);
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.startPrank(account);
        vm.expectRevert(ISuperExecutor.NO_HOOKS.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_Execute_WithHooksMismatch() public {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(this);
        bytes[] memory hooksData = new bytes[](0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.startPrank(account);
        vm.expectRevert(ISuperExecutor.LENGTH_MISMATCH.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_Execute_WithHooks() public {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(inflowHook);
        hooksAddresses[1] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            1,
            false,
            address(0),
            0
        );
        hooksData[1] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            account,
            1,
            false
        );

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

    function test_SourceExecutor_Execute_WithNoExecutionHook() public {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            1,
            true,
            address(0),
            0
        );

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(inflowHook),
            value: 0,
            callData: abi.encodeCall(inflowHook.preExecute, (address(0), address(0), ""))
        });
        // this should return an invalid case
        inflowHook.setExecutions(executions);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.startPrank(account);
        vm.expectRevert(ISuperExecutor.MALICIOUS_HOOK_DETECTED.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_Execute_WithInvalidCaller() public {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            1,
            true,
            address(0),
            0
        );

        inflowHook.setOverrideLastCaller(true);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.startPrank(account);
        vm.expectRevert(ISuperExecutor.INVALID_CALLER.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_Execute_WithHooks_InvalidHook() public {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(0);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            1,
            true,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.startPrank(account);
        vm.expectRevert(ISuperExecutor.ADDRESS_NOT_VALID.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Inflow() public {
        inflowHook.setOutAmount(1000, address(this));

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            1,
            false,
            address(0),
            0
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_WithFee() public {
        vm.startPrank(account);

        outflowHook.setOutAmount(1000, address(this));
        outflowHook.setUsedShares(500);
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            account,
            1,
            false
        );

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
        invalidHook.setOutAmount(1000, address(this));
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(invalidHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            account,
            1,
            false
        );

        vm.startPrank(makeAddr("account"));
        superSourceExecutor.onInstall("");

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert();
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_RevertIf_InsufficientBalance() public {
        outflowHook.setOutAmount(1000, address(this));
        ledger.setFeeAmount(100);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            account,
            1,
            false
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(ISuperExecutor.INSUFFICIENT_BALANCE_FOR_FEE.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_WrongData() public view {
        // the following PoC demonstrates the length can be 228 but execution is invalid
        ISuperExecutor.ExecutorEntry memory entry;
        entry.hooksAddresses = new address[](0);
        entry.hooksData = new bytes[](0);

        bytes memory entryData = abi.encode(entry);
        assertEq(entryData.length, 160);
        console2.logBytes(entryData);

        bytes memory alternativeEntryData = bytes.concat(
            hex"0000000000000000000000000000000000000000000000000000000000000020",
            hex"0000000000000000000000000000000000000000000000000000000000000040",
            hex"0000000000000000000000000000000000000000000000000000000000000040",
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            hex"0000000000000000000000000000000000000000000000000000000000000000"
        );

        bytes memory fullData = abi.encodeCall(this.execute, alternativeEntryData);
        assertEq(fullData.length, 228);
        console2.logBytes(fullData);
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_RevertIf_FeeNotTransferred() public {
        MaliciousToken maliciousToken = new MaliciousToken();

        maliciousToken.blacklist(feeRecipient);

        MockHook maliciousHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(maliciousToken));
        maliciousHook.setOutAmount(910, address(this));
        maliciousHook.setUsedShares(500);

        ledger.setFeeAmount(100);

        MockLedgerConfiguration maliciousConfig =
            new MockLedgerConfiguration(address(ledger), feeRecipient, address(maliciousToken), 100, account);
        superSourceExecutor = new SuperExecutor(address(maliciousConfig));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superSourceExecutor), data: "" });

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(maliciousHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            account,
            1,
            false
        );

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

    function test_SourceExecutor_UpdateAccounting_Outflow_WithFee_NativeToken() public {
        // Create a new native token hook
        MockHook nativeHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(0));
        nativeHook.setOutAmount(1000, address(this));
        nativeHook.setUsedShares(500);
        ledger.setFeeAmount(100);

        // Configure hook addresses and data
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(nativeHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(0), // Native token as address(0)
            account,
            1,
            false
        );

        // Fund the account with ETH
        vm.deal(account, 1000);

        // Execute the hook
        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Check initial balances
        uint256 initialFeeRecipientBalance = feeRecipient.balance;
        uint256 initialAccountBalance = account.balance;

        // Execute and process the hook
        superSourceExecutor.execute(abi.encode(entry));

        // Verify fee was transferred correctly
        assertEq(account.balance, initialAccountBalance - 100, "Native fee should be deducted from account");
        assertEq(
            feeRecipient.balance, initialFeeRecipientBalance + 100, "Fee recipient should receive native token fee"
        );
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_WithFee_NativeTokenSentinel() public {
        // Create a hook that uses NATIVE_TOKEN_SENTINEL
        MockHook nativeSentinelHook =
            new MockHook(ISuperHook.HookType.OUTFLOW, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
        nativeSentinelHook.setOutAmount(1000, address(this));
        nativeSentinelHook.setUsedShares(500);
        ledger.setFeeAmount(100);

        // Configure hook addresses and data
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(nativeSentinelHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
            account,
            1,
            false
        );

        // Fund the account with ETH
        vm.deal(account, 1000);

        // Execute the hook
        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Check initial balances
        uint256 initialFeeRecipientBalance = feeRecipient.balance;
        uint256 initialAccountBalance = account.balance;

        // Execute and process the hook
        superSourceExecutor.execute(abi.encode(entry));

        // Verify fee was transferred correctly
        assertEq(account.balance, initialAccountBalance - 100, "Native fee should be deducted from account");
        assertEq(
            feeRecipient.balance, initialFeeRecipientBalance + 100, "Fee recipient should receive native token fee"
        );
        vm.stopPrank();
    }

    function test_SourceExecutor_UpdateAccounting_Outflow_WithFee_NativeToken_InsufficientBalance() public {
        // Create a hook for native token
        MockHook nativeHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(0));
        nativeHook.setOutAmount(1000, address(this));
        nativeHook.setUsedShares(500);
        ledger.setFeeAmount(100);

        // Configure hook addresses and data
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(nativeHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createRedeem4626HookData(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(0), account, 1, false);

        // Don't fund the account - should have 0 ETH
        vm.deal(account, 0);

        // Try to execute the hook
        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Should revert due to insufficient balance
        vm.expectRevert(ISuperExecutor.INSUFFICIENT_BALANCE_FOR_FEE.selector);
        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_SourceExecutor_VaultBank() public {
        inflowHook.setOutAmount(1000, address(this));

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(inflowHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(token),
            1,
            false,
            address(0),
            0
        );

        vm.mockCall(address(inflowHook), abi.encodeWithSignature("vaultBank()"), abi.encode(address(this)));
        vm.mockCall(address(inflowHook), abi.encodeWithSignature("spToken()"), abi.encode(address(token)));
        vm.mockCall(address(inflowHook), abi.encodeWithSignature("dstChainId()"), abi.encode(1));
        vm.mockCall(
            address(this),
            abi.encodeWithSignature("lockAsset(bytes32,address,address,address,uint256,uint64)"),
            abi.encode(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
                address(account),
                address(token),
                address(inflowHook),
                1000,
                1
            )
        );

        vm.startPrank(account);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        superSourceExecutor.execute(abi.encode(entry));
        vm.stopPrank();
    }

    function test_claimTokenAvoidFee() public {
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);

        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        address rewardToken = address(_mockToken);
        FluidClaimRewardHook hook = new FluidClaimRewardHook();
        address stakingRewards = address(new MockStakingRewards(rewardToken));

        vm.mockCall(address(stakingRewards), abi.encodeWithSignature("rewardsToken()"), abi.encode(rewardToken));
        MockERC20(rewardToken).mint(stakingRewards, 1e18);

        address wrong_RewardToken = address(new MockERC20("Wrong Token", "FRT", 18));

        hooksAddresses[0] = address(hook);
        hooksData[0] = abi.encodePacked(bytes32(0), stakingRewards, wrong_RewardToken, account);

        vm.mockCall(address(stakingRewards), abi.encodeWithSignature("rewardsToken()"), abi.encode(rewardToken));
        vm.startPrank(account);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        vm.expectRevert(BaseClaimRewardHook.INVALID_REWARD_TOKEN.selector);
        superDestinationExecutor.execute(abi.encode(entry));
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
        new SuperDestinationExecutor(address(this), address(0));
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
        vm.expectRevert(ISuperDestinationExecutor.ARRAY_LENGTH_MISMATCH.selector);
        superDestinationExecutor.processBridgedExecution(
            address(token), address(this), dstTokens, intentAmounts, "", "", ""
        );
    }

    function test_DestinationExecutor_ProcessBridgedExecution_Revert_AccountCreated() public {
        vm.expectRevert(ISuperDestinationExecutor.ACCOUNT_NOT_CREATED.selector);
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
        bytes32 merkleRoot = bytes32(BytesLib.slice(signatureData, 96, 32));
        assertTrue(superDestinationExecutor.isMerkleRootUsed(address(account), merkleRoot));

        //shouldn't revert anymore; it just returns
        superDestinationExecutor.processBridgedExecution(
            address(token), address(account), dstTokens2, intentAmounts2, initData, executionDataForLeaf, signatureData
        );
        assertTrue(superDestinationExecutor.isMerkleRootUsed(address(account), merkleRoot));
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
        // Create execution that calls a simple view function that should succeed
        executorCalldata = abi.encodeWithSelector(ISuperExecutor.version.selector);

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
            validUntil,
            address(superDestinationValidator)
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
        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: executionDataForLeaf,
            executor: address(superDestinationExecutor),
            dstTokens: dstTokens,
            intentAmounts: intentAmounts,
            account: account,
            validator: address(superDestinationValidator)
        });
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] =
            ISuperValidator.DstProof({ proof: merkleProof[0], dstChainId: uint64(block.chainid), info: dstInfo });
        uint64[] memory chainsWithDestExecutionExecutor = new uint64[](0);
        signatureData =
            abi.encode(chainsWithDestExecutionExecutor, validUntil, 0, merkleRoot, merkleProof[0], proofDst, signature);
    }

    function test_FeeToleranceIsOnePercent() public {
        // Create a test token with precise control over transfer amounts
        TokenWithTransferControl feeToken = new TokenWithTransferControl("Fee Token", "FEE", 18);
        feeToken.setFeeRecipient(feeRecipient);

        // Create a mock hook for outflow operations
        MockHook outflowTestHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(feeToken));
        outflowTestHook.setOutAmount(1000 * 10 ** 18, address(this));
        outflowTestHook.setUsedShares(500);

        // Set up executor with new ledger configuration
        MockLedgerConfiguration testConfig = new MockLedgerConfiguration(
            address(ledger),
            feeRecipient,
            address(feeToken),
            1000, // 10% fee rate
            account
        );

        SuperExecutor testExecutor = new SuperExecutor(address(testConfig));

        // Initialize executor in the account
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(testExecutor), data: "" });

        // Make sure account has sufficient balance
        uint256 initialBalance = 100_000 * 10 ** 18;
        feeToken.mint(account, initialBalance);

        // Calculate the expected fee (10% of 1000 tokens)
        uint256 feeAmount = 100 * 10 ** 18; // 10% of 1000 tokens

        // Calculate 1% tolerance
        uint256 onePercent = feeAmount / 100; // Exactly 1%

        console2.log("Testing fee tolerance with:");
        console2.log(" - Fee amount:", feeAmount);
        console2.log(" - 1% tolerance:", onePercent);
        console2.log(" - Min allowed:", feeAmount - onePercent);
        console2.log(" - Max allowed:", feeAmount + onePercent);

        // Create execution entry with our test hook
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowTestHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(feeToken),
            account,
            1000, // Amount
            false // Use amount from previous hook
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Test case 1: Exact transfer amount (should pass)
        vm.prank(account);
        testExecutor.execute(abi.encode(entry));

        // Test case 2: Exactly 1% less than expected (at lower boundary, should pass)
        uint256 exactlyOnePercentLess = feeAmount - onePercent;
        feeToken.setTransferOverride(true);
        feeToken.setCustomTransferAmount(exactlyOnePercentLess);

        vm.prank(account);
        testExecutor.execute(abi.encode(entry));

        // Test case 3: Exactly 1% more than expected (at upper boundary, should pass)
        uint256 exactlyOnePercentMore = feeAmount + onePercent;
        feeToken.setCustomTransferAmount(exactlyOnePercentMore);

        vm.prank(account);
        testExecutor.execute(abi.encode(entry));

        // Test case 4: Just under 1% less (within tolerance, should pass)
        uint256 slightlyLessThanOnePercent = feeAmount - onePercent + 1;
        feeToken.setCustomTransferAmount(slightlyLessThanOnePercent);

        vm.prank(account);
        testExecutor.execute(abi.encode(entry));
    }

    function test_FeeToleranceIsOnePercent_2() public {
        // Create a test token with precise control over transfer amounts
        TokenWithTransferControl feeToken = new TokenWithTransferControl("Fee Token", "FEE", 18);
        feeToken.setFeeRecipient(feeRecipient);

        // Create a mock hook for outflow operations
        MockHook outflowTestHook = new MockHook(ISuperHook.HookType.OUTFLOW, address(feeToken));
        outflowTestHook.setOutAmount(1000 * 10 ** 18, address(this));
        outflowTestHook.setUsedShares(500);

        // Set up executor with new ledger configuration

        MockLedgerConfiguration testConfig = new MockLedgerConfiguration(
            address(ledger),
            feeRecipient,
            address(feeToken),
            1000, // 10% fee rate
            account
        );

        SuperExecutor testExecutor = new SuperExecutor(address(testConfig));

        // Initialize executor in the account
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(testExecutor), data: "" });

        // Make sure account has sufficient balance
        uint256 initialBalance = 100_000 * 10 ** 18;
        feeToken.mint(account, initialBalance);

        // Calculate the expected fee (10% of 1000 tokens)
        uint256 feeAmount = 100 * 10 ** 18; // 10% of 1000 tokens

        // Calculate 1% tolerance
        uint256 onePercent = feeAmount / 100; // Exactly 1%

        console2.log("Testing fee tolerance with:");
        console2.log(" - Fee amount:", feeAmount);
        console2.log(" - 1% tolerance:", onePercent);
        console2.log(" - Min allowed:", feeAmount - onePercent);
        console2.log(" - Max allowed:", feeAmount + onePercent);
        console2.log(" - FeeToken:", address(feeToken));

        // Create execution entry with our test hook
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(outflowTestHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(feeToken),
            account,
            1000, // Amount
            false // Use amount from previous hook
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Test case 5: Just over 1% less (exceeds tolerance, should fail)
        uint256 slightlyMoreThanOnePercent = feeAmount - onePercent - 2;
        ledger.setFeeAmount(feeAmount);
        feeToken.setTransferOverride(true);
        feeToken.setCustomTransferAmount(slightlyMoreThanOnePercent);
        vm.expectRevert();
        vm.prank(account);
        testExecutor.execute(abi.encode(entry));
    }

    struct ExecutionContext {
        bytes executorCalldata;
        bytes executionDataForLeaf;
        bytes32[] leaves;
        address[] dstTokens;
        uint256[] intentAmounts;
        bytes32[][] merkleProof;
        bytes32 merkleRoot;
        bytes signature;
        bytes signatureData;
    }

    function test_DestinationExecutor_ValidateBalances_RejectsZeroIntentAmount() public {
        bytes memory initData = "";

        address[] memory dstHookAddresses = new address[](0);
        bytes[] memory dstHookData = new bytes[](0);
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: dstHookAddresses, hooksData: dstHookData });

        ExecutionContext memory ctx;

        ctx.executorCalldata = abi.encodeWithSelector(ISuperExecutor.execute.selector, abi.encode(entryToExecute));

        uint48 validUntil = uint48(block.timestamp + 100 days);

        ctx.dstTokens = new address[](1);
        ctx.dstTokens[0] = address(token);
        ctx.intentAmounts = new uint256[](1);
        ctx.intentAmounts[0] = 0;

        ctx.executionDataForLeaf =
            abi.encode(ctx.executorCalldata, uint64(block.chainid), account, address(superDestinationExecutor), 1);

        ctx.leaves = new bytes32[](1);
        ctx.leaves[0] = _createDestinationValidatorLeaf(
            ctx.executionDataForLeaf,
            uint64(block.chainid),
            account,
            address(superDestinationExecutor),
            ctx.dstTokens,
            ctx.intentAmounts,
            validUntil,
            address(superDestinationValidator)
        );

        (ctx.merkleProof, ctx.merkleRoot) = _createValidatorMerkleTree(ctx.leaves);

        ctx.signature = _createSignature(
            SuperValidatorBase(address(superDestinationValidator)).namespace(), ctx.merkleRoot, signer, signerPrvKey
        );

        ISuperValidator.DstInfo memory dstInfo = ISuperValidator.DstInfo({
            data: ctx.executionDataForLeaf,
            executor: address(superDestinationExecutor),
            dstTokens: ctx.dstTokens,
            intentAmounts: ctx.intentAmounts,
            account: account,
            validator: address(superDestinationValidator)
        });
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] =
            ISuperValidator.DstProof({ proof: ctx.merkleProof[0], dstChainId: uint64(block.chainid), info: dstInfo });
        uint64[] memory chainsWithDestExecutionCtx = new uint64[](0);
        ctx.signatureData = abi.encode(
            chainsWithDestExecutionCtx, validUntil, 0, ctx.merkleRoot, ctx.merkleProof[0], proofDst, ctx.signature
        );

        vm.expectEmit(true, true, false, true);
        emit ISuperDestinationExecutor.SuperDestinationExecutorInvalidIntentAmount(account, address(token), 0);

        superDestinationExecutor.processBridgedExecution(
            address(token),
            address(account),
            ctx.dstTokens,
            ctx.intentAmounts,
            initData,
            ctx.executionDataForLeaf,
            ctx.signatureData
        );
    }

    function execute(bytes calldata data) external pure {
        ISuperExecutor.ExecutorEntry memory e = abi.decode(data, (ISuperExecutor.ExecutorEntry));
        console2.log("hooksAddresses.length", e.hooksAddresses.length);
        console2.log("hooksData.length", e.hooksData.length);

        for (uint256 i = 0; i < e.hooksAddresses.length; i++) {
            console2.logAddress(e.hooksAddresses[i]);
            console2.logBytes(e.hooksData[i]);
        }
    }

    // ---------------- DESTINATION EXECUTOR TESTS FOR _createAccount ------------------

    function test_CreateAccount_RevertIfZeroAddress() public {
        // Create initCode with zero address as senderCreator
        bytes memory zeroAddressInitCode = abi.encodePacked(address(0), abi.encodePacked("test data"));

        // Create a valid signature structure
        bytes32 merkleRoot = keccak256(abi.encode("test"));
        bytes32 sigHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encode(merkleRoot, block.chainid)))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrvKey, sigHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Prepare parameters for processBridgedExecution
        address tokenSent = address(token);
        address targetAccount = address(0);
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory initData = zeroAddressInitCode; // This will trigger _createAccount with zero address
        bytes memory executorCalldata = "";
        bytes memory userSignatureData = abi.encode(
            new bytes32[](0), // merkleProof
            merkleRoot,
            signature
        );

        // Call should revert with ADDRESS_NOT_VALID when _createAccount is called internally
        vm.expectRevert(ISuperExecutor.ADDRESS_NOT_VALID.selector);
        superDestinationExecutor.processBridgedExecution(
            tokenSent, targetAccount, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData
        );
    }

    function test_CreateAccount_RevertIfNotContract() public {
        // Use a regular EOA address that's not a contract
        address nonContractAddress = makeAddr("nonContractAddress");

        // Create initCode with non-contract address as senderCreator
        bytes memory nonContractInitCode = abi.encodePacked(nonContractAddress, abi.encodePacked("test data"));

        // Create a valid signature structure
        bytes32 merkleRoot = keccak256(abi.encode("test"));
        bytes32 sigHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encode(merkleRoot, block.chainid)))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrvKey, sigHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Prepare parameters for processBridgedExecution
        address tokenSent = address(token);
        address targetAccount = address(0);
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory initData = nonContractInitCode; // This will trigger _createAccount with a non-contract address
        bytes memory executorCalldata = "";
        bytes memory userSignatureData = abi.encode(
            new bytes32[](0), // merkleProof
            merkleRoot,
            signature
        );

        // Call should revert with SENDER_CREATOR_NOT_VALID when _createAccount is called internally
        vm.expectRevert(ISuperDestinationExecutor.SENDER_CREATOR_NOT_VALID.selector);
        superDestinationExecutor.processBridgedExecution(
            tokenSent, targetAccount, dstTokens, intentAmounts, initData, executorCalldata, userSignatureData
        );
    }

    function superSenderCreatorCall() external pure {
        revert("Test");
    }
}
