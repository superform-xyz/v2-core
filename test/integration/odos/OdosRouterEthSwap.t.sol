// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { strings } from "@stringutils/strings.sol";
import { SuperNativePaymaster } from "../../../src/core/paymaster/SuperNativePaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";
import { SwapOdosHook } from "../../../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract OdosRouterEthSwap is MinimalBaseIntegrationTest, OdosAPIParser {
    using ModuleKitHelpers for *;
    using strings for *;

    address public token;

    uint256 public nodeOperatorPremium;
    uint256 public maxFeePerGas;
    uint256 public maxGasLimit;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        MockValidatorModule validator = new MockValidatorModule();

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });

        token = CHAIN_1_USDC;

        maxFeePerGas = 10 gwei;
        maxGasLimit = 1_000_000;
        nodeOperatorPremium = 10; // 10%
    }

    function test_ETH_Swap_With_Odos_NoPaymaster() public {
        uint256 amount = 1e18;

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(new SwapOdosHook(CHAIN_1_ODOS_ROUTER));

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
            odosDecodedSwap.tokenInfo.outputMin,
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
    }

    function test_ETH_Swap_With_Odos_With_Paymaster() public {
        uint256 amount = 5e17;

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(new SwapOdosHook(CHAIN_1_ODOS_ROUTER));

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
            odosDecodedSwap.tokenInfo.outputMin,
            odosDecodedSwap.pathDefinition,
            odosDecodedSwap.executor,
            odosDecodedSwap.referralCode,
            false
        );
        hookData[1] = odosCalldata;

        address paymaster = address(new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032)));
        SuperNativePaymaster superNativePaymaster = SuperNativePaymaster(paymaster);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute), paymaster);

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
