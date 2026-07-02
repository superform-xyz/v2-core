// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Constants } from "../../utils/Constants.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../src/interfaces/ISuperHook.sol";

// Hooks under test
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../../src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import {
    AcrossSendFundsAndExecuteOnDstHookV2
} from "../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol";
import { SwapUniswapV3Hook } from "../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol";

/// @title HookSizingInterfaceIntegration
/// @notice Fork-based tests to prove sizing interface matches actual protocol data layouts.
///         Uses real mainnet addresses to verify decode/replace works with production-realistic data.
contract HookSizingInterfaceIntegration is Helpers {
    // ──────── Fork ────────
    uint256 public forkId;
    uint256 public constant FORK_BLOCK = 21_929_476;

    // ──────── Hooks ────────
    Deposit4626VaultHook deposit4626;
    Redeem4626VaultHook redeem4626;
    MorphoSupplyHook morphoSupply;
    MorphoWithdrawHook morphoWithdraw;
    AcrossSendFundsAndExecuteOnDstHookV2 acrossV2;
    SwapUniswapV3Hook swapUniV3;

    // ──────── Real addresses ────────
    address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant SPOKE_POOL = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
    address constant DST_VALIDATOR = address(0x4004);

    // Real ERC-4626 vault (Morpho vault on mainnet — also ERC4626 compliant)
    address constant ERC4626_VAULT = 0xdd0f28e19C1780eb6396170735D45153D261490d;

    // Tokens
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // Morpho market params (WBTC/USDC market)
    address constant MORPHO_ORACLE_WBTC = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
    address constant MORPHO_IRM_WBTC = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 constant MORPHO_LLTV = 86e16; // 86%

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), FORK_BLOCK);

        // Deploy hooks with real constructor args
        deposit4626 = new Deposit4626VaultHook();
        redeem4626 = new Redeem4626VaultHook();
        morphoSupply = new MorphoSupplyHook(MORPHO_BLUE);
        morphoWithdraw = new MorphoWithdrawHook(MORPHO_BLUE);
        acrossV2 = new AcrossSendFundsAndExecuteOnDstHookV2(SPOKE_POOL, DST_VALIDATOR);
        swapUniV3 = new SwapUniswapV3Hook(UNI_V3_ROUTER);
    }

    /*//////////////////////////////////////////////////////////////
              ERC-4626 INTEGRATION: Deposit
    //////////////////////////////////////////////////////////////*/

    /// @dev Build Deposit4626 data with real vault, verify decode/replace roundtrip
    function test_Fork_Deposit4626_RealVault_DecodeReplace() public view {
        bytes32 oracleId = bytes32(uint256(1));
        uint256 amount = 100e18;

        bytes memory data = abi.encodePacked(oracleId, ERC4626_VAULT, amount, false);

        // Verify decode
        uint256[] memory amounts = deposit4626.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], amount);

        // Verify replace
        uint256 newAmount = 200e18;
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(deposit4626.decodeAmounts(replaced)[0], newAmount);

        // Verify vault address preserved
        address decodedVault = BytesLib.toAddress(replaced, 32);
        assertEq(decodedVault, ERC4626_VAULT);

        // Verify oracleId preserved
        bytes32 decodedOracle = bytes32(BytesLib.toUint256(replaced, 0));
        assertEq(decodedOracle, oracleId);
    }

    /// @dev Build Deposit4626 data and verify the sizing interface metadata is correct
    function test_Fork_Deposit4626_AmountMeta() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = deposit4626.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.ASSETS));
    }

    /*//////////////////////////////////////////////////////////////
              ERC-4626 INTEGRATION: Redeem
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Redeem4626_RealVault_DecodeReplace() public view {
        bytes32 oracleId = bytes32(uint256(2));
        address owner = address(this);
        uint256 shares = 50e18;

        bytes memory data = abi.encodePacked(oracleId, ERC4626_VAULT, owner, shares, false);

        // Verify decode
        assertEq(redeem4626.decodeAmounts(data)[0], shares);

        // Replace shares
        uint256 newShares = 100e18;
        bytes memory replaced = redeem4626.replaceCalldataAmounts(data, _singleAmount(newShares));
        assertEq(redeem4626.decodeAmounts(replaced)[0], newShares);

        // Verify vault + owner preserved
        assertEq(BytesLib.toAddress(replaced, 32), ERC4626_VAULT);
        assertEq(BytesLib.toAddress(replaced, 52), owner);
    }

    /*//////////////////////////////////////////////////////////////
              MORPHO INTEGRATION: Supply (single-amount)
    //////////////////////////////////////////////////////////////*/

    /// @dev Build MorphoSupply data with real Morpho market params
    function test_Fork_MorphoSupply_RealMarket_DecodeReplace() public view {
        // BaseLoanHook data: header(52) + loanToken@52(20) + collateralToken@72(20) + oracle@92(20) + irm@112(20) + amount@132(32) + lltv@164(32) + usePrev@196(1)
        uint256 amount = 1e8; // 1 WBTC in WBTC decimals
        bytes memory data = abi.encodePacked(bytes32(0), address(0), WBTC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, amount, MORPHO_LLTV, false);

        // Verify decode with real addresses
        assertEq(morphoSupply.decodeAmounts(data)[0], amount);

        // Replace and verify
        uint256 newAmount = 5e8;
        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(morphoSupply.decodeAmounts(replaced)[0], newAmount);

        // Verify all real market param addresses preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), WBTC, "loanToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), USDC, "collateralToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 92), MORPHO_ORACLE_WBTC, "oracle mismatch");
        assertEq(BytesLib.toAddress(replaced, 112), MORPHO_IRM_WBTC, "irm mismatch");

        // Verify LLTV preserved (at offset 164)
        assertEq(BytesLib.toUint256(replaced, 164), MORPHO_LLTV, "lltv mismatch");
    }

    /*//////////////////////////////////////////////////////////////
              MORPHO INTEGRATION: Withdraw (XOR invariant)
    //////////////////////////////////////////////////////////////*/

    /// @dev MorphoWithdraw with real market — verify XOR invariant with real data layout
    function test_Fork_MorphoWithdraw_RealMarket_XOR() public view {
        // MorphoWithdraw: header(52) + loanToken@52(20) + collateralToken@72(20) + oracle@92(20) + irm@112(20) + lltv@132(32) + assets@164(32) + shares@196(32)
        uint256 assets = 1000e6; // 1000 USDC

        bytes memory data = abi.encodePacked(bytes32(0), address(0), WBTC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, MORPHO_LLTV, assets, uint256(0));

        uint256[] memory decoded = morphoWithdraw.decodeAmounts(data);
        assertEq(decoded.length, 2);
        assertEq(decoded[0], assets);
        assertEq(decoded[1], 0);

        // Replace with shares instead of assets
        uint256 shares = 500e18;
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(0, shares));
        uint256[] memory newDecoded = morphoWithdraw.decodeAmounts(replaced);
        assertEq(newDecoded[0], 0);
        assertEq(newDecoded[1], shares);

        // Verify real addresses preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), WBTC);
        assertEq(BytesLib.toAddress(replaced, 72), USDC);
        assertEq(BytesLib.toAddress(replaced, 92), MORPHO_ORACLE_WBTC);
        assertEq(BytesLib.toAddress(replaced, 112), MORPHO_IRM_WBTC);
        assertEq(BytesLib.toUint256(replaced, 132), MORPHO_LLTV);
    }

    /// @dev MorphoWithdraw XOR — both nonzero reverts even with real market data
    function test_Fork_MorphoWithdraw_RealMarket_RevertsBothNonzero() public {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), WBTC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, MORPHO_LLTV, uint256(1e18), uint256(0));

        vm.expectRevert();
        morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(1e18, 1e18));
    }

    /*//////////////////////////////////////////////////////////////
              UNISWAP V3 INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Build SwapUniswapV3 data with real router, verify sizing interface
    function test_Fork_SwapUniswapV3_RealRouter_DecodeReplace() public view {
        // UniV3 data: header(52) + tokenIn@52(20) + tokenOut@72(20) + fee@92(4) + recipient@96(20) + deadline@116(32) + sqrtPriceX96@148(32) + amount@180(32) + minAmountOut@212(32) + usePrev@244(1)
        uint256 amount = 1e18; // 1 WETH
        address recipient = address(0); // 0 means let router find pool

        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), WETH, USDC, uint32(3000), recipient, uint256(0), uint256(block.timestamp + 3600), amount, uint256(0), false
        );

        assertEq(swapUniV3.decodeAmounts(data)[0], amount);

        uint256 newAmount = 5e18;
        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(swapUniV3.decodeAmounts(replaced)[0], newAmount);

        // Verify token addresses preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), WETH, "tokenIn mismatch");
        assertEq(BytesLib.toAddress(replaced, 72), USDC, "tokenOut mismatch");
    }

    /*//////////////////////////////////////////////////////////////
              ACROSS V2 INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Build AcrossV2 data with real SpokePool address
    function test_Fork_AcrossV2_RealSpokePool_DecodeReplace() public view {
        // AcrossV2 data: header(52) + value@52(32) + recipient@84(20) + inputToken@104(20) + outputToken@124(20) + inputAmount@144(32) + ...
        address recipient = address(this);
        uint256 amount = 1000e6; // 1000 USDC

        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte header
            uint256(8453), // Base chain (value at offset 52)
            recipient,
            USDC, // inputToken
            USDC, // outputToken (same for CCTP)
            amount, // at offset 144
            uint256(990e6), // outputAmount
            uint256(block.timestamp + 7200) // fillDeadline
        );

        assertEq(acrossV2.decodeAmounts(data)[0], amount);

        uint256 newAmount = 5000e6;
        bytes memory replaced = acrossV2.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(acrossV2.decodeAmounts(replaced)[0], newAmount);

        // Verify dstChainId, recipient, tokens preserved (with 52-byte header offset)
        assertEq(BytesLib.toUint256(replaced, 52), 8453, "dstChainId mismatch");
        assertEq(BytesLib.toAddress(replaced, 84), recipient, "recipient mismatch");
        assertEq(BytesLib.toAddress(replaced, 104), USDC, "inputToken mismatch");
        assertEq(BytesLib.toAddress(replaced, 124), USDC, "outputToken mismatch");
    }

    /*//////////////////////////////////////////////////////////////
              BUILD CALLDATA VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @dev After replaceCalldataAmounts, verify the amount position is correct
    ///      by independently reading the uint256 at the expected byte offset
    function test_Fork_BuildVerification_Deposit4626() public view {
        bytes32 oracleId = bytes32(uint256(0xFF));
        uint256 origAmount = 100e18;
        uint256 newAmount = 777e18;

        bytes memory data = abi.encodePacked(oracleId, ERC4626_VAULT, origAmount, false);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(newAmount));

        // Independently verify: amount sits at byte offset 52 (32 bytes32 + 20 address)
        uint256 rawAmount = BytesLib.toUint256(replaced, 52);
        assertEq(rawAmount, newAmount);
    }

    function test_Fork_BuildVerification_MorphoSupply() public view {
        uint256 origAmount = 1e8;
        uint256 newAmount = 42e8;

        // BaseLoanHook data: header(52) + 4 addresses(80) + amount@132(32) + lltv@164(32) + usePrev@196(1)
        bytes memory data = abi.encodePacked(bytes32(0), address(0), WBTC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, origAmount, MORPHO_LLTV, false);
        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(newAmount));

        // Independently verify: amount sits at byte offset 132 (52 header + 4 * 20 byte addresses)
        uint256 rawAmount = BytesLib.toUint256(replaced, 132);
        assertEq(rawAmount, newAmount);
    }

    function test_Fork_BuildVerification_AcrossV2() public view {
        uint256 origAmount = 1000e6;
        uint256 newAmount = 9999e6;

        // AcrossV2 data: header(52) + value@52(32) + recipient@84(20) + inputToken@104(20) + outputToken@124(20) + amount@144(32) + ...
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), uint256(8453), address(this), USDC, USDC, origAmount, uint256(0), uint256(0)
        );
        bytes memory replaced = acrossV2.replaceCalldataAmounts(data, _singleAmount(newAmount));

        // Independently verify: amount at offset 144
        uint256 rawAmount = BytesLib.toUint256(replaced, 144);
        assertEq(rawAmount, newAmount);
    }

    function test_Fork_BuildVerification_SwapUniswapV3() public view {
        uint256 origAmount = 1e18;
        uint256 newAmount = 123e18;

        // UniV3 data: header(52) + tokenIn@52(20) + tokenOut@72(20) + fee@92(4) + recipient@96(20) + sqrtPriceX96@116(32) + deadline@148(32) + amount@180(32) + minAmountOut@212(32) + usePrev@244(1)
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), WETH, USDC, uint32(3000), address(0), uint256(0), uint256(block.timestamp + 3600), origAmount, uint256(0), false
        );
        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(newAmount));

        // Independently verify: amount at offset 180
        uint256 rawAmount = BytesLib.toUint256(replaced, 180);
        assertEq(rawAmount, newAmount);
    }

    /*//////////////////////////////////////////////////////////////
              FUZZ: Fork-based with real addresses
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Fork_Deposit4626_RealVault(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(1)), ERC4626_VAULT, uint256(0), false);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(deposit4626.decodeAmounts(replaced)[0], amt);
        // Real vault address always preserved
        assertEq(BytesLib.toAddress(replaced, 32), ERC4626_VAULT);
    }

    function testFuzz_Fork_MorphoSupply_RealMarket(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), WBTC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, uint256(0), MORPHO_LLTV, false);
        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(morphoSupply.decodeAmounts(replaced)[0], amt);
        // All real market addresses preserved (with 52-byte header offset)
        assertEq(BytesLib.toAddress(replaced, 52), WBTC);
        assertEq(BytesLib.toAddress(replaced, 72), USDC);
    }

    function testFuzz_Fork_MorphoWithdraw_RealMarket_XOR(uint256 a, uint256 b) public {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), WBTC, USDC, MORPHO_ORACLE_WBTC, MORPHO_IRM_WBTC, MORPHO_LLTV, uint256(0), uint256(0));

        bool bothZero = (a == 0 && b == 0);
        bool bothNonzero = (a != 0 && b != 0);

        if (bothZero || bothNonzero) {
            vm.expectRevert();
            morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(a, b));
        } else {
            bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(a, b));
            uint256[] memory amounts = morphoWithdraw.decodeAmounts(replaced);
            assertEq(amounts[0], a);
            assertEq(amounts[1], b);
            // Real addresses always preserved (with 52-byte header offset)
            assertEq(BytesLib.toAddress(replaced, 52), WBTC);
            assertEq(BytesLib.toAddress(replaced, 72), USDC);
        }
    }

    receive() external payable { }
}
