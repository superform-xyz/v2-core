// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { AttestationLib } from "evm-gateway/lib/AttestationLib.sol";
import { Attestation, AttestationSet } from "evm-gateway/lib/Attestations.sol";
import { TransferSpec } from "evm-gateway/lib/TransferSpec.sol";
import { TransferSpecLib } from "evm-gateway/lib/TransferSpecLib.sol";
import { AddressLib } from "evm-gateway/lib/AddressLib.sol";
import { Cursor } from "evm-gateway/lib/Cursor.sol";

import { CircleGatewayAdapter } from "../../../src/adapters/CircleGatewayAdapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @dev Executor stand-in that records calls and can be toggled to revert / returnbomb / reenter.
contract MockDestinationExecutor {
    address public SUPER_DESTINATION_VALIDATOR = address(0xDA11D);

    bool public shouldRevert;
    bool public shouldReturnbomb;
    bool public shouldReenter;
    bool public reenterViaRecover;
    address public reentrancyTarget;
    uint256 public callCount;

    address public lastTokenSent;
    address public lastAccount;
    bytes public lastInitData;
    bytes public lastExecutorCalldata;
    bytes public lastSigData;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function setShouldReturnbomb(bool v) external {
        shouldReturnbomb = v;
    }

    function setShouldReenter(bool v, address target) external {
        shouldReenter = v;
        reentrancyTarget = target;
    }

    function setReenterViaRecover(bool v) external {
        reenterViaRecover = v;
    }

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external
    {
        if (shouldReenter) {
            if (reenterViaRecover) CircleGatewayAdapter(reentrancyTarget).recoverDirectMint("");
            else CircleGatewayAdapter(reentrancyTarget).receiveAndExecute("", "");
        }
        if (shouldRevert) {
            if (shouldReturnbomb) {
                // 800 KB revert data starting with the Error(string) selector, produced with ONE memory expansion
                // (~1.3M gas) — `revert(string(new bytes(n)))` would ABI-encode and pay it twice. Copying it back in
                // the adapter frame would cost the same ~1.3M again (see test_ExecutorReturnbomb_DoesNotOOG).
                assembly ("memory-safe") {
                    let ptr := mload(0x40)
                    mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    revert(ptr, 800004)
                }
            }
            revert("EXECUTOR_REVERT");
        }
        callCount++;
        lastTokenSent = tokenSent;
        lastAccount = account;
        lastInitData = initData;
        lastExecutorCalldata = executorCalldata;
        lastSigData = userSignatureData;
    }
}

