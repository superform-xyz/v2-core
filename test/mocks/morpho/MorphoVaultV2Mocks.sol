// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MarketParams } from "../../../src/vendor/morpho/IMorpho.sol";

/// @notice Minimal Morpho Blue stand-in exposing only the two mapping getters the hook reads
/// @dev Both getters are PUBLIC MAPPINGS on the real Morpho Blue, so an unknown id returns zeros rather
///      than reverting. These mocks reproduce that, because the hook's "skip a market whose loanToken is
///      zero" filter depends on it.
contract MockMorphoBlue {
    struct MarketState {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
        uint128 lastUpdate;
        uint128 fee;
    }

    mapping(bytes32 => MarketState) internal states;
    mapping(bytes32 => MarketParams) internal params;

    function setMarket(bytes32 id, MarketParams memory p, uint128 supplyAssets, uint128 borrowAssets) external {
        params[id] = p;
        states[id] = MarketState(supplyAssets, supplyAssets, borrowAssets, borrowAssets, uint128(block.timestamp), 0);
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128) {
        MarketState memory s = states[id];
        return (s.totalSupplyAssets, s.totalSupplyShares, s.totalBorrowAssets, s.totalBorrowShares, s.lastUpdate, s.fee);
    }

    function idToMarketParams(bytes32 id) external view returns (address, address, address, address, uint256) {
        MarketParams memory p = params[id];
        return (p.loanToken, p.collateralToken, p.oracle, p.irm, p.lltv);
    }
}

/// @notice A Morpho Blue market adapter of a Vault V2, with every behaviour the hook filters on switchable
contract MockMorphoMarketAdapter {
    address public parentVault;
    address public morpho;

    bytes32[] internal ids;
    mapping(bytes32 => uint256) internal positions;

    /// @dev When zero, `adaptiveCurveIrm()` REVERTS, which is the V1 adapter shape the hook must read as
    ///      "pins no IRM". A non-zero value makes it answer, which is the V2 shape.
    address internal pinnedIrm;
    bool internal breakMarketIdsLength;
    bool internal overlongReplies;

    constructor(address parentVault_, address morpho_) {
        parentVault = parentVault_;
        morpho = morpho_;
    }

    function addMarket(bytes32 id, uint256 position) external {
        ids.push(id);
        positions[id] = position;
    }

    function setPinnedIrm(address irm) external {
        pinnedIrm = irm;
    }

    /// @dev Reproduces a `MorphoVaultV1Adapter`, which has no market list at all
    function setBreakMarketIdsLength(bool value) external {
        breakMarketIdsLength = value;
    }

    /// @dev Reproduces a hostile adapter returning two words where one is expected, to prove the hook
    ///      treats an over-long reply as a failed probe instead of reverting inside `abi.decode`
    function setOverlongReplies(bool value) external {
        overlongReplies = value;
    }

    function marketIdsLength() external view returns (uint256) {
        require(!breakMarketIdsLength, "no market list");
        return ids.length;
    }

    function marketIds(uint256 index) external view returns (bytes32) {
        if (overlongReplies) {
            assembly {
                mstore(0, 1)
                mstore(32, 2)
                return(0, 64)
            }
        }
        return ids[index];
    }

    function expectedSupplyAssets(bytes32 id) external view returns (uint256) {
        return positions[id];
    }

    function adaptiveCurveIrm() external view returns (address) {
        require(pinnedIrm != address(0), "no pinned irm");
        return pinnedIrm;
    }
}

/// @notice A Morpho Vault V2 stand-in that records every `forceDeallocate` it receives
contract MockMorphoVaultV2 {
    struct Call {
        address adapter;
        bytes data;
        uint256 assets;
        address onBehalf;
        address caller;
    }

    address public asset;
    address[] internal registered;
    mapping(address => uint256) internal penalties;
    mapping(address => uint256) internal shares;
    uint256 internal previewRate = 1e18;

    Call[] public calls;

    constructor(address asset_) {
        asset = asset_;
    }

    function addAdapter(address adapter, uint256 penaltyWad) external {
        registered.push(adapter);
        penalties[adapter] = penaltyWad;
    }

    function setShares(address account, uint256 amount) external {
        shares[account] = amount;
    }

    /// @dev `previewWithdraw` returns `assets * rate / 1e18`, rounded up, so a test can make shares
    ///      arbitrarily expensive relative to assets and exercise the solvency bound.
    function setPreviewRate(uint256 rate) external {
        previewRate = rate;
    }

    function adaptersLength() external view returns (uint256) {
        return registered.length;
    }

    function adapters(uint256 index) external view returns (address) {
        return registered[index];
    }

    function forceDeallocatePenalty(address adapter) external view returns (uint256) {
        return penalties[adapter];
    }

    function balanceOf(address account) external view returns (uint256) {
        return shares[account];
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return (assets * previewRate + 1e18 - 1) / 1e18;
    }

    function forceDeallocate(
        address adapter,
        bytes memory data,
        uint256 assets,
        address onBehalf
    )
        external
        returns (uint256)
    {
        calls.push(Call(adapter, data, assets, onBehalf, msg.sender));
        return 0;
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }

    function callAt(uint256 i) external view returns (Call memory) {
        return calls[i];
    }
}
