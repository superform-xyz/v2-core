// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

// 0x Settler Interfaces - Import directly from real contracts
import { IAllowanceHolder, ALLOWANCE_HOLDER } from "0x-settler/src/allowanceholder/IAllowanceHolder.sol";
import { ISettlerTakerSubmitted } from "0x-settler/src/interfaces/ISettlerTakerSubmitted.sol";
import { ISettlerBase } from "0x-settler/src/interfaces/ISettlerBase.sol";

/// @title Swap0xV2Hook
/// @author Superform Labs
/// @dev Hook for 0x Protocol v2 using AllowanceHolder pattern for smart contract compatibility
///
/// @notice ARCHITECTURE OVERVIEW:
/// This hook integrates with 0x Protocol v2's Settler architecture through the AllowanceHolder pattern:
/// 1. User calls /swap/allowance-holder/quote API endpoint to get swap calldata
/// 2. Hook receives AllowanceHolder.exec calldata with 5 parameters:
///    - operator: Settler contract address (allowed to consume allowance)
///    - token: Input token address
///    - amount: Input token amount to allow
///    - target: Settler contract address (call destination)
///    - data: Encoded call to Settler.execute(slippage, actions[], metadata)
/// 3. Hook validates and optionally updates amounts for hook chaining
/// 4. Execution flows: Account → AllowanceHolder → Settler → DEX protocols
///
///
/// @notice HOOK DATA STRUCTURE (total 73+ bytes):
/// @notice         address dstToken = address(bytes20(data[:20]));        // Expected output token
/// @notice         address dstReceiver = address(bytes20(data[20:40]));   // Token recipient (0 = account)
/// @notice         uint256 value = uint256(bytes32(data[40:72]));         // ETH value for native swaps
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);        // Hook chaining flag
/// @notice         bytes txData_ = data[73:]; // AllowanceHolder.exec calldata from 0x API
contract Swap0xV2Hook is BaseHook, ISuperHookContextAware {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parameters for validation to avoid stack too deep
    struct ValidationParams {
        address dstToken;
        address dstReceiver;
        address prevHook;
        address account;
        bool usePrevHookAmount;
    }

    /// @notice Local state for validation to avoid stack too deep - updated for real 0x architecture
    struct ValidationState {
        address operator;
        address token;
        uint256 amount;
        address payable target;
        bytes settlerCalldata;
        ISettlerBase.AllowedSlippage slippage;
        bytes[] actions;
        bytes32 zidAndAffiliate;
        uint256 prevAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 private constant _USE_PREV_HOOK_AMOUNT_POSITION = 72;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_RECEIVER();
    error INVALID_SELECTOR();
    error INVALID_INPUT_AMOUNT();
    error INVALID_OUTPUT_AMOUNT();
    error INVALID_DESTINATION_TOKEN();
    error PARTIAL_FILL_NOT_ALLOWED();
    error INVALID_ALLOWANCE_HOLDER_CALL();
    error NO_SETTLER_CALL_FOUND();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        // AllowanceHolder address is imported as a constant from real 0x contracts
        // ALLOWANCE_HOLDER = 0x0000000000001fF3684f28c67538d4D072C22734
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
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));
        uint256 value = uint256(bytes32(data[40:_USE_PREV_HOOK_AMOUNT_POSITION]));
        bool usePrevHookAmount = _decodeBool(data, _USE_PREV_HOOK_AMOUNT_POSITION);
        bytes calldata txData_ = data[73:];

        // VALIDATION AND AMOUNT UPDATE LOGIC:
        // Real AllowanceHolder.exec signature: exec(operator, token, amount, target, data)
        // If usePrevHookAmount is true, we need to:
        // 1. Decode the 5 AllowanceHolder.exec parameters
        // 2. Decode the nested Settler call in the 'data' parameter
        // 3. Update input amounts and proportionally scale minimum output amounts
        // 4. Re-encode everything back
        ValidationParams memory params = ValidationParams({
            dstToken: dstToken,
            dstReceiver: dstReceiver,
            prevHook: prevHook,
            account: account,
            usePrevHookAmount: usePrevHookAmount
        });

        bytes memory updatedTxData = _validateAndUpdateTxData(params, txData_);

        // SINGLE EXECUTION PATTERN:
        // 0x v2 requires only one call to AllowanceHolder.exec
        // which internally handles allowances and forwards to Settler
        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(ALLOWANCE_HOLDER),
            // VALUE HANDLING: ETH value for native token swaps
            value: value,
            // CALLDATA: Use updated calldata if amounts were modified, original otherwise
            callData: usePrevHookAmount ? updatedTxData : txData_
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, _USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory packed) {
        // Extract the AllowanceHolder calldata from hook data (starts at byte 73)
        bytes calldata txData_ = data[73:];
        bytes4 selector = bytes4(txData_[:4]);

        if (selector == IAllowanceHolder.exec.selector) {
            // Decode the real AllowanceHolder.exec parameters
            // exec(address operator, address token, uint256 amount, address payable target, bytes calldata data)
            (, address token,,, bytes memory settlerCalldata) =
                abi.decode(txData_[4:], (address, address, uint256, address, bytes));

            // Check if this is a Settler execution call
            if (settlerCalldata.length >= 4) {
                bytes4 settlerSelector;
                assembly {
                    settlerSelector := mload(add(settlerCalldata, 0x20))
                }

                if (settlerSelector == ISettlerTakerSubmitted.execute.selector) {
                    // Extract parameter data after 4-byte selector
                    bytes memory paramData = _extractParams(settlerCalldata);

                    // Decode the Settler execution parameters to extract token information
                    // execute(AllowedSlippage calldata slippage, bytes[] calldata actions, bytes32 zidAndAffiliate)
                    (ISettlerBase.AllowedSlippage memory slippage,,) =
                        abi.decode(paramData, (ISettlerBase.AllowedSlippage, bytes[], bytes32));

                    // Return input token (from AllowanceHolder) and output token (from Settler slippage)
                    packed = abi.encodePacked(token, address(slippage.buyToken));
                } else {
                    revert NO_SETTLER_CALL_FOUND();
                }
            } else {
                revert NO_SETTLER_CALL_FOUND();
            }
        } else {
            revert INVALID_SELECTOR();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validate and update transaction data, consolidating all validation logic
    /// @param params Validation parameters struct to avoid stack too deep
    /// @param txData Transaction data from calldata
    /// @return updatedTxData Updated transaction data if amounts were modified
    function _validateAndUpdateTxData(
        ValidationParams memory params,
        bytes calldata txData
    )
        private
        view
        returns (bytes memory updatedTxData)
    {
        if (txData.length < 4) {
            revert INVALID_ALLOWANCE_HOLDER_CALL();
        }

        bytes4 selector = bytes4(txData[:4]);

        if (selector != IAllowanceHolder.exec.selector) {
            revert INVALID_SELECTOR();
        }

        // Create validation state struct to manage local variables
        ValidationState memory state;

        // Decode the real AllowanceHolder.exec parameters
        // exec(address operator, address token, uint256 amount, address payable target, bytes calldata data)
        (state.operator, state.token, state.amount, state.target, state.settlerCalldata) =
            abi.decode(txData[4:], (address, address, uint256, address, bytes));

        // Validate that this is a Settler execute call
        if (state.settlerCalldata.length < 4) {
            revert NO_SETTLER_CALL_FOUND();
        }

        bytes4 settlerSelector;
        bytes memory settlerCalldata = state.settlerCalldata;
        assembly {
            settlerSelector := mload(add(settlerCalldata, 0x20))
        }
        if (settlerSelector != ISettlerTakerSubmitted.execute.selector) {
            revert NO_SETTLER_CALL_FOUND();
        }

        // Extract parameters from Settler.execute call data
        bytes memory settlerParamData = _extractParams(state.settlerCalldata);

        // Decode the Settler execute parameters
        // execute(AllowedSlippage calldata slippage, bytes[] calldata actions, bytes32 zidAndAffiliate)
        (state.slippage, state.actions, state.zidAndAffiliate) =
            abi.decode(settlerParamData, (ISettlerBase.AllowedSlippage, bytes[], bytes32));

        // Validate the transaction structure and parameters
        _validateSettlerParams(state.slippage, params.dstReceiver, params.dstToken, params.account);

        // Update amounts if using previous hook output
        if (params.usePrevHookAmount) {
            state.prevAmount = state.amount;

            // Update input amount to previous hook's output
            state.amount = ISuperHookResult(params.prevHook).getOutAmount(params.account);

            // Scale minimum output proportionally to maintain slippage tolerance
            state.slippage.minAmountOut =
                HookDataUpdater.getUpdatedOutputAmount(state.amount, state.prevAmount, state.slippage.minAmountOut);

            // Re-encode the updated Settler call
            state.settlerCalldata = bytes.concat(
                ISettlerTakerSubmitted.execute.selector,
                abi.encode(state.slippage, state.actions, state.zidAndAffiliate)
            );

            // Re-encode the updated AllowanceHolder.exec call
            updatedTxData = bytes.concat(
                selector, abi.encode(state.operator, state.token, state.amount, state.target, state.settlerCalldata)
            );
        }

        // Final validation: ensure no zero amounts after potential updates
        if (state.amount == 0) revert INVALID_INPUT_AMOUNT();
        if (state.slippage.minAmountOut == 0) revert INVALID_OUTPUT_AMOUNT();
    }

    function _validateSettlerParams(
        ISettlerBase.AllowedSlippage memory slippage,
        address receiver,
        address toToken,
        address account
    )
        private
        pure
    {
        // NATIVE TOKEN HANDLING:
        // 0x v2 uses address(0) in AllowedSlippage to represent native ETH
        // We normalize this to our NATIVE constant (0xEee...Eee) for consistency
        address outputTokenAddr = address(slippage.buyToken);
        if (outputTokenAddr == address(0)) {
            outputTokenAddr = NATIVE;
        }

        // Ensure the output token matches what the user expects to receive
        if (outputTokenAddr != toToken) {
            revert INVALID_DESTINATION_TOKEN();
        }

        // RECEIVER VALIDATION:
        // In 0x v2, outputs go to the recipient specified in AllowedSlippage
        // The receiver parameter in our hook data should either be:
        // - address(0): default to account (most common)
        // - account address: explicit specification (validation)
        if (receiver != address(0) && receiver != account) {
            revert INVALID_RECEIVER();
        }

        // RECIPIENT VALIDATION:
        // The slippage.recipient field specifies who receives the output tokens
        // This MUST be the executing account to ensure tokens go to the right place
        // If slippage.recipient != account, tokens would go to a different address
        if (slippage.recipient != account) {
            revert INVALID_RECEIVER();
        }
    }

    /// @dev Get the current balance of the destination token for tracking output amounts
    /// @notice This function is used in _preExecute and _postExecute to calculate
    ///         the actual amount of tokens received from the swap operation
    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        // Extract destination token and receiver from hook data
        address dstToken = address(bytes20(data[:20]));
        address dstReceiver = address(bytes20(data[20:40]));

        // RECEIVER DEFAULTING LOGIC:
        // If dstReceiver is address(0), default to the executing account
        // This is because 0x v2 Settler always sends output tokens to txn.from (the account)
        // So even if receiver is specified differently, tokens go to account in practice
        if (dstReceiver == address(0)) {
            dstReceiver = account;
        }

        // NATIVE TOKEN BALANCE HANDLING:
        // Check for both NATIVE constant (0xEee...Eee) and address(0)
        // since different parts of the system may use either representation for ETH
        if (dstToken == NATIVE || dstToken == address(0)) {
            return dstReceiver.balance; // ETH balance in wei
        }

        // ERC20 TOKEN BALANCE:
        // Standard ERC20 balanceOf call for token balances
        return IERC20(dstToken).balanceOf(dstReceiver);
    }

    /// @dev Extract parameters from call data by skipping the 4-byte function selector
    /// @param callData The raw call data including selector and parameters
    /// @return paramData The extracted parameter bytes without the selector
    function _extractParams(bytes memory callData) private pure returns (bytes memory paramData) {
        paramData = new bytes(callData.length - 4);

        for (uint256 j; j < paramData.length; j++) {
            paramData[j] = callData[j + 4];
        }
    }
}
