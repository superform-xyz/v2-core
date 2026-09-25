// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Constants } from "../../utils/Constants.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";

/// @notice Minimal interface for the real deployed SuperVaultStrategy
interface ISuperVaultStrategy {
    struct ExecuteArgs {
        address[] hooks;
        bytes[] hookCalldata;
        uint256[] expectedAssetsOrSharesOut;
        bytes32[][] globalProofs;
        bytes32[][] strategyProofs;
    }

    function executeHooks(ExecuteArgs calldata args) external payable;
    function SUPER_GOVERNOR() external view returns (address);
}

/// @notice Minimal interface for SuperGovernor
interface ISuperGovernor {
    function isHookRegistered(address hook) external view returns (bool);
    function getAddress(bytes32 key) external view returns (address);
    function SUPER_VAULT_AGGREGATOR() external view returns (bytes32);
}

/// @notice Minimal interface for the real deployed SuperVaultAggregator (root lifecycle + validation)
interface ISuperVaultAggregator {
    struct ValidateHookArgs {
        address hookAddress;
        bytes hookArgs;
        bytes32[] globalProof;
        bytes32[] strategyProof;
    }

    function getMainManager(address strategy) external view returns (address);
    function isAnyManager(address manager, address strategy) external view returns (bool);
    function validateHook(address strategy, ValidateHookArgs calldata args) external view returns (bool);
    function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) external;
    function executeStrategyHooksRootUpdate(address strategy) external;
    function getHooksRootUpdateTimelock() external view returns (uint256);
    function getStrategyHooksRoot(address strategy) external view returns (bytes32);
    function isStrategyHooksRootVetoed(address strategy) external view returns (bool);
    function isGlobalHooksRootVetoed() external view returns (bool);
}

