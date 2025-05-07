// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { BatchTransferFromHook } from "../../../../../src/core/hooks/tokens/permit2/BatchTransferFromHook.sol";
import { IAllowanceTransfer } from "../../../../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";

contract BatchTransferFromHookTest is Helpers, InternalHelpers {
    BatchTransferFromHook public hook;

    address public usdc;
    address public weth;
    address public dai;
    address[] public tokens;

    uint256[] public amounts;

    address public eoa;

    address public account;

    IAllowanceTransfer public permit2;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        tokens = new address[](3);
        tokens[0] = usdc;
        tokens[1] = weth;
        tokens[2] = dai;

        amounts = new uint256[](3);
        amounts[0] = 1000e6;
        amounts[1] = 2e18;
        amounts[2] = 3e18;

        eoa = vm.addr(321);
        deal(usdc, eoa, 1000e6);
        deal(weth, eoa, 2e18);
        deal(dai, eoa, 3e18);

        account = _deployAccount(1, "TEST");

        hook = new BatchTransferFromHook(PERMIT2);
        permit2 = IAllowanceTransfer(PERMIT2);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new BatchTransferFromHook(address(0));
    }

    function test_Build_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        bytes memory hookData = _createBatchTransferFromHookData(address(0), 3, tokens, amounts);
        hook.build(address(0), account, hookData);
    }

    function test_Build_Executions() public {
        bytes memory hookData = _createBatchTransferFromHookData(eoa, 3, tokens, amounts);

        vm.startPrank(eoa);
        permit2.approve(usdc, account, 10e18, uint48(block.timestamp + 1_000_000_000_000_000_000));
        permit2.approve(weth, account, 10e18, uint48(block.timestamp + 1_000_000_000_000_000_000));
        permit2.approve(dai, account, 10e18, uint48(block.timestamp + 1_000_000_000_000_000_000));
        vm.stopPrank();

        Execution[] memory executions = hook.build(eoa, account, hookData);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(PERMIT2));
        assertEq(executions[0].value, 0);
    }
}
