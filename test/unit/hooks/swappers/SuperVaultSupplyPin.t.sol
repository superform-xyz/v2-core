// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { ISuperHook, Execution } from "../../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../../src/interfaces/ISuperHookSwap.sol";
import { SuperVaultSupplyPin } from "../../../../src/hooks/swappers/SuperVaultSupplyPin.sol";
import { ApproveAndSwapKyberSwapHook } from "../../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { SwapKyberSwapHook } from "../../../../src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol";
import { ApproveAndSwapOpenOceanHook } from "../../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol";
import { SwapOpenOceanHook } from "../../../../src/hooks/swappers/openocean/SwapOpenOceanHook.sol";
import { Swap1InchHook } from "../../../../src/hooks/swappers/1inch/Swap1InchHook.sol";
import { ApproveAndSwapOdosV2Hook } from "../../../../src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol";
import { SwapOdosV2Hook } from "../../../../src/hooks/swappers/odos/SwapOdosV2Hook.sol";
import { ApproveAndSwapOdosV3Hook } from "../../../../src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol";
import { SwapOdosV3Hook } from "../../../../src/hooks/swappers/odos/SwapOdosV3Hook.sol";
import { IMetaAggregationRouterV2 } from "../../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IOdosRouterV2 } from "../../../../src/vendor/odos/IOdosRouterV2.sol";
import { IOdosRouterV3 } from "../../../../src/vendor/odos/IOdosRouterV3.sol";
import { IOpenOceanExchange } from "../../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { IOpenOceanCaller } from "../../../../src/vendor/openocean/IOpenOceanCaller.sol";
import {
    I1InchAggregationRouterV6,
    IAggregationExecutor
} from "../../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { IERC20 as I1InchERC20 } from "../../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockSuperVaultStrategy } from "../../../mocks/MockSuperVaultStrategy.sol";
import { MockKyberSwapRouter } from "../../../mocks/MockKyberSwapRouter.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import {
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookInspector
} from "../../../../src/interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @dev A strategy whose getVaultInfo answers with no vault: must be treated like a plain account
contract StrategyWithNoVault {
    function getVaultInfo() external pure returns (address, address, uint8) {
        return (address(0), address(0), 18);
    }
}

/// @dev Shared "the route minted vault shares mid-swap" switch for the venue mocks below
abstract contract MidSwapMinter {
    address public mintVault;
    uint256 public mintAmount;

    function setMidSwapMint(address vault, uint256 amount) external {
        mintVault = vault;
        mintAmount = amount;
    }

    function _maybeMint() internal {
        if (mintVault != address(0)) MockERC20(mintVault).mint(address(this), mintAmount);
    }
}

contract PinTestOdosV2Router is MidSwapMinter {
    function swap(
        IOdosRouterV2.swapTokenInfo calldata t,
        bytes calldata,
        address,
        uint32
    )
        external
        payable
        returns (uint256)
    {
        MockERC20(t.inputToken).transferFrom(msg.sender, address(this), t.inputAmount);
        _maybeMint();
        MockERC20(t.outputToken).mint(t.outputReceiver, t.outputMin);
        return t.outputMin;
    }
}

contract PinTestOdosV3Router is MidSwapMinter {
    function swap(
        IOdosRouterV3.swapTokenInfo calldata t,
        bytes calldata,
        address,
        IOdosRouterV3.swapReferralInfo memory
    )
        external
        payable
        returns (uint256)
    {
        MockERC20(t.inputToken).transferFrom(msg.sender, address(this), t.inputAmount);
        _maybeMint();
        MockERC20(t.outputToken).mint(t.outputReceiver, t.outputMin);
        return t.outputMin;
    }
}

contract PinTestOpenOceanRouter is MidSwapMinter {
    function swap(
        IOpenOceanCaller,
        IOpenOceanExchange.SwapDescription calldata desc,
        IOpenOceanCaller.CallDescription[] calldata
    )
        external
        payable
        returns (uint256)
    {
        MockERC20(address(desc.srcToken)).transferFrom(msg.sender, address(this), desc.amount);
        _maybeMint();
        address receiver = desc.dstReceiver == address(0) ? msg.sender : desc.dstReceiver;
        MockERC20(address(desc.dstToken)).mint(receiver, desc.minReturnAmount);
        return desc.minReturnAmount;
    }
}

