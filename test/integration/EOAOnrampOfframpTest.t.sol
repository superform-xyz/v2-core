// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BaseTest } from "../BaseTest.t.sol";
import { console } from "forge-std/console.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";
import { IAllowanceTransfer } from "../../../../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";

contract EOAOnrampOfframpTest is BaseTest {
    address public eoa;

    AccountInstance public instance;
    address public account;

    IAllowanceTransfer public permit2;

    address public usdc;
    address public weth;
    address public dai;
    address[] public tokens;

    uint256[] public amounts;

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

        permit2 = IAllowanceTransfer(PERMIT2);
    }

    function test_EOAOnrampOfframp() public {
        vm.selectFork(FORKS[ETH]);

        vm.startPrank(eoa);
        permit2.approve(usdc, account, 10e18, uint48(block.timestamp + 1000000000000000000));
        permit2.approve(weth, account, 10e18, uint48(block.timestamp + 1000000000000000000));
        permit2.approve(dai, account, 10e18, uint48(block.timestamp + 1000000000000000000));
        vm.stopPrank();

        address[] memory hooks = new address[](1);
        hooks[0] = _getHookAddress(ETH, BATCH_TRANSFER_FROM_HOOK_KEY);

        bytes memory hookData = _createBatchTransferFromHookData(eoa, 3, tokens, amounts);
    }
}