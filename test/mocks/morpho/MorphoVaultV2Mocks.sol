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

    /// @dev Lets the vault mock keep the adapter's position honest after a pull.
    function reducePosition(bytes32 id, uint256 amount) external {
        positions[id] = positions[id] >= amount ? positions[id] - amount : 0;
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

interface IMockMintable {
    function mint(address to, uint256 amount) external;
}

/// @notice A Morpho Vault V2 stand-in that records every `forceDeallocate` and reproduces V2's share math
/// @dev TWO FIDELITY LEVELS, both needed. The deallocate-only hooks read `previewWithdraw` as a solvency
///      bound and nothing else, so the legacy `setPreviewRate` knob stays for their suites. The redeem hook
///      (SUP-21849) reads `accrueInterestView / totalSupply / virtualShares` and plans an exact
///      `redeem(S - P)`, so this mock also carries real totals and applies V2's own arithmetic:
///        - accrual once per transaction (`transient` latch, like V2's `firstTotalAssets`), minting the
///          pending fee shares and settling `_totalAssets` on the first state-changing call;
///        - `forceDeallocate`: assets move adapter -> vault (minted to the vault here), then
///          `pa = mulDivUp(assets, rate, 1e18)`, `ps = mulDivUp(pa, N, D)`, burn `ps` from `onBehalf`,
///          `_totalAssets -= pa`, return `ps`;
///        - `redeem`: `assets = mulDivDown(shares, D, N)`, requires idle, burns, transfers.
///      `setTotals` opts a test into the totals model; until then `totalSupply()` is zero and the redeem
///      hook would price nothing, which is what the deallocate suites expect.
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

    // ── V2 totals model ──
    uint256 public totalSupply;
    uint256 public virtualShares = 1;
    uint256 internal _totalAssets;
    uint256 internal pendingPerfShares;
    uint256 internal pendingMgmtShares;
    bool transient accrued;
    /// @dev When set, the mock keeps the adapter's `expectedSupplyAssets` in step with the pulls.
    bool internal trackPositions;

    Call[] public calls;

    constructor(address asset_) {
        asset = asset_;
    }

    function addAdapter(address adapter, uint256 penaltyWad) external {
        registered.push(adapter);
        penalties[adapter] = penaltyWad;
    }

    function setPenalty(address adapter, uint256 penaltyWad) external {
        penalties[adapter] = penaltyWad;
    }

    function setShares(address account, uint256 amount) external {
        shares[account] = amount;
    }

    /// @dev `previewWithdraw` returns `assets * rate / 1e18`, rounded up, so a test can make shares
    ///      arbitrarily expensive relative to assets and exercise the solvency bound (legacy knob).
    function setPreviewRate(uint256 rate) external {
        previewRate = rate;
    }

    /// @notice Opt into the V2 totals model
    /// @param supply `totalSupply` EXCLUDING virtual shares
    /// @param assets_ `_totalAssets` before accrual
    /// @param virtual_ the virtual-share offset (`10 ** decimalOffset`)
    function setTotals(uint256 supply, uint256 assets_, uint256 virtual_) external {
        totalSupply = supply;
        _totalAssets = assets_;
        virtualShares = virtual_;
    }

    /// @notice Fee shares the next accrual will mint (both recipients are this contract, kept simple)
    function setPendingFees(uint256 perf, uint256 mgmt) external {
        pendingPerfShares = perf;
        pendingMgmtShares = mgmt;
    }

    function setTrackPositions(bool v) external {
        trackPositions = v;
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

    /// @dev Legacy, rate-based (the deallocate-only hooks' solvency bound).
    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return (assets * previewRate + 1e18 - 1) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                          V2 EXCHANGE-RATE MODEL
    //////////////////////////////////////////////////////////////*/

    /// @dev `(newTotalAssets, perfShares, mgmtShares)`; `(_totalAssets, 0, 0)` once accrued in this tx.
    function accrueInterestView() public view returns (uint256, uint256, uint256) {
        if (accrued) return (_totalAssets, 0, 0);
        return (_totalAssets, pendingPerfShares, pendingMgmtShares);
    }

    function _accrueInterest() internal {
        if (accrued) return;
        totalSupply += pendingPerfShares + pendingMgmtShares;
        shares[address(this)] += pendingPerfShares + pendingMgmtShares;
        pendingPerfShares = 0;
        pendingMgmtShares = 0;
        accrued = true;
    }

    function _n() internal view returns (uint256) {
        (, uint256 pf, uint256 mf) = accrueInterestView();
        return totalSupply + pf + mf + virtualShares;
    }

    function _d() internal view returns (uint256) {
        (uint256 ta,,) = accrueInterestView();
        return ta + 1;
    }

    function previewRedeem(uint256 shares_) public view returns (uint256) {
        return _mulDivDown(shares_, _d(), _n());
    }

    /// @dev V2-shaped `previewWithdraw` for tests that want the totals model explicitly
    function previewWithdrawV2(uint256 assets) public view returns (uint256) {
        return _mulDivUp(assets, _n(), _d());
    }

    function totalAssets() external view returns (uint256) {
        (uint256 ta,,) = accrueInterestView();
        return ta;
    }

    function forceDeallocate(
        address adapter,
        bytes memory data,
        uint256 assets,
        address onBehalf
    )
        external
        returns (uint256 penaltyShares)
    {
        calls.push(Call(adapter, data, assets, onBehalf, msg.sender));
        if (totalSupply == 0) return 0; // legacy model: record only

        // deallocateInternal: adapter -> vault, value-preserving
        IMockMintable(asset).mint(address(this), assets);
        if (trackPositions) {
            MarketParams memory p = abi.decode(data, (MarketParams));
            MockMorphoMarketAdapter(adapter).reducePosition(keccak256(abi.encode(p)), assets);
        }
        // withdraw(penaltyAssets, address(this), onBehalf)
        _accrueInterest();
        uint256 penaltyAssets = _mulDivUp(assets, penalties[adapter], 1e18);
        penaltyShares = _mulDivUp(penaltyAssets, _n(), _d());
        require(shares[onBehalf] >= penaltyShares, "mock: insufficient shares for penalty");
        shares[onBehalf] -= penaltyShares;
        totalSupply -= penaltyShares;
        _totalAssets -= penaltyAssets;
        // the penalty transfer is to the vault itself: idle unchanged
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

    /// @notice ERC-4626 `redeem` with V2's arithmetic: pays `floor(shares x D / N)` out of idle
    function redeem(uint256 shares_, address receiver, address owner) external virtual returns (uint256 assets) {
        _accrueInterest();
        assets = previewRedeem(shares_);
        require(IMockBalance(asset).balanceOf(address(this)) >= assets, "mock: idle too low");
        require(shares[owner] >= shares_, "mock: insufficient shares");
        shares[owner] -= shares_;
        totalSupply -= shares_;
        _totalAssets -= assets;
        IMockTransfer(asset).transfer(receiver, assets);
    }

    /// @notice ERC-4626 `withdraw`: pays `assets` of underlying and burns the corresponding shares (legacy)
    function withdraw(uint256 assets, address receiver, address owner) external virtual returns (uint256 sharesBurned) {
        sharesBurned = (assets * previewRate + 1e18 - 1) / 1e18;
        require(shares[owner] >= sharesBurned, "mock: insufficient shares");
        shares[owner] -= sharesBurned;
        IMockMintable(asset).mint(receiver, assets);
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y + (d - 1)) / d;
    }

    function _mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }
}

