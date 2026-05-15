// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ClaimRFLRHook } from "../../../src/hooks/claim/flare/ClaimRFLRHook.sol";
import { WithdrawRFLRHook } from "../../../src/hooks/claim/flare/WithdrawRFLRHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/*//////////////////////////////////////////////////////////////
                    MOCK RNAT CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title MockRNat
/// @notice Simulates the RNat contract for SuperVault strategy testing
contract MockRNat is MockERC20 {
    address public wflr;
    uint256 public claimAmount;

    constructor(address wflr_) MockERC20("rFLR", "rFLR", 18) {
        wflr = wflr_;
    }

    function setClaimAmount(uint256 amount) external {
        claimAmount = amount;
    }

    /// @dev Simulates claimRewards: mints rFLR to caller
    function claimRewards(uint256[] calldata, uint256) external returns (uint128) {
        if (claimAmount > 0) {
            _mint(msg.sender, claimAmount);
        }
        return uint128(claimAmount);
    }

    /// @dev Simulates withdrawAll: burns all rFLR from caller, mints WFLR
    function withdrawAll(bool) external returns (uint128) {
        uint256 bal = balanceOf(msg.sender);
        _burn(msg.sender, bal);
        MockERC20(wflr).mint(msg.sender, bal);
        return uint128(bal);
    }
}

/*//////////////////////////////////////////////////////////////
                MOCK SUPERVAULT STRATEGY
//////////////////////////////////////////////////////////////*/

/// @title MockSuperVaultStrategy
/// @notice Replicates the core hook execution flow from SuperVaultStrategy._processSingleHookExecution()
/// @dev The strategy IS the account — it holds tokens and is msg.sender for all hook calls.
///      Flow: setExecutionContext → build → execute each Execution via .call() → resetExecutionState → getOutAmount
contract MockSuperVaultStrategy {
    error SLIPPAGE_CHECK_FAILED(uint256 outAmount, uint256 minExpected);
    error EXECUTION_FAILED(uint256 index);

    event HookExecuted(address indexed hook, uint256 outAmount);

    /// @notice Execute a single hook through the full strategy flow
    function executeHook(
        address hook,
        address prevHook,
        bytes calldata data,
        uint256 minExpected
    )
        external
        returns (uint256 outAmount)
    {
        outAmount = _processHook(hook, prevHook, data);

        if (minExpected > 0 && outAmount < minExpected) {
            revert SLIPPAGE_CHECK_FAILED(outAmount, minExpected);
        }
    }

    /// @notice Execute multiple hooks in sequence (chained)
    function executeHooks(
        address[] calldata hooks,
        bytes[] calldata datas,
        uint256 minExpected
    )
        external
        returns (uint256 outAmount)
    {
        address prevHook = address(0);

        for (uint256 i; i < hooks.length; ++i) {
            outAmount = _processHook(hooks[i], prevHook, datas[i]);
            prevHook = hooks[i];
        }

        if (minExpected > 0 && outAmount < minExpected) {
            revert SLIPPAGE_CHECK_FAILED(outAmount, minExpected);
        }
    }

    /// @dev Replicates SuperVaultStrategy._processSingleHookExecution()
    function _processHook(address hook, address prevHook, bytes calldata data) internal returns (uint256) {
        // 1. Set execution context — sets lastCaller = address(this)
        ISuperHook(hook).setExecutionContext(address(this));

        // 2. Build execution array
        Execution[] memory execs = ISuperHook(hook).build(prevHook, address(this), data);

        // 3. Execute each via .call() (strategy is msg.sender = account)
        for (uint256 i; i < execs.length; ++i) {
            (bool ok,) = execs[i].target.call{ value: execs[i].value }(execs[i].callData);
            if (!ok) revert EXECUTION_FAILED(i);
        }

        // 4. Reset execution state — requires msg.sender == lastCaller
        ISuperHook(hook).resetExecutionState(address(this));

        // 5. Read outAmount
        uint256 out = ISuperHookResult(hook).getOutAmount(address(this));
        emit HookExecuted(hook, out);
        return out;
    }
}

