// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WebAuthn } from "solady/utils/WebAuthn.sol";

// Superform
import { SuperValidatorV2 } from "../../../src/validators/SuperValidatorV2.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../../src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import {
    ChainAgnosticCoinbaseSmartWalletValidation
} from "../../../src/libraries/ChainAgnosticCoinbaseSmartWalletValidation.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";

/// @notice The live Coinbase Smart Wallet factory's account-creation surface.
interface ICoinbaseSmartWalletFactory {
    function createAccount(bytes[] calldata owners, uint256 nonce) external payable returns (address);
    function getAddress(bytes[] calldata owners, uint256 nonce) external view returns (address);
    function implementation() external view returns (address);
}

/// @title SuperValidatorV2RealBaseSmartWalletFlowTest
/// @author Superform Labs
/// @notice THE REAL THING: a Base Smart Wallet deployed by the LIVE Coinbase factory, owning a real ERC-7579
///         account, authorising a real `SuperExecutor` flow that deposits real USDC into a real ERC-4626
///         vault on Base — with a real secp256r1 passkey assertion as the only signature.
/// @dev Everything on the critical path is production code or production state. Nothing here is a mock:
///         - the wallet comes from `0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a`
///           (`createAccount`), so its `ownerAtIndex` return shapes, its ERC-1271, and above all its
///           PERMISSIVE FALLBACK are the real implementation's rather than my approximation of them;
///         - USDC is `0x8335…2913` and the vault is Moonwell Flagship USDC (`0xc125…A2Ca`, `mwUSDC`), both
///           verified live at the pinned block;
///         - the user operation goes through the real EntryPoint, so `validateUserOp` is called by the
///           EntryPoint and the hooks run inside the account.
/// @dev WHY THIS EXISTS ON TOP OF THE MOCK SUITE. Every mock in `SuperValidatorV2E2E.t.sol` encodes an
///         assumption about the wallet, and two of this feature's four real bugs were assumption failures a
///         mock had hidden: the signature envelope layout, and the permissive fallback that makes `try`-shaped
///         probes revert uncatchably. A test against the deployed implementation is the only thing that
///         retires those assumptions.
contract SuperValidatorV2RealBaseSmartWalletFlowTest is
    Helpers,
    RhinestoneModuleKit,
    InternalHelpers,
    MerkleTreeHelper
{
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                             LIVE BASE STATE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant BASE_FORK_BLOCK = 51_778_000;

    ICoinbaseSmartWalletFactory internal constant CBSW_FACTORY =
        ICoinbaseSmartWalletFactory(0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a);
    address internal constant CBSW_IMPLEMENTATION = 0x000100abaad02f1cfC8Bbe32bD5a564817339E72;

    address internal constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    /// @dev Moonwell Flagship USDC, a MetaMorpho ERC-4626 whose asset is USDC. Verified live at the block.
    address internal constant MOONWELL_FLAGSHIP_USDC = 0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca;

    uint256 internal constant DEPOSIT_AMOUNT = 1000e6;

    /*//////////////////////////////////////////////////////////////
                           THE PASSKEY FIXTURE
    //////////////////////////////////////////////////////////////*/

    /// @dev The same real secp256r1 keypair as the mock suite. The wallet below is created with this key as
    ///      its only owner, so the owner set is genuinely the factory's and the key is genuinely ours.
    bytes32 internal constant PUBKEY_X = 0x6ee581a0aa61e6231f95283949e8e547e9f739d8cd33c2da167212476f88b3ca;
    bytes32 internal constant PUBKEY_Y = 0xb62dba6b3032304c71e0cda7bca138609d825bbbb26b7ef655f87b78a67dde1d;

    bytes internal constant AUTHENTICATOR_DATA =
        hex"f198086b2db17256731bc456673b96bcef23f51d1fbacdd7c4379ef65465572f0500000000";

    /// @dev The digest the passkey actually signed for THIS flow. It is a function of the real user
    ///      operation hash — which commits the account, the executor, the hook addresses and the deposit
    ///      calldata — so it is pinned, and `test_Precondition_FlowDigestIsStable` turns any drift in the
    ///      flow into one legible failure instead of an inscrutable signature rejection. No FFI is used (the
    ///      CI test job has no Python), so the fixture is generated out of band and checked in, exactly like
    ///      the ones in the mock suite.
    bytes32 internal constant FLOW_DIGEST = 0x0d9d2f79af3ad6734479520e8acfb0bf51fc623f695fbb1c4f4b661ff54a29b0;
    string internal constant CLIENT_DATA_JSON =
        "{\"type\":\"webauthn.get\",\"challenge\":\"DZ0vea861nNEeVIOis-wv1H8Yj9pX7scT0tmH_VKKbA\",\"origin\":\"https://keys.coinbase.com\",\"crossOrigin\":false}";
    uint256 internal constant CHALLENGE_INDEX = 23;
    uint256 internal constant TYPE_INDEX = 1;
    bytes32 internal constant SIG_R = 0xda4cdaeb2d9ac541b973bffbea6813e539d35c6ba1b1c5c41e1593fcb14f9dec;
    bytes32 internal constant SIG_S = 0x55e20cefefc0778fb2dc0ceabafd1ff9263faf772e359b4c65d74fdbddeeb567;

    /// @dev The redeem leg's own digest and assertion. A second signature is unavoidable: the redeem user
    ///      operation has a different nonce and different calldata, so a different hash, root and digest.
    ///      That is the honest shape of the flow — one passkey authorises one intent.
    bytes32 internal constant REDEEM_DIGEST = 0xcd1f3bb4fa5420b2e10fcbade706187b3e4b8aac1a015305636057bbd475c3dd;
    string internal constant REDEEM_CLIENT_DATA_JSON =
        "{\"type\":\"webauthn.get\",\"challenge\":\"zR87tPpUILLhD8ut5wYYez5LiqwaAVMFY2BXu9R1w90\",\"origin\":\"https://keys.coinbase.com\",\"crossOrigin\":false}";
    bytes32 internal constant REDEEM_SIG_R = 0xda4cdaeb2d9ac541b973bffbea6813e539d35c6ba1b1c5c41e1593fcb14f9dec;
    bytes32 internal constant REDEEM_SIG_S = 0x0cff88a55482a90e64b983a552bb559ffbe2b6f3fa6b2e946b6b66dd972165cb;

    struct SignatureWrapper {
        uint256 ownerIndex;
        bytes signatureData;
    }

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    address internal realWallet;
    SuperValidatorV2 internal v2;
    ISuperExecutor internal superExecutor;
    address internal ledgerConfig;
    address internal yieldSourceOracle;
    ISuperLedger internal ledger;
    address internal approveHook;
    address internal depositHook;
    address internal redeemHook;

    AccountInstance internal instance;
    address internal account;

    uint48 internal constant VALID_UNTIL = 2_000_000_000;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);

        // --- the REAL wallet, from the REAL factory, owned by our passkey ---
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(PUBKEY_X, PUBKEY_Y);
        realWallet = CBSW_FACTORY.createAccount(owners, 0);

        // --- real Superform core ---
        ledgerConfig = address(new SuperLedgerConfiguration());
        yieldSourceOracle = address(new ERC4626YieldSourceOracle(ledgerConfig));
        superExecutor = ISuperExecutor(new SuperExecutor(ledgerConfig));

        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutor);
        ledger = ISuperLedger(address(new SuperLedger(ledgerConfig, allowedExecutors)));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: 0,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY));
        ISuperLedgerConfiguration(ledgerConfig).setYieldSourceOracles(salts, configs);

        approveHook = address(new ApproveERC20Hook());
        depositHook = address(new Deposit4626VaultHook());

        v2 = new SuperValidatorV2();

        // --- the account, owned by the real Base Smart Wallet ---
        instance = makeAccountInstance(keccak256("SUP-17924-real-base-smart-wallet"));
        account = instance.account;
        instance.installModule(MODULE_TYPE_EXECUTOR, address(superExecutor), "");
        instance.installModule(MODULE_TYPE_VALIDATOR, address(v2), abi.encode(realWallet));

        deal(BASE_USDC, account, DEPOSIT_AMOUNT);

        // DEPLOY ORDER IS LOAD-BEARING: ANYTHING NEW GOES HERE, AT THE END.
        // The signed digest derives from the real user operation hash, which commits the account, the
        // executor and the hook addresses. Those are all CREATE addresses keyed on this contract's nonce —
        // and `makeAccountInstance` itself deploys, so even a contract created BEFORE it (but after the
        // modules) moves the account address and therefore every pinned fixture. `redeemHook` is created
        // last for exactly that reason. `test_Precondition_FlowDigestIsStable` is what caught the first
        // attempt at this, which placed it two lines earlier.
        redeemHook = address(new Redeem4626VaultHook());
    }

    /*//////////////////////////////////////////////////////////////
                      THE LIVE WALLET IS WHAT WE THINK
    //////////////////////////////////////////////////////////////*/

    /// @notice The factory really produced a wallet, with our passkey as owner zero, in the shapes the
    ///         library expects — read off the deployed implementation rather than a mock.
    function test_RealWallet_OwnerSetMatchesTheLibrarysExpectations() public view {
        assertEq(CBSW_FACTORY.implementation(), CBSW_IMPLEMENTATION, "unexpected factory implementation");
        assertGt(realWallet.code.length, 0, "wallet was not deployed");

        (bool ok, bytes memory ret) = realWallet.staticcall(abi.encodeWithSignature("nextOwnerIndex()"));
        assertTrue(ok && ret.length == 32, "real wallet did not answer nextOwnerIndex");
        assertEq(abi.decode(ret, (uint256)), 1, "expected exactly one owner");

        (ok, ret) = realWallet.staticcall(abi.encodeWithSignature("ownerAtIndex(uint256)", 0));
        assertTrue(ok, "ownerAtIndex failed");
        bytes memory owner = abi.decode(ret, (bytes));
        assertEq(owner.length, 64, "a passkey owner must be 64 bytes");
        assertEq(owner, abi.encode(PUBKEY_X, PUBKEY_Y), "owner zero is not our passkey");

        assertTrue(
            ChainAgnosticCoinbaseSmartWalletValidation.isCoinbaseSmartWallet(realWallet),
            "the detector must recognise a real wallet"
        );
    }

    /// @notice THE ASSUMPTION THAT BIT TWICE, confirmed against the deployed implementation: the real wallet
    ///         answers an unknown selector from a permissive fallback with EMPTY returndata rather than
    ///         reverting. That is what makes `try target.f() returns (T)` revert uncatchably in the caller's
    ///         frame, and therefore why the probes are low-level `staticcall`s and why `SuperValidatorV2`
    ///         routes the Safe and Coinbase families apart instead of chaining them.
    function test_RealWallet_PermissiveFallbackReturnsEmptyData() public view {
        (bool ok, bytes memory ret) = realWallet.staticcall(abi.encodeWithSignature("getOwners()"));
        assertTrue(ok, "the real wallet's fallback should NOT revert");
        assertEq(ret.length, 0, "the real wallet's fallback should return empty data");
    }

    /*//////////////////////////////////////////////////////////////
                          THE REAL FLOW
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds the real user operation for the deposit flow and returns it alongside the digest the
    ///      passkey must sign.
    function _buildFlow() internal returns (UserOpData memory userOpData, bytes32 root, bytes32 digest) {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = depositHook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(BASE_USDC, MOONWELL_FLAGSHIP_USDC, DEPOSIT_AMOUNT, false);
        hooksData[1] = _createDeposit4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            MOONWELL_FLAGSHIP_USDC,
            DEPOSIT_AMOUNT,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(v2));
        _cachedUserOpHash = userOpData.userOpHash;

        root = _createSourceValidatorLeaf(userOpData.userOpHash, VALID_UNTIL, 0, new uint64[](0), address(v2));
        digest = ChainAgnosticCoinbaseSmartWalletValidation.chainAgnosticDigest(
            realWallet, keccak256(abi.encode(v2.namespace(), root))
        );
    }

    /// @notice Pins the digest this flow produces. If the account salt, the module deployment order, the hook
    ///         set, the deposit amount or the pinned block changes, the real user operation hash moves and the
    ///         checked-in passkey assertion stops matching — this fails first, and says so.
    function test_Precondition_FlowDigestIsStable() public {
        (,, bytes32 digest) = _buildFlow();
        assertEq(digest, FLOW_DIGEST, "the flow moved; regenerate the passkey fixture");
    }

    /// @notice THE WHOLE FEATURE, FOR REAL. A passkey assertion from a Base Smart Wallet created by the live
    ///         Coinbase factory is the only authorisation for a user operation that runs through the real
    ///         EntryPoint, executes `SuperExecutor` with an approve + ERC-4626 deposit, and moves real USDC
    ///         into a real Moonwell vault. No mock anywhere on the path.
    function test_RealFlow_PasskeyAuthorisesAUsdcDepositIntoARealVault() public {
        (UserOpData memory userOpData,,) = _buildFlow();
        userOpData.userOp.signature = _flowSignature();

        uint256 usdcBefore = IERC20(BASE_USDC).balanceOf(account);
        uint256 sharesBefore = IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account);
        assertEq(usdcBefore, DEPOSIT_AMOUNT, "account should start funded");
        assertEq(sharesBefore, 0, "account should start with no shares");

        executeOp(userOpData);

        assertEq(IERC20(BASE_USDC).balanceOf(account), 0, "USDC was not spent");
        uint256 shares = IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account);
        assertGt(shares, 0, "no vault shares were minted");

        // The shares are worth roughly what went in — a sanity check that the deposit really happened against
        // the live vault's exchange rate rather than some no-op that merely moved tokens.
        uint256 redeemable = IERC4626(MOONWELL_FLAGSHIP_USDC).convertToAssets(shares);
        assertApproxEqRel(redeemable, DEPOSIT_AMOUNT, 0.01e18, "shares do not represent the deposit");
    }

    /// @notice And the accounting engine saw it: `SuperLedger` recorded the inflow for the real yield source,
    ///         so the passkey-authorised flow is a first-class Superform deposit and not just a token move.
    function test_RealFlow_LedgerRecordsTheInflow() public {
        (UserOpData memory userOpData,,) = _buildFlow();
        userOpData.userOp.signature = _flowSignature();
        executeOp(userOpData);

        uint256 shares = IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account);
        assertGt(shares, 0, "no shares minted");

        assertEq(
            SuperLedger(address(ledger)).usersAccumulatorShares(account, MOONWELL_FLAGSHIP_USDC),
            shares,
            "the ledger's share accumulator does not match the minted shares"
        );
        assertGt(
            SuperLedger(address(ledger)).usersAccumulatorCostBasis(account, MOONWELL_FLAGSHIP_USDC),
            0,
            "the ledger did not record a cost basis for the deposit"
        );
    }

    /// @notice THE NEGATIVE CONTROL, and the reason the positive result means something. The identical flow
    ///         with the passkey's `s` replaced by `n - s` — an equally valid curve signature, high-s — is
    ///         refused, so the EntryPoint never executes and no USDC moves. Without this, a validator that
    ///         accepted everything would pass the test above.
    function test_RealFlow_HighSPasskeyIsRefusedAndNothingMoves() public {
        (UserOpData memory userOpData,,) = _buildFlow();
        userOpData.userOp.signature = _signatureWith(SIG_R, _negateS(SIG_S));

        vm.expectRevert();
        executeOp(userOpData);

        assertEq(IERC20(BASE_USDC).balanceOf(account), DEPOSIT_AMOUNT, "USDC moved on a refused signature");
        assertEq(IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account), 0, "shares minted on a refused signature");
    }

    /// @notice REVOCATION, against the live implementation's owner set rather than a mock that merely returns
    ///         empty bytes. Two real behaviours, and the first one is a detail no mock had modelled:
    ///         `removeOwnerAtIndex` REVERTS `LastOwner()` when only one owner remains, so a user cannot
    ///         accidentally strand their wallet — and therefore cannot accidentally strand their Superform
    ///         validator either. Removing the sole owner requires the explicit `removeLastOwner`, and once it
    ///         is gone the previously-valid passkey assertion no longer authorises anything.
    function test_RealFlow_RevokingThePasskeyOnTheRealWalletStopsTheFlow() public {
        (UserOpData memory userOpData,,) = _buildFlow();
        userOpData.userOp.signature = _flowSignature();

        bytes memory ownerBytes = abi.encode(PUBKEY_X, PUBKEY_Y);

        // 1. The sole owner is protected by the real implementation.
        vm.prank(realWallet);
        (bool ok, bytes memory ret) =
            realWallet.call(abi.encodeWithSignature("removeOwnerAtIndex(uint256,bytes)", 0, ownerBytes));
        assertFalse(ok, "removing the sole owner should be refused by the wallet");
        assertEq(bytes4(ret), bytes4(keccak256("LastOwner()")), "expected the wallet's LastOwner() guard");

        // The flow still works while the owner is still registered — the guard above changed nothing.
        assertTrue(
            ChainAgnosticCoinbaseSmartWalletValidation.isCoinbaseSmartWallet(realWallet), "wallet still a wallet"
        );

        // 2. Explicit removal of the last owner, which the implementation does allow.
        vm.prank(realWallet);
        (ok,) = realWallet.call(abi.encodeWithSignature("removeLastOwner(uint256,bytes)", 0, ownerBytes));
        assertTrue(ok, "removeLastOwner should succeed");

        // 3. The same, previously-valid assertion now authorises nothing, and no funds move.
        vm.expectRevert();
        executeOp(userOpData);

        assertEq(IERC20(BASE_USDC).balanceOf(account), DEPOSIT_AMOUNT, "USDC moved after revocation");
        assertEq(IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account), 0, "shares minted after revocation");
    }

    /// @dev Builds the redeem leg. Must be called AFTER the deposit has executed, because the user
    ///      operation nonce (and therefore the hash, the root and the digest) depends on it.
    function _buildRedeemFlow(uint256 shares) internal returns (UserOpData memory userOpData, bytes32 digest) {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = redeemHook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            MOONWELL_FLAGSHIP_USDC,
            account,
            shares,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOpsWithValidator(instance, superExecutor, abi.encode(entry), address(v2));
        _cachedUserOpHash = userOpData.userOpHash;

        bytes32 root = _createSourceValidatorLeaf(userOpData.userOpHash, VALID_UNTIL, 0, new uint64[](0), address(v2));
        digest = ChainAgnosticCoinbaseSmartWalletValidation.chainAgnosticDigest(
            realWallet, keccak256(abi.encode(v2.namespace(), root))
        );
    }

    /// @notice THE ROUND TRIP, all of it real: deposit real USDC into the real Moonwell vault under one
    ///         passkey assertion, then redeem the real shares back under a second one. The redeem leg is what
    ///         exercises `SuperLedger`'s OUTFLOW path — cost-basis consumption and fee calculation against a
    ///         live vault's exchange rate — which the deposit alone never touches.
    function test_RealFlow_PasskeyRoundTripsDepositAndRedeem() public {
        (UserOpData memory depositOp,,) = _buildFlow();
        depositOp.userOp.signature = _flowSignature();
        executeOp(depositOp);

        uint256 shares = IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account);
        assertGt(shares, 0, "deposit leg did not mint shares");
        assertEq(IERC20(BASE_USDC).balanceOf(account), 0, "deposit leg did not spend the USDC");

        (UserOpData memory redeemOp, bytes32 redeemDigest) = _buildRedeemFlow(shares);
        assertEq(redeemDigest, REDEEM_DIGEST, "the redeem leg moved; regenerate its passkey fixture");
        redeemOp.userOp.signature = _redeemSignature();
        executeOp(redeemOp);

        assertEq(IERC4626(MOONWELL_FLAGSHIP_USDC).balanceOf(account), 0, "shares were not redeemed");
        uint256 usdcBack = IERC20(BASE_USDC).balanceOf(account);
        assertApproxEqRel(usdcBack, DEPOSIT_AMOUNT, 0.01e18, "did not get the USDC back");

        // The ledger consumed the cost basis it recorded on the way in.
        assertEq(
            SuperLedger(address(ledger)).usersAccumulatorShares(account, MOONWELL_FLAGSHIP_USDC),
            0,
            "the ledger still thinks shares are held"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _flowSignature() internal view returns (bytes memory) {
        return _signatureWith(SIG_R, SIG_S);
    }

    function _redeemSignature() internal view returns (bytes memory) {
        return _signatureWithClientData(REDEEM_CLIENT_DATA_JSON, REDEEM_SIG_R, REDEEM_SIG_S);
    }

    /// @dev Assembles the full merkle signature payload: a single-leaf tree (root == leaf, empty proof) whose
    ///      signature field is the wallet's own `SignatureWrapper` envelope, struct-encoded as the wallet
    ///      emits it.
    function _signatureWith(bytes32 r, bytes32 sVal) internal view returns (bytes memory) {
        return _signatureWithClientData(CLIENT_DATA_JSON, r, sVal);
    }

    function _signatureWithClientData(
        string memory clientData,
        bytes32 r,
        bytes32 sVal
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory inner = abi.encode(
            WebAuthn.WebAuthnAuth({
                authenticatorData: AUTHENTICATOR_DATA,
                clientDataJSON: clientData,
                challengeIndex: CHALLENGE_INDEX,
                typeIndex: TYPE_INDEX,
                r: r,
                s: sVal
            })
        );
        bytes memory wrapper = abi.encode(SignatureWrapper({ ownerIndex: 0, signatureData: inner }));

        return abi.encode(
            new uint64[](0),
            VALID_UNTIL,
            uint48(0),
            _createSourceValidatorLeaf(_currentUserOpHash(), VALID_UNTIL, 0, new uint64[](0), address(v2)),
            new bytes32[](0),
            new ISuperValidator.DstProof[](0),
            wrapper
        );
    }

    /// @dev The pinned flow's user operation hash, recovered from the pinned digest's own derivation chain.
    ///      Stored during `_buildFlow` so `_signatureWith` does not have to rebuild the operation.
    bytes32 internal _cachedUserOpHash;

    function _currentUserOpHash() internal view returns (bytes32) {
        require(_cachedUserOpHash != bytes32(0), "build the flow first");
        return _cachedUserOpHash;
    }

    /// @dev `n - s` for the secp256r1 group order: the malleable twin of a valid signature.
    function _negateS(bytes32 sVal) internal pure returns (bytes32) {
        uint256 order = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551;
        return bytes32(order - uint256(sVal));
    }
}
