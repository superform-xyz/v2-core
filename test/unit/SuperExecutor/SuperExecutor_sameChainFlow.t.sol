// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperCollectiveVault } from "../../../src/core/interfaces/ISuperCollectiveVault.sol";
import { Swap1InchHook } from "../../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import "../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";

import { Mock1InchRouter, MockDex } from "../../mocks/Mock1InchRouter.sol";
import { SwapOdosHook } from "../../../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { MockOdosRouterV2 } from "../../mocks/MockOdosRouterV2.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockLockVault } from "../../mocks/MockLockVault.sol";
import { MockSuperPositionFactory } from "../../mocks/MockSuperPositionFactory.sol";
import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";
import { BaseTest } from "../../BaseTest.t.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";

import "forge-std/console.sol";
import {Vm} from "forge-std/Test.sol";

contract SuperExecutor_sameChainFlow is BaseTest {
    using AddressLib for Address;

    IERC4626 public vaultInstance;
    address public yieldSourceAddress;
    address public yieldSourceOracle;
    address public underlying;
    address public account;
    AccountInstance public instance;
    ISuperExecutor public superExecutor;
    SuperRegistry public superRegistry;
    MockSuperPositionFactory public mockSuperPositionFactory;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        underlying = existingUnderlyingTokens[1][USDC_KEY];

        yieldSourceAddress = realVaultAddresses[1][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];
        yieldSourceOracle = _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vaultInstance = IERC4626(yieldSourceAddress);
        account = accountInstances[ETH].account;
        instance = accountInstances[ETH];
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superRegistry = SuperRegistry(_getContract(ETH, SUPER_REGISTRY_KEY));
        mockSuperPositionFactory = new MockSuperPositionFactory(address(this));
        vm.label(address(mockSuperPositionFactory), "MockSuperPositionFactory");
    }

    function test_ShouldExecuteAll(uint256 amount) external {
        amount = _bound(amount);

        _getTokens(underlying, account, amount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
    {
        amount = _bound(amount);
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[2] = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        hooksData[2] = _createWithdraw4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, account, amount, false, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertGt(accSharesAfter, 0);
    }

    function test_SwapThrough1InchHook_GenericRouterCall() public {
        uint256 amount = SMALL;

        address executor = address(new Mock1InchRouter());
        vm.label(executor, "Mock1InchRouter");

        Swap1InchHook hook = new Swap1InchHook(_getContract(ETH, SUPER_REGISTRY_KEY), address(this), executor);
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
        hooksData[0] = _create1InchGenericRouterSwapHookData(account, underlying, executor, desc, "", "");

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThrough1InchHook_UnoswapToCall() public {
        uint256 amount = SMALL;

        address executor = address(new Mock1InchRouter());
        vm.label(executor, "Mock1InchRouter");

        Swap1InchHook hook = new Swap1InchHook(_getContract(ETH, SUPER_REGISTRY_KEY), address(this), executor);
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
            Address.wrap(uint256(uint160(address(mockDex))))
        );

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThrough1InchHook_ClipperSwapToCall() public {
        uint256 amount = SMALL;

        address executor = address(new Mock1InchRouter());
        vm.label(executor, "Mock1InchRouter");

        Swap1InchHook hook = new Swap1InchHook(_getContract(ETH, SUPER_REGISTRY_KEY), address(this), executor);
        vm.label(address(hook), SWAP_1INCH_HOOK_KEY);

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _create1InchClipperSwapToHookData(
            account, underlying, executor, Address.wrap(uint256(uint160(underlying))), amount
        );

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedger.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThroughMockOdosRouter(uint256 amount) external {
        amount = _bound(amount);

        MockERC20 inputToken = new MockERC20("A", "A", 18);
        MockERC20 outputToken = new MockERC20("B", "B", 18);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        _getTokens(address(inputToken), account, amount);
        _getTokens(address(outputToken), odosRouters[ETH], amount);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(inputToken), odosRouters[ETH], amount, false);
        hooksData[1] = _createOdosSwapHookData(
            address(inputToken), amount, account, address(outputToken), 0, amount, "", address(this), uint32(0), false
        );

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_MockedSuperPositionFlow(uint256 amount) external {
        amount = _bound(amount);

        _getTokens(underlying, account, amount);

        // create MockVault and set it as SuperCollectiveVault
        MockLockVault lockVault = new MockLockVault();
        vm.label(address(lockVault), "MockLockVault");
        superRegistry.setAddress(keccak256(bytes(SUPER_COLLECTIVE_VAULT_KEY)), address(lockVault));

        // hooks list
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        // hooks data with lockSP true for the deposit hook
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, true
        );

        // execute
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        ExecutionReturnData memory executionReturnData = executeOp(_getExecOps(instance, superExecutor, abi.encode(entry)));

        // assert shares location
        {
            //uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);
            //uint256 accSharesAfter = vaultInstance.balanceOf(address(lockVault));
            //assertEq(accSharesAfter, sharesPreviewed);
        }

        // retrieve logs and mint SP
        {
            for (uint256 i; i < executionReturnData.logs.length;) {
                if (executionReturnData.logs[i].emitter == address(superExecutor)) {
                    if (address(uint160(uint256((executionReturnData.logs[i].topics[1])))) == account) {
                        console.log("\n SuperExecutor logs");

                        // mint SuperPositionMock to account
                        // should also create SP
                        uint256 precomputedId = mockSuperPositionFactory.getSPId(yieldSourceAddress, bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), uint64(ETH));

                        uint256 spCountBefore = mockSuperPositionFactory.spCount();
                        mockSuperPositionFactory.mintSuperPosition(uint64(ETH), yieldSourceAddress, bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(vaultInstance), account, amount);
                        uint256 spCountAfter = mockSuperPositionFactory.spCount();
                        assertEq(spCountAfter, spCountBefore + 1);

                        assertNotEq(mockSuperPositionFactory.createdSPs(precomputedId), address(0));
                    }

                }
                unchecked { ++i; }
            }
        }
    }
}
