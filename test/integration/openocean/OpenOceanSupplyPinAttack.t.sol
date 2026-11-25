// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ApproveAndSwapOpenOceanHook } from "../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol";
import { SuperVaultSupplyPin } from "../../../src/hooks/swappers/SuperVaultSupplyPin.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../src/interfaces/ISuperHookSwap.sol";
import { MockSuperVaultStrategy } from "../../mocks/MockSuperVaultStrategy.sol";
import { Constants } from "../../utils/Constants.sol";
import { SuperVaultLike } from "../kyberswap/KyberSwapSupplyPinAttack.t.sol";

/// @dev The `caller` of OpenOcean's real `swap(caller, desc, calls)`: the exchange claims the input leg from the
///      strategy to `desc.srcReceiver` (this contract) and then hands control to `makeCalls`. No whitelist.
contract OpenOceanRoute {
    using SafeERC20 for IERC20;

    enum Mode {
        HONEST,
        PAY_NOTHING,
        DEPOSIT
    }

    IERC20 public immutable CASH;
    SuperVaultLike public immutable VAULT;
    address public immutable STRATEGY;
    address public immutable ATTACKER;
    Mode public mode;
    uint256 public amount;

    constructor(IERC20 cash, SuperVaultLike vault, address strategy, address attacker) {
        CASH = cash;
        VAULT = vault;
        STRATEGY = strategy;
        ATTACKER = attacker;
    }

    function set(Mode mode_, uint256 amount_) external {
        mode = mode_;
        amount = amount_;
    }

    function makeCalls(IOpenOceanCaller.CallDescription[] memory) external payable {
        if (mode == Mode.HONEST) {
            CASH.safeTransfer(STRATEGY, amount);
        } else if (mode == Mode.DEPOSIT) {
            CASH.forceApprove(address(VAULT), amount);
            VAULT.deposit(amount, ATTACKER);
        }
    }
}

/// @title OpenOceanSupplyPinAttackTest
/// @notice SUP-21772 on the REAL OpenOcean exchange (mainnet fork): our hook already forces dstReceiver = the
///         strategy, and the exchange measures that receiver's delta, so a deposit mid-route satisfied it before.
///         With the pin, the batch fails; honest routes pass.
contract OpenOceanSupplyPinAttackTest is Test, Constants {
    address public constant OPENOCEAN = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDC = CHAIN_1_USDC;
    address public constant WETH = CHAIN_1_WETH;
    address internal constant REFERRER = address(0xF0);
    uint256 internal constant FLAG_SHOULD_CLAIM = 0x02; // OpenOceanExchange._SHOULD_CLAIM: pull src from msg.sender
    uint256 internal constant FORK_BLOCK = 26_400_000;

    uint256 internal constant LEG = 10_000e6;
    uint256 internal constant FLOOR = 2.5 ether;
    uint256 internal constant LP_SHARES = 1000 ether;

    ApproveAndSwapOpenOceanHook internal hook;
    MockSuperVaultStrategy internal strategy;
    SuperVaultLike internal vault;
    OpenOceanRoute internal route;
    address internal attacker = makeAddr("attacker");
    address internal lp = makeAddr("lp");

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ApproveAndSwapOpenOceanHook(OPENOCEAN, REFERRER, NATIVE);
        strategy = new MockSuperVaultStrategy(address(this));
        vault = new SuperVaultLike(IERC20(WETH), address(strategy));
        strategy.setVault(address(vault));
        deal(WETH, lp, LP_SHARES);
        vm.startPrank(lp);
        IERC20(WETH).approve(address(vault), LP_SHARES);
        vault.deposit(LP_SHARES, lp);
        vm.stopPrank();
        deal(USDC, address(strategy), LEG);
        route = new OpenOceanRoute(IERC20(WETH), vault, address(strategy), attacker);
        deal(WETH, address(route), 10 ether);
    }

    function _txData() internal view returns (bytes memory) {
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = IOpenOceanCaller.CallDescription({ target: 0, gasLimit: 0, value: 0, data: hex"01" });
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceiver: address(route), // the exchange claims the input leg here
            dstReceiver: address(strategy), // forced by our hook
            amount: LEG,
            minReturnAmount: FLOOR,
            guaranteedAmount: FLOOR,
            flags: FLAG_SHOULD_CLAIM,
            referrer: REFERRER,
            permit: ""
        });
        return abi.encodeCall(IOpenOceanExchange.swap, (IOpenOceanCaller(address(route)), desc, calls));
    }

    function _args() internal view returns (MockSuperVaultStrategy.ExecuteArgs memory args) {
        bytes memory data = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: USDC,
                outputToken: WETH,
                inputAmount: LEG,
                outputQuote: FLOOR,
                outputMin: FLOOR,
                usePrevHookAmount: false
            }),
            abi.encode(_txData())
        );
        args.hooks = new address[](1);
        args.hooks[0] = address(hook);
        args.hookCalldata = new bytes[](1);
        args.hookCalldata[0] = data;
        args.expectedAssetsOrSharesOut = new uint256[](1);
        args.expectedAssetsOrSharesOut[0] = FLOOR;
    }

    function test_Honest_RealExchange_Passes() public {
        route.set(OpenOceanRoute.Mode.HONEST, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _args();
        strategy.executeHooks(args);
        assertEq(IERC20(WETH).balanceOf(address(strategy)), LP_SHARES + FLOOR);
        assertEq(IERC20(USDC).balanceOf(address(route)), LEG, "the exchange claimed the input leg to the route");
        assertEq(hook.getOutAmount(address(strategy)), FLOOR);
        assertEq(vault.totalSupply(), LP_SHARES);
    }

    function test_PayNothing_ExchangeRefuses() public {
        route.set(OpenOceanRoute.Mode.PAY_NOTHING, 0);
        MockSuperVaultStrategy.ExecuteArgs memory args = _args();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        assertEq(IERC20(USDC).balanceOf(address(strategy)), LEG);
    }

    function test_Attack_DepositMidSwap_FailsTheBatch() public {
        route.set(OpenOceanRoute.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _args();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        assertEq(IERC20(USDC).balanceOf(address(strategy)), LEG, "input leg still with the strategy");
        assertEq(vault.balanceOf(attacker), 0);
        assertEq(vault.totalSupply(), LP_SHARES);
    }

    /// @notice Direct leg: the real exchange ACCEPTS the poisoned route (receiver delta == floor, shares minted) and
    ///         the hook's post is what refuses it
    function test_Attack_DepositMidSwap_RealExchangeAccepts_PinRefuses() public {
        route.set(OpenOceanRoute.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _args();
        bytes memory data = args.hookCalldata[0];
        ISuperHook(address(hook)).setExecutionContext(address(strategy));
        vm.startPrank(address(strategy));
        hook.preExecute(address(0), address(strategy), data);
        IERC20(USDC).approve(OPENOCEAN, LEG);
        (bool ok,) = OPENOCEAN.call(_txData());
        assertTrue(ok, "the real exchange accepted the poisoned route");
        assertEq(vault.balanceOf(attacker), FLOOR, "shares minted mid-swap");
        assertEq(IERC20(USDC).balanceOf(address(route)), LEG, "input leg taken");
        vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
        hook.postExecute(address(0), address(strategy), data);
        vm.stopPrank();
    }
}
