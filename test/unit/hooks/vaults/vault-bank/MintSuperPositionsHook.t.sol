// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MintSuperPositionsHook } from "../../../../../src/core/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";
import { IVaultBank } from "../../../../../src/periphery/interfaces/VaultBank/IVaultBank.sol";
import { ISuperHook, ISuperLockableHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockLockableHook } from "../../../../mocks/MockLockableHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

/**
 * @title MintSuperPositionsHookTest
 * @notice Test contract for MintSuperPositionsHook
 * @author Superform Labs
 */
contract MintSuperPositionsHookTest is Helpers {
    MintSuperPositionsHook public mintSuperPositionsHook;

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
        dstChainId = 123456;

        // Create the hook
        mintSuperPositionsHook = new MintSuperPositionsHook();

        // Create mock prev hook that implements ISuperLockableHook
        mockPrevHook = address(new MockLockableHook(ISuperHook.HookType.NONACCOUNTING, spToken, vaultBank, dstChainId, yieldSourceOracleId));
        MockLockableHook(mockPrevHook).setOutAmount(amount, address(this));
    }

    function test_Constructor() public view {
        assertEq(uint256(mintSuperPositionsHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Build_SuccessA() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, dstChainId);
        Execution[] memory executions = mintSuperPositionsHook.build(mockPrevHook, address(this), data);

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

        // Check third execution - lockAsset
        assertEq(executions[3].target, vaultBank, "C");
        assertEq(executions[3].value, 0, "C1");
        expectedCallData = abi.encodeCall(
            IVaultBank.lockAsset, 
            (yieldSourceOracleId, address(this), spToken, address(mintSuperPositionsHook), amount, uint64(dstChainId))
        );
        assertEq(executions[3].callData, expectedCallData);

        // Check fourth execution - reset approval
        assertEq(executions[4].target, spToken, "D");
        assertEq(executions[4].value, 0, "E");
        expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, 0));
        assertEq(executions[4].callData, expectedCallData, "F");
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Build_ZeroAmount() public {
        // Set prevHook amount to 0
        MockLockableHook(mockPrevHook).setOutAmount(0, address(this));
        
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, uint256(0), false, vaultBank, dstChainId);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        mintSuperPositionsHook.build(mockPrevHook, address(this), data);
    }

    function test_Build_WithUsePrev_ButNoHook() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, true, vaultBank, dstChainId);
        vm.expectRevert();
        mintSuperPositionsHook.build(address(0), address(this), data);
    }
    
    function test_Build_ZeroSpToken() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0), amount, false, vaultBank, dstChainId);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        mintSuperPositionsHook.build(mockPrevHook, address(this), data);
    }
    
    function test_Build_ZeroVaultBank() public {
        // Create a mock prev hook with zero vault bank
        address zeroVaultBankMock = address(new MockLockableHook(
            ISuperHook.HookType.NONACCOUNTING, 
            spToken, 
            address(0), 
            dstChainId, 
            yieldSourceOracleId
        ));
        MockLockableHook(zeroVaultBankMock).setOutAmount(amount, address(this));
        
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, address(0), dstChainId);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        mintSuperPositionsHook.build(zeroVaultBankMock, address(this), data);
    }
    
    function test_Build_ZeroYieldSourceOracleId() public {
        // Create a mock prev hook with zero oracle ID
        address zeroOracleIdMock = address(new MockLockableHook(
            ISuperHook.HookType.NONACCOUNTING, 
            spToken, 
            vaultBank, 
            dstChainId, 
            bytes32(0)
        ));
        MockLockableHook(zeroOracleIdMock).setOutAmount(amount, address(this));
        
        bytes memory data = abi.encodePacked(bytes32(0), spToken, amount, false, vaultBank, dstChainId);
        vm.expectRevert(MintSuperPositionsHook.ID_NOT_VALID.selector);
        mintSuperPositionsHook.build(zeroOracleIdMock, address(this), data);
    }
    
    function test_Build_ZeroDstChainId() public {
        // Create a mock prev hook with zero dst chain ID
        address zeroDstChainIdMock = address(new MockLockableHook(
            ISuperHook.HookType.NONACCOUNTING, 
            spToken, 
            vaultBank, 
            0, 
            yieldSourceOracleId
        ));
        MockLockableHook(zeroDstChainIdMock).setOutAmount(amount, address(this));
        
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken, amount, false, vaultBank, uint256(0));
        vm.expectRevert(MintSuperPositionsHook.ID_NOT_VALID.selector);
        mintSuperPositionsHook.build(zeroDstChainIdMock, address(this), data);
    }
}
