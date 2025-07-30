// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../src/vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../src/libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../src/interfaces/ISuperHook.sol";
import { MockDex } from "./MockDex.sol";

/// @title MockDexHook
/// @author Superform Labs
/// @dev Hook for interacting with MockDex contract
/// @notice Data structure:
///         address inputToken = BytesLib.toAddress(data, 0);
///         uint256 inputAmount = BytesLib.toUint256(data, 20);
///         address outputToken = BytesLib.toAddress(data, 52);
///         uint256 outputAmount = BytesLib.toUint256(data, 72);
///         bool usePrevHookAmount = _decodeBool(data, 104);
contract MockDexHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    MockDex public immutable mockDex;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 104;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _mockDex) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (_mockDex == address(0)) revert ZERO_ADDRESS();
        mockDex = MockDex(payable(_mockDex));
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address inputToken = BytesLib.toAddress(data, 0);
        uint256 inputAmount = BytesLib.toUint256(data, 20);
        address outputToken = BytesLib.toAddress(data, 52);
        uint256 outputAmount = BytesLib.toUint256(data, 72);
        bool usePrevHookAmount = _decodeBool(data, 104);

        // If using previous hook amount, get it from the previous hook
        if (usePrevHookAmount && prevHook != address(0)) {
            inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        // Validate amounts
        if (inputAmount == 0 || outputAmount == 0) revert ZERO_AMOUNT();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(mockDex),
            value: inputToken == address(0) ? inputAmount : 0, // Send ETH if input token is address(0)
            callData: abi.encodeCall(MockDex.swap, (inputToken, outputToken, inputAmount, outputAmount))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal implementation of preExecute
    function _preExecute(address, address, bytes calldata) internal override {
        // Mock implementation - no setup needed for this simple DEX hook
    }

    /// @notice Internal implementation of postExecute
    function _postExecute(address, address account, bytes calldata data) internal override {
        // Set output amount and asset for subsequent hooks
        address outputToken = BytesLib.toAddress(data, 52);
        uint256 outputAmount = BytesLib.toUint256(data, 72);

        _setOutAmount(outputAmount, account);
        asset = outputToken;
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Create encoded data for MockDexHook
    /// @param inputToken Address of the input token
    /// @param inputAmount Amount of input token
    /// @param outputToken Address of the output token
    /// @param outputAmount Amount of output token expected
    /// @param usePrevHookAmount Whether to use amount from previous hook
    /// @return Encoded data for the hook
    function createSwapData(
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 outputAmount,
        bool usePrevHookAmount
    )
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            inputToken, // 20 bytes (0-19)
            inputAmount, // 32 bytes (20-51)
            outputToken, // 20 bytes (52-71)
            outputAmount, // 32 bytes (72-103)
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // 1 byte (104)
        );
    }
}
