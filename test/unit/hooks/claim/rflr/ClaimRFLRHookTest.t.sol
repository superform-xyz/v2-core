// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { ClaimRFLRHook } from "../../../../../src/hooks/claim/flare/ClaimRFLRHook.sol";
import { IRNat } from "../../../../../src/vendor/flare/IRNat.sol";

contract ClaimRFLRHookTest is Helpers {
    ClaimRFLRHook public hook;

    address public rNat;
    address public account;

    function setUp() public {
        rNat = makeAddr("rNat");
        account = makeAddr("account");

        hook = new ClaimRFLRHook(rNat);
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
        new ClaimRFLRHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build() public view {
        uint256[] memory projectIds = new uint256[](2);
        projectIds[0] = 1;
        projectIds[1] = 2;

        bytes memory data = _createClaimRFLRData(5, projectIds);
        Execution[] memory executions = hook.build(address(0), account, data);

        // preExecute + claim + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[0].target, address(hook)); // preExecute
        assertEq(executions[1].target, rNat); // claim
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(hook)); // postExecute

        // Verify claim calldata
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (projectIds, 5));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    function test_Build_RevertIf_EmptyProjectIds() public {
        uint256[] memory projectIds = new uint256[](0);

        bytes memory data = _createClaimRFLRData(1, projectIds);
        vm.expectRevert(ClaimRFLRHook.EMPTY_PROJECT_IDS.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_MultipleProjectIds() public view {
        uint256[] memory projectIds = new uint256[](5);
        for (uint256 i; i < 5; ++i) {
            projectIds[i] = i + 10;
        }

        bytes memory data = _createClaimRFLRData(7, projectIds);
        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 3);

        // Verify projectIds in calldata
        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (projectIds, 7));
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

    /*//////////////////////////////////////////////////////////////
                           INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspector_ReturnsRNat() public view {
        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 1;

        bytes memory data = _createClaimRFLRData(1, projectIds);
        bytes memory argsEncoded = hook.inspect(data);

        assertEq(argsEncoded, abi.encodePacked(rNat));
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1));
        vm.expectRevert(ClaimRFLRHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), account, shortData);
    }

    function test_Build_RevertIf_TooManyProjectIds() public {
        // Encode month + length of 51 (exceeds MAX_PROJECT_IDS=50)
        bytes memory data = abi.encodePacked(uint256(1), uint256(51));
        for (uint256 i; i < 51; ++i) {
            data = bytes.concat(data, abi.encodePacked(i));
        }
        vm.expectRevert(ClaimRFLRHook.TOO_MANY_PROJECT_IDS.selector);
        hook.build(address(0), account, data);
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
                        CALLDATA DECODING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CalldataDecoding() public view {
        uint256[] memory projectIds = new uint256[](3);
        projectIds[0] = 100;
        projectIds[1] = 200;
        projectIds[2] = 300;

        bytes memory data = _createClaimRFLRData(12, projectIds);
        Execution[] memory executions = hook.build(address(0), account, data);

        bytes memory expectedCallData = abi.encodeCall(IRNat.claimRewards, (projectIds, 12));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCallData));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createClaimRFLRData(
        uint256 month_,
        uint256[] memory projectIds_
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = bytes.concat(abi.encodePacked(month_), abi.encodePacked(projectIds_.length));
        for (uint256 i; i < projectIds_.length; ++i) {
            data = bytes.concat(data, abi.encodePacked(projectIds_[i]));
        }
    }
}
