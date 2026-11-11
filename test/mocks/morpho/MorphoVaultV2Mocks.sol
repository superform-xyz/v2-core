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
    /// @dev Explicit getters rather than public vars so the gas-burning switch can cover EVERY probe the
    ///      hook makes. A worst-case measurement that cannot burn on two of the six probes understates the
    ///      bound it claims to prove.
    address internal _parentVault;
    address internal _morpho;

    bytes32[] internal ids;
    mapping(bytes32 => uint256) internal positions;

    /// @dev When zero, `adaptiveCurveIrm()` REVERTS, which is the V1 adapter shape the hook must read as
    ///      "pins no IRM". A non-zero value makes it answer, which is the V2 shape.
    address internal pinnedIrm;
    bool internal breakMarketIdsLength;
    bool internal overlongReplies;
    /// @dev Spins until the caller's stipend is nearly gone, then answers correctly. Models the adapter
    ///      that is not malformed but simply expensive — the case a per-probe stipend cannot catch,
    ///      because `staticcall` does not surface out-of-gas to the caller.
    bool internal burnGas;
    /// @dev Answers `adaptiveCurveIrm()` with the zero address instead of reverting. The hook reads a
    ///      FAILED probe as "pins no IRM"; this is the distinct case of an adapter that answers and says
    ///      zero, which disables the IRM filter through a success rather than a failure.
    bool internal zeroIrm;
    /// @dev `morpho()` reverts. Distinct from a codeless adapter: the contract exists and answers
    ///      `parentVault()` correctly, then fails the very next probe.
    bool internal breakMorpho;

    constructor(address parentVault_, address morpho_) {
        _parentVault = parentVault_;
        _morpho = morpho_;
    }

    function parentVault() external view returns (address) {
        _burn();
        return _parentVault;
    }

    function morpho() external view returns (address) {
        _burn();
        require(!breakMorpho, "no morpho");
        return _morpho;
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

    function setBurnGas(bool value) external {
        burnGas = value;
    }

    function setZeroIrm(bool value) external {
        zeroIrm = value;
    }

    function setBreakMorpho(bool value) external {
        breakMorpho = value;
    }

    /// @dev Leaves ~2k so the call still returns rather than reverting, which is the expensive case.
    function _burn() private view {
        if (!burnGas) return;
        uint256 dummy;
        while (gasleft() > 2000) {
            dummy = uint256(keccak256(abi.encode(dummy)));
        }
    }

    function marketIdsLength() external view returns (uint256) {
        _burn();
        require(!breakMarketIdsLength, "no market list");
        return ids.length;
    }

    function marketIds(uint256 index) external view returns (bytes32) {
        _burn();
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
        _burn();
        return positions[id];
    }

    function adaptiveCurveIrm() external view returns (address) {
        _burn();
        if (zeroIrm) return address(0);
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

    function _creditShares(address owner, uint256 amount) internal {
        shares[owner] += amount;
    }

    /// @notice ERC-4626 `withdraw`: pays `assets` of underlying and burns the corresponding shares
    /// @dev Needed because `ForceRedeemMorphoVaultHook` measures what the account actually RECEIVED. A mock
    ///      that recorded the call without moving tokens would let the hook's accounting assertions pass
    ///      against an outAmount of zero, which is the one thing they exist to catch.
    function withdraw(uint256 assets, address receiver, address owner)
        external
        virtual
        returns (uint256 sharesBurned)
    {
        sharesBurned = (assets * previewRate + 1e18 - 1) / 1e18;
        require(shares[owner] >= sharesBurned, "mock: insufficient shares");
        shares[owner] -= sharesBurned;
        IMockMintable(asset).mint(receiver, assets);
    }

}

interface IMockMintable {
    function mint(address to, uint256 amount) external;
}

/// @notice An underlying that keeps a cut on every transfer, to prove `outAmount` is MEASURED not declared
/// @dev `ForceRedeemMorphoVaultHook` publishes the account's observed balance delta rather than the
///      requested `assets`. On a plain ERC-20 the two are equal, so only a token that delivers less can
///      tell the two implementations apart.
contract FeeOnTransferToken {
    string public name = "Fee On Transfer";
    string public symbol = "FOT";
    uint8 public decimals = 18;
    uint256 public feeBps;
    mapping(address => uint256) public balanceOf;

    constructor(uint256 feeBps_) {
        feeBps = feeBps_;
    }

    function mint(address to, uint256 amount) external {
        uint256 fee = (amount * feeBps) / 10_000;
        balanceOf[to] += amount - fee;
    }

    function asset() external view returns (address) {
        return address(this);
    }
}

/// @notice A vault that MINTS shares during the withdraw, to reach `_postExecute`'s clamp
/// @dev The clamp cannot be reached by any honest path — every leg of the hook only burns the account's
///      shares — so the only way to cover that branch is a vault that violates the assumption.
contract SharesInflatingVault is MockMorphoVaultV2 {
    bool public inflate;

    constructor(address asset_) MockMorphoVaultV2(asset_) { }

    function setInflate(bool v) external {
        inflate = v;
    }

    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        IMockMintable(asset).mint(receiver, assets);
        if (inflate) _creditShares(owner, assets * 10);
        return 0;
    }
}
