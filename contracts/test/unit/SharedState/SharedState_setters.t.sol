// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { ISharedStateWriter } from "../../../src/interfaces/state/ISharedStateWriter.sol";
import { ISharedStateReader } from "../../../src/interfaces/state/ISharedStateReader.sol";

contract SharedState_setters is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    ISharedStateWriter public sharedStateWriter;
    ISharedStateReader public sharedStateReader;

    bytes32 public constant KEY = "0x123";

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        sharedStateWriter = ISharedStateWriter(_getContract(ETH, "SharedState"));
        sharedStateReader = ISharedStateReader(_getContract(ETH, "SharedState"));
    }

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
}