/*//////////////////////////////////////////////////////////////
                    TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title FlareRFLRSuperVaultE2ETest
/// @notice Tests RFLR hooks executed through a mock SuperVault strategy flow
contract FlareRFLRSuperVaultE2ETest is Test {
    MockERC20 public wflr;
    MockRNat public rNat;
    ClaimRFLRHook public claimHook;
    WithdrawRFLRHook public withdrawHook;
    MockSuperVaultStrategy public strategy;

    uint256 constant CLAIM_AMOUNT = 100e18;

    function setUp() public {
        // Deploy mock tokens
        wflr = new MockERC20("WFLR", "WFLR", 18);
        rNat = new MockRNat(address(wflr));

        // Deploy hooks
        claimHook = new ClaimRFLRHook(address(rNat));
        withdrawHook = new WithdrawRFLRHook(address(rNat), address(wflr));

        // Deploy mock strategy
        strategy = new MockSuperVaultStrategy();

        // Set default claim amount
        rNat.setClaimAmount(CLAIM_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                    HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes claim data: month=1, 1 project with id=0
    function _claimData() internal pure returns (bytes memory) {
        return abi.encodePacked(uint256(1), uint256(1), uint256(0));
    }

    /*//////////////////////////////////////////////////////////////
                    TEST: CLAIM THROUGH STRATEGY
    //////////////////////////////////////////////////////////////*/

    function test_claimRFLR_throughStrategy() public {
        // Pre-conditions
        assertEq(rNat.balanceOf(address(strategy)), 0, "strategy should start with 0 rFLR");

        // Execute claim hook through strategy
        uint256 outAmount = strategy.executeHook(address(claimHook), address(0), _claimData(), 0);

        // Verify rFLR minted to strategy
        assertEq(rNat.balanceOf(address(strategy)), CLAIM_AMOUNT, "strategy should have claimed rFLR");

        // Verify outAmount tracked correctly
        assertEq(outAmount, CLAIM_AMOUNT, "outAmount should match claim amount");
    }

    /*//////////////////////////////////////////////////////////////
                    TEST: WITHDRAW THROUGH STRATEGY
    //////////////////////////////////////////////////////////////*/

    function test_withdrawRFLR_throughStrategy() public {
        // Give strategy some rFLR
        rNat.mint(address(strategy), 50e18);
        assertEq(rNat.balanceOf(address(strategy)), 50e18);
        assertEq(wflr.balanceOf(address(strategy)), 0);

        // Execute withdraw hook through strategy
        uint256 outAmount = strategy.executeHook(address(withdrawHook), address(0), "", 0);

        // Verify rFLR burned, WFLR received
        assertEq(rNat.balanceOf(address(strategy)), 0, "strategy rFLR should be 0 after withdraw");
        assertEq(wflr.balanceOf(address(strategy)), 50e18, "strategy should have received WFLR");
        assertEq(outAmount, 50e18, "outAmount should match withdrawn amount");
    }

    /*//////////////////////////////////////////////////////////////
                    TEST: CLAIM THEN WITHDRAW (CHAINED)
    //////////////////////////////////////////////////////////////*/

    function test_claimThenWithdraw_throughStrategy() public {
        // Pre-conditions: strategy has nothing
        assertEq(rNat.balanceOf(address(strategy)), 0);
        assertEq(wflr.balanceOf(address(strategy)), 0);

        // Build chained execution: claim rFLR → withdraw to WFLR
        address[] memory hooks = new address[](2);
        hooks[0] = address(claimHook);
        hooks[1] = address(withdrawHook);

        bytes[] memory datas = new bytes[](2);
        datas[0] = _claimData();
        datas[1] = "";

        // Execute both hooks in sequence through strategy
        uint256 outAmount = strategy.executeHooks(hooks, datas, 0);

        // rFLR should be 0 (claimed then withdrawn)
        assertEq(rNat.balanceOf(address(strategy)), 0, "rFLR should be 0 after full lifecycle");

        // WFLR should equal claim amount
        assertEq(wflr.balanceOf(address(strategy)), CLAIM_AMOUNT, "WFLR should equal claimed amount");

        // outAmount is from the LAST hook (withdraw)
        assertEq(outAmount, CLAIM_AMOUNT, "final outAmount should be the WFLR received");
    }

    /*//////////////////////////////////////////////////////////////
                    TEST: SLIPPAGE CHECK REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_slippageCheck_reverts() public {
        // Set a small claim amount
        rNat.setClaimAmount(10e18);

        // Should revert when minExpected > actual outAmount
        vm.expectRevert(
            abi.encodeWithSelector(MockSuperVaultStrategy.SLIPPAGE_CHECK_FAILED.selector, 10e18, 50e18)
        );
        strategy.executeHook(address(claimHook), address(0), _claimData(), 50e18);
    }
}
