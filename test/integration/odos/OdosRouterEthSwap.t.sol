// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";
import { strings } from "@stringutils/strings.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
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

    uint256 public nodeOperatorPremium;
    uint256 public maxFeePerGas;
    uint256 public maxGasLimit;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

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

    function test_ETH_Swap_With_Odos_With_Paymaster() public {
        uint256 amount = 5e17;
    
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
        // vm.startPrank(superNativePaymaster.owner());
        // superNativePaymaster.addStake{value: 5 ether}(1 weeks);
        
        // superNativePaymaster.entryPoint().depositTo{value: 5 ether}(address(superNativePaymaster));
        // vm.stopPrank();

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: account,
            nonce: 0,
            initCode: bytes(""),
            callData: odosCalldata,
            accountGasLimits: bytes32(abi.encodePacked(uint128(0), uint128(25000000))),
            preVerificationGas: 10000000,
            gasFees: bytes32(abi.encodePacked(uint128(1e3), uint128(1e3))),
            paymasterAndData: bytes.concat(
                bytes20(address(paymaster)), 
                abi.encodePacked(uint128(2e6), // verificationGasLimit
                abi.encodePacked(uint128(1e6)), // postOpGasLimit
                abi.encode(maxGasLimit, nodeOperatorPremium) // callGasLimit
            )),
            signature: bytes("")
        });

        uint256 tokenBalanceBefore = IERC20(token).balanceOf(account);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        vm.prank(account);
        superNativePaymaster.handleOps{value: 20e18}(ops);

        uint256 tokenBalanceAfter = IERC20(token).balanceOf(account);
        assertGt(tokenBalanceAfter, tokenBalanceBefore);
    }
}