/// @dev GatewayMinter stand-in that behaves like `Mints.gatewayMint` on the parts the adapter depends on: it
///      parses the SAME payload with Circle's libraries, enforces `destinationCaller`, marks every TransferSpec
///      hash used (replay-rejecting) and mints exactly `value` of the spec's `destinationToken` to
///      `destinationRecipient`. Signature checking is skipped (the real minter's job; covered on the fork).
///      `mintMode` lets tests simulate a mint authority that under/over-mints.
contract MockGatewayMinter {
    using TransferSpecLib for bytes29;
    using AttestationLib for bytes29;
    using AttestationLib for Cursor;

    error TransferSpecHashUsed(bytes32 transferSpecHash);
    error InvalidDestinationCaller();
    error EnforcedPause();

    uint8 public constant MINT_EXACT = 0;
    uint8 public constant MINT_NONE = 1;
    uint8 public constant MINT_OVERRIDE = 2;

    uint32 public domain = 6;
    bool public paused;
    uint8 public mintMode;
    uint256 public mintOverride;
    uint256 public calls;
    bytes public lastPayload;
    bytes public lastSignature;

    mapping(address => bool) public isTokenSupported;
    mapping(bytes32 => bool) public isTransferSpecHashUsed;

    constructor(address usdc) {
        isTokenSupported[usdc] = true;
    }

    function setDomain(uint32 d) external {
        domain = d;
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function setTokenSupported(address t, bool v) external {
        isTokenSupported[t] = v;
    }

    function setMintMode(uint8 mode, uint256 amount) external {
        mintMode = mode;
        mintOverride = amount;
    }

    function gatewayMint(bytes memory payload, bytes memory signature) external {
        if (paused) revert EnforcedPause();
        calls++;
        lastPayload = payload;
        lastSignature = signature;
        Cursor memory c = AttestationLib.cursor(payload);
        while (!c.done) {
            bytes29 spec = c.next().getTransferSpec();
            address caller = AddressLib._bytes32ToAddress(spec.getDestinationCaller());
            if (caller != address(0) && caller != msg.sender) revert InvalidDestinationCaller();
            bytes32 h = spec.getHash();
            if (isTransferSpecHashUsed[h]) revert TransferSpecHashUsed(h);
            isTransferSpecHashUsed[h] = true;
            _mint(spec);
        }
    }

    function _mint(bytes29 spec) internal {
        uint256 amount = spec.getValue();
        if (mintMode == MINT_NONE) return;
        if (mintMode == MINT_OVERRIDE) amount = mintOverride;
        IMintable(AddressLib._bytes32ToAddress(spec.getDestinationToken()))
            .mint(AddressLib._bytes32ToAddress(spec.getDestinationRecipient()), amount);
    }
}

/// @dev A token whose `transfer` returns a 32-byte word that is NOT a valid bool (`2`).
contract NonBoolWordUSDC {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function transfer(address, uint256) external pure returns (uint256) {
        return 2;
    }
}

/// @dev USDC-like token with a blacklist that makes transfers to blacklisted accounts return false.
contract BlacklistUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public blacklisted;

    function setBlacklisted(address a, bool v) external {
        blacklisted[a] = v;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (blacklisted[to]) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract CircleGatewayAdapterUnitTests is Test {
    using AttestationLib for bytes29;
    using AttestationLib for Cursor;
    using TransferSpecLib for bytes29;

    uint32 internal constant SRC_DOMAIN = 0;
    address internal constant GATEWAY_WALLET = 0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE;
    address internal constant REMOTE_USDC = address(0xA0B8);

    CircleGatewayAdapter internal adapter;
    MockGatewayMinter internal minter;
    MockDestinationExecutor internal executor;
    MockERC20 internal usdc;
    MockERC20 internal other;

    address internal account = makeAddr("account");
    address internal depositor = makeAddr("depositor");
    uint256 internal saltNonce;

    event TransferFailed(address indexed account, address indexed token, uint256 amount);
    event TransferSucceeded(address indexed account, address indexed token, uint256 amount);
    event MisconfiguredMessageRelayed(uint8 indexed kind, address destinationRecipient);
    event SpecProcessed(bytes32 indexed specHash, address indexed account, uint256 value, bool recovered);
    event ExecutionFailed(address indexed account, bytes4 selector);
    event DestinationTargetMismatch(address indexed account, uint8 code);
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        other = new MockERC20("Other", "OTH", 6);
        minter = new MockGatewayMinter(address(usdc));
        minter.setTokenSupported(address(other), true);
        executor = new MockDestinationExecutor();
        adapter = new CircleGatewayAdapter(address(minter), address(usdc), address(executor));
    }

    /*//////////////////////////////////////////////////////////////
                               BUILDERS
    //////////////////////////////////////////////////////////////*/

    function _hook(address account_, uint256 intentAmount) internal pure returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = intentAmount;
        return abi.encode(bytes("init"), bytes("exec"), account_, dstTokens, intentAmounts, bytes("sig"));
    }

    function _spec(
        address recipient,
        address caller,
        address token,
        uint256 value,
        bytes memory hookData
    )
        internal
        returns (TransferSpec memory)
    {
        return TransferSpec({
            version: 1,
            sourceDomain: SRC_DOMAIN,
            destinationDomain: minter.domain(),
            sourceContract: AddressLib._addressToBytes32(GATEWAY_WALLET),
            destinationContract: AddressLib._addressToBytes32(address(minter)),
            sourceToken: AddressLib._addressToBytes32(REMOTE_USDC),
            destinationToken: AddressLib._addressToBytes32(token),
            sourceDepositor: AddressLib._addressToBytes32(depositor),
            destinationRecipient: AddressLib._addressToBytes32(recipient),
            sourceSigner: AddressLib._addressToBytes32(depositor),
            destinationCaller: AddressLib._addressToBytes32(caller),
            value: value,
            salt: keccak256(abi.encode(++saltNonce)),
            hookData: hookData
        });
    }

    function _encode(TransferSpec memory s) internal view returns (bytes memory) {
        return AttestationLib.encodeAttestation(Attestation({ maxBlockHeight: block.number + 100, spec: s }));
    }

    function _encodeSet(TransferSpec[] memory specs) internal view returns (bytes memory) {
        Attestation[] memory atts = new Attestation[](specs.length);
        for (uint256 i; i < specs.length; ++i) {
            atts[i] = Attestation({ maxBlockHeight: block.number + 100, spec: specs[i] });
        }
        return AttestationLib.encodeAttestationSet(AttestationSet({ attestations: atts }));
    }

    /// @dev Canonical happy-path payload: pinned to the adapter, mints USDC into it, routes to `account`.
    function _payload(uint256 value) internal returns (bytes memory) {
        return _encode(_spec(address(adapter), address(adapter), address(usdc), value, _hook(account, value)));
    }

    function _hash(TransferSpec memory s) internal pure returns (bytes32) {
        return keccak256(TransferSpecLib.encodeTransferSpec(s));
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZero() public {
        vm.expectRevert(CircleGatewayAdapter.ADDRESS_NOT_VALID.selector);
        new CircleGatewayAdapter(address(0), address(usdc), address(executor));
        vm.expectRevert(CircleGatewayAdapter.ADDRESS_NOT_VALID.selector);
        new CircleGatewayAdapter(address(minter), address(0), address(executor));
        vm.expectRevert(CircleGatewayAdapter.ADDRESS_NOT_VALID.selector);
        new CircleGatewayAdapter(address(minter), address(usdc), address(0));
    }

    /// @notice A populated-but-wrong minter (no code, or one that does not mint this USDC) cannot deploy.
    function test_Constructor_RevertsOnMinterWithoutCodeOrUsdc() public {
        vm.expectRevert(CircleGatewayAdapter.GATEWAY_MINTER_NOT_VALID.selector);
        new CircleGatewayAdapter(makeAddr("eoa"), address(usdc), address(executor));
        minter.setTokenSupported(address(usdc), false);
        vm.expectRevert(CircleGatewayAdapter.GATEWAY_MINTER_NOT_VALID.selector);
        new CircleGatewayAdapter(address(minter), address(usdc), address(executor));
    }

    /// @notice Ethereum's Gateway domain is 0 — the constructor must not treat it as "unset".
    function test_Constructor_AcceptsDomainZero() public {
        minter.setDomain(0);
        CircleGatewayAdapter a = new CircleGatewayAdapter(address(minter), address(usdc), address(executor));
        assertEq(address(a.GATEWAY_MINTER()), address(minter));
        assertEq(a.SUPER_DESTINATION_VALIDATOR(), executor.SUPER_DESTINATION_VALIDATOR());
        // and a relay at domain 0 parses + delivers (the `_parse` domain check must not treat 0 as unset)
        TransferSpec memory s = _spec(address(a), address(a), address(usdc), 1e6, _hook(account, 1e6));
        assertEq(s.destinationDomain, 0);
        a.receiveAndExecute(_encode(s), "");
        assertEq(usdc.balanceOf(account), 1e6, "delivered at domain 0");
    }

    /*//////////////////////////////////////////////////////////////
                              HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveAndExecute_MintsForwardsAndExecutes() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 500e6, _hook(account, 500e6));
        bytes memory payload = _encode(s);

        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(s), account, 500e6, false);
        vm.expectEmit(true, true, false, true);
        emit TransferSucceeded(account, address(usdc), 500e6);
        adapter.receiveAndExecute(payload, "sig");

        assertEq(minter.calls(), 1, "minter called once");
        assertEq(keccak256(minter.lastPayload()), keccak256(payload), "payload passed byte-identical");
        assertEq(keccak256(minter.lastSignature()), keccak256("sig"), "signature passed through");
        assertEq(usdc.balanceOf(account), 500e6, "delivered");
        assertEq(usdc.balanceOf(address(adapter)), 0, "no residual");
        assertEq(executor.callCount(), 1);
        assertEq(executor.lastTokenSent(), address(usdc));
        assertEq(executor.lastAccount(), account);
        assertEq(keccak256(executor.lastInitData()), keccak256("init"));
        assertEq(keccak256(executor.lastExecutorCalldata()), keccak256("exec"));
        assertEq(keccak256(executor.lastSigData()), keccak256("sig"));
        assertTrue(adapter.processed(_hash(s)), "spec attributed");
        assertTrue(minter.isTransferSpecHashUsed(_hash(s)), "minter consumed the spec");
    }

    /// @notice INV-1: only the mint delta is forwarded, never a pre-existing balance.
    function test_DonationProof_OnlyMintDeltaForwarded() public {
        usdc.mint(address(adapter), 1000e6);
        adapter.receiveAndExecute(_payload(500e6), "");
        assertEq(usdc.balanceOf(account), 500e6);
        assertEq(usdc.balanceOf(address(adapter)), 1000e6, "donation untouched");
    }

    /// @notice Replay: the minter rejects a used spec and the adapter bubbles it (no state of its own consumed).
    function test_Replay_RevertsAtMinter() public {
        bytes memory payload = _payload(500e6);
        adapter.receiveAndExecute(payload, "");
        vm.expectRevert(abi.encodeWithSelector(MockGatewayMinter.TransferSpecHashUsed.selector, _hashOf(payload)));
        adapter.receiveAndExecute(payload, "");
    }

    function _hashOf(bytes memory payload) internal pure returns (bytes32) {
        Cursor memory c = AttestationLib.cursor(payload);
        return c.next().getTransferSpec().getHash();
    }

    /// @notice A paused minter reverts the whole relay: nothing consumed, nothing escrowed.
    function test_PausedMinter_RevertsBeforeAnyEffect() public {
        minter.setPaused(true);
        bytes memory payload = _payload(500e6);
        vm.expectRevert(MockGatewayMinter.EnforcedPause.selector);
        adapter.receiveAndExecute(payload, "");
        assertFalse(adapter.processed(_hashOf(payload)));
    }

    /*//////////////////////////////////////////////////////////////
                          ATTESTATION SETS
    //////////////////////////////////////////////////////////////*/

    /// @notice A homogeneous set is minted once, delivered once (sum of values) and executed once.
    function test_Set_Homogeneous_DeliveredOnceExecutedOnce() public {
        bytes memory hook = _hook(account, 700e6);
        TransferSpec[] memory specs = new TransferSpec[](2);
        specs[0] = _spec(address(adapter), address(adapter), address(usdc), 300e6, hook);
        specs[1] = _spec(address(adapter), address(adapter), address(usdc), 400e6, hook);

        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(specs[0]), account, 300e6, false);
        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(specs[1]), account, 400e6, false);
        adapter.receiveAndExecute(_encodeSet(specs), "");

        assertEq(minter.calls(), 1);
        assertEq(usdc.balanceOf(account), 700e6, "sum delivered");
        assertEq(executor.callCount(), 1, "executed once");
        assertTrue(adapter.processed(_hash(specs[0])));
        assertTrue(adapter.processed(_hash(specs[1])));
    }

    function test_Set_MixedHookData_Rejected() public {
        TransferSpec[] memory specs = new TransferSpec[](2);
        specs[0] = _spec(address(adapter), address(adapter), address(usdc), 1e6, _hook(account, 1));
        specs[1] = _spec(address(adapter), address(adapter), address(usdc), 1e6, _hook(account, 2));
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_MIXED.selector);
        adapter.receiveAndExecute(_encodeSet(specs), "");
        assertEq(minter.calls(), 0, "rejected pre-mint");
    }

    function test_Set_MixedRecipientCallerOrToken_Rejected() public {
        bytes memory hook = _hook(account, 1);
        TransferSpec[] memory specs = new TransferSpec[](2);
        specs[0] = _spec(address(adapter), address(adapter), address(usdc), 1e6, hook);

        specs[1] = _spec(address(0xBEEF), address(adapter), address(usdc), 1e6, hook);
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_MIXED.selector);
        adapter.receiveAndExecute(_encodeSet(specs), "");

        specs[1] = _spec(address(adapter), address(0), address(usdc), 1e6, hook);
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_MIXED.selector);
        adapter.receiveAndExecute(_encodeSet(specs), "");

        specs[1] = _spec(address(adapter), address(adapter), address(other), 1e6, hook);
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_MIXED.selector);
        adapter.receiveAndExecute(_encodeSet(specs), "");
    }

    /// @notice A single-element set is just an attestation with a set wrapper — accepted.
    function test_Set_SingleElement_Accepted() public {
        TransferSpec[] memory specs = new TransferSpec[](1);
        specs[0] = _spec(address(adapter), address(adapter), address(usdc), 5e6, _hook(account, 5e6));
        adapter.receiveAndExecute(_encodeSet(specs), "");
        assertEq(usdc.balanceOf(account), 5e6);
    }

    /*//////////////////////////////////////////////////////////////
                        PRE-MINT FAIL-FAST CHECKS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_MalformedPayload_LibraryErrors() public {
        vm.expectRevert(abi.encodeWithSelector(TransferSpecLib.TransferPayloadDataTooShort.selector, 4, 1));
        adapter.receiveAndExecute(hex"00", "");

        bytes memory payload = _payload(1e6);
        payload[0] = 0x00;
        vm.expectPartialRevert(TransferSpecLib.InvalidTransferPayloadMagic.selector);
        adapter.receiveAndExecute(payload, "");
        assertEq(minter.calls(), 0);
    }

    function test_Revert_DestinationContractMismatch() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 1e6, _hook(account, 1));
        s.destinationContract = AddressLib._addressToBytes32(address(0xBAD));
        vm.expectRevert(CircleGatewayAdapter.DESTINATION_CONTRACT_MISMATCH.selector);
        adapter.receiveAndExecute(_encode(s), "");
    }

    function test_Revert_DestinationDomainMismatch() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 1e6, _hook(account, 1));
        s.destinationDomain = 99;
        vm.expectRevert(CircleGatewayAdapter.DESTINATION_DOMAIN_MISMATCH.selector);
        adapter.receiveAndExecute(_encode(s), "");
    }

    function test_Revert_ZeroValue() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 0, _hook(account, 1));
        vm.expectRevert(CircleGatewayAdapter.ZERO_VALUE.selector);
        adapter.receiveAndExecute(_encode(s), "");
    }

    /// @notice F1: `destinationCaller = 0` is accepted (rejecting it only forfeits the honest relayer's chance)
    ///         and flagged as MISCONFIG_UNPINNED.
    function test_F1_DestinationCallerZero_AcceptedAndDelivered() public {
        TransferSpec memory s = _spec(address(adapter), address(0), address(usdc), 5e6, _hook(account, 5e6));
        vm.expectEmit(true, false, false, true);
        emit MisconfiguredMessageRelayed(1, address(adapter));
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 1);
    }

    function test_F1_DestinationCallerThirdParty_Rejected() public {
        TransferSpec memory s = _spec(address(adapter), address(0xBEEF), address(usdc), 5e6, _hook(account, 5e6));
        vm.expectRevert(CircleGatewayAdapter.DESTINATION_CALLER_MISMATCH.selector);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(minter.calls(), 0);
    }

    /// @notice F2: pinned to us but minting elsewhere — nobody else can ever mint it, so pass it through.
    function test_F2_PinnedButMintsElsewhere_PassedThrough() public {
        address elsewhere = makeAddr("elsewhere");
        TransferSpec memory s = _spec(elsewhere, address(adapter), address(usdc), 5e6, "");
        vm.expectEmit(true, false, false, true);
        emit MisconfiguredMessageRelayed(2, elsewhere);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(minter.calls(), 1, "minter called");
        assertEq(usdc.balanceOf(elsewhere), 5e6, "Circle minted to the spec's own recipient");
        assertEq(usdc.balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 0, "nothing executed");
        assertFalse(adapter.processed(_hash(s)), "not attributed by this adapter");
    }

    function test_F2_MintsElsewhere_NotPinned_Rejected() public {
        TransferSpec memory s = _spec(makeAddr("elsewhere"), address(0), address(usdc), 5e6, "");
        vm.expectRevert(CircleGatewayAdapter.DESTINATION_RECIPIENT_MISMATCH.selector);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(minter.calls(), 0);
    }

    /// @notice Non-USDC specs are rejected BEFORE the mint (the attestation expires; the depositor's balance is
    ///         restored) — the adapter never holds a non-USDC balance.
    function test_Revert_NonUsdcToken_PreMint() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(other), 5e6, _hook(account, 5e6));
        vm.expectRevert(CircleGatewayAdapter.UNSUPPORTED_DESTINATION_TOKEN.selector);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(minter.calls(), 0);
        assertEq(other.balanceOf(address(adapter)), 0);
    }

    function test_Revert_MalformedHookData_PreMint() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 5e6, hex"deadbeef");
        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(minter.calls(), 0);
    }

    function test_Revert_EmptyHookData_PreMint() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 5e6, "");
        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        adapter.receiveAndExecute(_encode(s), "");
    }

    function test_Revert_AccountZeroOrSelf_PreMint() public {
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 5e6, _hook(address(0), 5e6));
        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        adapter.receiveAndExecute(_encode(s), "");

        s = _spec(address(adapter), address(adapter), address(usdc), 5e6, _hook(address(adapter), 5e6));
        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(minter.calls(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           MINT MEASUREMENT
    //////////////////////////////////////////////////////////////*/

    function test_Revert_NothingMinted() public {
        minter.setMintMode(minter.MINT_NONE(), 0);
        bytes memory payload = _payload(5e6);
        vm.expectRevert(CircleGatewayAdapter.NOTHING_MINTED.selector);
        adapter.receiveAndExecute(payload, "");
        assertFalse(minter.isTransferSpecHashUsed(_hashOf(payload)), "mint unwound");
    }

    /// @notice Under-mint: the account gets exactly what arrived, never the attested value.
    function test_UnderMint_DeliversDeltaOnly() public {
        minter.setMintMode(minter.MINT_OVERRIDE(), 3e6);
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 5e6, _hook(account, 5e6));
        // SpecProcessed reports the ATTESTED value; TransferSucceeded the delivered delta
        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(s), account, 5e6, false);
        vm.expectEmit(true, true, false, true);
        emit TransferSucceeded(account, address(usdc), 3e6);
        adapter.receiveAndExecute(_encode(s), "");
        assertEq(usdc.balanceOf(account), 3e6);
        assertEq(adapter.failedTransfers(account, address(usdc)), 0);
    }

    /// @notice Over-mint: the attested value is delivered; the anomalous surplus is credited to the account's
    ///         escrow (never retained, never stranded) and counted in totalEscrowed.
    function test_OverMint_SurplusCreditedToAccount() public {
        minter.setMintMode(minter.MINT_OVERRIDE(), 8e6);
        vm.expectEmit(true, true, false, true);
        emit TransferFailed(account, address(usdc), 3e6);
        adapter.receiveAndExecute(_payload(5e6), "");
        assertEq(usdc.balanceOf(account), 5e6, "attested value delivered");
        assertEq(adapter.failedTransfers(account, address(usdc)), 3e6, "surplus escrowed");
        assertEq(adapter.totalEscrowed(address(usdc)), 3e6);
        vm.prank(account);
        adapter.claimFailedTransfer(address(usdc), 3e6);
        assertEq(usdc.balanceOf(account), 8e6);
        assertEq(adapter.totalEscrowed(address(usdc)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        POST-MINT: NEVER REVERT
    //////////////////////////////////////////////////////////////*/

    function test_ExecutorRevert_EmitsExecutionFailed_ButFundsDelivered() public {
        executor.setShouldRevert(true);
        vm.expectEmit(true, false, false, true);
        emit ExecutionFailed(account, bytes4(keccak256("Error(string)")));
        adapter.receiveAndExecute(_payload(5e6), "");
        assertEq(usdc.balanceOf(account), 5e6, "funds delivered despite executor revert");
        assertEq(executor.callCount(), 0);
    }

    /// @notice Falsifiable returnbomb check: the cap leaves ~2.2M at the 2M floor (parse + the mock minter's
    ///         payload SSTOREs + self-calls cost ~0.77M), so the executor gets ~2.2M — enough to PRODUCE the 800 KB
    ///         bomb (~1.4M incl. memory expansion) but, after it returns, not enough for the adapter to COPY it
    ///         (another ~1.3M). A bare `catch` survives; a `catch (bytes memory)` regression would OOG the whole
    ///         relay. Keep the cap below ~3.4M or the copy becomes affordable and the test stops being falsifiable.
    function test_ExecutorReturnbomb_DoesNotOOG() public {
        executor.setShouldRevert(true);
        executor.setShouldReturnbomb(true);
        bytes memory payload = _payload(5e6);
        vm.expectEmit(true, false, false, true);
        emit ExecutionFailed(account, bytes4(keccak256("Error(string)"))); // selector present => bomb was produced
        adapter.receiveAndExecute{ gas: 3_000_000 }(payload, "");
        assertEq(usdc.balanceOf(account), 5e6);
    }

    /// @notice `recoverDirectMint` shares the same reentrancy lock.
    function test_ReentrantExecutor_ViaRecover_Rejected() public {
        executor.setShouldReenter(true, address(adapter));
        executor.setReenterViaRecover(true);
        vm.expectEmit(true, false, false, true);
        emit ExecutionFailed(account, ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        adapter.receiveAndExecute(_payload(5e6), "");
        assertEq(usdc.balanceOf(account), 5e6);
    }

    function test_ReentrantExecutor_Rejected_ExecutionFailed() public {
        executor.setShouldReenter(true, address(adapter));
        vm.expectEmit(true, false, false, true);
        emit ExecutionFailed(account, ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        adapter.receiveAndExecute(_payload(5e6), "");
        assertEq(usdc.balanceOf(account), 5e6, "funds delivered; reentry rejected");
    }

    function test_ExecutorOOGStyleRevert_ZeroSelector() public {
        // an executor that reverts with EMPTY returndata (INVALID opcode), as an OOG would
        MockDestinationExecutor dead = new MockDestinationExecutor();
        CircleGatewayAdapter a = new CircleGatewayAdapter(address(minter), address(usdc), address(dead));
        vm.etch(address(dead), hex"fe");
        TransferSpec memory s = _spec(address(a), address(a), address(usdc), 5e6, _hook(account, 5e6));
        vm.expectEmit(true, false, false, true);
        emit ExecutionFailed(account, bytes4(0));
        a.receiveAndExecute(_encode(s), "");
        assertEq(usdc.balanceOf(account), 5e6);
    }

    /// @notice A blacklisted account: the mint succeeded, so the funds are escrowed and claimable later.
    function test_FailedTransfer_Escrows_ThenClaim() public {
        BlacklistUSDC blk = new BlacklistUSDC();
        MockGatewayMinter m = new MockGatewayMinter(address(blk));
        CircleGatewayAdapter a = new CircleGatewayAdapter(address(m), address(blk), address(executor));
        blk.setBlacklisted(account, true);

        TransferSpec memory s = _specFor(m, address(a), address(a), address(blk), 5e6, _hook(account, 5e6));
        vm.expectEmit(true, true, false, true);
        emit TransferFailed(account, address(blk), 5e6);
        a.receiveAndExecute(_encode(s), "");

        assertEq(a.failedTransfers(account, address(blk)), 5e6);
        assertEq(a.totalEscrowed(address(blk)), 5e6);
        assertEq(executor.callCount(), 1, "execution still attempted (executor gates on balance itself)");

        blk.setBlacklisted(account, false);
        // claim isolation: a stranger cannot claim the account's escrow
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(CircleGatewayAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        a.claimFailedTransfer(address(blk), 5e6);

        vm.expectEmit(true, true, false, true);
        emit FailedTransferClaimed(account, address(blk), 5e6);
        vm.prank(account);
        a.claimFailedTransfer(address(blk), 5e6);
        assertEq(blk.balanceOf(account), 5e6);
        assertEq(a.failedTransfers(account, address(blk)), 0);
        assertEq(a.totalEscrowed(address(blk)), 0);
    }

    function _specFor(
        MockGatewayMinter m,
        address recipient,
        address caller,
        address token,
        uint256 value,
        bytes memory hookData
    )
        internal
        returns (TransferSpec memory s)
    {
        s = _spec(recipient, caller, token, value, hookData);
        s.destinationContract = AddressLib._addressToBytes32(address(m));
        s.destinationDomain = m.domain();
    }

    function test_Claim_Reverts_OnZeroAndInsufficient() public {
        vm.expectRevert(CircleGatewayAdapter.ZERO_AMOUNT.selector);
        adapter.claimFailedTransfer(address(usdc), 0);
        vm.expectRevert(CircleGatewayAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(address(usdc), 1);
    }

    function test_NonBoolReturnWordEscrowsInsteadOfPanicking() public {
        NonBoolWordUSDC nb = new NonBoolWordUSDC();
        MockGatewayMinter m = new MockGatewayMinter(address(nb));
        CircleGatewayAdapter a = new CircleGatewayAdapter(address(m), address(nb), address(executor));
        TransferSpec memory s = _specFor(m, address(a), address(a), address(nb), 5e6, _hook(account, 5e6));
        a.receiveAndExecute(_encode(s), "");
        assertEq(a.failedTransfers(account, address(nb)), 5e6, "escrowed, not panicked");
    }

    /*//////////////////////////////////////////////////////////////
                          DST-PROOF TARGETING
    //////////////////////////////////////////////////////////////*/

    function _hookWithProof(
        address account_,
        uint64 chainId,
        address proofExecutor,
        address proofValidator
    )
        internal
        pure
        returns (bytes memory)
    {
        address[] memory dstTokens = new address[](1);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account_,
                executor: proofExecutor,
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: proofValidator,
                data: bytes("exec")
            })
        });
        bytes memory sigData =
            abi.encode(new uint64[](0), uint48(0), uint48(0), bytes32(0), new bytes32[](0), proofDst, new bytes(65));
        return abi.encode(bytes("init"), bytes("exec"), account_, dstTokens, intentAmounts, sigData);
    }

    function _relayWithProof(uint64 chainId, address ex, address val) internal {
        bytes memory hook = _hookWithProof(account, chainId, ex, val);
        adapter.receiveAndExecute(_encode(_spec(address(adapter), address(adapter), address(usdc), 5e6, hook)), "");
    }

    function test_ExecutorMismatch_DeliversFundsSkipsExecution() public {
        vm.expectEmit(true, false, false, true);
        emit DestinationTargetMismatch(account, 1);
        _relayWithProof(uint64(block.chainid), address(0xBAD), executor.SUPER_DESTINATION_VALIDATOR());
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 0);
    }

    function test_ValidatorMismatch_DeliversFundsSkipsExecution() public {
        vm.expectEmit(true, false, false, true);
        emit DestinationTargetMismatch(account, 2);
        _relayWithProof(uint64(block.chainid), address(executor), address(0xBAD));
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 0);
    }

    function test_MatchingProof_Succeeds() public {
        _relayWithProof(uint64(block.chainid), address(executor), executor.SUPER_DESTINATION_VALIDATOR());
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 1);
    }

    function test_ProofForOtherChain_SkipsAssertion_StillDelivers() public {
        _relayWithProof(uint64(block.chainid) + 1, address(0xBAD), address(0xBAD));
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 1);
    }

    /// @notice `_hook` carries an undecodable sigData ("sig"): contained by the self-call, relay proceeds.
    function test_MalformedSigData_DoesNotRevert() public {
        adapter.receiveAndExecute(_payload(5e6), "");
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 1);
    }

    function test_Revert_SelfCallHelpers_NotSelfCalled() public {
        vm.expectRevert(CircleGatewayAdapter.INVALID_SENDER.selector);
        adapter.checkDestinationTargets("");
        vm.expectRevert(CircleGatewayAdapter.INVALID_SENDER.selector);
        adapter.decodeHookPayload("");
    }

    /*//////////////////////////////////////////////////////////////
                               GAS FLOOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverting at the floor unwinds the mint: the spec stays unused and the payload retriable.
    function test_Revert_InsufficientGasForExecution() public {
        bytes memory payload = _payload(5e6);
        // Budget assumption: parse + mock mint + transfer fit well inside 1.2M, so the floor (2M) is what reverts,
        // not a bare OOG. Re-check if the mock's cost drifts.
        vm.expectRevert(CircleGatewayAdapter.INSUFFICIENT_GAS.selector);
        adapter.receiveAndExecute{ gas: 1_200_000 }(payload, "");
        assertFalse(minter.isTransferSpecHashUsed(_hashOf(payload)), "mint unwound");
        assertFalse(adapter.processed(_hashOf(payload)));
    }

    /*//////////////////////////////////////////////////////////////
                           RECOVER DIRECT MINT
    //////////////////////////////////////////////////////////////*/

    /// @dev Simulates a third party calling `gatewayMint` directly on a zero-caller spec that mints into the
    ///      adapter: the minter marks the hash used and the USDC lands in the adapter with no delivery.
    function _strayMint(uint256 value) internal returns (TransferSpec memory s, bytes memory payload) {
        s = _spec(address(adapter), address(0), address(usdc), value, _hook(account, value));
        payload = _encode(s);
        vm.prank(makeAddr("thirdParty"));
        minter.gatewayMint(payload, "");
        assertEq(usdc.balanceOf(address(adapter)), value, "stranded in adapter");
    }

    function test_Recover_ForwardsStrayMintAndExecutes() public {
        (TransferSpec memory s, bytes memory payload) = _strayMint(5e6);
        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(s), account, 5e6, true);
        adapter.recoverDirectMint(payload);
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(usdc.balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 1, "intent executed as the relay would have");
        assertTrue(adapter.processed(_hash(s)));
        assertEq(minter.calls(), 1, "no second mint attempted");
    }

    function test_Recover_Set_Homogeneous() public {
        bytes memory hook = _hook(account, 7e6);
        TransferSpec[] memory specs = new TransferSpec[](2);
        specs[0] = _spec(address(adapter), address(0), address(usdc), 3e6, hook);
        specs[1] = _spec(address(adapter), address(0), address(usdc), 4e6, hook);
        bytes memory payload = _encodeSet(specs);
        vm.prank(makeAddr("thirdParty"));
        minter.gatewayMint(payload, "");
        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(specs[0]), account, 3e6, true);
        vm.expectEmit(true, true, false, true);
        emit SpecProcessed(_hash(specs[1]), account, 4e6, true);
        adapter.recoverDirectMint(payload);
        assertEq(usdc.balanceOf(account), 7e6);
        assertTrue(adapter.processed(_hash(specs[0])) && adapter.processed(_hash(specs[1])));
    }

    function test_Recover_Revert_SpecNotMinted() public {
        bytes memory payload = _encode(_spec(address(adapter), address(0), address(usdc), 5e6, _hook(account, 5e6)));
        usdc.mint(address(adapter), 5e6); // balance is there, but Circle never minted this spec
        vm.expectRevert(CircleGatewayAdapter.SPEC_NOT_MINTED.selector);
        adapter.recoverDirectMint(payload);
    }

    function test_Recover_Revert_AlreadyProcessed_AfterRelay() public {
        bytes memory payload = _encode(_spec(address(adapter), address(0), address(usdc), 5e6, _hook(account, 5e6)));
        adapter.receiveAndExecute(payload, "");
        usdc.mint(address(adapter), 5e6); // a donation must not be re-attributable to the same spec
        vm.expectRevert(CircleGatewayAdapter.SPEC_ALREADY_PROCESSED.selector);
        adapter.recoverDirectMint(payload);
    }

    function test_Recover_Revert_AlreadyRecovered() public {
        (, bytes memory payload) = _strayMint(5e6);
        adapter.recoverDirectMint(payload);
        usdc.mint(address(adapter), 5e6);
        vm.expectRevert(CircleGatewayAdapter.SPEC_ALREADY_PROCESSED.selector);
        adapter.recoverDirectMint(payload);
    }

    /// @notice R1-F2: recovery needs no Circle signature — the minter's used-hash record is the witness. Anyone
    ///         can reconstruct a payload around the minted spec (any maxBlockHeight) and drive the recovery.
    function test_Recover_AnyCallerWithReconstructedPayload() public {
        (TransferSpec memory s,) = _strayMint(5e6);
        bytes memory reconstructed = AttestationLib.encodeAttestation(Attestation({ maxBlockHeight: 1, spec: s })); // different
        // wrapper
        vm.prank(makeAddr("goodSamaritan"));
        adapter.recoverDirectMint(reconstructed);
        assertEq(usdc.balanceOf(account), 5e6);
        assertTrue(adapter.processed(_hash(s)));
    }

    /// @notice A forged payload (different account → different hash) is not minted: nothing to recover.
    function test_Recover_Revert_ForgedAccount_NotMinted() public {
        (TransferSpec memory s,) = _strayMint(5e6);
        s.hookData = _hook(makeAddr("thief"), 5e6);
        vm.expectRevert(CircleGatewayAdapter.SPEC_NOT_MINTED.selector);
        adapter.recoverDirectMint(_encode(s));
        assertEq(usdc.balanceOf(address(adapter)), 5e6, "funds untouched");
    }

    /// @notice A spec pinned to a THIRD-PARTY caller X: the relay rejects it, X can mint it directly into the
    ///         adapter, and recovery attributes it — recovery deliberately does not check destinationCaller.
    function test_Recover_ThirdPartyPinnedCaller_Recovered() public {
        address x = makeAddr("X");
        TransferSpec memory s = _spec(address(adapter), x, address(usdc), 5e6, _hook(account, 5e6));
        bytes memory payload = _encode(s);
        vm.expectRevert(CircleGatewayAdapter.DESTINATION_CALLER_MISMATCH.selector);
        adapter.receiveAndExecute(payload, "");
        vm.prank(x);
        minter.gatewayMint(payload, "");
        adapter.recoverDirectMint(payload);
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(executor.callCount(), 1);
    }

    /// @notice R1-F1: the same spec twice in one payload is rejected on BOTH entrypoints, so a recovery can never
    ///         attribute one stray mint twice (and take the second copy from other users' stray funds).
    function test_Set_DuplicateMember_Rejected() public {
        bytes memory hook = _hook(account, 5e6);
        TransferSpec memory s = _spec(address(adapter), address(0), address(usdc), 5e6, hook);
        TransferSpec[] memory dup = new TransferSpec[](2);
        dup[0] = s;
        dup[1] = s;
        bytes memory dupPayload = _encodeSet(dup);

        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_DUPLICATE.selector);
        adapter.receiveAndExecute(dupPayload, "");
        assertEq(minter.calls(), 0, "rejected pre-mint");

        // stray-mint the single spec, plus a second victim's stray mint sitting in the adapter
        vm.prank(makeAddr("thirdParty"));
        minter.gatewayMint(_encode(s), "");
        usdc.mint(address(adapter), 5e6); // stands in for another user's stray mint
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_DUPLICATE.selector);
        adapter.recoverDirectMint(dupPayload);

        adapter.recoverDirectMint(_encode(s));
        assertEq(usdc.balanceOf(account), 5e6, "exactly one attribution");
        assertEq(usdc.balanceOf(address(adapter)), 5e6, "the other stray funds are untouched");
    }

    /// @notice Two stray mints for two accounts: each recovery forwards exactly its own value, in either order,
    ///         and the adapter ends empty (INV: balance >= Σ unrecovered values + totalEscrowed).
    function test_Recover_TwoStrayMints_DifferentAccounts_EitherOrder() public {
        address other = makeAddr("other");
        TransferSpec memory s1 = _spec(address(adapter), address(0), address(usdc), 5e6, _hook(account, 5e6));
        TransferSpec memory s2 = _spec(address(adapter), address(0), address(usdc), 7e6, _hook(other, 7e6));
        vm.startPrank(makeAddr("thirdParty"));
        minter.gatewayMint(_encode(s1), "");
        minter.gatewayMint(_encode(s2), "");
        vm.stopPrank();
        assertEq(usdc.balanceOf(address(adapter)), 12e6);

        adapter.recoverDirectMint(_encode(s2)); // second first
        assertEq(usdc.balanceOf(other), 7e6);
        assertEq(usdc.balanceOf(address(adapter)), 5e6, "s1's value still held");
        adapter.recoverDirectMint(_encode(s1));
        assertEq(usdc.balanceOf(account), 5e6);
        assertEq(usdc.balanceOf(address(adapter)), 0, "adapter empty");
        assertEq(executor.callCount(), 2);
    }

    /// @notice Escrowed funds can never be forwarded by a recovery: spendable = balance - totalEscrowed.
    function test_Recover_Revert_InsufficientRecoverable_EscrowProtected() public {
        BlacklistUSDC blk = new BlacklistUSDC();
        MockGatewayMinter m = new MockGatewayMinter(address(blk));
        CircleGatewayAdapter a = new CircleGatewayAdapter(address(m), address(blk), address(executor));

        // 1. a relay whose delivery fails → 5e6 escrowed to `account`
        blk.setBlacklisted(account, true);
        a.receiveAndExecute(_encode(_specFor(m, address(a), address(a), address(blk), 5e6, _hook(account, 5e6))), "");
        assertEq(a.totalEscrowed(address(blk)), 5e6);

        // 2. a stray zero-caller mint for `victim` that somehow lost its funds (simulate: minter marks used but
        //    mints nothing) — the recovery must NOT dip into the escrow
        address victim = makeAddr("victim");
        m.setMintMode(m.MINT_NONE(), 0);
        TransferSpec memory s = _specFor(m, address(a), address(0), address(blk), 5e6, _hook(victim, 5e6));
        bytes memory payload = _encode(s);
        vm.prank(makeAddr("thirdParty"));
        m.gatewayMint(payload, "");
        assertEq(blk.balanceOf(address(a)), 5e6, "only the escrowed balance is present");

        vm.expectRevert(CircleGatewayAdapter.INSUFFICIENT_RECOVERABLE.selector);
        a.recoverDirectMint(payload);
    }

    function test_Recover_Revert_RecipientNotAdapter_OrNonUsdc() public {
        bytes memory payload = _encode(_spec(makeAddr("x"), address(0), address(usdc), 5e6, _hook(account, 5e6)));
        vm.expectRevert(CircleGatewayAdapter.DESTINATION_RECIPIENT_MISMATCH.selector);
        adapter.recoverDirectMint(payload);

        payload = _encode(_spec(address(adapter), address(0), address(other), 5e6, _hook(account, 5e6)));
        vm.expectRevert(CircleGatewayAdapter.UNSUPPORTED_DESTINATION_TOKEN.selector);
        adapter.recoverDirectMint(payload);
    }

    function test_Recover_Revert_MalformedHookData() public {
        TransferSpec memory s = _spec(address(adapter), address(0), address(usdc), 5e6, hex"dead");
        bytes memory payload = _encode(s);
        vm.prank(makeAddr("thirdParty"));
        minter.gatewayMint(payload, "");
        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        adapter.recoverDirectMint(payload);
    }

    /// @notice A relay of a zero-caller spec after a stray mint is rejected by the minter (hash used) — the
    ///         relayer is told to use `recoverDirectMint` by the revert, not by the adapter guessing.
    function test_Relay_AfterStrayMint_RevertsAtMinter_ThenRecoverWorks() public {
        (TransferSpec memory s, bytes memory payload) = _strayMint(5e6);
        vm.expectRevert(abi.encodeWithSelector(MockGatewayMinter.TransferSpecHashUsed.selector, _hash(s)));
        adapter.receiveAndExecute(payload, "");
        adapter.recoverDirectMint(payload);
        assertEq(usdc.balanceOf(account), 5e6);
    }

    /// @notice Non-adjacent duplicate {S, T, S}: the inner compare loop must look past index 0.
    function test_Set_NonAdjacentDuplicate_Rejected() public {
        bytes memory hook = _hook(account, 1);
        TransferSpec memory s = _spec(address(adapter), address(adapter), address(usdc), 1e6, hook);
        TransferSpec[] memory set = new TransferSpec[](3);
        set[0] = s;
        set[1] = _spec(address(adapter), address(adapter), address(usdc), 2e6, hook);
        set[2] = s;
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_DUPLICATE.selector);
        adapter.receiveAndExecute(_encodeSet(set), "");
        assertEq(minter.calls(), 0);
    }

    /// @notice An empty set is rejected with its own reason on both entrypoints, before any external call.
    function test_Set_Empty_Rejected() public {
        bytes memory empty = _encodeSet(new TransferSpec[](0));
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_EMPTY.selector);
        adapter.receiveAndExecute(empty, "");
        vm.expectRevert(CircleGatewayAdapter.ATTESTATION_SET_EMPTY.selector);
        adapter.recoverDirectMint(empty);
        assertEq(minter.calls(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @notice INV-1/INV-3: exactly the attested value is delivered; adapter returns to its baseline.
    function testFuzz_ExactDelivery(uint256 value, uint256 donation) public {
        value = bound(value, 1, 1e30);
        donation = bound(donation, 0, 1e30);
        usdc.mint(address(adapter), donation);
        adapter.receiveAndExecute(_payload(value), "");
        assertEq(usdc.balanceOf(account), value, "exact value delivered");
        assertEq(usdc.balanceOf(address(adapter)), donation, "adapter back to donated baseline");
    }

    /// @notice INV-2: hookData of arbitrary size round-trips byte-identically into the executor call.
    function testFuzz_HookDataRoundTrip(bytes calldata initData, bytes calldata execCalldata) public {
        vm.assume(initData.length < 4096 && execCalldata.length < 4096);
        address[] memory dstTokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        bytes memory hook = abi.encode(initData, execCalldata, account, dstTokens, amounts, bytes(""));
        adapter.receiveAndExecute(_encode(_spec(address(adapter), address(adapter), address(usdc), 1, hook)), "");
        assertEq(keccak256(executor.lastInitData()), keccak256(initData));
        assertEq(keccak256(executor.lastExecutorCalldata()), keccak256(execCalldata));
    }
}
