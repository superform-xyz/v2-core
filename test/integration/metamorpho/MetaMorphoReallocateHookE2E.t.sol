// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MetaMorphoReallocateHook } from "../../../src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol";
import { IMetaMorpho, MarketAllocation } from "../../../src/vendor/morpho/IMetaMorpho.sol";
import { MarketParamsLib } from "../../../src/vendor/morpho/MarketParamsLib.sol";
import { Id, IMorphoBase, IMorphoStaticTyping, MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";
import { Constants } from "../../utils/Constants.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

/// @notice Minimal interface for reading MetaMorpho vault state
interface IMetaMorphoRead {
    function owner() external view returns (address);
    function curator() external view returns (address);
    function isAllocator(address allocator) external view returns (bool);
    function supplyQueueLength() external view returns (uint256);
    function supplyQueue(uint256 index) external view returns (Id);
    function withdrawQueueLength() external view returns (uint256);
    function withdrawQueue(uint256 index) external view returns (Id);
    function setIsAllocator(address allocator, bool isAllocator_) external;
}

/// @notice Minimal interface for the real deployed SuperVaultStrategy.executeHooks
interface ISuperVaultStrategyExecute {
    struct ExecuteArgs {
        address[] hooks;
        bytes[] hookCalldata;
        uint256[] expectedAssetsOrSharesOut;
        bytes32[][] globalProofs;
        bytes32[][] strategyProofs;
    }

    function executeHooks(ExecuteArgs calldata args) external payable;
}

/// @notice Minimal interface for the SuperGovernor (used for isHookRegistered)
interface ISuperGovernor {
    function isHookRegistered(address hook) external view returns (bool);
}

/// @notice Minimal interface for the SuperVaultAggregator (used for isAnyManager + validateHook)
interface ISuperVaultAggregator {
    struct ValidateHookArgs {
        address hookAddress;
        bytes hookArgs;
        bytes32[] globalProof;
        bytes32[] strategyProof;
    }

    function isAnyManager(address manager, address strategy) external view returns (bool);
    function validateHook(address strategy, ValidateHookArgs calldata args) external view returns (bool isValid);
}

/// @title MetaMorphoReallocateHookE2E
/// @notice E2E integration test for MetaMorphoReallocateHook using real MetaMorpho vault on Ethereum mainnet fork
/// @dev Uses Steakhouse USDC vault (0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB) on Ethereum mainnet
contract MetaMorphoReallocateHookE2E is Test, Constants {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Steakhouse USDC MetaMorpho vault on Ethereum mainnet
    address public constant META_MORPHO_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    /// @dev Fork block (Ethereum mainnet)
    uint256 public constant FORK_BLOCK = 21_500_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    MetaMorphoReallocateHook public hook;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new MetaMorphoReallocateHook();
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Accrue interest on a Morpho Blue market and then get the vault's supply assets
    /// @notice Must accrue interest first to match MetaMorpho's internal calculation during reallocate()
    function _getSupplyAssets(MarketParams memory marketParams, address vault) internal returns (uint256 assets) {
        IMorphoBase(MORPHO).accrueInterest(marketParams);

        Id marketId = marketParams.id();
        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, vault);
        if (supplyShares == 0) return 0;

        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = IMorphoStaticTyping(MORPHO).market(marketId);
        if (totalSupplyShares == 0) return 0;

        assets = supplyShares * uint256(totalSupplyAssets) / uint256(totalSupplyShares);
    }

    /// @dev Get the supply assets without accruing interest (view function for post-execution checks)
    function _getSupplyAssetsView(Id marketId, address vault) internal view returns (uint256 assets) {
        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, vault);
        if (supplyShares == 0) return 0;

        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = IMorphoStaticTyping(MORPHO).market(marketId);
        if (totalSupplyShares == 0) return 0;

        assets = supplyShares * uint256(totalSupplyAssets) / uint256(totalSupplyShares);
    }

    /// @dev Get MarketParams from a market Id via Morpho Blue
    function _getMarketParams(Id marketId) internal view returns (MarketParams memory) {
        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            IMorphoStaticTyping(MORPHO).idToMarketParams(marketId);

        return MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }

    /// @dev Encode hook data matching the MetaMorphoReallocateHook data layout
    function _encodeData(
        address vault,
        bool usePrevHookAmount,
        uint8 prevHookAmountIndex,
        MarketAllocation[] memory allocations
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory placeholder = new bytes(32);
        bytes memory allocationsData = abi.encode(allocations);

        return bytes.concat(
            placeholder,
            abi.encodePacked(vault),
            abi.encodePacked(usePrevHookAmount ? uint8(1) : uint8(0)),
            abi.encodePacked(prevHookAmountIndex),
            allocationsData
        );
    }

    /// @dev Find a source market (with supply) and a destination market (from the supply queue)
    /// @notice Accrues interest on all markets to match MetaMorpho's internal accounting
    /// @return srcParams Source market params (has supply)
    /// @return dstParams Destination market params (may have 0 supply)
    /// @return srcSupply Current supply in source market (after interest accrual)
    /// @return dstSupply Current supply in destination market (after interest accrual)
    function _findSourceAndDestMarkets()
        internal
        returns (MarketParams memory srcParams, MarketParams memory dstParams, uint256 srcSupply, uint256 dstSupply)
    {
        uint256 queueLen = IMetaMorphoRead(META_MORPHO_VAULT).supplyQueueLength();
        require(queueLen >= 2, "Vault needs at least 2 markets in supply queue");

        bool foundSrc;
        for (uint256 i; i < queueLen; i++) {
            Id marketId = IMetaMorphoRead(META_MORPHO_VAULT).supplyQueue(i);
            MarketParams memory params = _getMarketParams(marketId);
            uint256 supply = _getSupplyAssets(params, META_MORPHO_VAULT);

            if (!foundSrc && supply > 0) {
                srcParams = params;
                srcSupply = supply;
                foundSrc = true;
            } else if (foundSrc) {
                dstParams = params;
                dstSupply = supply;
                return (srcParams, dstParams, srcSupply, dstSupply);
            }
        }

        revert("Could not find source market with supply and a destination market");
    }

    /*//////////////////////////////////////////////////////////////
                            E2E TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the hook builds correct executions targeting the real MetaMorpho vault
    function test_Build_RealVaultAddress() public {
        (MarketParams memory srcParams, MarketParams memory dstParams, uint256 srcSupply, uint256 dstSupply) =
            _findSourceAndDestMarkets();

        console2.log("=== Build Test: Real Vault Address ===");
        console2.log("Source market supply:", srcSupply);
        console2.log("Dest market supply:", dstSupply);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply });
        allocations[1] = MarketAllocation({ marketParams: dstParams, assets: dstSupply });

        bytes memory data = _encodeData(META_MORPHO_VAULT, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3, "Should have 3 executions (pre + hook + post)");
        assertEq(executions[1].target, META_MORPHO_VAULT, "Execution target should be MetaMorpho vault");
        assertEq(executions[1].value, 0, "Execution value should be 0");

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (allocations));
        assertEq(executions[1].callData, expectedCalldata, "Calldata should match reallocate encoding");
    }

    /// @notice Execute a real reallocation: move supply from one market to another
    function test_Reallocate_MovesSupplyBetweenMarkets() public {
        (MarketParams memory srcParams, MarketParams memory dstParams, uint256 srcSupply, uint256 dstSupply) =
            _findSourceAndDestMarkets();

        console2.log("=== Reallocate E2E: Move Supply Between Markets ===");
        console2.log("Source market supply before:", srcSupply);
        console2.log("Dest market supply before:", dstSupply);

        // Move 1% of source market's supply to destination (small amount to avoid hitting caps)
        uint256 moveAmount = srcSupply / 100;
        require(moveAmount > 0, "Move amount must be > 0");
        console2.log("Moving amount:", moveAmount);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply - moveAmount });
        allocations[1] = MarketAllocation({ marketParams: dstParams, assets: dstSupply + moveAmount });

        bytes memory data = _encodeData(META_MORPHO_VAULT, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Execute the reallocate as the vault owner (who has allocator privileges)
        address vaultOwner = IMetaMorphoRead(META_MORPHO_VAULT).owner();
        console2.log("Vault owner:", vaultOwner);

        vm.prank(vaultOwner);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "reallocate() should succeed on real vault");

        // Verify supply shifted
        Id srcId = srcParams.id();
        Id dstId = dstParams.id();
        uint256 srcSupplyAfter = _getSupplyAssetsView(srcId, META_MORPHO_VAULT);
        uint256 dstSupplyAfter = _getSupplyAssetsView(dstId, META_MORPHO_VAULT);

        console2.log("Source market supply after:", srcSupplyAfter);
        console2.log("Dest market supply after:", dstSupplyAfter);

        assertApproxEqRel(srcSupplyAfter, srcSupply - moveAmount, 1e15, "Source market supply should decrease");
        assertApproxEqRel(dstSupplyAfter, dstSupply + moveAmount, 1e15, "Dest market supply should increase");
    }

    /// @notice Execute a no-op reallocation on the source market (keep same allocation)
    function test_Reallocate_NoOp_SingleMarket() public {
        (MarketParams memory srcParams,, uint256 srcSupply,) = _findSourceAndDestMarkets();

        console2.log("=== Reallocate E2E: No-Op (Single Market) ===");
        console2.log("Source market supply:", srcSupply);

        // No-op: target equals current supply (no withdrawal, no supply)
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply });

        bytes memory data = _encodeData(META_MORPHO_VAULT, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        address vaultOwner = IMetaMorphoRead(META_MORPHO_VAULT).owner();

        vm.prank(vaultOwner);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "no-op reallocate should succeed");

        // Verify supply unchanged
        Id srcId = srcParams.id();
        uint256 srcSupplyAfter = _getSupplyAssetsView(srcId, META_MORPHO_VAULT);
        assertApproxEqRel(srcSupplyAfter, srcSupply, 1e15, "Supply should be unchanged");
    }

    /// @notice Verify that reallocate reverts when called by non-allocator
    function test_Reallocate_RevertsIf_NotAllocator() public {
        (MarketParams memory srcParams,, uint256 srcSupply,) = _findSourceAndDestMarkets();

        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply });

        bytes memory data = _encodeData(META_MORPHO_VAULT, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Execute as random address (not allocator)
        address notAllocator = makeAddr("notAllocator");
        vm.prank(notAllocator);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "reallocate should revert for non-allocator");
    }

    /// @notice Verify inspect returns the vault address from real data
    function test_Inspect_RealData() public {
        (MarketParams memory srcParams,, uint256 srcSupply,) = _findSourceAndDestMarkets();

        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply });

        bytes memory data = _encodeData(META_MORPHO_VAULT, false, 0, allocations);
        bytes memory inspectionResult = hook.inspect(data);

        address inspectedVault = BytesLib.toAddress(inspectionResult, 0);
        assertEq(inspectedVault, META_MORPHO_VAULT, "Inspect should return real vault address");
    }

    /// @notice Full cycle: query vault state, build hook, execute reallocate, verify results
    function test_FullCycle_QueryBuildExecuteVerify() public {
        console2.log("=== Full Cycle E2E: Query -> Build -> Execute -> Verify ===");

        // Step 1: Query vault state
        uint256 queueLen = IMetaMorphoRead(META_MORPHO_VAULT).supplyQueueLength();
        console2.log("Supply queue length:", queueLen);
        assertTrue(queueLen >= 2, "Vault should have at least 2 markets");

        // Step 2: Get all markets and their supply (accrue interest first for accurate values)
        Id[] memory marketIds = new Id[](queueLen);
        MarketParams[] memory allParams = new MarketParams[](queueLen);
        uint256[] memory allSupplies = new uint256[](queueLen);

        for (uint256 i; i < queueLen; i++) {
            marketIds[i] = IMetaMorphoRead(META_MORPHO_VAULT).supplyQueue(i);
            allParams[i] = _getMarketParams(marketIds[i]);
            allSupplies[i] = _getSupplyAssets(allParams[i], META_MORPHO_VAULT);
            console2.log("  Market", i, "supply:", allSupplies[i]);
        }

        // Step 3: Find source (has supply) and build reallocation to destination
        uint256 srcIdx;
        uint256 dstIdx;
        bool foundSrc;
        for (uint256 i; i < queueLen; i++) {
            if (!foundSrc && allSupplies[i] > 0) {
                srcIdx = i;
                foundSrc = true;
            } else if (foundSrc) {
                dstIdx = i;
                break;
            }
        }
        require(foundSrc, "Need at least 1 market with supply");

        uint256 moveAmount = allSupplies[srcIdx] / 50; // Move 2%
        require(moveAmount > 0, "Move amount must be > 0");
        console2.log("Moving from source to dest, amount:", moveAmount);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] =
            MarketAllocation({ marketParams: allParams[srcIdx], assets: allSupplies[srcIdx] - moveAmount });
        allocations[1] =
            MarketAllocation({ marketParams: allParams[dstIdx], assets: allSupplies[dstIdx] + moveAmount });

        // Step 4: Build hook executions
        bytes memory data = _encodeData(META_MORPHO_VAULT, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, META_MORPHO_VAULT);

        // Step 5: Execute as vault owner
        address vaultOwner = IMetaMorphoRead(META_MORPHO_VAULT).owner();
        vm.prank(vaultOwner);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "reallocate should succeed");

        // Step 6: Verify
        uint256 srcSupplyAfter = _getSupplyAssetsView(marketIds[srcIdx], META_MORPHO_VAULT);
        uint256 dstSupplyAfter = _getSupplyAssetsView(marketIds[dstIdx], META_MORPHO_VAULT);

        console2.log("Source market supply after:", srcSupplyAfter);
        console2.log("Dest market supply after:", dstSupplyAfter);

        assertApproxEqRel(srcSupplyAfter, allSupplies[srcIdx] - moveAmount, 1e15);
        assertApproxEqRel(dstSupplyAfter, allSupplies[dstIdx] + moveAmount, 1e15);

        console2.log("Full cycle completed successfully");
    }
}

/// @title MetaMorphoReallocateSuperVaultE2E
/// @notice E2E test for MetaMorphoReallocateHook executed through real deployed SuperVaultStrategy
/// @dev Uses the same SuperVault infrastructure as MorphoSuperVaultE2E (Flagship USDC SuperVault)
/// @dev The strategy is granted allocator role on the MetaMorpho vault via setIsAllocator
/// @dev Strategy: 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD (Flagship USDC SuperVault)
/// @dev Manager: 0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c
contract MetaMorphoReallocateSuperVaultE2E is Test, Constants {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Steakhouse USDC MetaMorpho vault on Ethereum mainnet
    address public constant META_MORPHO_VAULT = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;

    /// @dev Real deployed SuperVault strategy (Flagship USDC, Ethereum mainnet)
    address public constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;
    address public constant MANAGER = 0xb3dCDaA89B0A43bcC59a9BDEEb5583EC2071066c;
    address public constant AGGREGATOR = 0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698;
    address public constant SUPER_GOVERNOR = 0xB5396ef2bF8CA360cEB4166b77AFb2bed20e74d4;

    /// @dev Fork at a block after strategy deployment (deployed at block 23922236)
    uint256 public constant FORK_BLOCK = 23_930_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ISuperVaultStrategyExecute public strategy;
    MetaMorphoReallocateHook public hook;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);

        strategy = ISuperVaultStrategyExecute(STRATEGY);
        hook = new MetaMorphoReallocateHook();

        // Mock governance layer (same pattern as MorphoSuperVaultE2E)
        vm.mockCall(
            SUPER_GOVERNOR,
            abi.encodeWithSelector(ISuperGovernor.isHookRegistered.selector, address(hook)),
            abi.encode(true)
        );
        vm.mockCall(
            AGGREGATOR,
            abi.encodeWithSelector(ISuperVaultAggregator.validateHook.selector),
            abi.encode(true)
        );
        vm.mockCall(
            AGGREGATOR,
            abi.encodeWithSelector(ISuperVaultAggregator.isAnyManager.selector, MANAGER, STRATEGY),
            abi.encode(true)
        );

        // Grant the strategy allocator role on the MetaMorpho vault
        address vaultOwner = IMetaMorphoRead(META_MORPHO_VAULT).owner();
        vm.prank(vaultOwner);
        IMetaMorphoRead(META_MORPHO_VAULT).setIsAllocator(STRATEGY, true);
        assertTrue(IMetaMorphoRead(META_MORPHO_VAULT).isAllocator(STRATEGY), "Strategy should be allocator");
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Accrue interest and get supply assets
    function _getSupplyAssets(MarketParams memory marketParams, address vault) internal returns (uint256 assets) {
        IMorphoBase(MORPHO).accrueInterest(marketParams);

        Id marketId = marketParams.id();
        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, vault);
        if (supplyShares == 0) return 0;

        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = IMorphoStaticTyping(MORPHO).market(marketId);
        if (totalSupplyShares == 0) return 0;

        assets = supplyShares * uint256(totalSupplyAssets) / uint256(totalSupplyShares);
    }

    /// @dev Get supply assets without accruing interest (for post-execution checks)
    function _getSupplyAssetsView(Id marketId, address vault) internal view returns (uint256 assets) {
        (uint256 supplyShares,,) = IMorphoStaticTyping(MORPHO).position(marketId, vault);
        if (supplyShares == 0) return 0;

        (uint128 totalSupplyAssets, uint128 totalSupplyShares,,,,) = IMorphoStaticTyping(MORPHO).market(marketId);
        if (totalSupplyShares == 0) return 0;

        assets = supplyShares * uint256(totalSupplyAssets) / uint256(totalSupplyShares);
    }

    /// @dev Get MarketParams from a market Id
    function _getMarketParams(Id marketId) internal view returns (MarketParams memory) {
        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            IMorphoStaticTyping(MORPHO).idToMarketParams(marketId);

        return MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }

    /// @dev Encode hook data
    function _encodeData(
        address vault,
        bool usePrevHookAmount,
        uint8 prevHookAmountIndex,
        MarketAllocation[] memory allocations
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory placeholder = new bytes(32);
        bytes memory allocationsData = abi.encode(allocations);

        return bytes.concat(
            placeholder,
            abi.encodePacked(vault),
            abi.encodePacked(usePrevHookAmount ? uint8(1) : uint8(0)),
            abi.encodePacked(prevHookAmountIndex),
            allocationsData
        );
    }

    /// @dev Build ExecuteArgs for a single hook (empty Merkle proofs since validation is mocked)
    function _buildArgs(bytes memory hookCalldata) internal view returns (ISuperVaultStrategyExecute.ExecuteArgs memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = address(hook);

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = hookCalldata;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0;

        bytes32[][] memory emptyProofs = new bytes32[][](1);
        emptyProofs[0] = new bytes32[](0);

        return ISuperVaultStrategyExecute.ExecuteArgs({
            hooks: hooks,
            hookCalldata: calldatas,
            expectedAssetsOrSharesOut: expectedOut,
            globalProofs: emptyProofs,
            strategyProofs: emptyProofs
        });
    }

    /// @dev Find source and destination markets from the vault's supply queue
    function _findSourceAndDestMarkets()
        internal
        returns (MarketParams memory srcParams, MarketParams memory dstParams, uint256 srcSupply, uint256 dstSupply)
    {
        uint256 queueLen = IMetaMorphoRead(META_MORPHO_VAULT).supplyQueueLength();
        require(queueLen >= 2, "Vault needs at least 2 markets in supply queue");

        bool foundSrc;
        for (uint256 i; i < queueLen; i++) {
            Id marketId = IMetaMorphoRead(META_MORPHO_VAULT).supplyQueue(i);
            MarketParams memory params = _getMarketParams(marketId);
            uint256 supply = _getSupplyAssets(params, META_MORPHO_VAULT);

            if (!foundSrc && supply > 0) {
                srcParams = params;
                srcSupply = supply;
                foundSrc = true;
            } else if (foundSrc) {
                dstParams = params;
                dstSupply = supply;
                return (srcParams, dstParams, srcSupply, dstSupply);
            }
        }

        revert("Could not find source and destination markets");
    }

    /*//////////////////////////////////////////////////////////////
                    SUPERVAULT CONTEXT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute reallocate through real SuperVaultStrategy.executeHooks
    function test_SuperVault_Reallocate_ThroughStrategy() public {
        (MarketParams memory srcParams, MarketParams memory dstParams, uint256 srcSupply, uint256 dstSupply) =
            _findSourceAndDestMarkets();

        console2.log("=== SuperVault E2E: Reallocate Through Strategy ===");
        console2.log("Source market supply before:", srcSupply);
        console2.log("Dest market supply before:", dstSupply);

        // Move 1% from source to destination
        uint256 moveAmount = srcSupply / 100;
        require(moveAmount > 0, "Move amount must be > 0");
        console2.log("Moving amount:", moveAmount);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply - moveAmount });
        allocations[1] = MarketAllocation({ marketParams: dstParams, assets: dstSupply + moveAmount });

        bytes memory hookData = _encodeData(META_MORPHO_VAULT, false, 0, allocations);

        // Execute through real SuperVault strategy as the manager
        vm.prank(MANAGER);
        strategy.executeHooks(_buildArgs(hookData));

        // Verify supply shifted
        Id srcId = srcParams.id();
        Id dstId = dstParams.id();
        uint256 srcSupplyAfter = _getSupplyAssetsView(srcId, META_MORPHO_VAULT);
        uint256 dstSupplyAfter = _getSupplyAssetsView(dstId, META_MORPHO_VAULT);

        console2.log("Source market supply after:", srcSupplyAfter);
        console2.log("Dest market supply after:", dstSupplyAfter);

        assertApproxEqRel(srcSupplyAfter, srcSupply - moveAmount, 1e15, "Source should decrease");
        assertApproxEqRel(dstSupplyAfter, dstSupply + moveAmount, 1e15, "Dest should increase");
    }

    /// @notice No-op reallocate through SuperVaultStrategy
    function test_SuperVault_Reallocate_NoOp() public {
        (MarketParams memory srcParams,, uint256 srcSupply,) = _findSourceAndDestMarkets();

        console2.log("=== SuperVault E2E: No-Op Reallocate ===");
        console2.log("Source market supply:", srcSupply);

        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply });

        bytes memory hookData = _encodeData(META_MORPHO_VAULT, false, 0, allocations);

        vm.prank(MANAGER);
        strategy.executeHooks(_buildArgs(hookData));

        Id srcId = srcParams.id();
        uint256 srcSupplyAfter = _getSupplyAssetsView(srcId, META_MORPHO_VAULT);
        assertApproxEqRel(srcSupplyAfter, srcSupply, 1e15, "Supply should be unchanged");
    }

    /// @notice Verify strategy without allocator role cannot reallocate
    function test_SuperVault_Reallocate_RevertsWithout_AllocatorRole() public {
        (MarketParams memory srcParams,, uint256 srcSupply,) = _findSourceAndDestMarkets();

        // Revoke allocator role from strategy
        address vaultOwner = IMetaMorphoRead(META_MORPHO_VAULT).owner();
        vm.prank(vaultOwner);
        IMetaMorphoRead(META_MORPHO_VAULT).setIsAllocator(STRATEGY, false);

        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: srcParams, assets: srcSupply });

        bytes memory hookData = _encodeData(META_MORPHO_VAULT, false, 0, allocations);

        vm.prank(MANAGER);
        vm.expectRevert();
        strategy.executeHooks(_buildArgs(hookData));
    }
}
