// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test, console2 } from "forge-std/Test.sol";

/// @title StargateComposeMsgSizeComparison
/// @notice Compares V1 (6-field) vs V2 (2-field) compose message sizes using real production data.
/// @dev Uses calldata from Tenderly simulation 7ee45a9f-2166-4dd1-bf87-1ed186c0b3b7
/// @dev The simulation was a quoteSend() call on StargateOFTUSDC (Flare -> Base) that FAILED
/// @dev because the V1 compose message exceeded LayerZero's 10,000-byte limit.
contract StargateComposeMsgSizeComparison is Test {
    /// @dev LayerZero's enforced max message size in SendUln302._assertMessageSize()
    uint256 constant LZ_MAX_MESSAGE_SIZE = 10_000;

    /// @dev TaxiCodec adds 75 bytes of overhead (header + payload wrapping)
    uint256 constant TAXI_CODEC_OVERHEAD = 75;

    /// @dev Effective max composeMsg that fits within LZ limit
    uint256 constant EFFECTIVE_MAX_COMPOSE = LZ_MAX_MESSAGE_SIZE - TAXI_CODEC_OVERHEAD;

    struct V1Decoded {
        bytes initData;
        bytes executorCalldata;
        address account;
        address[] dstTokens;
        uint256[] intentAmounts;
        bytes sigData;
    }

    /// @notice Real production calldata from Tenderly simulation
    /// @dev quoteSend() on StargateOFTUSDC (0x77c71633c34c3784ede189d74223122422492a0f) on Flare
    /// @dev Block 62106288, Flare -> Base (dstEid=30184), amount=7.517481 USDC
    /// @dev TX: 0x4ea04967a1a7a897b0e3563865433ec121aec09a6377baf869900070dba60dff
    function test_ComposeMsgSizeComparison_RealProductionData() public view {
        // ═══════════════════════════════════════════════════════════════════
        // Step 1: Load V1 composeMsg from file
        // Format: abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)
        // ═══════════════════════════════════════════════════════════════════
        bytes memory v1ComposeMsg = vm.parseBytes(vm.readFile("test/integration/stargate/v1_compose_msg.hex"));

        // ═══════════════════════════════════════════════════════════════════
        // Step 2: Decode V1 6-field format into struct (avoids stack-too-deep)
        // ═══════════════════════════════════════════════════════════════════
        V1Decoded memory d;
        (d.initData, d.executorCalldata, d.account, d.dstTokens, d.intentAmounts, d.sigData) =
            abi.decode(v1ComposeMsg, (bytes, bytes, address, address[], uint256[], bytes));

        // ═══════════════════════════════════════════════════════════════════
        // Step 3: Re-encode as V2 2-field format: abi.encode(initData, sigData)
        // ═══════════════════════════════════════════════════════════════════
        bytes memory v2ComposeMsg = abi.encode(d.initData, d.sigData);

        // ═══════════════════════════════════════════════════════════════════
        // Step 4: Measure and log all sizes
        // ═══════════════════════════════════════════════════════════════════
        _logComparison(v1ComposeMsg, v2ComposeMsg, d);

        // ═══════════════════════════════════════════════════════════════════
        // Step 5: Assert the key result — V1 fails, V2 passes
        // ═══════════════════════════════════════════════════════════════════
        assertGt(v1ComposeMsg.length, EFFECTIVE_MAX_COMPOSE, "V1 should exceed LZ limit");
        assertLt(v2ComposeMsg.length, EFFECTIVE_MAX_COMPOSE, "V2 should fit within LZ limit");
    }

    function _logComparison(bytes memory v1, bytes memory v2, V1Decoded memory d) internal pure {
        uint256 savings = v1.length - v2.length;
        uint256 savingsPercent = (savings * 100) / v1.length;

        // Hook input comparison
        bytes memory v1HookInput = abi.encode(d.initData, d.executorCalldata, d.account, d.dstTokens, d.intentAmounts);
        bytes memory v2HookInput = abi.encode(d.initData);

        console2.log("============================================================");
        console2.log("  Stargate Compose Message Size Comparison");
        console2.log("  Real data: Tenderly sim 7ee45a9f (Flare -> Base)");
        console2.log("============================================================");
        console2.log("");
        console2.log("--- Transaction Details ---");
        console2.log("  Source:          Flare");
        console2.log("  Destination:     Base (dstEid=30184)");
        console2.log("  Amount:          7.517481 USDC");
        console2.log("  Account:        ", d.account);
        console2.log("  Dst tokens:     ", d.dstTokens.length);
        console2.log("  Intent amounts: ", d.intentAmounts.length);
        console2.log("");
        console2.log("--- Individual Field Sizes (raw) ---");
        console2.log("  initData:           ", d.initData.length, "bytes");
        console2.log("  executorCalldata:   ", d.executorCalldata.length, "bytes");
        console2.log("  account:             20 bytes");
        console2.log("  dstTokens:          ", d.dstTokens.length, "addresses");
        console2.log("  intentAmounts:      ", d.intentAmounts.length, "uint256s");
        console2.log("  sigData:            ", d.sigData.length, "bytes");
        console2.log("");
        console2.log("--- Hook Input (what bundler sends in composeMsg) ---");
        console2.log("  V1 hook input (5-field):  ", v1HookInput.length, "bytes");
        console2.log("  V2 hook input (1-field):  ", v2HookInput.length, "bytes");
        console2.log("  Hook input savings:       ", v1HookInput.length - v2HookInput.length, "bytes");
        console2.log("");
        console2.log("--- Compose Message (what goes over LayerZero) ---");
        console2.log("  V1 composeMsg (6-field):  ", v1.length, "bytes");
        console2.log("  V2 composeMsg (2-field):  ", v2.length, "bytes");
        console2.log("  Savings:                  ", savings, "bytes");
        console2.log("  Savings percentage:       ", savingsPercent, "%");
        console2.log("");
        console2.log("--- LayerZero Limit Check ---");
        console2.log("  LZ max message size:      10000 bytes");
        console2.log("  TaxiCodec overhead:          75 bytes");
        console2.log("  Effective max compose:    ", EFFECTIVE_MAX_COMPOSE, "bytes");
        console2.log("");

        if (v1.length > EFFECTIVE_MAX_COMPOSE) {
            console2.log("  V1: EXCEEDS LIMIT by      ", v1.length - EFFECTIVE_MAX_COMPOSE, "bytes  << BLOCKED");
        } else {
            console2.log("  V1: Within limit, margin: ", EFFECTIVE_MAX_COMPOSE - v1.length, "bytes");
        }

        if (v2.length > EFFECTIVE_MAX_COMPOSE) {
            console2.log("  V2: EXCEEDS LIMIT by      ", v2.length - EFFECTIVE_MAX_COMPOSE, "bytes  << BLOCKED");
        } else {
            console2.log("  V2: Within limit, margin: ", EFFECTIVE_MAX_COMPOSE - v2.length, "bytes  << OK");
        }

        console2.log("");
        console2.log("============================================================");
        console2.log("  RESULT: Savings = %d bytes (%d%%)", savings, savingsPercent);
        console2.log("============================================================");
    }

}
