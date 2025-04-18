// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { Swap1InchHook } from "../../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import { SuperExecutor } from "../../../src/core/executors/SuperExecutor.sol";
import "../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { ISuperHookOutflow } from "../../../src/core/interfaces/ISuperHook.sol";

import { Mock1InchRouter, MockDex } from "../../mocks/Mock1InchRouter.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockLockVault } from "../../mocks/MockLockVault.sol";
import { MockSuperPositionFactory } from "../../mocks/MockSuperPositionFactory.sol";
import { BaseTest } from "../../BaseTest.t.sol";
import { ExecutionReturnData } from "modulekit/test/RhinestoneModuleKit.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import "forge-std/console.sol";

import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { ExecLib } from "modulekit/accounts/kernel/lib/ExecLib.sol";
import { ModeLib, ModeCode } from "modulekit/accounts/common/lib/ModeLib.sol";
import { CallType, ExecType, ExecMode, ExecLib } from "modulekit/accounts/kernel/lib/ExecLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import "modulekit/test/RhinestoneModuleKit.sol";
import { ERC7579Precompiles } from "modulekit/deployment/precompiles/ERC7579Precompiles.sol";
import "modulekit/accounts/erc7579/ERC7579Factory.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";

import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import { Vm } from "forge-std/Test.sol";