contract PinTest1InchRouter is MidSwapMinter {
    function swap(
        IAggregationExecutor,
        I1InchAggregationRouterV6.SwapDescription calldata desc,
        bytes calldata
    )
        external
        payable
        returns (uint256 returnAmount, uint256 spentAmount)
    {
        _maybeMint();
        address receiver = desc.dstReceiver == address(0) ? msg.sender : desc.dstReceiver;
        MockERC20(address(desc.dstToken)).mint(receiver, desc.minReturnAmount);
        return (desc.minReturnAmount, desc.amount);
    }
}

/// @dev A strategy that names a vault with no code: the pin must fail the leg, not silently skip it
contract StrategyWithCodelessVault {
    function getVaultInfo() external pure returns (address, address, uint8) {
        return (address(0xDEAD), address(0), 18);
    }
}

/// @dev An account whose fallback returns SHORT data for any selector: must read as "not a strategy", not brick
contract ShortReturnAccount {
    fallback() external payable {
        assembly {
            mstore(0, 1)
            return(0, 32)
        }
    }
}

/// @dev An input token whose transferFrom runs attacker code (a hooked / callback token): the only pre-router
///      re-entry surface, since build() is a view. When armed it bumps the hook's context and mints vault shares.
contract CallbackInputToken is MockERC20 {
    ISuperHook public hook;
    address public strategy;
    MockERC20 public vaultShares;
    bool public armed;

    constructor() MockERC20("Callback Token", "CBK", 18) { }

    function arm(ISuperHook hook_, address strategy_, MockERC20 vaultShares_) external {
        hook = hook_;
        strategy = strategy_;
        vaultShares = vaultShares_;
        armed = true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (armed) {
            hook.setExecutionContext(strategy); // unpermissioned
            vaultShares.mint(address(this), 1);
        }
        return super.transferFrom(from, to, value);
    }
}

