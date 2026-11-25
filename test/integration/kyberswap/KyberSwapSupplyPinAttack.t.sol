// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ApproveAndSwapKyberSwapHook } from "../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { SuperVaultSupplyPin } from "../../../src/hooks/swappers/SuperVaultSupplyPin.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { IMetaAggregationRouterV2 } from "../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../src/interfaces/ISuperHookSwap.sol";
import { MockSuperVaultStrategy } from "../../mocks/MockSuperVaultStrategy.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { Constants } from "../../utils/Constants.sol";

interface IOutAmountSetter {
    function setOutAmount(uint256 outAmount, address caller) external;
}

/// @dev The vault, with the two semantics that matter: `deposit` / `mint` forward the asset to the STRATEGY and pay the
///      depositor in shares, and shares can be moved (to an escrow, as a redeem request does) but not burned in-frame.
contract SuperVaultLike is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable ASSET;
    address public immutable STRATEGY;
    address public immutable ESCROW = address(0xE5C);

    constructor(IERC20 asset_, address strategy_) ERC20("SuperVault WETH", "svWETH") {
        ASSET = asset_;
        STRATEGY = strategy_;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        ASSET.safeTransferFrom(msg.sender, STRATEGY, assets);
        shares = assets; // PPS 1.0
        _mint(receiver, shares);
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = shares;
        ASSET.safeTransferFrom(msg.sender, STRATEGY, assets);
        _mint(receiver, shares);
    }

    /// @dev requestRedeem: shares leave the owner for the escrow, totalSupply is untouched
    function requestRedeem(uint256 shares) external {
        _transfer(msg.sender, ESCROW, shares);
    }
}

/// @dev Funds a route "paying itself" so the router's receiver-delta check can be met without the strategy seeing
/// anything
contract WethTreasury {
    using SafeERC20 for IERC20;

    IERC20 public immutable CASH;

    constructor(IERC20 cash) {
        CASH = cash;
    }

    function pay(address to, uint256 amount) external {
        CASH.safeTransfer(to, amount);
    }
}

