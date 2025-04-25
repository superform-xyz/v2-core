// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { BatchTransferFromHook } from "../../../../../src/core/hooks/tokens/permit2/BatchTransferFromHook.sol";

contract BatchTransferFromHookTest is BaseTest {
    BatchTransferFromHook public hook;

    address public usdc;
    address public weth;
    address public dai;
    address[] public tokens;

    uint256[] public amounts;

    address public eoa;

    AccountInstance public instance;
    address public account;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        usdc = existingUnderlyingTokens[ETH][USDC_KEY];
        weth = existingUnderlyingTokens[ETH][WETH_KEY];
        dai = existingUnderlyingTokens[ETH][DAI_KEY];

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

        instance = accountInstances[ETH];
        account = instance.account;

        hook = new BatchTransferFromHook(PERMIT2);
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
}
