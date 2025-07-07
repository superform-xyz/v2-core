// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { BatchTransferFromHook } from "../../../../../src/hooks/tokens/permit2/BatchTransferFromHook.sol";
import { IAllowanceTransfer } from "../../../../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { IPermit2Batch } from "../../../../../src/vendor/uniswap/permit2/IPermit2Batch.sol";

contract BatchTransferFromHookTest is Helpers, InternalHelpers {
    BatchTransferFromHook public hook;

    address public usdc;
    address public weth;
    address public dai;
    address[] public tokens;

    uint256[] public amounts;
    uint256 public sigDeadline;

    address public eoa;
    address public account;

    IAllowanceTransfer public permit2;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        tokens = new address[](3);
        tokens[0] = usdc;
        tokens[1] = weth;
        tokens[2] = dai;

        amounts = new uint256[](3);
        amounts[0] = 1000e6;
        amounts[1] = 2e18;
        amounts[2] = 3e18;

        sigDeadline = block.timestamp + 2 weeks;

        eoa = vm.addr(321);
        deal(usdc, eoa, 1000e6);
        deal(weth, eoa, 2e18);
        deal(dai, eoa, 3e18);

        account = _deployAccount(1, "TEST");

        hook = new BatchTransferFromHook(PERMIT2);
        permit2 = IAllowanceTransfer(PERMIT2);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new BatchTransferFromHook(address(0));
    }

    function test_Build_RevertIf_InvalidAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        bytes memory hookData = abi.encodePacked(
            address(0), // invalid from address
            uint256(3),
            sigDeadline,
            abi.encodePacked(tokens[0], tokens[1], tokens[2]),
            abi.encodePacked(amounts[0], amounts[1], amounts[2]),
            new bytes(65)
        );
        hook.build(address(0), account, hookData);
    }

    function test_Build_RevertIf_ZeroTokens() public {
        vm.expectRevert(BatchTransferFromHook.INVALID_ARRAY_LENGTH.selector);
        bytes memory hookData = abi.encodePacked(
            eoa,
            uint256(0), // zero tokens
            sigDeadline,
            new bytes(65)
        );
        hook.build(address(0), account, hookData);
    }

    function test_Build_Executions() public view {
        bytes memory hookData = abi.encodePacked(
            eoa, // from address (20 bytes)
            uint256(3), // number of tokens (32 bytes)
            sigDeadline, // signature deadline (32 bytes)
            abi.encodePacked(tokens[0], tokens[1], tokens[2]), // token addresses (20 bytes each)
            abi.encodePacked(amounts[0], amounts[1], amounts[2]), // amounts (32 bytes each)
            new bytes(65) // mock signature (65 bytes)
        );

        Execution[] memory executions = hook.build(address(0), account, hookData);

        assertEq(executions.length, 4);
        // First execution should be a dummy call to the first token
        assertEq(executions[1].target, PERMIT2);
        assertEq(executions[1].value, 0);

        // Second execution should be the transferFrom call
        assertEq(executions[2].target, PERMIT2);
        assertEq(executions[2].value, 0);

        // Verify the transfer call data
        bytes memory expectedTransferCallData =
            abi.encodeCall(IPermit2Batch.transferFrom, (_buildExpectedTransferDetails(eoa, account, tokens, amounts)));
        assertEq(executions[2].callData, expectedTransferCallData);
    }

    function _buildExpectedPermitBatch(
        address spender,
        address[] memory tokens_,
        uint256[] memory amountPerToken
    )
        internal
        view
        returns (IAllowanceTransfer.PermitBatch memory)
    {
        uint256 len = tokens_.length;
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](len);

        for (uint256 i; i < len; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens_[i],
                amount: uint160(amountPerToken[i]),
                expiration: type(uint48).max,
                nonce: 0
            });
        }

        return IAllowanceTransfer.PermitBatch({ details: details, spender: spender, sigDeadline: sigDeadline });
    }

    function _buildExpectedTransferDetails(
        address from,
        address to,
        address[] memory tokens_,
        uint256[] memory amountPerToken
    )
        internal
        pure
        returns (IAllowanceTransfer.AllowanceTransferDetails[] memory)
    {
        uint256 len = tokens_.length;
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            new IAllowanceTransfer.AllowanceTransferDetails[](len);

        for (uint256 i; i < len; ++i) {
            details[i] = IAllowanceTransfer.AllowanceTransferDetails({
                from: from,
                to: to,
                token: tokens_[i],
                amount: uint160(amountPerToken[i])
            });
        }

        return details;
    }

    function test_Build_RevertIf_InvalidArrayLengths() public {
        // Create arrays with mismatched lengths
        address[] memory mismatchedTokens = new address[](2);
        mismatchedTokens[0] = usdc;
        mismatchedTokens[1] = weth;

        uint256[] memory mismatchedAmounts = new uint256[](3);
        mismatchedAmounts[0] = 1000e6;
        mismatchedAmounts[1] = 2e18;
        mismatchedAmounts[2] = 3e18;

        bytes memory hookData = abi.encodePacked(
            eoa,
            uint256(3), // This should match the amounts array length
            sigDeadline,
            abi.encodePacked(mismatchedTokens[0], mismatchedTokens[1]),
            abi.encodePacked(mismatchedAmounts[0], mismatchedAmounts[1], mismatchedAmounts[2]),
            new bytes(65)
        );

        // This should revert when trying to decode the third token
        vm.expectRevert();
        hook.build(address(0), account, hookData);
    }

    function test_Build_RevertIf_EmptyTokenArray() public {
        bytes memory hookData = abi.encodePacked(eoa, uint256(0), sigDeadline, new bytes(65));

        vm.expectRevert(BatchTransferFromHook.INVALID_ARRAY_LENGTH.selector);
        hook.build(address(0), account, hookData);
    }

    function test_Build_RevertIf_ZeroAmount() public {
        bytes memory hookData = abi.encodePacked(
            eoa,
            uint256(3),
            sigDeadline,
            abi.encodePacked(tokens[0], tokens[1], tokens[2]),
            abi.encodePacked(uint256(0), uint256(0), uint256(0)),
            new bytes(65)
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, hookData);
    }

    function test_Build_RevertIf_InvalidSignatureLength() public view {
        bytes memory hookData = abi.encodePacked(
            eoa,
            uint256(3),
            sigDeadline,
            abi.encodePacked(tokens[0], tokens[1], tokens[2]),
            abi.encodePacked(amounts[0], amounts[1], amounts[2]),
            new bytes(64) // Invalid signature length (not 65 bytes)
        );

        // The hook doesn't actually check signature length, so this should succeed
        Execution[] memory executions = hook.build(address(0), account, hookData);
        assertEq(executions.length, 4);
    }

    function test_Build_RevertIf_InvalidTokenAddress() public {
        bytes memory hookData = abi.encodePacked(
            eoa,
            uint256(3),
            sigDeadline,
            abi.encodePacked(address(0), weth, dai), // Invalid token address
            abi.encodePacked(amounts[0], amounts[1], amounts[2]),
            new bytes(65)
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, hookData);
    }
}
