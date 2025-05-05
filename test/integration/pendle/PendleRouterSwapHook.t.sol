// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";

contract PendleRouterSwapHook is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;

    address public pendlePufETHMarket;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        token = CHAIN_1_USDC;
        pendlePufETHMarket = 0x58612beB0e8a126735b19BB222cbC7fC2C162D2a;
    }

    // tx example: https://etherscan.io/tx/0x36b2c58e314e9d9bf73fc0d632ed228e35cd6b840066d12d39f72c633bad27a5
    function test_PendleRouterSwap_Token_To_Pt() public {
        if (!useRealOdosRouter) {
            return;
        }
        uint256 amount = 1e6;

        // get tokens
        deal(token, account, amount);
        IPendleMarket _market = IPendleMarket(pendlePufETHMarket);
        (address sy, address pt,) = _market.readTokens();
        // note syTokenIns [1] is WETH for this SY, which should have high liquidity
        address[] memory syTokenIns = IStandardizedYield(sy).getTokensIn();
        uint256 balance = IERC20(pt).balanceOf(account);
        assertEq(balance, 0);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, PENDLE_ROUTER_SWAP_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, PENDLE_ROUTERS[ETH], amount, false);
        hookData[1] = _createPendleRouterSwapHookDataWithOdos(
            pendlePufETHMarket, account, false, 1 ether, false, amount, CHAIN_1_USDC, syTokenIns[1], ETH
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute)
        );

        executeOp(opData);

        balance = IERC20(pt).balanceOf(account);
        assertGt(balance, 0);
    }
}
