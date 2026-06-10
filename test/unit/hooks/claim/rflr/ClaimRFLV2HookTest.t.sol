// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { ClaimRFLV2Hook } from "../../../../../src/hooks/claim/flare/ClaimRFLV2Hook.sol";
import { IRNat } from "../../../../../src/vendor/flare/IRNat.sol";

contract ClaimRFLV2HookTest is Helpers {
    ClaimRFLV2Hook public hook;

    address public rNat;
    address public account;

    function setUp() public {
        rNat = makeAddr("rNat");
        account = makeAddr("account");

        hook = new ClaimRFLV2Hook(rNat);
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
        new ClaimRFLV2Hook(address(0));
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

        // Verify claim calldata
        uint256[] memory expectedIds = new uint256[](1);
        expectedIds[0] = 1;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 5));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_MultipleClaimableProjects() public {
        _mockProjectsCount(5);
        _mockCurrentMonth(10);
        _mockClaimableRewards(0, account, 50e18);
        _mockClaimableRewards(1, account, 0);
        _mockClaimableRewards(2, account, 200e18);
        _mockClaimableRewards(3, account, 0);
        _mockClaimableRewards(4, account, 75e18);

        Execution[] memory executions = hook.build(address(0), account, "");

        assertEq(executions.length, 3);

        uint256[] memory expectedIds = new uint256[](3);
        expectedIds[0] = 0;
        expectedIds[1] = 2;
        expectedIds[2] = 4;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 10));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_AllProjectsClaimable() public {
        _mockProjectsCount(3);
        _mockCurrentMonth(7);
        _mockClaimableRewards(0, account, 10e18);
        _mockClaimableRewards(1, account, 20e18);
        _mockClaimableRewards(2, account, 30e18);

        Execution[] memory executions = hook.build(address(0), account, "");

        assertEq(executions.length, 3);

        uint256[] memory expectedIds = new uint256[](3);
        expectedIds[0] = 0;
        expectedIds[1] = 1;
        expectedIds[2] = 2;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 7));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_RevertIf_NoClaimableRewards() public {
        _mockProjectsCount(3);
        _mockCurrentMonth(5);
        _mockClaimableRewards(0, account, 0);
        _mockClaimableRewards(1, account, 0);
        _mockClaimableRewards(2, account, 0);

        vm.expectRevert(ClaimRFLV2Hook.NO_CLAIMABLE_REWARDS.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_ZeroProjects() public {
        _mockProjectsCount(0);

        vm.expectRevert(ClaimRFLV2Hook.NO_CLAIMABLE_REWARDS.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_RevertIf_TooManyProjects() public {
        _mockProjectsCount(201);

        vm.expectRevert(ClaimRFLV2Hook.TOO_MANY_PROJECTS.selector);
        hook.build(address(0), account, "");
    }

    function test_Build_EmptyDataAccepted() public {
        _mockProjectsCount(1);
        _mockCurrentMonth(1);
        _mockClaimableRewards(0, account, 1e18);

        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);
    }

    function test_Build_NonEmptyDataIgnored() public {
        _mockProjectsCount(1);
        _mockCurrentMonth(1);
        _mockClaimableRewards(0, account, 1e18);

        // Pass arbitrary non-empty data -- should be ignored
        bytes memory arbitraryData = abi.encodePacked(uint256(999), uint256(888));
        Execution[] memory executions = hook.build(address(0), account, arbitraryData);
        assertEq(executions.length, 3);
    }

    function test_Build_ExactlyMaxProjects() public {
        _mockProjectsCount(200);
        _mockCurrentMonth(3);

        // Make only project 100 claimable
        for (uint256 i; i < 200; ++i) {
            _mockClaimableRewards(i, account, i == 100 ? 1e18 : 0);
        }

        Execution[] memory executions = hook.build(address(0), account, "");
        assertEq(executions.length, 3);

        uint256[] memory expectedIds = new uint256[](1);
        expectedIds[0] = 100;
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (expectedIds, 3));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreAndPostExecute() public {
        uint256 initialBalance = 500 ether;
        uint256 claimedAmount = 100 ether;

        // Mock RNAT.balanceOf for pre
        vm.mockCall(rNat, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialBalance));

        // Set up execution context
        hook.setExecutionContext(account);

        // Pre-execute
        vm.prank(account);
        hook.preExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), initialBalance);

        // Mock increased balance for post
        vm.mockCall(rNat, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialBalance + claimedAmount));

        // Post-execute
        vm.prank(account);
        hook.postExecute(address(0), account, "");
        assertEq(hook.getOutAmount(account), claimedAmount);
    }

    function test_PreExecute_SetsAsset() public {
        vm.mockCall(rNat, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(0));

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        assertEq(hook.asset(), rNat);
    }

    function test_PostExecute_ZeroDeltaWhenBalanceDecreases() public {
        uint256 initialBalance = 500 ether;

        // Mock RNAT.balanceOf for pre (high balance)
        vm.mockCall(rNat, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialBalance));

        hook.setExecutionContext(account);

        vm.prank(account);
        hook.preExecute(address(0), account, "");

        // Mock decreased balance for post (balance dropped)
        vm.mockCall(rNat, abi.encodeCall(IERC20.balanceOf, (account)), abi.encode(initialBalance - 100 ether));

        vm.prank(account);
        hook.postExecute(address(0), account, "");

        // Should be 0, not revert
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
