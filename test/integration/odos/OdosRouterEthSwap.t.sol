// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";
import { strings } from "@stringutils/strings.sol";
import { SuperNativePaymaster } from "../../../src/core/paymaster/SuperNativePaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { AccountInstance, UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract OdosRouterEthSwap is BaseTest {
    using ModuleKitHelpers for *;
    using strings for *;

    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;

    uint256 public nodeOperatorPremium;
    uint256 public maxFeePerGas;
    uint256 public maxGasLimit;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        MockValidatorModule validator = new MockValidatorModule();
        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        instance = accountInstances[ETH];
        account = instance.account;
        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });

        token = CHAIN_1_USDC;

        maxFeePerGas = 10 gwei;
        maxGasLimit = 1_000_000;
        nodeOperatorPremium = 10; // 10%
    }

    function test_ETH_Swap_With_Odos_NoPaymaster() public {
        uint256 amount = 1e18;

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, ODOS_ROUTER[ETH], amount, false);

        QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
        quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(0), amount: amount });

        QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
        quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: token, proportion: 1 });
        string memory path = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, account, ETH, false);
        string memory requestBody = surlCallAssemble(path, account);

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
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute), _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY)
        );
        opData.userOp.paymasterAndData = bytes("");

        uint256 tokenBalanceBefore = IERC20(token).balanceOf(account);

        executeOp(opData);

        uint256 tokenBalanceAfter = IERC20(token).balanceOf(account);
        assertGt(tokenBalanceAfter, tokenBalanceBefore);
    }

    function test_ETH_Swap_With_Odos_With_Paymaster() public {
        uint256 amount = 5e17;

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, SWAP_ODOS_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, ODOS_ROUTER[ETH], amount, false);

        QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
        quoteInputTokens[0] = QuoteInputToken({ tokenAddress: address(0), amount: amount });

        QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
        quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: token, proportion: 1 });
        string memory path = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, account, ETH, false);
        string memory requestBody = surlCallAssemble(path, account);

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

        address paymaster = _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY);
        SuperNativePaymaster superNativePaymaster = SuperNativePaymaster(paymaster);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute), _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY)
        );

        uint256 tokenBalanceBefore = IERC20(token).balanceOf(account);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = opData.userOp;

        address bundler = vm.addr(1234);
        vm.deal(bundler, 30 ether);
        vm.prank(bundler);
        superNativePaymaster.handleOps{ value: 20 ether }(ops);

        uint256 tokenBalanceAfter = IERC20(token).balanceOf(account);
        assertGt(tokenBalanceAfter, tokenBalanceBefore);
    }
}
