// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHookSwap } from "../../../src/interfaces/ISuperHookSwap.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ApproveAndSwapKyberSwapHook } from "../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { IMetaAggregationRouterV2 } from "../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { MockKyberSwapRouter } from "../../mocks/MockKyberSwapRouter.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/// @title KyberSwapSupplyPinAccountPathTest
/// @notice The 4337 path is untouched by the pin: a Nexus smart account swaps through the patched
///         ApproveAndSwapKyberSwapHook via SuperExecutor while some vault mints shares mid-swap, and the swap passes.
///         A smart account has no getVaultInfo(), so the pin commits to zero on both sides.
contract KyberSwapSupplyPinAccountPathTest is MinimalBaseIntegrationTest {
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockKyberSwapRouter internal router;
    ApproveAndSwapKyberSwapHook internal hook;
    ISuperNativePaymaster internal superNativePaymaster;
    MockERC20 internal someVaultShares;

    uint256 internal constant AMOUNT_IN = 1_000_000; // 1 USDC
    uint256 internal constant MIN_OUT = 1e5; // 0.001 WBTC

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        router = new MockKyberSwapRouter();
        hook = new ApproveAndSwapKyberSwapHook(address(router), address(0), NATIVE);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
        someVaultShares = new MockERC20("Some SuperVault", "svX", 18);
        _getTokens(CHAIN_1_USDC, accountEth, 10 * AMOUNT_IN);
        deal(CHAIN_1_WBTC, address(router), 1e8);
        // a vault somewhere mints shares during every swap: irrelevant to a smart account
        router.setMidSwapMint(address(someVaultShares), 1e18);
    }

    receive() external payable { }

    function _hookData() internal view returns (bytes memory) {
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc;
        desc.srcToken = IERC20(CHAIN_1_USDC);
        desc.dstToken = IERC20(CHAIN_1_WBTC);
        desc.dstReceiver = accountEth;
        desc.amount = AMOUNT_IN;
        desc.minReturnAmount = MIN_OUT;
        bytes memory txData = abi.encodeCall(
            IMetaAggregationRouterV2.swap,
            (IMetaAggregationRouterV2.SwapExecutionParams({
                    callTarget: address(0xCA11),
                    approveTarget: address(router),
                    clientData: "",
                    desc: desc,
                    targetData: ""
                }))
        );
        return hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: CHAIN_1_USDC,
                outputToken: CHAIN_1_WBTC,
                inputAmount: AMOUNT_IN,
                outputQuote: MIN_OUT,
                outputMin: MIN_OUT,
                usePrevHookAmount: false
            }),
            abi.encode(txData)
        );
    }

    function test_SmartAccount_SwapPasses_WhileSomeVaultMintsMidSwap() external {
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(accountEth);
        uint256 supplyBefore = someVaultShares.totalSupply();

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _hookData();
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);

        assertEq(usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), AMOUNT_IN, "input spent");
        assertEq(IERC20(CHAIN_1_WBTC).balanceOf(accountEth) - wbtcBefore, MIN_OUT, "output received");
        assertEq(someVaultShares.totalSupply(), supplyBefore + 1e18, "the mint happened mid-swap");
        assertEq(hook.getOutAmount(accountEth), MIN_OUT, "outAmount is the plain delta");
    }
}
