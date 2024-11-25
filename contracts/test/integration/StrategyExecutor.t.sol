// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// modulekit
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/external/ERC7579.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroReceiver.sol";
import { StrategyExecutor } from "src/mee-example/executor/StrategyExecutor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperPositions } from "src/interfaces/ISuperPositions.sol";
import { SuperPositions } from "src/superpositions/SuperPositions.sol";

import "forge-std/console.sol";

import { ModulesShared } from "test/shared/ModulesShared.t.sol";
import { ApproveERC20Hook } from "src/mee-example/hooks/erc20/ApproveERC20Hook.sol";
import { Deposit4626Hook } from "src/mee-example/hooks/erc4626/Deposit4626Hook.sol";
import { Shares4626SetterHook } from "src/mee-example/hooks/erc4626/Shares4626SetterHook.sol";
import { ReadAndMintSuperpositionHook } from "src/mee-example/hooks/superpositions/ReadAndMintSuperpositionHook.sol";
import { LzV2SendToChainHook } from "src/mee-example/hooks/lzv2/LzV2SendToChainHook.sol";
import { ERC4626Helpers } from "src/mee-example/ERC4626Helpers.sol";
import { ComposabilityStorageMock } from "src/mee-example/ComposabilityStorageMock.sol";
import { SuperLZV2 } from "src/mee-example/bridges/SuperLZV2.sol";
import { SuperPositionHelper } from "src/mee-example/SuperPositionHelper.sol";

import { Vm } from "forge-std/Vm.sol";

