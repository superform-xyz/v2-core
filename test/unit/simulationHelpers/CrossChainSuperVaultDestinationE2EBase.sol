// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
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

/// @dev Hub-side signature storage stub for the cap hooks' parents (build-time append only).
contract MockHubSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        return abi.encode(new uint64[](0), validUntil, 0, keccak256("root"), proofSrc, proofDst, hex"abcdef");
    }
}

/// @title CrossChainSuperVaultDestinationE2EBase
/// @notice Shared fixture for the per-bridge "full remote lifecycle" e2e tests (PR #336 review
///         test matrix): the REAL destination stack — SuperDestinationExecutor +
///         SuperDestinationValidator (real EOA-owner signature over the real destination merkle
///         leaf) + real ApproveERC20Hook / Deposit4626VaultHook executed ON the hub-controlled
///         ERC7579 account — plus the hub-side cap mocks. Each concrete test adds its bridge
///         adapter (Across / deBridge / Stargate), its cap hook, and its delivery mechanics.
abstract contract CrossChainSuperVaultDestinationE2EBase is Test {
    uint256 internal constant AMOUNT = 1000e6;

    // Destination stack (real contracts)
    SuperDestinationExecutor internal executor;
    SuperDestinationValidator internal validator;
    ExecutingERC7579Account internal account;
    ApproveERC20Hook internal approveHook;
    Deposit4626VaultHook internal depositHook;
    MockERC20 internal token;
    Mock4626Vault internal vault;
    MockLedger internal ledger;
    MockLedgerConfiguration internal ledgerConfig;

    // Hub-side cap stack (mock policy, real cap hooks added by concrete tests)
    MockCapGuard internal capGuard;
    MockPositionRegistry internal positionRegistry;
    MockGovernorAddressBook internal governor;
    MockHubSignatureStorage internal hubValidator;

    address internal owner;
    uint256 internal ownerPk;
    uint64 internal chainId;

    function _setUpDestinationStack() internal {
        (owner, ownerPk) = makeAddrAndKey("accountOwner");
        chainId = uint64(block.chainid);

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

        // The hub-controlled destination account: same address as the hub strategy account, with
        // the REAL validator (EOA owner) and the destination executor installed.
        account = new ExecutingERC7579Account();
        account.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(owner));
        account.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));

        // Hub-side cap policy mocks (the same surface the periphery cap guard serves).
        capGuard = new MockCapGuard();
        positionRegistry = new MockPositionRegistry();
        governor = new MockGovernorAddressBook(address(capGuard), address(positionRegistry));
        hubValidator = new MockHubSignatureStorage();

        capGuard.setDestinationHooks(chainId, address(approveHook), address(depositHook));
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

    /// @dev The raw 5-tuple destination message the cap hooks validate (signature appended later).
    function _message5(bytes memory executorCalldata) internal view returns (bytes memory) {
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _intent();
        return abi.encode(bytes(""), executorCalldata, address(account), dstTokens, intentAmounts);
    }

    /// @dev The 6-tuple message the adapters deliver (signature included).
    function _message6(bytes memory executorCalldata, bytes memory sigData) internal view returns (bytes memory) {
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _intent();
        return abi.encode(bytes(""), executorCalldata, address(account), dstTokens, intentAmounts, sigData);
    }

    /// @dev Real destination signature: leaf over (callData, chainId, sender, executor, dstTokens,
    ///      intentAmounts, validUntil, validator), single-leaf root, EOA owner signs
    ///      keccak(abi.encode(namespace, root)) as an eth-signed message.
    function _signDestination(bytes memory executorCalldata)
        internal
        view
        returns (bytes32 root, bytes memory sigData)
    {
        (address[] memory dstTokens, uint256[] memory intentAmounts) = _intent();
        uint48 validUntil = uint48(block.timestamp + 1 hours);

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

    /// @dev The shared success assertions: the position exists as SHARES owned by the
    ///      hub-controlled account, nothing idles, replay is blocked.
    function _assertSharesMinted(bytes32 root, address adapter) internal view {
        assertGt(vault.balanceOf(address(account)), 0, "no destination vault shares minted to the account");
        assertEq(token.balanceOf(address(vault)), AMOUNT, "assets not deposited into the vault");
        assertEq(token.balanceOf(address(account)), 0, "assets must not idle on the account");
        assertEq(token.balanceOf(adapter), 0, "adapter must not retain funds");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root not consumed (replay protection)");
    }
}
