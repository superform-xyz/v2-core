// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { StargateAdapter } from "../../../src/adapters/StargateAdapter.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import {
    SuperVaultStargateCapBridgeHook
} from "../../../src/hooks/bridges/stargate/SuperVaultStargateCapBridgeHook.sol";

import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { CrossChainSuperVaultDestinationE2EBase } from "./CrossChainSuperVaultDestinationE2EBase.sol";

/// @dev Minimal TokenMessaging stand-in: the adapter only reads `assetIds` (pool registration).
contract MockTokenMessaging {
    mapping(address => uint16) public assetIds;

    function setAssetId(address pool, uint16 id) external {
        assetIds[pool] = id;
    }
}

/// @dev Minimal Stargate pool stand-in: the adapter only reads `token()` from the verified pool;
///      the hub cap hook quotes `quoteOFT` at runtime (R4-P1) — this pool credits exactly.
contract MockStargatePool {
    address public token;
    address public feeLib = address(0xFEE1);

    constructor(address token_) {
        token = token_;
    }

    function getAddressConfig() external view returns (IStargate.AddressConfig memory c) {
        c.feeLib = feeLib;
    }

    function quoteOFT(IStargate.SendParam calldata p)
        external
        pure
        returns (
            IStargate.OFTLimit memory limit,
            IStargate.OFTFeeDetail[] memory details,
            IStargate.OFTReceipt memory receipt
        )
    {
        receipt = IStargate.OFTReceipt({ amountSentLD: p.amountLD, amountReceivedLD: p.amountLD });
        limit = IStargate.OFTLimit({ minAmountLD: 0, maxAmountLD: type(uint256).max });
        details = new IStargate.OFTFeeDetail[](0);
    }
}