/// @dev The payload's `callTarget`: Kyber's real `swap()` hands it the input leg (srcReceivers) and then calls
///      `callBytes(targetData)` on it with no whitelist. Each mode is one attempt to get past the pinned hook.
contract AttackerExecutor {
    using SafeERC20 for IERC20;

    enum Mode {
        HONEST, // pays the strategy the floor from its own inventory
        PAY_NOTHING, // keeps the input, pays nobody
        DEPOSIT, // THE FINDING: deposit own cash into the vault for the attacker
        MINT, // same through mint()
        DEPOSIT_THEN_PARK, // deposit, then move the shares to the escrow (supply unchanged by a transfer)
        HALF_HONEST_HALF_DEPOSIT, // the hooked-pool shape: part real payout, part deposit
        DEPOSIT_OTHER_VAULT, // deposit into an unrelated vault (credits a different strategy)
        CONTEXT_BUMP_THEN_DEPOSIT, // bump the hook's execution context first, then deposit
        CONTEXT_BUMP_HONEST_FAKE_ZERO, // pay honestly, bump the context, write outAmount = 0 (inflates the delta)
        CONTEXT_BUMP_HONEST_FAKE_MAX, // pay honestly, bump the context, write outAmount = max (underflows the delta)
        DEPOSIT_FOR_STRATEGY, // deposit own cash for the STRATEGY as receiver
        DEPOSIT_THEN_TRANSFER_TO_STRATEGY, // deposit for self, hand the shares to the strategy
        HONEST_PLUS_SELF_DEPOSIT, // the documented false positive: real payout AND an unrelated own deposit
        HONEST_TO_ROUTER, // fee-on-dst path: the router receives first and forwards to the receiver itself
        PAY_SELF // dstReceiver == the route: it pays ITSELF (from a treasury) so the router's receiver delta is met
    }

    IERC20 public immutable CASH; // the vault asset == the swap's output token
    SuperVaultLike public immutable VAULT;
    SuperVaultLike public immutable OTHER_VAULT;
    address public immutable STRATEGY;
    address public immutable ATTACKER;
    ISuperHook public immutable HOOK;
    address public TREASURY;
    Mode public mode;
    uint256 public amount;

    function setTreasury(address treasury) external {
        TREASURY = treasury;
    }

    constructor(
        IERC20 cash,
        SuperVaultLike vault,
        SuperVaultLike otherVault,
        address strategy,
        address attacker,
        ISuperHook hook
    ) {
        CASH = cash;
        VAULT = vault;
        OTHER_VAULT = otherVault;
        STRATEGY = strategy;
        ATTACKER = attacker;
        HOOK = hook;
    }

    function set(Mode mode_, uint256 amount_) external {
        mode = mode_;
        amount = amount_;
    }

    /// @dev IAggregationExecutor.callBytes, what the real router calls
    function callBytes(bytes calldata) external payable {
        if (mode == Mode.HONEST) {
            CASH.safeTransfer(STRATEGY, amount);
        } else if (mode == Mode.DEPOSIT) {
            CASH.forceApprove(address(VAULT), amount);
            VAULT.deposit(amount, ATTACKER);
        } else if (mode == Mode.MINT) {
            CASH.forceApprove(address(VAULT), amount);
            VAULT.mint(amount, ATTACKER);
        } else if (mode == Mode.DEPOSIT_THEN_PARK) {
            CASH.forceApprove(address(VAULT), amount);
            uint256 shares = VAULT.deposit(amount, address(this));
            VAULT.requestRedeem(shares);
        } else if (mode == Mode.HALF_HONEST_HALF_DEPOSIT) {
            CASH.safeTransfer(STRATEGY, amount / 2);
            CASH.forceApprove(address(VAULT), amount - amount / 2);
            VAULT.deposit(amount - amount / 2, ATTACKER);
        } else if (mode == Mode.DEPOSIT_OTHER_VAULT) {
            CASH.forceApprove(address(OTHER_VAULT), amount);
            OTHER_VAULT.deposit(amount, ATTACKER);
        } else if (mode == Mode.CONTEXT_BUMP_THEN_DEPOSIT) {
            HOOK.setExecutionContext(STRATEGY); // unpermissioned
            CASH.forceApprove(address(VAULT), amount);
            VAULT.deposit(amount, ATTACKER);
        } else if (mode == Mode.CONTEXT_BUMP_HONEST_FAKE_ZERO) {
            CASH.safeTransfer(STRATEGY, amount);
            HOOK.setExecutionContext(STRATEGY);
            IOutAmountSetter(address(HOOK)).setOutAmount(0, STRATEGY); // the fresh context has no mutex yet
        } else if (mode == Mode.CONTEXT_BUMP_HONEST_FAKE_MAX) {
            CASH.safeTransfer(STRATEGY, amount);
            HOOK.setExecutionContext(STRATEGY);
            IOutAmountSetter(address(HOOK)).setOutAmount(type(uint128).max, STRATEGY);
        } else if (mode == Mode.DEPOSIT_FOR_STRATEGY) {
            CASH.forceApprove(address(VAULT), amount);
            VAULT.deposit(amount, STRATEGY);
        } else if (mode == Mode.DEPOSIT_THEN_TRANSFER_TO_STRATEGY) {
            CASH.forceApprove(address(VAULT), amount);
            uint256 shares = VAULT.deposit(amount, address(this));
            VAULT.transfer(STRATEGY, shares);
        } else if (mode == Mode.HONEST_PLUS_SELF_DEPOSIT) {
            CASH.safeTransfer(STRATEGY, amount);
            CASH.forceApprove(address(VAULT), 1 ether);
            VAULT.deposit(1 ether, ATTACKER);
        } else if (mode == Mode.HONEST_TO_ROUTER) {
            CASH.safeTransfer(msg.sender, amount); // msg.sender is the router on this path
        } else if (mode == Mode.PAY_SELF) {
            WethTreasury(TREASURY).pay(address(this), amount);
        }
        // PAY_NOTHING: keep the input leg, pay nobody
    }
}

