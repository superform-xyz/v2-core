// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { SuperVaultAcrossCapBridgeHook } from "../../../src/hooks/bridges/across/SuperVaultAcrossCapBridgeHook.sol";
import { SuperVaultCapBridgeCommon } from "../../../src/hooks/bridges/SuperVaultCapBridgeCommon.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { MockLedger, MockLedgerConfiguration } from "../../mocks/MockLedger.sol";
import { ExecutingERC7579Account } from "./AcrossDestinationExecutionE2E.t.sol";
import {
    MockCapGuard,
    MockPositionRegistry,
    MockGovernorAddressBook,
    CapMessageLib
} from "../hooks/bridges/CapBridgeTestUtils.sol";

/// @dev Hub-side signature storage stub for the cap hook's parent (build-time append only).
contract MockHubSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @title CrossChainSuperVaultDestinationE2E
/// @notice The "full remote lifecycle" leg of the PR #336 review test matrix, with the REAL
///         destination stack — no simulation shortcuts:
///         AcrossV3Adapter -> SuperDestinationExecutor -> SuperDestinationValidator (real EOA-owner
///         signature over the real destination merkle leaf) -> real ApproveERC20Hook +
///         Deposit4626VaultHook executed ON the hub-controlled account -> ERC4626 SHARES MINTED TO
///         THE ACCOUNT. The message delivered is byte-identical to the typed destination action
///         the SuperVaultAcrossCapBridgeHook validated hub-side, closing the loop the review
///         flagged: the cap-validated action IS the action that creates the position, and a
///         mutated action (different vault) fails BOTH hub-side (leaf/preExecute) and
///         destination-side (signature).
contract CrossChainSuperVaultDestinationE2E is Test {
    uint256 internal constant AMOUNT = 1000e6;

    // Destination stack (real contracts)
    SuperDestinationExecutor internal executor;
    SuperDestinationValidator internal validator;
    AcrossV3Adapter internal adapter;
    ExecutingERC7579Account internal account;
    ApproveERC20Hook internal approveHook;
    Deposit4626VaultHook internal depositHook;
    MockERC20 internal token;
    Mock4626Vault internal vault;
    MockLedger internal ledger;
    MockLedgerConfiguration internal ledgerConfig;

    // Hub-side cap stack
    SuperVaultAcrossCapBridgeHook internal capHook;
    MockCapGuard internal capGuard;
    MockPositionRegistry internal positionRegistry;
    MockGovernorAddressBook internal governor;
    MockHubSignatureStorage internal hubValidator;

    address internal spokePool = makeAddr("spokePool");
    address internal owner;
    uint256 internal ownerPk;
    uint64 internal chainId;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("accountOwner");
        chainId = uint64(block.chainid);

        // Destination stack.
        token = new MockERC20("USD Coin", "USDC", 6);
        vault = new Mock4626Vault(address(token), "Dest SuperVault", "dSV");
        ledger = new MockLedger();
        validator = new SuperDestinationValidator();
        approveHook = new ApproveERC20Hook();
        depositHook = new Deposit4626VaultHook();

        // Ledger config needs a non-zero manager (executor accounting for the INFLOW deposit hook).
        ledgerConfig =
            new MockLedgerConfiguration(address(ledger), makeAddr("feeRecipient"), address(vault), 0, makeAddr("mgr"));
        executor = new SuperDestinationExecutor(address(ledgerConfig), address(validator));
        adapter = new AcrossV3Adapter(spokePool, address(executor));

        // The hub-controlled destination account: same address as the hub strategy account, with
        // the REAL validator (EOA owner) and the destination executor installed.
        account = new ExecutingERC7579Account();
        account.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(owner));
        account.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));

        // Hub-side cap stack: the same governance policy the periphery cap guard would serve.
        capGuard = new MockCapGuard();
        positionRegistry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(positionRegistry));
        hubValidator = new MockHubSignatureStorage();
        capHook = new SuperVaultAcrossCapBridgeHook(spokePool, address(hubValidator), address(governor));
        capHook.setExecutionContext(address(account));

        capGuard.setApprovedAdapter(chainId, address(adapter), true);
        capGuard.setDestinationHooks(chainId, address(approveHook), address(depositHook));
    }

    /*//////////////////////////////////////////////////////////////
                        FULL REMOTE LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice RR1/RR5: bridge message -> adapter -> executor -> validated signature -> real
    ///         approve+deposit on the account -> vault SHARES owned by the hub-controlled account
    ///         (not merely tokens delivered to an address) — and the exact same message passed the
    ///         hub-side cap hook first.
    function test_E2E_CapValidatedDepositMintsSharesToAccount() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _intent();

        // 1. HUB SIDE: the cap hook validates this exact destination action — economic vault, not
        //    the transport adapter — and mints the reservation for it.
        bytes memory message5 = abi.encode(bytes(""), executorCalldata, address(account), dstTokens, intentAmounts);
        vm.prank(address(account));
        capHook.preExecute(address(0), address(account), _hubData(message5));
        assertEq(positionRegistry.lastVault(), address(vault), "cap must reserve against the economic vault");
        assertEq(positionRegistry.bridgedOut(address(account)), AMOUNT, "in-flight reservation not recorded");

        // 2. OWNER SIGNATURE over the real destination leaf (single-leaf tree: root == leaf).
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        (bytes32 root, bytes memory sigData) = _signDestination(executorCalldata, dstTokens, intentAmounts, validUntil);

        // 3. DESTINATION: Across fill delivers funds + message to the adapter (transport hop),
        //    which forwards to the executor.
        bytes memory message6 =
            abi.encode(bytes(""), executorCalldata, address(account), dstTokens, intentAmounts, sigData);
        token.mint(address(adapter), AMOUNT);
        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), message6);

        // 4. The position exists as SHARES owned by the hub-controlled account.
        assertGt(vault.balanceOf(address(account)), 0, "no destination vault shares minted to the account");
        assertEq(token.balanceOf(address(vault)), AMOUNT, "assets not deposited into the vault");
        assertEq(token.balanceOf(address(account)), 0, "assets must not idle on the account");
        assertEq(token.balanceOf(address(adapter)), 0, "adapter must not retain funds");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root not consumed (replay protection)");
    }

    /// @notice B1.RR2 destination leg: mutating ONLY the vault inside the executor calldata after
    ///         signing must fail destination signature validation — the signed leaf commits to the
    ///         exact action.
    function test_E2E_MutatedVaultFailsDestinationSignature() public {
        bytes memory executorCalldata = _depositExecutorCalldata(address(vault));
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _intent();
        uint48 validUntil = uint48(block.timestamp + 1 hours);
        (, bytes memory sigData) = _signDestination(executorCalldata, dstTokens, intentAmounts, validUntil);

        // Attacker swaps the destination action for a different vault, keeping the valid signature.
        Mock4626Vault rogueVault = new Mock4626Vault(address(token), "Rogue", "RGV");
        bytes memory mutatedCalldata = _depositExecutorCalldata(address(rogueVault));
        bytes memory message6 =
            abi.encode(bytes(""), mutatedCalldata, address(account), dstTokens, intentAmounts, sigData);

        token.mint(address(adapter), AMOUNT);
        vm.prank(spokePool);
        vm.expectRevert(); // INVALID_PROOF: the leaf no longer opens against the signed root
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), message6);

        assertEq(vault.balanceOf(address(account)), 0, "no shares may exist");
        assertEq(rogueVault.balanceOf(address(account)), 0, "mutated action must not execute");
    }

    /// @notice B1.RR2 hub leg on the same fixture: the mutated action never leaves the hub either.
    function test_E2E_MutatedVaultRejectedByCapHook() public {
        Mock4626Vault rogueVault = new Mock4626Vault(address(token), "Rogue", "RGV");
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _intent();
        // Approve spender still the approved vault, deposit target swapped -> spender/vault
        // mismatch is caught by the typed-action decode.
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook);
        hooks[1] = address(depositHook);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(address(token), address(vault), AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(address(rogueVault), AMOUNT);
        bytes memory message5 = abi.encode(
            bytes(""), CapMessageLib.executorCalldataFor(hooks, hooksData), address(account), dstTokens, intentAmounts
        );

        vm.prank(address(account));
        vm.expectRevert(SuperVaultCapBridgeCommon.DESTINATION_ACTION_NOT_VALID.selector);
        capHook.preExecute(address(0), address(account), _hubData(message5));
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical typed destination action: execute([approve(token, vault), deposit(vault)]).
    function _depositExecutorCalldata(address vault_) internal view returns (bytes memory) {
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveHook);
        hooks[1] = address(depositHook);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = CapMessageLib.approveHookData(address(token), vault_, AMOUNT);
        hooksData[1] = CapMessageLib.depositHookData(vault_, AMOUNT);
        return CapMessageLib.executorCalldataFor(hooks, hooksData);
    }

    function _intent() internal view returns (address[] memory dstTokens, uint256[] memory intentAmounts) {
        dstTokens = new address[](1);
        dstTokens[0] = address(token);
        intentAmounts = new uint256[](1);
        intentAmounts[0] = AMOUNT;
    }

    /// @dev Across ApproveAnd hookData wrapping `message` (hub-side cap-hook input).
    function _hubData(bytes memory message) internal view returns (bytes memory) {
        bytes memory header = abi.encodePacked(
            bytes(new bytes(52)),
            uint256(0), // value
            address(adapter), // recipient = transport adapter
            address(token), // inputToken
            address(token), // outputToken
            AMOUNT,
            AMOUNT
        );
        return abi.encodePacked(
            header,
            uint256(chainId), // destinationChainId
            address(0), // exclusiveRelayer
            uint32(3600),
            uint32(0),
            false, // usePrevHookAmount
            message
        );
    }

    /// @dev Real destination signature: leaf over (callData, chainId, sender, executor, dstTokens,
    ///      intentAmounts, validUntil, validator), single-leaf root, EOA owner signs
    ///      keccak(abi.encode(namespace, root)) as an eth-signed message.
    function _signDestination(
        bytes memory executorCalldata,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        uint48 validUntil
    )
        internal
        view
        returns (bytes32 root, bytes memory sigData)
    {
        root = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        executorCalldata,
                        chainId,
                        address(account),
                        address(executor),
                        dstTokens,
                        intentAmounts,
                        validUntil,
                        address(validator)
                    )
                )
            )
        );

        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        bytes32 ethSigned = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, ethSigned);

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: address(account),
                executor: address(executor),
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: address(validator),
                data: bytes("")
            })
        });

        sigData = abi.encode(
            new uint64[](0), validUntil, uint48(0), root, new bytes32[](0), proofDst, abi.encodePacked(r, s, v)
        );
    }
}