/// @title CrossChainSuperVaultDestinationStargateE2E
/// @notice The "full remote lifecycle" e2e over the STARGATE (LayerZero compose) transport, with
///         the REAL destination stack: the LZ endpoint delivers the OFT compose message to
///         StargateAdapter (`lzCompose`), which forwards funds + payload to
///         SuperDestinationExecutor -> validated owner signature -> real approve+deposit ON the
///         hub-controlled account -> shares minted. The compose payload is byte-identical to the
///         typed destination action the SuperVaultStargateCapBridgeHook validated hub-side, keyed
///         under the CANONICAL chain id (B4: the EID never leaks into the cap namespace).
contract CrossChainSuperVaultDestinationStargateE2E is CrossChainSuperVaultDestinationE2EBase {
    StargateAdapter internal adapter;
    SuperVaultStargateCapBridgeHook internal capHook;
    MockTokenMessaging internal tokenMessaging;
    MockStargatePool internal pool;

    address internal lzEndpoint = makeAddr("lzEndpoint");
    uint32 internal constant DST_EID = 30_184; // LayerZero routing namespace

    /// @dev lzCompose gas option placeholder (content irrelevant to the decode paths under test).
    bytes internal constant EXTRA_OPTIONS = hex"000301001101000000000000000000000000000186a0";

    function setUp() public {
        _setUpDestinationStack();

        tokenMessaging = new MockTokenMessaging();
        adapter = new StargateAdapter(lzEndpoint, address(tokenMessaging), address(executor));
        pool = new MockStargatePool(address(token));
        tokenMessaging.setAssetId(address(pool), 1); // registered Stargate pool

        capHook = new SuperVaultStargateCapBridgeHook(address(hubValidator), address(governor));
        capHook.setExecutionContext(address(account));

        // B4: the routing EID maps to the canonical chain id the whole cap system keys on.
        capGuard.setEidChainId(DST_EID, chainId);
        capGuard.setApprovedAdapter(chainId, address(adapter), true);
        capGuard.setStargateRoute(address(pool), chainId, address(token)); // R3-RF1
        capGuard.setStargateFeeLib(address(pool), pool.feeLib()); // R4-P1: reviewed fee library
        // R4-F3: cap-enabled Stargate routes are periphery-locked to full delivery (10_000 bps):
        // the encoded minAmountLD must equal amountLD, so credited == action-accounted amount.
        capGuard.setStargateMinDeliveryBps(10_000);
    }

    /*//////////////////////////////////////////////////////////////
                        FULL REMOTE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    function test_E2E_Stargate_CapValidatedDepositMintsSharesToAccount() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));

        // 1. HUB SIDE: the cap hook validates the compose action under the CANONICAL chain id.
        vm.prank(address(account));
        capHook.preExecute(address(0), address(account), _hubData(_message5(executorCalldata)));
        assertEq(positionRegistry.lastVault(), address(vault), "cap must reserve against the economic vault");
        assertEq(positionRegistry.bridgedOutByChain(address(account), chainId), AMOUNT, "must key by canonical chain");
        assertEq(positionRegistry.bridgedOutByChain(address(account), uint64(DST_EID)), 0, "must NOT key by EID");

        // 2. OWNER SIGNATURE over the real destination leaf.
        (bytes32 root, bytes memory sigData) = _signDestination(executorCalldata);

        // 3. DESTINATION: the LZ endpoint composes to the adapter (funds credited during lzReceive).
        token.mint(address(adapter), AMOUNT);
        vm.prank(lzEndpoint);
        adapter.lzCompose(
            address(pool), keccak256("guid"), _oftCompose(_message6(executorCalldata, sigData)), address(0), bytes("")
        );

        // 4. The position exists as SHARES owned by the hub-controlled account.
        _assertSharesMinted(root, address(adapter));

        // R4-F3: the credited/delivered amount equals the destination action's accounted amount
        // EXACTLY — with stargateMinDeliveryBps periphery-locked to 10_000, minAmountLD ==
        // amountLD, so no delivery sliver can exist and every credited token is consumed by the
        // accounted action. Any surplus over the accounted amount would be unbooked exposure the
        // reservation/settlement accounting cannot represent.
        assertEq(
            token.balanceOf(address(vault)), AMOUNT, "credited amount must equal the action-accounted amount (R4-F3)"
        );
        assertEq(
            token.balanceOf(address(account)) + token.balanceOf(address(adapter)),
            0,
            "no credited surplus may remain outside the accounted action (R4-F3)"
        );
    }

    /// @notice Mutating only the vault after signing fails destination signature validation. The
    ///         Stargate adapter absorbs the executor revert (compose pipeline must not block), so
    ///         the observable outcome is: funds parked on the hub-controlled account, NO shares,
    ///         root NOT consumed (the action can be retried with a correct payload).
    function test_E2E_Stargate_MutatedVaultFailsDestinationSignature() public {
        (bytes32 root, bytes memory sigData) = _signDestination(_depositExecutorCalldata(address(vault)));

        Mock4626Vault rogueVault = new Mock4626Vault(address(token), "Rogue", "RGV");
        bytes memory mutatedCalldata = _depositExecutorCalldata(address(rogueVault));

        token.mint(address(adapter), AMOUNT);
        vm.prank(lzEndpoint);
        adapter.lzCompose(
            address(pool), keccak256("guid"), _oftCompose(_message6(mutatedCalldata, sigData)), address(0), bytes("")
        );

        assertEq(vault.balanceOf(address(account)), 0, "no shares may exist");
        assertEq(rogueVault.balanceOf(address(account)), 0, "mutated action must not execute");
        assertEq(token.balanceOf(address(account)), AMOUNT, "funds strand only on the hub-controlled account");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root must stay unconsumed for retry");
    }

    /// @notice Only the LZ endpoint may compose.
    function test_E2E_Stargate_RevertIf_CallerNotEndpoint() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));
        (, bytes memory sigData) = _signDestination(executorCalldata);

        vm.prank(makeAddr("rogueCaller"));
        vm.expectRevert(); // INVALID_SENDER
        adapter.lzCompose(
            address(pool), keccak256("guid"), _oftCompose(_message6(executorCalldata, sigData)), address(0), bytes("")
        );
    }

    /// @notice A compose from an unregistered pool is ignored (no execution, no shares).
    function test_E2E_Stargate_UnregisteredPoolIgnored() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));
        (bytes32 root, bytes memory sigData) = _signDestination(executorCalldata);

        MockStargatePool roguePool = new MockStargatePool(address(token)); // never registered
        token.mint(address(adapter), AMOUNT);
        vm.prank(lzEndpoint);
        adapter.lzCompose(
            address(roguePool),
            keccak256("guid"),
            _oftCompose(_message6(executorCalldata, sigData)),
            address(0),
            bytes("")
        );

        assertEq(vault.balanceOf(address(account)), 0, "no shares may exist");
        assertEq(token.balanceOf(address(adapter)), AMOUNT, "funds untouched");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root untouched");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev OFTComposeMsgCodec envelope: nonce(8) | srcEid(4) | amountLD(32) | composeFrom(32) | payload.
    function _oftCompose(bytes memory payload) internal view returns (bytes memory) {
        return abi.encodePacked(
            uint64(1), // nonce
            uint32(30_101), // srcEid (hub)
            uint256(AMOUNT), // amountLD credited during lzReceive
            bytes32(uint256(uint160(address(account)))), // composeFrom (source sender)
            payload
        );
    }

    /// @dev Stargate ApproveAnd hookData wrapping `composeMsg` (hub-side cap-hook input).
    function _hubData(bytes memory composeMsg) internal view returns (bytes memory) {
        bytes memory fixedPart = abi.encodePacked(
            bytes32(0),
            address(0), // 52-byte strategy header
            uint256(0), // lzNativeFee
            address(pool), // stargatePool
            address(token), // inputToken
            DST_EID, // dstEid (routing namespace)
            bytes32(uint256(uint160(address(adapter)))), // to = TRANSPORT adapter
            AMOUNT, // amountLD
            AMOUNT // minAmountLD
        );
        return abi.encodePacked(
            fixedPart,
            false, // usePrevHookAmount
            uint8(0), // mode 0 (taxi)
            uint256(EXTRA_OPTIONS.length),
            EXTRA_OPTIONS,
            composeMsg.length,
            composeMsg
        );
    }
}
