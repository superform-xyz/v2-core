// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { CircleGatewayHelper } from "@pigeon/circle-gateway/CircleGatewayHelper.sol";
import { IGatewayMinter as IPigeonGatewayMinter } from "@pigeon/circle-gateway/interfaces/IGatewayMinter.sol";
import { IGatewayWallet as IPigeonGatewayWallet } from "@pigeon/circle-gateway/interfaces/IGatewayWallet.sol";

import { CircleGatewayAdapter } from "../../../src/adapters/CircleGatewayAdapter.sol";
import { CircleGatewayWalletHook } from "../../../src/hooks/bridges/circle/CircleGatewayWalletHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/*//////////////////////////////////////////////////////////////
                              MOCKS
//////////////////////////////////////////////////////////////*/

/// @notice Records what the adapter forwarded, and exposes the validator getter the adapter caches.
contract RecordingDestinationExecutor {
    address public SUPER_DESTINATION_VALIDATOR = address(0xDA11D);

    uint256 public callCount;
    address public lastAccount;
    address public lastTokenSent;
    address[] public lastDstTokens;
    uint256[] public lastIntentAmounts;

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        bytes memory,
        bytes memory,
        bytes memory
    )
        external
    {
        ++callCount;
        lastTokenSent = tokenSent;
        lastAccount = account;
        lastDstTokens = dstTokens;
        lastIntentAmounts = intentAmounts;
    }
}

/*//////////////////////////////////////////////////////////////
                              TESTS
//////////////////////////////////////////////////////////////*/

