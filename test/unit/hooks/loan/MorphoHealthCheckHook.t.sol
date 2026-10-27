// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { Helpers } from "../../../utils/Helpers.sol";
import { morphoMarketKey } from "../../../utils/MorphoMarketKey.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { MathLib } from "../../../../src/vendor/morpho/MathLib.sol";
import { SharesMathLib } from "../../../../src/vendor/morpho/SharesMathLib.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../../src/vendor/morpho/MorphoBalancesLib.sol";
import { Id, IMorpho, MarketParams, Market, Position } from "../../../../src/vendor/morpho/IMorpho.sol";
import { MorphoHealthCheckHook } from "../../../../src/hooks/loan/morpho/MorphoHealthCheckHook.sol";

// Mocks shared with the Morpho V2 loan-hook suite
import { MockMorpho, MockIRM, MockPrevHook } from "./MorphoLoanHooksV2.t.sol";

/*//////////////////////////////////////////////////////////////
                            LOCAL MOCKS
//////////////////////////////////////////////////////////////*/

/// @dev Settable Morpho IOracle: price of 1 collateral asset in loan assets, scaled by 1e36
contract MockMorphoOracle {
    uint256 public price;

    constructor(uint256 price_) {
        price = price_;
    }

    function setPrice(uint256 price_) external {
        price = price_;
    }
}

/// @dev Proves the no-debt path never consults the oracle
contract RevertingOracle {
    function price() external pure returns (uint256) {
        revert("ORACLE_MUST_NOT_BE_CALLED");
    }
}

