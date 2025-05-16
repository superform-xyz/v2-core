// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPermit2 } from "../../src/vendor/uniswap/permit2/IPermit2.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { TrustedForwarder } from "modulekit/module-bases/utils/TrustedForwarder.sol";
import { IPermit2Batch } from "../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { BatchTransferFromHook } from "../../src/core/hooks/tokens/permit2/BatchTransferFromHook.sol";
import { IAllowanceTransfer } from "../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { TransferERC20Hook } from "../../src/core/hooks/tokens/erc20/TransferERC20Hook.sol";

contract EOAOnrampOfframpTest is MinimalBaseIntegrationTest, TrustedForwarder {
    address public eoa;

    IAllowanceTransfer public permit2;
    IPermit2Batch public permit2Batch;

    address public usdc;
    address public weth;
    address public dai;
    address[] public tokens;

    uint256[] public amounts;

    bytes32 public DOMAIN_SEPARATOR;

    // Permit2 typehashes
    bytes32 public constant _PERMIT_BATCH_TYPEHASH = keccak256(
        "PermitBatch(PermitDetails[] details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        usdc = CHAIN_1_USDC;
        weth = CHAIN_1_WETH;
        dai = CHAIN_1_DAI;

        tokens = new address[](3);
        tokens[0] = usdc;
        tokens[1] = weth;
        tokens[2] = dai;

        amounts = new uint256[](3);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 1e18;

        eoa = vm.addr(0x12341234);
        vm.label(eoa, "EOA");

        deal(usdc, eoa, 1e18);
        deal(weth, eoa, 1e18);
        deal(dai, eoa, 1e18);

        permit2 = IAllowanceTransfer(PERMIT2);
        permit2Batch = IPermit2Batch(PERMIT2);

        try IPermit2(PERMIT2).DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
            DOMAIN_SEPARATOR = domainSeparator;
            console.log("Got DOMAIN_SEPARATOR from contract");
        } catch {
            DOMAIN_SEPARATOR = 0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28;
            console.log("Using hardcoded DOMAIN_SEPARATOR");
        }
    }

    function test_EOAOnrampOfframp() public {
        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(accountEth);
        uint256 wethBalanceBefore = IERC20(weth).balanceOf(accountEth);
        uint256 daiBalanceBefore = IERC20(dai).balanceOf(accountEth);

        BatchTransferFromHook hook = new BatchTransferFromHook(PERMIT2);
        address[] memory hooks = new address[](1);
        hooks[0] = address(hook);

        vm.startPrank(eoa);
        IERC20(usdc).approve(PERMIT2, 10e18);
        IERC20(weth).approve(PERMIT2, 10e18);
        IERC20(dai).approve(PERMIT2, 10e18);
        vm.stopPrank();

        IAllowanceTransfer.PermitBatch memory permitBatch =
            defaultERC20PermitBatchAllowance(tokens, amounts, uint48(block.timestamp + 2 weeks), uint48(0));

        bytes memory sig = getPermitBatchSignature(permitBatch, 0x12341234, DOMAIN_SEPARATOR);

        bytes memory hookData = _createBatchTransferFromHookData(eoa, 3, tokens, amounts, sig);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        uint256 expectedLength = 20 + 32 + (20 * 3) + (32 * 3) + 65;
        assertEq(hookData.length, expectedLength);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDataArray });

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOp(userOpData);

        assertEq(IERC20(usdc).balanceOf(accountEth), usdcBalanceBefore + 1e18);
        assertEq(IERC20(weth).balanceOf(accountEth), wethBalanceBefore + 1e18);
        assertEq(IERC20(dai).balanceOf(accountEth), daiBalanceBefore + 1e18);

        uint256 usdcBalanceEOABefore = IERC20(usdc).balanceOf(eoa);
        uint256 wethBalanceEOABefore = IERC20(weth).balanceOf(eoa);
        uint256 daiBalanceEOABefore = IERC20(dai).balanceOf(eoa);

        address[] memory offrampHooks = new address[](3);
        address transferHook = address(new TransferERC20Hook());
        offrampHooks[0] = transferHook;
        offrampHooks[1] = transferHook;
        offrampHooks[2] = transferHook;

        bytes[] memory offrampHookData = new bytes[](3);
        offrampHookData[0] = _createTransferERC20HookData(usdc, eoa, 1e18, false);
        offrampHookData[1] = _createTransferERC20HookData(weth, eoa, 1e18, false);
        offrampHookData[2] = _createTransferERC20HookData(dai, eoa, 1e18, false);

        ISuperExecutor.ExecutorEntry memory offrampEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: offrampHooks, hooksData: offrampHookData });

        UserOpData memory offrampUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(offrampEntry));

        executeOp(offrampUserOpData);

        assertEq(IERC20(usdc).balanceOf(eoa), usdcBalanceEOABefore + 1e18);
        assertEq(IERC20(weth).balanceOf(eoa), wethBalanceEOABefore + 1e18);
        assertEq(IERC20(dai).balanceOf(eoa), daiBalanceEOABefore + 1e18);
    }

    function defaultERC20PermitBatchAllowance(
        address[] memory permitTokens,
        uint256[] memory permitAmounts,
        uint48 expiration,
        uint48 nonce
    )
        internal
        view
        returns (IAllowanceTransfer.PermitBatch memory)
    {
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](permitTokens.length);

        for (uint256 i = 0; i < permitTokens.length; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: permitTokens[i],
                amount: uint160(permitAmounts[i]),
                expiration: expiration,
                nonce: nonce
            });
        }

        return IAllowanceTransfer.PermitBatch({
            details: details,
            spender: accountEth,
            sigDeadline: block.timestamp + 2 weeks
        });
    }

    function getPermitBatchSignature(
        IAllowanceTransfer.PermitBatch memory permit,
        uint256 privateKey,
        bytes32 domainSeparator
    )
        internal
        pure
        returns (bytes memory sig)
    {
        bytes32[] memory permitHashes = new bytes32[](permit.details.length);
        for (uint256 i = 0; i < permit.details.length; ++i) {
            permitHashes[i] = keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, permit.details[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TYPEHASH,
                        keccak256(abi.encodePacked(permitHashes)),
                        permit.spender,
                        permit.sigDeadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    // function _createBatchTransferFromHookData(
    //     address from,
    //     uint256 tokenCount,
    //     address[] memory tokenAddresses,
    //     uint256[] memory tokenAmounts,
    //     bytes memory signature
    // )
    //     internal
    //     pure
    //     returns (bytes memory)
    // {
    //     // Format data according to BatchTransferFromHook expectations:
    //     // address from (20 bytes) at offset 0
    //     // uint256 amountTokens (32 bytes) at offset 20
    //     // address[] tokens at offset 52 (tokenCount * 20 bytes)
    //     // uint256[] amounts after tokens (tokenCount * 32 bytes)
    //     // bytes signature (65 bytes) at the end

    //     bytes memory data = abi.encodePacked(
    //         from, // 20 bytes
    //         tokenCount, // 32 bytes
    //         _encodeAddressArray(tokenAddresses, tokenCount), // tokenCount * 20 bytes
    //         _encodeUint256Array(tokenAmounts, tokenCount), // tokenCount * 32 bytes
    //         signature // signature bytes
    //     );

    //     return data;
    // }

    function _encodeAddressArray(address[] memory array, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(20 * length);
        for (uint256 i = 0; i < length; i++) {
            bytes memory addressBytes = abi.encodePacked(array[i]);
            for (uint256 j = 0; j < 20; j++) {
                result[i * 20 + j] = addressBytes[j];
            }
        }
        return result;
    }

    function _encodeUint256Array(uint256[] memory array, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(32 * length);
        for (uint256 i = 0; i < length; i++) {
            bytes memory valueBytes = abi.encodePacked(array[i]);
            for (uint256 j = 0; j < 32; j++) {
                result[i * 32 + j] = valueBytes[j];
            }
        }
        return result;
    }
}
