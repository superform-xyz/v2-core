// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";

/// @title BaseEulerLoanHook
/// @author Superform Labs
/// @notice Abstract base for all Euler V2 lending hooks, providing shared calldata layout constants and errors
/// @dev All Euler hooks share a standard data layout: 32-byte header, 20-byte addresses at offsets 32/52/72/92/112,
///      followed by uint256 amounts at offsets 132/164 and a bool at offset 196.
/// @dev UNSUPPORTED TOKENS: Fee-on-transfer and rebasing tokens are NOT supported. Balance delta calculations
///      in _preExecute/_postExecute assume standard ERC20 transfer semantics.
/// @dev EULER V1 DONATION ATTACK: The Euler V1 exploit (March 2023, $197M) leveraged donateToReserves for share
///      price manipulation. Euler V2 mitigates this with internal balance tracking — direct token transfers
///      do not affect share pricing. These hooks interact through standard vault functions only.
/// @dev EVC AUTH PATTERN: EVC operations (enableCollateral/enableController) are called directly by the smart
///      account. The EVC uses address prefixes (first 19 bytes) to determine account ownership. Integration tests
///      must verify the smart account address is recognized by the EVC as the account owner.
/// @dev INSPECT VALIDATION: inspect() functions rely on BytesLib for bounds checking. Callers should ensure
///      data meets MIN_DATA_LENGTH before calling inspect().
abstract contract BaseEulerLoanHook is BaseLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant COLLATERAL_VAULT_OFFSET = 32;
    uint256 internal constant DEBT_ASSET_OFFSET = 52;
    uint256 internal constant COLLATERAL_ASSET_OFFSET = 72;
    uint256 internal constant EVC_OFFSET = 92;
    uint256 internal constant CONTROLLER_VAULT_OFFSET = 112;
    uint256 internal constant PRIMARY_AMOUNT_OFFSET = 132;
    uint256 internal constant SECONDARY_AMOUNT_OFFSET = 164;
    uint256 internal constant USE_PREV_OFFSET = 196;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook calldata is shorter than the required minimum
    error INVALID_DATA_LENGTH();

    /// @notice Thrown when a different controller is already set for the account in the EVC
    error CONTROLLER_ALREADY_SET();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) { }
}