/// @title MorphoHealthCheckHookTest
/// @notice Unit coverage for the Morpho Blue health-factor guard (no fork; MockMorpho + MockIRM)
contract MorphoHealthCheckHookTest is Helpers {
    using MarketParamsLib for MarketParams;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;
    uint256 internal constant DATA_LENGTH = 196;

    uint128 internal constant POSITION_BORROW_SHARES = 10e18;
    uint128 internal constant POSITION_COLLATERAL = 5e18;

    MorphoHealthCheckHook public hook;
    MockMorpho public mockMorpho;
    MockIRM public mockIRM;
    MockMorphoOracle public mockOracle;
    MockPrevHook public prevHook;

    address public loanToken;
    address public collateralToken;
    address public oracle;
    address public irm;
    uint256 public lltv;

    MarketParams public marketParams;
    Id public marketId;

    function setUp() public {
        mockMorpho = new MockMorpho();
        mockIRM = new MockIRM();
        irm = address(mockIRM);
        mockOracle = new MockMorphoOracle(ORACLE_PRICE_SCALE); // 1 collateral = 1 loan
        oracle = address(mockOracle);
        prevHook = new MockPrevHook();

        loanToken = address(new MockERC20("Loan Token", "LOAN", 18));
        collateralToken = address(new MockERC20("Collateral Token", "COLL", 18));
        lltv = 860_000_000_000_000_000; // 86%

        hook = new MorphoHealthCheckHook(address(mockMorpho));

        marketParams = MarketParams({
            loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv
        });
        marketId = marketParams.id();

        mockMorpho.setMarket(
            Market({
                totalSupplyAssets: 100e18,
                totalSupplyShares: 100e18,
                totalBorrowAssets: 80e18,
                totalBorrowShares: 80e18,
                lastUpdate: uint128(block.timestamp),
                fee: 0
            })
        );
        _setPosition(POSITION_BORROW_SHARES, POSITION_COLLATERAL);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setPosition(uint128 borrowShares, uint128 collateral) internal {
        mockMorpho.setPosition(
            marketId, address(this), Position({ supplyShares: 0, borrowShares: borrowShares, collateral: collateral })
        );
    }

    /// @dev Canonical 196-byte layout with the header key derived from the body
    function _encode(
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        uint256 minHealthFactor_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeWithKey(
            morphoMarketKey(loanToken_, collateralToken_, oracle_, irm_, lltv_),
            loanToken_,
            collateralToken_,
            oracle_,
            irm_,
            lltv_,
            minHealthFactor_
        );
    }

    function _encodeWithKey(
        address key,
        address loanToken_,
        address collateralToken_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        uint256 minHealthFactor_
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(bytes32(0), key, loanToken_, collateralToken_, oracle_, irm_, lltv_, minHealthFactor_);
        require(data.length == DATA_LENGTH, "layout must be exactly 196 bytes");
    }

    function _data(uint256 minHealthFactor_) internal view returns (bytes memory) {
        return _encode(loanToken, collateralToken, oracle, irm, lltv, minHealthFactor_);
    }

    /// @dev Morpho's `_isHealthy` numbers computed in-test with the same libraries the hook uses
    function _expectedBorrowed(MarketParams memory mp, uint128 borrowShares) internal view returns (uint256) {
        (uint256 totalBorrowAssets, uint256 totalBorrowShares) =
            MorphoBalancesLib.expectedBorrowBalances(IMorpho(address(mockMorpho)), mp);
        return uint256(borrowShares).toAssetsUp(totalBorrowAssets, totalBorrowShares);
    }

    function _expectedHealthFactor(
        MarketParams memory mp,
        uint128 borrowShares,
        uint128 collateral,
        uint256 price
    )
        internal
        view
        returns (uint256)
    {
        uint256 borrowed = _expectedBorrowed(mp, borrowShares);
        uint256 maxBorrow = uint256(collateral).mulDivDown(price, ORACLE_PRICE_SCALE).wMulDown(mp.lltv);
        return maxBorrow.wDivDown(borrowed);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_NonAccounting_MiscSubtype_MorphoImmutable() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.MISC);
        assertEq(hook.morpho(), address(mockMorpho));
        assertEq(address(hook.morphoStaticTyping()), address(mockMorpho));
        assertEq(hook.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(), WAD);
        assertEq(hook.ORACLE_PRICE_SCALE(), ORACLE_PRICE_SCALE);
    }

    function test_Constructor_RevertIf_ZeroMorpho() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoHealthCheckHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                                 BUILD
    //////////////////////////////////////////////////////////////*/

    function test_Build_ReturnsOnlyPreAndPost() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18); // hf ~4.3e18
        Execution[] memory executions = hook.build(address(0), address(this), _data(WAD));

        assertEq(executions.length, 2, "guard emits no executions of its own");
        assertEq(executions[0].target, address(hook));
        assertEq(bytes4(executions[0].callData), ISuperHook.preExecute.selector);
        assertEq(executions[1].target, address(hook));
        assertEq(bytes4(executions[1].callData), ISuperHook.postExecute.selector);
    }

    function test_Build_Pass_WhenHealthFactorAtOrAboveMin() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        uint256 hf = _expectedHealthFactor(marketParams, POSITION_BORROW_SHARES, 50e18, ORACLE_PRICE_SCALE);
        assertGt(hf, 4e18, "fixture: comfortably healthy");

        hook.build(address(0), address(this), _data(hf)); // exactly at min passes
        hook.build(address(0), address(this), _data(hf - 1));
        assertEq(hook.previewHealthFactor(_data(WAD), address(this)), hf);
    }

    function test_Build_Pass_NoDebt_ReturnsMax_NeverCallsOracle() public {
        address reverting = address(new RevertingOracle());
        MarketParams memory mp = MarketParams({
            loanToken: loanToken, collateralToken: collateralToken, oracle: reverting, irm: irm, lltv: lltv
        });
        mockMorpho.setPosition(
            mp.id(), address(this), Position({ supplyShares: 0, borrowShares: 0, collateral: POSITION_COLLATERAL })
        );
        bytes memory data = _encode(loanToken, collateralToken, reverting, irm, lltv, type(uint256).max);

        hook.build(address(0), address(this), data); // "must have no debt" passes without pricing
        assertEq(hook.previewHealthFactor(data, address(this)), type(uint256).max);
    }

    /// @notice With nonzero debt the oracle IS consulted, so a reverting oracle fails the guard closed
    ///         (the staticcall revert propagates) rather than silently passing. Complements the no-debt
    ///         path above, which must never touch the oracle.
    function test_Build_RevertIf_OracleReverts_WithDebt() public {
        address reverting = address(new RevertingOracle());
        MarketParams memory mp = MarketParams({
            loanToken: loanToken, collateralToken: collateralToken, oracle: reverting, irm: irm, lltv: lltv
        });
        // Nonzero borrow under the reverting-oracle market id so _healthFactor reaches price()
        mockMorpho.setPosition(
            mp.id(),
            address(this),
            Position({ supplyShares: 0, borrowShares: POSITION_BORROW_SHARES, collateral: POSITION_COLLATERAL })
        );
        bytes memory data = _encode(loanToken, collateralToken, reverting, irm, lltv, WAD);

        vm.expectRevert(bytes("ORACLE_MUST_NOT_BE_CALLED"));
        hook.build(address(0), address(this), data);

        vm.expectRevert(bytes("ORACLE_MUST_NOT_BE_CALLED"));
        hook.previewHealthFactor(data, address(this));
    }

    function test_Build_RevertIf_HealthFactorBelowMin() public {
        uint256 hf =
            _expectedHealthFactor(marketParams, POSITION_BORROW_SHARES, POSITION_COLLATERAL, ORACLE_PRICE_SCALE);
        assertLt(hf, WAD, "fixture: 5 collateral vs ~10 debt at 86% is underwater");

        vm.expectRevert(abi.encodeWithSelector(MorphoHealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, hf, WAD));
        hook.build(address(0), address(this), _data(WAD));
    }

    /// @dev Pins the rounding equivalence: at min = 1e18 the guard passes iff Morpho's `_isHealthy` is true
    function test_Build_Boundary_MatchesMorphoIsHealthy() public {
        uint256 fullLltv = WAD;
        MarketParams memory mp = MarketParams({
            loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: fullLltv
        });
        uint256 borrowed = _expectedBorrowed(mp, POSITION_BORROW_SHARES);
        bytes memory data = _encode(loanToken, collateralToken, oracle, irm, fullLltv, WAD);

        // maxBorrow == borrowed (price 1:1, lltv 100%, collateral == borrowed) -> hf == 1e18 -> passes
        mockMorpho.setPosition(
            mp.id(),
            address(this),
            Position({ supplyShares: 0, borrowShares: POSITION_BORROW_SHARES, collateral: uint128(borrowed) })
        );
        hook.build(address(0), address(this), data);
        assertEq(hook.previewHealthFactor(data, address(this)), WAD);

        // maxBorrow == borrowed - 1 -> Morpho would refuse -> guard reverts
        mockMorpho.setPosition(
            mp.id(),
            address(this),
            Position({ supplyShares: 0, borrowShares: POSITION_BORROW_SHARES, collateral: uint128(borrowed - 1) })
        );
        uint256 hf = (borrowed - 1).wDivDown(borrowed);
        vm.expectRevert(abi.encodeWithSelector(MorphoHealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, hf, WAD));
        hook.build(address(0), address(this), data);
    }

    function test_Build_ViewAccrual_LowersHealthFactorAfterWarp() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        bytes memory data = _data(WAD);
        uint256 before = hook.previewHealthFactor(data, address(this));

        vm.warp(block.timestamp + 1 days);
        uint256 after_ = hook.previewHealthFactor(data, address(this));

        assertLt(after_, before, "accrued interest raises debt and lowers the health factor");
        assertEq(after_, _expectedHealthFactor(marketParams, POSITION_BORROW_SHARES, 50e18, ORACLE_PRICE_SCALE));
    }

    function test_Build_RevertIf_HeaderNotMarketKey() public {
        bytes memory data = _encodeWithKey(address(0xBEEF), loanToken, collateralToken, oracle, irm, lltv, WAD);
        vm.expectRevert(MorphoHealthCheckHook.MARKET_KEY_MISMATCH.selector);
        hook.build(address(0), address(this), data);
    }

    function test_Build_RevertIf_WrongLength() public {
        bytes memory data = _data(WAD);
        bytes memory shorter = BytesLib.slice(data, 0, DATA_LENGTH - 1);
        bytes memory longer = abi.encodePacked(data, bytes1(0));

        vm.expectRevert(MorphoHealthCheckHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), address(this), shorter);
        vm.expectRevert(MorphoHealthCheckHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), address(this), longer);
    }

    function test_Build_RevertIf_ZeroAddresses() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(
            address(0), address(this), _encodeWithKey(address(0), loanToken, collateralToken, oracle, irm, lltv, WAD)
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encode(address(0), collateralToken, oracle, irm, lltv, WAD));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encode(loanToken, address(0), oracle, irm, lltv, WAD));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encode(loanToken, collateralToken, address(0), irm, lltv, WAD));
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encode(loanToken, collateralToken, oracle, address(0), lltv, WAD));
    }

    function test_Build_RevertIf_IdenticalTokens() public {
        vm.expectRevert(MorphoHealthCheckHook.IDENTICAL_TOKENS.selector);
        hook.build(address(0), address(this), _encode(loanToken, loanToken, oracle, irm, lltv, WAD));
    }

    function test_Build_RevertIf_MinBelowWad() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        vm.expectRevert(MorphoHealthCheckHook.INVALID_MIN_HEALTH_FACTOR.selector);
        hook.build(address(0), address(this), _data(WAD - 1));
        vm.expectRevert(MorphoHealthCheckHook.INVALID_MIN_HEALTH_FACTOR.selector);
        hook.build(address(0), address(this), _data(0));
    }

    /*//////////////////////////////////////////////////////////////
                           PRE / POST EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_RevertIf_HealthFactorBelowMin() public {
        bytes memory data = _data(WAD);
        uint256 hf =
            _expectedHealthFactor(marketParams, POSITION_BORROW_SHARES, POSITION_COLLATERAL, ORACLE_PRICE_SCALE);

        hook.preExecute(address(0), address(this), data); // passthrough, no read
        vm.expectRevert(abi.encodeWithSelector(MorphoHealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, hf, WAD));
        hook.postExecute(address(0), address(this), data);
    }

    function test_PostExecute_Pass() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        bytes memory data = _data(WAD);
        hook.preExecute(address(0), address(this), data);
        hook.postExecute(address(0), address(this), data);
    }

    /// @dev Build passes (healthy at build), position worsens, postExecute still catches it: the
    ///      post-action read is the authoritative one
    function test_PostExecute_CatchesStateChangeAfterBuild() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        bytes memory data = _data(WAD);
        hook.build(address(0), address(this), data);

        _setPosition(POSITION_BORROW_SHARES, POSITION_COLLATERAL);
        hook.preExecute(address(0), address(this), data);
        vm.expectRevert();
        hook.postExecute(address(0), address(this), data);
    }

    function test_PreExecute_Passthrough_ForwardsPrevHookOutput() public {
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        prevHook.setOutAmount(123);
        prevHook.setOutToken(loanToken);

        hook.preExecute(address(prevHook), address(this), _data(WAD));

        assertEq(hook.getOutAmount(address(this)), 123);
        assertEq(hook.getOutToken(address(this)), loanToken);
    }

    /*//////////////////////////////////////////////////////////////
                           INSPECT / SIZING API
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_PacksIdentityAndThreshold() public view {
        bytes memory out = hook.inspect(_data(WAD));
        assertEq(out.length, 164, "marketKey + 4 addresses + lltv + minHealthFactor");
        assertEq(BytesLib.toAddress(out, 0), morphoMarketKey(loanToken, collateralToken, oracle, irm, lltv));
        assertEq(BytesLib.toAddress(out, 20), loanToken);
        assertEq(BytesLib.toAddress(out, 40), collateralToken);
        assertEq(BytesLib.toAddress(out, 60), oracle);
        assertEq(BytesLib.toAddress(out, 80), irm);
        assertEq(BytesLib.toUint256(out, 100), lltv);
        assertEq(BytesLib.toUint256(out, 132), WAD);

        assertTrue(keccak256(out) != keccak256(hook.inspect(_data(3e18))), "threshold is identity");
    }

    /// @dev Regression for PR #1037 F1: the SuperVault leaf (`SuperVaultAggregator._createLeaf` replica) must change
    ///      when only the threshold changes, so a proof issued for `minHealthFactor = 2e18` cannot authorise a
    ///      downgraded `1e18` check.
    function test_Leaf_ThresholdDowngrade_FailsOldProof() public view {
        bytes32 root = _leaf(hook.inspect(_data(2e18))); // single-leaf tree: root == leaf, empty proof
        bytes32[] memory proof = new bytes32[](0);

        assertTrue(MerkleProof.verify(proof, root, _leaf(hook.inspect(_data(2e18)))), "intended threshold");
        assertFalse(MerkleProof.verify(proof, root, _leaf(hook.inspect(_data(WAD)))), "downgraded threshold");
        assertFalse(MerkleProof.verify(proof, root, _leaf(hook.inspect(_data(3e18)))), "upgraded threshold");
    }

    /// @dev == SuperVaultAggregator._createLeaf
    function _leaf(bytes memory hookArgs) internal view returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(address(hook), hookArgs))));
    }

    function test_Inspect_RevertIf_HeaderNotMarketKey() public {
        bytes memory data = _encodeWithKey(address(0xBEEF), loanToken, collateralToken, oracle, irm, lltv, WAD);
        vm.expectRevert(MorphoHealthCheckHook.MARKET_KEY_MISMATCH.selector);
        hook.inspect(data);
    }

    function test_SizingApi_Sizeless() public view {
        assertEq(hook.decodeAmounts("").length, 0);
        assertEq(hook.amountRoles("").length, 0);
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertFalse(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertFalse(hook.supportsInterface(0xdeadbeef));
    }

    function test_MarketKey_MatchesHelperAndRegistryDerivation() public view {
        address expected = address(uint160(uint256(Id.unwrap(marketParams.id()))));
        assertEq(morphoMarketKey(loanToken, collateralToken, oracle, irm, lltv), expected);
        // The hook accepts exactly that key (and nothing else, see test_Build_RevertIf_HeaderNotMarketKey)
        hook.inspect(_encodeWithKey(expected, loanToken, collateralToken, oracle, irm, lltv, WAD));
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Threshold_PassIffHealthFactorAtLeastMin(uint256 min) public {
        min = bound(min, WAD, 10e18);
        _setPosition(POSITION_BORROW_SHARES, 50e18);
        uint256 hf = _expectedHealthFactor(marketParams, POSITION_BORROW_SHARES, 50e18, ORACLE_PRICE_SCALE);

        if (hf >= min) {
            hook.build(address(0), address(this), _data(min));
        } else {
            vm.expectRevert(abi.encodeWithSelector(MorphoHealthCheckHook.HEALTH_FACTOR_BELOW_MINIMUM.selector, hf, min));
            hook.build(address(0), address(this), _data(min));
        }
    }
}
