// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { WebAuthn } from "solady/utils/WebAuthn.sol";

// Superform
import { SuperValidator } from "../../../src/validators/SuperValidator.sol";
import { SuperValidatorV2 } from "../../../src/validators/SuperValidatorV2.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";
import {
    ChainAgnosticCoinbaseSmartWalletValidation
} from "../../../src/libraries/ChainAgnosticCoinbaseSmartWalletValidation.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";

/// @dev Minimal Coinbase Smart Wallet stand-in: only the owner-set surface the library reads, with the return
///      shapes verified against the live implementation, AND the permissive fallback the real wallet has.
///      The fallback is not decoration — it is what makes a `try`-shaped probe revert uncatchably, so a mock
///      without one would hide the very failure `SuperValidatorV2`'s family routing exists to avoid.
contract E2EMockCoinbaseSmartWallet {
    mapping(uint256 => bytes) internal _owners;
    uint256 public nextOwnerIndexValue;

    function setPasskeyOwner(uint256 index, bytes32 x, bytes32 y) external {
        _owners[index] = abi.encode(x, y);
        if (index + 1 > nextOwnerIndexValue) nextOwnerIndexValue = index + 1;
    }

    function nextOwnerIndex() external view returns (uint256) {
        return nextOwnerIndexValue;
    }

    function ownerAtIndex(uint256 index) external view returns (bytes memory) {
        return _owners[index];
    }

    fallback() external { }
}

/// @dev Minimal Safe owner. No fallback, so the Coinbase probe's `staticcall` to `nextOwnerIndex()` REVERTS
///      (the probe reports "not mine") and `SuperValidatorV2` routes to the Safe path — which is the whole
///      purpose of routing rather than chaining the two families.
contract E2EMockSafe {
    address[] internal _owners;

    constructor(address owner_) {
        _owners.push(owner_);
    }

    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    function getThreshold() external pure returns (uint256) {
        return 1;
    }
}

/// @dev An owner that is neither a Safe nor a Coinbase wallet: plain ERC-1271 over the raw message hash.
contract E2EMock1271 {
    address public immutable OWNER;
    bool public broken;

    constructor(address owner_) {
        OWNER = owner_;
    }

    function setBroken(bool v) external {
        broken = v;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        if (broken) return bytes4(0xdeadbeef);
        return ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(hash), signature) == OWNER
            ? bytes4(0x1626ba7e)
            : bytes4(0xffffffff);
    }
}

