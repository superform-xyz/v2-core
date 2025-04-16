// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";
import { strings } from "@stringutils/strings.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";
import { SuperNativePaymaster } from "../../../src/core/paymaster/SuperNativePaymaster.sol";
import "forge-std/console2.sol";


contract OdosRouterEthSwap is BaseTest {
    using strings for *;

    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;
    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        token = CHAIN_1_USDC;
    }

    function test_ETH_Swap_With_Odos_NoPaymaster() public {
        uint256 amount = 1e18;

    
        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, ODOS_ROUTER[ETH], amount, false);


        QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
        quoteInputTokens[0] = QuoteInputToken({
            tokenAddress: address(0),
            amount: amount
        });

        QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
        quoteOutputTokens[0] = QuoteOutputToken({
            tokenAddress: token,
            proportion: 1
        });
        string memory path = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, account, ETH, false);
        string memory requestBody = surlCallAssemble(path, account);

        OdosDecodedSwap memory odosDecodedSwap = decodeOdosSwapCalldata(fromHex(requestBody));
        bytes memory odosCalldata =
                _createOdosSwapHookData(
                    odosDecodedSwap.tokenInfo.inputToken,
                    odosDecodedSwap.tokenInfo.inputAmount,
                    odosDecodedSwap.tokenInfo.inputReceiver,
                    odosDecodedSwap.tokenInfo.outputToken,
                    odosDecodedSwap.tokenInfo.outputQuote,
                    odosDecodedSwap.tokenInfo.outputMin,
                    odosDecodedSwap.pathDefinition,
                    odosDecodedSwap.executor,
                    odosDecodedSwap.referralCode,
                    false
                );
        hookData[1] = odosCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute), _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY)
        );
        opData.userOp.paymasterAndData = bytes("");

        uint256 tokenBalanceBefore = IERC20(token).balanceOf(account);

        executeOp(opData);

        uint256 tokenBalanceAfter = IERC20(token).balanceOf(account);
        assertGt(tokenBalanceAfter, tokenBalanceBefore);
    }

    //@dev will do this after the others are done not to lose time on it
    /**
    function test_ETH_Swap_With_Odos_With_Paymaster() public {
        uint256 amount = 1e18;

    
        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, ODOS_ROUTER[ETH], amount, false);


        QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
        quoteInputTokens[0] = QuoteInputToken({
            tokenAddress: address(0),
            amount: amount
        });

        QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
        quoteOutputTokens[0] = QuoteOutputToken({
            tokenAddress: token,
            proportion: 1
        });
        string memory path = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, account, ETH, false);
        string memory requestBody = surlCallAssemble(path, account);

        OdosDecodedSwap memory odosDecodedSwap = decodeOdosSwapCalldata(fromHex(requestBody));
        bytes memory odosCalldata =
                _createOdosSwapHookData(
                    odosDecodedSwap.tokenInfo.inputToken,
                    odosDecodedSwap.tokenInfo.inputAmount,
                    odosDecodedSwap.tokenInfo.inputReceiver,
                    odosDecodedSwap.tokenInfo.outputToken,
                    odosDecodedSwap.tokenInfo.outputQuote,
                    odosDecodedSwap.tokenInfo.outputMin,
                    odosDecodedSwap.pathDefinition,
                    odosDecodedSwap.executor,
                    odosDecodedSwap.referralCode,
                    false
                );
        hookData[1] = odosCalldata;

        address paymaster = _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY);
        SuperNativePaymaster superNativePaymaster = SuperNativePaymaster(paymaster);
        vm.startPrank(superNativePaymaster.owner());
        superNativePaymaster.addStake{value: 2 ether}(1);
        vm.stopPrank();
        superNativePaymaster.entryPoint().depositTo{value: 2 ether}(address(superNativePaymaster));

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute), paymaster
        );

        //opData.userOp.accountGasLimits = bytes32(abi.encodePacked(uint128(2e12), uint128(2e12)));
        opData.userOp.paymasterAndData = bytes.concat(
            bytes20(address(paymaster)), 
            new bytes(32),
            abi.encode(uint128(2e6), uint128(1000)) 
        );
        uint256 tokenBalanceBefore = IERC20(token).balanceOf(account);

        executeOp(opData);

        uint256 tokenBalanceAfter = IERC20(token).balanceOf(account);
        assertGt(tokenBalanceAfter, tokenBalanceBefore);
    }
    */

}