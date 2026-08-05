// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ModuleKitHelpers, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { FeeSplittingHook } from "../../../src/hooks/tokens/FeeSplittingHook.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";

/// @title FeeSplittingHookIntegrationTest
/// @notice Fork integration tests for FeeSplittingHook executed through the real
///         ERC-4337 flow (smart account + SuperExecutor + entrypoint)
contract FeeSplittingHookIntegrationTest is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    FeeSplittingHook public feeSplittingHook;

    address public recipient1;
    address public recipient2;
    address public recipient3;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        feeSplittingHook = new FeeSplittingHook(NATIVE_TOKEN);

        recipient1 = makeAddr("feeRecipient1");
        recipient2 = makeAddr("feeRecipient2");
        recipient3 = makeAddr("feeRecipient3");

        vm.deal(accountEth, 10 ether);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Two ERC20 tokens split to two different receivers in one userOp
    function test_FeeSplit_ERC20TwoTokensTwoReceivers() public {
        uint256 usdcAmount = 1000e6;
        uint256 wethAmount = 1e18;
        deal(CHAIN_1_USDC, accountEth, usdcAmount);
        deal(CHAIN_1_WETH, accountEth, wethAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = CHAIN_1_USDC;
        tokens[1] = CHAIN_1_WETH;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = wethAmount;
        address[] memory receivers = new address[](2);
        receivers[0] = recipient1;
        receivers[1] = recipient2;

        _executeFeeSplit(tokens, amounts, receivers);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient1), usdcAmount, "Recipient1 should receive USDC");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(recipient2), wethAmount, "Recipient2 should receive WETH");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient2), 0, "Recipient2 should not receive USDC");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(recipient1), 0, "Recipient1 should not receive WETH");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), 0, "Account USDC should be fully split");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(accountEth), 0, "Account WETH should be fully split");
    }

    /// @notice Realistic fee split: one token split across three receivers with different shares
    function test_FeeSplit_SameTokenThreeReceivers() public {
        uint256 totalFee = 1000e6;
        deal(CHAIN_1_USDC, accountEth, totalFee);

        address[] memory tokens = new address[](3);
        tokens[0] = CHAIN_1_USDC;
        tokens[1] = CHAIN_1_USDC;
        tokens[2] = CHAIN_1_USDC;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 700e6; // 70%
        amounts[1] = 200e6; // 20%
        amounts[2] = 100e6; // 10%
        address[] memory receivers = new address[](3);
        receivers[0] = recipient1;
        receivers[1] = recipient2;
        receivers[2] = recipient3;

        _executeFeeSplit(tokens, amounts, receivers);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient1), 700e6, "Recipient1 should receive 70%");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient2), 200e6, "Recipient2 should receive 20%");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient3), 100e6, "Recipient3 should receive 10%");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), 0, "Account USDC should be fully split");
    }

    /// @notice Native ETH split to two receivers
    function test_FeeSplit_NativeToken() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 0.5 ether;

        address[] memory tokens = new address[](2);
        tokens[0] = NATIVE_TOKEN;
        tokens[1] = NATIVE_TOKEN;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        address[] memory receivers = new address[](2);
        receivers[0] = recipient1;
        receivers[1] = recipient2;

        _executeFeeSplit(tokens, amounts, receivers);

        assertEq(recipient1.balance, amount1, "Recipient1 should receive ETH");
        assertEq(recipient2.balance, amount2, "Recipient2 should receive ETH");
    }

    /// @notice Mixed ERC20 + native split, each entry to a distinct receiver
    function test_FeeSplit_MixedTokens() public {
        uint256 usdcAmount = 500e6;
        uint256 nativeAmount = 1 ether;
        uint256 wethAmount = 2e18;
        deal(CHAIN_1_USDC, accountEth, usdcAmount);
        deal(CHAIN_1_WETH, accountEth, wethAmount);

        address[] memory tokens = new address[](3);
        tokens[0] = CHAIN_1_USDC;
        tokens[1] = NATIVE_TOKEN;
        tokens[2] = CHAIN_1_WETH;
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = usdcAmount;
        amounts[1] = nativeAmount;
        amounts[2] = wethAmount;
        address[] memory receivers = new address[](3);
        receivers[0] = recipient1;
        receivers[1] = recipient2;
        receivers[2] = recipient3;

        _executeFeeSplit(tokens, amounts, receivers);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient1), usdcAmount, "Recipient1 should receive USDC");
        assertEq(recipient2.balance, nativeAmount, "Recipient2 should receive ETH");
        assertEq(IERC20(CHAIN_1_WETH).balanceOf(recipient3), wethAmount, "Recipient3 should receive WETH");
    }

    /// @notice Fee split composed with a real vault deposit in the same userOp:
    ///         approve + deposit into ERC4626 vault, then split USDC fees to two receivers
    function test_FeeSplit_ChainedAfterVaultDeposit() public {
        uint256 depositAmount = 1e8;
        uint256 fee1 = 2e6;
        uint256 fee2 = 1e6;
        deal(CHAIN_1_USDC, accountEth, depositAmount + fee1 + fee2);

        address[] memory splitTokens = new address[](2);
        splitTokens[0] = CHAIN_1_USDC;
        splitTokens[1] = CHAIN_1_USDC;
        uint256[] memory splitAmounts = new uint256[](2);
        splitAmounts[0] = fee1;
        splitAmounts[1] = fee2;
        address[] memory splitReceivers = new address[](2);
        splitReceivers[0] = recipient1;
        splitReceivers[1] = recipient2;

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveAndDeposit4626Hook;
        hooksAddresses[1] = address(feeSplittingHook);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveAndDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSourceAddressEth,
            underlyingEth_USDC,
            depositAmount,
            false,
            address(0),
            0
        );
        hooksData[1] = _createFeeSplitHookData(splitTokens, splitAmounts, splitReceivers);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        assertGt(vaultInstanceEth.balanceOf(accountEth), 0, "Account should hold vault shares");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient1), fee1, "Recipient1 should receive fee1");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient2), fee2, "Recipient2 should receive fee2");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), 0, "Account USDC should be fully consumed");
    }

    /// @notice Mismatched array lengths must revert the userOp execution
    function test_FeeSplit_RevertIf_LengthMismatch() public {
        uint256 usdcAmount = 100e6;
        deal(CHAIN_1_USDC, accountEth, usdcAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = CHAIN_1_USDC;
        tokens[1] = CHAIN_1_USDC;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount / 2;
        amounts[1] = usdcAmount / 2;
        address[] memory receivers = new address[](1); // one less than tokens/amounts
        receivers[0] = recipient1;

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(feeSplittingHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createFeeSplitHookData(tokens, amounts, receivers);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        instanceOnEth.expect4337Revert();
        executeOp(userOpData);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(recipient1), 0, "No tokens should move on revert");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcAmount, "Account keeps its tokens on revert");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeFeeSplit(
        address[] memory tokens,
        uint256[] memory amounts,
        address[] memory receivers
    )
        internal
    {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(feeSplittingHook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createFeeSplitHookData(tokens, amounts, receivers);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function _createFeeSplitHookData(
        address[] memory tokens,
        uint256[] memory amounts,
        address[] memory receivers
    )
        internal
        pure
        returns (bytes memory)
    {
        // 52-byte strategy header + abi.encode(address[] tokens, uint256[] amounts, address[] receivers)
        return abi.encodePacked(bytes32(0), address(0), abi.encode(tokens, amounts, receivers));
    }
}
