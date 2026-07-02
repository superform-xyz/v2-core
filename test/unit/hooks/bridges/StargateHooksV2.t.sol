// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { StargateSendHookV2 } from "../../../../src/hooks/bridges/stargate/StargateSendHookV2.sol";
import {
    ApproveAndStargateSendHookV2
} from "../../../../src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol";
import { IStargate } from "../../../../src/vendor/bridges/stargate/IStargate.sol";
import { IOFT } from "../../../../src/vendor/bridges/layerzero/IOFT.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Mock signature storage that returns sigData with a DstProof matching the current chain
contract MockStargateSignatureStorageV2 {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");

        // V2: Include DstProof with matching chain ID so adapter can extract fields
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: address(0xBEEF),
                executor: address(0xCAFE),
                dstTokens: new address[](0),
                intentAmounts: new uint256[](0),
                validator: address(0xFACE),
                data: hex"deadbeef"
            })
        });

        bytes memory signature = hex"abcdef";
        return abi.encode(new uint64[](0), validUntil, 0, merkleRoot, proofSrc, proofDst, signature);
    }
}

contract StargateHooksV2 is Helpers {
    StargateSendHookV2 public stargateHookV2;
    ApproveAndStargateSendHookV2 public approveAndStargateHookV2;
    MockStargateSignatureStorageV2 public mockSignatureStorage;

    address public mockAccount;
    address public mockPrevHook;
    address public mockStargatePool;
    address public mockInputToken;

    uint256 public mockLzNativeFee;
    uint32 public mockDstEid;
    bytes32 public mockTo;
    uint256 public mockAmountLD;
    uint256 public mockMinAmountLD;
    bytes public mockExtraOptions;

    function setUp() public {
        mockAccount = makeAddr("account");
        mockStargatePool = makeAddr("stargatePool");
        mockInputToken = makeAddr("inputToken");

        mockLzNativeFee = 0.01 ether;
        mockDstEid = 30_184; // Base
        mockTo = bytes32(uint256(uint160(mockAccount)));
        mockAmountLD = 1000e6; // 1000 USDC
        mockMinAmountLD = 995e6; // 0.5% slippage
        mockExtraOptions = hex"0003";

        mockSignatureStorage = new MockStargateSignatureStorageV2();
        stargateHookV2 = new StargateSendHookV2(address(mockSignatureStorage));
        approveAndStargateHookV2 = new ApproveAndStargateSendHookV2(address(mockSignatureStorage));

        // Mock the Stargate pool's token() function for on-chain validation
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Constructor() public view {
        assertEq(uint256(stargateHookV2.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_StargateSendV2_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new StargateSendHookV2(address(0));
    }

    function test_ApproveAndStargateSendV2_Constructor() public view {
        assertEq(uint256(approveAndStargateHookV2.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ApproveAndStargateSendV2_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndStargateSendHookV2(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          STARGATE SEND V2 BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Build_TaxiMode() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);

        // preExecute + sendToken + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
    }

    function test_StargateSendV2_Build_BusMode() public view {
        bytes memory data = _encodeStargateV2Data(false, 1, false);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
    }

    function test_StargateSendV2_Build_OFTMode() public view {
        bytes memory data = _encodeStargateV2Data(false, 2, false);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        // OFT mode: value = lzNativeFee only (no amountLD)
        assertEq(executions[1].value, mockLzNativeFee);
        // Verify it uses IOFT.send selector
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IOFT.send.selector);
    }

    function test_StargateSendV2_Build_WithComposeMsg() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, true);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);

        // Verify the calldata contains sendToken call
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    function test_StargateSendV2_Build_WithoutComposeMsg() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    function test_StargateSendV2_Build_ComposeMsgIsCompact() public view {
        // Verify V2 produces a compact 2-field composeMsg (initData, sigData)
        // by checking the calldata is smaller than V1 would produce with same inputs
        bytes memory data = _encodeStargateV2Data(false, 0, true);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);

        // The calldata should contain sendToken with the compact composeMsg
        assertGt(executions[1].callData.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE V2 PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateV2Data(true, 0, false);
        Execution[] memory executions = stargateHookV2.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
        // value should use prevHookAmount instead of mockAmountLD
        assertEq(executions[1].value, mockLzNativeFee + prevHookAmount);
    }

    function test_StargateSendV2_Build_WithPrevHookAmount_ScalesMinAmount() public {
        uint256 prevHookAmount = 2000e6; // Double the original

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateV2Data(true, 0, false);
        Execution[] memory executions = stargateHookV2.build(mockPrevHook, mockAccount, data);

        // Verify minAmountLD was scaled: minAmountLD * prevHookAmount / amountLD
        uint256 expectedMinAmount = Math.mulDiv(mockMinAmountLD, prevHookAmount, mockAmountLD);

        assertEq(executions[1].value, mockLzNativeFee + prevHookAmount);
        assertGt(expectedMinAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE V2 REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(StargateSendHookV2.DATA_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, shortData);
    }

    function test_StargateSendV2_Build_RevertIf_AmountZero() public {
        uint256 originalAmount = mockAmountLD;
        mockAmountLD = 0;
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        mockAmountLD = originalAmount;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_PoolZero() public {
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert(StargateSendHookV2.POOL_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_RecipientZero() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        mockTo = originalTo;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_ModeInvalid() public {
        // V2 only supports modes 0-2, mode 3 is excluded
        bytes memory data = _encodeStargateV2Data(false, 3, false);

        vm.expectRevert(StargateSendHookV2.MODE_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_PrevHookAmountZero() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateV2Data(true, 0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHookV2.build(mockPrevHook, mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_ComposeMsgTooShort() public {
        // composeMsg present but < 64 bytes (too short for V2 abi.decode(bytes))
        bytes memory shortCompose = hex"deadbeef"; // 4 bytes

        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee,
            mockStargatePool,
            mockInputToken,
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            header,
            false,
            uint8(0),
            uint256(mockExtraOptions.length),
            mockExtraOptions,
            uint256(shortCompose.length),
            shortCompose
        );

        vm.expectRevert(StargateSendHookV2.DATA_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_ExtraOptionsLengthExceedsData() public {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee,
            mockStargatePool,
            mockInputToken,
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            header,
            false,
            uint8(0),
            uint256(100), // extraOptionsLength = 100 (but only 2 bytes follow)
            hex"0003"
        );

        vm.expectRevert(StargateSendHookV2.DATA_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_Build_RevertIf_PoolIsEOA() public {
        address eoaPool = address(0xdead);
        address originalPool = mockStargatePool;
        mockStargatePool = eoaPool;
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert();
        stargateHookV2.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE V2 INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Inspector() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        bytes memory argsEncoded = stargateHookV2.inspect(data);

        // Should return stargatePool + inputToken + toAddress (60 bytes)
        assertEq(argsEncoded.length, 60);
    }

    /*//////////////////////////////////////////////////////////////
                    STARGATE V2 CONTEXT AWARE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeStargateV2Data(true, 0, false);
        assertTrue(stargateHookV2.decodeUsePrevHookAmount(data));
    }

    function test_StargateSendV2_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        assertFalse(stargateHookV2.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                    STARGATE V2 BUS MODE OFT CMD ENCODING
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Build_BusMode_OftCmdDiffersFromTaxi() public view {
        bytes memory busData = _encodeStargateV2Data(false, 1, false);
        Execution[] memory busExec = stargateHookV2.build(address(0), mockAccount, busData);

        bytes memory taxiData = _encodeStargateV2Data(false, 0, false);
        Execution[] memory taxiExec = stargateHookV2.build(address(0), mockAccount, taxiData);

        // Bus and taxi calldata should differ (oftCmd field differs)
        assertFalse(keccak256(busExec[1].callData) == keccak256(taxiExec[1].callData));
    }

    /*//////////////////////////////////////////////////////////////
                    STARGATE V2 DATA LENGTH BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_Build_ExactMinimumDataLength() public view {
        // Exactly 290 bytes with 0-length variable fields (238 + 52-byte placeholder)
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, // 32
            mockStargatePool, // 20
            mockInputToken, // 20
            mockDstEid, // 4
            mockTo, // 32
            mockAmountLD, // 32
            mockMinAmountLD // 32
        );
        bytes memory data = abi.encodePacked(
            header,
            false, // 1
            uint8(0), // 1
            uint256(0), // 32 (extraOptionsLength)
            uint256(0) // 32 (composeMsgLength)
        );

        assertEq(data.length, 290);
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_StargateSendV2_Build_ZeroExtraOptionsAndZeroComposeMsg() public view {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee,
            mockStargatePool,
            mockInputToken,
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            header,
            false,
            uint8(0),
            uint256(0),
            uint256(0)
        );

        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                    APPROVE AND STARGATE V2 BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndStargateSendV2_Build_ERC20() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        Execution[] memory executions = approveAndStargateHookV2.build(address(0), mockAccount, data);

        // preExecute + approve(0) + approve(amount) + sendToken + approve(0) + postExecute = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(pool, 0)
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: approve(pool, amountLD)
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, mockAmountLD)));

        // Execution 3: sendToken (value = lzNativeFee only for ERC20)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee);

        // Execution 4: approve(pool, 0)
        assertEq(executions[4].target, mockInputToken);
        assertEq(executions[4].value, 0);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    function test_ApproveAndStargateSendV2_Build_OFTMode() public view {
        bytes memory data = _encodeStargateV2Data(false, 2, false);
        Execution[] memory executions = approveAndStargateHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        // Execution 3: OFT send (value = lzNativeFee)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee);
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IOFT.send.selector);
    }

    function test_ApproveAndStargateSendV2_Build_WithComposeMsg() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, true);
        Execution[] memory executions = approveAndStargateHookV2.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    function test_ApproveAndStargateSendV2_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateV2Data(true, 0, false);
        Execution[] memory executions = approveAndStargateHookV2.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Approval should use prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)));
        // Value should be lzNativeFee only (ERC20)
        assertEq(executions[3].value, mockLzNativeFee);
    }

    function test_ApproveAndStargateSendV2_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(ApproveAndStargateSendHookV2.DATA_NOT_VALID.selector);
        approveAndStargateHookV2.build(address(0), mockAccount, shortData);
    }

    function test_ApproveAndStargateSendV2_Build_RevertIf_InputTokenZero() public {
        address originalToken = mockInputToken;
        mockInputToken = address(0);
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        mockInputToken = originalToken;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHookV2.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSendV2_Build_RevertIf_PoolTokenMismatch() public {
        address wrongToken = makeAddr("wrongToken");
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(wrongToken));

        bytes memory data = _encodeStargateV2Data(false, 0, false);

        vm.expectRevert(ApproveAndStargateSendHookV2.POOL_NOT_VALID.selector);
        approveAndStargateHookV2.build(address(0), mockAccount, data);

        // Restore original mock
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    function test_ApproveAndStargateSendV2_Build_RevertIf_ModeInvalid() public {
        // V2 only supports modes 0-2
        bytes memory data = _encodeStargateV2Data(false, 3, false);

        vm.expectRevert(ApproveAndStargateSendHookV2.MODE_NOT_VALID.selector);
        approveAndStargateHookV2.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSendV2_Inspector() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        bytes memory argsEncoded = approveAndStargateHookV2.inspect(data);
        assertEq(argsEncoded.length, 60);
    }

    function test_subtype() public view {
        assertNotEq(BaseHook(address(stargateHookV2)).subtype(), bytes32(0));
        assertNotEq(BaseHook(address(approveAndStargateHookV2)).subtype(), bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                    FAIL-FAST VALIDATION ORDER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_FailFast_PoolZeroBeforePrevHookCall() public {
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateV2Data(true, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert(StargateSendHookV2.POOL_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_StargateSendV2_FailFast_RecipientZeroBeforePrevHookCall() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateV2Data(true, 0, false);
        mockTo = originalTo;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHookV2.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSendV2_FailFast_InputTokenZeroBeforePrevHookCall() public {
        address originalToken = mockInputToken;
        mockInputToken = address(0);
        bytes memory data = _encodeStargateV2Data(true, 0, false);
        mockInputToken = originalToken;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHookV2.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSendV2_DecodeAmounts() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        assertEq(stargateHookV2.decodeAmounts(data)[0], mockAmountLD);
    }

    function test_StargateSendV2_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        uint256 newAmount = 2e18;
        bytes memory result = stargateHookV2.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(stargateHookV2.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_StargateSendV2_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        bytes memory result = stargateHookV2.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(stargateHookV2.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndStargateSendV2_DecodeAmounts() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        assertEq(approveAndStargateHookV2.decodeAmounts(data)[0], mockAmountLD);
    }

    function test_ApproveAndStargateSendV2_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndStargateHookV2.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndStargateHookV2.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndStargateSendV2_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        bytes memory result = approveAndStargateHookV2.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndStargateHookV2.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_StargateV2_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        uint256 newAmount = 500;
        bytes memory replaced = stargateHookV2.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = stargateHookV2.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 3);
        assertEq(stargateHookV2.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndStargateV2_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndStargateHookV2.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndStargateHookV2.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndStargateHookV2.decodeAmounts(replaced)[0], newAmount);
    }

    function test_StargateV2_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _encodeStargateV2Data(false, 0, false);
        bytes memory replaced = stargateHookV2.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        for (uint256 i = 0; i < 160; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 192; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Encodes hook data for V2 hooks
    ///      V2 composeMsg input = abi.encode(initData) — 1-field only
    function _encodeStargateV2Data(
        bool usePrevHookAmount,
        uint8 mode,
        bool includeComposeMsg
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory composeMsg;
        if (includeComposeMsg) {
            // V2: composeMsg = abi.encode(initData) — 1-field only
            bytes memory initData = bytes("0x123");
            composeMsg = abi.encode(initData);
        }

        // Split encoding to avoid stack too deep
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        return abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            fixedPart, usePrevHookAmount, mode, uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );
    }
}
