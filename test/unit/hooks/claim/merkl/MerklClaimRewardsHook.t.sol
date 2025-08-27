// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IDistributor } from "../../../../../src/vendor/merkl/IDistributor.sol";

// Superform
import { Helpers } from "../../../../utils/Helpers.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MerklClaimRewardHook } from "../../../../../src/hooks/claim/merkl/MerklClaimRewardHook.sol";

contract MerklClaimRewardsHookTest is Helpers, InternalHelpers {
    using BytesLib for bytes;

    MerklClaimRewardHook public hook;

    address public distributor;

    address[] public users;
    address[] public tokens;
    uint256[] public amounts;
    bytes32[][] public proofs;

    function setUp() public {
        distributor = MERKL_DISTRIBUTOR;
        address user = makeAddr("user");
        users = [user, user, user];

        MockERC20 _mockToken1 = new MockERC20("Mock Token", "MTK", 18);
        MockERC20 _mockToken2 = new MockERC20("Mock Token", "MTK", 18);
        MockERC20 _mockToken3 = new MockERC20("Mock Token", "MTK", 18);

        tokens = [address(_mockToken1), address(_mockToken2), address(_mockToken3)];

        amounts = [1000, 2000, 3000];

        proofs = [
            [keccak256(abi.encodePacked(user, address(_mockToken1), uint256(1000)))],
            [keccak256(abi.encodePacked(user, address(_mockToken2), uint256(2000)))],
            [keccak256(abi.encodePacked(user, address(_mockToken3), uint256(3000)))]
        ];

        hook = new MerklClaimRewardHook(distributor, address(this), 0);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_MerklClaimReward_InvalidConstructorParms() public {
        vm.expectRevert(MerklClaimRewardHook.FEE_NOT_VALID.selector);
        new MerklClaimRewardHook(distributor, address(this), 1e18);
    }

    function test_Build_RevertIf_DistributorZero() public {
        distributor = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MerklClaimRewardHook(distributor, address(this), 100);
    }

    function test_MerklClaimRewardsHook_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 6);
        assertEq(executions[1].target, distributor);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_PreAndPostExecute() public {
        address account = makeAddr("account");

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData());
        assertEq(hook.getOutAmount(account), 0);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData());
        assertEq(hook.getOutAmount(account), 0);
    }

    function test_MerklClaimRewardsHook_Inspector() public view {
        bytes memory data = _encodeData();
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        // Check that tokens are encoded correctly
        assertEq(BytesLib.toAddress(argsEncoded, 0), tokens[0]);
        assertEq(BytesLib.toAddress(argsEncoded, 20), tokens[1]);
        assertEq(BytesLib.toAddress(argsEncoded, 40), tokens[2]);
    }

    function test_MerklClaimRewardsHook_Inspector_SingleToken() public {
        address[] memory singleToken = new address[](1);
        singleToken[0] = address(makeAddr("singleToken"));

        uint256[] memory singleAmount = new uint256[](1);
        singleAmount[0] = 1000;

        bytes32[][] memory singleProof = new bytes32[][](1);
        singleProof[0] = new bytes32[](1);
        singleProof[0][0] = keccak256(abi.encodePacked(makeAddr("user"), singleToken[0], uint256(1000)));

        bytes memory data = _createMerklClaimRewardHookData(singleToken, singleAmount, singleProof);
        bytes memory argsEncoded = hook.inspect(data);

        assertGt(argsEncoded.length, 0);
        assertEq(argsEncoded.length, 20); // Should be exactly 20 bytes for one address

        // Check that the single token is encoded correctly
        assertEq(BytesLib.toAddress(argsEncoded, 0), singleToken[0]);
    }

    // Test inspect function with two tokens to ensure return statement coverage
    function test_MerklClaimRewardsHook_Inspector_TwoTokens() public {
        address[] memory twoTokens = new address[](2);
        twoTokens[0] = address(makeAddr("token1"));
        twoTokens[1] = address(makeAddr("token2"));

        uint256[] memory twoAmounts = new uint256[](2);
        twoAmounts[0] = 1000;
        twoAmounts[1] = 2000;

        bytes32[][] memory twoProofs = new bytes32[][](2);
        twoProofs[0] = new bytes32[](1);
        twoProofs[0][0] = keccak256(abi.encodePacked(makeAddr("user"), twoTokens[0], uint256(1000)));
        twoProofs[1] = new bytes32[](1);
        twoProofs[1][0] = keccak256(abi.encodePacked(makeAddr("user"), twoTokens[1], uint256(2000)));

        bytes memory data = _createMerklClaimRewardHookData(twoTokens, twoAmounts, twoProofs);
        bytes memory argsEncoded = hook.inspect(data);

        assertGt(argsEncoded.length, 0);
        assertEq(argsEncoded.length, 40); // Should be exactly 40 bytes for two addresses

        // Check that both tokens are encoded correctly
        assertEq(BytesLib.toAddress(argsEncoded, 0), twoTokens[0]);
        assertEq(BytesLib.toAddress(argsEncoded, 20), twoTokens[1]);
    }

    // Test inspect function with empty token array to ensure return statement coverage
    function test_MerklClaimRewardsHook_Inspector_EmptyTokens() public view {
        address[] memory emptyTokens = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        bytes32[][] memory emptyProofs = new bytes32[][](0);

        bytes memory data = _createMerklClaimRewardHookData(emptyTokens, emptyAmounts, emptyProofs);
        bytes memory argsEncoded = hook.inspect(data);

        assertEq(argsEncoded.length, 0); // Should be empty for no tokens
    }

    function test_CalldataDecoding() public view {
        bytes memory data = _encodeData();

        Execution[] memory executions = hook.build(address(0), users[0], data);

        assertEq(executions[1].target, distributor, "Distributor address not correctly decoded");

        bytes memory expectedCallData = abi.encodeCall(IDistributor.claim, (users, tokens, amounts, proofs));

        assertEq(
            keccak256(executions[1].callData),
            keccak256(expectedCallData),
            "Calldata doesn't contain the correct parameters"
        );
    }

    function test_Build_RevertIf_ZeroTokenAddress() public {
        // Create data with a zero token address
        address[] memory tokensWithZero = new address[](1);
        tokensWithZero[0] = address(0);

        uint256[] memory amountsSingle = new uint256[](1);
        amountsSingle[0] = 1000;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), address(0), uint256(1000)));

        bytes memory data = _createMerklClaimRewardHookData(tokensWithZero, amountsSingle, proofsSingle);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_ZeroAmount() public {
        // Create data with a zero amount
        address[] memory tokensSingle = new address[](1);
        tokensSingle[0] = address(makeAddr("token"));

        uint256[] memory amountsWithZero = new uint256[](1);
        amountsWithZero[0] = 0;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensSingle[0], uint256(0)));

        bytes memory data = _createMerklClaimRewardHookData(tokensSingle, amountsWithZero, proofsSingle);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_InvalidEncoding() public {
        // Create data with incorrect length that will cause cursor mismatch
        address[] memory tokensSingle = new address[](1);
        tokensSingle[0] = address(makeAddr("token"));

        uint256[] memory amountsSingle = new uint256[](1);
        amountsSingle[0] = 1000;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensSingle[0], uint256(1000)));

        bytes memory data = _createMerklClaimRewardHookData(tokensSingle, amountsSingle, proofsSingle);

        // Create invalid data by adding extra bytes at the end to cause cursor mismatch
        bytes memory invalidData = bytes.concat(data, abi.encodePacked(uint256(999)));

        vm.expectRevert(MerklClaimRewardHook.INVALID_ENCODING.selector);
        hook.build(address(0), address(0), invalidData);
    }

    function test_Build_RevertIf_InvalidEncodingExtraData() public {
        address[] memory tokensSingle = new address[](1);
        tokensSingle[0] = address(makeAddr("token"));

        uint256[] memory amountsSingle = new uint256[](1);
        amountsSingle[0] = 1000;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensSingle[0], uint256(1000)));

        bytes memory data = _createMerklClaimRewardHookData(tokensSingle, amountsSingle, proofsSingle);

        // Add extra data to cause cursor mismatch
        bytes memory extraData = bytes.concat(data, abi.encodePacked(uint256(999)));

        vm.expectRevert(MerklClaimRewardHook.INVALID_ENCODING.selector);
        hook.build(address(0), address(0), extraData);
    }

    // Test multiple zero token addresses
    function test_Build_RevertIf_MultipleZeroTokenAddresses() public {
        address[] memory tokensWithZeros = new address[](2);
        tokensWithZeros[0] = address(makeAddr("token1"));
        tokensWithZeros[1] = address(0); // Zero address

        uint256[] memory amountsMultiple = new uint256[](2);
        amountsMultiple[0] = 1000;
        amountsMultiple[1] = 2000;

        bytes32[][] memory proofsMultiple = new bytes32[][](2);
        proofsMultiple[0] = new bytes32[](1);
        proofsMultiple[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensWithZeros[0], uint256(1000)));
        proofsMultiple[1] = new bytes32[](1);
        proofsMultiple[1][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensWithZeros[1], uint256(2000)));

        bytes memory data = _createMerklClaimRewardHookData(tokensWithZeros, amountsMultiple, proofsMultiple);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    // Test multiple zero amounts
    function test_Build_RevertIf_MultipleZeroAmounts() public {
        address[] memory tokensMultiple = new address[](2);
        tokensMultiple[0] = address(makeAddr("token1"));
        tokensMultiple[1] = address(makeAddr("token2"));

        uint256[] memory amountsWithZeros = new uint256[](2);
        amountsWithZeros[0] = 1000;
        amountsWithZeros[1] = 0; // Zero amount

        bytes32[][] memory proofsMultiple = new bytes32[][](2);
        proofsMultiple[0] = new bytes32[](1);
        proofsMultiple[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensMultiple[0], uint256(1000)));
        proofsMultiple[1] = new bytes32[](1);
        proofsMultiple[1][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensMultiple[1], uint256(0)));

        bytes memory data = _createMerklClaimRewardHookData(tokensMultiple, amountsWithZeros, proofsMultiple);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    // Test invalid encoding with wrong array length in proofs
    function test_Build_RevertIf_InvalidProofsEncoding() public {
        address[] memory tokensSingle = new address[](1);
        tokensSingle[0] = address(makeAddr("token"));

        uint256[] memory amountsSingle = new uint256[](1);
        amountsSingle[0] = 1000;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensSingle[0], uint256(1000)));

        // Create invalid data by adding extra bytes in the middle to cause cursor mismatch
        // This will make the cursor calculation wrong but won't cause out-of-bounds errors
        bytes memory invalidData = bytes.concat(
            abi.encodePacked(uint256(1)), // array length = 1
            bytes20(tokensSingle[0]), // token address
            abi.encodePacked(amountsSingle[0]), // amount
            abi.encodePacked(uint256(1)), // proof array length = 1
            proofsSingle[0][0], // proof bytes32
            abi.encodePacked(uint256(999)) // extra data that will cause cursor mismatch
        );

        vm.expectRevert(MerklClaimRewardHook.INVALID_ENCODING.selector);
        hook.build(address(0), address(0), invalidData);
    }

    // Test inspect function with zero token address
    function test_Inspect_RevertIf_ZeroTokenAddress() public {
        address[] memory tokensWithZero = new address[](1);
        tokensWithZero[0] = address(0);

        uint256[] memory amountsSingle = new uint256[](1);
        amountsSingle[0] = 1000;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), address(0), uint256(1000)));

        bytes memory data = _createMerklClaimRewardHookData(tokensWithZero, amountsSingle, proofsSingle);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.inspect(data);
    }

    // Test inspect function with zero amount
    function test_Inspect_RevertIf_ZeroAmount() public {
        address[] memory tokensSingle = new address[](1);
        tokensSingle[0] = address(makeAddr("token"));

        uint256[] memory amountsWithZero = new uint256[](1);
        amountsWithZero[0] = 0;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensSingle[0], uint256(0)));

        bytes memory data = _createMerklClaimRewardHookData(tokensSingle, amountsWithZero, proofsSingle);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.inspect(data);
    }

    // Test inspect function with invalid encoding
    function test_Inspect_RevertIf_InvalidEncoding() public {
        address[] memory tokensSingle = new address[](1);
        tokensSingle[0] = address(makeAddr("token"));

        uint256[] memory amountsSingle = new uint256[](1);
        amountsSingle[0] = 1000;

        bytes32[][] memory proofsSingle = new bytes32[][](1);
        proofsSingle[0] = new bytes32[](1);
        proofsSingle[0][0] = keccak256(abi.encodePacked(makeAddr("user"), tokensSingle[0], uint256(1000)));

        bytes memory data = _createMerklClaimRewardHookData(tokensSingle, amountsSingle, proofsSingle);

        // Create invalid data by adding extra bytes at the end to cause cursor mismatch
        bytes memory invalidData = bytes.concat(data, abi.encodePacked(uint256(999)));

        vm.expectRevert(MerklClaimRewardHook.INVALID_ENCODING.selector);
        hook.inspect(invalidData);
    }

    function _encodeData() internal view returns (bytes memory data) {
        data = abi.encodePacked(uint256(users.length));

        for (uint256 i = 0; i < tokens.length; i++) {
            data = bytes.concat(data, bytes20(tokens[i]));
        }

        for (uint256 i = 0; i < amounts.length; i++) {
            data = bytes.concat(data, abi.encodePacked(amounts[i]));
        }

        data = bytes.concat(data, _flattenProofs(proofs));
    }
}
