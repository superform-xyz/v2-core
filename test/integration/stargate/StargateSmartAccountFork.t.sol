// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ApproveAndStargateSendHook } from "../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { StargateSendHook } from "../../../src/hooks/bridges/stargate/StargateSendHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { LayerZeroV2Helper } from "../../../lib/pigeon/src/layerzero-v2/LayerZeroV2Helper.sol";
import { MinimalBaseNexusIntegrationTest } from "../MinimalBaseNexusIntegrationTest.t.sol";

import { Vm } from "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @dev Mock signature storage for smart account tests
contract SmartAccountMockSignatureStorage {
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

/// @title StargateSmartAccountFork
/// @notice Integration test: execute Stargate bridge hook through a Nexus smart account via EntryPoint
/// @dev Tests the full ERC-4337 flow: UserOp → EntryPoint → Nexus → SuperExecutor → Hook → Stargate
contract StargateSmartAccountFork is MinimalBaseNexusIntegrationTest {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Stargate V2 USDC Pool on Ethereum mainnet
    address public constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;

    // USDC on Ethereum
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // LayerZero V2 Endpoint on Base
    address public constant LZ_ENDPOINT_BASE = 0x1a44076050125825900e736c501f859c50fE728c;

    // LayerZero V2 Endpoint IDs
    uint32 public constant EID_BASE = 30_184;

    // USDC on Base
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // LayerZero ZRO token on Ethereum
    address public constant LZ_TOKEN_ETH = 0x6985884C4392D348587B19cb9eAAf157F13271cd;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    ApproveAndStargateSendHook public approveAndStargateHook;
    SmartAccountMockSignatureStorage public mockSignatureStorage;
    LayerZeroV2Helper public lzHelper;

    address public smartAccount;
    uint256 public ethForkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Override blockNumber for reproducible fork
        blockNumber = 21_929_476;
        super.setUp();

        ethForkId = vm.activeFork();

        // Deploy mock signature storage and hooks
        mockSignatureStorage = new SmartAccountMockSignatureStorage();
        approveAndStargateHook = new ApproveAndStargateSendHook(address(mockSignatureStorage));
        lzHelper = new LayerZeroV2Helper();

        // Create Nexus smart account with SuperValidator + SuperExecutor
        address[] memory attesters = new address[](0);
        smartAccount = _createWithNexus(attesters, 0, 10 ether);
        vm.label(smartAccount, "SmartAccount");
    }

    /*//////////////////////////////////////////////////////////////
                    SMART ACCOUNT EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute ERC20 Stargate bridge through smart account via EntryPoint UserOp
    function test_Fork_SmartAccount_ApproveAndStargateSend_USDC_EthToBase() public {
        uint256 amountLD = 1000e6; // 1000 USDC
        uint256 minAmountLD = 995e6; // 0.5% slippage

        // Fund the smart account with USDC
        deal(USDC_ETH, smartAccount, amountLD);
        // Fund with ETH for LZ fee (account already has 10 ETH from creation)

        // Quote the real LZ fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(smartAccount))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);
        console2.log("LZ fee for smart account bridge:", fee.nativeFee);

        // Build hook data
        bytes memory hookData = _encodeStargateData(
            fee.nativeFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            EID_BASE,
            bytes32(uint256(uint160(smartAccount))),
            amountLD,
            minAmountLD,
            false, // usePrevHookAmount
            false, // isBusMode (taxi)
            hex"", // extraOptions
            hex"" // no composeMsg
        );

        // Create ExecutorEntry with the hook
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveAndStargateHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData
        });

        // Verify initial state
        uint256 usdcBefore = IERC20(USDC_ETH).balanceOf(smartAccount);
        assertEq(usdcBefore, amountLD, "Smart account should have USDC");

        // Execute through EntryPoint → Nexus → SuperExecutor → Hook → Stargate
        _executeThroughEntrypoint(smartAccount, entry);

        // Verify USDC was bridged from smart account
        uint256 usdcAfter = IERC20(USDC_ETH).balanceOf(smartAccount);
        assertEq(usdcAfter, 0, "All USDC should have been bridged from smart account");

        // Verify approval was cleaned up
        uint256 allowance = IERC20(USDC_ETH).allowance(smartAccount, STARGATE_USDC_POOL_ETH);
        assertEq(allowance, 0, "Approval should be cleaned up after bridge");

        console2.log("Successfully bridged 1000 USDC via smart account through EntryPoint");
    }

    /// @notice Full cross-chain test: smart account bridges USDC from ETH to Base with pigeon relay
    function test_Fork_SmartAccount_CrossChain_USDC_EthToBase_WithPigeon() public {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;

        // Create Base fork
        uint256 baseForkId = vm.createFork(vm.envString("BASE_RPC_URL"));

        // Switch back to ETH fork
        vm.selectFork(ethForkId);

        // Fund the smart account with USDC
        deal(USDC_ETH, smartAccount, amountLD);

        // Quote fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(smartAccount))),
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
            bytes32(uint256(uint160(smartAccount))),
            amountLD,
            minAmountLD,
            false,
            false,
            hex"",
            hex""
        );

        // Create ExecutorEntry
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(approveAndStargateHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData
        });

        // Record logs for pigeon relay
        vm.recordLogs();

        // Execute through EntryPoint
        _executeThroughEntrypoint(smartAccount, entry);

        // Verify source chain: USDC deducted
        uint256 usdcAfterSrc = IERC20(USDC_ETH).balanceOf(smartAccount);
        assertEq(usdcAfterSrc, 0, "All USDC should be bridged from source");

        // Get logs for LZ message relay
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Use pigeon to relay the LayerZero message to Base fork
        lzHelper.help(LZ_ENDPOINT_BASE, baseForkId, logs);

        // Switch to Base and verify receipt
        vm.selectFork(baseForkId);

        uint256 baseBalance = IERC20(USDC_BASE).balanceOf(smartAccount);
        console2.log("USDC received on Base by smart account:", baseBalance);
        assertGe(baseBalance, minAmountLD, "Should receive at least minAmountLD on Base");

        // Switch back to ETH fork
        vm.selectFork(ethForkId);
    }

    /// @notice Verify hook generates correct execution structure with LZ token fee path
    /// @dev LZ token payment is not available on Ethereum mainnet (endpoint.lzToken == address(0))
    /// @dev so we test the hook's execution generation logic directly
    function test_Fork_SmartAccount_ApproveAndStargateSend_LzTokenFee_ExecutionStructure() public {
        uint256 amountLD = 1000e6;
        uint256 minAmountLD = 995e6;
        uint256 lzTokenFee = 1e18; // 1 ZRO token

        // Quote the native fee (still needed even when paying LZ token)
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(smartAccount))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);

        // Build hook data WITH LZ token fee
        bytes memory hookData = _encodeStargateDataWithLzToken(
            fee.nativeFee,
            lzTokenFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            LZ_TOKEN_ETH,
            EID_BASE,
            bytes32(uint256(uint160(smartAccount))),
            amountLD,
            minAmountLD,
            false,
            false,
            hex"",
            hex""
        );

        // Build executions - verifies hook logic generates correct structure
        Execution[] memory executions = approveAndStargateHook.build(address(0), smartAccount, hookData);

        // With LZ token fee: pre + 7 hook executions + post = 9 total
        assertEq(executions.length, 9, "Should have 9 executions (pre + 7 hook + post)");

        // Execution 1: Reset input token approval to 0
        assertEq(executions[1].target, USDC_ETH);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        // Execution 2: Approve input token amount
        assertEq(executions[2].target, USDC_ETH);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, amountLD)));

        // Execution 3: Reset LZ token approval to 0
        assertEq(executions[3].target, LZ_TOKEN_ETH);
        assertEq(executions[3].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        // Execution 4: Approve LZ token fee amount
        assertEq(executions[4].target, LZ_TOKEN_ETH);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, lzTokenFee)));

        // Execution 5: sendToken call
        assertEq(executions[5].target, STARGATE_USDC_POOL_ETH);
        assertEq(executions[5].value, fee.nativeFee, "Value should be lzNativeFee only");
        assertEq(bytes4(executions[5].callData), IStargate.sendToken.selector);

        // Execution 6: Cleanup LZ token approval to 0
        assertEq(executions[6].target, LZ_TOKEN_ETH);
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        // Execution 7: Cleanup input token approval to 0
        assertEq(executions[7].target, USDC_ETH);
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        console2.log("LZ token fee path generates correct 7-execution structure");
    }


    /// @notice Verify StargateSendHook (native) generates correct structure with LZ token fee
    function test_Fork_SmartAccount_StargateSend_LzTokenFee_ExecutionStructure() public {
        uint256 amountLD = 1 ether;
        uint256 minAmountLD = 0.995 ether;
        uint256 lzTokenFee = 1e18;

        StargateSendHook stargateHook = new StargateSendHook(address(mockSignatureStorage));

        // Quote fee
        IStargate.SendParam memory quoteSendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(smartAccount))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(STARGATE_USDC_POOL_ETH).quoteSend(quoteSendParam, false);

        // Build hook data with LZ token fee (StargateSendHook = native variant)
        bytes memory hookData = _encodeStargateDataWithLzToken(
            fee.nativeFee,
            lzTokenFee,
            STARGATE_USDC_POOL_ETH,
            USDC_ETH,
            LZ_TOKEN_ETH,
            EID_BASE,
            bytes32(uint256(uint160(smartAccount))),
            amountLD,
            minAmountLD,
            false,
            false,
            hex"",
            hex""
        );

        // Build executions
        Execution[] memory executions = stargateHook.build(address(0), smartAccount, hookData);

        // With LZ token fee on native hook: pre + 4 hook executions + post = 6 total
        assertEq(executions.length, 6, "Should have 6 executions (pre + 4 hook + post)");

        // Execution 1: Reset LZ token approval to 0
        assertEq(executions[1].target, LZ_TOKEN_ETH);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        // Execution 2: Approve LZ token fee
        assertEq(executions[2].target, LZ_TOKEN_ETH);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, lzTokenFee)));

        // Execution 3: sendToken (value = lzNativeFee + amountLD for native)
        assertEq(executions[3].target, STARGATE_USDC_POOL_ETH);
        assertEq(executions[3].value, fee.nativeFee + amountLD);
        assertEq(bytes4(executions[3].callData), IStargate.sendToken.selector);

        // Execution 4: Cleanup LZ token approval to 0
        assertEq(executions[4].target, LZ_TOKEN_ETH);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (STARGATE_USDC_POOL_ETH, 0)));

        console2.log("StargateSendHook LZ token fee path generates correct 4-execution structure");
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