/// @title CircleGatewayAdapterPigeonE2E
/// @author Superform Labs
/// @notice True end-to-end coverage of the Circle Gateway destination path driven by pigeon: deposit on Ethereum
///         through the real `CircleGatewayWalletHook` into the real `GatewayWallet`, attest with pigeon's
///         `CircleGatewayHelper` (which plays Circle's attestation signer against the REAL `GatewayMinter`), then
///         mint + forward + execute through `CircleGatewayAdapter` on Base.
/// @dev Gateway has no source-chain message to relay (the attestation is issued off-chain by Circle), so unlike
///      the CCTP pigeon suite there are no logs to scan: the test describes the transfer as a TransferSpec and
///      pigeon signs it. The deposit leg is real but, as in production, not linked on-chain to the mint.
contract CircleGatewayAdapterPigeonE2E is Test {
    address public constant GATEWAY_WALLET = 0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE;
    address public constant GATEWAY_MINTER = 0x2222222d7164433c4C09B0b0D809a9b52C04C205;
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint32 public constant DOMAIN_ETH = 0;
    uint32 public constant DOMAIN_BASE = 6;
    uint64 public constant CHAINID_BASE = 8453;
    uint256 public constant AMOUNT = 1000e6;

    uint256 internal ethForkId;
    uint256 internal baseForkId;

    CircleGatewayWalletHook internal walletHook;
    CircleGatewayHelper internal pigeon;

    CircleGatewayAdapter internal adapter;
    RecordingDestinationExecutor internal executor;

    address internal account;
    /// @dev cached on Base: the executor does not exist on the Ethereum fork
    address internal validatorAddr;

    function setUp() public {
        // --- Destination fork first: the adapter address goes into the TransferSpec ---
        baseForkId = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        executor = new RecordingDestinationExecutor();
        adapter = new CircleGatewayAdapter(GATEWAY_MINTER, USDC_BASE, address(executor));
        validatorAddr = executor.SUPER_DESTINATION_VALIDATOR();

        // --- Source fork ---
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        walletHook = new CircleGatewayWalletHook(GATEWAY_WALLET);
        pigeon = new CircleGatewayHelper(0); // persistent across forks by construction

        account = makeAddr("account");
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice A SignatureData carrying a DstProof for Base naming `proofExecutor`/`proofValidator`, so the
    ///         adapter's target assertion has something real to check.
    function _signatureData(address proofExecutor, address proofValidator) internal view returns (bytes memory) {
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: CHAINID_BASE,
            info: ISuperValidator.DstInfo({
                account: account,
                executor: proofExecutor,
                dstTokens: _one(USDC_BASE),
                intentAmounts: _one(1),
                validator: proofValidator,
                data: bytes("executorCalldata")
            })
        });
        uint64[] memory chains = new uint64[](1);
        chains[0] = CHAINID_BASE;
        return abi.encode(
            chains,
            uint48(block.timestamp + 1 days),
            uint48(0),
            keccak256("root"),
            new bytes32[](0),
            proofDst,
            new bytes(65)
        );
    }

    /// @notice The 6-tuple the SDK places in TransferSpec.hookData.
    function _hookData(uint256 intentAmount, bytes memory sigData) internal view returns (bytes memory) {
        return abi.encode(bytes(""), bytes("executorCalldata"), account, _one(USDC_BASE), _one(intentAmount), sigData);
    }

    function _hookData(uint256 intentAmount) internal view returns (bytes memory) {
        return _hookData(intentAmount, _signatureData(address(executor), validatorAddr));
    }

    /// @notice A spec funded from Ethereum, pinned to and minting into the adapter on Base.
    function _spec(uint256 value, bytes memory hookData) internal returns (CircleGatewayHelper.TransferSpec memory) {
        return pigeon.buildSpec(
            DOMAIN_ETH, DOMAIN_BASE, USDC_ETH, USDC_BASE, account, address(adapter), address(adapter), value, hookData
        );
    }

    /// @dev Packs the wallet hook's data layout (52-byte strategy header + usdc @52, amount @72, usePrev @104).
    function _walletHookData(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), address(0), USDC_ETH, amount, false);
    }

    /// @notice Deposit into the REAL GatewayWallet on Ethereum through the real hook's executions.
    function _depositOnEth(uint256 amount) internal {
        vm.selectFork(ethForkId);
        deal(USDC_ETH, account, amount);
        Execution[] memory executions = walletHook.build(address(0), account, _walletHookData(amount));
        vm.startPrank(account);
        for (uint256 i; i < executions.length; ++i) {
            (bool ok,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(ok, string.concat("source execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
    }

    function _one(address v) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = v;
    }

    function _one(uint256 v) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = v;
    }

    /*//////////////////////////////////////////////////////////////
                                 E2E
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit on Ethereum via the real hook → pigeon attests → adapter mints, forwards and executes on
    /// Base.
    function test_E2E_Pigeon_DepositOnEth_AdapterExecutesOnBase() public {
        _depositOnEth(AMOUNT);
        assertEq(
            IPigeonGatewayWallet(GATEWAY_WALLET).availableBalance(USDC_ETH, account),
            AMOUNT,
            "hook deposited into the real GatewayWallet"
        );

        CircleGatewayHelper.TransferSpec memory spec = _spec(AMOUNT, _hookData(1));
        CircleGatewayHelper.Attested memory attested = pigeon.helpMintViaAdapter(baseForkId, address(adapter), spec);
        assertEq(vm.activeFork(), ethForkId, "pigeon restored the source fork");

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(account), AMOUNT, "account received the full minted amount");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter retains nothing");
        assertEq(executor.callCount(), 1, "executor invoked exactly once");
        assertEq(executor.lastAccount(), account);
        assertEq(executor.lastTokenSent(), USDC_BASE);
        assertEq(executor.lastDstTokens(0), USDC_BASE, "dstTokens survived the Gateway wire");
        assertTrue(adapter.processed(attested.transferSpecHashes[0]), "spec attributed");
        assertTrue(IPigeonGatewayMinter(GATEWAY_MINTER).isTransferSpecHashUsed(attested.transferSpecHashes[0]));
    }

    /// @notice A homogeneous AttestationSet minted through the adapter in one call: delivered once, executed once.
    function test_E2E_Pigeon_Set_DeliveredOnceExecutedOnce() public {
        bytes memory hookData = _hookData(1);
        CircleGatewayHelper.TransferSpec[] memory specs = new CircleGatewayHelper.TransferSpec[](2);
        specs[0] = _spec(300e6, hookData);
        specs[1] = _spec(400e6, hookData);

        CircleGatewayHelper.Attested memory attested = pigeon.helpMintViaAdapterSet(baseForkId, address(adapter), specs);

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(account), 700e6, "sum of both members delivered");
        assertEq(executor.callCount(), 1, "one execution for the set");
        assertTrue(
            adapter.processed(attested.transferSpecHashes[0]) && adapter.processed(attested.transferSpecHashes[1])
        );
    }

    /// @notice The same attested payload cannot be relayed twice: the real minter rejects the replay.
    function test_E2E_Pigeon_Replay_RejectedByMinter() public {
        CircleGatewayHelper.Attested memory attested = pigeon.helpAttest(baseForkId, _spec(AMOUNT, _hookData(1)));

        vm.selectFork(baseForkId);
        adapter.receiveAndExecute(attested.payload, attested.signature);
        assertEq(IERC20(USDC_BASE).balanceOf(account), AMOUNT);

        vm.expectRevert(abi.encodeWithSignature("TransferSpecHashUsed(bytes32)", attested.transferSpecHashes[0]));
        adapter.receiveAndExecute(attested.payload, attested.signature);
    }

    /// @notice A spec pinned to the adapter cannot be minted by anyone else — the real minter enforces it.
    function test_E2E_Pigeon_DestinationCallerBlocksDirectMint() public {
        CircleGatewayHelper.Attested memory attested = pigeon.helpAttest(baseForkId, _spec(AMOUNT, _hookData(1)));

        vm.selectFork(baseForkId);
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAttestationDestinationCallerAtIndex(uint32,address,address)", 0, address(adapter), address(this)
            )
        );
        IPigeonGatewayMinter(GATEWAY_MINTER).gatewayMint(attested.payload, attested.signature);

        // the adapter path still works afterwards
        adapter.receiveAndExecute(attested.payload, attested.signature);
        assertEq(executor.callCount(), 1);
    }

    /// @notice An UNPINNED spec minted straight into the adapter by a third party (pigeon's direct `help` is the
    ///         third party here): the relay is rejected by the minter, and `recoverDirectMint` — permissionless,
    ///         signature-free — forwards the stranded USDC and executes the intent.
    function test_E2E_Pigeon_DirectMintIntoAdapter_RecoveredPermissionlessly() public {
        CircleGatewayHelper.TransferSpec memory spec = pigeon.buildSpec(
            DOMAIN_ETH, DOMAIN_BASE, USDC_ETH, USDC_BASE, account, address(adapter), address(0), AMOUNT, _hookData(1)
        );
        CircleGatewayHelper.Attested memory attested = pigeon.help(baseForkId, spec); // minted by pigeon itself

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), AMOUNT, "stranded in the adapter");
        assertEq(executor.callCount(), 0, "nothing executed");

        vm.expectRevert(abi.encodeWithSignature("TransferSpecHashUsed(bytes32)", attested.transferSpecHashes[0]));
        adapter.receiveAndExecute(attested.payload, attested.signature);

        vm.prank(makeAddr("goodSamaritan"));
        adapter.recoverDirectMint(attested.payload);
        assertEq(IERC20(USDC_BASE).balanceOf(account), AMOUNT, "recovered to the account");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 1, "intent executed as the relay would have");
    }

    /// @notice A DstProof naming another executor: funds delivered, execution skipped, nothing reverts.
    function test_E2E_Pigeon_ExecutorMismatch_DeliversFundsAndSkipsExecution() public {
        bytes memory hookData = _hookData(1, _signatureData(makeAddr("otherExecutor"), validatorAddr));
        pigeon.helpMintViaAdapter(baseForkId, address(adapter), _spec(AMOUNT, hookData));

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(account), AMOUNT, "funds delivered");
        assertEq(executor.callCount(), 0, "execution skipped");
    }

    /// @notice Starving the relay hits the adapter's gas floor: the whole tx unwinds, the spec stays unused on the
    ///         real minter, and the same attestation relays with enough gas.
    function test_E2E_Pigeon_InsufficientGas_LeavesSpecUnconsumed() public {
        CircleGatewayHelper.Attested memory attested = pigeon.helpAttest(baseForkId, _spec(AMOUNT, _hookData(1)));

        vm.selectFork(baseForkId);
        vm.expectRevert(CircleGatewayAdapter.INSUFFICIENT_GAS.selector);
        adapter.receiveAndExecute{ gas: 1_500_000 }(attested.payload, attested.signature);
        assertFalse(IPigeonGatewayMinter(GATEWAY_MINTER).isTransferSpecHashUsed(attested.transferSpecHashes[0]));

        adapter.receiveAndExecute(attested.payload, attested.signature);
        assertEq(executor.callCount(), 1);
    }

    /// @notice Garbage hookData is rejected BEFORE the mint: pigeon re-raises the adapter's error and restores
    ///         the fork, the spec is unused, and the depositor's Gateway balance on Ethereum is untouched.
    function test_E2E_Pigeon_UndecodableHookData_RejectedPreMint() public {
        _depositOnEth(AMOUNT);
        CircleGatewayHelper.TransferSpec memory spec = _spec(AMOUNT, hex"deadbeef");

        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        pigeon.helpMintViaAdapter(baseForkId, address(adapter), spec);
        assertEq(vm.activeFork(), ethForkId, "fork restored after the re-raised revert");
        assertEq(IPigeonGatewayWallet(GATEWAY_WALLET).availableBalance(USDC_ETH, account), AMOUNT, "balance intact");

        vm.selectFork(baseForkId);
        assertFalse(IPigeonGatewayMinter(GATEWAY_MINTER).isTransferSpecHashUsed(pigeon.transferSpecHash(spec)));
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0);
    }
}
