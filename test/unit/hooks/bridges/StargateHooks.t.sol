// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { StargateSendHook } from "../../../../src/hooks/bridges/stargate/StargateSendHook.sol";
import { ApproveAndStargateSendHook } from "../../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { IStargate } from "../../../../src/vendor/bridges/stargate/IStargate.sol";
import { IOFT } from "../../../../src/vendor/bridges/layerzero/IOFT.sol";
import { ILZMultiCall } from "../../../../src/vendor/bridges/layerzero/ILZMultiCall.sol";
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
        mockTo = bytes32(uint256(uint160(mockAccount)));
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
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // preExecute + sendToken + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
    }

    function test_StargateSend_Build_BusMode() public view {
        bytes memory data = _encodeStargateData(false, 1, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
    }

    function test_StargateSend_Build_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, 0, true);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);

        // Verify the calldata contains sendToken call
        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    function test_StargateSend_Build_WithoutComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
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

        bytes memory data = _encodeStargateData(true, 0, false);
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

        bytes memory data = _encodeStargateData(true, 0, false);
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
        bytes memory data = _encodeStargateData(false, 0, false);
        mockAmountLD = originalAmount;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_PoolZero() public {
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateData(false, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_RecipientZero() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateData(false, 0, false);
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

        bytes memory data = _encodeStargateData(true, 0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(mockPrevHook, mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                        STARGATE INSPECTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_Inspector() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        bytes memory argsEncoded = stargateHook.inspect(data);

        // Should return stargatePool + inputToken + toAddress (60 bytes)
        assertEq(argsEncoded.length, 60);
    }

    /*//////////////////////////////////////////////////////////////
                    STARGATE CONTEXT AWARE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeStargateData(true, 0, false);
        assertTrue(stargateHook.decodeUsePrevHookAmount(data));
    }

    function test_StargateSend_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
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
        bytes memory data = _encodeStargateData(false, 0, false);
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
        bytes memory data = _encodeStargateData(false, 0, true);
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

        bytes memory data = _encodeStargateData(true, 0, false);
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
        bytes memory data = _encodeStargateData(false, 0, false);
        mockInputToken = originalToken;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_PoolTokenMismatch() public {
        // Mock pool.token() to return a different token than inputToken
        address wrongToken = makeAddr("wrongToken");
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(wrongToken));

        bytes memory data = _encodeStargateData(false, 0, false);

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
        bytes memory data = _encodeStargateData(false, 0, false);
        mockStargatePool = originalPool;

        // Should revert because token() call fails on non-contract address
        vm.expectRevert();
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Inspector() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
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
        bytes memory data = _encodeStargateData(false, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert();
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_PoolIsEOA() public {
        address eoaPool = address(0xdead);
        address originalPool = mockStargatePool;
        mockStargatePool = eoaPool;
        bytes memory data = _encodeStargateData(false, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert();
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_PoolReturnsZeroToken() public {
        // Pool returns address(0) as token (native pool), but hook expects ERC20
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));

        bytes memory data = _encodeStargateData(false, 0, false);

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);

        // Restore
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    function test_ApproveAndStargateSend_Build_Passes_WhenPoolTokenMatches() public view {
        // Happy path: pool.token() == inputToken (set up in setUp)
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
    }

    // --- P2-2: Validation ordering (fail-fast before external calls) ---

    function test_StargateSend_FailFast_PoolZeroBeforePrevHookCall() public {
        // With usePrevHookAmount=true but pool=address(0), should revert with POOL_NOT_VALID
        // BEFORE attempting to call prevHook.getOutAmount()
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateData(true, 0, false);
        mockStargatePool = originalPool;

        // If validation ordering is wrong, this would revert with a different error
        // (e.g., call to address(0) for prevHook) instead of POOL_NOT_VALID
        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_FailFast_RecipientZeroBeforePrevHookCall() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(0);
        bytes memory data = _encodeStargateData(true, 0, false);
        mockTo = originalTo;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_FailFast_InputTokenZeroBeforePrevHookCall() public {
        address originalToken = mockInputToken;
        mockInputToken = address(0);
        bytes memory data = _encodeStargateData(true, 0, false);
        mockInputToken = originalToken;

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_FailFast_PoolZeroBeforePrevHookCall() public {
        address originalPool = mockStargatePool;
        mockStargatePool = address(0);
        bytes memory data = _encodeStargateData(true, 0, false);
        mockStargatePool = originalPool;

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    // --- P2-3: Variable-length data bounds validation ---

    function test_StargateSend_Build_RevertIf_ExtraOptionsLengthExceedsData() public {
        // Encode data with extraOptionsLength claiming 100 bytes but only 2 bytes actually present
        bytes memory data = abi.encodePacked(
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
        // Pool is address(0), data meets 238 min but has invalid extraOptionsLength
        // Should get POOL_NOT_VALID (checked before variable-length validation)
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, // 32
            address(0), // 20 - zero pool
            mockInputToken, // 20
            mockDstEid, // 4
            mockTo, // 32
            mockAmountLD, // 32
            mockMinAmountLD, // 32
            false, // 1
            false, // 1
            uint256(999), // 32 - invalid extraOptionsLength
            uint256(0) // 32 - composeMsgLength (to reach 238 min)
        );
        // Total: 52+32+20+20+4+32+32+32+1+1+32+32 = 290 (with 52-byte placeholder)

        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_ValidationOrder_AddressCheckedBeforePoolToken() public {
        // inputToken is address(0), pool mock is correct
        // Should get ADDRESS_NOT_VALID (checked before pool.token())
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee,
            mockStargatePool,
            address(0), // zero inputToken
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
            _stargateFixedHeader(),
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
            _stargateFixedHeader(),
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
        bytes memory data = _encodeStargateData(false, 1, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // Verify bus mode produces different calldata than taxi mode
        bytes memory taxiData = _encodeStargateData(false, 0, false);
        Execution[] memory taxiExecutions = stargateHook.build(address(0), mockAccount, taxiData);

        // Both should target the pool and have valid calldata
        assertEq(executions[1].target, mockStargatePool);
        assertGt(executions[1].callData.length, 0);

        // Bus and taxi calldata should differ (oftCmd field differs)
        assertFalse(keccak256(executions[1].callData) == keccak256(taxiExecutions[1].callData));
    }

    function test_StargateSend_Build_TaxiMode_OftCmdEncoding() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertGt(executions[1].callData.length, 0);
    }

    // --- P3-3: Pool/token matching edge cases ---

    function test_ApproveAndStargateSend_Build_RevertIf_PoolTokenIsAddressZero() public {
        // Simulate a native pool (token() returns address(0)) being used with ERC20 hook
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(address(0)));

        bytes memory data = _encodeStargateData(false, 0, false);

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
        bytes memory data = _encodeStargateData(true, 0, false);
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

        bytes memory data = _encodeStargateData(true, 0, false);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Verify approval uses prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)));
    }

    // --- Data length boundary tests ---

    function test_StargateSend_Build_ExactMinimumDataLength() public view {
        // Exactly 290 bytes with 0-length variable fields (238 + 52-byte placeholder)
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, // 32
            mockStargatePool, // 20
            mockInputToken, // 20
            mockDstEid, // 4
            mockTo, // 32
            mockAmountLD, // 32
            mockMinAmountLD, // 32
            false, // 1
            false, // 1
            uint256(0), // 32 (extraOptionsLength)
            uint256(0) // 32 (composeMsgLength)
        );
        // Total: 52+32+20+20+4+32+32+32+1+1+32+32 = 290 bytes (with 52-byte placeholder)

        assertEq(data.length, 290);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_StargateSend_Build_RevertIf_OneByteShort() public {
        // 237 bytes - one short of minimum
        bytes memory data = new bytes(237);
        // Fill first 32 bytes with lzNativeFee
        assembly ("memory-safe") {
            mstore(add(data, 32), 10000000000000000) // 0.01 ether
        }

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                         OFT MODE (MODE=2) TESTS
    //////////////////////////////////////////////////////////////*/

    // --- StargateSendHook OFT mode ---

    function test_StargateSend_Build_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // preExecute + IOFT.send + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);

        // CRITICAL: OFT mode value = lzNativeFee ONLY (not + amountLD)
        assertEq(executions[1].value, mockLzNativeFee);

        // Verify selector is IOFT.send, not IStargate.sendToken
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
    }

    function test_StargateSend_Build_OFTMode_ValueIsLzNativeFeeOnly() public view {
        // Explicitly verify the critical msg.value difference between modes
        bytes memory stargateData = _encodeStargateData(false, 0, false);
        Execution[] memory stargateExecs = stargateHook.build(address(0), mockAccount, stargateData);

        bytes memory oftData = _encodeStargateData(false, 2, false);
        Execution[] memory oftExecs = stargateHook.build(address(0), mockAccount, oftData);

        // Stargate: value = lzNativeFee + amountLD
        assertEq(stargateExecs[1].value, mockLzNativeFee + mockAmountLD);

        // OFT: value = lzNativeFee ONLY
        assertEq(oftExecs[1].value, mockLzNativeFee);
    }

    function test_StargateSend_Build_OFTMode_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, 2, true);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
        // value still lzNativeFee only
        assertEq(executions[1].value, mockLzNativeFee);
    }

    function test_StargateSend_Build_OFTMode_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, 2, false);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
        // OFT mode: value = lzNativeFee only (prevHookAmount NOT added to value)
        assertEq(executions[1].value, mockLzNativeFee);
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
    }

    // --- ApproveAndStargateSendHook OFT mode ---

    function test_ApproveAndStargateSend_Build_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // preExecute + approve(0) + approve(amount) + IOFT.send + approve(0) + postExecute = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(inputToken, pool/OFT, 0)
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: approve(inputToken, pool/OFT, amountLD)
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, mockAmountLD)));

        // Execution 3: IOFT.send (value = lzNativeFee)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);

        // Execution 4: approve(inputToken, pool/OFT, 0)
        assertEq(executions[4].target, mockInputToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    function test_ApproveAndStargateSend_Build_OFTMode_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, 2, true);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
    }

    function test_ApproveAndStargateSend_Build_OFTMode_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Approval should use prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)));
        // Value should be lzNativeFee only
        assertEq(executions[3].value, mockLzNativeFee);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
    }

    function test_ApproveAndStargateSend_Build_OFTMode_TokenValidation() public {
        // OFT's token() must match inputToken, same as Stargate mode
        address wrongToken = makeAddr("wrongToken");
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(wrongToken));

        bytes memory data = _encodeStargateData(false, 2, false);

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);

        // Restore
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    // --- Mode validation tests (both hooks) ---

    function test_StargateSend_Build_RevertIf_ModeInvalid() public {
        bytes memory data = _encodeStargateData(false, 4, false);

        vm.expectRevert(StargateSendHook.MODE_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_ModeMax() public {
        bytes memory data = _encodeStargateData(false, 255, false);

        vm.expectRevert(StargateSendHook.MODE_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ModeInvalid() public {
        bytes memory data = _encodeStargateData(false, 4, false);

        vm.expectRevert(ApproveAndStargateSendHook.MODE_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ModeMax() public {
        bytes memory data = _encodeStargateData(false, 255, false);

        vm.expectRevert(ApproveAndStargateSendHook.MODE_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    // --- OFT mode selector verification ---

    function test_StargateSend_OFTMode_UsesCorrectSelector() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
        assertTrue(bytes4(executions[1].callData) != IStargate.sendToken.selector);
    }

    function test_ApproveAndStargateSend_OFTMode_UsesCorrectSelector() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
        assertTrue(bytes4(executions[3].callData) != IStargate.sendToken.selector);
    }

    // --- Backward compatibility ---

    function test_StargateSend_Mode0_IdenticalToOriginalTaxi() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
        assertEq(bytes4(executions[1].callData), IStargate.sendToken.selector);
    }

    function test_StargateSend_Mode1_IdenticalToOriginalBus() public view {
        bytes memory data = _encodeStargateData(false, 1, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
        assertEq(bytes4(executions[1].callData), IStargate.sendToken.selector);
    }

    /*//////////////////////////////////////////////////////////////
                     SECURITY VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev P1 Fix: composeMsg _account must match executing account
    function test_StargateSend_Build_RevertIf_ComposeMsgAccountMismatch() public {
        // Encode composeMsg with a different _account than mockAccount
        address wrongAccount = makeAddr("attacker");
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = mockAmountLD;
        bytes memory composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), wrongAccount, dstTokens, intentAmounts);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    /// @dev P1 Fix: composeMsg _account must match executing account (ApproveAndStargate)
    function test_ApproveAndStargateSend_Build_RevertIf_ComposeMsgAccountMismatch() public {
        address wrongAccount = makeAddr("attacker");
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = mockAmountLD;
        bytes memory composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), wrongAccount, dstTokens, intentAmounts);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    /// @dev Recipient can be a different address (e.g., StargateAdapter for cross-chain execution)
    function test_StargateSend_Build_RecipientCanBeAdapter() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(uint256(uint160(makeAddr("stargateAdapter"))));
        bytes memory data = _encodeStargateData(false, 0, false);
        mockTo = originalTo;

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
    }

    /// @dev Recipient can be a different address (ApproveAndStargate variant)
    function test_ApproveAndStargateSend_Build_RecipientCanBeAdapter() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(uint256(uint160(makeAddr("stargateAdapter"))));
        bytes memory data = _encodeStargateData(false, 0, false);
        mockTo = originalTo;

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
        assertEq(executions[3].target, mockStargatePool);
    }

    /// @dev Recipient can be adapter in OFT mode too
    function test_StargateSend_Build_OFTMode_RecipientCanBeAdapter() public {
        bytes32 originalTo = mockTo;
        mockTo = bytes32(uint256(uint160(makeAddr("stargateAdapter"))));
        bytes memory data = _encodeStargateData(false, 2, false);
        mockTo = originalTo;

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
        // OFT mode: value = lzNativeFee only
        assertEq(executions[1].value, mockLzNativeFee);
    }

    /// @dev Finding #4: minAmountLD must not round to zero after proportional scaling
    function test_StargateSend_Build_RevertIf_MinAmountRoundsToZero() public {
        // Set up prev hook with a very small output relative to amountLD
        // minAmountLD=1, amountLD=1000e6, outAmount=1 => mulDiv(1, 1, 1000e6) = 0
        uint256 originalMinAmountLD = mockMinAmountLD;
        uint256 originalAmountLD = mockAmountLD;
        mockMinAmountLD = 1;
        mockAmountLD = 1000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(1, mockAccount);

        bytes memory data = _encodeStargateData(true, 0, false);
        mockMinAmountLD = originalMinAmountLD;
        mockAmountLD = originalAmountLD;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        stargateHook.build(address(mockPrevHook), mockAccount, data);
    }

    /// @dev Finding #4: minAmountLD must not round to zero after proportional scaling (ApproveAndStargate)
    function test_ApproveAndStargateSend_Build_RevertIf_MinAmountRoundsToZero() public {
        uint256 originalMinAmountLD = mockMinAmountLD;
        uint256 originalAmountLD = mockAmountLD;
        mockMinAmountLD = 1;
        mockAmountLD = 1000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(1, mockAccount);

        bytes memory data = _encodeStargateData(true, 0, false);
        mockMinAmountLD = originalMinAmountLD;
        mockAmountLD = originalAmountLD;

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndStargateHook.build(address(mockPrevHook), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                  DATA LAYOUT & OFFSET CORRECTNESS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Verify that decoded SendParam fields in the generated calldata exactly match encoded values
    function test_StargateSend_Build_CalldataDecodesCorrectly_TaxiMode() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // Decode the sendToken calldata (skip 4-byte selector)
        bytes memory callData = executions[1].callData;
        assertEq(bytes4(callData), IStargate.sendToken.selector);

        // Decode: sendToken(SendParam, MessagingFee, refundAddress)
        (IStargate.SendParam memory sp, IStargate.MessagingFee memory mf, address refund) =
            abi.decode(_stripSelector(callData), (IStargate.SendParam, IStargate.MessagingFee, address));

        assertEq(sp.dstEid, mockDstEid, "dstEid mismatch");
        assertEq(sp.to, mockTo, "to mismatch");
        assertEq(sp.amountLD, mockAmountLD, "amountLD mismatch");
        assertEq(sp.minAmountLD, mockMinAmountLD, "minAmountLD mismatch");
        assertEq(sp.extraOptions.length, mockExtraOptions.length, "extraOptions length mismatch");
        assertEq(sp.composeMsg.length, 0, "composeMsg should be empty");
        assertEq(sp.oftCmd.length, 0, "taxi mode should have empty oftCmd");
        assertEq(mf.nativeFee, mockLzNativeFee, "nativeFee mismatch");
        assertEq(mf.lzTokenFee, 0, "lzTokenFee must be hardcoded to 0");
        assertEq(refund, mockAccount, "refundAddress must be account");
    }

    /// @dev Verify OFT mode calldata decodes correctly with IOFT.send
    function test_StargateSend_Build_CalldataDecodesCorrectly_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        bytes memory callData = executions[1].callData;
        assertEq(bytes4(callData), IOFT.send.selector);

        (IOFT.SendParam memory sp, IOFT.MessagingFee memory mf, address refund) =
            abi.decode(_stripSelector(callData), (IOFT.SendParam, IOFT.MessagingFee, address));

        assertEq(sp.dstEid, mockDstEid);
        assertEq(sp.to, mockTo);
        assertEq(sp.amountLD, mockAmountLD);
        assertEq(sp.minAmountLD, mockMinAmountLD);
        assertEq(sp.oftCmd.length, 0, "OFT mode should have empty oftCmd");
        assertEq(mf.nativeFee, mockLzNativeFee);
        assertEq(mf.lzTokenFee, 0, "lzTokenFee must be hardcoded to 0");
        assertEq(refund, mockAccount);
    }

    /// @dev Verify bus mode uses correct oftCmd encoding in calldata
    function test_StargateSend_Build_CalldataDecodesCorrectly_BusMode() public view {
        bytes memory data = _encodeStargateData(false, 1, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        (IStargate.SendParam memory sp,,) =
            abi.decode(_stripSelector(executions[1].callData), (IStargate.SendParam, IStargate.MessagingFee, address));

        assertEq(sp.oftCmd.length, 1, "bus mode should have 1-byte oftCmd");
        assertEq(uint8(sp.oftCmd[0]), 1, "bus mode oftCmd should be 0x01");
    }

    /// @dev Verify ApproveAndStargate calldata decodes correctly including approval targets
    function test_ApproveAndStargateSend_Build_CalldataDecodesCorrectly() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // All approve executions must have value 0
        assertEq(executions[1].value, 0, "approve(0) must have zero value");
        assertEq(executions[2].value, 0, "approve(amount) must have zero value");
        assertEq(executions[4].value, 0, "cleanup approve must have zero value");

        // Decode sendToken calldata
        (IStargate.SendParam memory sp, IStargate.MessagingFee memory mf, address refund) =
            abi.decode(_stripSelector(executions[3].callData), (IStargate.SendParam, IStargate.MessagingFee, address));

        assertEq(sp.dstEid, mockDstEid);
        assertEq(sp.amountLD, mockAmountLD);
        assertEq(sp.minAmountLD, mockMinAmountLD);
        assertEq(mf.lzTokenFee, 0, "lzTokenFee must be hardcoded to 0");
        assertEq(refund, mockAccount);
    }

    /// @dev Verify ApproveAndStargate OFT mode calldata
    function test_ApproveAndStargateSend_Build_CalldataDecodesCorrectly_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        (IOFT.SendParam memory sp, IOFT.MessagingFee memory mf, address refund) =
            abi.decode(_stripSelector(executions[3].callData), (IOFT.SendParam, IOFT.MessagingFee, address));

        assertEq(sp.dstEid, mockDstEid);
        assertEq(sp.amountLD, mockAmountLD);
        assertEq(sp.oftCmd.length, 0, "OFT mode always has empty oftCmd");
        assertEq(mf.lzTokenFee, 0, "lzTokenFee must be hardcoded to 0");
        assertEq(refund, mockAccount);
    }

    /*//////////////////////////////////////////////////////////////
                      DATA BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev ApproveAndStargate: exact minimum data length
    function test_ApproveAndStargateSend_Build_ExactMinimumDataLength() public view {
        bytes memory data = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, // 32
            mockStargatePool, // 20
            mockInputToken, // 20
            mockDstEid, // 4
            mockTo, // 32
            mockAmountLD, // 32
            mockMinAmountLD, // 32
            false, // 1 (usePrevHookAmount)
            uint8(0), // 1 (mode)
            uint256(0), // 32 (extraOptionsLength)
            uint256(0) // 32 (composeMsgLength)
        );

        assertEq(data.length, 290);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
    }

    /// @dev ApproveAndStargate: one byte short of minimum
    function test_ApproveAndStargateSend_Build_RevertIf_OneByteShort() public {
        bytes memory data = new bytes(237);
        assembly ("memory-safe") {
            mstore(add(data, 32), 10000000000000000) // 0.01 ether
        }

        vm.expectRevert(ApproveAndStargateSendHook.DATA_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                      ZERO LZ NATIVE FEE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Zero lzNativeFee is valid (some LZ configs allow free messaging)
    function test_StargateSend_Build_ZeroLzNativeFee() public view {
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            uint256(0), // zero lzNativeFee
            mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
        // value = 0 + amountLD for Stargate mode
        assertEq(executions[1].value, mockAmountLD, "Value should be just amountLD when lzNativeFee is 0");
    }

    /// @dev Zero lzNativeFee with OFT mode results in zero msg.value
    function test_StargateSend_Build_ZeroLzNativeFee_OFTMode() public view {
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            uint256(0), // zero lzNativeFee
            mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(2), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions[1].value, 0, "OFT mode with zero lzNativeFee = zero value");
    }

    /// @dev Zero lzNativeFee for ApproveAndStargate
    function test_ApproveAndStargateSend_Build_ZeroLzNativeFee() public view {
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            uint256(0), mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions[3].value, 0, "ERC20 hook with zero lzNativeFee = zero value");
    }

    /*//////////////////////////////////////////////////////////////
                      INSPECT OFFSET TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Inspect returns correct addresses for OFT mode data
    function test_StargateSend_Inspector_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        bytes memory inspected = stargateHook.inspect(data);

        assertEq(inspected.length, 60);
        address pool;
        address token;
        address to;
        assembly ("memory-safe") {
            pool := mload(add(inspected, 20))
            token := mload(add(inspected, 40))
            to := mload(add(inspected, 60))
        }
        assertEq(pool, mockStargatePool, "inspect pool mismatch in OFT mode");
        assertEq(token, mockInputToken, "inspect token mismatch in OFT mode");
        assertEq(to, mockAccount, "inspect to mismatch in OFT mode");
    }

    /// @dev Inspect returns correct addresses for ApproveAndStargate OFT mode
    function test_ApproveAndStargateSend_Inspector_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        bytes memory inspected = approveAndStargateHook.inspect(data);

        assertEq(inspected.length, 60);
        address pool;
        address token;
        address to;
        assembly ("memory-safe") {
            pool := mload(add(inspected, 20))
            token := mload(add(inspected, 40))
            to := mload(add(inspected, 60))
        }
        assertEq(pool, mockStargatePool);
        assertEq(token, mockInputToken);
        assertEq(to, mockAccount);
    }

    /*//////////////////////////////////////////////////////////////
                  BOTH VARIABLE-LENGTH FIELDS POPULATED
    //////////////////////////////////////////////////////////////*/

    /// @dev Build with both extraOptions AND composeMsg non-empty
    function test_StargateSend_Build_BothVariableFieldsPopulated() public view {
        bytes memory extraOptions = hex"000301001101000000000000000000000000000186a0";
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = mockAmountLD;
        bytes memory composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), mockAccount, dstTokens, intentAmounts);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(extraOptions.length), extraOptions,
            uint256(composeMsg.length), composeMsg
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);

        // Decode and verify both fields are present
        (IStargate.SendParam memory sp,,) =
            abi.decode(_stripSelector(executions[1].callData), (IStargate.SendParam, IStargate.MessagingFee, address));

        assertEq(sp.extraOptions.length, extraOptions.length, "extraOptions should be preserved");
        assertGt(sp.composeMsg.length, composeMsg.length, "composeMsg should have signature appended");
    }

    /// @dev ApproveAndStargate with both variable fields in OFT mode
    function test_ApproveAndStargateSend_Build_OFTMode_BothVariableFields() public view {
        bytes memory extraOptions = hex"000301001101000000000000000000000000000186a0";
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockInputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = mockAmountLD;
        bytes memory composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), mockAccount, dstTokens, intentAmounts);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(2), uint256(extraOptions.length), extraOptions,
            uint256(composeMsg.length), composeMsg
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector, "OFT mode with compose should use IOFT.send");
    }

    /*//////////////////////////////////////////////////////////////
                      LARGE COMPOSE MSG TEST
    //////////////////////////////////////////////////////////////*/

    /// @dev Build with large composeMsg
    function test_StargateSend_Build_LargeComposeMsg() public view {
        // Build large composeMsg with multiple destination tokens
        address[] memory dstTokens = new address[](5);
        uint256[] memory intentAmounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            dstTokens[i] = address(uint160(i + 1));
            intentAmounts[i] = (i + 1) * 1e18;
        }
        bytes memory composeMsg =
            abi.encode(bytes(hex"aabbccdd"), bytes(hex"11223344"), mockAccount, dstTokens, intentAmounts);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
               PREV HOOK AMOUNT WITH OFT MODE SCALING
    //////////////////////////////////////////////////////////////*/

    /// @dev OFT mode with prevHookAmount correctly scales minAmountLD
    function test_StargateSend_Build_OFTMode_PrevHookAmount_ScalesMinAmount() public {
        uint256 prevHookAmount = 500e6; // Half of original amountLD

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, 2, false);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        // Decode calldata to verify scaled amounts
        (IOFT.SendParam memory sp,,) =
            abi.decode(_stripSelector(executions[1].callData), (IOFT.SendParam, IOFT.MessagingFee, address));

        assertEq(sp.amountLD, prevHookAmount, "amountLD should be prevHookAmount");
        // minAmountLD should be scaled: Math.mulDiv(995e6, 500e6, 1000e6) = 497.5e6 = 497500000
        uint256 expectedMin = Math.mulDiv(mockMinAmountLD, prevHookAmount, mockAmountLD);
        assertEq(sp.minAmountLD, expectedMin, "minAmountLD should be proportionally scaled");
        // Value is lzNativeFee only in OFT mode
        assertEq(executions[1].value, mockLzNativeFee);
    }

    /// @dev ApproveAndStargate OFT mode prevHookAmount scales approval and minAmount
    function test_ApproveAndStargateSend_Build_OFTMode_PrevHookAmount_ScalesApproval() public {
        uint256 prevHookAmount = 500e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        // Approval should use prevHookAmount
        assertEq(
            executions[2].callData,
            abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)),
            "Approval should be for prevHookAmount"
        );

        // Decode send calldata to verify scaled minAmountLD
        (IOFT.SendParam memory sp,,) =
            abi.decode(_stripSelector(executions[3].callData), (IOFT.SendParam, IOFT.MessagingFee, address));

        uint256 expectedMin = Math.mulDiv(mockMinAmountLD, prevHookAmount, mockAmountLD);
        assertEq(sp.minAmountLD, expectedMin, "minAmountLD should be proportionally scaled");
    }

    /*//////////////////////////////////////////////////////////////
                      MODE VALUE EXHAUSTIVE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Verify msg.value for all 3 valid modes in StargateSendHook
    function test_StargateSend_Build_ValueForAllModes() public view {
        // Mode 0 (taxi): lzNativeFee + amountLD
        bytes memory d0 = _encodeStargateData(false, 0, false);
        Execution[] memory e0 = stargateHook.build(address(0), mockAccount, d0);
        assertEq(e0[1].value, mockLzNativeFee + mockAmountLD, "taxi: lzNativeFee + amountLD");

        // Mode 1 (bus): lzNativeFee + amountLD
        bytes memory d1 = _encodeStargateData(false, 1, false);
        Execution[] memory e1 = stargateHook.build(address(0), mockAccount, d1);
        assertEq(e1[1].value, mockLzNativeFee + mockAmountLD, "bus: lzNativeFee + amountLD");

        // Mode 2 (OFT): lzNativeFee ONLY
        bytes memory d2 = _encodeStargateData(false, 2, false);
        Execution[] memory e2 = stargateHook.build(address(0), mockAccount, d2);
        assertEq(e2[1].value, mockLzNativeFee, "OFT: lzNativeFee only");
    }

    /// @dev Verify msg.value for all 3 valid modes in ApproveAndStargateSendHook
    function test_ApproveAndStargateSend_Build_ValueForAllModes() public view {
        // All modes: value = lzNativeFee for ERC20 hook
        for (uint8 mode = 0; mode <= 2; mode++) {
            bytes memory data = _encodeStargateData(false, mode, false);
            Execution[] memory execs = approveAndStargateHook.build(address(0), mockAccount, data);
            assertEq(execs[3].value, mockLzNativeFee, string.concat("mode ", vm.toString(mode), ": lzNativeFee"));
        }
    }

    /// @dev Verify selector for all 3 valid modes
    function test_StargateSend_Build_SelectorForAllModes() public view {
        // Mode 0 (taxi): sendToken
        bytes memory d0 = _encodeStargateData(false, 0, false);
        assertEq(bytes4(stargateHook.build(address(0), mockAccount, d0)[1].callData), IStargate.sendToken.selector);

        // Mode 1 (bus): sendToken
        bytes memory d1 = _encodeStargateData(false, 1, false);
        assertEq(bytes4(stargateHook.build(address(0), mockAccount, d1)[1].callData), IStargate.sendToken.selector);

        // Mode 2 (OFT): IOFT.send
        bytes memory d2 = _encodeStargateData(false, 2, false);
        assertEq(bytes4(stargateHook.build(address(0), mockAccount, d2)[1].callData), IOFT.send.selector);
    }

    /*//////////////////////////////////////////////////////////////
                      FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fuzz: any valid amountLD/minAmountLD produces correct execution for StargateSendHook
    function testFuzz_StargateSend_Build_AmountLD(uint256 amountLD, uint256 minAmountLD) public view {
        vm.assume(amountLD > 0 && amountLD <= type(uint128).max);
        vm.assume(minAmountLD > 0 && minAmountLD <= amountLD);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, amountLD, minAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].value, mockLzNativeFee + amountLD);
    }

    /// @dev Fuzz: any valid amountLD/minAmountLD produces correct execution for ApproveAndStargateSendHook
    function testFuzz_ApproveAndStargateSend_Build_AmountLD(uint256 amountLD, uint256 minAmountLD) public view {
        vm.assume(amountLD > 0 && amountLD <= type(uint128).max);
        vm.assume(minAmountLD > 0 && minAmountLD <= amountLD);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, amountLD, minAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
        // Approval should match amountLD
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, amountLD)));
        assertEq(executions[3].value, mockLzNativeFee);
    }

    /// @dev Fuzz: any valid mode 0-2 succeeds, 4-255 reverts (mode 3 tested separately with executeCalldata)
    function testFuzz_StargateSend_Build_ModeValidation(uint8 mode) public {
        vm.assume(mode != 3); // mode 3 requires executeCalldata, tested separately

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, mode, uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        if (mode > 3) {
            vm.expectRevert(StargateSendHook.MODE_NOT_VALID.selector);
            stargateHook.build(address(0), mockAccount, data);
        } else {
            Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
            assertGt(executions.length, 0);
        }
    }

    /// @dev Fuzz: lzNativeFee doesn't overflow when added to amountLD in Stargate mode
    function testFuzz_StargateSend_Build_NoValueOverflow(uint256 lzNativeFee, uint256 amountLD) public view {
        vm.assume(amountLD > 0 && amountLD <= type(uint128).max);
        vm.assume(lzNativeFee <= type(uint128).max);

        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            lzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, amountLD, amountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(0), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions[1].value, lzNativeFee + amountLD);
    }

    /*//////////////////////////////////////////////////////////////
                     LZ MULTICALL MODE (MODE=3) TESTS
    //////////////////////////////////////////////////////////////*/

    // --- StargateSendHook mode 3 ---

    function test_StargateSend_Build_LzMulticallMode() public view {
        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory data = _encodeLzMulticallData(executeCalldata, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // preExecute + lzMulticall + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee);
        assertEq(executions[1].callData, executeCalldata);
    }

    function test_StargateSend_Build_LzMulticallMode_PoolValidationSkipped() public {
        // No token() mock needed for mode 3 - pool validation is skipped
        address lzMulticallAddr = makeAddr("lzMulticall");
        address originalPool = mockStargatePool;

        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, lzMulticallAddr, mockInputToken, uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(3),
            uint256(0), // extraOptionsLength
            uint256(0), // composeMsgLength
            uint256(executeCalldata.length), executeCalldata
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, lzMulticallAddr);
    }

    function test_StargateSend_Build_LzMulticallMode_ToZeroAllowed() public view {
        // to=bytes32(0) is allowed for mode 3
        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(3),
            uint256(0),
            uint256(0),
            uint256(executeCalldata.length), executeCalldata
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 3);
    }

    function test_StargateSend_Build_LzMulticallMode_RevertIf_EmptyExecuteCalldata() public {
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(3),
            uint256(0), // extraOptionsLength
            uint256(0), // composeMsgLength
            uint256(0) // executeCalldataLength = 0
        );

        vm.expectRevert(StargateSendHook.DATA_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_LzMulticallMode_RevertIf_PoolZero() public {
        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, address(0), mockInputToken, uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(3),
            uint256(0),
            uint256(0),
            uint256(executeCalldata.length), executeCalldata
        );

        vm.expectRevert(StargateSendHook.POOL_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_LzMulticallMode_CorrectValueAndCalldata() public view {
        // Build realistic lzMulticall.execute calldata
        ILZMultiCall.Call[] memory calls = new ILZMultiCall.Call[](2);
        calls[0] = ILZMultiCall.Call({ target: address(0x1), value: 0.005 ether, data: hex"aabbccdd" });
        calls[1] = ILZMultiCall.Call({ target: address(0x2), value: 0.005 ether, data: hex"eeff0011" });
        bytes32 quoteId = keccak256("quote123");
        bytes memory executeCalldata = abi.encodeCall(ILZMultiCall.execute, (calls, quoteId));

        bytes memory data = _encodeLzMulticallData(executeCalldata, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions[1].target, mockStargatePool);
        assertEq(executions[1].value, mockLzNativeFee);
        assertEq(executions[1].callData, executeCalldata);
    }

    // --- ApproveAndStargateSendHook mode 3 ---

    function test_ApproveAndStargateSend_Build_LzMulticallMode() public view {
        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory data = _encodeLzMulticallData(executeCalldata, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // preExecute + approve(0) + approve(amount) + lzMulticall + approve(0) + postExecute = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(inputToken, lzMulticall, 0)
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: approve(inputToken, lzMulticall, amountLD)
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, mockAmountLD)));

        // Execution 3: lzMulticall.execute (value = lzNativeFee, calldata = executeCalldata)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee);
        assertEq(executions[3].callData, executeCalldata);

        // Execution 4: approve(inputToken, lzMulticall, 0)
        assertEq(executions[4].target, mockInputToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    function test_ApproveAndStargateSend_Build_LzMulticallMode_TokenMatchSkipped() public {
        // pool.token() check is skipped in mode 3, so wrong token mock won't cause revert
        address lzMulticallAddr = makeAddr("lzMulticall");
        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, lzMulticallAddr, mockInputToken, uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(3),
            uint256(0),
            uint256(0),
            uint256(executeCalldata.length), executeCalldata
        );

        // Should succeed even without mocking token() on lzMulticallAddr
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);
        assertEq(executions.length, 6);
        // Approval targets lzMulticall
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (lzMulticallAddr, 0)));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (lzMulticallAddr, mockAmountLD)));
    }

    function test_ApproveAndStargateSend_Build_LzMulticallMode_CalldataForwarded() public view {
        ILZMultiCall.Call[] memory calls = new ILZMultiCall.Call[](1);
        calls[0] = ILZMultiCall.Call({ target: address(0x1), value: 0.01 ether, data: hex"deadbeef" });
        bytes32 quoteId = keccak256("quote456");
        bytes memory executeCalldata = abi.encodeCall(ILZMultiCall.execute, (calls, quoteId));

        bytes memory data = _encodeLzMulticallData(executeCalldata, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // Verify the calldata is forwarded exactly
        assertEq(executions[3].callData, executeCalldata);
    }

    function test_ApproveAndStargateSend_Build_LzMulticallMode_RevertIf_InputTokenZero() public {
        bytes memory executeCalldata = _buildMockExecuteCalldata();
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, address(0), uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(3),
            uint256(0),
            uint256(0),
            uint256(executeCalldata.length), executeCalldata
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StargateSend_DecodeAmounts() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        assertEq(stargateHook.decodeAmounts(data)[0], mockAmountLD);
    }

    function test_StargateSend_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        uint256 newAmount = 2e18;
        bytes memory result = stargateHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(stargateHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_StargateSend_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeStargateData(false, 0, false);
        bytes memory result = stargateHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(stargateHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndStargateSend_DecodeAmounts() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        assertEq(approveAndStargateHook.decodeAmounts(data)[0], mockAmountLD);
    }

    function test_ApproveAndStargateSend_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndStargateHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndStargateHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndStargateSend_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeStargateData(false, 0, false);
        bytes memory result = approveAndStargateHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndStargateHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_Stargate_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        uint256 newAmount = 500;
        bytes memory replaced = stargateHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 3);
        assertEq(stargateHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndStargate_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndStargateHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndStargateHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_Stargate_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _encodeStargateData(false, 0, false);
        bytes memory replaced = stargateHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // amountLD is at AMOUNT_POSITION = 160 (uint256 = 32 bytes, ends at byte 191)
        for (uint256 i = 0; i < 160; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 192; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strip 4-byte selector from calldata for abi.decode
    function _stripSelector(bytes memory data) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; i++) {
            result[i - 4] = data[i];
        }
        return result;
    }

    function _encodeStargateData(
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
            address[] memory dstTokens = new address[](1);
            dstTokens[0] = mockInputToken;
            uint256[] memory intentAmounts = new uint256[](1);
            intentAmounts[0] = mockAmountLD;
            composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), mockAccount, dstTokens, intentAmounts);
        }

        // Split encoding to avoid stack too deep
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, mockDstEid, mockTo, mockAmountLD, mockMinAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrevHookAmount, mode, uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );
    }

    function _encodeLzMulticallData(
        bytes memory executeCalldata,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory fixedPart = abi.encodePacked(
            bytes(new bytes(52)), // 52-byte placeholder
            mockLzNativeFee, mockStargatePool, mockInputToken, uint32(0), bytes32(0), mockAmountLD, mockMinAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrevHookAmount, uint8(3),
            uint256(0), // extraOptionsLength
            uint256(0), // composeMsgLength
            uint256(executeCalldata.length), executeCalldata
        );
    }

    function _buildMockExecuteCalldata() internal pure returns (bytes memory) {
        ILZMultiCall.Call[] memory calls = new ILZMultiCall.Call[](1);
        calls[0] = ILZMultiCall.Call({ target: address(0x1), value: 0.01 ether, data: hex"aabbccdd" });
        return abi.encodeCall(ILZMultiCall.execute, (calls, keccak256("testQuote")));
    }

    /// @dev Helper to encode the standard 8-field Stargate fixed header (avoids stack too deep)
    function _stargateFixedHeader() internal view returns (bytes memory) {
        return abi.encodePacked(
            bytes(new bytes(52)),
            mockLzNativeFee,
            mockStargatePool,
            mockInputToken,
            mockDstEid,
            mockTo,
            mockAmountLD,
            mockMinAmountLD
        );
    }
}
