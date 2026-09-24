// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransferSpec } from "evm-gateway/lib/TransferSpec.sol";

import { CircleGatewayAdapter } from "../../../src/adapters/CircleGatewayAdapter.sol";
import { GatewayAttestationHelpers, IGatewayMinterLive, IFiatTokenBlacklist } from "./GatewayAttestationHelpers.sol";

/// @dev Executor stand-in on the destination fork — records the call the adapter makes.
contract MockDestinationExecutor {
    address public SUPER_DESTINATION_VALIDATOR = address(0xDA11D);
    uint256 public callCount;
    address public lastAccount;
    address public lastTokenSent;

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    )
        external
    {
        callCount++;
        lastAccount = account;
        lastTokenSent = tokenSent;
    }
}

/// @title CircleGatewayAdapterE2EFork
/// @notice Drives `CircleGatewayAdapter` against Circle's REAL `GatewayMinter` proxy on Base (and Ethereum,
///         domain 0): a test attestation signer is enrolled by the minter's owner and every attestation is built
///         and signed exactly as Circle's service does, so the minter's own structural, expiry, caller, domain,
///         token and replay checks all run for real and mint real USDC.
contract CircleGatewayAdapterE2EFork is GatewayAttestationHelpers {
    uint256 internal baseFork;
    uint256 internal ethFork;

    CircleGatewayAdapter internal adapter;
    MockDestinationExecutor internal executor;

    address internal depositor = makeAddr("depositor");
    address internal account = makeAddr("account");

    function setUp() public {
        ethFork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"));
        baseFork = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        executor = new MockDestinationExecutor();
        adapter = new CircleGatewayAdapter(GATEWAY_MINTER, USDC_BASE, address(executor));
        _enrollSigner();
    }

    function _hook(address account_, uint256 minimum) internal pure returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_BASE;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = minimum;
        return abi.encode(bytes(""), bytes("exec"), account_, dstTokens, amounts, bytes("sig"));
    }

    function _payload(uint256 value) internal returns (TransferSpec memory s, bytes memory payload) {
        s = _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, value, _hook(account, value));
        payload = _gwEncode(s);
    }

    /*//////////////////////////////////////////////////////////////
                              HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Base_MintForwardedAndExecutorCalled() public {
        (TransferSpec memory s, bytes memory payload) = _payload(1000e6);
        uint256 supplyBefore = IERC20(USDC_BASE).totalSupply();

        // permissionless: no prank; the adapter is the destinationCaller
        adapter.receiveAndExecute(payload, _gwSign(payload));

        assertEq(IERC20(USDC_BASE).balanceOf(account), 1000e6, "real USDC minted and forwarded");
        assertEq(IERC20(USDC_BASE).totalSupply() - supplyBefore, 1000e6, "minted, not moved");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "no residual");
        assertEq(executor.callCount(), 1);
        assertEq(executor.lastAccount(), account);
        assertEq(executor.lastTokenSent(), USDC_BASE);
        assertTrue(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(s)), "minter consumed");
        assertTrue(adapter.processed(_gwHash(s)), "adapter attributed");
    }

    /// @notice Ethereum's Gateway domain is 0: the constructor accepts it and the relay works end to end.
    function test_Fork_Ethereum_DomainZero_Works() public {
        vm.selectFork(ethFork);
        assertEq(IGatewayMinterLive(GATEWAY_MINTER).domain(), 0, "Ethereum is Gateway domain 0");
        MockDestinationExecutor ex = new MockDestinationExecutor();
        CircleGatewayAdapter a = new CircleGatewayAdapter(GATEWAY_MINTER, USDC_ETH, address(ex));
        _enrollSigner();

        TransferSpec memory s = _gwSpec(address(a), address(a), USDC_ETH, depositor, 250e6, _hook(account, 250e6));
        bytes memory payload = _gwEncode(s);
        a.receiveAndExecute(payload, _gwSign(payload));

        assertEq(IERC20(USDC_ETH).balanceOf(account), 250e6);
        assertEq(ex.callCount(), 1);
    }

    /// @notice A homogeneous AttestationSet is minted by the real minter in one call and delivered once.
    function test_Fork_HomogeneousSet_DeliveredOnce() public {
        bytes memory hook = _hook(account, 700e6);
        TransferSpec[] memory specs = new TransferSpec[](2);
        specs[0] = _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, 300e6, hook);
        specs[1] = _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, 400e6, hook);
        bytes memory payload = _gwEncodeSet(specs);

        adapter.receiveAndExecute(payload, _gwSign(payload));

        assertEq(IERC20(USDC_BASE).balanceOf(account), 700e6, "sum delivered");
        assertEq(executor.callCount(), 1, "executed once");
        assertTrue(adapter.processed(_gwHash(specs[0])) && adapter.processed(_gwHash(specs[1])));
    }

    /*//////////////////////////////////////////////////////////////
                    THE MINTER'S OWN CHECKS, FOR REAL
    //////////////////////////////////////////////////////////////*/

    function test_Fork_Replay_RejectedByMinter() public {
        (TransferSpec memory s, bytes memory payload) = _payload(100e6);
        bytes memory sig = _gwSign(payload);
        adapter.receiveAndExecute(payload, sig);
        vm.expectRevert(abi.encodeWithSignature("TransferSpecHashUsed(bytes32)", _gwHash(s)));
        adapter.receiveAndExecute(payload, sig);
    }

    function test_Fork_BadSigner_RejectedByMinter_NothingConsumed() public {
        (TransferSpec memory s, bytes memory payload) = _payload(100e6);
        vm.expectRevert(abi.encodeWithSignature("InvalidAttestationSigner()"));
        adapter.receiveAndExecute(payload, _gwSignWith(payload, 0xBAD));
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(s)));
        assertFalse(adapter.processed(_gwHash(s)));
    }

    /// @notice An expired attestation is rejected by the minter; the adapter consumed nothing, so a fresh
    ///         attestation for the same intent (new salt) relays normally — the user only lost a retry.
    function test_Fork_Expired_RejectedThenFreshAttestationWorks() public {
        TransferSpec memory s =
            _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, 100e6, _hook(account, 100e6));
        bytes memory stale = _gwEncode(s, block.number - 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AttestationExpiredAtIndex(uint32,uint256,uint256)", 0, block.number - 1, block.number
            )
        );
        adapter.receiveAndExecute(stale, _gwSign(stale));
        assertFalse(adapter.processed(_gwHash(s)));

        (, bytes memory fresh) = _payload(100e6);
        adapter.receiveAndExecute(fresh, _gwSign(fresh));
        assertEq(IERC20(USDC_BASE).balanceOf(account), 100e6);
    }

    /// @notice A pinned spec cannot be minted by anyone but the adapter (real destinationCaller check), so a
    ///         front-runner gains nothing and the honest relay still lands afterwards.
    function test_Fork_PinnedSpec_ThirdPartyCannotMintDirectly() public {
        (, bytes memory payload) = _payload(100e6);
        bytes memory sig = _gwSign(payload);
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAttestationDestinationCallerAtIndex(uint32,address,address)", 0, address(adapter), attacker
            )
        );
        IGatewayMinterLive(GATEWAY_MINTER).gatewayMint(payload, sig);

        adapter.receiveAndExecute(payload, sig);
        assertEq(IERC20(USDC_BASE).balanceOf(account), 100e6);
    }

    /// @notice A non-USDC token in the spec is rejected by the ADAPTER before the minter is touched — even a
    ///         token the minter does not support never gets as far as `UnsupportedTokenAtIndex`.
    function test_Fork_NonUsdc_RejectedPreMint() public {
        TransferSpec memory s =
            _gwSpec(address(adapter), address(adapter), makeAddr("notUsdc"), depositor, 1e6, _hook(account, 1));
        bytes memory payload = _gwEncode(s);
        vm.expectRevert(CircleGatewayAdapter.UNSUPPORTED_DESTINATION_TOKEN.selector);
        adapter.receiveAndExecute(payload, _gwSign(payload));
    }

    /// @notice The minter's denylist gates the CALLER: a denylisted adapter cannot mint (the whole relay
    ///         reverts, nothing consumed) and works again once undenylisted.
    function test_Fork_DenylistedAdapter_RevertsAtMinter_ThenRecovers() public {
        (TransferSpec memory s, bytes memory payload) = _payload(100e6);
        bytes memory sig = _gwSign(payload);
        IGatewayMinterLive m = IGatewayMinterLive(GATEWAY_MINTER);

        vm.prank(m.denylister());
        m.denylist(address(adapter));
        vm.expectRevert(abi.encodeWithSignature("AccountDenylisted(address)", address(adapter)));
        adapter.receiveAndExecute(payload, sig);
        assertFalse(adapter.processed(_gwHash(s)));

        vm.prank(m.denylister());
        m.unDenylist(address(adapter));
        adapter.receiveAndExecute(payload, sig);
        assertEq(IERC20(USDC_BASE).balanceOf(account), 100e6);
    }

    /// @notice The adapter's duplicate rejection can never block a mintable payload: the REAL minter marks hashes
    ///         as it iterates and reverts on the second identical member itself.
    function test_Fork_DuplicateSet_RejectedByAdapterAndMinter() public {
        TransferSpec memory s =
            _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, 10e6, _hook(account, 10e6));
        TransferSpec[] memory dup = new TransferSpec[](2);
        dup[0] = s;
        dup[1] = s;
        bytes memory payload = _gwEncodeSet(dup);
        bytes memory sig = _gwSign(payload);

        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_DUPLICATE.selector);
        adapter.receiveAndExecute(payload, sig);
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(s)));

        vm.prank(address(adapter));
        vm.expectRevert(abi.encodeWithSignature("TransferSpecHashUsed(bytes32)", _gwHash(s)));
        IGatewayMinterLive(GATEWAY_MINTER).gatewayMint(payload, sig);
    }

    /// @notice Witness semantics the signature-free recovery relies on, probed on the LIVE minter: USDC is minted
    ///         by FiatToken itself (no mint authority that could return false without minting), a successful mint
    ///         flips the hash AND moves exactly `value`, and a failed mint leaves the hash unused.
    function test_Fork_WitnessSemantics_UsedHashImpliesMinted() public {
        IGatewayMinterLive m = IGatewayMinterLive(GATEWAY_MINTER);
        assertEq(m.tokenMintAuthority(USDC_BASE), address(0), "USDC minted by FiatToken directly");

        (TransferSpec memory s, bytes memory payload) = _payload(42e6);
        bytes memory sig = _gwSign(payload);
        uint256 before = IERC20(USDC_BASE).balanceOf(address(adapter));
        vm.prank(address(adapter));
        m.gatewayMint(payload, sig);
        assertTrue(m.isTransferSpecHashUsed(_gwHash(s)), "hash used");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)) - before, 42e6, "exactly value arrived");

        (TransferSpec memory bad, bytes memory badPayload) = _payload(1e6);
        vm.prank(address(adapter));
        vm.expectRevert(abi.encodeWithSignature("InvalidAttestationSigner()"));
        m.gatewayMint(badPayload, _gwSignWith(badPayload, 0xBAD));
        assertFalse(m.isTransferSpecHashUsed(_gwHash(bad)), "failed mint leaves the hash unused");
    }

    /// @notice F2 on the real minter: a spec PINNED to the adapter but minting elsewhere is passed through — Circle
    ///         mints to the spec's own recipient, the adapter's balances are untouched, kind 2 is flagged.
    function test_Fork_PinnedButMintsElsewhere_PassedThrough() public {
        address elsewhere = makeAddr("elsewhere");
        TransferSpec memory s = _gwSpec(elsewhere, address(adapter), USDC_BASE, depositor, 50e6, "");
        bytes memory payload = _gwEncode(s);
        vm.recordLogs();
        adapter.receiveAndExecute(payload, _gwSign(payload));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool kind2;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(adapter)
                    && logs[i].topics[0] == keccak256("MisconfiguredMessageRelayed(uint8,address)")
                    && uint256(logs[i].topics[1]) == 2
            ) kind2 = true;
        }
        assertTrue(kind2, "MISCONFIG_MINT_ELSEWHERE flagged");
        assertEq(IERC20(USDC_BASE).balanceOf(elsewhere), 50e6, "Circle minted to the spec's recipient");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 0);
        assertFalse(adapter.processed(_gwHash(s)), "not attributed by the adapter");
        assertTrue(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(s)), "consumed on the minter");
    }

    /// @notice A mixed set is rejected by the adapter BEFORE the real minter sees it: every member stays unused.
    function test_Fork_MixedSet_RejectedPreMint() public {
        TransferSpec[] memory specs = new TransferSpec[](2);
        specs[0] = _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, 1e6, _hook(account, 1));
        specs[1] = _gwSpec(address(adapter), address(adapter), USDC_BASE, depositor, 1e6, _hook(account, 2));
        bytes memory payload = _gwEncodeSet(specs);
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_MIXED.selector);
        adapter.receiveAndExecute(payload, _gwSign(payload));
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(specs[0])));
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(specs[1])));
    }

    /// @notice FiatToken blacklist of the ADAPTER itself (distinct from the Gateway denylist): USDC's `mint` reverts
    ///         inside `gatewayMint` AFTER the hash mark, so the whole relay unwinds with the spec unused; after
    ///         unblacklisting the same attestation relays.
    function test_Fork_AdapterBlacklistedOnUsdc_RevertsAtMint_ThenRecovers() public {
        (TransferSpec memory s, bytes memory payload) = _payload(100e6);
        bytes memory sig = _gwSign(payload);
        IFiatTokenBlacklist usdc = IFiatTokenBlacklist(USDC_BASE);
        vm.prank(usdc.blacklister());
        usdc.blacklist(address(adapter));

        vm.expectRevert(bytes("Blacklistable: account is blacklisted"));
        adapter.receiveAndExecute(payload, sig);
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(s)), "mark unwound");

        vm.prank(usdc.blacklister());
        usdc.unBlacklist(address(adapter));
        adapter.receiveAndExecute(payload, sig);
        assertEq(IERC20(USDC_BASE).balanceOf(account), 100e6);
    }

    /*//////////////////////////////////////////////////////////////
                         STRAY MINT → RECOVERY
    //////////////////////////////////////////////////////////////*/

    /// @notice F1 on the real minter: a zero-caller spec minting into the adapter is minted directly by a third
    ///         party (funds land in the adapter, nothing delivered). The relay is then rejected by the minter,
    ///         and `recoverDirectMint` — keyed on the minter's own used-hash record, no signature needed —
    ///         forwards and executes it, even from a payload reconstructed by anyone.
    function test_Fork_ZeroCallerStrayMint_Recovered() public {
        TransferSpec memory s =
            _gwSpec(address(adapter), address(0), USDC_BASE, depositor, 100e6, _hook(account, 100e6));
        bytes memory payload = _gwEncode(s);
        bytes memory sig = _gwSign(payload);

        vm.prank(makeAddr("thirdParty"));
        IGatewayMinterLive(GATEWAY_MINTER).gatewayMint(payload, sig);
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 100e6, "stranded in the adapter");

        vm.expectRevert(abi.encodeWithSignature("TransferSpecHashUsed(bytes32)", _gwHash(s)));
        adapter.receiveAndExecute(payload, sig);

        // a forged spec (same salt, different account) has a different hash: not minted, nothing to recover.
        // NB: built fresh — `TransferSpec memory forged = s` would alias the same struct.
        TransferSpec memory forged =
            _gwSpec(address(adapter), address(0), USDC_BASE, depositor, 100e6, _hook(makeAddr("thief"), 100e6));
        forged.salt = s.salt;
        vm.expectRevert(CircleGatewayAdapter.SPEC_NOT_MINTED.selector);
        adapter.recoverDirectMint(_gwEncode(forged));

        // reconstructed wrapper (different maxBlockHeight), random caller
        vm.prank(makeAddr("goodSamaritan"));
        adapter.recoverDirectMint(_gwEncode(s, block.number + 999));
        assertEq(IERC20(USDC_BASE).balanceOf(account), 100e6, "recovered to the account");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 1, "intent executed");
        assertTrue(adapter.processed(_gwHash(s)));

        vm.expectRevert(CircleGatewayAdapter.SPEC_ALREADY_PROCESSED.selector);
        adapter.recoverDirectMint(payload);
    }

    /// @notice The zero-caller spec relayed by the honest relayer FIRST is simply delivered (MISCONFIG_UNPINNED).
    function test_Fork_ZeroCaller_HonestRelayFirst_Delivered() public {
        TransferSpec memory s =
            _gwSpec(address(adapter), address(0), USDC_BASE, depositor, 100e6, _hook(account, 100e6));
        bytes memory payload = _gwEncode(s);
        vm.recordLogs();
        adapter.receiveAndExecute(payload, _gwSign(payload));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool flagged;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(adapter)
                    && logs[i].topics[0] == keccak256("MisconfiguredMessageRelayed(uint8,address)")
                    && uint256(logs[i].topics[1]) == 1
            ) flagged = true;
        }
        assertTrue(flagged, "MISCONFIG_UNPINNED flagged");
        assertEq(IERC20(USDC_BASE).balanceOf(account), 100e6);
    }
}