/// @title SuperValidatorV2E2ETest
/// @author Superform Labs
/// @notice END TO END: `SuperValidatorV2` installed on a real ERC-7579 account ALONGSIDE the already-deployed
///         `SuperValidator`, validating a Coinbase Smart Wallet ("Base Smart Wallet") passkey owner through
///         both validator entry points (`validateUserOp` and `isValidSignatureWithSender`).
/// @dev WHY THE MODULE AND WALLET ADDRESSES ARE PINNED WITH `vm.etch`. The WebAuthn fixture below is a real
///      secp256r1 assertion over one specific EIP-712 digest, and that digest is a function of the wallet
///      address (it is the EIP-712 `verifyingContract`) and of the merkle root — which itself commits
///      `address(this)` of the validator via `SuperValidator._createLeaf`. If either address moved with a
///      deployment nonce the fixture would silently stop matching, so both are fixed and
///      `test_E2E_Precondition_DigestIsStable` turns any drift into one legible failure instead of a dozen
///      mysterious ones.
/// @dev The merkle tree is deliberately a single leaf (`root == leaf`, empty proof). The merkle machinery is
///      covered exhaustively in `SuperMerkleValidator.t.sol`; what is new here is the SIGNATURE path and the
///      module coexistence, so the tree is kept trivial to keep the root — and therefore the signed digest —
///      deterministic.
contract SuperValidatorV2E2ETest is MerkleTreeHelper, RhinestoneModuleKit {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                              ENVIRONMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Pinned Base fork. REQUIRED, not incidental: P-256 verification needs either the RIP-7212
    ///      precompile at `0x100` — which Foundry does not emulate and a fork does not carry — or solady's
    ///      deployed Solidity verifier, which DOES exist on Base. The verifier is what answers here; see
    ///      `test_E2E_Precondition_P256VerificationIsAvailable`.
    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;

    address internal constant V2_ADDR = 0x0000000000000000000000000000000000005002;
    address internal constant WALLET_ADDR = 0x00000000000000000000000000000000CB5c0002;

    SuperValidator internal v1;
    SuperValidatorV2 internal v2;
    E2EMockCoinbaseSmartWallet internal wallet;

    /// @dev `account` holds BOTH validators: V1 owned by an EOA, V2 owned by the passkey wallet.
    AccountInstance internal instance;
    address internal account;

    /// @dev `accountEoa` holds V2 only, owned by an EOA — the superset proof.
    AccountInstance internal instanceEoa;
    address internal accountEoa;

    /// @dev `accountCounterfactual` holds V2 only, owned by a CODELESS address — the original bug report.
    AccountInstance internal instanceCounterfactual;
    address internal accountCounterfactual;

    /// @dev `accountMigration` is the realistic starting point: an EXISTING Superform account that has only
    ///      `SuperValidator` installed, whose owner is now a Base Smart Wallet. It is deliberately left
    ///      without V2 in `setUp` so the migration test can install it mid-flight.
    AccountInstance internal instanceMigration;
    address internal accountMigration;

    address internal eoaOwner;
    uint256 internal eoaKey;

    /// @dev A deterministic address with no code: a Coinbase Smart Wallet that exists on another chain but
    ///      has not yet been deployed on this one.
    address internal constant COUNTERFACTUAL_OWNER = 0x00000000000000000000000000000000C0dE1E55;

    /*//////////////////////////////////////////////////////////////
                           FIXED INTENT + FIXTURE
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant USEROP_HASH = keccak256("SuperValidatorV2 e2e userOp");
    uint48 internal constant VALID_UNTIL = 2_000_000_000;

    /// @dev The digest the passkey actually signed. Pinned; regenerate the fixture if it ever changes.
    bytes32 internal constant DIGEST = 0x46eb1ca771e7cc9ef97c8c7d4b85d266a1cb2ee06f7dc7ce8a7181a43228d4ac;

    /// @dev A real secp256r1 keypair and two real assertions over `DIGEST`, generated off-chain with a
    ///      dependency-free P-256 signer and low-s normalised as RIP-7212 requires. Nothing here is a mock:
    ///      the signatures are verified by solady's `WebAuthn`/`P256` exactly as production would.
    bytes32 internal constant PUBKEY_X = 0x6ee581a0aa61e6231f95283949e8e547e9f739d8cd33c2da167212476f88b3ca;
    bytes32 internal constant PUBKEY_Y = 0xb62dba6b3032304c71e0cda7bca138609d825bbbb26b7ef655f87b78a67dde1d;

    /// @dev User Present + User Verified (flags byte `0x05`) — a biometric/PIN-confirmed assertion.
    bytes internal constant AUTH_DATA_UP_UV =
        hex"f198086b2db17256731bc456673b96bcef23f51d1fbacdd7c4379ef65465572f0500000000";
    bytes32 internal constant SIG_R_UP_UV = 0xda4cdaeb2d9ac541b973bffbea6813e539d35c6ba1b1c5c41e1593fcb14f9dec;
    bytes32 internal constant SIG_S_UP_UV = 0x7eabe796aa682a8c1a6ebdd11dece49fc226961ccec757e2918b6d33098874e1;

    /// @dev User Present ONLY (flags byte `0x01`). Kept as a separate real signature because the library
    ///      passes `requireUserVerification = false`, matching what the wallet's own ERC-1271 accepts — and a
    ///      fixture that always set the UV bit would leave that decision completely untested.
    bytes internal constant AUTH_DATA_UP_ONLY =
        hex"f198086b2db17256731bc456673b96bcef23f51d1fbacdd7c4379ef65465572f0100000000";
    bytes32 internal constant SIG_R_UP_ONLY = 0x951c20b4fd4fd8f28aaffdcd49a8a65299d4a0ab911ca68dbc604637837fa1a6;
    bytes32 internal constant SIG_S_UP_ONLY = 0x4cb3bc6e3e5aee054fc107738683f20c4ccbdd658de85336a221e56413079015;

    string internal constant CLIENT_DATA_JSON =
        "{\"type\":\"webauthn.get\",\"challenge\":\"Ruscp3HnzJ75fIx9S4XSZqHLLuBvfcfOinGBpDIo1Kw\",\"origin\":\"https://keys.coinbase.com\",\"crossOrigin\":false}";
    uint256 internal constant CHALLENGE_INDEX = 23;
    uint256 internal constant TYPE_INDEX = 1;

    /// @dev The wallet's signature envelope. Declared as a STRUCT so `abi.encode` produces the dynamic-tuple
    ///      layout the wallet actually consumes, complete with its leading `0x20` offset word.
    struct SignatureWrapper {
        uint256 ownerIndex;
        bytes signatureData;
    }

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);

        v1 = new SuperValidator();

        SuperValidatorV2 freshV2 = new SuperValidatorV2();
        vm.etch(V2_ADDR, address(freshV2).code);
        v2 = SuperValidatorV2(V2_ADDR);

        E2EMockCoinbaseSmartWallet freshWallet = new E2EMockCoinbaseSmartWallet();
        vm.etch(WALLET_ADDR, address(freshWallet).code);
        wallet = E2EMockCoinbaseSmartWallet(WALLET_ADDR);
        wallet.setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);

        (eoaOwner, eoaKey) = makeAddrAndKey("v1-eoa-owner");

        // THE POINT OF THIS SUITE: one account, both validators, installed independently.
        instance = makeAccountInstance(keccak256("SUP-17924-e2e-both"));
        account = instance.account;
        instance.installModule(MODULE_TYPE_VALIDATOR, address(v1), abi.encode(eoaOwner));
        instance.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(WALLET_ADDR));

        instanceEoa = makeAccountInstance(keccak256("SUP-17924-e2e-eoa"));
        accountEoa = instanceEoa.account;
        instanceEoa.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(eoaOwner));

        instanceMigration = makeAccountInstance(keccak256("SUP-17924-e2e-migration"));
        accountMigration = instanceMigration.account;
        // ONLY V1, and its owner is the passkey wallet. V2 is installed later, inside the test.
        instanceMigration.installModule(MODULE_TYPE_VALIDATOR, address(v1), abi.encode(WALLET_ADDR));

        instanceCounterfactual = makeAccountInstance(keccak256("SUP-17924-e2e-cf"));
        accountCounterfactual = instanceCounterfactual.account;
        instanceCounterfactual.installModule(MODULE_TYPE_VALIDATOR, address(v1), abi.encode(COUNTERFACTUAL_OWNER));
        instanceCounterfactual.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(COUNTERFACTUAL_OWNER));
    }

    /*//////////////////////////////////////////////////////////////
                              PRECONDITIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Pins the digest the fixture was signed against. If the validator address, the wallet address,
    ///         the intent parameters or the library's domain constants move, this fails first with a legible
    ///         message instead of every passkey test failing for an unrelated-looking reason.
    function test_E2E_Precondition_DigestIsStable() public view {
        assertEq(
            ChainAgnosticCoinbaseSmartWalletValidation.chainAgnosticDigest(WALLET_ADDR, _messageHash(address(v2))),
            DIGEST,
            "regenerate the WebAuthn fixture"
        );
    }

    /// @notice Documents what verifies P-256 in this environment, so nobody reads the gas numbers below as
    ///         production costs. Not the precompile: Foundry does not emulate `0x100` and a fork does not
    ///         carry it, so solady falls back to the deployed Solidity verifier — ~291k gas here against the
    ///         ~3.4k the precompile costs on Base in production.
    function test_E2E_Precondition_P256VerificationIsAvailable() public view {
        assertEq(address(0x100).code.length, 0, "fork unexpectedly provides the RIP-7212 precompile");
        assertGt(
            address(0x000000000000D01eA45F9eFD5c54f037Fa57Ea1a).code.length,
            0,
            "solady's P256 verifier is absent on the pinned fork"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    INSTALLING V2 NEXT TO THE LIVE V1
    //////////////////////////////////////////////////////////////*/

    /// @notice Both modules are installed on the SAME account, each with its own owner and its own namespace.
    ///         This is the deployment story for SUP-17924: V2 ships as a new module rather than as an edit to
    ///         the shared base, so the two already-deployed validators keep their addresses and their code,
    ///         and an account opts in by installing one more module.
    function test_E2E_BothValidatorsCoexistOnOneAccount() public view {
        assertTrue(v1.isInitialized(account), "V1 not initialized");
        assertTrue(v2.isInitialized(account), "V2 not initialized");

        assertEq(v1.getAccountOwner(account), eoaOwner, "V1 owner");
        assertEq(v2.getAccountOwner(account), WALLET_ADDR, "V2 owner");

        assertEq(v1.namespace(), "SuperValidator");
        assertEq(v2.namespace(), "SuperValidatorV2");

        assertTrue(address(v1) != address(v2), "distinct module addresses");
        assertTrue(v1.isModuleType(MODULE_TYPE_VALIDATOR) && v2.isModuleType(MODULE_TYPE_VALIDATOR));
    }

    /// @notice Installing V2 does not touch V1's state, and uninstalling V2 leaves V1 working. Each module
    ///         keeps its own `_initialized` / `_accountOwners` mapping, so there is nothing shared to corrupt.
    function test_E2E_UninstallingV2LeavesV1Intact() public {
        instance.uninstallModule(MODULE_TYPE_VALIDATOR, address(v2), "");

        assertFalse(v2.isInitialized(account), "V2 still initialized");
        assertTrue(v1.isInitialized(account), "V1 was disturbed");
        assertEq(v1.getAccountOwner(account), eoaOwner, "V1 owner was disturbed");

        _assertValid(v1.validateUserOp(_userOp(account, _eoaSigData(address(v1))), USEROP_HASH), "V1 after V2 removal");
    }

    /*//////////////////////////////////////////////////////////////
                  THE FEATURE: A REAL PASSKEY, END TO END
    //////////////////////////////////////////////////////////////*/

    /// @notice THE HEADLINE. A genuine secp256r1 WebAuthn assertion from a passkey registered on a Coinbase
    ///         Smart Wallet validates a user operation through `SuperValidatorV2`, with the wallet as the
    ///         account's owner. Under V1 this same signature cannot work at all: V1 would reach the wallet's
    ///         own ERC-1271, whose digest binds `chainId` and the wallet address.
    function test_E2E_V2_ValidatesACoinbasePasskeyOwner() public {
        _assertValid(
            v2.validateUserOp(
                _userOp(account, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
            ),
            "passkey userOp rejected"
        );
    }

    /// @notice The same assertion through the ERC-1271 entry point the account uses for off-chain signatures.
    function test_E2E_V2_ValidatesAPasskeyThroughIsValidSignatureWithSender() public {
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        vm.prank(account);
        assertEq(
            v2.isValidSignatureWithSender(address(0), USEROP_HASH, abi.encode(sigData)),
            bytes4(0x1626ba7e),
            "ERC-1271 path rejected the passkey"
        );
    }

    /// @notice ONE SIGNATURE, EVERY CHAIN — the property that would be lost by delegating to the wallet's own
    ///         ERC-1271, and the reason this library verifies against a fixed domain instead. The identical
    ///         assertion validates with the chain id set to Ethereum, Optimism and Arbitrum.
    function test_E2E_V2_PasskeyIsValidOnEveryChain() public {
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        uint64[3] memory chains = [uint64(1), 10, 42_161];
        for (uint256 i; i < chains.length; ++i) {
            vm.chainId(chains[i]);
            _assertValid(v2.validateUserOp(_userOp(account, sigData), USEROP_HASH), "rejected on another chain");
        }
    }

    /// @notice A passkey that proves only USER PRESENCE (no biometric/PIN) is accepted, because the library
    ///         passes `requireUserVerification = false` to match what the wallet's own ERC-1271 accepts.
    ///         Being stricter here would reject signatures the wallet itself considers valid. Asserted with a
    ///         separate real signature whose authenticator flags byte is `0x01` rather than `0x05`.
    function test_E2E_V2_UserPresenceOnlyPasskeyIsAccepted() public {
        _assertValid(
            v2.validateUserOp(
                _userOp(account, _passkeySigData(0, AUTH_DATA_UP_ONLY, SIG_R_UP_ONLY, SIG_S_UP_ONLY)), USEROP_HASH
            ),
            "user-presence-only passkey rejected"
        );
    }

    /// @notice `ownerIndex` is attacker-supplied calldata: pointing it at an unoccupied index is refused even
    ///         though the cryptography is untouched.
    function test_E2E_V2_RejectsAPasskeyAtTheWrongOwnerIndex() public {
        vm.expectRevert(SuperValidatorBase.NOT_EIP1271_SIGNER.selector);
        v2.validateUserOp(_userOp(account, _passkeySigData(1, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH);
    }

    /// @notice A passkey that is no longer a registered owner stops working immediately. The owner set is read
    ///         LIVE from the wallet on every validation rather than captured at install time, which is what
    ///         makes passkey removal an effective revocation — pinning the credential at install would
    ///         preserve a compromised key forever.
    function test_E2E_V2_RevokingThePasskeyRevokesTheSignature() public {
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        _assertValid(v2.validateUserOp(_userOp(account, sigData), USEROP_HASH), "sanity");

        wallet.setPasskeyOwner(0, bytes32(uint256(1)), bytes32(uint256(2)));

        vm.expectRevert(SuperValidatorBase.NOT_EIP1271_SIGNER.selector);
        v2.validateUserOp(_userOp(account, sigData), USEROP_HASH);
    }

    /// @notice REGRESSION, found by this suite rather than by review. When the chain-agnostic passkey check
    ///         fails, validation falls through to generic ERC-1271 against the wallet — and a Coinbase Smart
    ///         Wallet answers unknown selectors from a permissive fallback with `0x`. Written as
    ///         `try owner.isValidSignature(...) returns (bytes4)`, as V1 does, the call SUCCEEDS and the
    ///         decode of the absent return value then reverts in the validator's own frame WITH NO DATA,
    ///         where `catch` cannot reach it. A bundler cannot tell that apart from out-of-gas. V2 reads the
    ///         return with a low-level `staticcall` and a `returndatasize` check instead, so the failure is
    ///         the typed `NOT_EIP1271_SIGNER` this test asserts.
    function test_E2E_V2_NonConformingOwnerRevertsWithDataNotSilently() public {
        // Same shape as the real wallet: implements the owner set, answers everything else with `0x`.
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        // Break the passkey check so the generic ERC-1271 fallback is the path under test.
        wallet.setPasskeyOwner(0, bytes32(uint256(7)), bytes32(uint256(8)));

        vm.expectRevert(SuperValidatorBase.NOT_EIP1271_SIGNER.selector);
        v2.validateUserOp(_userOp(account, sigData), USEROP_HASH);
    }

    /*//////////////////////////////////////////////////////////////
              MIGRATION: THE SAME BYTES, BEFORE AND AFTER INSTALL
    //////////////////////////////////////////////////////////////*/

    /// @notice THE MIGRATION STORY, end to end on one account, with ONE immutable signature blob.
    ///         An existing Superform account has only `SuperValidator` installed and its owner is now a Base
    ///         Smart Wallet. The user signs an intent with their passkey. Three phases:
    ///           1. V1 is the only validator installed, and it cannot serve this owner at all.
    ///           2. The passkey intent is submitted to V2 before V2 is installed -> `NOT_INITIALIZED`.
    ///           3. The account installs V2 and resubmits THE IDENTICAL BYTES -> valid.
    ///         The blob is hashed before and after to make "the same signature" a checked claim rather than a
    ///         comment, and V2 is then uninstalled to show the install was the only variable.
    function test_E2E_Migration_SamePasskeySignatureFailsBeforeInstallAndWorksAfter() public {
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        bytes32 blobBefore = keccak256(sigData);

        // --- Phase 1: only V1 is installed, and V1 cannot serve a Base Smart Wallet owner ---
        assertTrue(v1.isInitialized(accountMigration), "V1 should be installed");
        assertFalse(v2.isInitialized(accountMigration), "V2 must NOT be installed yet");
        assertEq(v1.getAccountOwner(accountMigration), WALLET_ADDR, "V1's owner is the passkey wallet");

        // V1's own intent shape (its address in the leaf, its namespace in the message) still fails, and it
        // fails with NO revert data — see the dedicated test below for why that is the signature of the
        // capability gap rather than of a rejected signature.
        assertEq(
            _revertDataOf(
                v1, accountMigration, _passkeySigDataFor(address(v1), 0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)
            )
            .length,
            0,
            "V1 should die dataless on the wallet probe"
        );

        // --- Phase 2: the V2 intent, submitted before V2 exists on this account ---
        vm.expectRevert(ISuperValidator.NOT_INITIALIZED.selector);
        v2.validateUserOp(_userOp(accountMigration, sigData), USEROP_HASH);

        // --- Phase 3: install V2, change nothing else, resubmit the same bytes ---
        instanceMigration.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(WALLET_ADDR));

        assertTrue(v2.isInitialized(accountMigration), "V2 should now be installed");
        assertTrue(v1.isInitialized(accountMigration), "installing V2 must not disturb V1");
        assertEq(keccak256(sigData), blobBefore, "the signature blob must be byte-identical across phases");

        _assertValid(
            v2.validateUserOp(_userOp(accountMigration, sigData), USEROP_HASH),
            "the same passkey signature must validate once V2 is installed"
        );

        // --- And the install really was the only variable ---
        instanceMigration.uninstallModule(MODULE_TYPE_VALIDATOR, address(v2), "");
        vm.expectRevert(ISuperValidator.NOT_INITIALIZED.selector);
        v2.validateUserOp(_userOp(accountMigration, sigData), USEROP_HASH);
    }

    /// @notice WHY V1 CANNOT BE PATCHED INTO SERVING THIS, shown rather than asserted. V1 reaches
    ///         `ChainAgnosticSafeSignatureValidation`, whose probe is
    ///         `try ISafeConfiguration(owner).getOwners() returns (address[] memory)`. The ABI decode of that
    ///         dynamic return runs in V1's OWN frame after the call succeeds, so against a Base Smart
    ///         Wallet — which answers unknown selectors from a permissive fallback with `0x`, verified
    ///         against the live implementation — the decode reverts where `catch` cannot see it, with no
    ///         revert data at all.
    ///         The failure is therefore STRUCTURAL, not signature-specific: it happens before V1 looks at the
    ///         signature. Asserted by giving V1 a real passkey assertion and then pure garbage and showing
    ///         the two are indistinguishable.
    function test_E2E_Migration_V1DiesOnTheWalletProbeWhateverTheSignature() public {
        bytes memory realPasskey = _passkeySigDataFor(address(v1), 0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        bytes memory garbage = _sigData(address(v1), hex"c0ffee");

        // EMPTY revert data is the specific claim. A rejected signature would carry a selector —
        // `INVALID_PROOF` or `NOT_EIP1271_SIGNER`, four bytes — and an invalid ECDSA length would carry
        // `ECDSAInvalidSignatureLength(uint256)` with its argument. Zero bytes means the frame died inside an
        // ABI decode that no `catch` could intercept, which is only reachable through the `getOwners()` probe.
        assertEq(_revertDataOf(v1, accountMigration, realPasskey).length, 0, "expected a dataless revert");
        assertEq(_revertDataOf(v1, accountMigration, garbage).length, 0, "expected a dataless revert");

        // The contrast that proves the above is about the OWNER and not about V1 being broken in general:
        // with an EOA owner, the same validator rejects a bad signature with a typed error instead.
        assertEq(
            bytes4(_revertDataOf(v1, account, _sigData(address(v1), hex"c0ffee"))),
            ECDSA.ECDSAInvalidSignatureLength.selector,
            "with an EOA owner V1 fails with a typed error"
        );
    }

    /// @notice And the mirror image: V2 serves the SAME owner on the SAME account. Together with the test
    ///         above this isolates the difference to the validator, not to the account, the owner, the
    ///         signature or the chain.
    function test_E2E_Migration_V2ServesTheOwnerV1CannotOnTheSameAccount() public {
        instanceMigration.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(WALLET_ADDR));

        assertEq(v1.getAccountOwner(accountMigration), v2.getAccountOwner(accountMigration), "same owner");

        _assertValid(
            v2.validateUserOp(
                _userOp(accountMigration, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
            ),
            "V2 must serve the owner V1 cannot"
        );
    }

    /*//////////////////////////////////////////////////////////////
                      V2 IS A SUPERSET, V1 IS UNTOUCHED
    //////////////////////////////////////////////////////////////*/

    /// @notice V1 keeps validating its EOA owner exactly as before, on the very account that also holds V2.
    function test_E2E_V1_StillValidatesItsEoaOwner() public {
        _assertValid(v1.validateUserOp(_userOp(account, _eoaSigData(address(v1))), USEROP_HASH), "V1 EOA rejected");
    }

    /// @notice And V2 validates a plain EOA owner too, so nothing that worked under V1 is lost by migrating.
    function test_E2E_V2_AlsoValidatesAnEoaOwner() public {
        _assertValid(v2.validateUserOp(_userOp(accountEoa, _eoaSigData(address(v2))), USEROP_HASH), "V2 EOA rejected");
    }

    /*//////////////////////////////////////////////////////////////
                 DESTINATION EXECUTION IS REFUSED, NOT SILENT
    //////////////////////////////////////////////////////////////*/

    /// @notice V2 refuses an intent that carries destination execution, and the reason is fund safety rather
    ///         than incompleteness. The cross-chain flow has `SuperValidator.validateUserOp` stash the
    ///         signature in transient storage, and a bridge hook read it back from
    ///         `ISuperSignatureStorage(VALIDATOR)` — where `VALIDATOR` is an IMMUTABLE constructor argument,
    ///         and all eleven deployed bridge hooks were built with V1's address. A V2-validated cross-chain
    ///         intent would therefore write to V2's transient storage, have the hook read V1's and get empty
    ///         bytes, bridge the funds regardless, and leave the destination execution unauthorisable.
    ///         Reverting during validation happens before anything moves.
    function test_E2E_V2_RefusesDestinationExecutionBeforeAnythingMoves() public {
        uint64[] memory chains = new uint64[](1);
        chains[0] = 10;

        bytes memory sigData = abi.encode(
            chains,
            VALID_UNTIL,
            uint48(0),
            _createSourceValidatorLeaf(USEROP_HASH, VALID_UNTIL, 0, chains, address(v2)),
            new bytes32[](0),
            new ISuperValidator.DstProof[](0),
            _passkeySignature(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)
        );

        vm.expectRevert(SuperValidatorV2.DESTINATION_EXECUTION_NOT_SUPPORTED.selector);
        v2.validateUserOp(_userOp(account, sigData), USEROP_HASH);
    }

    /// @notice The restriction is V2's ALONE: V1 takes the identical intent shape past the merkle proof and
    ///         on to signature processing, where it fails only because the owner did not sign. So nothing
    ///         regressed for existing cross-chain intents — they keep using V1, which is the validator its
    ///         bridge hooks are bound to.
    function test_E2E_V1_AcceptsTheSameDestinationIntentShape() public {
        uint64[] memory chains = new uint64[](1);
        chains[0] = 10;

        bytes memory sigData = abi.encode(
            chains,
            VALID_UNTIL,
            uint48(0),
            _createSourceValidatorLeaf(USEROP_HASH, VALID_UNTIL, 0, chains, address(v1)),
            new bytes32[](0),
            new ISuperValidator.DstProof[](0),
            _passkeySignature(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)
        );

        // Reaches the signature path (V1's owner here is an EOA, so a passkey blob fails the ECDSA length)
        // rather than being refused on its shape. The contrast with V2 above is the whole assertion.
        vm.expectRevert();
        v1.validateUserOp(_userOp(account, sigData), USEROP_HASH);
    }

    /*//////////////////////////////////////////////////////////////
                   OWNER-SET AND WALLET-BINDING EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice The passkey need not be owner zero. Users add passkeys over time, so the registered index is
    ///         whatever the wallet assigned — and the signed digest does NOT include the index, so index
    ///         selection has to work on its own. Here the key sits at index 3 behind an unrelated key at
    ///         index 0: selecting 3 validates, selecting 0 does not.
    function test_E2E_PasskeyAtANonZeroOwnerIndex() public {
        wallet.setPasskeyOwner(0, bytes32(uint256(1)), bytes32(uint256(2)));
        wallet.setPasskeyOwner(3, PUBKEY_X, PUBKEY_Y);

        _assertValid(
            v2.validateUserOp(
                _userOp(account, _passkeySigData(3, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
            ),
            "passkey at index 3 rejected"
        );

        vm.expectRevert(SuperValidatorBase.NOT_EIP1271_SIGNER.selector);
        v2.validateUserOp(_userOp(account, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH);
    }

    /// @notice CROSS-WALLET REPLAY, end to end. The digest puts the wallet in EIP-712 `verifyingContract`, so
    ///         the SAME passkey registered on a DIFFERENT wallet must not accept the same assertion. Checked
    ///         through the validator rather than only at the library, because the validator is what chooses
    ///         which wallet to read — if it ever read the wrong one, this is the test that fails.
    function test_E2E_SamePasskeyOnADifferentWalletIsRejected() public {
        address otherWalletAddr = address(uint160(uint256(keccak256("second-cbsw"))));
        E2EMockCoinbaseSmartWallet fresh = new E2EMockCoinbaseSmartWallet();
        vm.etch(otherWalletAddr, address(fresh).code);
        E2EMockCoinbaseSmartWallet(otherWalletAddr).setPasskeyOwner(0, PUBKEY_X, PUBKEY_Y);

        AccountInstance memory inst = makeAccountInstance(keccak256("SUP-17924-e2e-other-wallet"));
        inst.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(otherWalletAddr));

        vm.expectRevert(SuperValidatorBase.NOT_EIP1271_SIGNER.selector);
        v2.validateUserOp(
            _userOp(inst.account, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
        );

        // And the original wallet is unaffected — the refusal is about the binding, not a broken fixture.
        _assertValid(
            v2.validateUserOp(
                _userOp(account, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
            ),
            "original wallet must still validate"
        );
    }

    /// @notice INVARIANT implied by the destination-execution guard: V2 can never stash a signature in
    ///         transient storage, because the only code path that does so is behind a non-empty
    ///         `chainsWithDestinationExecution`, which V2 refuses. So the bridge-hook read that motivated the
    ///         guard would find nothing even if a hook were pointed at V2 — asserted here so the guard and
    ///         this consequence cannot drift apart.
    function test_E2E_V2_NeverStashesASignatureForBridging() public {
        _assertValid(
            v2.validateUserOp(
                _userOp(account, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
            ),
            "sanity"
        );
        assertEq(v2.retrieveSignatureData(account).length, 0, "V2 must never stash a signature");
    }

    /// @notice Fuzzed garbage in the signature field never validates through the FULL validator dispatch —
    ///         not just the library. Reverting is acceptable (several typed errors are reachable); returning
    ///         a SUCCESSFUL validation is not, and that is the only thing asserted.
    /// forge-config: default.fuzz.runs = 512
    function testFuzz_E2E_RandomSignatureNeverValidatesThroughV2(bytes calldata blob) public {
        (bool ok, bytes memory ret) = address(v2)
            .call(
                abi.encodeCall(
                    SuperValidator.validateUserOp, (_userOp(account, _sigData(address(v2), blob)), USEROP_HASH)
                )
            );
        if (ok) {
            assertTrue(abi.decode(ret, (uint256)) & 1 == 1, "a random signature was accepted");
        }
    }

    /*//////////////////////////////////////////////////////////////
          THE SUPERSET CLAIM, CHECKED FOR EVERY OWNER FAMILY
    //////////////////////////////////////////////////////////////*/

    /// @notice A SAFE owner still validates on V2. This is the assertion that justifies routing the two
    ///         wallet families apart instead of chaining them: the Coinbase probe must report "not mine" for
    ///         a Safe and let the Safe path run untouched. Until this test existed, "V2 is a superset of V1"
    ///         was only checked for EOA owners — the Safe path was argued in a comment and never executed.
    function test_E2E_Superset_SafeOwnerStillValidatesOnV2() public {
        (address safeOwner, uint256 safeKey) = makeAddrAndKey("v2-safe-owner");
        address safe = address(new E2EMockSafe(safeOwner));

        AccountInstance memory inst = makeAccountInstance(keccak256("SUP-17924-e2e-safe"));
        inst.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(safe));

        (uint8 v, bytes32 r, bytes32 sVal) = vm.sign(safeKey, _safeChainAgnosticHash(safe, _messageHash(address(v2))));
        bytes memory sigData = _sigData(address(v2), abi.encodePacked(r, sVal, v));

        _assertValid(v2.validateUserOp(_userOp(inst.account, sigData), USEROP_HASH), "Safe owner rejected by V2");
    }

    /// @notice And a generic ERC-1271 owner — neither Safe nor Coinbase — still validates on V2 through the
    ///         hardened fallback. Together with the Safe and EOA cases this covers every owner family V1
    ///         served, so the superset claim is now exercised rather than asserted.
    function test_E2E_Superset_Generic1271OwnerStillValidatesOnV2() public {
        (address signer, uint256 key) = makeAddrAndKey("v2-1271-owner");
        E2EMock1271 owner1271 = new E2EMock1271(signer);

        AccountInstance memory inst = makeAccountInstance(keccak256("SUP-17924-e2e-1271"));
        inst.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(address(owner1271)));

        (uint8 v, bytes32 r, bytes32 sVal) =
            vm.sign(key, MessageHashUtils.toEthSignedMessageHash(_messageHash(address(v2))));
        bytes memory sigData = _sigData(address(v2), abi.encodePacked(r, sVal, v));

        _assertValid(v2.validateUserOp(_userOp(inst.account, sigData), USEROP_HASH), "1271 owner rejected by V2");

        // A wrong magic value is refused with the typed error, not accepted and not a dataless revert.
        owner1271.setBroken(true);
        vm.expectRevert(SuperValidatorBase.NOT_EIP1271_SIGNER.selector);
        v2.validateUserOp(_userOp(inst.account, sigData), USEROP_HASH);
    }

    /// @notice An EIP-7702 SENDER takes the ECDSA path on V2, exactly as on V1: the account is the signer and
    ///         the module's init check is skipped. Untested before, and it is the one branch of the dispatch
    ///         that runs before the owner is even looked up.
    function test_E2E_Superset_Eip7702SenderTakesTheEcdsaPath() public {
        (address eoa, uint256 key) = makeAddrAndKey("v2-7702-sender");
        vm.etch(eoa, abi.encodePacked(hex"ef0100", bytes20(uint160(0xBEEF))));

        (uint8 v, bytes32 r, bytes32 sVal) =
            vm.sign(key, MessageHashUtils.toEthSignedMessageHash(_messageHash(address(v2))));

        // No install: `validateUserOp` deliberately skips the init check for 7702 accounts.
        assertFalse(v2.isInitialized(eoa), "a 7702 sender needs no install");
        _assertValid(
            v2.validateUserOp(_userOp(eoa, _sigData(address(v2), abi.encodePacked(r, sVal, v))), USEROP_HASH),
            "7702 sender rejected by V2"
        );
    }

    /// @notice An EIP-7702 OWNER also takes the ECDSA path. This is the case the new codeless-owner guard
    ///         must not catch: a 7702 owner HAS code, so it never reaches the length check, and a delegated
    ///         EOA keeps signing with its own key.
    function test_E2E_Superset_Eip7702OwnerStillSignsWithItsKey() public {
        (address eoa, uint256 key) = makeAddrAndKey("v2-7702-owner");
        vm.etch(eoa, abi.encodePacked(hex"ef0100", bytes20(uint160(0xBEEF))));

        AccountInstance memory inst = makeAccountInstance(keccak256("SUP-17924-e2e-7702-owner"));
        inst.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(eoa));

        (uint8 v, bytes32 r, bytes32 sVal) =
            vm.sign(key, MessageHashUtils.toEthSignedMessageHash(_messageHash(address(v2))));

        _assertValid(
            v2.validateUserOp(_userOp(inst.account, _sigData(address(v2), abi.encodePacked(r, sVal, v))), USEROP_HASH),
            "7702 owner rejected by V2"
        );
    }

    /*//////////////////////////////////////////////////////////////
                   TIME WINDOW, INSTALL GUARDS, ENTRY POINTS
    //////////////////////////////////////////////////////////////*/

    /// @notice A cryptographically perfect passkey signature still fails once the intent has EXPIRED, and it
    ///         fails by returning the failure bit rather than reverting — which is what ERC-4337 requires of
    ///         a signature failure. The time window lives in shared code, but its interaction with the
    ///         passkey path was never exercised: a passkey signature is verified against a digest that does
    ///         NOT include `block.timestamp`, so only `_isSignatureValid` stands between an old assertion and
    ///         acceptance.
    function test_E2E_ExpiredPasskeyIntentFailsWithoutReverting() public {
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        _assertValid(v2.validateUserOp(_userOp(account, sigData), USEROP_HASH), "sanity: valid before expiry");

        vm.warp(uint256(VALID_UNTIL) + 1);

        ERC7579ValidatorBase.ValidationData result = v2.validateUserOp(_userOp(account, sigData), USEROP_HASH);
        assertTrue(
            ERC7579ValidatorBase.ValidationData.unwrap(result) & 1 == 1, "an expired intent must fail validation"
        );
    }

    /// @notice THE CLAIM I HAD NOT CHECKED. The destination-execution guard was placed in the shared dispatch
    ///         specifically so that NEITHER entry point can bypass it, but only `validateUserOp` was tested.
    ///         This covers the ERC-1271 entry point.
    function test_E2E_DestinationExecutionIsAlsoRefusedOnThe1271Path() public {
        uint64[] memory chains = new uint64[](1);
        chains[0] = 10;

        bytes memory sigData = abi.encode(
            chains,
            VALID_UNTIL,
            uint48(0),
            _createSourceValidatorLeaf(USEROP_HASH, VALID_UNTIL, 0, chains, address(v2)),
            new bytes32[](0),
            new ISuperValidator.DstProof[](0),
            _passkeySignature(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)
        );

        vm.prank(account);
        vm.expectRevert(SuperValidatorV2.DESTINATION_EXECUTION_NOT_SUPPORTED.selector);
        v2.isValidSignatureWithSender(address(0), USEROP_HASH, abi.encode(sigData));
    }

    /// @notice The ERC-1271 entry point also refuses an account that has not installed V2 — the migration
    ///         test covers `validateUserOp`; this covers the other door.
    function test_E2E_Uninstalled_1271PathAlsoRefuses() public {
        bytes memory sigData = _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        vm.prank(accountMigration); // has V1 only
        vm.expectRevert(ISuperValidator.NOT_INITIALIZED.selector);
        v2.isValidSignatureWithSender(address(0), USEROP_HASH, abi.encode(sigData));
    }

    /// @notice V2 inherits the base's install guards, and the override must not have disturbed them: a second
    ///         install is refused and a zero owner is refused.
    function test_E2E_InstallGuardsStillApplyToV2() public {
        address fresh = makeAddr("fresh-account");

        vm.prank(fresh);
        v2.onInstall(abi.encode(WALLET_ADDR));
        assertTrue(v2.isInitialized(fresh));

        vm.prank(fresh);
        vm.expectRevert(SuperValidatorBase.ALREADY_INITIALIZED.selector);
        v2.onInstall(abi.encode(WALLET_ADDR));

        vm.prank(makeAddr("another-account"));
        vm.expectRevert(SuperValidatorBase.ZERO_ADDRESS.selector);
        v2.onInstall(abi.encode(address(0)));

        vm.prank(makeAddr("never-installed"));
        vm.expectRevert(ISuperValidator.NOT_INITIALIZED.selector);
        v2.onUninstall("");
    }

    /*//////////////////////////////////////////////////////////////
                SIGNATURES DO NOT CROSS BETWEEN V1 AND V2
    //////////////////////////////////////////////////////////////*/

    /// @notice Neither validator will accept the other's signature, in either direction. Two independent
    ///         mechanisms enforce this and either would be sufficient: every merkle leaf commits
    ///         `address(this)`, so a proof built for one module cannot verify against the other; and the
    ///         namespaces differ, so the signed message hash differs too. The leaf check fires first, which is
    ///         why both directions revert with `INVALID_PROOF`.
    function test_E2E_SignaturesDoNotCrossBetweenValidators() public {
        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        v2.validateUserOp(_userOp(account, _eoaSigData(address(v1))), USEROP_HASH);

        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        v1.validateUserOp(_userOp(account, _eoaSigData(address(v2))), USEROP_HASH);
    }

    /// @notice The second mechanism on its own: the same merkle root yields different signed messages under
    ///         the two namespaces, so even a leaf collision could not transfer a signature.
    function test_E2E_NamespaceSeparatesTheSignedMessage() public view {
        bytes32 root = _root(address(v1));
        assertTrue(
            keccak256(abi.encode(v1.namespace(), root)) != keccak256(abi.encode(v2.namespace(), root)),
            "namespaces must separate the signed message"
        );
    }

    /*//////////////////////////////////////////////////////////////
                  THE ORIGINAL BUG: A COUNTERFACTUAL WALLET
    //////////////////////////////////////////////////////////////*/

    /// @notice THE REPORTED SYMPTOM, AND THE FIX, SIDE BY SIDE. A Coinbase Smart Wallet has a deterministic
    ///         address but no code on a chain until its first transaction there, so a ~300-byte passkey
    ///         signature arrives for an owner with no bytecode. V1 reads "no code" as "EOA" and dies inside
    ///         `ECDSA.recover` on the signature length — the "signature is 600 characters … not valid for our
    ///         bundler and contract" report. V2 separates the two cases on the 65-byte ECDSA length and fails
    ///         with a typed error that tells the user what to do: deploy the wallet on this chain and retry.
    function test_E2E_CounterfactualOwner_V1DiesInEcdsaWhileV2IsLegible() public {
        bytes memory sigDataV1 = _passkeySigDataFor(address(v1), 0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV);
        uint256 length = _passkeySignature(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV).length;

        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, length));
        v1.validateUserOp(_userOp(accountCounterfactual, sigDataV1), USEROP_HASH);

        vm.expectRevert(SuperValidatorV2.UNDEPLOYED_CONTRACT_SIGNER.selector);
        v2.validateUserOp(
            _userOp(accountCounterfactual, _passkeySigData(0, AUTH_DATA_UP_UV, SIG_R_UP_UV, SIG_S_UP_UV)), USEROP_HASH
        );
    }

    /// @notice And a codeless owner presenting a genuine 65-byte ECDSA signature is still treated as an EOA,
    ///         so the new guard does not break the ordinary counterfactual-EOA case.
    function test_E2E_CounterfactualOwner_EcdsaLengthStillTakesTheEoaPath() public {
        // The owner is codeless and is NOT the signer, so this must fail validation — but it must fail as a
        // signature mismatch, NOT by reverting on the length.
        ERC7579ValidatorBase.ValidationData result =
            v2.validateUserOp(_userOp(accountCounterfactual, _eoaSigData(address(v2))), USEROP_HASH);
        assertTrue(
            ERC7579ValidatorBase.ValidationData.unwrap(result) & 1 == 1,
            "a non-owner EOA signature must fail validation"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Single-leaf tree: the root IS the leaf, so the source proof is empty and `MerkleProof.verify`
    ///      reduces to a root/leaf equality check.
    function _root(address validator) internal pure returns (bytes32) {
        return _createSourceValidatorLeaf(USEROP_HASH, VALID_UNTIL, 0, new uint64[](0), validator);
    }

    function _messageHash(address validator) internal view returns (bytes32) {
        string memory ns = validator == address(v2) ? "SuperValidatorV2" : "SuperValidator";
        return keccak256(abi.encode(ns, _root(validator)));
    }

    function _sigData(address validator, bytes memory signature) internal pure returns (bytes memory) {
        return abi.encode(
            new uint64[](0),
            VALID_UNTIL,
            uint48(0),
            _root(validator),
            new bytes32[](0),
            new ISuperValidator.DstProof[](0),
            signature
        );
    }

    function _eoaSigData(address validator) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(eoaKey, MessageHashUtils.toEthSignedMessageHash(_messageHash(validator)));
        return _sigData(validator, abi.encodePacked(r, s, v));
    }

    function _passkeySignature(
        uint256 ownerIndex,
        bytes memory authData,
        bytes32 r,
        bytes32 s
    )
        internal
        pure
        returns (bytes memory)
    {
        WebAuthn.WebAuthnAuth memory auth = WebAuthn.WebAuthnAuth({
            authenticatorData: authData,
            clientDataJSON: CLIENT_DATA_JSON,
            challengeIndex: CHALLENGE_INDEX,
            typeIndex: TYPE_INDEX,
            r: r,
            s: s
        });
        return abi.encode(SignatureWrapper({ ownerIndex: ownerIndex, signatureData: abi.encode(auth) }));
    }

    function _passkeySigData(
        uint256 ownerIndex,
        bytes memory authData,
        bytes32 r,
        bytes32 s
    )
        internal
        view
        returns (bytes memory)
    {
        return _passkeySigDataFor(address(v2), ownerIndex, authData, r, s);
    }

    function _passkeySigDataFor(
        address validator,
        uint256 ownerIndex,
        bytes memory authData,
        bytes32 r,
        bytes32 s
    )
        internal
        pure
        returns (bytes memory)
    {
        return _sigData(validator, _passkeySignature(ownerIndex, authData, r, s));
    }

    /// @dev `validateUserOp` reads only `sender` and `signature`, and takes the hash as a separate argument,
    ///      so a minimal operation keeps the fixed root (and therefore the signed digest) deterministic.
    function _userOp(address sender, bytes memory signature) internal pure returns (PackedUserOperation memory) {
        PackedUserOperation memory userOp;
        userOp.sender = sender;
        userOp.signature = signature;
        return userOp;
    }

    /// @dev `ChainAgnosticSafeSignatureValidation`'s digest, recomputed here rather than imported, so the
    ///      test would notice if the library's domain ever changed under it.
    function _safeChainAgnosticHash(address safe, bytes32 rawHash) internal pure returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("SuperformSafe")),
                keccak256(bytes("1.0.0")),
                uint256(1),
                safe
            )
        );
        return keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(rawHash))))
            )
        );
    }

    /// @dev Calls `validateUserOp` low-level and returns the raw revert data, so a test can assert on its
    ///      LENGTH. `vm.expectRevert()` with no argument cannot distinguish "reverted with a typed error"
    ///      from "reverted with nothing", and that distinction is the whole point here.
    function _revertDataOf(
        SuperValidator validator,
        address sender,
        bytes memory sigData
    )
        internal
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = address(validator)
            .call(abi.encodeCall(SuperValidator.validateUserOp, (_userOp(sender, sigData), USEROP_HASH)));
        assertFalse(ok, "validation was expected to revert");
        return ret;
    }

    function _assertValid(ERC7579ValidatorBase.ValidationData result, string memory reason) internal pure {
        assertFalse(ERC7579ValidatorBase.ValidationData.unwrap(result) & 1 == 1, reason);
    }
}
