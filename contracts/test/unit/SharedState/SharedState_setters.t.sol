// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/Accounts.sol";
import { IERC7579Account, ERC7579ModeLib, ERC7579ExecutionLib } from "modulekit/external/ERC7579.sol";

// Superform
import { ISharedStateOperations } from "src/interfaces/state/ISharedStateOperations.sol";

import { MockTarget } from "test/mocks/MockTarget.sol";
import { Unit_Shared } from "test/unit/Unit_Shared.t.sol";

contract SharedState_setters is Unit_Shared {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    bytes32 public constant KEY = "0x123";

    function test_WhenProvidedAnAddress() external {
        address value = address(1);
        sharedStateWriter.setAddress(KEY, value);

        assertEq(sharedStateReader.getAddress(KEY, address(this)), value);
    }

    function test_WhenProvidedAddressAndIndex() external {
        address value = address(1);
        sharedStateWriter.setAddress(KEY, value, 10);

        assertEq(sharedStateReader.getAddress(KEY, address(this), 10), value);
    }

    function test_WhenProvidedBytes32() external {
        bytes32 value = bytes32("0x123");
        sharedStateWriter.setBytes32(KEY, value);

        assertEq(sharedStateReader.getBytes32(KEY, address(this)), value);
    }

    function test_WhenProvidedBytes32AndIndex() external {
        bytes32 value = bytes32("0x123");
        sharedStateWriter.setBytes32(KEY, value, 10);

        assertEq(sharedStateReader.getBytes32(KEY, address(this), 10), value);
    }

    function test_WhenProvidedBytes() external {
        bytes memory value = hex"1234567890abcdef";
        sharedStateWriter.setBytes(KEY, value);

        assertEq(sharedStateReader.getBytes(KEY, address(this)), value);
    }

    function test_WhenProvidedBytesAndIndex() external {
        bytes memory value = hex"1234567890abcdef";
        sharedStateWriter.setBytes(KEY, value, 10);

        assertEq(sharedStateReader.getBytes(KEY, address(this), 10), value);
    }

    function test_WhenProvidedUint(uint256 amount) external {
        amount = _bound(amount);
        sharedStateWriter.setUint(KEY, amount);

        assertEq(sharedStateReader.getUint(KEY, address(this)), amount);
    }

    function test_WhenProvidedAnUintAndIndex(uint256 amount) external {
        amount = _bound(amount);

        sharedStateWriter.setUint(KEY, amount, 10);

        assertEq(sharedStateReader.getUint(KEY, address(this), 10), amount);
    }

    function test_WhenProvidedInt(int256 amount) external {
        amount = int256(_bound(uint256(amount)));

        sharedStateWriter.setInt(KEY, amount);

        assertEq(sharedStateReader.getInt(KEY, address(this)), amount);
    }

    function test_WhenProvidedAnIntAndIndex(int256 amount) external {
        amount = int256(_bound(uint256(amount)));

        sharedStateWriter.setInt(KEY, amount, 10);

        assertEq(sharedStateReader.getInt(KEY, address(this), 10), amount);
    }

    function test_WhenProvidedString() external {
        string memory value = "0x123";
        sharedStateWriter.setString(KEY, value);

        assertEq(sharedStateReader.getString(KEY, address(this)), value);
    }

    function test_WhenProvidedStringAndIndex() external {
        string memory value = "0x123";
        sharedStateWriter.setString(KEY, value, 10);

        assertEq(sharedStateReader.getString(KEY, address(this), 10), value);
    }

    function test_WhenExistingUint() external {
        // it should be allowed to perform math operations
        uint256 value = 1;
        sharedStateWriter.setUint(KEY, value);

        uint256 index = sharedStateReader.lastUintValuesIndex(address(this));

        // add
        uint256 newValue = value + value;
        sharedStateOperations.addUint(KEY, index, value);
        assertEq(sharedStateReader.getUint(KEY, address(this)), newValue);

        // sub
        newValue = newValue - value;
        sharedStateOperations.subUint(KEY, index, value);
        assertEq(sharedStateReader.getUint(KEY, address(this)), newValue);

        // mul
        newValue = newValue * value;
        sharedStateOperations.mulUint(KEY, index, value);
        assertEq(sharedStateReader.getUint(KEY, address(this)), newValue);

        // div
        newValue = newValue / value;
        sharedStateOperations.divUint(KEY, index, value);
        assertEq(sharedStateReader.getUint(KEY, address(this)), newValue);
    }

    function test_WhenExistingInt() external {
        // it should be allowed to perform math operations
        int256 value = 1;
        sharedStateWriter.setInt(KEY, value);

        uint256 index = sharedStateReader.lastIntValuesIndex(address(this));

        // add
        int256 newValue = value + value;
        sharedStateOperations.addInt(KEY, index, value);
        assertEq(sharedStateReader.getInt(KEY, address(this)), newValue);

        // sub
        newValue = newValue - value;
        sharedStateOperations.subInt(KEY, index, value);
        assertEq(sharedStateReader.getInt(KEY, address(this)), newValue);

        // mul
        newValue = newValue * value;
        sharedStateOperations.mulInt(KEY, index, value);
        assertEq(sharedStateReader.getInt(KEY, address(this)), newValue);

        // div
        newValue = newValue / value;
        sharedStateOperations.divInt(KEY, index, value);
        assertEq(sharedStateReader.getInt(KEY, address(this)), newValue);
    }

    function test_WhenExecutingABatchOfUserOperationsAndSetterIsCalled() external {
        MockTarget target = new MockTarget();

        bytes4 selector = bytes4(keccak256("setUint(bytes32,uint256)"));
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(sharedStateWriter),
            value: 0,
            callData: abi.encodeWithSelector(selector, KEY, 1)
        });
        executions[1] = Execution({
            target: address(sharedStateWriter),
            value: 0,
            callData: abi.encodeWithSelector(ISharedStateOperations.addUint.selector, KEY, 1, 1)
        });

        UserOpData memory userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
        userOpData.execUserOps();

        assertEq(sharedStateReader.getUint(KEY, instance.account, 1), 2);
    }
}
