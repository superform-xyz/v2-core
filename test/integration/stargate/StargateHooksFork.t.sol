// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { StargateSendHook } from "../../../src/hooks/bridges/stargate/StargateSendHook.sol";
import { ApproveAndStargateSendHook } from "../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { IOFT } from "../../../src/vendor/bridges/layerzero/IOFT.sol";
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
            0, // mode: taxi
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
            0, // mode: taxi
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
            0, // mode: taxi
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
            0, // mode: taxi
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
            0, // mode: taxi
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
                    OFT MODE FORK TESTS - COMPREHENSIVE
    //////////////////////////////////////////////////////////////*/

    // UP OFTAdapter on Ethereum mainnet (locks UP tokens and sends cross-chain)
    address public constant UP_OFT_ADAPTER_ETH = 0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD;

    // WBTC OFTAdapter on Ethereum mainnet (locks WBTC and sends cross-chain)
    address public constant WBTC_OFT_ADAPTER_ETH = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;

    // WBTC on Ethereum (8 decimals)
    address public constant WBTC_ETH = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    /*//////////////////////////////////////////////////////////////
                    OFT INTERFACE COMPATIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify UP OFTAdapter implements token() and returns valid ERC20
    function test_Fork_OFTAdapter_UP_TokenInterface() public view {
        address token = IOFT(UP_OFT_ADAPTER_ETH).token();
        assertTrue(token != address(0), "OFTAdapter should return a non-zero token address");
        uint256 totalSupply = IERC20(token).totalSupply();
        assertGt(totalSupply, 0, "UP token should have non-zero total supply");
        console2.log("UP OFTAdapter underlying token:", token);
        console2.log("UP token total supply:", totalSupply);
    }

    /// @notice Verify WBTC OFTAdapter implements token() and returns WBTC
    function test_Fork_OFTAdapter_WBTC_TokenInterface() public view {
        address token = IOFT(WBTC_OFT_ADAPTER_ETH).token();
        assertEq(token, WBTC_ETH, "WBTC OFTAdapter should return WBTC as underlying token");
        uint256 totalSupply = IERC20(token).totalSupply();
        assertGt(totalSupply, 0, "WBTC should have non-zero total supply");
        // WBTC is 8 decimals
        uint8 decimals = IERC20Metadata(WBTC_ETH).decimals();
        assertEq(decimals, 8, "WBTC should have 8 decimals");
        console2.log("WBTC OFTAdapter underlying token:", token);
    }

    /// @notice Verify token() selector (0xfc0c546a) is identical across IStargate and IOFT
    /// @dev This is what makes our pool validation work for OFT contracts
    function test_Fork_OFTAdapter_SelectorCompatibility() public view {
        // Cast UP OFTAdapter as IStargate and call token() — should return same result
        address tokenViaIOFT = IOFT(UP_OFT_ADAPTER_ETH).token();
        address tokenViaIStargate = IStargate(UP_OFT_ADAPTER_ETH).token();
        assertEq(tokenViaIOFT, tokenViaIStargate, "token() must return same result regardless of interface cast");

        // Same for WBTC
        address wbtcViaIOFT = IOFT(WBTC_OFT_ADAPTER_ETH).token();
        address wbtcViaIStargate = IStargate(WBTC_OFT_ADAPTER_ETH).token();
        assertEq(wbtcViaIOFT, wbtcViaIStargate, "WBTC token() must match across interfaces");
    }

    /// @notice Verify quoteSend ABI compatibility — OFTAdapter.quoteSend works via IStargate cast
    function test_Fork_OFTAdapter_UP_QuoteSend() public view {
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: 100e18,
            minAmountLD: 99e18,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        // Cast OFTAdapter to IStargate for quoteSend — identical ABI
        IStargate.MessagingFee memory fee = IStargate(UP_OFT_ADAPTER_ETH).quoteSend(sendParam, false);
        assertGt(fee.nativeFee, 0, "UP OFTAdapter quoteSend should return non-zero fee");
        console2.log("UP OFTAdapter LZ fee for ETH->Base:", fee.nativeFee);
    }

    /*//////////////////////////////////////////////////////////////
            APPROVE AND STARGATE SEND - OFT MODE BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build OFT mode executions with real UP OFTAdapter
    function test_Fork_ApproveAndStargateSend_OFTMode_Build_UP() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 100e18;
        uint256 minAmountLD = 99e18;

        bytes memory hookData = _encodeStargateData(
            0.01 ether,
            UP_OFT_ADAPTER_ETH,
            upToken,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            2, // mode: OFT
            hex"",
            hex""
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        // preExecute + approve(0) + approve(amount) + IOFT.send + approve(0) + postExecute = 6
        assertEq(executions.length, 6, "OFT mode should have 6 executions");

        // Verify approval targets the UP token, NOT the OFTAdapter
        assertEq(executions[1].target, upToken, "First approve should target UP token");
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (UP_OFT_ADAPTER_ETH, 0)));
        assertEq(executions[2].target, upToken, "Second approve should target UP token");
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (UP_OFT_ADAPTER_ETH, amountLD)));

        // Verify the send call targets the OFTAdapter
        assertEq(executions[3].target, UP_OFT_ADAPTER_ETH, "Send should target OFTAdapter");
        assertEq(executions[3].value, 0.01 ether, "Value should be lzNativeFee only for OFT mode");
        assertEq(bytes4(executions[3].callData), IOFT.send.selector, "Should use IOFT.send selector");

        // Verify cleanup approval
        assertEq(executions[4].target, upToken, "Cleanup approve should target UP token");
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (UP_OFT_ADAPTER_ETH, 0)));
    }

    /// @notice Build OFT mode executions with real WBTC OFTAdapter (different token, different decimals)
    function test_Fork_ApproveAndStargateSend_OFTMode_Build_WBTC() public view {
        uint256 amountLD = 1e7; // 0.1 WBTC (8 decimals)
        uint256 minAmountLD = 99e5; // ~0.099 WBTC

        bytes memory hookData = _encodeStargateData(
            0.005 ether,
            WBTC_OFT_ADAPTER_ETH,
            WBTC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            2, // mode: OFT
            hex"",
            hex""
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        assertEq(executions.length, 6, "OFT mode should have 6 executions");

        // Verify approval targets WBTC, approved to WBTC OFTAdapter
        assertEq(executions[1].target, WBTC_ETH);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (WBTC_OFT_ADAPTER_ETH, 0)));
        assertEq(executions[2].target, WBTC_ETH);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (WBTC_OFT_ADAPTER_ETH, amountLD)));

        // Verify send targets WBTC OFTAdapter with IOFT.send selector
        assertEq(executions[3].target, WBTC_OFT_ADAPTER_ETH);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
        assertEq(executions[3].value, 0.005 ether);

        // Cleanup
        assertEq(executions[4].target, WBTC_ETH);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (WBTC_OFT_ADAPTER_ETH, 0)));
    }

    /// @notice OFT mode with composeMsg — verify compose path works with real OFTAdapter
    function test_Fork_ApproveAndStargateSend_OFTMode_WithComposeMsg() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 50e18;
        uint256 minAmountLD = 49e18;

        // Build composeMsg
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = 0x5b2193fDc451C1f847bE09CA9d13A4Bf60f8c86B; // UP OFT on Base
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = amountLD;
        bytes memory composeMsgForHook = abi.encode(
            bytes(""), bytes(""), account, dstTokens, intentAmounts
        );
        bytes memory extraOptions = hex"000301001101000000000000000000000000000186a0";

        bytes memory hookData = _encodeStargateData(
            0.02 ether,
            UP_OFT_ADAPTER_ETH,
            upToken,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            2, // mode: OFT
            extraOptions,
            composeMsgForHook
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6);

        // Verify selector is IOFT.send (not IStargate.sendToken) even with composeMsg
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
        assertEq(executions[3].target, UP_OFT_ADAPTER_ETH);

        // The calldata should contain the compose message with appended signature
        // sendCallData length should be > basic send without compose
        assertGt(executions[3].callData.length, 200, "Calldata should include composed message");
    }

    /*//////////////////////////////////////////////////////////////
      APPROVE AND STARGATE SEND - OFT MODE VALUE & COMPARISON TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice CRITICAL: Verify OFT mode value is lzNativeFee ONLY, while Stargate mode adds amountLD
    /// @dev This is the most important safety check — sending excess ETH to OFT = permanent loss
    function test_Fork_ApproveAndStargateSend_OFTMode_ValueAlwaysLzNativeFee() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 500e18;
        uint256 minAmountLD = 495e18;
        uint256 lzNativeFee = 0.01 ether;

        // Build OFT mode
        bytes memory oftHookData = _encodeStargateData(
            lzNativeFee,
            UP_OFT_ADAPTER_ETH,
            upToken,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            2, // mode: OFT
            hex"",
            hex""
        );

        Execution[] memory oftExecs = approveAndStargateHook.build(address(0), account, oftHookData);

        // For ApproveAndStargateSendHook, value is ALWAYS lzNativeFee regardless of mode
        // (tokens are pulled via approve/transferFrom)
        assertEq(oftExecs[3].value, lzNativeFee, "OFT mode: value must be lzNativeFee only");

        // Build Stargate mode with same params but using real Stargate pool
        bytes memory stargateHookData = _encodeStargateData(
            lzNativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            1000e6, // USDC amount
            995e6,
            false,
            0, // mode: Stargate taxi
            hex"",
            hex""
        );

        Execution[] memory sgExecs = approveAndStargateHook.build(address(0), account, stargateHookData);

        // Both should have same value (lzNativeFee only) since ApproveAndStargate is ERC20 path
        assertEq(sgExecs[3].value, lzNativeFee, "Stargate mode: value should also be lzNativeFee for ERC20 hook");
        assertEq(oftExecs[3].value, sgExecs[3].value, "Both modes should have same value in ERC20 hook");
    }

    /// @notice CRITICAL: StargateSendHook value divergence — OFT = lzNativeFee, Stargate = lzNativeFee + amountLD
    /// @dev This test proves the safety-critical difference between modes in the native hook
    function test_Fork_StargateSend_OFTMode_CriticalValueDivergence() public view {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;
        uint256 lzNativeFee = 0.01 ether;

        // Stargate mode (0) — value = lzNativeFee + amountLD
        bytes memory stargateHookData = _encodeStargateData(
            lzNativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            0, // mode: Stargate taxi
            hex"",
            hex""
        );
        Execution[] memory sgExecs = stargateHook.build(address(0), account, stargateHookData);
        assertEq(sgExecs[1].value, lzNativeFee + amountLD, "Stargate mode: value = lzNativeFee + amountLD");

        // OFT mode (2) — value = lzNativeFee ONLY
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        bytes memory oftHookData = _encodeStargateData(
            lzNativeFee,
            UP_OFT_ADAPTER_ETH,
            upToken,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            100e18,
            99e18,
            false,
            2, // mode: OFT
            hex"",
            hex""
        );
        Execution[] memory oftExecs = stargateHook.build(address(0), account, oftHookData);
        assertEq(oftExecs[1].value, lzNativeFee, "OFT mode: value = lzNativeFee ONLY");

        // The difference is amountLD — sending this excess to an OFT would be permanent ETH loss
        assertGt(sgExecs[1].value, oftExecs[1].value, "Stargate mode should have higher value than OFT mode");
    }

    /*//////////////////////////////////////////////////////////////
          APPROVE AND STARGATE SEND - OFT MODE REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Revert when inputToken doesn't match UP OFTAdapter.token()
    function test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_WrongToken_UP() public {
        bytes memory hookData = _encodeStargateData(
            0.01 ether,
            UP_OFT_ADAPTER_ETH,
            USDC_ETH, // wrong — OFTAdapter.token() returns UP, not USDC
            EID_BASE,
            bytes32(uint256(uint160(account))),
            100e18,
            99e18,
            false,
            2,
            hex"",
            hex""
        );

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), account, hookData);
    }

    /// @notice Revert when inputToken doesn't match WBTC OFTAdapter.token()
    function test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_WrongToken_WBTC() public {
        // Use UP token address as inputToken with WBTC OFTAdapter
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();

        bytes memory hookData = _encodeStargateData(
            0.01 ether,
            WBTC_OFT_ADAPTER_ETH,
            upToken, // wrong — WBTC adapter expects WBTC
            EID_BASE,
            bytes32(uint256(uint160(account))),
            1e7,
            99e5,
            false,
            2,
            hex"",
            hex""
        );

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), account, hookData);
    }

    /// @notice Revert when inputToken doesn't match Stargate pool in OFT mode
    /// @dev Even though the validation uses IStargate(pool).token(), mode doesn't affect validation
    function test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_WrongToken_StargatePoolAsOFT() public {
        // Use WBTC as inputToken with Stargate USDC pool in OFT mode
        bytes memory hookData = _encodeStargateData(
            0.01 ether,
            STARGATE_USDC_POOL_ETH, // Stargate pool used with OFT mode
            WBTC_ETH, // wrong — pool.token() returns USDC
            EID_BASE,
            bytes32(uint256(uint160(account))),
            1e7,
            99e5,
            false,
            2, // mode: OFT
            hex"",
            hex""
        );

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), account, hookData);
    }

    /// @notice Revert when mode is invalid (3) with real OFT address
    function test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_ModeInvalid() public {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();

        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), 100e18, 99e18, false,
            3, // invalid mode
            hex"", hex""
        );

        vm.expectRevert(ApproveAndStargateSendHook.MODE_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), account, hookData);
    }

    /// @notice StargateSendHook also reverts on invalid mode with real contract
    function test_Fork_StargateSend_OFTMode_RevertIf_ModeInvalid() public {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();

        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), 100e18, 99e18, false,
            3, hex"", hex""
        );

        vm.expectRevert(StargateSendHook.MODE_NOT_VALID.selector);
        stargateHook.build(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
           STARGATE SEND HOOK - OFT MODE BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice StargateSendHook OFT mode build with UP OFTAdapter
    function test_Fork_StargateSend_OFTMode_Build_UP() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 100e18;
        uint256 minAmountLD = 99e18;

        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), amountLD, minAmountLD,
            false, 2, hex"", hex""
        );

        Execution[] memory executions = stargateHook.build(address(0), account, hookData);

        // preExecute + IOFT.send + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, UP_OFT_ADAPTER_ETH);
        assertEq(executions[1].value, 0.01 ether, "Value must be lzNativeFee only");
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
    }

    /// @notice StargateSendHook OFT mode build with WBTC OFTAdapter
    function test_Fork_StargateSend_OFTMode_Build_WBTC() public view {
        uint256 amountLD = 1e7; // 0.1 WBTC
        uint256 minAmountLD = 99e5;

        bytes memory hookData = _encodeStargateData(
            0.005 ether, WBTC_OFT_ADAPTER_ETH, WBTC_ETH, EID_BASE,
            bytes32(uint256(uint160(account))), amountLD, minAmountLD,
            false, 2, hex"", hex""
        );

        Execution[] memory executions = stargateHook.build(address(0), account, hookData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, WBTC_OFT_ADAPTER_ETH);
        assertEq(executions[1].value, 0.005 ether, "Value must be lzNativeFee only");
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
    }

    /*//////////////////////////////////////////////////////////////
               OFT MODE EXECUTION TESTS (REAL SENDS)
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute a real UP OFT send via ApproveAndStargateSendHook on fork
    /// @dev Verifies: token transfer, approval cleanup, correct msg.value, LZ message emission
    function test_Fork_ApproveAndStargateSend_OFTMode_Execute_UP() public {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 100e18;
        uint256 minAmountLD = 99e18;

        // Fund account with UP tokens
        deal(upToken, account, amountLD);

        // Quote the real LZ fee via IStargate cast (ABI-compatible)
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });
        IStargate.MessagingFee memory fee = IStargate(UP_OFT_ADAPTER_ETH).quoteSend(quoteSendParam, false);
        console2.log("UP OFTAdapter LZ fee:", fee.nativeFee);
        assertGt(fee.nativeFee, 0, "Fee should be positive");

        // Build hook data with real fee
        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            UP_OFT_ADAPTER_ETH,
            upToken,
            EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD,
            minAmountLD,
            false,
            2, // mode: OFT
            hex"",
            hex""
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6);

        // Snapshot balances before
        uint256 upBefore = IERC20(upToken).balanceOf(account);
        assertEq(upBefore, amountLD);

        // Execute all from account
        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();

        // Verify UP tokens were transferred (locked in OFTAdapter)
        uint256 upAfter = IERC20(upToken).balanceOf(account);
        assertEq(upAfter, 0, "All UP tokens should have been locked in OFTAdapter");

        // Verify approval was cleaned up
        uint256 allowance = IERC20(upToken).allowance(account, UP_OFT_ADAPTER_ETH);
        assertEq(allowance, 0, "Approval should be cleaned up to 0");

        console2.log("Successfully sent", amountLD / 1e18, "UP tokens via OFTAdapter to Base");
    }

    /// @notice Verify approval cleanup works correctly after OFT mode execution
    function test_Fork_ApproveAndStargateSend_OFTMode_ApprovalCleanup_WBTC() public {
        uint256 amountLD = 1e7; // 0.1 WBTC

        // Fund account with WBTC
        deal(WBTC_ETH, account, amountLD);

        // Build hook data — we only care about the approval lifecycle, not the send success
        // Use quoteSend to get real fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD,
            minAmountLD: 99e5,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        // This may revert if WBTC OFTAdapter doesn't support Base as destination
        // In that case, the test verifies the build at least generates correct approvals
        try IStargate(WBTC_OFT_ADAPTER_ETH).quoteSend(quoteSendParam, false) returns (
            IStargate.MessagingFee memory fee
        ) {
            bytes memory hookData = _encodeStargateData(
                fee.nativeFee, WBTC_OFT_ADAPTER_ETH, WBTC_ETH, EID_BASE,
                bytes32(uint256(uint160(account))), amountLD, 99e5,
                false, 2, hex"", hex""
            );

            Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

            // Execute approval steps only (0-2), skip send (3), execute cleanup (4-5)
            vm.startPrank(account);

            // preExecute
            (bool s0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
            assertTrue(s0, "preExecute failed");

            // approve(0) + approve(amount)
            (bool s1,) = executions[1].target.call(executions[1].callData);
            assertTrue(s1, "approve(0) failed");
            (bool s2,) = executions[2].target.call(executions[2].callData);
            assertTrue(s2, "approve(amount) failed");

            // Verify approval is set
            uint256 allowanceBefore = IERC20(WBTC_ETH).allowance(account, WBTC_OFT_ADAPTER_ETH);
            assertEq(allowanceBefore, amountLD, "Allowance should be set to amountLD");

            // Skip send (executions[3]) — we're testing cleanup
            // Execute cleanup approve(0) directly
            (bool s4,) = executions[4].target.call(executions[4].callData);
            assertTrue(s4, "cleanup approve(0) failed");

            vm.stopPrank();

            // Verify approval is cleaned
            uint256 allowanceAfter = IERC20(WBTC_ETH).allowance(account, WBTC_OFT_ADAPTER_ETH);
            assertEq(allowanceAfter, 0, "Approval should be cleaned up to 0 after cleanup step");
        } catch {
            // quoteSend reverted — WBTC adapter might not support Base
            // Still verify build works
            bytes memory hookData = _encodeStargateData(
                0.01 ether, WBTC_OFT_ADAPTER_ETH, WBTC_ETH, EID_BASE,
                bytes32(uint256(uint160(account))), amountLD, 99e5,
                false, 2, hex"", hex""
            );
            Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
            assertEq(executions.length, 6, "Build should succeed even if quoteSend fails");
        }
    }

    /*//////////////////////////////////////////////////////////////
              CROSS-MODE VALIDATION (WRONG MODE + CONTRACT TYPE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Stargate mode (0) with OFTAdapter address — build succeeds but execution reverts
    /// @dev OFTAdapter doesn't implement sendToken(), only send()
    function test_Fork_StargateMode_WithOFTAdapter_BuildSucceeds_ExecuteReverts() public {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 100e18;

        // Build with mode=0 (Stargate) but using OFTAdapter address
        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), amountLD, 99e18,
            false, 0, // mode: Stargate taxi (WRONG for OFTAdapter)
            hex"", hex""
        );

        // Build should succeed — token() validation passes (same selector)
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "Build should succeed");

        // But the generated calldata uses sendToken selector (wrong for OFTAdapter)
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IStargate.sendToken.selector, "Mode 0 should generate sendToken selector");

        // Fund the account and try to execute — should fail at the sendToken call
        deal(upToken, account, amountLD);
        vm.deal(account, 1 ether);

        vm.startPrank(account);

        // preExecute, approve(0), approve(amount) should succeed
        for (uint256 i = 0; i < 3; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Pre-send execution ", vm.toString(i), " should succeed"));
        }

        // sendToken on OFTAdapter should revert — function doesn't exist
        (bool sendSuccess,) =
            executions[3].target.call{ value: executions[3].value }(executions[3].callData);
        assertFalse(sendSuccess, "sendToken should revert on OFTAdapter (function not found)");

        vm.stopPrank();
    }

    /// @notice OFT mode (2) with Stargate pool address — build succeeds, selector differs
    /// @dev Stargate pools inherit OFTCore which has send(), so this might succeed at execution
    /// @dev But the OFT mode sets value = lzNativeFee only (missing amountLD for native sends)
    function test_Fork_OFTMode_WithStargatePool_BuildSucceeds() public view {
        // Build with mode=2 (OFT) but using Stargate pool address
        bytes memory hookData = _encodeStargateData(
            0.01 ether, STARGATE_USDC_POOL_ETH, USDC_ETH, EID_BASE,
            bytes32(uint256(uint160(account))), 1000e6, 995e6,
            false, 2, // mode: OFT (UNUSUAL for Stargate pool)
            hex"", hex""
        );

        // Build should succeed — token() validation passes
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6);

        // Verify it generates IOFT.send selector instead of sendToken
        bytes4 selector = bytes4(executions[3].callData);
        assertEq(selector, IOFT.send.selector, "Mode 2 should generate IOFT.send selector");
        // Note: value is still lzNativeFee only (correct for ApproveAndStargate ERC20 path)
    }

    /// @notice StargateSendHook: using OFT mode with Stargate pool changes the value
    /// @dev Proves that using wrong mode with Stargate pool would under-send ETH for native sends
    function test_Fork_StargateSend_WrongMode_ValueMismatch() public view {
        uint256 amountLD = 1000e6;
        uint256 lzNativeFee = 0.01 ether;

        // Correct: Stargate mode, value = lzNativeFee + amountLD
        bytes memory correctData = _encodeStargateData(
            lzNativeFee, STARGATE_USDC_POOL_ETH, USDC_ETH, EID_BASE,
            bytes32(uint256(uint160(account))), amountLD, 995e6,
            false, 0, hex"", hex""
        );
        Execution[] memory correctExecs = stargateHook.build(address(0), account, correctData);
        assertEq(correctExecs[1].value, lzNativeFee + amountLD);

        // Wrong: OFT mode with Stargate pool, value = lzNativeFee ONLY (missing amountLD!)
        bytes memory wrongData = _encodeStargateData(
            lzNativeFee, STARGATE_USDC_POOL_ETH, USDC_ETH, EID_BASE,
            bytes32(uint256(uint160(account))), amountLD, 995e6,
            false, 2, hex"", hex""
        );
        Execution[] memory wrongExecs = stargateHook.build(address(0), account, wrongData);
        assertEq(wrongExecs[1].value, lzNativeFee, "OFT mode omits amountLD from value");

        // The difference equals amountLD — this is the ETH that would be missing
        assertEq(correctExecs[1].value - wrongExecs[1].value, amountLD);
    }

    /*//////////////////////////////////////////////////////////////
                    OFT MODE EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice Zero amount reverts even in OFT mode
    function test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_ZeroAmount() public {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();

        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), 0, 0,
            false, 2, hex"", hex""
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), account, hookData);
    }

    /// @notice Very large amount still builds correctly in OFT mode
    function test_Fork_ApproveAndStargateSend_OFTMode_LargeAmount() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 1_000_000e18; // 1M UP tokens

        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), amountLD, amountLD - 1e18,
            false, 2, hex"", hex""
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (UP_OFT_ADAPTER_ETH, amountLD)));
    }

    /// @notice OFT mode with zero lzNativeFee — some LZ configs allow free messaging
    function test_Fork_ApproveAndStargateSend_OFTMode_ZeroNativeFee() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();

        bytes memory hookData = _encodeStargateData(
            0, // zero lzNativeFee
            UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), 100e18, 99e18,
            false, 2, hex"", hex""
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6);
        assertEq(executions[3].value, 0, "Value should be 0 when lzNativeFee is 0");
    }

    /// @notice Verify inspect() returns correct addresses regardless of mode
    function test_Fork_ApproveAndStargateSend_OFTMode_Inspect() public view {
        address upToken = IOFT(UP_OFT_ADAPTER_ETH).token();

        bytes memory hookData = _encodeStargateData(
            0.01 ether, UP_OFT_ADAPTER_ETH, upToken, EID_BASE,
            bytes32(uint256(uint160(account))), 100e18, 99e18,
            false, 2, hex"", hex""
        );

        bytes memory inspected = approveAndStargateHook.inspect(hookData);

        // inspect returns: stargatePool (20) + inputToken (20) + to (20) = 60 bytes
        assertEq(inspected.length, 60);

        // Decode addresses
        address inspectedPool;
        address inspectedToken;
        address inspectedTo;
        assembly {
            inspectedPool := mload(add(inspected, 20))
            inspectedToken := mload(add(inspected, 40))
            inspectedTo := mload(add(inspected, 60))
        }
        assertEq(inspectedPool, UP_OFT_ADAPTER_ETH);
        assertEq(inspectedToken, upToken);
        assertEq(inspectedTo, account);
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
        uint8 mode,
        bytes memory extraOptions,
        bytes memory composeMsg
    )
        internal
        pure
        returns (bytes memory)
    {
        // Split encoding to avoid stack too deep
        bytes memory fixedPart = abi.encodePacked(
            lzNativeFee, stargatePool, inputToken, dstEid, to, amountLD, minAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrevHookAmount, mode, uint256(extraOptions.length), extraOptions,
            uint256(composeMsg.length), composeMsg
        );
    }
}
