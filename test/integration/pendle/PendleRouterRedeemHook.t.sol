// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PendleRouterRedeemHookTest is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;

    address public pendleMarket;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        token = underlyingTokens[ETH][USDC_KEY];
    }
}