/// @title MorphoLendStrategyProofFork
/// @notice PR #1010 review F1 regression (SUP-21024 / SUP-21025): the SuperVault aggregator hashes a
///         hook's RAW `inspect()` bytes into the Merkle leaf, so the money-market hooks' identity must
///         be the MARKET KEY first (the yield source the ledger is keyed by), not the Morpho singleton.
///         This suite proves it with a REAL proof through the REAL deployed strategy + aggregator on a
///         mainnet fork (no `validateHook` mock): a two-leaf tree whose leaves are built OFF-hook from
///         the SUP-21025 encoding is proposed by the strategy's real main manager, executed after the
///         real timelock, and then `executeHooks` runs lend and withdraw with real sibling proofs.
///         A root built from singleton-first leaves does not authorize.
/// @dev Only `isHookRegistered` is mocked (freshly deployed hooks cannot be registered on the real
///      governor from a test); manager authorization and Merkle validation are the real thing.
contract MorphoLendStrategyProofForkTest is Test, Constants {
    using MarketParamsLib for MarketParams;

    address public constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD; // SuperUSDC strategy
    uint256 public constant LEND_AMOUNT = 10_000e6;

    MorphoLendHook public lendHook;
    MorphoWithdrawHook public withdrawHook;
    ISuperVaultAggregator public aggregator;
    address public mainManager;
    MarketParams public marketParams;
    Id public marketId;
    address public marketKey;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK_SUPERVAULT);

        lendHook = new MorphoLendHook(MORPHO);
        withdrawHook = new MorphoWithdrawHook(MORPHO);

        address superGovernor = ISuperVaultStrategy(STRATEGY).SUPER_GOVERNOR();
        aggregator = ISuperVaultAggregator(
            ISuperGovernor(superGovernor).getAddress(ISuperGovernor(superGovernor).SUPER_VAULT_AGGREGATOR())
        );
        mainManager = aggregator.getMainManager(STRATEGY);
        assertTrue(aggregator.isAnyManager(mainManager, STRATEGY), "real main manager");
        assertFalse(aggregator.isGlobalHooksRootVetoed(), "fixture assumes global root not vetoed");
        assertFalse(aggregator.isStrategyHooksRootVetoed(STRATEGY), "fixture assumes strategy root not vetoed");

        // Freshly deployed hooks are not on the real governor's registry — the only mock in this suite
        vm.mockCall(
            superGovernor, abi.encodeCall(ISuperGovernor.isHookRegistered, (address(lendHook))), abi.encode(true)
        );
        vm.mockCall(
            superGovernor, abi.encodeCall(ISuperGovernor.isHookRegistered, (address(withdrawHook))), abi.encode(true)
        );

        marketParams = MarketParams({
            loanToken: CHAIN_1_USDC,
            collateralToken: CHAIN_1_WBTC,
            oracle: MORPHO_ORACLE_WBTC_USDC,
            irm: MORPHO_IRM_WBTC_USDC,
            lltv: 860_000_000_000_000_000
        });
        marketId = marketParams.id();
        marketKey = address(uint160(uint256(Id.unwrap(marketId))));
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Key-first leaves (SUP-21025 encoding, built off-hook) authorize lend AND withdraw through
    ///         the real strategy with real sibling proofs; the on-chain inspect bytes equal the encoding.
    function test_Fork_RealProof_KeyFirstLeaves_AuthorizeLendAndWithdraw() public {
        (bytes32 lendLeaf, bytes32 wdLeaf) = _keyFirstLeaves();
        _installStrategyRoot(_root(lendLeaf, wdLeaf));

        // on-chain identity == SUP-21025 encoding (the thing the leaf was built from)
        bytes memory lendData = _lendData(LEND_AMOUNT);
        assertEq(lendHook.inspect(lendData), _sup21025Encoding(), "inspect == key-first encoding");
        assertEq(lendHook.inspect(lendData).length, 132);

        // direct aggregator validation with the real proof (sibling = withdraw leaf)
        assertTrue(
            aggregator.validateHook(
                STRATEGY, _validateArgs(address(lendHook), lendHook.inspect(lendData), _proof(wdLeaf))
            ),
            "aggregator accepts key-first leaf with real proof"
        );

        // LEND through the real strategy
        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        (uint256 sharesBefore,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        _executeOne(address(lendHook), lendData, _proof(wdLeaf));
        (uint256 sharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertGt(sharesAfter, sharesBefore, "lend executed under a real proof");

        // WITHDRAW through the real strategy (sibling = lend leaf)
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(STRATEGY);
        _executeOne(address(withdrawHook), _withdrawData(0, sharesAfter - sharesBefore), _proof(lendLeaf));
        assertGt(IERC20(CHAIN_1_USDC).balanceOf(STRATEGY), usdcBefore, "withdraw executed under a real proof");
    }

    /// @notice A root built from singleton-first leaves (the pre-fix encoding) does NOT authorize: the
    ///         aggregator rejects the proof and the strategy reverts before any Morpho call.
    function test_Fork_RealProof_SingletonFirstLeaves_DoNotAuthorize() public {
        bytes memory singletonFirst = abi.encodePacked(
            MORPHO,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv
        );
        bytes32 lendLeaf = _leaf(address(lendHook), singletonFirst);
        bytes32 wdLeaf = _leaf(address(withdrawHook), singletonFirst);
        _installStrategyRoot(_root(lendLeaf, wdLeaf));

        bytes memory lendData = _lendData(LEND_AMOUNT);
        assertFalse(
            aggregator.validateHook(
                STRATEGY, _validateArgs(address(lendHook), lendHook.inspect(lendData), _proof(wdLeaf))
            ),
            "singleton-first root must not validate the key-first inspect bytes"
        );

        deal(CHAIN_1_USDC, STRATEGY, LEND_AMOUNT);
        (uint256 sharesBefore,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        vm.expectRevert();
        _executeOne(address(lendHook), lendData, _proof(wdLeaf));
        (uint256 sharesAfter,,) = IMorphoStaticTyping(MORPHO).position(marketId, STRATEGY);
        assertEq(sharesAfter, sharesBefore, "nothing supplied");
    }

    /// @notice Leaf sensitivity through the real aggregator: a proof for market A's key-first leaf does
    ///         not authorize a payload whose header names another market's key (the hook's identity
    ///         follows the header), nor one whose lltv differs; amount-only changes stay authorized.
    function test_Fork_RealProof_LeafSensitivity_HeaderKey_MarketParams_AmountInvariance() public {
        (bytes32 lendLeaf, bytes32 wdLeaf) = _keyFirstLeaves();
        _installStrategyRoot(_root(lendLeaf, wdLeaf));

        // amount-only change: same leaf, still authorized
        assertTrue(
            aggregator.validateHook(
                STRATEGY, _validateArgs(address(lendHook), lendHook.inspect(_lendData(LEND_AMOUNT * 7)), _proof(wdLeaf))
            ),
            "amount is not part of the identity"
        );
        // header key of another market: identity moves, proof fails
        bytes memory otherKeyData = _lendData(LEND_AMOUNT);
        bytes20 k = bytes20(address(0xBEEF));
        for (uint256 i; i < 20; ++i) {
            otherKeyData[32 + i] = k[i];
        }
        assertFalse(
            aggregator.validateHook(
                STRATEGY, _validateArgs(address(lendHook), lendHook.inspect(otherKeyData), _proof(wdLeaf))
            ),
            "header key is part of the identity"
        );
        // lltv change: identity moves, proof fails
        bytes memory lltvData = abi.encodePacked(
            MORPHO_YS_ORACLE_ID,
            marketKey,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            LEND_AMOUNT,
            marketParams.lltv + 1,
            false
        );
        assertFalse(
            aggregator.validateHook(
                STRATEGY, _validateArgs(address(lendHook), lendHook.inspect(lltvData), _proof(wdLeaf))
            ),
            "lltv is part of the identity"
        );
    }

    /*//////////////////////////////////////////////////////////////
                               MERKLE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev SUP-21025 encoding for the money-market hooks: (marketKey, loan, collateral, oracle, irm, lltv)
    function _sup21025Encoding() internal view returns (bytes memory) {
        return abi.encodePacked(
            marketKey,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv
        );
    }

    function _keyFirstLeaves() internal view returns (bytes32 lendLeaf, bytes32 wdLeaf) {
        bytes memory enc = _sup21025Encoding();
        lendLeaf = _leaf(address(lendHook), enc);
        wdLeaf = _leaf(address(withdrawHook), enc);
    }

    /// @dev == SuperVaultAggregator._createLeaf
    function _leaf(address hook, bytes memory args) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(hook, args))));
    }

    /// @dev Two-leaf tree root with OpenZeppelin MerkleProof's sorted-pair hashing
    function _root(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _proof(bytes32 sibling) internal pure returns (bytes32[] memory p) {
        p = new bytes32[](1);
        p[0] = sibling;
    }

    /// @dev Real root lifecycle: proposed by the strategy's real main manager, executed after the timelock
    function _installStrategyRoot(bytes32 root) internal {
        vm.prank(mainManager);
        aggregator.proposeStrategyHooksRoot(STRATEGY, root);
        vm.warp(block.timestamp + aggregator.getHooksRootUpdateTimelock() + 1);
        aggregator.executeStrategyHooksRootUpdate(STRATEGY);
        assertEq(aggregator.getStrategyHooksRoot(STRATEGY), root, "strategy root installed");
    }

    function _validateArgs(
        address hook,
        bytes memory args,
        bytes32[] memory strategyProof
    )
        internal
        pure
        returns (ISuperVaultAggregator.ValidateHookArgs memory)
    {
        return ISuperVaultAggregator.ValidateHookArgs({
            hookAddress: hook, hookArgs: args, globalProof: new bytes32[](0), strategyProof: strategyProof
        });
    }

    /*//////////////////////////////////////////////////////////////
                              EXEC + ENCODERS
    //////////////////////////////////////////////////////////////*/

    function _executeOne(address hook, bytes memory data, bytes32[] memory strategyProof) internal {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        uint256[] memory expectedOut = new uint256[](1);
        bytes32[][] memory globalProofs = new bytes32[][](1);
        globalProofs[0] = new bytes32[](0);
        bytes32[][] memory strategyProofs = new bytes32[][](1);
        strategyProofs[0] = strategyProof;

        vm.prank(mainManager);
        ISuperVaultStrategy(STRATEGY)
            .executeHooks(
                ISuperVaultStrategy.ExecuteArgs({
                    hooks: hooks,
                    hookCalldata: datas,
                    expectedAssetsOrSharesOut: expectedOut,
                    globalProofs: globalProofs,
                    strategyProofs: strategyProofs
                })
            );
    }

    // lend (197): header (oracle id + MARKET KEY) + market + amount@132 + lltv@164 + usePrev@196
    function _lendData(uint256 amount) internal view returns (bytes memory) {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID,
            marketKey,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            amount,
            marketParams.lltv,
            false
        );
    }

    // withdraw (228): header (oracle id + MARKET KEY) + market + lltv@132 + assets@164 + shares@196
    function _withdrawData(uint256 assets, uint256 shares) internal view returns (bytes memory) {
        return abi.encodePacked(
            MORPHO_YS_ORACLE_ID,
            marketKey,
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv,
            assets,
            shares
        );
    }
}