contract StrategyExecutorTests is ModulesShared {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    StrategyExecutor strategyExecutor;

    ApproveERC20Hook approveERC20Hook;
    Shares4626SetterHook shares4626SetterHook;
    Deposit4626Hook deposit4626Hook;
    ReadAndMintSuperpositionHook readAndMintSuperpositionHook;
    LzV2SendToChainHook lzV2SendToChainHook;

    ERC4626Helpers erc4626Helpers;
    ComposabilityStorageMock composabilityStorageMock;
    SuperLZV2 superLZV2;
    SuperPositionHelper superPositionHelper;

    address public constant ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    ISuperPositions public sp;

    function setUp() public override {
        super.setUp();

        erc4626Helpers = new ERC4626Helpers();
        strategyExecutor = new StrategyExecutor();
        composabilityStorageMock = new ComposabilityStorageMock();
        superPositionHelper = new SuperPositionHelper(address(composabilityStorageMock));
        superLZV2 = new SuperLZV2(address(strategyExecutor), address(this), address(this));

        deposit4626Hook = new Deposit4626Hook(address(superRegistrySrc));
        approveERC20Hook = new ApproveERC20Hook(address(superRegistrySrc));
        shares4626SetterHook = new Shares4626SetterHook(
            address(superRegistrySrc), address(composabilityStorageMock), address(erc4626Helpers)
        );
        readAndMintSuperpositionHook =
            new ReadAndMintSuperpositionHook(address(superRegistrySrc), address(superPositionHelper));
        lzV2SendToChainHook = new LzV2SendToChainHook(address(superRegistrySrc), address(superLZV2));

        sp = ISuperPositions(new SuperPositions(address(superRegistrySrc), 18));
        vm.label(address(sp), "SuperPositions");

        // set-up deposit strategy
        address[] memory hooks = new address[](4);
        hooks[0] = address(approveERC20Hook); //approve
        hooks[1] = address(shares4626SetterHook); //use composability stack to store existing shares
        hooks[2] = address(deposit4626Hook); //deposit
        hooks[3] = address(shares4626SetterHook); //store obtained shares (difference between new - old shares)
        strategyExecutor.setStrategy(0, hooks);

        hooks = new address[](5);
        hooks[0] = address(approveERC20Hook); //approve
        hooks[1] = address(shares4626SetterHook); //use composability stack to store existing shares
        hooks[2] = address(deposit4626Hook); //deposit
        hooks[3] = address(shares4626SetterHook); //store obtained shares (difference between new - old shares)
        hooks[4] = address(lzV2SendToChainHook); //lzv2 send to chain
        strategyExecutor.setStrategy(1, hooks);

        hooks = new address[](1);
        hooks[0] = address(readAndMintSuperpositionHook);
        strategyExecutor.setStrategy(2, hooks);
    }

    function test_executeSimpleStrategy(uint256 amount) external whenAccountHasTokens {
        amount = bound(amount, SMALL, LARGE);
        uint256 strategyId = 0;

        // create call data for each hook
        // -- approve hook
        bytes memory approveHookData = abi.encode(address(wethMock), address(wethVault), amount);
        // -- shares4626SetterHook
        bytes memory setExistingSharesHookData = abi.encode(address(wethVault), address(instance.account), true);
        // -- deposit4626Hook
        bytes memory deposit4626HookData = abi.encode(address(wethVault), address(instance.account), amount);
        // -- shares4626SetterHook
        bytes memory obtainedSharesHookData = abi.encode(address(wethVault), address(instance.account), false);

        bytes[] memory hooksData = new bytes[](4);
        hooksData[0] = approveHookData;
        hooksData[1] = setExistingSharesHookData;
        hooksData[2] = deposit4626HookData;
        hooksData[3] = obtainedSharesHookData;

        Execution[] memory executions = strategyExecutor.executeStrategy(abi.encode(strategyId, hooksData));
        assertEq(executions.length, 5);

        UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
        userOpData.execUserOps();

        uint256 obtained = composabilityStorageMock.obtained();
        assertEq(obtained, amount);
    }

    function test_crossChainReceive(uint256 amount) external whenAccountHasTokens {
        amount = bound(amount, SMALL, LARGE);
        vm.deal(instance.account, LARGE);

        bytes[] memory hooksData = new bytes[](5);
        bytes memory dstHooksPayload;
        {
            // create destination chain hooks
            bytes memory readAndMintSuperpositionHookData = abi.encode(address(sp), address(instance.account));

            // create source chain hooks
            // -- approve hook
            bytes memory approveHookData = abi.encode(address(wethMock), address(wethVault), amount);
            // -- shares4626SetterHook
            bytes memory setExistingSharesHookData = abi.encode(address(wethVault), address(instance.account), true);
            // -- deposit4626Hook
            bytes memory deposit4626HookData = abi.encode(address(wethVault), address(instance.account), amount);
            // -- shares4626SetterHook
            bytes memory obtainedSharesHookData = abi.encode(address(wethVault), address(instance.account), false);
            // -- lzv2SendToChainHook
            uint256 lzV2SendToChainValue = 0.1 ether;
            bytes[] memory dstCalls = new bytes[](1);
            dstCalls[0] = readAndMintSuperpositionHookData;
            dstHooksPayload = abi.encode(2, dstCalls);
            bytes memory bridgePayload = abi.encode(1, dstHooksPayload, "");
            bytes memory lzv2SendToChainHookData = abi.encode(lzV2SendToChainValue, bridgePayload);

            hooksData = new bytes[](5);
            hooksData[0] = approveHookData;
            hooksData[1] = setExistingSharesHookData;
            hooksData[2] = deposit4626HookData;
            hooksData[3] = obtainedSharesHookData;
            hooksData[4] = lzv2SendToChainHookData;
        }
        Execution[] memory executions = strategyExecutor.executeStrategy(abi.encode(1, hooksData));
        UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
        userOpData.execUserOps();
        uint256 obtained = composabilityStorageMock.obtained();
        assertEq(obtained, amount);

        // simulate receive call
        superLZV2.receiveMock(dstHooksPayload);

        // -- read executions from bridge. Please check comment from SuperLZV2.sol contract
        executions = superLZV2.getExecutions();
        assertEq(executions.length, 1);
        userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
        userOpData.execUserOps();
        uint256 spBalance = IERC20(address(sp)).balanceOf(instance.account);
        assertEq(spBalance, amount);
    }

    // lz methods
    function send(MessagingParams memory params, address refundAddress) public payable { }
    function setDelegate(address delegate_) public pure { }
}