/// @title SuperVaultSupplyPinTest
/// @notice SUP-21772: every aggregator swap hook pins the executing account's SuperVault share supply across the
///         leg. A route that mints or burns vault shares mid-swap (a nested SuperVault.deposit / mint) is refused in
///         _postExecute; plain accounts and strategies without a vault are untouched.
contract SuperVaultSupplyPinTest is Test {
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockERC20 internal inputToken;
    MockERC20 internal outputToken;
    MockERC20 internal vaultShares;
    MockSuperVaultStrategy internal strategy;
    MockKyberSwapRouter internal kyberRouter;

    BaseHook[] internal hooks;
    string[] internal names;

    function setUp() public {
        inputToken = new MockERC20("Input", "IN", 18);
        outputToken = new MockERC20("Output", "OUT", 6);
        vaultShares = new MockERC20("SuperVault Shares", "svOUT", 18);
        vaultShares.mint(address(0xBEEF), 1_000_000e18);
        strategy = new MockSuperVaultStrategy(address(this));
        strategy.setVault(address(vaultShares));
        kyberRouter = new MockKyberSwapRouter();

        address r = address(0xA11CE); // any non-zero router: pre/post never call it
        _add(new ApproveAndSwapKyberSwapHook(address(kyberRouter), address(0), NATIVE), "ApproveAndSwapKyberSwapHook");
        _add(new SwapKyberSwapHook(address(kyberRouter), address(0), NATIVE), "SwapKyberSwapHook");
        _add(new ApproveAndSwapOpenOceanHook(r, address(0xF0), NATIVE), "ApproveAndSwapOpenOceanHook");
        _add(new SwapOpenOceanHook(r, address(0xF0), NATIVE), "SwapOpenOceanHook");
        _add(new Swap1InchHook(r, NATIVE), "Swap1InchHook");
        _add(new ApproveAndSwapOdosV2Hook(r), "ApproveAndSwapOdosV2Hook");
        _add(new SwapOdosV2Hook(r), "SwapOdosV2Hook");
        _add(new ApproveAndSwapOdosV3Hook(r), "ApproveAndSwapOdosV3Hook");
        _add(new SwapOdosV3Hook(r), "SwapOdosV3Hook");
    }

    function _add(BaseHook h, string memory n) internal {
        hooks.push(h);
        names.push(n);
    }

    /// @dev Only the Layer-1 header matters to pre/post; 1inch decodes (dstReceiver, txData) from the payload
    function _data(uint256 i) internal view returns (bytes memory) {
        bytes memory payload = keccak256(bytes(names[i])) == keccak256("Swap1InchHook")
            ? abi.encode(address(0), bytes(""))
            : abi.encode(bytes(""));
        return ISuperHookSwap(address(hooks[i]))
            .encodeSwapData(
                ISuperHookSwap.SwapHeader({
                    inputToken: address(inputToken),
                    outputToken: address(outputToken),
                    inputAmount: 1e18,
                    outputQuote: 100e6,
                    outputMin: 99e6,
                    usePrevHookAmount: false
                }),
                payload
            );
    }

    /// @dev As the strategy does: open a fresh execution context for the account, then pre
    function _pre(uint256 i, address account, bytes memory data) internal {
        ISuperHook(address(hooks[i])).setExecutionContext(account);
        vm.prank(account);
        hooks[i].preExecute(address(0), account, data);
    }

    function _post(uint256 i, address account, bytes memory data) internal {
        vm.prank(account);
        hooks[i].postExecute(address(0), account, data);
    }

    /// @notice An unchanged supply passes on every hook and the measured delta is intact
    function test_AllHooks_UnchangedSupply_Passes() public {
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _data(i);
            _pre(i, address(strategy), data);
            outputToken.mint(address(strategy), 99e6);
            _post(i, address(strategy), data);
            assertEq(hooks[i].getOutAmount(address(strategy)), 99e6, names[i]);
        }
    }

    /// @notice THE FINDING, closed: shares minted mid-leg (a nested deposit) revert the leg on every hook
    function test_AllHooks_MintMidLeg_Reverts() public {
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _data(i);
            _pre(i, address(strategy), data);
            outputToken.mint(address(strategy), 99e6); // the "delivery" the deposit faked
            vaultShares.mint(address(0xA77), 1); // one wei of supply is enough
            vm.prank(address(strategy));
            vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
            hooks[i].postExecute(address(0), address(strategy), data);
            vaultShares.burn(address(0xA77), 1);
        }
    }

    /// @notice A burn mid-leg is refused too: the pin is on the exact supply, not a direction
    function test_AllHooks_BurnMidLeg_Reverts() public {
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _data(i);
            _pre(i, address(strategy), data);
            vaultShares.burn(address(0xBEEF), 1);
            vm.prank(address(strategy));
            vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
            hooks[i].postExecute(address(0), address(strategy), data);
            vaultShares.mint(address(0xBEEF), 1);
        }
    }

    /// @notice Plain accounts (this contract, an EOA) and strategies without a vault are no-ops: supply moves freely
    function test_AllHooks_NonStrategyAccounts_Unaffected() public {
        MockSuperVaultStrategy unset = new MockSuperVaultStrategy(address(this)); // getVaultInfo reverts
        StrategyWithNoVault noVault = new StrategyWithNoVault(); // getVaultInfo returns zero vault
        address eoa = makeAddr("eoa");
        address[4] memory accounts = [address(this), eoa, address(unset), address(noVault)];
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _data(i);
            for (uint256 a; a < accounts.length; ++a) {
                // each (hook, account) pair has its own context slots, so pre/post run once per pair
                _pre(i, accounts[a], data);
                vaultShares.mint(address(0xA77), 1e18);
                outputToken.mint(accounts[a], 5e6);
                _post(i, accounts[a], data);
                assertEq(hooks[i].getOutAmount(accounts[a]), 5e6, names[i]);
            }
        }
    }

    /// @notice setExecutionContext is unpermissioned: a route bumping the context mid-leg cannot blank the check
    function test_AllHooks_ContextBumpMidLeg_DoesNotDisableThePin() public {
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory data = _data(i);
            _pre(i, address(strategy), data);
            vm.prank(address(0xBAD));
            ISuperHook(address(hooks[i])).setExecutionContext(address(strategy));
            vaultShares.mint(address(0xA77), 1);
            vm.prank(address(strategy));
            vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
            hooks[i].postExecute(address(0), address(strategy), data);
            vaultShares.burn(address(0xA77), 1);
        }
    }

    /*//////////////////////////////////////////////////////////////
                END TO END THROUGH executeHooks (KYBER)
    //////////////////////////////////////////////////////////////*/

    function _kyberArgs(
        uint256 amountIn,
        uint256 minOut
    )
        internal
        view
        returns (MockSuperVaultStrategy.ExecuteArgs memory args)
    {
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc;
        desc.srcToken = IERC20(address(inputToken));
        desc.dstToken = IERC20(address(outputToken));
        desc.dstReceiver = address(strategy);
        desc.amount = amountIn;
        desc.minReturnAmount = minOut;
        bytes memory txData = abi.encodeCall(
            IMetaAggregationRouterV2.swap,
            (IMetaAggregationRouterV2.SwapExecutionParams({
                    callTarget: address(0xCA11),
                    approveTarget: address(kyberRouter),
                    clientData: "",
                    desc: desc,
                    targetData: ""
                }))
        );
        bytes memory data = ISuperHookSwap(address(hooks[0]))
            .encodeSwapData(
                ISuperHookSwap.SwapHeader({
                    inputToken: address(inputToken),
                    outputToken: address(outputToken),
                    inputAmount: amountIn,
                    outputQuote: minOut,
                    outputMin: minOut,
                    usePrevHookAmount: false
                }),
                abi.encode(txData)
            );
        args.hooks = new address[](1);
        args.hooks[0] = address(hooks[0]);
        args.hookCalldata = new bytes[](1);
        args.hookCalldata[0] = data;
        args.expectedAssetsOrSharesOut = new uint256[](1);
        args.expectedAssetsOrSharesOut[0] = minOut;
    }

    /// @notice Through the strategy's own executeHooks: an honest Kyber swap passes, the same swap with a vault
    ///         share minted mid-route fails the whole batch (OPERATION_FAILED wraps the hook's revert)
    function test_Kyber_ExecuteHooks_MidSwapMintFailsTheBatch() public {
        inputToken.mint(address(strategy), 10e18);
        outputToken.mint(address(kyberRouter), 1000e6);
        strategy.executeHooks(_kyberArgs(1e18, 99e6));
        assertEq(outputToken.balanceOf(address(strategy)), 99e6, "honest swap paid");
        assertEq(hooks[0].getOutAmount(address(strategy)), 99e6);

        kyberRouter.setMidSwapMint(address(vaultShares), 1);
        MockSuperVaultStrategy.ExecuteArgs memory poisoned = _kyberArgs(1e18, 99e6); // built first: expectRevert must
        // land on executeHooks
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(poisoned);
        assertEq(outputToken.balanceOf(address(strategy)), 99e6, "nothing moved on the refused batch");
        assertEq(inputToken.balanceOf(address(strategy)), 9e18);
    }

    /*//////////////////////////////////////////////////////////////
                      REVIEW ADDITIONS: EDGES OF THE PIN
    //////////////////////////////////////////////////////////////*/

    /// @notice Two swap legs of the same hook for the same account in one batch: the slot is per leg
    function test_Kyber_TwoLegsOneBatch_SecondLegMintFailsTheBatch() public {
        inputToken.mint(address(strategy), 10e18);
        outputToken.mint(address(kyberRouter), 1000e6);
        MockSuperVaultStrategy.ExecuteArgs memory one = _kyberArgs(1e18, 99e6);
        MockSuperVaultStrategy.ExecuteArgs memory two;
        two.hooks = new address[](2);
        two.hooks[0] = one.hooks[0];
        two.hooks[1] = one.hooks[0];
        two.hookCalldata = new bytes[](2);
        two.hookCalldata[0] = one.hookCalldata[0];
        two.hookCalldata[1] = one.hookCalldata[0];
        two.expectedAssetsOrSharesOut = new uint256[](2);
        two.expectedAssetsOrSharesOut[0] = 99e6;
        two.expectedAssetsOrSharesOut[1] = 99e6;
        strategy.executeHooks(two);
        assertEq(outputToken.balanceOf(address(strategy)), 198e6, "both legs paid");
        assertEq(hooks[0].getOutAmount(address(strategy)), 99e6, "second leg measured on its own");
        // the same batch with the mint on the second leg only: pin re-armed per leg
        kyberRouter.setMidSwapMint(address(vaultShares), 1);
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(two);
    }

    /// @notice post without pre on a strategy fails closed (pinned zero vs a real commitment); on a plain account the
    ///         same sequence is a no-op, as before
    function test_PostWithoutPre_FailsClosedForStrategies_NoopForAccounts() public {
        bytes memory data = _data(0);
        ISuperHook(address(hooks[0])).setExecutionContext(address(strategy));
        vm.prank(address(strategy));
        vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
        hooks[0].postExecute(address(0), address(strategy), data);
        ISuperHook(address(hooks[0])).setExecutionContext(address(this));
        hooks[0].postExecute(address(0), address(this), data); // plain account: passes
    }

    /// @notice A strategy whose vault has no code cannot be pinned: the leg fails rather than skipping the check
    function test_StrategyWithCodelessVault_FailsTheLeg() public {
        StrategyWithCodelessVault bad = new StrategyWithCodelessVault();
        bytes memory data = _data(0);
        ISuperHook(address(hooks[0])).setExecutionContext(address(bad));
        vm.prank(address(bad));
        vm.expectRevert(bytes("")); // totalSupply() on a codeless address: the extcodesize check reverts with no data
        hooks[0].preExecute(address(0), address(bad), data);
    }

    /// @notice An account with a permissive fallback that returns short data reads as "not a strategy": the leg runs
    function test_ShortReturnAccount_IsTreatedAsPlainAccount() public {
        ShortReturnAccount acct = new ShortReturnAccount();
        bytes memory data = _data(0);
        _pre(0, address(acct), data);
        vaultShares.mint(address(0xA77), 1e18);
        outputToken.mint(address(acct), 7e6);
        _post(0, address(acct), data);
        assertEq(hooks[0].getOutAmount(address(acct)), 7e6);
    }

    /// @notice Native output leg: the pin reads only the vault, the delta is the account's ETH balance
    function test_Kyber_NativeOutput_PinStillApplies() public {
        inputToken.mint(address(strategy), 10e18);
        vm.deal(address(kyberRouter), 10 ether);
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc;
        desc.srcToken = IERC20(address(inputToken));
        desc.dstToken = IERC20(NATIVE);
        desc.dstReceiver = address(strategy);
        desc.amount = 1e18;
        desc.minReturnAmount = 1 ether;
        bytes memory txData = abi.encodeCall(
            IMetaAggregationRouterV2.swap,
            (IMetaAggregationRouterV2.SwapExecutionParams({
                    callTarget: address(0xCA11),
                    approveTarget: address(kyberRouter),
                    clientData: "",
                    desc: desc,
                    targetData: ""
                }))
        );
        MockSuperVaultStrategy.ExecuteArgs memory args;
        args.hooks = new address[](1);
        args.hooks[0] = address(hooks[0]);
        args.hookCalldata = new bytes[](1);
        args.hookCalldata[0] = ISuperHookSwap(address(hooks[0]))
            .encodeSwapData(
                ISuperHookSwap.SwapHeader({
                    inputToken: address(inputToken),
                    outputToken: NATIVE,
                    inputAmount: 1e18,
                    outputQuote: 1 ether,
                    outputMin: 1 ether,
                    usePrevHookAmount: false
                }),
                abi.encode(txData)
            );
        args.expectedAssetsOrSharesOut = new uint256[](1);
        args.expectedAssetsOrSharesOut[0] = 1 ether;
        strategy.executeHooks(args);
        assertEq(address(strategy).balance, 1 ether);
        assertEq(hooks[0].getOutAmount(address(strategy)), 1 ether);
        kyberRouter.setMidSwapMint(address(vaultShares), 1);
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
    }

    /*//////////////////////////////////////////////////////////////
            END TO END THROUGH executeHooks: THE OTHER VENUES
    //////////////////////////////////////////////////////////////*/

    function _oneHook(
        address hook,
        bytes memory data,
        uint256 floor
    )
        internal
        pure
        returns (MockSuperVaultStrategy.ExecuteArgs memory args)
    {
        args.hooks = new address[](1);
        args.hooks[0] = hook;
        args.hookCalldata = new bytes[](1);
        args.hookCalldata[0] = data;
        args.expectedAssetsOrSharesOut = new uint256[](1);
        args.expectedAssetsOrSharesOut[0] = floor;
    }

    function _header(uint256 amountIn, uint256 floor) internal view returns (ISuperHookSwap.SwapHeader memory) {
        return ISuperHookSwap.SwapHeader({
            inputToken: address(inputToken),
            outputToken: address(outputToken),
            inputAmount: amountIn,
            outputQuote: floor,
            outputMin: floor,
            usePrevHookAmount: false
        });
    }

    /// @dev honest passes with outAmount == floor; the same batch with a mid-swap mint fails
    function _runVenue(BaseHook hook, MidSwapMinter router, MockSuperVaultStrategy.ExecuteArgs memory args) internal {
        inputToken.mint(address(strategy), 1e18);
        uint256 before = outputToken.balanceOf(address(strategy));
        strategy.executeHooks(args);
        assertEq(outputToken.balanceOf(address(strategy)) - before, 99e6, "honest: paid the floor");
        assertEq(hook.getOutAmount(address(strategy)), 99e6);
        inputToken.mint(address(strategy), 1e18);
        router.setMidSwapMint(address(vaultShares), 1);
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
        router.setMidSwapMint(address(0), 0);
    }

    function test_OdosV2_ExecuteHooks_MidSwapMintFailsTheBatch() public {
        PinTestOdosV2Router router = new PinTestOdosV2Router();
        ApproveAndSwapOdosV2Hook hook = new ApproveAndSwapOdosV2Hook(address(router));
        bytes memory payload = abi.encode(address(router), hex"01", address(0xE), uint32(0));
        bytes memory data = hook.encodeSwapData(_header(1e18, 99e6), payload);
        _runVenue(hook, router, _oneHook(address(hook), data, 99e6));
    }

    function test_OdosV3_ExecuteHooks_MidSwapMintFailsTheBatch() public {
        PinTestOdosV3Router router = new PinTestOdosV3Router();
        ApproveAndSwapOdosV3Hook hook = new ApproveAndSwapOdosV3Hook(address(router));
        bytes memory payload = abi.encode(address(router), hex"01", address(0xE), uint64(0), uint64(0), address(0));
        bytes memory data = hook.encodeSwapData(_header(1e18, 99e6), payload);
        _runVenue(hook, router, _oneHook(address(hook), data, 99e6));
    }

    function test_OpenOcean_ExecuteHooks_MidSwapMintFailsTheBatch() public {
        PinTestOpenOceanRouter router = new PinTestOpenOceanRouter();
        address referrer = address(0xF0);
        ApproveAndSwapOpenOceanHook hook = new ApproveAndSwapOpenOceanHook(address(router), referrer, NATIVE);
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](1);
        calls[0] = IOpenOceanCaller.CallDescription({ target: 0, gasLimit: 0, value: 0, data: hex"01" });
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(address(inputToken)),
            dstToken: IERC20(address(outputToken)),
            srcReceiver: address(0xCA11),
            dstReceiver: address(strategy),
            amount: 1e18,
            minReturnAmount: 99e6,
            guaranteedAmount: 99e6,
            flags: 0,
            referrer: referrer,
            permit: ""
        });
        bytes memory txData = abi.encodeCall(IOpenOceanExchange.swap, (IOpenOceanCaller(address(0xCA11)), desc, calls));
        bytes memory data = hook.encodeSwapData(_header(1e18, 99e6), abi.encode(txData));
        _runVenue(hook, router, _oneHook(address(hook), data, 99e6));
    }

    function test_1Inch_ExecuteHooks_MidSwapMintFailsTheBatch() public {
        PinTest1InchRouter router = new PinTest1InchRouter();
        Swap1InchHook hook = new Swap1InchHook(address(router), NATIVE);
        I1InchAggregationRouterV6.SwapDescription memory desc = I1InchAggregationRouterV6.SwapDescription({
            srcToken: I1InchERC20(address(inputToken)),
            dstToken: I1InchERC20(address(outputToken)),
            srcReceiver: payable(address(0xCA11)),
            dstReceiver: payable(address(0)), // 0 = msg.sender, the strategy
            amount: 1e18,
            minReturnAmount: 99e6,
            flags: 0
        });
        bytes memory callData = abi.encodePacked(
            I1InchAggregationRouterV6.swap.selector, abi.encode(address(0xE), desc, bytes(""), bytes(""))
        );
        bytes memory data = hook.encodeSwapData(_header(1e18, 99e6), abi.encode(address(0), callData));
        _runVenue(hook, router, _oneHook(address(hook), data, 99e6));
    }

    /*//////////////////////////////////////////////////////////////
                    FUZZ, LEAF AND CHAIN REGRESSION GUARDS
    //////////////////////////////////////////////////////////////*/

    /// @notice Any non-zero supply move between pre and post reverts on every hook; zero never does
    function testFuzz_AnySupplyDeltaReverts(uint8 hookSeed, uint96 delta, bool burn) public {
        uint256 i = uint256(hookSeed) % hooks.length;
        bytes memory data = _data(i);
        _pre(i, address(strategy), data);
        outputToken.mint(address(strategy), 99e6);
        if (burn) {
            delta = uint96(bound(uint256(delta), 0, 1_000_000e18));
            if (delta != 0) vaultShares.burn(address(0xBEEF), delta);
        } else if (delta != 0) {
            vaultShares.mint(address(0xA77), delta);
        }
        vm.prank(address(strategy));
        if (delta != 0) vm.expectRevert(SuperVaultSupplyPin.SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP.selector);
        hooks[i].postExecute(address(0), address(strategy), data);
        if (delta == 0) assertEq(hooks[i].getOutAmount(address(strategy)), 99e6, names[i]);
    }

    /// @notice The fix must not touch what the Merkle leaves commit to: inspect() is unchanged on every hook
    function test_AllHooks_InspectUnchanged() public view {
        for (uint256 i; i < hooks.length; ++i) {
            bytes memory got = ISuperHookInspector(address(hooks[i])).inspect(_data(i));
            if (keccak256(bytes(names[i])) == keccak256("Swap1InchHook")) {
                assertEq(got, abi.encodePacked(address(outputToken), address(0)), names[i]); // outputToken ||
                // dstReceiver
            } else {
                assertEq(got, abi.encodePacked(address(outputToken)), names[i]);
            }
        }
    }

    /// @notice ERC165 surface unchanged: swap hooks still advertise both sizing interfaces
    function test_AllHooks_Erc165Unchanged() public view {
        for (uint256 i; i < hooks.length; ++i) {
            IERC165 h = IERC165(address(hooks[i]));
            assertTrue(h.supportsInterface(type(ISuperHookInflowOutflow).interfaceId), names[i]);
            assertTrue(h.supportsInterface(type(ISuperHookOutflow).interfaceId), names[i]);
        }
    }

    /// @notice A usePrevHookAmount chain: the Odos V2 leg sizes itself from the previous hook and is still pinned
    function test_OdosV2_UsePrevHookAmount_ChainIsPinned() public {
        PinTestOdosV2Router router = new PinTestOdosV2Router();
        ApproveAndSwapOdosV2Hook odos = new ApproveAndSwapOdosV2Hook(address(router));
        MockHook prev = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));
        prev.setOutAmount(1e18, address(strategy)); // "the previous leg produced 1e18 input token"
        inputToken.mint(address(strategy), 2e18);
        bytes memory payload = abi.encode(address(router), hex"01", address(0xE), uint32(0));
        bytes memory data = odos.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(inputToken),
                outputToken: address(outputToken),
                inputAmount: 1e18, // the quote's size; usePrev replaces it with the prev outAmount
                outputQuote: 99e6,
                outputMin: 99e6,
                usePrevHookAmount: true
            }),
            payload
        );
        MockSuperVaultStrategy.ExecuteArgs memory args;
        args.hooks = new address[](2);
        args.hooks[0] = address(prev);
        args.hooks[1] = address(odos);
        args.hookCalldata = new bytes[](2);
        args.hookCalldata[0] = "";
        args.hookCalldata[1] = data;
        args.expectedAssetsOrSharesOut = new uint256[](2);
        args.expectedAssetsOrSharesOut[1] = 99e6;
        strategy.executeHooks(args);
        assertEq(odos.getOutAmount(address(strategy)), 99e6);
        assertEq(inputToken.balanceOf(address(strategy)), 1e18, "sized from the previous leg");
        router.setMidSwapMint(address(vaultShares), 1);
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
    }

    /*//////////////////////////////////////////////////////////////
                        ROUND 3: MORE WAYS IN
    //////////////////////////////////////////////////////////////*/

    /// @notice A callback input token that bumps the context and mints during the router's transferFrom: refused
    function test_Kyber_CallbackInputToken_MintsDuringTransferFrom_FailsTheBatch() public {
        CallbackInputToken cbk = new CallbackInputToken();
        cbk.mint(address(strategy), 10e18);
        outputToken.mint(address(kyberRouter), 1000e6);
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc;
        desc.srcToken = IERC20(address(cbk));
        desc.dstToken = IERC20(address(outputToken));
        desc.dstReceiver = address(strategy);
        desc.amount = 1e18;
        desc.minReturnAmount = 99e6;
        bytes memory txData = abi.encodeCall(
            IMetaAggregationRouterV2.swap,
            (IMetaAggregationRouterV2.SwapExecutionParams({
                    callTarget: address(0xCA11),
                    approveTarget: address(kyberRouter),
                    clientData: "",
                    desc: desc,
                    targetData: ""
                }))
        );
        bytes memory data = ISuperHookSwap(address(hooks[0]))
            .encodeSwapData(
                ISuperHookSwap.SwapHeader({
                    inputToken: address(cbk),
                    outputToken: address(outputToken),
                    inputAmount: 1e18,
                    outputQuote: 99e6,
                    outputMin: 99e6,
                    usePrevHookAmount: false
                }),
                abi.encode(txData)
            );
        MockSuperVaultStrategy.ExecuteArgs memory args = _oneHook(address(hooks[0]), data, 99e6);
        strategy.executeHooks(args); // unarmed: an ordinary token
        assertEq(hooks[0].getOutAmount(address(strategy)), 99e6);
        cbk.arm(ISuperHook(address(hooks[0])), address(strategy), vaultShares);
        vm.expectRevert(MockSuperVaultStrategy.OPERATION_FAILED.selector);
        strategy.executeHooks(args);
    }

    /// @notice The hook does not pin the router selector: a swapGeneric-shaped payload builds, and its approveTarget
    ///         is ignored like any other. Pinned here so a future selector rule is a deliberate change.
    function test_Kyber_SwapGenericSelector_BuildsAndApprovesTheRouterOnly() public view {
        bytes4 swapGeneric = bytes4(
            keccak256(
                "swapGeneric((address,address,bytes,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes))"
            )
        );
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc;
        desc.srcToken = IERC20(address(inputToken));
        desc.dstToken = IERC20(address(outputToken));
        desc.dstReceiver = address(strategy);
        desc.amount = 1e18;
        desc.minReturnAmount = 99e6;
        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: address(0xCA11), approveTarget: address(0xBAD), clientData: "", desc: desc, targetData: ""
        });
        bytes memory data = ISuperHookSwap(address(hooks[0]))
            .encodeSwapData(_header(1e18, 99e6), abi.encode(abi.encodePacked(swapGeneric, abi.encode(params))));
        Execution[] memory ex = hooks[0].build(address(0), address(strategy), data);
        (address spender,) = abi.decode(_slice(ex[2].callData, 4), (address, uint256));
        assertEq(spender, address(kyberRouter));
        assertEq(bytes4(ex[3].callData), swapGeneric, "the selector is forwarded as is");
    }

    /// @notice Whatever approveTarget the payload names, the account approves only the router
    function testFuzz_Kyber_ApproveTargetIsAlwaysTheRouter(address foreign) public view {
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc;
        desc.srcToken = IERC20(address(inputToken));
        desc.dstToken = IERC20(address(outputToken));
        desc.dstReceiver = address(strategy);
        desc.amount = 1e18;
        desc.minReturnAmount = 99e6;
        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: address(0xCA11), approveTarget: foreign, clientData: "", desc: desc, targetData: ""
        });
        bytes memory data = ISuperHookSwap(address(hooks[0]))
            .encodeSwapData(_header(1e18, 99e6), abi.encode(abi.encodeCall(IMetaAggregationRouterV2.swap, (params))));
        Execution[] memory ex = hooks[0].build(address(0), address(strategy), data);
        for (uint256 k = 1; k <= 4; k += 1) {
            if (k == 3) continue; // ex[3] is the router call
            (address spender,) = abi.decode(_slice(ex[k].callData, 4), (address, uint256));
            assertEq(spender, address(kyberRouter));
        }
    }

    function _slice(bytes memory d, uint256 start) internal pure returns (bytes memory out) {
        out = new bytes(d.length - start);
        for (uint256 k; k < out.length; ++k) {
            out[k] = d[k + start];
        }
    }
}
