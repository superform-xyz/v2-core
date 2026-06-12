// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { ClaimRFLRHook } from "../../src/hooks/claim/flare/ClaimRFLRHook.sol";
import { WithdrawRFLRHook } from "../../src/hooks/claim/flare/WithdrawRFLRHook.sol";
import { ISuperHook } from "../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

/*//////////////////////////////////////////////////////////////
                    MOCK RNAT CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title MockRNat
/// @notice Simulates the RNat contract for invariant testing
/// @dev Extends MockERC20 with claimRewards and withdrawAll functions
contract MockRNat is MockERC20 {
    address public wflr;
    uint256 public claimAmount;

    constructor(address wflr_) MockERC20("rFLR", "rFLR", 18) {
        wflr = wflr_;
    }

    function setClaimAmount(uint256 amount) external {
        claimAmount = amount;
    }

    /// @dev Returns a dummy current month for on-chain lookup
    function getCurrentMonth() external pure returns (uint256) {
        return 1;
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
                    HANDLER
//////////////////////////////////////////////////////////////*/

/// @title RFLRHooksHandler
/// @notice Exercises ClaimRFLRHook and WithdrawRFLRHook with varying parameters
/// @dev Executes full hook flows (setContext + pre + action + post) in single calls,
///      records results in regular storage for invariant assertions.
///      Uses mint/burn instead of deal() to keep totalSupply in sync.
contract RFLRHooksHandler is Test {
    ClaimRFLRHook public claimHook;
    WithdrawRFLRHook public withdrawHook;
    MockRNat public rNat;
    MockERC20 public wflr;
    address[] public actors;

    // Ghost state: tracks results of the last execution per actor
    mapping(address => uint256) public ghost_lastClaimOutAmount;
    mapping(address => uint256) public ghost_lastClaimActualDelta;
    mapping(address => uint256) public ghost_lastWithdrawOutAmount;
    mapping(address => uint256) public ghost_lastWithdrawActualDelta;
    mapping(address => address) public ghost_lastClaimAsset;
    mapping(address => address) public ghost_lastWithdrawAsset;

    // Ghost state: aggregate counters
    uint256 public ghost_totalClaims;
    uint256 public ghost_totalWithdrawals;
    uint256 public ghost_totalClaimReverts;
    uint256 public ghost_totalWithdrawReverts;

    // Ghost state: build validation
    uint256 public ghost_lastClaimBuildLength;
    uint256 public ghost_lastWithdrawBuildLength;

    constructor(
        ClaimRFLRHook claimHook_,
        WithdrawRFLRHook withdrawHook_,
        MockRNat rNat_,
        MockERC20 wflr_,
        address[] memory actors_
    ) {
        claimHook = claimHook_;
        withdrawHook = withdrawHook_;
        rNat = rNat_;
        wflr = wflr_;
        actors = actors_;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    /// @dev Resets an actor's token balance to a target using mint/burn (keeps totalSupply in sync)
    function _setBalance(MockERC20 token, address account, uint256 target) internal {
        uint256 current = token.balanceOf(account);
        if (current < target) {
            token.mint(account, target - current);
        } else if (current > target) {
            token.burn(account, current - target);
        }
    }

    /// @notice Execute a full claim flow: setContext -> pre -> claim -> post
    function executeClaim(
        uint256 actorSeed,
        uint256 existingBalance,
        uint256 claimAmount_,
        uint256 month,
        uint256 numProjects
    )
        external
    {
        address actor = _actor(actorSeed);
        existingBalance = bound(existingBalance, 0, 1e30);
        claimAmount_ = bound(claimAmount_, 0, 1e30);
        month = bound(month, 0, 100);
        numProjects = bound(numProjects, 1, 10);

        // Set up mock state (mint/burn to keep totalSupply in sync)
        _setBalance(rNat, actor, existingBalance);
        rNat.setClaimAmount(claimAmount_);

        // Encode claim data (month is now fetched on-chain via IRNat.getCurrentMonth())
        bytes memory data = abi.encodePacked(numProjects);
        for (uint256 i; i < numProjects; ++i) {
            data = abi.encodePacked(data, i);
        }

        // Build and verify execution count
        Execution[] memory executions = claimHook.build(address(0), actor, data);
        ghost_lastClaimBuildLength = executions.length;

        // Record pre-balance
        uint256 balBefore = rNat.balanceOf(actor);

        // Execute the full flow as the actor
        claimHook.setExecutionContext(actor);
        vm.startPrank(actor);
        for (uint256 i; i < executions.length; ++i) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                vm.stopPrank();
                ghost_totalClaimReverts++;
                return;
            }
        }
        vm.stopPrank();

        // Record ghost state
        uint256 balAfter = rNat.balanceOf(actor);
        ghost_lastClaimOutAmount[actor] = claimHook.getOutAmount(actor);
        ghost_lastClaimActualDelta[actor] = balAfter > balBefore ? balAfter - balBefore : 0;
        ghost_lastClaimAsset[actor] = claimHook.asset();
        ghost_totalClaims++;
    }

    /// @notice Execute a full withdraw flow: setContext -> pre -> withdrawAll -> post
    function executeWithdraw(uint256 actorSeed, uint256 rflrBalance, uint256 existingWflr) external {
        address actor = _actor(actorSeed);
        rflrBalance = bound(rflrBalance, 0, 1e30);
        existingWflr = bound(existingWflr, 0, 1e30);

        // Set up mock state (mint/burn to keep totalSupply in sync)
        _setBalance(rNat, actor, rflrBalance);
        _setBalance(wflr, actor, existingWflr);

        // Build and verify execution count
        Execution[] memory executions = withdrawHook.build(address(0), actor, "");
        ghost_lastWithdrawBuildLength = executions.length;

        // Record pre-balance
        uint256 wflrBefore = wflr.balanceOf(actor);

        // Execute the full flow as the actor
        withdrawHook.setExecutionContext(actor);
        vm.startPrank(actor);
        for (uint256 i; i < executions.length; ++i) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                vm.stopPrank();
                ghost_totalWithdrawReverts++;
                return;
            }
        }
        vm.stopPrank();

        // Record ghost state
        uint256 wflrAfter = wflr.balanceOf(actor);
        ghost_lastWithdrawOutAmount[actor] = withdrawHook.getOutAmount(actor);
        ghost_lastWithdrawActualDelta[actor] = wflrAfter > wflrBefore ? wflrAfter - wflrBefore : 0;
        ghost_lastWithdrawAsset[actor] = withdrawHook.asset();
        ghost_totalWithdrawals++;
    }

    /// @notice Execute a claim where the balance decreases between pre and post
    /// @dev Tests the safe delta pattern (should return 0, not revert)
    function executeClaimWithBalanceDecrease(uint256 actorSeed, uint256 existingBalance, uint256 decreaseBy) external {
        address actor = _actor(actorSeed);
        existingBalance = bound(existingBalance, 1, 1e30);
        decreaseBy = bound(decreaseBy, 1, existingBalance);

        // Set up initial balance (mint/burn to keep totalSupply in sync)
        _setBalance(rNat, actor, existingBalance);
        rNat.setClaimAmount(0); // No claim amount

        // Encode minimal valid claim data (1 project, month fetched on-chain)
        bytes memory data = abi.encodePacked(uint256(1), uint256(0));

        // Build (for INV-3 tracking)
        Execution[] memory executions = claimHook.build(address(0), actor, data);
        ghost_lastClaimBuildLength = executions.length;

        // Execute pre
        claimHook.setExecutionContext(actor);
        vm.prank(actor);
        claimHook.preExecute(address(0), actor, data);

        // Decrease balance between pre and post (simulates external transfer out)
        rNat.burn(actor, decreaseBy);

        // Execute the claim (no-op since claimAmount = 0)
        vm.prank(actor);
        (bool success,) = address(rNat).call(abi.encodeCall(rNat.claimRewards, (new uint256[](1), 1)));
        require(success, "claim call failed");

        // Execute post -- should NOT revert due to safe delta pattern
        vm.prank(actor);
        claimHook.postExecute(address(0), actor, data);

        // Record ghost state
        ghost_lastClaimOutAmount[actor] = claimHook.getOutAmount(actor);
        ghost_lastClaimActualDelta[actor] = 0; // balance decreased, actual delta is 0
        ghost_totalClaims++;
    }
}

