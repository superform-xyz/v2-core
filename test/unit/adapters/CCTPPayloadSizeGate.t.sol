// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test, console2 } from "forge-std/Test.sol";

import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @title CCTPPayloadSizeGate
/// @author Superform Labs
/// @notice Phase 0 gate for the CCTP destination adapter: proves that a realistic destination intent
///         fits inside CCTP V2's message-body ceiling.
/// @dev `MessageTransmitterV2.maxMessageBodySize()` is 8192 bytes (verified on-chain at
///      0x81D40F21F12A8F0E3252Bccb954D722d4c464B64). The body is `BurnMessageV2` (228 fixed bytes)
///      plus the `hookData` tail, so hookData must be <= 7964 bytes or `depositForBurnWithHook`
///      reverts on the SOURCE chain and the intent can never be built.
/// @dev The deployed `CCTPSendHook` emits the fat 6-tuple
///      `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`.
///      `executorCalldata` also appears a second time inside `signature.proofDst[i].info.data`, so it
///      is paid for twice. Stargate already had to abandon this format under LayerZero's *looser*
///      10 KB limit (specs/stargate-compose-data-minimization/spec.md:12).
/// @dev This suite measures the real encoding rather than estimating, and also measures the compact
///      2-tuple alternative so the size of the `CCTPSendHookV2` fallback is quantified.
contract CCTPPayloadSizeGate is Test {
    /// @dev MessageTransmitterV2.maxMessageBodySize() — verified live on Ethereum mainnet
    uint256 internal constant MAX_MESSAGE_BODY_SIZE = 8192;

    /// @dev Fixed BurnMessageV2 prefix preceding the hookData tail
    uint256 internal constant BURN_MESSAGE_FIXED = 228;

    /// @dev Ceiling for the hookData tail itself
    uint256 internal constant HOOK_DATA_CEILING = MAX_MESSAGE_BODY_SIZE - BURN_MESSAGE_FIXED; // 7964

    /// @dev Representative per-hook payload. Real layouts sit in this range: ApproveERC20Hook is a
    ///      52-byte strategy header + 73 bytes of fields = 125; Deposit4626VaultHook is 85.
    uint256 internal constant HOOK_DATA_BYTES = 125;

    /// @dev Merkle proof depth. A tree over ~256 leaves gives depth 8; deeper trees cost 32 bytes each.
    uint256 internal constant PROOF_DEPTH = 8;

    address internal constant ACCOUNT = address(0xA11CE);
    address internal constant EXECUTOR = address(0xE0E0);
    address internal constant VALIDATOR = address(0xDA11D);
    address internal constant USDC = address(0x0DDC);

    /*//////////////////////////////////////////////////////////////
                                BUILDERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build an ExecutorEntry with `nHooks` realistically-sized hooks
    function _executorCalldata(uint256 nHooks) internal pure returns (bytes memory) {
        address[] memory hooksAddresses = new address[](nHooks);
        bytes[] memory hooksData = new bytes[](nHooks);
        for (uint256 i; i < nHooks; ++i) {
            hooksAddresses[i] = address(uint160(0x1000 + i));
            hooksData[i] = new bytes(HOOK_DATA_BYTES);
        }
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        return abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));
    }

    /// @notice Build a realistic SignatureData blob, including the DstProof that duplicates
    ///         executorCalldata inside `info.data`.
    function _sigData(uint256 nHooks, uint256 nDstChains) internal view returns (bytes memory) {
        bytes memory executorCalldata = _executorCalldata(nHooks);

        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1000e6;

        uint64[] memory chains = new uint64[](nDstChains);
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](nDstChains);
        for (uint256 i; i < nDstChains; ++i) {
            chains[i] = uint64(8453 + i);
            bytes32[] memory proof = new bytes32[](PROOF_DEPTH);
            proofDst[i] = ISuperValidator.DstProof({
                proof: proof,
                dstChainId: uint64(8453 + i),
                info: ISuperValidator.DstInfo({
                    account: ACCOUNT,
                    executor: EXECUTOR,
                    dstTokens: dstTokens,
                    intentAmounts: intentAmounts,
                    validator: VALIDATOR,
                    data: executorCalldata
                })
            });
        }

        ISuperValidator.SignatureData memory sd = ISuperValidator.SignatureData({
            chainsWithDestinationExecution: chains,
            validUntil: uint48(block.timestamp + 1 days),
            validAfter: uint48(block.timestamp),
            merkleRoot: keccak256("root"),
            proofSrc: new bytes32[](PROOF_DEPTH),
            proofDst: proofDst,
            signature: new bytes(65)
        });
        return abi.encode(sd);
    }

    /// @notice The 6-tuple the DEPLOYED CCTPSendHook emits
    function _hookDataSixTuple(uint256 nHooks, uint256 initDataBytes) internal view returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1000e6;

        return abi.encode(
            new bytes(initDataBytes),
            _executorCalldata(nHooks),
            ACCOUNT,
            dstTokens,
            intentAmounts,
            _sigData(nHooks, 1)
        );
    }

    /// @notice The compact 2-tuple a hypothetical CCTPSendHookV2 would emit
    function _hookDataTwoTuple(uint256 nHooks, uint256 initDataBytes) internal view returns (bytes memory) {
        return abi.encode(new bytes(initDataBytes), _sigData(nHooks, 1));
    }

    /*//////////////////////////////////////////////////////////////
                                 THE GATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Sweep hook counts and report exactly where the 7964-byte cliff falls.
    function test_Gate_SweepHookCounts_SixTuple() public view {
        console2.log("=== 6-tuple (DEPLOYED CCTPSendHook format) ===");
        console2.log("ceiling (bytes):", HOOK_DATA_CEILING);
        for (uint256 n = 1; n <= 8; ++n) {
            uint256 lean = _hookDataSixTuple(n, 0).length;
            uint256 withInit = _hookDataSixTuple(n, 320).length;
            console2.log(n, lean, withInit, withInit <= HOOK_DATA_CEILING ? 1 : 0);
        }
    }

    /// @notice Same sweep for the compact 2-tuple, to size the CCTPSendHookV2 fallback.
    function test_Gate_SweepHookCounts_TwoTuple() public view {
        console2.log("=== 2-tuple (hypothetical CCTPSendHookV2) ===");
        for (uint256 n = 1; n <= 8; ++n) {
            uint256 lean = _hookDataTwoTuple(n, 0).length;
            uint256 withInit = _hookDataTwoTuple(n, 320).length;
            console2.log(n, lean, withInit, withInit <= HOOK_DATA_CEILING ? 1 : 0);
        }
    }

    /// @notice A 2-hook destination intent (approve + deposit) is the common shape and MUST fit.
    function test_Gate_TypicalTwoHookIntent_Fits() public view {
        uint256 size = _hookDataSixTuple(2, 320).length;
        console2.log("2-hook intent with 7702 initData (bytes):", size);
        assertLe(size, HOOK_DATA_CEILING, "typical 2-hook CCTP intent exceeds the CCTP body ceiling");
    }

    /// @notice Quantify the duplication overhead the 2-tuple migration would remove.
    function test_Gate_QuantifySixVsTwoTupleSaving() public view {
        for (uint256 n = 2; n <= 6; n += 2) {
            uint256 six = _hookDataSixTuple(n, 320).length;
            uint256 two = _hookDataTwoTuple(n, 320).length;
            console2.log(n, six, two, six - two);
        }
    }

    /// @notice Does the compact 2-tuple rescue the multi-destination case?
    function test_Gate_MultiDestination_TwoTuple() public view {
        for (uint256 chains = 1; chains <= 6; ++chains) {
            bytes memory hookData = abi.encode(new bytes(320), _sigData(2, chains));
            console2.log(chains, hookData.length, hookData.length <= HOOK_DATA_CEILING ? 1 : 0);
        }
    }

    /// @notice Multi-destination intents carry one DstProof per chain, each duplicating executorCalldata.
    function test_Gate_MultiDestinationScaling() public view {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1000e6;

        for (uint256 chains = 1; chains <= 4; ++chains) {
            bytes memory hookData = abi.encode(
                new bytes(320), _executorCalldata(2), ACCOUNT, dstTokens, intentAmounts, _sigData(2, chains)
            );
            console2.log(chains, hookData.length, hookData.length <= HOOK_DATA_CEILING ? 1 : 0);
        }
    }
}
