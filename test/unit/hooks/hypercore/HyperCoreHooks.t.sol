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
    /// @dev decibps — tenths of a basis point. 10 == 1bp, so 100 == 0.1% (perp max), 1000 == 1% (spot max).
    uint64 internal constant MAX_FEE_PERPS = 100;
    uint64 internal constant MAX_FEE_SPOT = 1000;

    HyperCoreAddApiWalletHook internal addAgent;
    HyperCoreUsdClassTransferHook internal classTransfer;
    HyperCoreSendAssetHook internal sendAsset;
    HyperCoreApproveBuilderFeeHook internal builderFee;
    HyperCoreApproveBuilderFeeHook internal builderFeeSpot;

    function setUp() public {
        addAgent = new HyperCoreAddApiWalletHook(CORE_WRITER);
        classTransfer = new HyperCoreUsdClassTransferHook(CORE_WRITER);
        sendAsset = new HyperCoreSendAssetHook(CORE_WRITER);
        builderFee = new HyperCoreApproveBuilderFeeHook(CORE_WRITER, MAX_FEE_PERPS);
        builderFeeSpot = new HyperCoreApproveBuilderFeeHook(CORE_WRITER, MAX_FEE_SPOT);
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
            hex"01000009" hex"00000000000000000000000040a5089854165d3d8bc054cf02adffda28ac092c"
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
            hex"01000007" hex"00000000000000000000000000000000000000000000000000000000011d7df0"
            hex"0000000000000000000000000000000000000000000000000000000000000000",
            "action 7 payload must match mainnet byte-for-byte"
        );
    }

    /// @dev Mainnet action 12: maxFeeRate 1000, builder 0xcab5…252c.
    ///      1000 decibps is 1% — the SPOT maximum, not the perp one — so this fixture is built
    ///      against a spot-capped instance. That the observed mainnet value is spot-legal rather
    ///      than perp-legal is the whole reason the perps cap is 100.
    function test_Fixture_ApproveBuilderFee_MatchesMainnetBytes() public view {
        bytes memory data =
            abi.encodePacked(_header(), uint64(1000), bytes20(0xCaB561b82f58CA7104105F52e5563A83a948252C));
        bytes memory got = _payloadOf(builderFeeSpot.build(address(0), address(this), data));
        assertEq(
            got,
            hex"0100000c" hex"00000000000000000000000000000000000000000000000000000000000003e8"
            hex"000000000000000000000000cab561b82f58ca7104105f52e5563a83a948252c",
            "action 12 payload must match mainnet byte-for-byte"
        );
    }

    /// @dev Mainnet action 13, token 0 (USDC), destination = the USDC system address.
    ///      This is the withdraw-to-HyperEVM shape.
    function test_Fixture_SendAsset_Token0_MatchesMainnetBytes() public view {
        bytes memory data = abi.encodePacked(
            _header(), bytes20(0x2000000000000000000000000000000000000000), uint64(0), uint64(49_317_726_300)
        );
        bytes memory got = _payloadOf(sendAsset.build(address(0), address(this), data));
        assertEq(
            got,
            hex"0100000d" hex"0000000000000000000000002000000000000000000000000000000000000000"
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
            _header(), bytes20(0x12f30684c6a92C1E7237DAAEC781377B9D71253A), uint64(360), uint64(6_778_179_200)
        );
        bytes memory got = _payloadOf(sendAsset.build(address(0), address(this), data));
        assertEq(
            got,
            hex"0100000d" hex"00000000000000000000000012f30684c6a92c1e7237daaec781377b9d71253a"
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
        bytes memory data = abi.encodePacked(_header(), bytes20(address(0xBEEF)), type(uint256).max);
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
        bytes memory data = abi.encodePacked(_header(), uint64(MAX_FEE_PERPS + 1), bytes20(address(0xBEEF)));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        builderFee.build(address(0), address(this), data);
    }

    /// @dev Regression guard for a real bug: the cap was originally set to 1000 on the belief that
    ///      1000 == 0.1%. It is 1% — the spot maximum — so a perps deployment would have admitted
    ///      approvals 10x over the protocol limit. CoreWriter never reverts, so HyperCore would have
    ///      silently dropped them behind a successful EVM receipt.
    function test_Revert_PerpsCapRejectsTheSpotMaximum() public {
        bytes memory data = abi.encodePacked(_header(), MAX_FEE_SPOT, bytes20(address(0xBEEF)));
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        builderFee.build(address(0), address(this), data);
    }

    /// @dev 0.1% expressed correctly must be accepted at the perps cap.
    function test_ApproveBuilderFee_AcceptsPerpMaximum() public view {
        bytes memory data = abi.encodePacked(_header(), MAX_FEE_PERPS, bytes20(address(0xBEEF)));
        bytes memory p = _payloadOf(builderFee.build(address(0), address(this), data));
        assertEq(uint8(p[3]), 12, "action 12");
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

    /// @dev Sending token Y to token X's system address strands the balance permanently behind a
    ///      green receipt — CoreWriter cannot revert — so the pairing is enforced on-chain.
    function test_Revert_SendAssetSystemAddressTokenMismatch() public {
        // USDC's system address (index 0) paired with a non-zero token index
        bytes memory data =
            abi.encodePacked(_header(), bytes20(0x2000000000000000000000000000000000000000), uint64(360), uint64(1));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        sendAsset.build(address(0), address(this), data);
    }

    /// @dev A 0x20…-band destination whose low bytes equal the token index is the legitimate
    ///      withdrawal shape and must pass for a non-zero index too.
    function test_SendAsset_AllowsMatchingSystemAddress() public view {
        // 0x20… ‖ 197 (UBTC) built numerically — top byte 0x20, low bytes = token index
        bytes20 ubtcSystemAddress = bytes20(uint160((uint160(0x20) << 152) | uint160(197)));
        bytes memory data = abi.encodePacked(_header(), ubtcSystemAddress, uint64(197), uint64(1));
        bytes memory p = _payloadOf(sendAsset.build(address(0), address(this), data));
        assertEq(uint8(p[3]), 13, "action 13");
    }

    /// @dev HYPE's system address (0x2222…2222) is a documented exception OUTSIDE the 0x20… band
    ///      and must pass through as an ordinary destination regardless of token index.
    function test_SendAsset_AllowsHypeSystemAddressOutsideBand() public view {
        bytes memory data =
            abi.encodePacked(_header(), bytes20(0x2222222222222222222222222222222222222222), uint64(150), uint64(1));
        bytes memory p = _payloadOf(sendAsset.build(address(0), address(this), data));
        assertEq(uint8(p[3]), 13, "action 13");
    }

    /*//////////////////////////////////////////////////////////////
                    S2 SIZING DECLARATION — SECURITY
    //////////////////////////////////////////////////////////////*/

    /// @dev The whole point: no rewrite function exists, so the bundler cannot resize a fee rate,
    ///      an ntl or a token index during hook chaining.
    function test_S2_DeclaresSizelessAndRefusesOutflow() public view {
        address[4] memory hooks = [address(addAgent), address(classTransfer), address(sendAsset), address(builderFee)];
        for (uint256 i; i < hooks.length; ++i) {
            assertTrue(
                IERC165(hooks[i]).supportsInterface(type(ISuperHookInflowOutflow).interfaceId),
                "must declare ISuperHookInflowOutflow"
            );
            assertFalse(
                IERC165(hooks[i]).supportsInterface(type(ISuperHookOutflow).interfaceId),
                "must NOT declare ISuperHookOutflow"
            );
            assertEq(ISuperHookInflowOutflow(hooks[i]).amountRoles("").length, 0, "authoritatively sizeless");
            assertEq(ISuperHookInflowOutflow(hooks[i]).decodeAmounts("").length, 0, "no decodable amounts");
        }
    }

    function test_Revert_ConstructorRejectsZeroCoreWriter() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new HyperCoreUsdClassTransferHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    REMAINING VALIDATION BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_Revert_ZeroBuilder() public {
        bytes memory data = abi.encodePacked(_header(), uint64(50), bytes20(address(0)));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        builderFee.build(address(0), address(this), data);
    }

    /// @dev A zero cap would make every approval impossible — reject it at deployment.
    function test_Revert_ConstructorRejectsZeroFeeCap() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        new HyperCoreApproveBuilderFeeHook(CORE_WRITER, 0);
    }

    function test_Revert_SendAssetLengthNotExact() public {
        bytes memory tooShort = abi.encodePacked(_header(), bytes20(address(0xBEEF)), uint64(0));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        sendAsset.build(address(0), address(this), tooShort);

        bytes memory tooLong = abi.encodePacked(_header(), bytes20(address(0xBEEF)), uint64(0), uint64(1), bytes1(0));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        sendAsset.build(address(0), address(this), tooLong);
    }

    function test_Revert_ApproveBuilderFeeLengthNotExact() public {
        bytes memory tooShort = abi.encodePacked(_header(), uint64(50));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        builderFee.build(address(0), address(this), tooShort);

        bytes memory tooLong = abi.encodePacked(_header(), uint64(50), bytes20(address(0xBEEF)), bytes1(0));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        builderFee.build(address(0), address(this), tooLong);
    }

    function test_Revert_AddApiWalletDataTooShort() public {
        bytes memory tooShort = abi.encodePacked(_header(), bytes20(address(0xBEEF)));
        vm.expectRevert(BaseHyperCoreWriterHook.DATA_NOT_VALID.selector);
        addAgent.build(address(0), address(this), tooShort);
    }

    /*//////////////////////////////////////////////////////////////
                    PASSTHROUGH PIPE MODE
    //////////////////////////////////////////////////////////////*/

    /// @dev CoreWriter actions produce nothing EVM-observable, so the accounting design leans on
    ///      PASSTHROUGH: preExecute must forward the previous hook's outAmount and outToken, and
    ///      postExecute must leave them untouched.
    function test_Passthrough_ForwardsPrevHookOutput() public {
        PrevHookStub prev = new PrevHookStub(1234, address(0xCAFE));
        bytes memory data = abi.encodePacked(_header(), uint64(1), true);

        classTransfer.preExecute(address(prev), address(this), data);
        assertEq(classTransfer.getOutAmount(address(this)), 1234, "outAmount must forward from prevHook");
        assertEq(classTransfer.getOutToken(address(this)), address(0xCAFE), "outToken must forward from prevHook");

        classTransfer.postExecute(address(prev), address(this), data);
        assertEq(classTransfer.getOutAmount(address(this)), 1234, "postExecute must not change outAmount");
        assertEq(classTransfer.getOutToken(address(this)), address(0xCAFE), "postExecute must not change outToken");
    }

    /// @dev First hook in a chain: nothing to forward, values stay zero, no revert.
    function test_Passthrough_NoPrevHookIsNoop() public {
        bytes memory data = abi.encodePacked(_header(), uint64(1), true);
        classTransfer.preExecute(address(0), address(this), data);
        assertEq(classTransfer.getOutAmount(address(this)), 0, "nothing to forward");
        assertEq(classTransfer.getOutToken(address(this)), address(0), "nothing to forward");
    }

    /*//////////////////////////////////////////////////////////////
                              INSPECT
    //////////////////////////////////////////////////////////////*/

    /// @dev inspect() feeds sign-time tooling and must surface exactly the addresses a user needs
    ///      to see before signing — packed, addresses only.
    function test_Inspect_AllLeaves() public view {
        address agent = address(0xA9E27);
        bytes memory addData = abi.encodePacked(_header(), bytes20(agent), uint256(0));
        assertEq(addAgent.inspect(addData), abi.encodePacked(CORE_WRITER, agent), "addAgent: coreWriter + agent");

        bytes memory ctData = abi.encodePacked(_header(), uint64(1), true);
        assertEq(classTransfer.inspect(ctData), abi.encodePacked(CORE_WRITER), "classTransfer: coreWriter only");

        address destination = address(0xDE57);
        bytes memory saData = abi.encodePacked(_header(), bytes20(destination), uint64(0), uint64(1));
        assertEq(
            sendAsset.inspect(saData), abi.encodePacked(CORE_WRITER, destination), "sendAsset: coreWriter + destination"
        );

        address builder = address(0xB111DE2);
        bytes memory bfData = abi.encodePacked(_header(), uint64(50), bytes20(builder));
        assertEq(builderFee.inspect(bfData), abi.encodePacked(CORE_WRITER, builder), "builderFee: coreWriter + builder");
    }
}

/// @dev Minimal previous-hook stub: MockHook hardcodes getOutToken to address(0), which would make
///      the outToken-forwarding assertion vacuous.
contract PrevHookStub {
    uint256 internal immutable AMOUNT;
    address internal immutable TOKEN;

    constructor(uint256 amount_, address token_) {
        AMOUNT = amount_;
        TOKEN = token_;
    }

    function getOutAmount(address) external view returns (uint256) {
        return AMOUNT;
    }

    function getOutToken(address) external view returns (address) {
        return TOKEN;
    }
}