/*//////////////////////////////////////////////////////////////
                    INVARIANT TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title RFLRHooksInvariantTest
/// @notice Invariant tests for ClaimRFLRHook and WithdrawRFLRHook
/// @dev Verifies 7 invariants across randomized handler actions
contract RFLRHooksInvariantTest is Test {
    ClaimRFLRHook public claimHook;
    WithdrawRFLRHook public withdrawHook;
    MockRNat public rNat;
    MockERC20 public wflr;
    RFLRHooksHandler public handler;

    address[] public actors;

    function setUp() public {
        // Deploy mock tokens
        wflr = new MockERC20("WFLR", "WFLR", 18);
        rNat = new MockRNat(address(wflr));

        // Deploy hooks
        claimHook = new ClaimRFLRHook(address(rNat));
        withdrawHook = new WithdrawRFLRHook(address(rNat), address(wflr));

        // Create actors
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));

        // Create handler
        handler = new RFLRHooksHandler(claimHook, withdrawHook, rNat, wflr, actors);

        // Target only the handler
        targetContract(address(handler));
    }

    /*//////////////////////////////////////////////////////////////
                INV-1: outAmount == actual balance delta
    //////////////////////////////////////////////////////////////*/

    /// @notice For all actors: outAmount from hook must equal the actual token balance change
    function invariant_INV1_outAmountMatchesActualDelta() public view {
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];

            assertEq(
                handler.ghost_lastClaimOutAmount(a),
                handler.ghost_lastClaimActualDelta(a),
                "INV-1 claim: outAmount must equal actual rFLR delta"
            );

            assertEq(
                handler.ghost_lastWithdrawOutAmount(a),
                handler.ghost_lastWithdrawActualDelta(a),
                "INV-1 withdraw: outAmount must equal actual WFLR delta"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                INV-2: asset is correctly set
    //////////////////////////////////////////////////////////////*/

    /// @notice After claim, asset == RNAT; after withdraw, asset == WFLR
    function invariant_INV2_assetCorrectlySet() public view {
        for (uint256 i; i < actors.length; ++i) {
            address a = actors[i];

            address claimAsset = handler.ghost_lastClaimAsset(a);
            if (claimAsset != address(0)) {
                assertEq(claimAsset, address(rNat), "INV-2 claim: asset must be RNAT");
            }

            address withdrawAsset = handler.ghost_lastWithdrawAsset(a);
            if (withdrawAsset != address(0)) {
                assertEq(withdrawAsset, address(wflr), "INV-2 withdraw: asset must be WFLR");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                INV-3: build always returns exactly 3 executions
    //////////////////////////////////////////////////////////////*/

    /// @notice build() must always return pre + 1 hook operation + post = 3 executions
    function invariant_INV3_buildReturnsThreeExecutions() public view {
        if (handler.ghost_totalClaims() > 0) {
            assertEq(handler.ghost_lastClaimBuildLength(), 3, "INV-3 claim: build must return 3 executions");
        }
        if (handler.ghost_totalWithdrawals() > 0) {
            assertEq(handler.ghost_lastWithdrawBuildLength(), 3, "INV-3 withdraw: build must return 3 executions");
        }
    }

    /*//////////////////////////////////////////////////////////////
                INV-4: hook flows never revert
    //////////////////////////////////////////////////////////////*/

    /// @notice The hook flow must never revert -- including balance-decrease scenarios
    function invariant_INV4_hookFlowsNeverRevert() public view {
        assertEq(handler.ghost_totalClaimReverts(), 0, "INV-4: claim hook should never revert");
        assertEq(handler.ghost_totalWithdrawReverts(), 0, "INV-4: withdraw hook should never revert");
    }

    /*//////////////////////////////////////////////////////////////
                INV-5: hook types are immutable and correct
    //////////////////////////////////////////////////////////////*/

    /// @notice Both hooks must be NONACCOUNTING type
    function invariant_INV5_hookTypeIsNonaccounting() public view {
        assertEq(
            uint256(claimHook.hookType()),
            uint256(ISuperHook.HookType.NONACCOUNTING),
            "INV-5: ClaimRFLRHook must be NONACCOUNTING"
        );
        assertEq(
            uint256(withdrawHook.hookType()),
            uint256(ISuperHook.HookType.NONACCOUNTING),
            "INV-5: WithdrawRFLRHook must be NONACCOUNTING"
        );
    }

    /*//////////////////////////////////////////////////////////////
                INV-6: inspect returns RNAT for both hooks
    //////////////////////////////////////////////////////////////*/

    /// @notice inspect() must return abi.encodePacked(RNAT) for both hooks
    function invariant_INV6_inspectReturnsRNat() public view {
        bytes memory expected = abi.encodePacked(address(rNat));
        assertEq(claimHook.inspect(""), expected, "INV-6: ClaimRFLRHook.inspect must return RNAT");
        assertEq(withdrawHook.inspect(""), expected, "INV-6: WithdrawRFLRHook.inspect must return RNAT");
    }

    /*//////////////////////////////////////////////////////////////
                INV-7: multi-actor isolation
    //////////////////////////////////////////////////////////////*/

    /// @notice One actor's claim/withdraw must not affect another actor's outAmount
    function invariant_INV7_multiActorIsolation() public view {
        for (uint256 i; i < actors.length; ++i) {
            for (uint256 j = i + 1; j < actors.length; ++j) {
                address a = actors[i];
                address b = actors[j];

                if (handler.ghost_lastClaimOutAmount(a) > 0 && handler.ghost_lastClaimOutAmount(b) > 0) {
                    assertEq(
                        handler.ghost_lastClaimOutAmount(a),
                        handler.ghost_lastClaimActualDelta(a),
                        "INV-7: actor A claim isolated"
                    );
                    assertEq(
                        handler.ghost_lastClaimOutAmount(b),
                        handler.ghost_lastClaimActualDelta(b),
                        "INV-7: actor B claim isolated"
                    );
                }
            }
        }
    }
}
