// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { ApproveAndSwapBinanceHook } from "../../../../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol";
import { ConstantsOtherHooks } from "../../../../../script/utils/ConstantsOtherHooks.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";

/// @dev `ConstantsOtherHooks` and the test `Constants` both declare several hook-key names, so the
///      production values are read through this wrapper instead of by inheritance.
contract ProdBinanceConstants is ConstantsOtherHooks {
    function router() external pure returns (address) {
        return BINANCE_DEX_ROUTER_BNB;
    }

    function cap() external pure returns (uint256) {
        return BINANCE_MAX_INPUT_AMOUNT_BNB;
    }

    function key() external pure returns (string memory) {
        return APPROVE_AND_SWAP_BINANCE_HOOK_KEY;
    }
}

/// @title BinanceDeployConfig
/// @notice Pins the PRODUCTION deploy inputs for ApproveAndSwapBinanceHook (SUP-21203) so a silent change to
///         the router, the cap, the hook key or the locked bytecode fails CI instead of shipping.
contract BinanceDeployConfig is Helpers, InternalHelpers {
    address internal constant LIQUIDMESH_ROUTER = 0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5;
    uint256 internal constant TEN_MILLION_USDT = 10_000_000e18;
    string internal constant ARTIFACT = "ApproveAndSwapBinanceHook";

    ProdBinanceConstants internal prod;

    function setUp() public {
        prod = new ProdBinanceConstants();
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS PINNED
    //////////////////////////////////////////////////////////////*/

    function test_Config_RouterIsLiquidMeshDiamond() public view {
        assertEq(prod.router(), LIQUIDMESH_ROUTER);
        assertEq(prod.router(), CHAIN_56_BINANCE_LIQUIDMESH_ROUTER, "test constant drifted from deploy constant");
    }

    function test_Config_CapIsTenMillionUSDT() public view {
        assertEq(prod.cap(), TEN_MILLION_USDT);
    }

    function test_Config_HookKey() public view {
        assertEq(prod.key(), "ApproveAndSwapBinanceHook");
    }

    /*//////////////////////////////////////////////////////////////
                    HOOK BEHAVIOUR WITH PRODUCTION ARGS
    //////////////////////////////////////////////////////////////*/

    function _prodHook() internal returns (ApproveAndSwapBinanceHook) {
        return new ApproveAndSwapBinanceHook(prod.router(), prod.cap());
    }

    function _data(uint256 amountIn) internal pure returns (bytes memory) {
        return _createBinanceSwapHookData(
            CHAIN_56_USDT, CHAIN_56_AAPLB, amountIn, 0, 1, false, LIQUIDMESH_ROUTER, hex"ad43f73d00"
        );
    }

    function test_ProdHook_Immutables() public {
        ApproveAndSwapBinanceHook hook = _prodHook();
        assertEq(hook.BINANCE_ROUTER(), LIQUIDMESH_ROUTER);
        assertEq(hook.MAX_INPUT_AMOUNT(), TEN_MILLION_USDT);
    }

    function test_ProdHook_AcceptsExactlyTenMillion() public {
        Execution[] memory executions = _prodHook().build(address(0), address(this), _data(TEN_MILLION_USDT));
        assertEq(executions.length, 6);
    }

    function test_ProdHook_RejectsTenMillionPlusOne() public {
        ApproveAndSwapBinanceHook hook = _prodHook();
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(0), address(this), _data(TEN_MILLION_USDT + 1));
    }

    /// @dev The classic fat finger: one extra zero on a 1M order.
    function test_ProdHook_RejectsFatFinger() public {
        ApproveAndSwapBinanceHook hook = _prodHook();
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(0), address(this), _data(100_000_000e18));
    }

    function test_ProdHook_RejectsWrongRouterInPayload() public {
        ApproveAndSwapBinanceHook hook = _prodHook();
        bytes memory data = _createBinanceSwapHookData(
            CHAIN_56_USDT,
            CHAIN_56_AAPLB,
            1e18,
            0,
            1,
            false,
            0xb300000b72DEAEb607a12d5f54773D1C19c7028d,
            hex"ad43f73d00"
        );
        vm.expectRevert(ApproveAndSwapBinanceHook.ROUTER_MISMATCH.selector);
        hook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                            LOCKED BYTECODE
    //////////////////////////////////////////////////////////////*/

    function _artifact(string memory dir) internal view returns (bytes memory) {
        return vm.getCode(string(abi.encodePacked(dir, ARTIFACT, ".json")));
    }

    /// @dev All three artefact copies must agree, and must match the current source. `foundry.toml` sets
    ///      `bytecode_hash = "none"`, so comment-only edits do not move this; any CODE change does —
    ///      regenerate with `regenerate_bytecode.sh ApproveAndSwapBinanceHook` and copy to both locked dirs.
    function test_LockedBytecode_MatchesSourceAndCopies() public view {
        bytes memory locked = _artifact("script/locked-bytecode/");
        assertEq(keccak256(locked), keccak256(_artifact("script/generated-bytecode/")), "locked != generated");
        assertEq(keccak256(locked), keccak256(_artifact("script/locked-bytecode-dev/")), "locked != locked-dev");
        assertEq(keccak256(locked), keccak256(type(ApproveAndSwapBinanceHook).creationCode), "locked != source");
    }

    /// @dev Deploying the LOCKED artefact with the production constructor args yields the expected hook.
    function test_LockedBytecode_DeploysWithProdArgs() public {
        bytes memory initCode =
            abi.encodePacked(_artifact("script/locked-bytecode/"), abi.encode(prod.router(), prod.cap()));
        address deployed;
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), "deploy failed");

        ApproveAndSwapBinanceHook hook = ApproveAndSwapBinanceHook(deployed);
        assertEq(hook.BINANCE_ROUTER(), LIQUIDMESH_ROUTER);
        assertEq(hook.MAX_INPUT_AMOUNT(), TEN_MILLION_USDT);
        assertEq(hook.name(), "Approve and Swap Binance");
        assertEq(hook.amountRoles("").length, 0, "sizeless");
        assertEq(keccak256(deployed.code), keccak256(address(_prodHook()).code), "runtime differs from source");
    }
}
