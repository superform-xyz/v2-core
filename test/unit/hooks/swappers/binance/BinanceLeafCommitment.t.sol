// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { ApproveAndSwapBinanceHook } from "../../../../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol";
import { ISuperHookInspector } from "../../../../../src/interfaces/ISuperHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";

/// @title BinanceLeafCommitment
/// @notice Proves the SuperVault Merkle-leaf path works with this hook's `inspect()` output and that the
///         v2-periphery SuperBank root generator can reproduce it with its existing arg encoder.
/// @dev Two replicas are copied verbatim from v2-periphery:
///      - leaf:  `SuperVaultAggregator._createLeaf` / `MerkleTreeBuilder._createLeaf`
///               leaf = keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))))
///               where `hookArgs = ISuperHookInspector(hook).inspect(hookCalldata)` is read ON-CHAIN at
///               validation time (`SuperVaultStrategy._validateHook`).
///      - args:  `script/superbank-roots/tree_builder.py::encode_hook_args`
///               concatenates each configured `address` arg as raw 20 bytes, in config order.
///      So the root generator only needs a config entry with two address args (inputToken, outputToken).
contract BinanceLeafCommitment is Helpers, InternalHelpers {
    ApproveAndSwapBinanceHook public hook;

    address public router = makeAddr("router");
    address public usdt = makeAddr("USDT");
    address public aaplb = makeAddr("AAPLB");
    address public nvdab = makeAddr("NVDAB");

    bytes public txData = hex"ad43f73d00000000";

    function setUp() public {
        hook = new ApproveAndSwapBinanceHook(router, 1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                    PERIPHERY REPLICAS (keep byte-identical)
    //////////////////////////////////////////////////////////////*/

    /// @dev == SuperVaultAggregator._createLeaf
    function _createLeaf(address hookAddress, bytes memory hookArgs) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));
    }

    /// @dev == tree_builder.encode_hook_args for a hook configured with `address` args in this order.
    function _peripheryEncodeHookArgs(address[] memory configuredArgs) internal pure returns (bytes memory packed) {
        for (uint256 i = 0; i < configuredArgs.length; i++) {
            packed = bytes.concat(packed, bytes20(configuredArgs[i]));
        }
    }

    /// @dev == SuperVaultAggregator._validateSingleHook (strategy root branch, no veto)
    function _validateSingleHook(
        bytes32 strategyRoot,
        address hookAddress,
        bytes memory hookCalldata,
        bytes32[] memory proof
    )
        internal
        view
        returns (bool)
    {
        bytes memory hookArgs = ISuperHookInspector(hookAddress).inspect(hookCalldata);
        bytes32 leaf = _createLeaf(hookAddress, hookArgs);
        if (proof.length == 0) return strategyRoot == leaf;
        return MerkleProof.verify(proof, strategyRoot, leaf);
    }

    /// @dev Two-leaf tree: root = hashPair(a, b); proof for a is [b]. Matches sorted-pair hashing.
    function _twoLeafTree(bytes32 a, bytes32 b) internal pure returns (bytes32 root, bytes32[] memory proofForA) {
        root = _hashPair(a, b);
        proofForA = new bytes32[](1);
        proofForA[0] = b;
    }

    /// @dev The config entry the root generator needs: args = [inputToken, outputToken].
    function _offchainHookArgs(address in_, address out_) internal pure returns (bytes memory) {
        address[] memory cfg = new address[](2);
        cfg[0] = in_;
        cfg[1] = out_;
        return _peripheryEncodeHookArgs(cfg);
    }

    function _data(
        address in_,
        address out_,
        uint256 amount,
        uint256 minOut,
        bytes memory tx_
    )
        internal
        view
        returns (bytes memory)
    {
        return _createBinanceSwapHookData(in_, out_, amount, 0, minOut, false, router, tx_);
    }

    /*//////////////////////////////////////////////////////////////
                                   TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The periphery encoder's output for [inputToken, outputToken] is byte-identical to inspect().
    function test_OffchainEncoding_MatchesPeripheryTreeBuilder() public view {
        bytes memory onchain = hook.inspect(_data(usdt, aaplb, 100e18, 1, txData));
        assertEq(onchain, _offchainHookArgs(usdt, aaplb));
        assertEq(onchain, abi.encodePacked(usdt, aaplb));
        assertEq(onchain.length, 40);
    }

    /// @notice A leaf built off-chain for (USDT, AAPLB) validates ANY calldata for that pair.
    function test_StrategyLeaf_ValidatesAnyAmountAndPayload() public view {
        bytes32 leaf = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        bytes32 other = _createLeaf(address(hook), _offchainHookArgs(usdt, nvdab));
        (bytes32 root, bytes32[] memory proof) = _twoLeafTree(leaf, other);

        assertTrue(_validateSingleHook(root, address(hook), _data(usdt, aaplb, 100e18, 1, txData), proof));
        assertTrue(_validateSingleHook(root, address(hook), _data(usdt, aaplb, 999_999e18, 42, hex"deadbeef"), proof));
    }

    /// @notice Single-leaf root (root == leaf, empty proof), as the aggregator special-cases it.
    function test_StrategyLeaf_SingleLeafRoot() public view {
        bytes32 root = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        assertTrue(_validateSingleHook(root, address(hook), _data(usdt, aaplb, 1e18, 1, txData), new bytes32[](0)));
    }

    /// @notice The same leaf does NOT authorise a different input token (the D11 property).
    function test_StrategyLeaf_RejectsDifferentInputToken() public view {
        bytes32 leaf = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        bytes32 other = _createLeaf(address(hook), _offchainHookArgs(usdt, nvdab));
        (bytes32 root, bytes32[] memory proof) = _twoLeafTree(leaf, other);

        assertFalse(_validateSingleHook(root, address(hook), _data(nvdab, aaplb, 100e18, 1, txData), proof));
    }

    function test_StrategyLeaf_RejectsDifferentOutputToken() public view {
        bytes32 root = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        assertFalse(_validateSingleHook(root, address(hook), _data(usdt, nvdab, 100e18, 1, txData), new bytes32[](0)));
    }

    /// @notice Arg ORDER in the config matters: [outputToken, inputToken] produces a dead leaf.
    function test_StrategyLeaf_RejectsSwappedArgOrder() public view {
        bytes32 root = _createLeaf(address(hook), _offchainHookArgs(aaplb, usdt));
        assertFalse(_validateSingleHook(root, address(hook), _data(usdt, aaplb, 100e18, 1, txData), new bytes32[](0)));
    }

    function test_StrategyLeaf_RejectsDifferentHookAddress() public {
        ApproveAndSwapBinanceHook otherHook = new ApproveAndSwapBinanceHook(makeAddr("otherRouter"), 1e18);
        bytes32 root = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        assertTrue(_validateSingleHook(root, address(hook), _data(usdt, aaplb, 100e18, 1, txData), new bytes32[](0)));
        assertFalse(
            _validateSingleHook(root, address(otherHook), _data(usdt, aaplb, 100e18, 1, txData), new bytes32[](0))
        );
    }

    /// @notice Copying a sibling's single-arg config (outputToken only) produces a leaf that never validates.
    function test_StrategyLeaf_SingleArgConfig_DoesNotValidate() public view {
        address[] memory cfg = new address[](1);
        cfg[0] = aaplb;
        bytes32 wrongRoot = _createLeaf(address(hook), _peripheryEncodeHookArgs(cfg));
        assertFalse(
            _validateSingleHook(wrongRoot, address(hook), _data(usdt, aaplb, 100e18, 1, txData), new bytes32[](0))
        );
    }

    /// @notice The spec's original abi.encode (64-byte) form is NOT what the generator emits and would not
    ///         validate against this hook either — documents why inspect() is packed.
    function test_StrategyLeaf_AbiEncodedArgs_DoesNotValidate() public view {
        bytes32 wrongRoot = _createLeaf(address(hook), abi.encode(usdt, aaplb));
        assertFalse(
            _validateSingleHook(wrongRoot, address(hook), _data(usdt, aaplb, 100e18, 1, txData), new bytes32[](0))
        );
    }

    function testFuzz_StrategyLeaf_AnyCalldataForPair(uint256 amount, uint256 minOut, bytes memory tx_) public view {
        vm.assume(tx_.length >= 4);
        bytes32 root = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        assertTrue(_validateSingleHook(root, address(hook), _data(usdt, aaplb, amount, minOut, tx_), new bytes32[](0)));
    }

    function testFuzz_StrategyLeaf_PairIsolation(address in_, address out_) public view {
        vm.assume(in_ != usdt || out_ != aaplb);
        bytes32 root = _createLeaf(address(hook), _offchainHookArgs(usdt, aaplb));
        assertFalse(_validateSingleHook(root, address(hook), _data(in_, out_, 1e18, 1, txData), new bytes32[](0)));
    }
}
