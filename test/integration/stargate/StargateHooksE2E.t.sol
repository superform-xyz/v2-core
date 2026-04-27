// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, Vm } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StargateV2SendHook } from "../../../src/hooks/bridges/stargate/StargateV2SendHook.sol";
import { ApproveAndStargateV2SendHook } from
    "../../../src/hooks/bridges/stargate/ApproveAndStargateV2SendHook.sol";
import { IOFT, SendParam, MessagingFee, OFTReceipt } from "../../../src/vendor/bridges/stargate/IOFT.sol";
import { LayerZeroV2Helper } from "@pigeon/layerzero-v2/LayerZeroV2Helper.sol";

/// @dev Mock validator that returns empty signature data (composeMsg is empty in these tests)
contract MockValidator {
    function retrieveSignatureData(address) external pure returns (bytes memory) {
        return "";
    }
}

/// @title StargateHooksE2E
/// @notice Fork integration tests for Stargate V2 bridge hooks — USDC bridging ETH → Base
/// @dev Uses real Stargate V2 pools on Ethereum and Base mainnet
contract StargateHooksE2E is Test {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Stargate V2 USDC Pool on Ethereum (implements IOFT)
    address constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;

    // Stargate V2 USDC Pool on Base
    address constant STARGATE_USDC_POOL_BASE = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;

    // LayerZero endpoint (same address on all chains)
    address constant LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    // LayerZero endpoint IDs
    uint32 constant ETH_EID = 30_101;
    uint32 constant BASE_EID = 30_184;

    // USDC
    address constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Test amounts
    uint256 constant BRIDGE_AMOUNT = 100e6; // 100 USDC

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ApproveAndStargateV2SendHook public approveAndStargateHook;
    StargateV2SendHook public stargateHook;
    MockValidator public mockValidator;
    LayerZeroV2Helper public lzHelper;

    address public account;
    address public recipient;

    uint256 public ethForkId;
    uint256 public baseForkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        ethForkId = vm.createFork(vm.envString("ETHEREUM_RPC_URL"));
        baseForkId = vm.createFork(vm.envString("BASE_RPC_URL"));

        // Deploy before selecting any fork — contracts are automatically persistent
        account = address(this);
        recipient = makeAddr("recipient");
        mockValidator = new MockValidator();
        lzHelper = new LayerZeroV2Helper();

        vm.selectFork(ethForkId);

        approveAndStargateHook = new ApproveAndStargateV2SendHook(address(mockValidator));
        stargateHook = new StargateV2SendHook(address(mockValidator));
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Quote the native fee for sending via Stargate
    function _quoteFee(uint32 dstEid, address to, uint256 amountLD) internal view returns (uint256 nativeFee) {
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(to))),
            amountLD: amountLD,
            minAmountLD: (amountLD * 99) / 100,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = IOFT(STARGATE_USDC_POOL_ETH).quoteSend(sendParam, false);
        return fee.nativeFee;
    }

    /// @dev Encode hook data for Stargate V2 hooks (217+ bytes)
    function _encodeStargateHookData(
        address oftContract,
        uint256 value,
        uint32 dstEid,
        address to,
        uint256 amountLD,
        uint256 minAmountLD,
        uint256 nativeFee,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        // Fixed fields (217 bytes)
        bytes memory fixedFields = abi.encodePacked(
            oftContract, // address oftContract (offset 0, 20 bytes)
            value, // uint256 value (offset 20)
            dstEid, // uint32 dstEid (offset 52)
            bytes32(uint256(uint160(to))), // bytes32 to (offset 56)
            amountLD, // uint256 amountLD (offset 88)
            minAmountLD, // uint256 minAmountLD (offset 120)
            nativeFee, // uint256 nativeFee (offset 152)
            uint256(0), // uint256 lzTokenFee (offset 184)
            usePrevHookAmount // bool usePrevHookAmount (offset 216)
        );

        // Variable-length fields (all empty)
        bytes memory variableFields = abi.encodePacked(
            uint256(0), // extraOptions length
            uint256(0), // composeMsg length
            uint256(0) // oftCmd length
        );

        return abi.encodePacked(fixedFields, variableFields);
    }

    /// @dev Execute all executions sequentially, return true if all succeed
    function _tryExecuteAll(Execution[] memory executions) internal returns (bool) {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) return false;
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
              E2E: ApproveAndStargateV2 USDC ETH → Base
    //////////////////////////////////////////////////////////////*/

    /// @notice Bridge USDC ETH → Base via ApproveAndStargateV2SendHook on real Stargate pool
    function test_E2E_ApproveAndStargateV2_USDC_ETH_to_Base() public {
        vm.selectFork(ethForkId);

        deal(USDC_ETH, account, BRIDGE_AMOUNT);
        uint256 nativeFee = _quoteFee(BASE_EID, recipient, BRIDGE_AMOUNT);
        vm.deal(account, nativeFee);

        bytes memory hookData = _encodeStargateHookData(
            STARGATE_USDC_POOL_ETH,
            nativeFee, // value = nativeFee (sent as msg.value with the send call)
            BASE_EID,
            recipient,
            BRIDGE_AMOUNT,
            (BRIDGE_AMOUNT * 99) / 100, // 1% slippage
            nativeFee,
            false
        );

        uint256 usdcBefore = IERC20(USDC_ETH).balanceOf(account);

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + send + approve(0) + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "ApproveAndStargateV2 USDC bridge should succeed");

        uint256 usdcAfter = IERC20(USDC_ETH).balanceOf(account);
        assertEq(usdcAfter, usdcBefore - BRIDGE_AMOUNT, "should spend all USDC");

        // Verify allowance cleaned up
        uint256 allowance = IERC20(USDC_ETH).allowance(account, STARGATE_USDC_POOL_ETH);
        assertEq(allowance, 0, "allowance should be cleaned up to 0");

        console2.log("USDC bridged:", BRIDGE_AMOUNT);
        console2.log("Native fee paid:", nativeFee);
    }

    /*//////////////////////////////////////////////////////////////
              E2E: StargateV2 USDC Pre-Approved
    //////////////////////////////////////////////////////////////*/

    /// @notice Bridge USDC with pre-approval via StargateV2SendHook
    function test_E2E_StargateV2_USDC_PreApproved() public {
        vm.selectFork(ethForkId);

        deal(USDC_ETH, account, BRIDGE_AMOUNT);
        uint256 nativeFee = _quoteFee(BASE_EID, recipient, BRIDGE_AMOUNT);
        vm.deal(account, nativeFee);

        // Pre-approve USDC to the Stargate pool
        IERC20(USDC_ETH).approve(STARGATE_USDC_POOL_ETH, BRIDGE_AMOUNT);

        bytes memory hookData = _encodeStargateHookData(
            STARGATE_USDC_POOL_ETH,
            nativeFee,
            BASE_EID,
            recipient,
            BRIDGE_AMOUNT,
            (BRIDGE_AMOUNT * 99) / 100,
            nativeFee,
            false
        );

        uint256 usdcBefore = IERC20(USDC_ETH).balanceOf(account);

        Execution[] memory executions = stargateHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "pre + send + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "StargateV2 USDC pre-approved bridge should succeed");

        uint256 usdcAfter = IERC20(USDC_ETH).balanceOf(account);
        assertEq(usdcAfter, usdcBefore - BRIDGE_AMOUNT, "should spend all USDC");

        console2.log("USDC bridged (pre-approved):", BRIDGE_AMOUNT);
        console2.log("Native fee paid:", nativeFee);
    }

    /*//////////////////////////////////////////////////////////////
              E2E: Quote Fee Accuracy
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify that quoted fee is sufficient (no revert)
    function test_E2E_ApproveAndStargateV2_QuoteFeeAndSend() public {
        vm.selectFork(ethForkId);

        deal(USDC_ETH, account, BRIDGE_AMOUNT);
        uint256 nativeFee = _quoteFee(BASE_EID, recipient, BRIDGE_AMOUNT);

        // Provide exactly the quoted fee — should be sufficient
        vm.deal(account, nativeFee);

        bytes memory hookData = _encodeStargateHookData(
            STARGATE_USDC_POOL_ETH,
            nativeFee,
            BASE_EID,
            recipient,
            BRIDGE_AMOUNT,
            (BRIDGE_AMOUNT * 99) / 100,
            nativeFee,
            false
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "Quoted fee should be sufficient for bridge");
    }

    /*//////////////////////////////////////////////////////////////
              E2E: Insufficient Fee Revert
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify that zero fee causes revert during execution
    function test_E2E_ApproveAndStargateV2_RevertIf_InsufficientFee() public {
        vm.selectFork(ethForkId);

        deal(USDC_ETH, account, BRIDGE_AMOUNT);
        vm.deal(account, 0);

        bytes memory hookData = _encodeStargateHookData(
            STARGATE_USDC_POOL_ETH,
            0, // value = 0 (no ETH sent for fee)
            BASE_EID,
            recipient,
            BRIDGE_AMOUNT,
            (BRIDGE_AMOUNT * 99) / 100,
            0, // nativeFee = 0
            false
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), account, hookData);

        bool success = _tryExecuteAll(executions);
        assertFalse(success, "Should fail with insufficient fee");
    }

    /*//////////////////////////////////////////////////////////////
              E2E: Cross-chain Relay via Pigeon (ETH → Base)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full E2E: bridge USDC ETH → Base via Stargate pool, relay with Pigeon, verify on Base
    function test_E2E_StargateV2_USDC_CrossChain_ETH_to_Base() public {
        // --- Source chain: Ethereum ---
        vm.selectFork(ethForkId);

        deal(USDC_ETH, account, BRIDGE_AMOUNT);

        SendParam memory sendParam = SendParam({
            dstEid: BASE_EID,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: BRIDGE_AMOUNT,
            minAmountLD: (BRIDGE_AMOUNT * 99) / 100,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = IOFT(STARGATE_USDC_POOL_ETH).quoteSend(sendParam, false);
        vm.deal(account, fee.nativeFee);

        IERC20(USDC_ETH).approve(STARGATE_USDC_POOL_ETH, BRIDGE_AMOUNT);

        vm.recordLogs();

        (, OFTReceipt memory oftReceipt) =
            IOFT(STARGATE_USDC_POOL_ETH).send{ value: fee.nativeFee }(sendParam, fee, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 usdcAfterSrc = IERC20(USDC_ETH).balanceOf(account);
        assertEq(usdcAfterSrc, 0, "should spend all USDC on source");

        console2.log("Amount sent:", oftReceipt.amountSentLD);
        console2.log("Amount to receive:", oftReceipt.amountReceivedLD);

        // --- Destination chain: Base ---
        vm.selectFork(baseForkId);

        uint256 recipientBefore = IERC20(USDC_BASE).balanceOf(recipient);

        lzHelper.help(LZ_ENDPOINT, baseForkId, logs);

        uint256 recipientAfter = IERC20(USDC_BASE).balanceOf(recipient);
        assertGt(recipientAfter, recipientBefore, "recipient should receive USDC on Base");
        assertEq(
            recipientAfter - recipientBefore,
            oftReceipt.amountReceivedLD,
            "received amount should match OFT receipt"
        );

        console2.log("Recipient USDC on Base:", recipientAfter - recipientBefore);
    }
}
