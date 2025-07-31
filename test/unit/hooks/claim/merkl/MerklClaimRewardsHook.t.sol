// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IDistributor } from "../../../../../src/vendor/merkl/IDistributor.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MerklClaimRewardHook } from "../../../../../src/hooks/claim/merkl/MerklClaimRewardHook.sol";

contract MerklClaimRewardsHookTest is Helpers {
    using BytesLib for bytes;

    MerklClaimRewardHook public hook;

    address public distributor;

    address[] public users;
    address[] public tokens;
    uint256[] public amounts;
    bytes32[][] public proofs;

    function setUp() public {
        distributor = makeAddr("distributor");
        address user = makeAddr("user");
        users = [user, user, user];

        MockERC20 _mockToken1 = new MockERC20("Mock Token", "MTK", 18);
        MockERC20 _mockToken2 = new MockERC20("Mock Token", "MTK", 18);
        MockERC20 _mockToken3 = new MockERC20("Mock Token", "MTK", 18);

        tokens = [address(_mockToken1), address(_mockToken2), address(_mockToken3)];

        amounts = [1000, 2000, 3000];

        proofs = [
            [keccak256(abi.encodePacked(user, address(_mockToken1), uint256(1000)))],
            [keccak256(abi.encodePacked(user, address(_mockToken2), uint256(2000)))],
            [keccak256(abi.encodePacked(user, address(_mockToken3), uint256(3000)))]
        ];

        hook = new MerklClaimRewardHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_decodeAmount() public view {
        bytes memory data = _encodeData();
        assertEq(hook.decodeAmount(data), 0);
    }

    function test_replaceCalldataAmount() public view {
        bytes memory data = _encodeData();
        bytes memory newData = hook.replaceCalldataAmount(data, 5000);
        assertEq(newData, data);
    }

    function test_decodeUsePrevHookAmount() public view {
        bytes memory data = _encodeData();
        assertEq(hook.decodeUsePrevHookAmount(data), false);
    }

    function test_MerklClaimRewardsHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, distributor);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_DistributorZero() public {
        distributor = address(0);
        bytes memory data = _encodeData();
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_PreAndPostExecute() public {
        address account = makeAddr("account");
        _getTokens(tokens[0], account, amounts[0]);
        _getTokens(tokens[1], account, amounts[1]);
        _getTokens(tokens[2], account, amounts[2]);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData());
        assertEq(hook.getOutAmount(account), 0);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData());
        assertEq(hook.getOutAmount(account), 0);
    }

    function test_MerklClaimRewardsHook_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        // Check that distributor is encoded correctly
        assertEq(BytesLib.toAddress(argsEncoded, 0), distributor);

        // Check that users are encoded correctly
        assertEq(BytesLib.toAddress(argsEncoded, 20), users[0]);
        assertEq(BytesLib.toAddress(argsEncoded, 40), users[1]);
        assertEq(BytesLib.toAddress(argsEncoded, 60), users[2]);

        // Check that tokens are encoded correctly
        assertEq(BytesLib.toAddress(argsEncoded, 80), tokens[0]);
        assertEq(BytesLib.toAddress(argsEncoded, 100), tokens[1]);
        assertEq(BytesLib.toAddress(argsEncoded, 120), tokens[2]);
    }

    function test_CalldataDecoding() public view {
        bytes memory data = _encodeData();

        Execution[] memory executions = hook.build(address(0), users[0], data);

        assertEq(executions[1].target, distributor, "Distributor address not correctly decoded");

        bytes memory expectedCallData = abi.encodeCall(IDistributor.claim, (users, tokens, amounts, proofs));

        assertEq(
            keccak256(executions[1].callData),
            keccak256(expectedCallData),
            "Calldata doesn't contain the correct parameters"
        );
    }

    function _encodeData() internal view returns (bytes memory data) {
        data = abi.encodePacked(bytes32(0), distributor, uint256(users.length));

        for (uint256 i = 0; i < users.length; i++) {
            data = bytes.concat(data, bytes20(users[i]));
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            data = bytes.concat(data, bytes20(tokens[i]));
        }

        for (uint256 i = 0; i < amounts.length; i++) {
            data = bytes.concat(data, abi.encodePacked(amounts[i]));
        }

        data = bytes.concat(data, _flattenProofs(proofs));
    }

    function _flattenProofs(bytes32[][] memory proofsToFlatten) internal pure returns (bytes memory) {
        bytes memory flattenedProofs;

        for (uint256 i = 0; i < proofsToFlatten.length; i++) {
            flattenedProofs = bytes.concat(flattenedProofs, abi.encodePacked(uint256(proofsToFlatten[i].length))); // inner
                // array length

            for (uint256 j; j < proofsToFlatten[i].length; ++j) {
                flattenedProofs = bytes.concat(flattenedProofs, proofsToFlatten[i][j]);
            }
        }

        return flattenedProofs;
    }
}
