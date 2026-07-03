// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { ClaimRFLRV3Hook } from "../../../../../src/hooks/claim/flare/ClaimRFLRV3Hook.sol";
import { IRNat } from "../../../../../src/vendor/flare/IRNat.sol";

contract ClaimRFLRV3HookTest is Helpers {
    ClaimRFLRV3Hook public hook;

    address public rNat;
    address public account;

    function setUp() public {
        rNat = makeAddr("rNat");
        account = makeAddr("account");

        hook = new ClaimRFLRV3Hook(rNat);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.RNAT(), rNat);
    }

    function test_Constructor_RevertIf_RNatZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ClaimRFLRV3Hook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                         NAME / DESCRIPTION
    //////////////////////////////////////////////////////////////*/

    function test_Name() public view {
        assertEq(hook.name(), "Claim RFLR V3");
    }

    function test_Description() public view {
        assertEq(hook.description(), "Claims rFLR rewards from Flare's RNat contract with safe balance snapshot");
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SingleClaimableProject() public {
        _mockProjectsCount(3);
        _mockCurrentMonth(5);
        _mockClaimableRewards(0, account, 0);
        _mockClaimableRewards(1, account, 100e18);
        _mockClaimableRewards(2, account, 0);

        Execution[] memory executions = hook.build(address(0), account, "");

        // preExecute + claim + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[0].target, address(hook)); // preExecute
        assertEq(executions[1].target, rNat); // claim
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(hook)); // postExecute

        uint256[] memory expectedIds = new uint256[](1);
        expectedIds[0] = 1;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 5));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_MultipleClaimableProjects() public {
        _mockProjectsCount(4);
        _mockCurrentMonth(7);
        _mockClaimableRewards(0, account, 50e18);
        _mockClaimableRewards(1, account, 0);
        _mockClaimableRewards(2, account, 200e18);
        _mockClaimableRewards(3, account, 30e18);

        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);

        uint256[] memory expectedIds = new uint256[](3);
        expectedIds[0] = 0;
        expectedIds[1] = 2;
        expectedIds[2] = 3;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 7));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_AllProjectsClaimable() public {
        _mockProjectsCount(3);
        _mockCurrentMonth(1);
        _mockClaimableRewards(0, account, 10e18);
        _mockClaimableRewards(1, account, 20e18);
        _mockClaimableRewards(2, account, 30e18);

        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);

        uint256[] memory expectedIds = new uint256[](3);
        expectedIds[0] = 0;
        expectedIds[1] = 1;
        expectedIds[2] = 2;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 1));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_RevertIf_NoClaimableRewards_AllZero() public {
        _mockProjectsCount(3);
        _mockClaimableRewards(0, account, 0);
        _mockClaimableRewards(1, account, 0);
        _mockClaimableRewards(2, account, 0);

        vm.expectRevert(ClaimRFLRV3Hook.NO_CLAIMABLE_REWARDS.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_NoProjects() public {
        _mockProjectsCount(0);

        vm.expectRevert(ClaimRFLRV3Hook.NO_CLAIMABLE_REWARDS.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_TooManyProjects() public {
        _mockProjectsCount(201);

        vm.expectRevert(ClaimRFLRV3Hook.TOO_MANY_PROJECTS.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_ExactlyMaxProjects_Succeeds() public {
        // 200 is the max allowed — should not revert
        _mockProjectsCount(200);
        _mockCurrentMonth(2);
        for (uint256 i = 0; i < 200; ++i) {
            _mockClaimableRewards(i, account, i == 0 ? 1e18 : 0);
        }

        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);

        uint256[] memory expectedIds = new uint256[](1);
        expectedIds[0] = 0;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 2));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreAndPostExecute_ExistingAccount() public {
        uint256 initialBalance = 500 ether;
        uint256 claimedAmount = 100 ether;

        // balanceOf succeeds for existing account
        vm.mockCall(rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(initialBalance));

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), initialBalance);

        // Balance increases after claim
        vm.mockCall(
            rNat,
            abi.encodeWithSelector(IERC20.balanceOf.selector, account),
            abi.encode(initialBalance + claimedAmount)
        );

        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), claimedAmount);
    }

    function test_PreExecute_SetsAsset() public {
        vm.mockCall(rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(0));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        assertEq(hook.asset(), rNat);
    }

    /// @dev New account: balanceOf reverts because no RNatAccount exists yet.
    ///      _preExecute leaves outAmount at 0 (default). After claimRewards creates
    ///      the RNatAccount, _postExecute gets the full claimed amount as delta.
    function test_PreAndPostExecute_NewAccount_BalanceOfReverts() public {
        uint256 claimedAmount = 75 ether;

        // Pre: balanceOf reverts (no RNatAccount exists yet)
        vm.mockCallRevert(rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), "no RNatAccount");

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");
        // outAmount stays at 0 (default) since snapshot was skipped
        assertEq(hook.getOutAmount(account), 0);

        // Post: balanceOf now succeeds after claimRewards lazily created RNatAccount
        vm.clearMockedCalls();
        vm.mockCall(
            rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(claimedAmount)
        );

        vm.prank(account);
        hook.postExecute(address(0), account, "");
        // delta = claimedAmount - 0 = claimedAmount
        assertEq(hook.getOutAmount(account), claimedAmount);
    }

    /// @dev Existing account with 0 rFLR balance: _preExecute snapshots 0, then
    ///      postExecute computes delta = claimedAmount - 0 = claimedAmount.
    function test_PreAndPostExecute_ExistingAccountZeroBalance() public {
        uint256 claimedAmount = 50 ether;

        // balanceOf succeeds but returns 0 (account exists, no accumulated rFLR yet)
        vm.mockCall(rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(0));

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), 0);

        // After claim, balance increases
        vm.mockCall(
            rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(claimedAmount)
        );

        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), claimedAmount);
    }

    function test_PostExecute_ZeroDeltaWhenBalanceDecreases() public {
        uint256 initialBalance = 500 ether;

        vm.mockCall(rNat, abi.encodeWithSelector(IERC20.balanceOf.selector, account), abi.encode(initialBalance));
        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        // Balance dropped (edge case — handled safely, not a revert)
        vm.mockCall(
            rNat,
            abi.encodeWithSelector(IERC20.balanceOf.selector, account),
            abi.encode(initialBalance - 100 ether)
        );

        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspector_ReturnsRNat() public view {
        bytes memory argsEncoded = hook.inspect("");
        assertEq(argsEncoded, abi.encodePacked(rNat));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _mockProjectsCount(uint256 count) internal {
        vm.mockCall(rNat, abi.encodeCall(IRNat.getProjectsCount, ()), abi.encode(count));
    }

    function _mockClaimableRewards(uint256 projectId, address owner, uint128 amount) internal {
        vm.mockCall(rNat, abi.encodeCall(IRNat.getClaimableRewards, (projectId, owner)), abi.encode(amount));
    }

    function _mockCurrentMonth(uint256 month) internal {
        vm.mockCall(rNat, abi.encodeCall(IRNat.getCurrentMonth, ()), abi.encode(month));
    }
}
