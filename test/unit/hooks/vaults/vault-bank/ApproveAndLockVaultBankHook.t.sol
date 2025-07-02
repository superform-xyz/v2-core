// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndLockVaultBankHook } from "../../../../../src/core/hooks/vaults/vault-bank/ApproveAndLockVaultBankHook.sol";
import { IVaultBank } from "../../../../../src/periphery/interfaces/VaultBank/IVaultBank.sol";
import { ISuperHook, ISuperLockableHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockLockableHook } from "../../../../mocks/MockLockableHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

/**
 * @title ApproveAndLockVaultBankHookTest
 * @notice Test contract for ApproveAndLockVaultBankHook
 * @author Superform Labs
 */
contract ApproveAndLockVaultBankHookTest is Helpers {
    ApproveAndLockVaultBankHook public approveAndLockHook;

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
        approveAndLockHook = new ApproveAndLockVaultBankHook();

        // Create mock prev hook that implements ISuperLockableHook
        mockPrevHook = address(new MockLockableHook(ISuperHook.HookType.NONACCOUNTING, spToken, vaultBank, dstChainId, yieldSourceOracleId));
        MockLockableHook(mockPrevHook).setOutAmount(amount, address(this));
    }

    function test_Constructor() public view {
        assertEq(uint256(approveAndLockHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    /*//////////////////////////////////////////////////////////////
                          BUILD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Build_Success() public view {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        Execution[] memory executions = approveAndLockHook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 6);

        // Check first execution - approve with 0
        assertEq(executions[1].target, spToken);
        assertEq(executions[1].value, 0);
        bytes memory expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, 0));
        assertEq(executions[1].callData, expectedCallData);

        // Check second execution - approve with amount
        assertEq(executions[2].target, spToken);
        assertEq(executions[2].value, 0);
        expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, amount));
        assertEq(executions[2].callData, expectedCallData);

        // Check third execution - lockAsset
        assertEq(executions[3].target, vaultBank);
        assertEq(executions[3].value, 0);
        expectedCallData = abi.encodeCall(
            IVaultBank.lockAsset, 
            (yieldSourceOracleId, address(this), spToken, mockPrevHook, amount, uint64(dstChainId))
        );
        assertEq(executions[3].callData, expectedCallData);

        // Check fourth execution - reset approval
        assertEq(executions[4].target, spToken);
        assertEq(executions[4].value, 0);
        expectedCallData = abi.encodeCall(IERC20.approve, (vaultBank, 0));
        assertEq(executions[4].callData, expectedCallData);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Build_NoPrevHook() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        vm.expectRevert(ApproveAndLockVaultBankHook.PREV_HOOK_NOT_VALID.selector);
        approveAndLockHook.build(address(0), address(this), data);
    }
    
    function test_Build_ZeroAmount() public {
        // Set prevHook amount to 0
        MockLockableHook(mockPrevHook).setOutAmount(0, address(this));
        
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndLockHook.build(mockPrevHook, address(this), data);
    }
    
    function test_Build_ZeroSpToken() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, address(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndLockHook.build(mockPrevHook, address(this), data);
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
        
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndLockHook.build(zeroVaultBankMock, address(this), data);
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
        
        bytes memory data = abi.encodePacked(bytes32(0), spToken);
        vm.expectRevert(ApproveAndLockVaultBankHook.ID_NOT_VALID.selector);
        approveAndLockHook.build(zeroOracleIdMock, address(this), data);
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
        
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        vm.expectRevert(ApproveAndLockVaultBankHook.ID_NOT_VALID.selector);
        approveAndLockHook.build(zeroDstChainIdMock, address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_PreExecute() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        
        // Check initial state
        assertEq(approveAndLockHook.getOutAmount(address(this)), 0);
        
        // Call preExecute
        approveAndLockHook.preExecute(mockPrevHook, address(this), data);
        
        // Verify outAmount was set correctly
        assertEq(approveAndLockHook.getOutAmount(address(this)), amount);
    }

    function test_PostExecute() public {
        bytes memory data = abi.encodePacked(yieldSourceOracleId, spToken);
        
        // Set initial state using preExecute
        approveAndLockHook.preExecute(mockPrevHook, address(this), data);
        assertEq(approveAndLockHook.getOutAmount(address(this)), amount);
        
        // Call postExecute - in this hook it doesn't do anything but we should test it anyway
        approveAndLockHook.postExecute(mockPrevHook, address(this), data);
        
        // Verify outAmount remains the same (since postExecute doesn't modify it)
        assertEq(approveAndLockHook.getOutAmount(address(this)), amount);
    }
}
