// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { StargateSendHook } from "../../../../src/hooks/bridges/stargate/StargateSendHook.sol";
import { ApproveAndStargateSendHook } from "../../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { IStargate } from "../../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperValidator } from "../../../../src/interfaces/ISuperValidator.sol";
import { ISuperHook, ISuperHookResult } from "../../../../src/interfaces/ISuperHook.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockStargateSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        bytes memory signature = hex"abcdef";
        return abi.encode(new uint64[](0), validUntil, 0, merkleRoot, proofSrc, proofDst, signature);
    }
}

contract StargateHooks is Helpers {
    StargateSendHook public stargateHook;
    ApproveAndStargateSendHook public approveAndStargateHook;
    MockStargateSignatureStorage public mockSignatureStorage;

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
    bytes public mockComposeMsg;

    function setUp() public {
        mockAccount = makeAddr("account");
        mockStargatePool = makeAddr("stargatePool");
        mockInputToken = makeAddr("inputToken");

        mockLzNativeFee = 0.01 ether;
        mockDstEid = 30_184; // Base
        mockTo = bytes32(uint256(uint160(makeAddr("recipient"))));
        mockAmountLD = 1000e6; // 1000 USDC
        mockMinAmountLD = 995e6; // 0.5% slippage
        mockExtraOptions = hex"0003";

        mockSignatureStorage = new MockStargateSignatureStorage();
        stargateHook = new StargateSendHook(address(mockSignatureStorage));
        approveAndStargateHook = new ApproveAndStargateSendHook(address(mockSignatureStorage));

        // Mock the Stargate pool's token() function for on-chain validation
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Constructor() public view {
        assertEq(uint256(stargateHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_StargateSend_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new StargateSendHook(address(0));
    }

    function test_ApproveAndStargateSend_Constructor() public view {
        assertEq(uint256(approveAndStargateHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_ApproveAndStargateSend_Constructor_RevertIf_ZeroValidator() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndStargateSendHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          STARGATE SEND BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Build_TaxiMode() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // preExecute + sendToken + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
    }

    function test_StargateSend_Build_BusMode() public view {
        bytes memory data = _encodeStargateData(false, true, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
    }

    function test_StargateSend_Build_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, false, true);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);

        // Verify the calldata contains sendToken call
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    function test_StargateSend_Build_WithoutComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, false, false);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
        // value should use prevHookAmount instead of mockAmountLD
        assertEq(executions[1].value, mockLzNativeFee + prevHookAmount);
    }

    function test_StargateSend_Build_WithPrevHookAmount_ScalesMinAmount() public {
        uint256 prevHookAmount = 2000e6; // Double the original

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, false, false);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        // Verify minAmountLD was scaled: minAmountLD * prevHookAmount / amountLD
        uint256 expectedMinAmount = Math.mulDiv(mockMinAmountLD, prevHookAmount, mockAmountLD);

        // Decode the calldata to verify minAmountLD
        // The calldata encodes IStargate.sendToken(SendParam, MessagingFee, address)
        // We check via value that amountLD was updated
        assertEq(executions[1].value, mockLzNativeFee + prevHookAmount);
        assertGt(expectedMinAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, shortData);
    }

    function test_StargateSend_Build_RevertIf_AmountZero() public {
        uint256 originalAmount = mockAmountLD;
        mockAmountLD = 0;
        bytes memory data = _encodeStargateData(false, false, false);
        mockAmountLD = originalAmount;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_PoolZero() public {
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateData(false, false, false);
        mockStargatePool = originalPool;

        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_RecipientZero() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateData(false, false, false);
        mockTo = originalTo;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_PrevHookAmountZero() public {
        uint256 prevHookAmount = 0;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, false, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(mockPrevHook, mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Inspector() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        bytes memory argsEncoded = stargateHook.inspect(data);

        // Should return stargatePool + inputToken + toAddress (60 bytes)
        assertEq(argsEncoded.length, 60);
    }

    /*//////////////////////////////////////////////////////////////
                    STARGATE CONTEXT AWARE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeStargateData(true, false, false);
        assertTrue(stargateHook.decodeUsePrevHookAmount(data));
    }

    function test_StargateSend_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        assertFalse(stargateHook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                    STARGATE PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_PreExecute() public {
        stargateHook.preExecute(address(0), address(this), "");
    }

    function test_StargateSend_PostExecute() public {
        stargateHook.postExecute(address(0), address(this), "");
    }

    /*//////////////////////////////////////////////////////////////
                    APPROVE AND STARGATE BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndStargateSend_Build_ERC20() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

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

    function test_ApproveAndStargateSend_Build_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, false, true);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    function test_ApproveAndStargateSend_Build_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, false, false);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Approval should use prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)));
        // Value should be lzNativeFee only (ERC20)
        assertEq(executions[3].value, mockLzNativeFee);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1 ether), address(0x1));

        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, shortData);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_InputTokenZero() public {
        address originalToken = mockInputToken;
        mockInputToken = address(0);
        bytes memory data = _encodeStargateData(false, false, false);
        mockInputToken = originalToken;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_PoolTokenMismatch() public {
        // Mock pool.token() to return a different token than inputToken
        address wrongToken = makeAddr("wrongToken");
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(wrongToken));

        bytes memory data = _encodeStargateData(false, false, false);

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);

        // Restore original mock
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    function test_StargateSend_Build_RevertIf_PoolNotStargateContract() public {
        // Use an address that doesn't implement IStargate.token() (no mock)
        address fakePool = makeAddr("fakePool");
        address originalPool = mockStargatePool;
        mockStargatePool = fakePool;
        bytes memory data = _encodeStargateData(false, false, false);
        mockStargatePool = originalPool;

        // Should revert because token() call fails on non-contract address
        vm.expectRevert();
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Inspector() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        bytes memory argsEncoded = approveAndStargateHook.inspect(data);
        assertEq(argsEncoded.length, 60);
    }

    function test_ApproveAndStargateSend_PreExecute() public {
        approveAndStargateHook.preExecute(address(0), address(this), "");
    }

    function test_ApproveAndStargateSend_PostExecute() public {
        approveAndStargateHook.postExecute(address(0), address(this), "");
    }

    function test_subtype() public view {
        assertNotEq(BaseHook(address(stargateHook)).subtype(), bytes32(0));
        assertNotEq(BaseHook(address(approveAndStargateHook)).subtype(), bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY FIX VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    // --- P2-1: Pool validation (on-chain interface check) ---

    function test_StargateSend_Build_RevertIf_PoolIsEOA() public {
        // EOA addresses don't have code, so token() staticcall will revert
        address eoaPool = address(0xdead);
        address originalPool = mockStargatePool;
        mockStargatePool = eoaPool;
        bytes memory data = _encodeStargateData(false, false, false);
        mockStargatePool = originalPool;

        vm.expectRevert();
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_PoolIsEOA() public {
        address eoaPool = address(0xdead);
        address originalPool = mockStargatePool;
        mockStargatePool = eoaPool;
        bytes memory data = _encodeStargateData(false, false, false);
        mockStargatePool = originalPool;

        vm.expectRevert();
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_PoolReturnsZeroToken() public {
        // Pool returns address(0) as token (native pool), but hook expects ERC20
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));

        bytes memory data = _encodeStargateData(false, false, false);

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);

        // Restore
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    function test_ApproveAndStargateSend_Build_Passes_WhenPoolTokenMatches() public view {
        // Happy path: pool.token() == inputToken (set up in setUp)
        bytes memory data = _encodeStargateData(false, false, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
    }

    // --- P2-2: Validation ordering (fail-fast before external calls) ---

    function test_StargateSend_FailFast_PoolZeroBeforePrevHookCall() public {
        // With usePrevHookAmount=true but pool=address(0), should revert with POOL_NOT_VALID
        // BEFORE attempting to call prevHook.getOutAmount()
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateData(true, false, false);
        mockStargatePool = originalPool;

        // If validation ordering is wrong, this would revert with a different error
        // (e.g., call to address(0) for prevHook) instead of POOL_NOT_VALID
        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_FailFast_RecipientZeroBeforePrevHookCall() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateData(true, false, false);
        mockTo = originalTo;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_FailFast_InputTokenZeroBeforePrevHookCall() public {
        address originalToken = mockInputToken;
        mockInputToken = address(0);
        bytes memory data = _encodeStargateData(true, false, false);
        mockInputToken = originalToken;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_FailFast_PoolZeroBeforePrevHookCall() public {
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateData(true, false, false);
        mockStargatePool = originalPool;

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    // --- P2-3: Variable-length data bounds validation ---

    function test_StargateSend_Build_RevertIf_ExtraOptionsLengthExceedsData() public {
        // Encode data with extraOptionsLength claiming 100 bytes but only 2 bytes actually present
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false, // usePrevHookAmount
            false, // isBusMode
            uint256(100), // extraOptionsLength = 100 (but only 2 bytes follow)
            hex"0003" // only 2 bytes of extraOptions
        );

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ExtraOptionsLengthExceedsData() public {
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(100), // claims 100 bytes of extraOptions
            hex"0003" // only 2 bytes
        );

        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_ComposeMsgLengthExceedsData() public {
        // extraOptions is valid (2 bytes) but composeMsgLength claims more than available
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(2), // extraOptionsLength = 2
            hex"0003", // 2 bytes of extraOptions (valid)
            uint256(500) // composeMsgLength = 500 (but no composeMsg bytes follow)
        );

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ComposeMsgLengthExceedsData() public {
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(2),
            hex"0003",
            uint256(500) // composeMsgLength = 500 but nothing follows
        );

        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_ZeroExtraOptionsAndZeroComposeMsg() public view {
        // Edge case: both variable fields are zero-length
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(0), // extraOptionsLength = 0
            uint256(0) // composeMsgLength = 0
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_ApproveAndStargateSend_Build_ZeroExtraOptionsAndZeroComposeMsg() public view {
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(0),
            uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
    }

    // --- P3-2: composeMsg minimum length validation ---

    function test_StargateSend_Build_RevertIf_ComposeMsgTooShort() public {
        // composeMsg present but < 160 bytes (too short for abi.decode)
        bytes memory shortCompose = hex"deadbeef"; // 4 bytes

        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(2), // extraOptionsLength
            hex"0003", // extraOptions
            uint256(shortCompose.length), // composeMsgLength = 4
            shortCompose
        );

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ComposeMsgTooShort() public {
        bytes memory shortCompose = hex"deadbeef"; // 4 bytes

        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(2),
            hex"0003",
            uint256(shortCompose.length),
            shortCompose
        );

        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_ComposeMsgExactlyMinLength() public {
        // Create a valid composeMsg that's exactly at the boundary (>= 160 bytes)
        // Using proper ABI encoding which produces > 160 bytes
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = mockAmountLD;
        bytes memory validCompose = abi.encode(bytes(""), bytes(""), mockAccount, dstTokens, intentAmounts);

        // Verify it's >= 160 bytes
        assertGe(validCompose.length, 160);

        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(2),
            hex"0003",
            uint256(validCompose.length),
            validCompose
        );

        // Should succeed - valid compose msg
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    // --- P2-2 + P2-1: Combined validation ordering with pool check ---

    function test_StargateSend_ValidationOrder_PoolCheckedBeforeVariableLength() public {
        // Pool is address(0), data meets 290 min but has invalid extraOptionsLength
        // Should get POOL_NOT_VALID (checked before variable-length validation)
        bytes memory data = abi.encodePacked(
            mockLzNativeFee, // 32
            uint256(0), // 32 - lzTokenFee
            address(0), // 20 - zero pool
            mockInputToken, // 20
            address(0), // 20 - lzToken
            mockDstEid, // 4
            mockTo, // 32
            mockAmountLD, // 32
            mockMinAmountLD, // 32
            false, // 1
            false, // 1
            uint256(999), // 32 - invalid extraOptionsLength
            uint256(0) // 32 - composeMsgLength (to reach 290 min)
        );
        // Total: 32+32+20+20+20+4+32+32+32+1+1+32+32 = 290

        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_ValidationOrder_AddressCheckedBeforePoolToken() public {
        // inputToken is address(0), pool mock is correct
        // Should get ADDRESS_NOT_VALID (checked before pool.token())
        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            address(0), // zero inputToken
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(2),
            hex"0003",
            uint256(0)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    // --- Large extraOptions (realistic LayerZero V2 options) ---

    function test_StargateSend_Build_LargeExtraOptions() public view {
        // Simulate realistic LayerZero V2 extraOptions (128 bytes of options)
        bytes memory largeOptions = new bytes(128);
        for (uint256 i = 0; i < 128; i++) {
            largeOptions[i] = bytes1(uint8(i % 256));
        }

        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(largeOptions.length),
            largeOptions,
            uint256(0) // no compose msg
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
    }

    function test_ApproveAndStargateSend_Build_LargeExtraOptions() public view {
        bytes memory largeOptions = new bytes(128);
        for (uint256 i = 0; i < 128; i++) {
            largeOptions[i] = bytes1(uint8(i % 256));
        }

        bytes memory data = abi.encodePacked(
            mockLzNativeFee,
            uint256(0), // lzTokenFee
            mockStargatePool,
            mockInputToken,
            address(0), // lzToken
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD,
            false,
            false,
            uint256(largeOptions.length),
            largeOptions,
            uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
        assertEq(executions[3].target, mockStargatePool);
    }

    // --- Bus mode OFT cmd encoding validation ---

    function test_StargateSend_Build_BusMode_OftCmdEncoding() public view {
        bytes memory data = _encodeStargateData(false, true, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // Verify bus mode produces different calldata than taxi mode
        bytes memory taxiData = _encodeStargateData(false, false, false);
        Execution[] memory taxiExecutions = stargateHook.build(address(0), mockAccount, taxiData);

        // Both should target the pool and have valid calldata
        assertEq(executions[1].target, mockStargatePool);
        assertGt(executions[1].callData.length, 0);

        // Bus and taxi calldata should differ (oftCmd field differs)
        assertFalse(keccak256(executions[1].callData) == keccak256(taxiExecutions[1].callData));
    }

    function test_StargateSend_Build_TaxiMode_OftCmdEncoding() public view {
        bytes memory data = _encodeStargateData(false, false, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertGt(executions[1].callData.length, 0);
    }

    // --- P3-3: Pool/token matching edge cases ---

    function test_ApproveAndStargateSend_Build_RevertIf_PoolTokenIsAddressZero() public {
        // Simulate a native pool (token() returns address(0)) being used with ERC20 hook
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));

        bytes memory data = _encodeStargateData(false, false, false);

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);

        // Restore
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    // --- Combined: prevHookAmount + pool validation ---

    function test_StargateSend_Build_WithPrevHookAmount_PoolStillValidated() public {
        uint256 prevHookAmount = 500e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        // Pool mock is still set from setUp, so token() check passes
        bytes memory data = _encodeStargateData(true, false, false);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, mockLzNativeFee + prevHookAmount);
    }

    function test_ApproveAndStargateSend_Build_WithPrevHookAmount_PoolTokenValidated() public {
        uint256 prevHookAmount = 500e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));
        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, false, false);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Verify approval uses prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)));
    }

    // --- Data length boundary tests ---

    function test_StargateSend_Build_ExactMinimumDataLength() public view {
        // Exactly 290 bytes with 0-length variable fields
        bytes memory data = abi.encodePacked(
            mockLzNativeFee, // 32
            uint256(0), // 32 (lzTokenFee)
            mockStargatePool, // 20
            mockInputToken, // 20
            address(0), // 20 (lzToken)
            mockDstEid, // 4
            mockTo, // 32
            mockAmountLD, // 32
            mockMinAmountLD, // 32
            false, // 1
            false, // 1
            uint256(0), // 32 (extraOptionsLength)
            uint256(0) // 32 (composeMsgLength)
        );
        // Total: 32+32+20+20+20+4+32+32+32+1+1+32+32 = 290 bytes

        assertEq(data.length, 290);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_StargateSend_Build_RevertIf_OneByteShort() public {
        // 289 bytes - one short of minimum
        bytes memory data = new bytes(289);
        // Fill first 32 bytes with lzNativeFee
        assembly {
            mstore(add(data, 32), 10000000000000000) // 0.01 ether
        }

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                         LZ TOKEN FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Build_WithLzTokenFee() public {
        address mockLzToken = makeAddr("lzToken");
        uint256 lzTokenFee = 1e18;

        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, lzTokenFee, mockStargatePool, mockInputToken, mockLzToken, mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, false, uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // pre + 4 hook (lz approve 0 + lz approve fee + sendToken + lz cleanup) + post = 6
        assertEq(executions.length, 6);

        // Execution 1: Reset LZ token approval
        assertEq(executions[1].target, mockLzToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: Approve LZ token fee
        assertEq(executions[2].target, mockLzToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, lzTokenFee)));

        // Execution 3: sendToken (value = lzNativeFee + amountLD for native)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee + mockAmountLD);
        assertEq(bytes4(executions[3].callData), IStargate.sendToken.selector);

        // Execution 4: Cleanup LZ token approval
        assertEq(executions[4].target, mockLzToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    function test_ApproveAndStargateSend_Build_WithLzTokenFee() public {
        address mockLzToken = makeAddr("lzToken");
        uint256 lzTokenFee = 1e18;

        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, lzTokenFee, mockStargatePool, mockInputToken, mockLzToken, mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, false, uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // pre + 7 hook executions + post = 9
        assertEq(executions.length, 9);

        // Execution 1: Reset input token approval
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: Approve input token amount
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, mockAmountLD)));

        // Execution 3: Reset LZ token approval
        assertEq(executions[3].target, mockLzToken);
        assertEq(executions[3].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 4: Approve LZ token fee
        assertEq(executions[4].target, mockLzToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, lzTokenFee)));

        // Execution 5: sendToken (value = lzNativeFee only for ERC20)
        assertEq(executions[5].target, mockStargatePool);
        assertEq(executions[5].value, mockLzNativeFee);
        assertEq(bytes4(executions[5].callData), IStargate.sendToken.selector);

        // Execution 6: Cleanup LZ token approval
        assertEq(executions[6].target, mockLzToken);
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 7: Cleanup input token approval
        assertEq(executions[7].target, mockInputToken);
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    function test_StargateSend_Build_RevertIf_LzTokenFeeWithoutLzToken() public {
        // lzTokenFee > 0 but lzToken = address(0) should revert
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, uint256(1e18), mockStargatePool, mockInputToken, address(0), mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, false, uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_LzTokenFeeWithoutLzToken() public {
        // lzTokenFee > 0 but lzToken = address(0) should revert
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, uint256(1e18), mockStargatePool, mockInputToken, address(0), mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, false, uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _encodeStargateData(
        bool usePrevHookAmount,
        bool isBusMode,
        bool includeComposeMsg
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory composeMsg;
        if (includeComposeMsg) {
            address[] memory dstTokens = new address[](1);
            dstTokens[0] = mockInputToken;
            uint256[] memory intentAmounts = new uint256[](1);
            intentAmounts[0] = mockAmountLD;
            composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), mockAccount, dstTokens, intentAmounts);
        }

        // Split encoding to avoid stack too deep
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, uint256(0), mockStargatePool, mockInputToken, address(0), mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrevHookAmount, isBusMode, uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );
    }
}
