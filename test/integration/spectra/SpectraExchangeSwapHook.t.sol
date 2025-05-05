// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

import { SpectraExchangeSwapHook } from "../../../src/core/hooks/swappers/spectra/SpectraExchangeSwapHook.sol";
import { ApproveERC20Hook } from "../../../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";

contract SpectraExchangeSwapHookTest is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public spectraRouter;
    address public tokenIn;
    address public ptToken;

    ApproveERC20Hook public approveHook;
    SpectraExchangeSwapHook public hook;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        spectraRouter = CHAIN_1_SpectraRouter;
        vm.label(spectraRouter, "Spectra Router");
        tokenIn = CHAIN_1_USDC;
        vm.label(tokenIn, "USDC");
        ptToken = CHAIN_1_SPECTRA_PT_IPOR_USDC;
        vm.label(ptToken, "PT-IPOR-USDC");

        approveHook = new ApproveERC20Hook();
        hook = new SpectraExchangeSwapHook(SPECTRA_ROUTERS[ETH]);
    }

    function test_SpectraExchangeSwapHook_DepositAssetInPT() public {
        uint256 amount = 1e6;

        // get tokens
        deal(tokenIn, account, amount);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = address(approveHook);
        hookAddresses_[1] = address(hook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(tokenIn, spectraRouter, amount, false);
        hookData[1] = _createSpectraExchangeSwapHookData(false, 0, ptToken, tokenIn, amount, account);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute)
        );
        executeOp(opData);

        uint256 balance = IERC20(ptToken).balanceOf(account);
        assertGt(balance, 0);
    }
}