interface IMockBalance {
    function balanceOf(address) external view returns (uint256);
}

interface IMockTransfer {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @notice An underlying that keeps a cut on every transfer, to prove `outAmount` is MEASURED not declared
/// @dev `ForceRedeemMorphoVaultHook` publishes the account's observed balance delta rather than the
///      quoted amount. On a plain ERC-20 the two are equal, so only a token that delivers less can tell
///      the two implementations apart.
contract FeeOnTransferToken {
    string public name = "Fee On Transfer";
    string public symbol = "FOT";
    uint8 public decimals = 18;
    uint256 public feeBps;
    mapping(address => uint256) public balanceOf;

    constructor(uint256 feeBps_) {
        feeBps = feeBps_;
    }

    /// @dev Mint is fee-free: it stands in for the adapter -> vault move, which is value-preserving.
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    /// @dev Vault -> receiver with the cut taken, so a redeem delivers less than the vault accounted.
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "fot: balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount - (amount * feeBps) / 10_000;
        return true;
    }

    function asset() external view returns (address) {
        return address(this);
    }
}

/// @notice A vault that MINTS shares during the redeem, to reach `_postExecute`'s clamp
/// @dev The clamp cannot be reached by any honest path — every leg of the hook only burns the account's
///      shares — so the only way to cover that branch is a vault that violates the assumption.
contract SharesInflatingVault is MockMorphoVaultV2 {
    bool public inflate;

    constructor(address asset_) MockMorphoVaultV2(asset_) { }

    function setInflate(bool v) external {
        inflate = v;
    }

    function redeem(uint256 shares_, address receiver, address owner) external override returns (uint256 assets) {
        assets = previewRedeem(shares_);
        IMockMintable(asset).mint(receiver, assets);
        if (inflate) _creditShares(owner, shares_ * 10);
    }
}
