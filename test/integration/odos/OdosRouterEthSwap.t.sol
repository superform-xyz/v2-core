// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

// Tests
import { strings } from "@stringutils/strings.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";
import { SwapOdosV2Hook } from "../../../src/hooks/swappers/odos/SwapOdosV2Hook.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MockOdosRouterV2 } from "../../mocks/MockOdosRouterV2.sol";

contract OdosRouterEthSwap is MinimalBaseIntegrationTest, OdosAPIParser {
    using ModuleKitHelpers for *;
    using strings for *;

    address public token;

    uint256 public nodeOperatorPremium;
    uint256 public maxFeePerGas;
    uint256 public maxGasLimit;

    MockOdosRouterV2 public odosRouter;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        MockValidatorModule validator = new MockValidatorModule();

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });

        maxFeePerGas = 10 gwei;
        maxGasLimit = 1_000_000;
        nodeOperatorPremium = 10; // 10%

        if (useRealOdosRouter) {
            token = CHAIN_1_USDC;
        } else {
            token = address(new MockERC20("Test Token", "TEST", 18));
            odosRouter = new MockOdosRouterV2();
        }
    }

    function test_OdosRouter_Swap() public {
        execute_ETH_Swap_With_Odos_NoPaymaster(useRealOdosRouter);

        execute_ETH_Swap_With_Odos_With_Paymaster(useRealOdosRouter);
    }

    function execute_ETH_Swap_With_Odos_NoPaymaster(bool useRealOdosRouter) public {
        uint256 amount = 1e18;

        if (useRealOdosRouter) {
            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = approveHook;
            hookAddresses_[1] = address(new SwapOdosV2Hook(CHAIN_1_ODOS_ROUTER));

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(token, CHAIN_1_ODOS_ROUTER, amount, false);

            QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
            quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(0), amount: amount });

            QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
            quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: token, proportion: 1 });
            string memory path = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, accountEth, ETH, false);
            string memory requestBody = surlCallAssemble(path, accountEth);

            OdosDecodedSwap memory odosDecodedSwap = decodeOdosSwapCalldata(fromHex(requestBody));
            bytes memory odosCalldata = _createOdosSwapHookData(
                odosDecodedSwap.tokenInfo.inputToken,
                odosDecodedSwap.tokenInfo.inputAmount,
                odosDecodedSwap.tokenInfo.inputReceiver,
                odosDecodedSwap.tokenInfo.outputToken,
                odosDecodedSwap.tokenInfo.outputQuote,
                odosDecodedSwap.tokenInfo.outputMin - odosDecodedSwap.tokenInfo.outputMin * 1e4 / 1e5,
                odosDecodedSwap.pathDefinition,
                odosDecodedSwap.executor,
                odosDecodedSwap.referralCode,
                false
            );
            hookData[1] = odosCalldata;

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

            UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

            uint256 tokenBalanceBefore = IERC20(token).balanceOf(accountEth);

            executeOp(opData);

            uint256 tokenBalanceAfter = IERC20(token).balanceOf(accountEth);
            assertGt(tokenBalanceAfter, tokenBalanceBefore);
        } else {
            deal(token, address(odosRouter), amount);

            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = approveHook;
            hookAddresses_[1] = address(new SwapOdosV2Hook(address(odosRouter)));

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(token, address(odosRouter), amount, false);

            QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
            quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(0), amount: amount });

            QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
            quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: token, proportion: 1 });

            bytes memory odosCalldata = abi.encodePacked(
                address(0),
                amount,
                accountEth,
                token,
                amount,
                amount - amount * 1e4 / 1e5,
                true,
                uint256(0),
                bytes(""),
                address(0),
                uint32(0),
                false
            );
            hookData[1] = odosCalldata;

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
            UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

            uint256 tokenBalanceBefore = IERC20(token).balanceOf(accountEth);

            executeOp(opData);

            uint256 tokenBalanceAfter = IERC20(token).balanceOf(accountEth);
            assertGt(tokenBalanceAfter, tokenBalanceBefore);
        }
    }

    function execute_ETH_Swap_With_Odos_With_Paymaster(bool useRealOdosRouter) public {
        uint256 amount = 5e17;

        if (useRealOdosRouter) {
            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = approveHook;
            hookAddresses_[1] = address(new SwapOdosV2Hook(CHAIN_1_ODOS_ROUTER));

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(token, CHAIN_1_ODOS_ROUTER, amount, false);

            QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
            quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(0), amount: amount });

            QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
            quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: token, proportion: 1 });
            string memory path = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, accountEth, ETH, false);
            string memory requestBody = surlCallAssemble(path, accountEth);

            OdosDecodedSwap memory odosDecodedSwap = decodeOdosSwapCalldata(fromHex(requestBody));
            bytes memory odosCalldata = _createOdosSwapHookData(
                odosDecodedSwap.tokenInfo.inputToken,
                odosDecodedSwap.tokenInfo.inputAmount,
                odosDecodedSwap.tokenInfo.inputReceiver,
                odosDecodedSwap.tokenInfo.outputToken,
                odosDecodedSwap.tokenInfo.outputQuote,
                odosDecodedSwap.tokenInfo.outputMin - odosDecodedSwap.tokenInfo.outputMin * 1e4 / 1e5,
                odosDecodedSwap.pathDefinition,
                odosDecodedSwap.executor,
                odosDecodedSwap.referralCode,
                false
            );
            hookData[1] = odosCalldata;

            address paymaster =
                address(new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032)));
            SuperNativePaymaster superNativePaymaster = SuperNativePaymaster(paymaster);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

            UserOpData memory opData =
                _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute), paymaster);

            uint256 tokenBalanceBefore = IERC20(token).balanceOf(accountEth);

            PackedUserOperation[] memory ops = new PackedUserOperation[](1);
            ops[0] = opData.userOp;

            address bundler = vm.addr(1234);
            vm.deal(bundler, 30 ether);
            vm.prank(bundler);
            superNativePaymaster.handleOps{ value: 20 ether }(ops);

            uint256 tokenBalanceAfter = IERC20(token).balanceOf(accountEth);
            assertGt(tokenBalanceAfter, tokenBalanceBefore);
        } else {
            deal(token, address(odosRouter), amount);

            address[] memory hookAddresses_ = new address[](2);
            hookAddresses_[0] = approveHook;
            hookAddresses_[1] = address(new SwapOdosV2Hook(address(odosRouter)));

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(token, address(odosRouter), amount, false);

            QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
            quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(0), amount: amount });

            QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
            quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: token, proportion: 1 });

            bytes memory odosCalldata = abi.encodePacked(
                address(0),
                amount,
                accountEth,
                token,
                amount,
                amount - amount * 1e4 / 1e5,
                true,
                uint256(0),
                bytes(""),
                address(0),
                uint32(0),
                false
            );
            hookData[1] = odosCalldata;

            address paymaster =
                address(new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032)));
            SuperNativePaymaster superNativePaymaster = SuperNativePaymaster(paymaster);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

            UserOpData memory opData =
                _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute), paymaster);

            uint256 tokenBalanceBefore = IERC20(token).balanceOf(accountEth);

            PackedUserOperation[] memory ops = new PackedUserOperation[](1);
            ops[0] = opData.userOp;

            address bundler = vm.addr(1234);
            vm.deal(bundler, 30 ether);
            vm.prank(bundler);
            superNativePaymaster.handleOps{ value: 20 ether }(ops);

            uint256 tokenBalanceAfter = IERC20(token).balanceOf(accountEth);
            assertGt(tokenBalanceAfter, tokenBalanceBefore);
        }
    }
}