contract SuperExecutor_sameChainFlow is BaseTest, ERC7579Precompiles {
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
    MockSuperPositionFactory public mockSuperPositionFactory;

    uint256 eoaKey;
    address account7702;
    ERC7579Factory erc7579factory;
    IERC7579Account erc7579account;
    IERC7579Bootstrap bootstrapDefault;
    address ledgerConfig;

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
        ledgerConfig = _getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY);
        mockSuperPositionFactory = new MockSuperPositionFactory(address(this));
        vm.label(address(mockSuperPositionFactory), "MockSuperPositionFactory");

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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_ReplaceCalldataAmount() public view {
        uint256 amount = LARGE;
        bytes memory hookData = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, account, SMALL, false, false
        );

        address hook = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        bytes memory replacedData = ISuperHookOutflow(hook).replaceCalldataAmount(hookData, amount);
        uint256 finalAmount = BytesLib.toUint256(BytesLib.slice(replacedData, 44, 32), 0);
        assertEq(finalAmount, amount);
    }

    function test_WhenHooksAreDefinedAndExecutionDataIsValid_Deposit_And_Withdraw_In_The_Same_Intent(uint256 amount)
        external
    {
        amount = _bound(amount);
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        hooksAddresses[2] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        hooksData[2] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, account, amount, false, false
        );
        // assure account has tokens
        _getTokens(underlying, account, amount);

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
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
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
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
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
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
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        emit ISuperLedgerData.AccountingInflow(account, yieldSourceOracle, yieldSourceAddress, amount, 1e18);
        executeOp(userOpData);

        assertEq(Mock1InchRouter(executor).swappedAmount(), amount);
    }

    function test_SwapThroughOdosRouter(uint256 amount) external {
        amount = _bound(amount);

        MockERC20 inputToken = new MockERC20("A", "A", 18);
        MockERC20 outputToken = new MockERC20("B", "B", 18);

        address swapHook;
        if (useRealOdosRouter) {
            swapHook = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);
        } else {
            swapHook = _getHookAddress(ETH, MOCK_SWAP_ODOS_HOOK_KEY);
        }

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = swapHook;

        _getTokens(address(inputToken), account, amount);
        _getTokens(address(outputToken), mockOdosRouters[ETH], amount);

        bytes memory approveData;
        if (useRealOdosRouter) {
            approveData = _createApproveHookData(address(inputToken), mockOdosRouters[ETH], amount, false);
        } else {
            approveData = _createApproveHookData(address(inputToken), mockOdosRouters[ETH], amount, false);
        }

        bytes memory odosCallData;
        if (useRealOdosRouter) {
            odosCallData = _createOdosCallData(address(inputToken), amount, address(outputToken), account);
        } else {
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
        }

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = approveData;
        hooksData[1] = odosCallData;

        // it should execute all hooks
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_SwapNativeThroughOdosAndDeposit4626() external {
        uint256 amount = 1 ether;

        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = _getHookAddress(ETH, MOCK_SWAP_ODOS_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[2] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
        );
        uint256 routerEthBalanceBefore = address(mockOdosRouters[ETH]).balance;
        _getTokens(address(underlying), mockOdosRouters[ETH], amount);

        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 routerEthBalanceAfter = address(mockOdosRouters[ETH]).balance;
        assertEq(routerEthBalanceAfter, routerEthBalanceBefore + amount);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertEq(accSharesAfter, sharesPreviewed);
    }

    function test_SwapUnderlyingToNativeAndThenUnderlying() external {
        uint256 amount = 1 ether;

        _getTokens(address(underlying), mockOdosRouters[ETH], amount);
        vm.deal(address(mockOdosRouters[ETH]), amount);

        address[] memory hooksAddresses = new address[](5);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, MOCK_SWAP_ODOS_HOOK_KEY);
        hooksAddresses[2] = _getHookAddress(ETH, MOCK_SWAP_ODOS_HOOK_KEY);
        hooksAddresses[3] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[4] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](5);
        hooksData[0] = _createApproveHookData(underlying, mockOdosRouters[ETH], amount, false);
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
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, true, false
        );

        uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstance.balanceOf(account);
        assertApproxEqRel(accSharesAfter, sharesPreviewed, 0.05e18);
    }

    function test_MockedSuperPositionFlow(uint256 amount) external {
        amount = _bound(amount);

        _getTokens(underlying, account, amount);

        superExecutor = SuperExecutor(_getContract(ETH, SUPER_EXECUTOR_WITH_SP_LOCK_KEY));

        // hooks list
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        // hooks data with lockSP true for the deposit hook
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, true
        );

        // execute
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        ExecutionReturnData memory executionReturnData =
            executeOp(_getExecOps(instance, superExecutor, abi.encode(entry)));

        // assert shares location
        {
            //uint256 sharesPreviewed = vaultInstance.previewDeposit(amount);
            //uint256 accSharesAfter = vaultInstance.balanceOf(address(lockVault));
            //assertEq(accSharesAfter, sharesPreviewed);
        }

        // retrieve logs and mint SP
        {
            for (uint256 i; i < executionReturnData.logs.length; ++i) {
                if (executionReturnData.logs[i].emitter == address(superExecutor)) {
                    if (address(uint160(uint256((executionReturnData.logs[i].topics[1])))) == account) {
                        console.log("\n SuperExecutor logs");

                        // mint SuperPositionMock to account
                        // should also create SP
                        uint256 precomputedId = mockSuperPositionFactory.getSPId(
                            yieldSourceAddress, bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), uint64(ETH)
                        );

                        uint256 spCountBefore = mockSuperPositionFactory.spCount();
                        mockSuperPositionFactory.mintSuperPosition(
                            uint64(ETH),
                            yieldSourceAddress,
                            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                            address(vaultInstance),
                            account,
                            amount
                        );
                        uint256 spCountAfter = mockSuperPositionFactory.spCount();
                        assertEq(spCountAfter, spCountBefore + 1);

                        assertNotEq(mockSuperPositionFactory.createdSPs(precomputedId), address(0));
                    }
                }
            }
        }
    }

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
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddress, amount, false, false
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

    function _get7702InitData() internal view returns (bytes memory) {
        bytes memory initData = erc7579factory.getInitData(address(_defaultValidator), "");
        return initData;
    }

    function _get7702InitDataWithExecutor(
        address validator,
        bytes memory initData
    )
        public
        view
        returns (bytes memory _init)
    {
        ERC7579BootstrapConfig[] memory _validators = new ERC7579BootstrapConfig[](1);
        _validators[0].module = validator;
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
