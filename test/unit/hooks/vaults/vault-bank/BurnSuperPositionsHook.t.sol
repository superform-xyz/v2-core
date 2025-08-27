// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BurnSuperPositionsHook } from "../../../../../src/hooks/vaults/vault-bank/BurnSuperPositionsHook.sol";
import { IVaultBank } from "../../../../../src/vendor/superform/IVaultBank.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockLockableHook } from "../../../../mocks/MockLockableHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

/**
 * @title BurnSuperPositionsHookTest
 * @notice Test contract for BurnSuperPositionsHook
 * @author Superform Labs
 */
contract BurnSuperPositionsHookTest is Helpers {
    BurnSuperPositionsHook public burnSuperPositionsHook;

    bytes32 public yieldSourceOracleId;
    address public spToken;
    address public vaultBank;
    address public mockPrevHook;
    uint256 public amount;
    uint256 public dstChainId;

    function setUp() public {
        yieldSourceOracleId = bytes32(keccak256("YIELD_SOURCE_ORACLE_ID"));
        spToken = address(new MockERC20("Superform Position Token", "SPT", 18));
        vaultBank = address(this);
        amount = 1000;
        dstChainId = 123_456;

        // Create the hook
        burnSuperPositionsHook = new BurnSuperPositionsHook();

        mockPrevHook = address(
            new MockLockableHook(ISuperHook.HookType.NONACCOUNTING, spToken, vaultBank, dstChainId, yieldSourceOracleId)
        );
        MockLockableHook(mockPrevHook).setOutAmount(amount, address(this));
    }

    function test_Constructor() public view {
        assertEq(uint256(burnSuperPositionsHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    /*//////////////////////////////////////////////////////////////
                           BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Build_Success() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, dstChainId);
        Execution[] memory executions = burnSuperPositionsHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 6);

        // Check first execution - approve with 0
        assertEq(executions[1].target, spToken, "A");
        assertEq(executions[1].value, 0);
        bytes memory expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, 0));
        assertEq(executions[1].callData, expectedCallData);

        // Check second execution - approve with amount
        assertEq(executions[2].target, spToken, "B");
        assertEq(executions[2].value, 0);
        expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, amount));
        assertEq(executions[2].callData, expectedCallData);

        // Check third execution - burnSuperPosition
        assertEq(executions[3].target, vaultBank, "C");
        assertEq(executions[3].value, 0, "C1");
        expectedCallData =
            abi.encodeCall(IVaultBank.burnSuperPosition, (amount, spToken, uint64(dstChainId), yieldSourceOracleId));
        assertEq(executions[3].callData, expectedCallData);

        // Check fourth execution - reset approval
        assertEq(executions[4].target, spToken, "D");
        assertEq(executions[4].value, 0, "E");
        expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, 0));
        assertEq(executions[4].callData, expectedCallData, "F");
    }

    function test_Build_WithUsePrevHook() public {
        uint256 prevHookAmount = 2000;
        MockLockableHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, true, vaultBank, dstChainId);
        Execution[] memory executions = burnSuperPositionsHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 6);

        // Check second execution to verify it uses prevHook amount instead of encoded amount
        assertEq(executions[2].target, spToken);
        assertEq(executions[2].value, 0);
        bytes memory expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, prevHookAmount));
        assertEq(executions[2].callData, expectedCallData);

        // Check third execution - burnSuperPosition with prevHook amount
        assertEq(executions[3].target, vaultBank);
        assertEq(executions[3].value, 0);
        expectedCallData = abi.encodeCall(
            IVaultBank.burnSuperPosition, (prevHookAmount, spToken, uint64(dstChainId), yieldSourceOracleId)
        );
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_VB_PreExecute() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, true, vaultBank, dstChainId);
        burnSuperPositionsHook.preExecute(address(this), address(this), data);

        assertEq(burnSuperPositionsHook.vaultBank(), vaultBank);
        assertEq(burnSuperPositionsHook.dstChainId(), dstChainId);
        assertEq(burnSuperPositionsHook.spToken(), spToken);
    }

    /*//////////////////////////////////////////////////////////////
                         ERROR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Build_ZeroAmount() public {
        // Set prevHook amount to 0
        MockLockableHook(mockPrevHook).setOutAmount(0, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, uint256(0), false, vaultBank, dstChainId);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        burnSuperPositionsHook.build(mockPrevHook, address(this), data);
    }

    function test_Build_WithUsePrev_ButNoHook() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, true, vaultBank, dstChainId);
        vm.expectRevert();
        burnSuperPositionsHook.build(address(0), address(this), data);
    }

    function test_Build_ZeroSpToken() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), amount, false, vaultBank, dstChainId);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        burnSuperPositionsHook.build(mockPrevHook, address(this), data);
    }

    function test_Build_ZeroVaultBank() public {
        // Create a mock prev hook with zero vault bank
        address zeroVaultBankMock = address(
            new MockLockableHook(
                ISuperHook.HookType.NONACCOUNTING, spToken, address(0), dstChainId, yieldSourceOracleId
            )
        );
        MockLockableHook(zeroVaultBankMock).setOutAmount(amount, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, address(0), dstChainId);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        burnSuperPositionsHook.build(zeroVaultBankMock, address(this), data);
    }

    function test_Build_ZeroYieldSourceOracleId() public {
        // Create a mock prev hook with zero oracle ID
        address zeroOracleIdMock =
            address(new MockLockableHook(ISuperHook.HookType.NONACCOUNTING, spToken, vaultBank, dstChainId, bytes32(0)));
        MockLockableHook(zeroOracleIdMock).setOutAmount(amount, address(this));

        bytes memory data = abi.encodePacked(bytes32(0), spToken, amount, false, vaultBank, dstChainId);
        vm.expectRevert(BurnSuperPositionsHook.ID_NOT_VALID.selector);
        burnSuperPositionsHook.build(zeroOracleIdMock, address(this), data);
    }

    function test_Build_ZeroDstChainId() public {
        // Create a mock prev hook with zero dst chain ID
        address zeroDstChainIdMock =
            address(new MockLockableHook(ISuperHook.HookType.NONACCOUNTING, spToken, vaultBank, 0, yieldSourceOracleId));
        MockLockableHook(zeroDstChainIdMock).setOutAmount(amount, address(this));

        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, uint256(0));
        vm.expectRevert(BurnSuperPositionsHook.ID_NOT_VALID.selector);
        burnSuperPositionsHook.build(zeroDstChainIdMock, address(this), data);
    }

    function test_DecodeAmount() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, dstChainId);
        uint256 decodedAmount = burnSuperPositionsHook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_DecodeUsePrevHookAmount() public view {
        bytes memory dataWithUsePrev =
            abi.encodePacked(yieldSourceOracleId, spToken, amount, true, vaultBank, dstChainId);
        bool usePrev = burnSuperPositionsHook.decodeUsePrevHookAmount(dataWithUsePrev);
        assertTrue(usePrev);

        bytes memory dataWithoutUsePrev =
            abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, dstChainId);
        usePrev = burnSuperPositionsHook.decodeUsePrevHookAmount(dataWithoutUsePrev);
        assertFalse(usePrev);
    }

    function test_Inspect() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, dstChainId);
        bytes memory inspectResult = burnSuperPositionsHook.inspect(data);

        // The inspect function should return spToken and vaultBank addresses
        assertEq(
            inspectResult, abi.encodePacked(spToken, vaultBank), "Inspect should return spToken and vaultBank addresses"
        );
    }
}
