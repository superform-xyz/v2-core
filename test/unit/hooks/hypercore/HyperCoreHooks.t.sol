// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { BaseHyperCoreWriterHook } from "../../../../src/hooks/hypercore/BaseHyperCoreWriterHook.sol";
import { HyperCoreAddApiWalletHook } from "../../../../src/hooks/hypercore/HyperCoreAddApiWalletHook.sol";
import { HyperCoreUsdClassTransferHook } from "../../../../src/hooks/hypercore/HyperCoreUsdClassTransferHook.sol";
import { HyperCoreSendAssetHook } from "../../../../src/hooks/hypercore/HyperCoreSendAssetHook.sol";
import { HyperCoreApproveBuilderFeeHook } from "../../../../src/hooks/hypercore/HyperCoreApproveBuilderFeeHook.sol";
import { ICoreWriter } from "../../../../src/vendor/hyperliquid/ICoreWriter.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../../src/interfaces/ISuperHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";

/// @notice Byte-exact fixture tests for the CoreWriter hook family.
/// @dev These fixtures are transcribed from real HyperEVM mainnet payloads. They are not
///      defence-in-depth over an abi.encodeCall reconstruction — they are the ENTIRE defence.
///      A reconstruction shares the hook's own ABI assumption and would pass against a wrong tuple.
///      CoreWriter has no revert path, so a wrong encoding is silently accepted on-chain and the
///      only place it can ever be caught is here.
contract HyperCoreHooksTest is Helpers {
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;
    uint64 internal constant MAX_BUILDER_FEE_RATE = 1000; // 0.1%, the perp protocol maximum

    HyperCoreAddApiWalletHook internal addAgent;
    HyperCoreUsdClassTransferHook internal classTransfer;
    HyperCoreSendAssetHook internal sendAsset;
    HyperCoreApproveBuilderFeeHook internal builderFee;

    function setUp() public {
        addAgent = new HyperCoreAddApiWalletHook(CORE_WRITER);
        classTransfer = new HyperCoreUsdClassTransferHook(CORE_WRITER);
        sendAsset = new HyperCoreSendAssetHook(CORE_WRITER);
        builderFee = new HyperCoreApproveBuilderFeeHook(CORE_WRITER, MAX_BUILDER_FEE_RATE);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Every leaf emits exactly one execution: preExecute, the CoreWriter call, postExecute.
    function _payloadOf(Execution[] memory ex) internal pure returns (bytes memory payload) {
        assertEq(ex.length, 3, "expected pre + action + post");
        assertEq(ex[1].target, CORE_WRITER, "action must target CoreWriter");
        assertEq(ex[1].value, 0, "action must carry no value");
        bytes memory cd = ex[1].callData;
        assertEq(bytes4(cd), ICoreWriter.sendRawAction.selector, "selector");
        // strip the 4-byte selector, then abi.decode the single bytes argument
        bytes memory args = new bytes(cd.length - 4);
        for (uint256 i = 0; i < args.length; ++i) {
            args[i] = cd[i + 4];
        }
        payload = abi.decode(args, (bytes));
    }

    function _header() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(0));
    }

    /*//////////////////////////////////////////////////////////////
                    BYTE-EXACT MAINNET FIXTURES
    //////////////////////////////////////////////////////////////*/

    /// @dev Mainnet action 9: agent 0x40a5…092c, name "beat-mobile"
    function test_Fixture_AddApiWallet_MatchesMainnetBytes() public view {
        bytes memory name = bytes("beat-mobile");
        bytes memory data = abi.encodePacked(
            _header(), bytes20(0x40A5089854165d3d8Bc054CF02aDffDA28Ac092C), uint256(name.length), name
        );
        bytes memory got = _payloadOf(addAgent.build(address(0), address(this), data));
        assertEq(
            got,
            hex"01000009"
            hex"00000000000000000000000040a5089854165d3d8bc054cf02adffda28ac092c"
            hex"0000000000000000000000000000000000000000000000000000000000000040"
            hex"000000000000000000000000000000000000000000000000000000000000000b"
            hex"626561742d6d6f62696c65000000000000000000000000000000000000000000",
            "action 9 payload must match mainnet byte-for-byte"
        );
    }

    /// @dev Mainnet action 7: ntl 18,710,000 (= $18.71 at 1e6), toPerp false
    function test_Fixture_UsdClassTransfer_MatchesMainnetBytes() public view {
        bytes memory data = abi.encodePacked(_header(), uint64(18_710_000), false);
        bytes memory got = _payloadOf(classTransfer.build(address(0), address(this), data));
        assertEq(
            got,
            hex"01000007"
            hex"00000000000000000000000000000000000000000000000000000000011d7df0"
            hex"0000000000000000000000000000000000000000000000000000000000000000",
            "action 7 payload must match mainnet byte-for-byte"
        );
    }

    /// @dev Mainnet action 12: maxFeeRate 1000, builder 0xcab5…252c
    function test_Fixture_ApproveBuilderFee_MatchesMainnetBytes() public view {
        bytes memory data = abi.encodePacked(
            _header(), uint64(1000), bytes20(0xCaB561b82f58CA7104105F52e5563A83a948252C)
        );
        bytes memory got = _payloadOf(builderFee.build(address(0), address(this), data));
        assertEq(
            got,
            hex"0100000c"
            hex"00000000000000000000000000000000000000000000000000000000000003e8"
            hex"000000000000000000000000cab561b82f58ca7104105f52e5563a83a948252c",
            "action 12 payload must match mainnet byte-for-byte"
        );
    }

    /// @dev Mainnet action 13, token 0 (USDC), destination = the USDC system address.
    ///      This is the withdraw-to-HyperEVM shape.
    function test_Fixture_SendAsset_Token0_MatchesMainnetBytes() public view {
        bytes memory data = abi.encodePacked(
            _header(),
            bytes20(0x2000000000000000000000000000000000000000),
            uint64(0),
            uint64(49_317_726_300)
        );
        bytes memory got = _payloadOf(sendAsset.build(address(0), address(this), data));
        assertEq(
            got,
            hex"0100000d"
            hex"0000000000000000000000002000000000000000000000000000000000000000"
            hex"0000000000000000000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000000000000000ffffffff"
            hex"00000000000000000000000000000000000000000000000000000000ffffffff"
            hex"0000000000000000000000000000000000000000000000000000000000000000"
            hex"0000000000000000000000000000000000000000000000000000000b7b90c85c",
            "action 13 token-0 payload must match mainnet byte-for-byte"
        );
    }

    /// @dev Second fixture with a NON-ZERO token index. Without this, the token field is
    ///      indistinguishable from padding and the withdrawal leg could silently hardcode USDC.
    function test_Fixture_SendAsset_NonZeroToken_MatchesMainnetBytes() public view {
        bytes memory data = abi.encodePacked(
            _header(),
            bytes20(0x12f30684c6a92C1E7237DAAEC781377B9D71253A),
            uint64(360),
            uint64(6_778_179_200)
        );
        bytes memory got = _payloadOf(sendAsset.build(address(0), address(this), data));
        assertEq(
            got,
            hex"0100000d"
            hex"00000000000000000000000012f30684c6a92c1e7237daaec781377b9d71253a"
            hex"0000000000000000000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000000000000000ffffffff"
            hex"00000000000000000000000000000000000000000000000000000000ffffffff"
            hex"0000000000000000000000000000000000000000000000000000000000000168"
            hex"000000000000000000000000000000000000000000000000000000019402ce80",
            "action 13 non-zero-token payload must match mainnet byte-for-byte"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ENVELOPE INVARIANTS
    //////////////////////////////////////////////////////////////*/

    function test_Envelope_VersionAndActionIdPrefix() public view {
        bytes memory data = abi.encodePacked(_header(), uint64(1), false);
        bytes memory p = _payloadOf(classTransfer.build(address(0), address(this), data));
        assertEq(uint8(p[0]), 0x01, "version byte");
        assertEq(uint8(p[1]), 0x00, "action id b0");
        assertEq(uint8(p[2]), 0x00, "action id b1");
        assertEq(uint8(p[3]), 0x07, "action id b2 == 7");
    }

    /*//////////////////////////////////////////////////////////////
                    THE TWO DELIBERATE "MUST ALLOW" CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Empty agent name is the default unnamed API wallet slot, NOT an error.
    function test_AddApiWallet_AllowsEmptyName() public view {
        bytes memory data = abi.encodePacked(_header(), bytes20(address(0xBEEF)), uint256(0));
        bytes memory p = _payloadOf(addAgent.build(address(0), address(this), data));
        assertEq(uint8(p[3]), 9, "action 9");
        assertGt(p.length, 4, "payload built");
    }

    /// @dev maxFeeRate == 0 is how a builder approval is REVOKED. Must not revert.
    function test_ApproveBuilderFee_AllowsZeroRateAsRevocation() public view {
        bytes memory data = abi.encodePacked(_header(), uint64(0), bytes20(address(0xBEEF)));
        bytes memory p = _payloadOf(builderFee.build(address(0), address(this), data));
        assertEq(uint8(p[3]), 12, "action 12");
    }

    /*//////////////////////////////////////////////////////////////
                              VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_Revert_LengthNotExact() public {
        bytes memory tooLong = abi.encodePacked(_header(), uint64(1), false, bytes1(0));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        classTransfer.build(address(0), address(this), tooLong);
    }

    function test_Revert_TrailingBytesOnVariableLengthField() public {
        bytes memory name = bytes("abc");
        bytes memory padded =
            abi.encodePacked(_header(), bytes20(address(0xBEEF)), uint256(name.length), name, bytes1(0));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        addAgent.build(address(0), address(this), padded);
    }

    function test_Revert_AgentNameExceedsBound() public {
        bytes memory data = abi.encodePacked(_header(), bytes20(address(0xBEEF)), uint256(65));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        addAgent.build(address(0), address(this), data);
    }

    /// @dev A near-max length must surface the custom error, not an arithmetic panic.
    function test_Revert_AbsurdNameLengthIsCleanError() public {
        bytes memory data =
            abi.encodePacked(_header(), bytes20(address(0xBEEF)), type(uint256).max);
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        addAgent.build(address(0), address(this), data);
    }

    function test_Revert_ZeroAgent() public {
        bytes memory data = abi.encodePacked(_header(), bytes20(address(0)), uint256(0));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        addAgent.build(address(0), address(this), data);
    }

    function test_Revert_ZeroNtl() public {
        bytes memory data = abi.encodePacked(_header(), uint64(0), true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        classTransfer.build(address(0), address(this), data);
    }

    function test_Revert_FeeRateAboveCap() public {
        bytes memory data =
            abi.encodePacked(_header(), uint64(MAX_BUILDER_FEE_RATE + 1), bytes20(address(0xBEEF)));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        builderFee.build(address(0), address(this), data);
    }

    function test_Revert_SendAssetZeroDestination() public {
        bytes memory data = abi.encodePacked(_header(), bytes20(address(0)), uint64(0), uint64(1));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        sendAsset.build(address(0), address(this), data);
    }

    function test_Revert_SendAssetZeroAmount() public {
        bytes memory data = abi.encodePacked(_header(), bytes20(address(0xBEEF)), uint64(0), uint64(0));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        sendAsset.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                    S2 SIZING DECLARATION — SECURITY
    //////////////////////////////////////////////////////////////*/

    /// @dev The whole point: no rewrite function exists, so the bundler cannot resize a fee rate,
    ///      an ntl or a token index during hook chaining.
    function test_S2_DeclaresSizelessAndRefusesOutflow() public view {
        address[4] memory hooks =
            [address(addAgent), address(classTransfer), address(sendAsset), address(builderFee)];
        for (uint256 i; i < hooks.length; ++i) {
            assertTrue(
                IERC165(hooks[i]).supportsInterface(type(ISuperHookInflowOutflow).interfaceId),
                "must declare ISuperHookInflowOutflow"
            );
            assertFalse(
                IERC165(hooks[i]).supportsInterface(type(ISuperHookOutflow).interfaceId),
                "must NOT declare ISuperHookOutflow"
            );
            assertEq(
                ISuperHookInflowOutflow(hooks[i]).amountRoles("").length, 0, "authoritatively sizeless"
            );
        }
    }

    function test_Revert_ConstructorRejectsZeroCoreWriter() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new HyperCoreUsdClassTransferHook(address(0));
    }
}
