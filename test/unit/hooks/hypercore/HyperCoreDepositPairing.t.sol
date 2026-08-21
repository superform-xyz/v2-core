// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { DeployV2OtherHooks } from "../../../../script/DeployV2OtherHooks.s.sol";

/// @notice Exposes the deploy script's internal pairing guard so it can be exercised directly.
contract PairingHarness is DeployV2OtherHooks {
    function depositArgs(address token, address gateway, uint32 dex) external pure returns (bytes memory) {
        return _hyperCoreDepositArgs(token, gateway, dex);
    }

    /// @dev Exposes the real deploy-path wiring, configuration included.
    function depositArgsForChain(uint64 chainId) external returns (bytes memory) {
        _setOtherHooksConfiguration();
        return _hyperCoreDepositArgsForChain(chainId);
    }
}

/// @notice The token/dex pairing guard must actually fire, not just read as if it does.
/// @dev A non-quote token against a perp dex emits a CoreWriter action 13 HyperCore will not credit.
///      CoreWriter cannot revert, so nothing downstream catches it — this guard is the only check.
contract HyperCoreDepositPairingTest is Test {
    PairingHarness internal h;

    address internal constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address internal constant USDC_GATEWAY = 0x6B9E773128f453f5c2C60935Ee2DE2CBc5390A24;
    // UBTC — HyperCore token index 197, its own distinct gateway
    address internal constant UBTC = 0x9FDBdA0A5e284c32744D2f17Ee5c74B284993463;

    uint32 internal constant DEX_PERP = 0;
    uint32 internal constant DEX_SPOT = type(uint32).max;
    uint64 internal constant HYPEREVM_CHAIN_ID = 999;

    function setUp() public {
        h = new PairingHarness();
    }

    /// @dev The scenario the guard exists for: a second token deployed against a perp dex.
    function test_Revert_NonQuoteTokenAgainstPerpDex() public {
        vm.expectRevert(bytes("HyperCore deposit: perp destinationDex requires the quote asset"));
        h.depositArgs(UBTC, address(0xBEEF), DEX_PERP);
    }

    /// @dev The same token is fine on spot — that is the correct pairing for a non-quote asset.
    function test_NonQuoteTokenAgainstSpotDexIsAllowed() public view {
        bytes memory args = h.depositArgs(UBTC, address(0xBEEF), DEX_SPOT);
        assertEq(args, abi.encode(UBTC, address(0xBEEF), DEX_SPOT), "spot pairing must encode through");
    }

    /// @dev The shipping configuration.
    function test_QuoteAssetAgainstPerpDexIsAllowed() public view {
        bytes memory args = h.depositArgs(USDC, USDC_GATEWAY, DEX_PERP);
        assertEq(args, abi.encode(USDC, USDC_GATEWAY, DEX_PERP), "USDC perps pairing must encode through");
    }

    /// @dev Guards the config-drift case too: a wrong address in the USDC mapping entry.
    function test_Revert_WrongAddressInQuoteAssetSlot() public {
        vm.expectRevert(bytes("HyperCore deposit: perp destinationDex requires the quote asset"));
        h.depositArgs(address(0xDEAD), USDC_GATEWAY, DEX_PERP);
    }

    /// @dev A HIP-3 builder-deployed dex picks its own collateral asset, so "not spot" does not
    ///      imply "quoted in USDC". Rejected outright rather than guessed at — otherwise the guard
    ///      would accept USDC on a dex not quoted in USDC, which is the stranding it exists to stop.
    function test_Revert_Hip3DexIsRejectedNotInferred() public {
        vm.expectRevert(bytes("HyperCore deposit: unsupported destinationDex"));
        h.depositArgs(USDC, USDC_GATEWAY, 1);
    }

    /// @dev And the mirror: a token legitimately quoted on a HIP-3 dex is not silently approved.
    function test_Revert_Hip3DexRejectedForNonQuoteTokenToo() public {
        vm.expectRevert(bytes("HyperCore deposit: unsupported destinationDex"));
        h.depositArgs(UBTC, address(0xBEEF), 1);
    }

    /*//////////////////////////////////////////////////////////////
                      THE WIRING, NOT A COPY OF IT
    //////////////////////////////////////////////////////////////*/

    /// @dev The guard being correct is worthless if the deploy path passes something else. This
    ///      asserts the args the real call site builds: USDC, its gateway, perp dex. Flipping the
    ///      call site to SPOT would silently move where user deposits land and reinstate the
    ///      usdClassTransfer leg — with every other test in this file still green.
    function test_DeployPathWiresUsdcToPerpDex() public {
        bytes memory args = h.depositArgsForChain(HYPEREVM_CHAIN_ID);
        assertEq(args, abi.encode(USDC, USDC_GATEWAY, DEX_PERP), "deploy path must wire USDC to perp dex 0");

        (address token, address gateway, uint32 dex) = abi.decode(args, (address, address, uint32));
        assertEq(token, USDC, "token must be the real USDC ERC-20, not the gateway");
        assertEq(gateway, USDC_GATEWAY, "gateway must be tokenInfo.evmContract");
        assertEq(dex, DEX_PERP, "perp dex 0: deposits credit perp margin directly");
        assertTrue(token != gateway, "token and gateway must never be the same address");
    }
}
