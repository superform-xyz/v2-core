// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarkRootAsUsedHook } from "../../../../src/hooks/superform/MarkRootAsUsedHook.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";

contract MarkRootAsUsedHookTest is Helpers {
    using BytesLib for bytes;

    MarkRootAsUsedHook public hook;

    address public destinationExecutor;
    bytes32[] public merkleRoots;

    function setUp() public {
        destinationExecutor = makeAddr("destinationExecutor");

        merkleRoots = new bytes32[](2);
        merkleRoots[0] = keccak256("root1");
        merkleRoots[1] = keccak256("root2");

        hook = new MarkRootAsUsedHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(hook.SUB_TYPE()), uint256(HookSubTypes.MISC));
    }

    function test_BuildABC() public view {
        bytes memory data = _encodeData(destinationExecutor, merkleRoots);

        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, destinationExecutor);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_EmptyMerkleRoots() public {
        bytes32[] memory emptyRoots = new bytes32[](0);
        bytes memory data = _encodeData(destinationExecutor, emptyRoots);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData(destinationExecutor, merkleRoots);
        bytes memory inspectionResult = hook.inspect(data);

        assertEq(BytesLib.toAddress(inspectionResult, 0), destinationExecutor);
    }

    function test_DataDecoding() public view {
        bytes memory data = _encodeData(destinationExecutor, merkleRoots);

        address extractedExecutor = BytesLib.toAddress(data, 32);
        bytes memory merkleRootData = BytesLib.slice(data, 52, data.length - 52);
        bytes32[] memory extractedRoots = abi.decode(merkleRootData, (bytes32[]));

        assertEq(extractedExecutor, destinationExecutor);
        assertEq(extractedRoots.length, merkleRoots.length);
        assertEq(extractedRoots[0], merkleRoots[0]);
        assertEq(extractedRoots[1], merkleRoots[1]);
    }

    function _encodeData(
        address _destinationExecutor,
        bytes32[] memory _merkleRoots
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory placeholder = new bytes(32);
        bytes memory merkleRootData = abi.encode(_merkleRoots);

        bytes memory data = bytes.concat(placeholder, abi.encodePacked(_destinationExecutor), merkleRootData);
        return data;
    }
}
