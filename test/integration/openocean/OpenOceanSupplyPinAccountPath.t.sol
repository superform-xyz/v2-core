// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHookSwap } from "../../../src/interfaces/ISuperHookSwap.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ApproveAndSwapOpenOceanHook } from "../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { PinTestOpenOceanRouter } from "../../unit/hooks/swappers/SuperVaultSupplyPin.t.sol";

/// @title OpenOceanSupplyPinAccountPathTest
/// @notice The 4337 path through the patched OpenOcean hook: a Nexus account swaps via SuperExecutor while some vault
///         mints shares mid-swap, and the swap passes. The hook forces dstReceiver == account, the pin is a no-op.
contract OpenOceanSupplyPinAccountPathTest is MinimalBaseIntegrationTest {
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant REFERRER = address(0xF0);

    PinTestOpenOceanRouter internal router;
    ApproveAndSwapOpenOceanHook internal hook;
    ISuperNativePaymaster internal superNativePaymaster;
    MockERC20 internal outToken;
    MockERC20 internal someVaultShares;

    uint256 internal constant AMOUNT_IN = 1_000_000; // 1 USDC
    uint256 internal constant MIN_OUT = 5e17;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        router = new PinTestOpenOceanRouter();
        hook = new ApproveAndSwapOpenOceanHook(address(router), REFERRER, NATIVE);
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
        outToken = new MockERC20("Out", "OUT", 18);
        someVaultShares = new MockERC20("Some SuperVault", "svX", 18);
        _getTokens(CHAIN_1_USDC, accountEth, 10 * AMOUNT_IN);
        router.setMidSwapMint(address(someVaultShares), 1e18);
    }

    receive() external payable { }

    function _hookData() internal view returns (bytes memory) {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = IOpenOceanCaller.CallDescription({ target: 0, gasLimit: 0, value: 0, data: hex"01" });
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(CHAIN_1_USDC),
            dstToken: IERC20(address(outToken)),
            srcReceiver: address(0xCA11),
            dstReceiver: accountEth,
            amount: AMOUNT_IN,
            minReturnAmount: MIN_OUT,
            guaranteedAmount: MIN_OUT,
            flags: 0,
            referrer: REFERRER,
            permit: ""
        });
        bytes memory txData = abi.encodeCall(IOpenOceanExchange.swap, (IOpenOceanCaller(address(0xCA11)), desc, calls));
        return hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: CHAIN_1_USDC,
                outputToken: address(outToken),
                inputAmount: AMOUNT_IN,
                outputQuote: MIN_OUT,
                outputMin: MIN_OUT,
                usePrevHookAmount: false
            }),
            abi.encode(txData)
        );
    }

    function test_SmartAccount_OpenOceanSwapPasses_WhileSomeVaultMintsMidSwap() external {
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _hookData();
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
        assertEq(usdcBefore - IERC20(CHAIN_1_USDC).balanceOf(accountEth), AMOUNT_IN, "input spent");
        assertEq(outToken.balanceOf(accountEth), MIN_OUT, "output received");
        assertEq(someVaultShares.totalSupply(), 1e18, "the mint happened mid-swap");
        assertEq(hook.getOutAmount(accountEth), MIN_OUT);
    }
}
