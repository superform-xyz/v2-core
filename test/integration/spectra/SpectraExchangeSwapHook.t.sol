// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";

contract SpectraExchangeSwapHook is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public spectraRouter;
    address public tokenIn;
    address public ptToken;

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
    }

    function test_SpectraExchangeSwapHook_DepositAssetInPT() public {
        uint256 amount = 1e6;

        // get tokens
        deal(tokenIn, account, amount);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, SPECTRA_EXCHANGE_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(tokenIn, spectraRouter, amount, false);
        hookData[1] = _createSpectraExchangeSwapHookData(false, 0, ptToken, tokenIn, amount, account);

        
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute), _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY)
        );
        opData.userOp.paymasterAndData = bytes("");
        executeOp(opData);

        uint256 balance = IERC20(ptToken).balanceOf(account);
        assertGt(balance, 0);
    }
}