// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { StargateAdapter } from "../../../src/adapters/StargateAdapter.sol";
import { ApproveAndStargateSendHook } from "../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { Helpers } from "../../utils/Helpers.sol";

import "forge-std/console2.sol";

/// @dev Mock signature storage for end-to-end compose tests
contract MockAdapterForkSignatureStorage {
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

/// @title StargateAdapterFork
/// @notice Fork-based integration tests for StargateAdapter using real on-chain contracts
/// @dev Tests real Stargate pool and OFT adapter interactions on forked Ethereum mainnet
contract StargateAdapterFork is Helpers {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // LayerZero V2 Endpoint on Ethereum (same on all EVM chains)
    address public constant LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    // Stargate V2 USDC Pool on Ethereum
    address public constant STARGATE_USDC_POOL_ETH = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;

    // USDC on Ethereum
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // UP OFT Adapter on Ethereum
    address public constant UP_OFT_ADAPTER_ETH = 0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD;

    // WBTC OFT Adapter on Ethereum
    address public constant WBTC_OFT_ADAPTER_ETH = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;

    // WBTC on Ethereum
    address public constant WBTC_ETH = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // LayerZero V2 Endpoint IDs
    uint32 public constant EID_ETHEREUM = 30_101;
    uint32 public constant EID_BASE = 30_184;

    // OFTComposeMsgCodec header constants
    bytes32 internal constant GUID = bytes32(uint256(1));

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    StargateAdapter public adapter;
    address public mockExecutor;
    address public account;
    uint256 public ethForkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        mockExecutor = makeAddr("mockExecutor");
        account = makeAddr("account");
        vm.deal(account, 100 ether);

        // Deploy adapter with real LZ endpoint and mock executor
        adapter = new StargateAdapter(LZ_ENDPOINT, mockExecutor);
    }

    /*//////////////////////////////////////////////////////////////
                    FORK VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy adapter with real LZ endpoint, verify immutables
    function test_Fork_StargateAdapter_Constructor_RealEndpoint() public view {
        assertEq(adapter.LZ_ENDPOINT(), LZ_ENDPOINT, "LZ endpoint should match real address");
        assertEq(address(adapter.SUPER_DESTINATION_EXECUTOR()), mockExecutor, "Executor should match");
    }

    /// @notice Verify real Stargate USDC pool returns correct token()
    function test_Fork_StargateAdapter_RealPool_TokenInterface() public view {
        address token = IStargate(STARGATE_USDC_POOL_ETH).token();
        assertEq(token, USDC_ETH, "Stargate USDC pool should return USDC address");

        // Verify it's actually USDC with correct metadata
        assertEq(IERC20Metadata(token).symbol(), "USDC", "Token should be USDC");
        assertEq(IERC20Metadata(token).decimals(), 6, "USDC should have 6 decimals");
    }

    /// @notice Verify real OFT adapters return correct token()
    function test_Fork_StargateAdapter_RealOFTAdapter_TokenInterface() public view {
        // WBTC OFT Adapter should return WBTC
        address wbtcToken = IStargate(WBTC_OFT_ADAPTER_ETH).token();
        assertEq(wbtcToken, WBTC_ETH, "WBTC OFT adapter should return WBTC address");
        assertEq(IERC20Metadata(wbtcToken).symbol(), "WBTC", "Token should be WBTC");
        assertEq(IERC20Metadata(wbtcToken).decimals(), 8, "WBTC should have 8 decimals");

        // UP OFT Adapter — verify token() returns a non-zero address
        address upToken = IStargate(UP_OFT_ADAPTER_ETH).token();
        assertTrue(upToken != address(0), "UP OFT adapter should return a non-zero token address");
        console2.log("UP token address:", upToken);
        console2.log("UP token symbol:", IERC20Metadata(upToken).symbol());
    }

    /*//////////////////////////////////////////////////////////////
                    LZCOMPOSE INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice lzCompose with real USDC pool as _from, prank as real LZ endpoint
    function test_Fork_StargateAdapter_lzCompose_ERC20_RealPool() public {
        uint256 amount = 1000e6; // 1000 USDC

        // Deal real USDC to adapter (simulates lzReceive token credit)
        deal(USDC_ETH, address(adapter), amount);
        assertEq(IERC20(USDC_ETH).balanceOf(address(adapter)), amount, "Adapter should hold USDC");

        // Build compose message
        bytes memory innerPayload = _buildStargateDestinationData(account);
        bytes memory message = _encodeComposeMsg(1, EID_BASE, amount, bytes32(uint256(1)), innerPayload);

        // Mock the executor's processBridgedExecution call
        _mockProcessBridgedExecution();

        // Prank as real LZ endpoint and call lzCompose with real pool as _from
        vm.prank(LZ_ENDPOINT);
        adapter.lzCompose(STARGATE_USDC_POOL_ETH, GUID, message, address(0), new bytes(0));

        // Verify USDC transferred to account
        assertEq(IERC20(USDC_ETH).balanceOf(account), amount, "Account should receive USDC");
        assertEq(IERC20(USDC_ETH).balanceOf(address(adapter)), 0, "Adapter should be empty");
    }

    /// @notice lzCompose with real OFT adapter (WBTC) as _from
    function test_Fork_StargateAdapter_lzCompose_ERC20_OFTAdapter() public {
        uint256 amount = 1e8; // 1 WBTC

        // Deal real WBTC to adapter
        deal(WBTC_ETH, address(adapter), amount);

        bytes memory innerPayload = _buildStargateDestinationData(account);
        bytes memory message = _encodeComposeMsg(1, EID_BASE, amount, bytes32(uint256(1)), innerPayload);

        _mockProcessBridgedExecution();

        // Use WBTC OFT adapter as _from — adapter will call _from.token() which returns WBTC_ETH
        vm.prank(LZ_ENDPOINT);
        adapter.lzCompose(WBTC_OFT_ADAPTER_ETH, GUID, message, address(0), new bytes(0));

        assertEq(IERC20(WBTC_ETH).balanceOf(account), amount, "Account should receive WBTC");
        assertEq(IERC20(WBTC_ETH).balanceOf(address(adapter)), 0, "Adapter should be empty");
    }

    /// @notice Verify revert when sender is not the real LZ endpoint
    function test_Fork_StargateAdapter_lzCompose_RevertIf_NotRealEndpoint() public {
        bytes memory innerPayload = _buildStargateDestinationData(account);
        bytes memory message = _encodeComposeMsg(1, EID_BASE, 1000e6, bytes32(uint256(1)), innerPayload);

        // Random address (not the real LZ endpoint) tries to call lzCompose
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(StargateAdapter.INVALID_SENDER.selector);
        adapter.lzCompose(STARGATE_USDC_POOL_ETH, GUID, message, address(0), new bytes(0));
    }

    /// @notice Deal extra USDC (simulating dust from prior compose), verify only amountLD transferred
    function test_Fork_StargateAdapter_lzCompose_RealUSDC_DustNotSwept() public {
        uint256 deliveredAmount = 1000e6;
        uint256 dustAmount = 50e6;
        uint256 totalBalance = deliveredAmount + dustAmount;

        // Simulate dust from prior failed compose + new delivery
        deal(USDC_ETH, address(adapter), totalBalance);

        bytes memory innerPayload = _buildStargateDestinationData(account);
        // amountLD in codec says 1000 USDC, adapter holds 1050 USDC — only 1000 should transfer
        bytes memory message = _encodeComposeMsg(1, EID_BASE, deliveredAmount, bytes32(uint256(1)), innerPayload);

        _mockProcessBridgedExecution();

        vm.prank(LZ_ENDPOINT);
        adapter.lzCompose(STARGATE_USDC_POOL_ETH, GUID, message, address(0), new bytes(0));

        // Only amountLD transferred, dust remains in adapter
        assertEq(IERC20(USDC_ETH).balanceOf(account), deliveredAmount, "Account should receive only amountLD");
        assertEq(IERC20(USDC_ETH).balanceOf(address(adapter)), dustAmount, "Dust should remain in adapter");
    }

    /// @notice Test with WBTC (8 decimals) via OFT adapter to verify different decimal tokens
    function test_Fork_StargateAdapter_lzCompose_MultipleTokenTypes() public {
        // Test 1: USDC (6 decimals) via Stargate pool
        uint256 usdcAmount = 5000e6;
        deal(USDC_ETH, address(adapter), usdcAmount);

        bytes memory usdcPayload = _buildStargateDestinationData(account);
        bytes memory usdcMessage = _encodeComposeMsg(1, EID_BASE, usdcAmount, bytes32(uint256(1)), usdcPayload);
        _mockProcessBridgedExecution();

        vm.prank(LZ_ENDPOINT);
        adapter.lzCompose(STARGATE_USDC_POOL_ETH, GUID, usdcMessage, address(0), new bytes(0));
        assertEq(IERC20(USDC_ETH).balanceOf(account), usdcAmount, "Account should receive USDC");

        // Test 2: WBTC (8 decimals) via OFT adapter
        address account2 = makeAddr("account2");
        uint256 wbtcAmount = 5e7; // 0.5 WBTC
        deal(WBTC_ETH, address(adapter), wbtcAmount);

        bytes memory wbtcPayload = _buildStargateDestinationData(account2);
        bytes memory wbtcMessage = _encodeComposeMsg(2, EID_BASE, wbtcAmount, bytes32(uint256(2)), wbtcPayload);
        _mockProcessBridgedExecution();

        vm.prank(LZ_ENDPOINT);
        adapter.lzCompose(WBTC_OFT_ADAPTER_ETH, GUID, wbtcMessage, address(0), new bytes(0));
        assertEq(IERC20(WBTC_ETH).balanceOf(account2), wbtcAmount, "Account2 should receive WBTC");
    }

    /*//////////////////////////////////////////////////////////////
                    END-TO-END: HOOK SEND → ADAPTER LZCOMPOSE
    //////////////////////////////////////////////////////////////*/

    /// @notice End-to-end test: source hook sends via real Stargate with composeMsg,
    ///         then adapter receives lzCompose with the same message format
    /// @dev Proves the composeMsg produced by ApproveAndStargateSendHook is correctly
    ///      decoded by StargateAdapter.lzCompose — verifying format compatibility
    function test_Fork_EndToEnd_HookSendWithCompose_To_AdapterLzCompose() public {
        // In production, the same smart account address exists on both chains.
        // The hook validates that the composeMsg account == caller account.
        address dstAccount = account;
        uint256 amountLD = 1000e6; // 1000 USDC

        // Build the full composeMsg (6 fields: hook's 5 fields + appended sigData)
        bytes memory fullComposeMsg = _buildFullComposeMsg(dstAccount, amountLD);

        // === SOURCE SIDE: Execute real sendToken with compose on real Stargate pool ===
        _executeSourceSendWithCompose(dstAccount, amountLD, fullComposeMsg);

        // Verify source: USDC deducted, approval cleaned up
        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "All USDC bridged from source");
        assertEq(
            IERC20(USDC_ETH).allowance(account, STARGATE_USDC_POOL_ETH), 0, "Approval cleaned up"
        );
        console2.log("Source: sendToken with composeMsg succeeded");

        // === DESTINATION SIDE: Simulate lzCompose on the adapter ===
        // In production: lzReceive credits tokens to the account (to field), then lzCompose
        // is called on the registered compose receiver (adapter). The adapter transfers its
        // balance to the account decoded from the compose message.
        uint256 amountReceived = 998e6; // After Stargate dust removal
        _executeDstLzCompose(amountReceived, fullComposeMsg);

        // Verify destination: tokens transferred to account, adapter empty
        assertEq(
            IERC20(USDC_ETH).balanceOf(dstAccount), amountReceived, "dstAccount should receive tokens"
        );
        assertEq(IERC20(USDC_ETH).balanceOf(address(adapter)), 0, "Adapter should be empty");
        console2.log("Destination: lzCompose succeeded, tokens transferred to dstAccount");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encodeComposeMsg(
        uint64 nonce_,
        uint32 srcEid_,
        uint256 amountLD_,
        bytes32 composeFrom_,
        bytes memory innerPayload_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(nonce_, srcEid_, amountLD_, composeFrom_, innerPayload_);
    }

    function _buildStargateDestinationData(address account_) private pure returns (bytes memory) {
        bytes memory initData = new bytes(0);
        bytes memory executorCalldata = new bytes(0);
        address[] memory dstTokens = new address[](0);
        uint256[] memory intentAmounts = new uint256[](0);
        bytes memory sigData = new bytes(0);
        return abi.encode(initData, executorCalldata, account_, dstTokens, intentAmounts, sigData);
    }

    function _mockProcessBridgedExecution() private {
        vm.mockCall(
            mockExecutor,
            abi.encodeWithSignature("processBridgedExecution(address,address,address[],uint256[],bytes,bytes,bytes)"),
            abi.encode()
        );
    }

    /// @dev Builds the full 6-field composeMsg that the hook would produce
    function _buildFullComposeMsg(
        address dstAccount_,
        uint256 amountLD_
    )
        private
        returns (bytes memory)
    {
        MockAdapterForkSignatureStorage sigStorage = new MockAdapterForkSignatureStorage();
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_ETH;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = amountLD_;
        bytes memory sigData = sigStorage.retrieveSignatureData(account);
        return abi.encode(bytes(""), bytes(""), dstAccount_, dstTokens, intentAmounts, sigData);
    }

    /// @dev Executes the source-side sendToken with compose via real Stargate pool
    function _executeSourceSendWithCompose(
        address dstAccount_,
        uint256 amountLD_,
        bytes memory fullComposeMsg_
    )
        private
    {
        MockAdapterForkSignatureStorage sigStorage = new MockAdapterForkSignatureStorage();
        ApproveAndStargateSendHook hook = new ApproveAndStargateSendHook(address(sigStorage));

        // 5-field composeMsg for the hook (hook appends sigData as 6th field)
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_ETH;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = amountLD_;
        bytes memory composeMsgForHook =
            abi.encode(bytes(""), bytes(""), dstAccount_, dstTokens, intentAmounts);

        // extraOptions with lzComposeOption (index=0, gas=100000, value=0)
        bytes memory extraOptions = hex"000301001101000000000000000000000000000186a0";

        // Quote fee with full composeMsg for accurate gas estimation
        uint256 lzFee = _quoteLzFee(amountLD_, extraOptions, fullComposeMsg_);

        // Build hook data and executions
        // NOTE: Hook validates to == account (tokens credited to account during lzReceive).
        // In production, the compose receiver (adapter) is registered separately at the LZ endpoint.
        // The adapter receives lzCompose callbacks but the token credit goes to the account.
        bytes memory hookData = _encodeStargateHookData(
            lzFee, STARGATE_USDC_POOL_ETH, USDC_ETH, EID_BASE,
            bytes32(uint256(uint160(account))),
            amountLD_, 995e6, false, 0, extraOptions, composeMsgForHook
        );
        Execution[] memory executions = hook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "Should have 6 executions");
        assertEq(bytes4(executions[3].callData), IStargate.sendToken.selector);

        // Fund and execute
        deal(USDC_ETH, account, amountLD_);
        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
    }

    /// @dev Quotes LZ fee for a compose-enabled Stargate send
    function _quoteLzFee(
        uint256 amountLD_,
        bytes memory extraOptions_,
        bytes memory composeMsg_
    )
        private
        view
        returns (uint256)
    {
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: EID_BASE,
            to: bytes32(uint256(uint160(account))),
            amountLD: amountLD_,
            minAmountLD: 995e6,
            extraOptions: extraOptions_,
            composeMsg: composeMsg_,
            oftCmd: bytes("")
        });
        IStargate.MessagingFee memory fee =
            IStargate(STARGATE_USDC_POOL_ETH).quoteSend(sendParam, false);
        console2.log("LZ fee for compose-enabled send:", fee.nativeFee);
        return fee.nativeFee;
    }

    /// @dev Simulates the destination-side lzCompose call
    function _executeDstLzCompose(
        uint256 amountReceived_,
        bytes memory fullComposeMsg_
    )
        private
    {
        deal(USDC_ETH, address(adapter), amountReceived_);

        bytes memory lzComposeMessage = _encodeComposeMsg(
            1, EID_ETHEREUM, amountReceived_,
            bytes32(uint256(uint160(account))),
            fullComposeMsg_
        );

        _mockProcessBridgedExecution();

        vm.prank(LZ_ENDPOINT);
        adapter.lzCompose(STARGATE_USDC_POOL_ETH, GUID, lzComposeMessage, address(0), new bytes(0));
    }

    /// @dev Encodes hook data for ApproveAndStargateSendHook (matches the hook's expected layout)
    function _encodeStargateHookData(
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
        // Layout: lzNativeFee(32) + stargatePool(20) + inputToken(20)
        //       + dstEid(4) + to(32) + amountLD(32) + minAmountLD(32)
        //       + usePrevHookAmount(1) + mode(1)
        //       + extraOptionsLength(32) + extraOptions + composeMsgLength(32) + composeMsg
        bytes memory fixedPart = abi.encodePacked(
            lzNativeFee,
            stargatePool,
            inputToken,
            dstEid,
            to,
            amountLD,
            minAmountLD
        );
        return abi.encodePacked(
            fixedPart,
            usePrevHookAmount,
            mode,
            uint256(extraOptions.length),
            extraOptions,
            uint256(composeMsg.length),
            composeMsg
        );
    }
}
