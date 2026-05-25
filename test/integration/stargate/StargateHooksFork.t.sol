// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { StargateSendHook } from "../../../src/hooks/bridges/stargate/StargateSendHook.sol";
import { ApproveAndStargateSendHook } from "../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { LayerZeroV2Helper } from "../../../lib/pigeon/src/layerzero-v2/LayerZeroV2Helper.sol";

import { Vm } from "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @dev Mock signature storage for integration tests
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

/// @title StargateHooksFork
/// @notice Integration tests for Stargate V2 bridge hooks using mainnet fork
/// @dev Tests real Stargate pool interactions on forked Ethereum mainnet
contract StargateHooksFork is Helpers {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Stargate V2 USDC Pool on Ethereum mainnet
    address public constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;

    // Stargate V2 USDC Pool on Base
    address public constant STARGATE_USDC_POOL_BASE = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;

    // LayerZero V2 Endpoint on Ethereum
    address public constant LZ_ENDPOINT_ETH = 0x1a44076050125825900e736c501f859c50fE728c;

    // LayerZero V2 Endpoint on Base
    address public constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;

    // USDC on Ethereum
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // LayerZero V2 Endpoint IDs
    uint32 public constant EID_ETHEREUM = 30_101;
    uint32 public constant EID_BASE = 30_184;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    StargateSendHook public stargateHook;
    ApproveAndStargateSendHook public approveAndStargateHook;
    MockStargateSignatureStorage public mockSignatureStorage;
    LayerZeroV2Helper public lzHelper;

    address public account;
    uint256 public ethForkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        mockSignatureStorage = new MockStargateSignatureStorage();
        stargateHook = new StargateSendHook(address(mockSignatureStorage));
        approveAndStargateHook = new ApproveAndStargateSendHook(address(mockSignatureStorage));
        lzHelper = new LayerZeroV2Helper();

        account = makeAddr("account");
        vm.deal(account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    FORK VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify we can interact with the real Stargate V2 USDC pool
    function test_Fork_StargatePoolIsValid() public view {
        // Verify the pool has the correct token
        address token = IStargate(STARGATE_USDC_POOL_ETH).token();
        assertEq(token, USDC_ETH, "Stargate USDC pool should have USDC as underlying token");
    }

    /// @notice Quote a real send fee from Stargate to verify interface compatibility
    function test_Fork_QuoteSend_USDC_EthToBase() public view {
        uint256 amountLD = 1000e6; // 1000 USDC

        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: 995e6, // 0.5% slippage
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("") // taxi mode
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(sendParam, false);

        console2.log("LZ native fee for ETH->Base USDC transfer:", fee.nativeFee);
        assertGt(fee.nativeFee, 0, "Fee should be non-zero");
        assertEq(fee.lzTokenFee, 0, "LZ token fee should be 0 when not paying in LZ token");
    }

    /*//////////////////////////////////////////////////////////////
                APPROVE AND STARGATE SEND - ERC20 FORK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test building hook executions with real Stargate pool address (ERC20 USDC)
    function test_Fork_ApproveAndStargateSend_Build_USDC() public view {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;

        // Quote the real fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);

        // Build hook data
        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false, // usePrevHookAmount
            false, // isBusMode (taxi)
            hex"", // extraOptions
            hex"" // no composeMsg
        );

        // Build executions
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        // Verify structure: preExecute + approve(0) + approve(amount) + sendToken + approve(0) + postExecute
        assertEq(executions.length, 6, "Should have 6 executions (pre + 4 hook + post)");

        // Execution 1: approve(pool, 0)
        assertEq(executions[1].target, USDC_ETH);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        // Execution 2: approve(pool, amountLD)
        assertEq(executions[2].target, USDC_ETH);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, amountLD)));

        // Execution 3: sendToken call to Stargate pool
        assertEq(executions[3].target, STARGATE_USDC_POOL_ETH);
        assertEq(executions[3].value, fee.nativeFee, "Value should be lzNativeFee only for ERC20");

        // Verify sendToken selector
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IStargate.sendToken.selector);

        // Execution 4: approve(pool, 0) cleanup
        assertEq(executions[4].target, USDC_ETH);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));
    }

    /// @notice Execute a real USDC bridge from Ethereum to Base via Stargate V2
    function test_Fork_ApproveAndStargateSend_Execute_USDC_EthToBase() public {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;

        // Fund the account with USDC
        deal(USDC_ETH, account, amountLD);

        // Quote the real LZ fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);
        console2.log("LZ fee:", fee.nativeFee);

        // Build hook data
        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            false, // taxi mode
            hex"",
            hex""
        );

        // Build executions
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        // Execute from the account
        uint256 usdcBefore = IERC20(USDC_ETH).balanceOf(account);
        assertEq(usdcBefore, amountLD);

        // Record logs for LZ helper
        vm.recordLogs();

        // Execute all hook executions from the account
        vm.startPrank(account);

        // preExecute
        (bool success,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(success, "preExecute failed");

        // approve(0)
        (success,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(success, "approve(0) failed");

        // approve(amount)
        (success,) = executions[2].target.call{ value: executions[2].value }(executions[2].callData);
        assertTrue(success, "approve(amount) failed");

        // sendToken (the actual bridge call)
        (success,) = executions[3].target.call{ value: executions[3].value }(executions[3].callData);
        assertTrue(success, "sendToken failed");

        // approve(0) cleanup
        (success,) = executions[4].target.call{ value: executions[4].value }(executions[4].callData);
        assertTrue(success, "approve(0) cleanup failed");

        // postExecute
        (success,) = executions[5].target.call{ value: executions[5].value }(executions[5].callData);
        assertTrue(success, "postExecute failed");

        vm.stopPrank();

        // Verify USDC was taken from the account
        uint256 usdcAfter = IERC20(USDC_ETH).balanceOf(account);
        assertEq(usdcAfter, 0, "All USDC should have been bridged");

        // Verify approval was cleaned up
        uint256 allowance = IERC20(USDC_ETH).allowance(account, STARGATE_USDC_POOL_ETH);
        assertEq(allowance, 0, "Approval should be cleaned up");

        console2.log("Successfully bridged", amountLD / 1e6, "USDC from ETH to Base via Stargate V2");
    }

    /// @notice Test bus mode quote (should differ from taxi mode)
    function test_Fork_QuoteSend_BusMode() public view {
        uint256 amountLD = 1000e6;

        IStargate.SendParam memory taxiParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: 995e6,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("") // taxi
        });

        IStargate.SendParam memory busParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: 995e6,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: abi.encodePacked(uint8(1)) // bus
        });

        IStargate.MessagingFee memory taxiFee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(taxiParam, false);
        IStargate.MessagingFee memory busFee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(busParam, false);

        console2.log("Taxi fee:", taxiFee.nativeFee);
        console2.log("Bus fee:", busFee.nativeFee);

        // Both should be valid fees
        assertGt(taxiFee.nativeFee, 0, "Taxi fee should be non-zero");
        assertGt(busFee.nativeFee, 0, "Bus fee should be non-zero");
    }

    /*//////////////////////////////////////////////////////////////
                STARGATE SEND - NATIVE ETH FORK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test StargateSendHook build with real pool address (native variant)
    function test_Fork_StargateSend_Build_Native() public view {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;

        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);

        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            false,
            hex"",
            hex""
        );

        Execution[] memory executions = stargateHook.build(address(0), account, hookData);

        // preExecute + sendToken + postExecute = 3
        assertEq(executions.length, 3);

        // sendToken execution
        assertEq(executions[1].target, STARGATE_USDC_POOL_ETH);
        // For native variant: value = lzNativeFee + amountLD
        assertEq(executions[1].value, fee.nativeFee + amountLD);

        bytes4 selector = bytes4(executions[1].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    /*//////////////////////////////////////////////////////////////
               CROSS-CHAIN WITH PIGEON LZ V2 HELPER
    //////////////////////////////////////////////////////////////*/

    /// @notice Full cross-chain test: send USDC from ETH to Base using pigeon helper
    function test_Fork_CrossChain_USDC_EthToBase_WithPigeon() public {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;

        // Create Base fork
        uint256 baseForkId = vm.createFork(vm.envString("BASE_RPC_URL"));

        // Switch back to ETH fork
        vm.selectFork(ethForkId);

        // Fund the account with USDC
        deal(USDC_ETH, account, amountLD);

        // Quote fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);

        // Build hook data
        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            false,
            hex"",
            hex""
        );

        // Build and execute
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        // Record logs for pigeon
        vm.recordLogs();

        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();

        // Verify source chain state
        uint256 usdcAfter = IERC20(USDC_ETH).balanceOf(account);
        assertEq(usdcAfter, 0, "All USDC should have been bridged from source");

        // Get logs for LZ message relay
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Use pigeon LayerZeroV2Helper to relay the message to Base fork
        lzHelper.help(LZ_ENDPOINT_BASE, baseForkId, logs);

        // Switch to Base and verify receipt
        vm.selectFork(baseForkId);

        // Check USDC balance on Base
        address USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        uint256 baseBalance = IERC20(USDC_BASE).balanceOf(account);

        console2.log("USDC received on Base:", baseBalance);
        // The amount received should be >= minAmountLD (after Stargate fees/dust removal)
        assertGe(baseBalance, minAmountLD, "Should receive at least minAmountLD on Base");

        // Switch back to ETH fork for cleanup
        vm.selectFork(ethForkId);
    }

    /*//////////////////////////////////////////////////////////////
                    WITH COMPOSE MSG (DST EXECUTION)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test build with composeMsg for destination execution
    function test_Fork_ApproveAndStargateSend_Build_WithComposeMsg() public view {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;

        // Build a composeMsg payload (same format as Across destinationMessage)
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = amountLD;
        bytes memory composeMsg = abi.encode(
            bytes(""), // initData
            bytes(""), // executorCalldata
            account, // destination account
            dstTokens,
            intentAmounts
        );

        // Quote with compose (needs extraOptions for compose gas)
        // Using minimal extraOptions for test
        bytes memory extraOptions = hex"000301001101000000000000000000000000000186a0"; // type3 + lzComposeOption(0, 100000, 0)

        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);
        console2.log("Fee with composeMsg:", fee.nativeFee);
        assertGt(fee.nativeFee, 0, "Fee should be positive with compose");

        // Build hook data (composeMsg WITHOUT signature - hook appends it)
        bytes memory composeMsgForHook = abi.encode(
            bytes(""), // initData
            bytes(""), // executorCalldata
            account,
            dstTokens,
            intentAmounts
        );

        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            false,
            extraOptions,
            composeMsgForHook
        );

        // Build should succeed and append signature
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6);

        // The sendToken call should have the compose message with signature appended
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IStargate.sendToken.selector);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _encodeStargateData(
        uint256 lzNativeFee,
        address stargatePool,
        address inputToken,
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        uint256 minAmountLD,
        bool usePrevHookAmount,
        bool isBusMode,
        bytes memory extraOptions,
        bytes memory composeMsg
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeStargateDataWithLzToken(
            lzNativeFee, 0, stargatePool, inputToken, address(0), dstEid, to, amountLD, minAmountLD,
            usePrevHookAmount, isBusMode, extraOptions, composeMsg
        );
    }

    function _encodeStargateDataWithLzToken(
        uint256 lzNativeFee,
        uint256 lzTokenFee,
        address stargatePool,
        address inputToken,
        address lzToken,
        uint32 dstEid,
        bytes32 to,
        uint256 amountLD,
        uint256 minAmountLD,
        bool usePrevHookAmount,
        bool isBusMode,
        bytes memory extraOptions,
        bytes memory composeMsg
    )
        internal
        pure
        returns (bytes memory)
    {
        // Split encoding to avoid stack too deep
        bytes memory fixedPart = abi.encodePacked(
            lzNativeFee, lzTokenFee, stargatePool, inputToken, lzToken, dstEid, to, amountLD, minAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrevHookAmount, isBusMode, uint256(extraOptions.length), extraOptions,
            uint256(composeMsg.length), composeMsg
        );
    }
}
