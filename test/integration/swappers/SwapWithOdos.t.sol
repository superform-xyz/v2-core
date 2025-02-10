// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SuperExecutor } from "../../../src/core/executors/SuperExecutor.sol";

import { MockRegistry } from "../../mocks/MockRegistry.sol";

import { BaseE2ETest } from "../../BaseE2ETest.t.sol";


contract SwapWithOdosIntegrationTest is BaseE2ETest {
    MockRegistry nexusRegistry;
    address[] attesters;
    uint8 threshold;

    SuperExecutor superExecutor;
    bytes mockSignature;

    address tokenOut = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address tokenIn = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        nexusRegistry = new MockRegistry();
        attesters = new address[](1);

        attesters[0] = address(MANAGER);
        threshold = 1;

        mockSignature = abi.encodePacked(hex"41414141");

        superExecutor = SuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
    }
    /**
    function test_SwapIntegration_With_Odos_WETH_to_USDC() public {
        uint256 amount = SMALL;

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        vm.deal(nexusAccount, LARGE);

        // add tokens to account
        _getTokens(tokenIn, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        address router = address(SwapOdosHook(hooksAddresses[1]).odosRouterV2());
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(inputToken), router, amount, false);
        hooksData[1] = _createOdosSwapHookData(
            address(tokenIn),
            amount,
            account,
            address(tokenOut),
            0,
            amount,
            "",
            address(this),
            uint32(0),
            false
        );
        
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
    }
     */
}