/// @title KyberSwapSupplyPinAttackTest
/// @notice SUP-21772 end to end on a mainnet fork against the REAL Kyber router: a SuperVault strategy swaps USDC for
///         WETH (the vault asset) through the pinned ApproveAndSwapKyberSwapHook while a poisoned route tries every way
///         it has to be paid in vault shares instead of paying. Every attempt fails the batch; honest fills pass.
contract KyberSwapSupplyPinAttackTest is Test, Constants {
    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public constant SCALE_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDC = CHAIN_1_USDC;
    address public constant WETH = CHAIN_1_WETH;

    uint256 internal constant LEG = 10_000e6; // USDC the strategy sells
    uint256 internal constant FLOOR = 2.5 ether; // the OMS fair floor for the WETH it expects back
    uint256 internal constant LP_SHARES = 1000 ether;
    uint256 internal constant FORK_BLOCK = 26_400_000; // pinned: router code and whitelist state must not drift
    uint256 internal constant FLAG_PARTIAL_FILL = 0x01; // MetaAggregationRouterV2._PARTIAL_FILL
    uint256 internal constant FLAG_FEE_ON_DST = 0x40; // MetaAggregationRouterV2._FEE_ON_DST: router receives, then
    // forwards
    /// @dev swapGeneric(SwapExecutionParams), not in our vendor interface: the whitelisted entrypoint of the real
    /// router
    bytes4 internal constant SWAP_GENERIC = bytes4(
        keccak256(
            "swapGeneric((address,address,bytes,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes))"
        )
    );

    ApproveAndSwapKyberSwapHook internal hook;
    MockSuperVaultStrategy internal strategy;
    SuperVaultLike internal vault;
    SuperVaultLike internal otherVault;
    AttackerExecutor internal route;
    address internal attacker = makeAddr("attacker");
    address internal lp = makeAddr("lp");

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ApproveAndSwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
        strategy = new MockSuperVaultStrategy(address(this));
        vault = new SuperVaultLike(IERC20(WETH), address(strategy));
        otherVault = new SuperVaultLike(IERC20(WETH), makeAddr("otherStrategy"));
        strategy.setVault(address(vault));
        // an LP position so the supply is non-trivial, and the strategy's cash to sell
        deal(WETH, lp, LP_SHARES);
        vm.startPrank(lp);
        IERC20(WETH).approve(address(vault), LP_SHARES);
        vault.deposit(LP_SHARES, lp);
        vm.stopPrank();
        deal(USDC, address(strategy), LEG);
        // the route: funded with the attacker's own WETH (temporarily at risk, meant to come back as shares)
        route = new AttackerExecutor(
            IERC20(WETH), vault, otherVault, address(strategy), attacker, ISuperHook(address(hook))
        );
        deal(WETH, address(route), 10 ether);
        WethTreasury treasury = new WethTreasury(IERC20(WETH));
        deal(WETH, address(treasury), 10 ether);
        route.setTreasury(address(treasury));
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _txData(bytes4 selector, address approveTarget_) internal view returns (bytes memory) {
        return _txDataFull(selector, approveTarget_, address(strategy), 0);
    }

    function _txDataFull(
        bytes4 selector,
        address approveTarget_,
        address dstReceiver_,
        uint256 flags_
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = address(route); // the real router pays the input leg straight to the route
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = LEG;
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: new address[](0),
            feeAmounts: new uint256[](0),
            dstReceiver: dstReceiver_,
            amount: LEG,
            minReturnAmount: FLOOR,
            flags: flags_,
            permit: ""
        });
        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: address(route),
            approveTarget: approveTarget_,
            // NOTE: the real router struct is (callTarget, approveTarget, targetData, desc, clientData); our vendor
            // interface names the two bytes fields the other way round (same ABI, so real payloads decode fine).
            // The executor data therefore goes in the field our interface calls clientData.
            clientData: hex"01", // = the router's targetData, which must be non-empty
            desc: desc,
            targetData: ""
        });
        return abi.encodePacked(selector, abi.encode(params));
    }

    function _args(bytes memory txData) internal view returns (MockSuperVaultStrategy.ExecuteArgs memory args) {
        bytes memory data = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: USDC,
                outputToken: WETH,
                inputAmount: LEG,
                outputQuote: FLOOR,
                outputMin: FLOOR,
                usePrevHookAmount: false
            }),
            abi.encode(txData)
        );
        args.hooks = new address[](1);
        args.hooks[0] = address(hook);
        args.hookCalldata = new bytes[](1);
        args.hookCalldata[0] = data;
        args.expectedAssetsOrSharesOut = new uint256[](1);
        args.expectedAssetsOrSharesOut[0] = FLOOR;
    }

    function _swapArgs() internal view returns (MockSuperVaultStrategy.ExecuteArgs memory) {
        return _args(_txData(IMetaAggregationRouterV2.swap.selector, address(0)));
    }

    function _assertNothingMoved() internal view {
        assertEq(IERC20(USDC).balanceOf(address(strategy)), LEG, "input leg still with the strategy");
        assertEq(IERC20(USDC).balanceOf(address(route)), 0, "route got nothing");
        assertEq(vault.balanceOf(attacker), 0, "no shares for the attacker");
        assertEq(vault.totalSupply(), LP_SHARES, "supply untouched");
        assertEq(IERC20(WETH).balanceOf(address(route)), 10 ether, "attacker capital untouched");
    }

    /*//////////////////////////////////////////////////////////////
                                 CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @notice The real router with an honest route: the strategy is paid, the floor passes, supply unchanged
    function test_Honest_RealRouter_Passes() public {
        route.set(AttackerExecutor.Mode.HONEST, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        strategy.executeHooks(args);
        // the strategy already held the LP's forwarded WETH; the swap adds exactly the floor
        assertEq(IERC20(WETH).balanceOf(address(strategy)), LP_SHARES + FLOOR);
        assertEq(IERC20(USDC).balanceOf(address(route)), LEG, "the route got the input leg");
        assertEq(hook.getOutAmount(address(strategy)), FLOOR);
        assertEq(vault.totalSupply(), LP_SHARES);
        assertEq(IERC20(USDC).allowance(address(strategy), KYBER_ROUTER), 0, "approval reset");
    }

    /// @notice A route that pays nothing is stopped by the router's own return check (pre-existing behaviour)
    function test_PayNothing_RouterRefuses() public {
        route.set(AttackerExecutor.Mode.PAY_NOTHING, 0);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /*//////////////////////////////////////////////////////////////
                              THE ATTEMPTS
    //////////////////////////////////////////////////////////////*/

    /// @notice THE FINDING: a deposit mid-swap satisfies the router and the floor; the pin fails the batch
    function test_Attack_DepositMidSwap_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice The exact hook error is the pin's, not something incidental
    function test_Attack_DepositMidSwap_RevertsWithThePinError() public {
        route.set(AttackerExecutor.Mode.DEPOSIT, FLOOR);
        // run the hook legs by hand, as the strategy does, to see the inner revert
        ISuperHook(address(hook)).setExecutionContext(address(strategy));
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.startPrank(address(strategy));
        bytes memory data = args.hookCalldata[0];
        hook.preExecute(address(0), address(strategy), data);
        IERC20(USDC).approve(KYBER_ROUTER, LEG);
        (bool ok,) = KYBER_ROUTER.call(_txData(IMetaAggregationRouterV2.swap.selector, address(0)));
        assertTrue(ok, "the real router accepted the poisoned route: receiver delta == floor");
        assertEq(vault.balanceOf(attacker), FLOOR, "shares minted mid-swap");
        vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
        hook.postExecute(address(0), address(strategy), data);
        vm.stopPrank();
    }

    /// @notice mint() instead of deposit(): same supply move, same outcome
    function test_Attack_MintMidSwap_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.MINT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice Parking the minted shares in the escrow (a redeem request) does not change totalSupply: still refused
    function test_Attack_DepositThenPark_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.DEPOSIT_THEN_PARK, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice The hooked-pool shape: a real partial payout topped up with a deposit. Any supply move is enough.
    function test_Attack_HalfHonestHalfDeposit_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.HALF_HONEST_HALF_DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice Depositing into ANOTHER vault leaves this vault's supply alone, but then nothing reaches this strategy
    ///         and the router's return check fails: the pin only has to cover the vault whose strategy is swapping
    function test_Attack_DepositIntoOtherVault_RouterRefuses() public {
        route.set(AttackerExecutor.Mode.DEPOSIT_OTHER_VAULT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
        assertEq(otherVault.totalSupply(), 0, "rolled back with the batch");
    }

    /// @notice setExecutionContext is unpermissioned: bumping it before the deposit does not blank the pin
    function test_Attack_ContextBumpThenDeposit_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.CONTEXT_BUMP_THEN_DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice Pay honestly, bump the context and write outAmount = 0 into the fresh context: the post delta would be
    ///         INFLATED (balance - 0) and the pin cannot see it. What kills the batch is the strategy's
    ///         resetExecutionState, which is onlyLastCaller and the route is now the last caller.
    function test_Attack_ContextBumpHonestFakeZero_KilledByLastCallerLock() public {
        route.set(AttackerExecutor.Mode.CONTEXT_BUMP_HONEST_FAKE_ZERO, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice Same with outAmount = max: the post delta underflows and the leg fails before the lock is even reached
    function test_Attack_ContextBumpHonestFakeMax_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.CONTEXT_BUMP_HONEST_FAKE_MAX, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice Depositing FOR the strategy, or handing it the minted shares, changes nothing: the tripwire is supply
    function test_Attack_DepositForStrategy_OrTransferSharesToIt_FailsTheBatch() public {
        route.set(AttackerExecutor.Mode.DEPOSIT_FOR_STRATEGY, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
        route.set(AttackerExecutor.Mode.DEPOSIT_THEN_TRANSFER_TO_STRATEGY, FLOOR);
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice The partial-fill flag changes the router's accounting, not the pin: a deposit still fails the batch
    function test_Attack_PartialFillFlag_DepositStillFailsTheBatch() public {
        route.set(AttackerExecutor.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _args(
            _txDataFull(IMetaAggregationRouterV2.swap.selector, address(0), address(strategy), FLAG_PARTIAL_FILL)
        );
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice dstReceiver pointed at the route itself, which pays itself: the ROUTER is satisfied (its receiver's
    /// delta met the minimum) but the hook measures the STRATEGY, whose delta is zero, so the strategy's own floor
    ///         is what refuses. The pin is not even reached: nothing credited the vault.
    function test_Attack_ReceiverIsTheRoute_StrategyFloorRefuses() public {
        route.set(AttackerExecutor.Mode.PAY_SELF, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args =
            _args(_txDataFull(IMetaAggregationRouterV2.swap.selector, address(0), address(route), 0));
        vm.expectRevert(MockSuperVaultStrategy.MINIMUM_OUTPUT_AMOUNT_NOT_MET.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice Fee-on-destination path: the router receives the output itself and forwards it to the receiver, but it
    ///         still measures the receiver's delta. A deposit mid-route satisfies it; the pin refuses. An honest
    ///         route paying the router passes.
    function test_Attack_FeeOnDstPath_DepositFails_HonestToRouterPasses() public {
        route.set(AttackerExecutor.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args =
            _args(_txDataFull(IMetaAggregationRouterV2.swap.selector, address(0), address(strategy), FLAG_FEE_ON_DST));
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
        route.set(AttackerExecutor.Mode.HONEST_TO_ROUTER, FLOOR);
        strategy.executeHooks(args);
        assertEq(IERC20(WETH).balanceOf(address(strategy)), LP_SHARES + FLOOR, "router forwarded the payout");
        assertEq(hook.getOutAmount(address(strategy)), FLOOR);
    }

    /// @notice Two-hook batches: a benign hook before or after the poisoned swap changes nothing, and a benign hook
    ///         next to an honest swap keeps working
    function test_Attack_TwoHookBatches_BenignNeighbourDoesNotHelp() public {
        MockHook benign = new MockHook(ISuperHook.HookType.NONACCOUNTING, WETH);
        route.set(AttackerExecutor.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory one = _swapArgs();
        // [benign, poisoned]
        MockSuperVaultStrategy.ExecuteArgs memory two;
        two.hooks = new address[](2);
        two.hookCalldata = new bytes[](2);
        two.expectedAssetsOrSharesOut = new uint256[](2);
        two.hooks[0] = address(benign);
        two.hooks[1] = one.hooks[0];
        two.hookCalldata[1] = one.hookCalldata[0];
        two.expectedAssetsOrSharesOut[1] = FLOOR;
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(two);
        _assertNothingMoved();
        // [poisoned, benign]
        two.hooks[0] = one.hooks[0];
        two.hooks[1] = address(benign);
        two.hookCalldata[0] = one.hookCalldata[0];
        two.hookCalldata[1] = "";
        two.expectedAssetsOrSharesOut[0] = FLOOR;
        two.expectedAssetsOrSharesOut[1] = 0;
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(two);
        _assertNothingMoved();
        // [honest, benign]
        route.set(AttackerExecutor.Mode.HONEST, FLOOR);
        strategy.executeHooks(two);
        assertEq(IERC20(WETH).balanceOf(address(strategy)), LP_SHARES + FLOOR);
    }

    /// @notice The documented false positive: an honest fill whose route ALSO makes an unrelated deposit into the
    ///         vault is refused. Routes must not touch the traded vault at all; that is the trade-off of the pin.
    function test_FalsePositive_HonestPlusSelfDeposit_IsRefused() public {
        route.set(AttackerExecutor.Mode.HONEST_PLUS_SELF_DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _swapArgs();
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }

    /// @notice approveTarget poisoning: the payload names the route as approve target; the hook ignores it and the
    ///         allowance goes to the router. The honest swap still works and the route never held an allowance.
    function test_Attack_ApproveTargetPoisoned_IgnoredAllowanceStaysWithRouter() public {
        route.set(AttackerExecutor.Mode.HONEST, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args =
            _args(_txData(IMetaAggregationRouterV2.swap.selector, address(route)));
        strategy.executeHooks(args);
        assertEq(IERC20(WETH).balanceOf(address(strategy)), LP_SHARES + FLOOR, "swap went through the router");
        assertEq(IERC20(USDC).allowance(address(strategy), address(route)), 0, "no allowance to the route");
        assertEq(IERC20(USDC).allowance(address(strategy), KYBER_ROUTER), 0, "router allowance reset");
    }

    /// @notice swapGeneric on the real router whitelists callTarget: a poisoned route cannot even start there
    function test_Attack_ViaSwapGeneric_RouterWhitelistRefuses() public {
        route.set(AttackerExecutor.Mode.DEPOSIT, FLOOR);
        MockSuperVaultStrategy.ExecuteArgs memory args = _args(_txData(SWAP_GENERIC, address(0)));
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        _assertNothingMoved();
    }
}
