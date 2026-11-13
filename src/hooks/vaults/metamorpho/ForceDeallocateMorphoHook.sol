// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IMorphoVaultV2 } from "../../../vendor/morpho/IMorphoVaultV2.sol";

/// @title ForceDeallocateMorphoHook
/// @author Superform Labs
/// @notice NONACCOUNTING hook that calls Morpho Vault V2's forceDeallocate() for emergency asset extraction
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         address adapter = BytesLib.toAddress(data, 52);
/// @notice         uint256 assets = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
/// @notice         bytes adapterData = BytesLib.slice(data, 105, data.length - 105);
/// @dev SUP-21780: THIS NATSPEC IS THE SOURCE OF THE REGISTRY BUILD PATH, not just documentation. The OMS
///      hook registry parses these lines to derive:
///        None-bytes32-32-yieldSourceOracleId, None-address-20-yieldSource, None-address-20-adapter,
///        None-uint256-32-assets, None-bool-1-usePrevHookAmount, None-bytes-0-adapterData
///      Two renames here are load-bearing rather than cosmetic. The first field used to be named
///      `placeholder0`, which matches the registry's reserved `^placeholder\d*$` pattern and is encoded
///      `Zeroes-...`, so the oracle id was zero-filled and never reached the chain. The second used to be
///      `morphoVaultV2`; OMS asset identity reads the parameter named literally `yieldSource`, so the old
///      name was invisible to it even though the offset was already correct. Renaming a field in this block
///      changes what Superman can encode. Do not rename them back.
/// @dev `adapter` and `adapterData` are real `forceDeallocate` arguments and must stay. `deadline` and
///      `maxPenaltyBps` were NOT: Morpho takes neither, it already caps the penalty at 2% (0.02e18)
///      internally, and intent expiry already bounds the deadline. NO PENALTY CAP OF ITS OWN (SUP-21849):
///      the exit planner prices the live rate into its quote and the redeem leg that follows carries the
///      on-chain output floor, so a cap here would only duplicate that check with a second knob.
/// @dev TRUST ASSUMPTION: This hook trusts Morpho Vault V2's internal reentrancy guards, adapter validation
///      and its own 2% penalty cap. onBehalf is always set to the executing smart account.
/// @dev NOT A WITHDRAW, despite moving underlying. `forceDeallocate` moves underlying from an adapter into
///      the vault's idle balance and burns penalty shares from the executing account; it does not redeem
///      shares and does not pay the account. It stays NONACCOUNTING, and the classification stays
///      config/instant/sized. Relabelling it would make OMS price this hop as a vault conversion.
contract ForceDeallocateMorphoHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant ADAPTER_OFFSET = 52;
    /// @notice The single sized leg. DELIBERATELY STILL 72: the two deleted words sat AFTER it, so
    ///         `decodeAmounts` and `replaceCalldataAmounts` keep working on the same offset.
    uint256 private constant ASSETS_OFFSET = 72;
    uint256 private constant USE_PREV_HOOK_AMOUNT_OFFSET = 104;
    /// @notice The raw `adapterData` tail starts here; a payload with no tail is exactly this long.
    uint256 private constant ADAPTER_DATA_OFFSET = 105;
    /// @dev Tied to the offset above rather than repeated, so the two cannot drift apart in a later edit.
    uint256 private constant MIN_DATA_LENGTH = ADAPTER_DATA_OFFSET;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Force Deallocate Morpho";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Force deallocates liquidity from a Morpho market";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev `build` makes no call to `yieldSource` (SUP-21849 removed the only read it had), so a codeless
    ///      vault address fails at execution inside `forceDeallocate`, not here.
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
        if (data.length < MIN_DATA_LENGTH) revert AMOUNT_NOT_VALID();

        address vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        address adapter = data.toAddress(ADAPTER_OFFSET);
        if (adapter == address(0)) revert ADDRESS_NOT_VALID();

        uint256 assets = data.toUint256(ASSETS_OFFSET);

        // Use previous hook amount if specified
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (assets == 0) revert AMOUNT_NOT_VALID();

        // Extract adapter data (raw tail, no length prefix). Empty is valid: an adapter that needs no
        // data is encoded as exactly MIN_DATA_LENGTH bytes with nothing after the flag.
        bytes memory adapterData;
        if (data.length > ADAPTER_DATA_OFFSET) {
            adapterData = data.slice(ADAPTER_DATA_OFFSET, data.length - ADAPTER_DATA_OFFSET);
        }

        // Build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IMorphoVaultV2.forceDeallocate, (adapter, adapterData, assets, account))
        });

    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, ASSETS_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev DENOMINATION IS DELIBERATELY `TOKEN`, NOT `ASSETS`, and SUP-21780 freezes it. By the letter of
    ///      `ISuperHook`'s own definitions `ASSETS` is the closer fit — `assets` here is an underlying
    ///      quantity on an ERC-4626-shaped vault. It stays `TOKEN` because `ASSETS` invites OMS to apply a
    ///      price-per-share conversion, and there is no share conversion in this operation at all: the
    ///      amount is a raw underlying quantity handed straight to `forceDeallocate`. Changing it also
    ///      requires an `amountMeta` override in `tooling/hook-enrichment.yaml`, whose default is IN/TOKEN.
    /// @dev The argument is intentionally unnamed and unread. `HookSizingInterface.t.sol` calls this with
    ///      `""`, so reading `data` here would break that caller.
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    /// @dev PIPE MODE STAYS THE `TRANSFORM` DEFAULT, recorded here because the alternative looks
    ///      superficially right. A hook that pays nobody reads like the textbook alternative mode, but
    ///      that mode AUTO-FORWARDS the previous hook's output, which is exactly the chaining this hook
    ///      must not invite (see `_preExecute`). That, not the sizing manifest, is the reason.
    /// @dev An earlier version of this comment justified it by claiming check 9 of
    ///      `tooling/validate-hook-sizing-manifest.ts` ASSERTS such hooks are sizeless. It does not — it
    ///      only `warn()`s, and its own comments whitelist `ApproveERC20Hook` and
    ///      `CircleGatewayWalletHook` as exactly that combination. The conclusion held but the cited
    ///      reason was wrong; corrected so this block is not read as specification.
    /// @dev DO NOT WRITE THE QUALIFIED ENUM NAME ANYWHERE IN THIS FILE, including in prose.
    ///      `detectPipeMode` in `tooling/generate-hook-sizing-manifest.ts` classifies a hook by plain
    ///      substring search over its SOURCE TEXT (it looks for the enum name, dot and mode spelled out
    ///      as one literal), so a comment
    ///      mentioning the qualified name would silently reclassify this hook in the generated sizing
    ///      manifest. That is why the modes are described in words above rather than named.
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], ASSETS_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice On-chain pre-execution: records what moved, and publishes an output that FAILS CLOSED.
    /// @dev outAmount IS DELIBERATELY ZERO, not the requested `assets`. This is a documented deviation
    ///      from SUP-21780's acceptance criterion ("outAmount equals assets"), because that criterion
    ///      conflicts with a rule this repo has already written down twice and paid for once:
    ///        - `BaseLoanHookV2._settleRepay` (src/hooks/loan/BaseLoanHookV2.sol:257-262): "A repay hook
    ///          is terminal — it consumes the debt asset and produces nothing — so it publishes
    ///          outAmount = 0 while keeping outToken = loanToken for off-chain classification.
    ///          Publishing the spend as an output would let a downstream usePrevHookAmount consumer
    ///          mistake it for produced tokens and spend an equal amount of unrelated wallet balance;
    ///          zero makes any such chaining fail closed."
    ///        - `HyperCoreSendAssetHook` (src/hooks/hypercore/HyperCoreSendAssetHook.sol:144-148) states
    ///          the same rule, and PR #1029 (`c219e2d3`) applied it after the fact to value-moving
    ///          HyperCore leaves, with a test proving the chain fails downstream.
    ///      `forceDeallocate` is terminal in exactly that sense: it moves underlying from an adapter into
    ///      the VAULT'S idle balance and burns penalty shares from the account. The account receives
    ///      nothing, and its share balance strictly DECREASES. Publishing `assets` here is byte-identical
    ///      to the receipt a real redeem publishes, so a successor with `usePrevHookAmount = true` would
    ///      size a real movement of the account's own balance from a figure it never received.
    /// @dev CONSEQUENCE FOR THE MANAGER PATH: `SuperVaultStrategy._processSingleHookExecution` compares
    ///      `getOutAmount()` against this leg's `expectedAssetsOrSharesOut`, so a leaf containing this
    ///      hook must pass ZERO as that leg's floor. That is the honest value — the leg produces nothing.
    ///      A non-zero floor would otherwise be "met" by a number describing funds nobody received.
    /// @dev outToken REMAINS `asset()` per the ticket, for off-chain classification. Keeping it is safe
    ///      only because outAmount is zero: `BaseLoanHookV2:145`'s `PREV_TOKEN_MISMATCH` would now pass
    ///      for a successor expecting the same underlying, and the zero amount is what stops it.
    /// @dev outToken is the vault's UNDERLYING, not the vault. This was previously the vault address, which
    ///      named a token that never moved: `forceDeallocate` shifts underlying out of an adapter into the
    ///      vault's idle balance and burns shares; no vault shares are transferred to or from the account.
    /// @dev THIS HOOK CANNOT BE CHAINED OFF, AND THAT IS ENFORCED, NOT DOCUMENTED. `outAmount` is zero
    ///      (see below), so every `usePrevHookAmount` consumer hits its own `amount == 0` guard and
    ///      reverts. An earlier revision published `assets` here and relied on a comment instead; that was
    ///      the weaker design and is the one this NatSpec used to defend.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        address vault = data.extractYieldSource();

        uint256 assets = data.toUint256(ASSETS_OFFSET);
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }
        // Zero, deliberately — see the NatSpec above. `assets` is still resolved because the
        // `usePrevHookAmount` path must still validate (a zero resolved amount is a configuration error
        // worth surfacing here rather than at the venue).
        if (assets == 0) revert AMOUNT_NOT_VALID();

        _setOutAmount(0, account);
        _setOutToken(IERC4626(vault).asset(), account);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address vault = data.extractYieldSource();
        address adapter = data.toAddress(ADAPTER_OFFSET);
        return abi.encodePacked(vault, adapter);
    }
}
