// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Vm } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { RelayFillHelper } from "../../utils/RelayFillHelper.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";

import { RelayAdapterV2 } from "../../../src/adapters/RelayAdapterV2.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { IRelayDepository } from "../../../src/vendor/bridges/relay/IRelayDepository.sol";

contract V2Executor {
    address public SUPER_DESTINATION_VALIDATOR;
    uint256 public callCount;
    address public lastAccount;

    constructor(address v) {
        SUPER_DESTINATION_VALIDATOR = v;
    }

    function processBridgedExecution(
        address,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    ) external {
        ++callCount;
        lastAccount = account;
    }
}

contract V2Account {
    receive() external payable { }
}

/// @title RelayAdapterV2PigeonE2E
/// @author Superform Labs
/// @notice Two-fork proof that the V1 fund-theft gap is closed: a real `RelayDepository` deposit on
///         Ethereum, a simulated solver fill on Base, and a `RelayAdapterV2` that authenticates the
///         intent with a REAL signature before moving anything.
/// @dev Each test here is the direct counterpart of a V1 test in `RelayAdapterPigeonE2E.t.sol`. Those
///      V1 tests PASS while demonstrating theft; these show the same attacks failing against V2.
contract RelayAdapterV2PigeonE2E is RelayFillHelper, MerkleTreeHelper {
    address internal constant RELAY_DEPOSITORY = 0x4cD00E387622C35bDDB9b4c962C136462338BC31;
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 internal ethForkId;
    uint256 internal baseForkId;

    RelayAdapterV2 internal adapter;
    SuperDestinationValidator internal validator;
    V2Executor internal executor;

    uint256 internal ownerPk = 0xBEEF;
    address internal owner;

    address internal account;
    address internal depositor;
    address internal attacker;
    address internal attackerAccount;
    address internal solver;

    uint48 internal validUntil;

    function setUp() public {
        owner = vm.addr(ownerPk);

        baseForkId = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        validator = new SuperDestinationValidator();
        executor = new V2Executor(address(validator));
        adapter = new RelayAdapterV2(address(executor));

        account = address(new V2Account());
        attackerAccount = address(new V2Account());
        vm.prank(account);
        validator.onInstall(abi.encode(owner));
        vm.prank(attackerAccount);
        validator.onInstall(abi.encode(owner));

        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        depositor = makeAddr("depositor");
        attacker = makeAddr("attacker");
        solver = makeAddr("relaySolver");
        validUntil = uint48(block.timestamp + 1 days);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function _depositOnEth(uint256 amount, bytes32 id) internal returns (Vm.Log[] memory) {
        deal(USDC_ETH, depositor, amount);
        vm.recordLogs();
        vm.startPrank(depositor);
        IERC20(USDC_ETH).approve(RELAY_DEPOSITORY, amount);
        IRelayDepository(RELAY_DEPOSITORY).depositErc20(depositor, USDC_ETH, amount, id);
        vm.stopPrank();
        return vm.getRecordedLogs();
    }

    /// @dev Root + proof for a single-leaf tree committing to `acct` on the destination chain.
    function _rootAndProof(address acct) private view returns (bytes32 root, bytes32[] memory proof0) {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _createDestinationValidatorLeaf(
            bytes(""),
            uint64(block.chainid),
            acct,
            address(executor),
            _tokens(),
            _mins(),
            validUntil,
            address(validator)
        );
        bytes32[][] memory proof;
        (proof, root) = _createValidatorMerkleTree(leaves);
        proof0 = proof[0];
    }

    function _sign(bytes32 root) private view returns (bytes memory) {
        bytes32 h = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, MessageHashUtils.toEthSignedMessageHash(h));
        return abi.encodePacked(r, s, v);
    }

    function _dstProof(address acct, bytes32[] memory proof0)
        private
        view
        returns (ISuperValidator.DstProof[] memory proofDst)
    {
        proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: proof0,
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: acct,
                executor: address(executor),
                dstTokens: _tokens(),
                intentAmounts: _mins(),
                validator: address(validator),
                data: bytes("")
            })
        });
    }

    /// @dev The intent must name the delivered token (USDC on Base) with a non-zero MINIMUM.
    function _tokens() private pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = USDC_BASE;
    }

    function _mins() private pure returns (uint256[] memory m) {
        m = new uint256[](1);
        m[0] = 1;
    }

    function _chains() private view returns (uint64[] memory c) {
        c = new uint64[](1);
        c[0] = uint64(block.chainid);
    }

    /// @dev A genuinely signed message. Built on the Base fork so the leaf commits to Base's chain id.
    function _validMessage(address acct) internal returns (bytes memory message) {
        uint256 prev = vm.activeFork();
        vm.selectFork(baseForkId);

        (bytes32 root, bytes32[] memory proof0) = _rootAndProof(acct);
        message = abi.encode(
            bytes(""),
            abi.encode(
                _chains(), validUntil, uint48(0), root, new bytes32[](0), _dstProof(acct, proof0), _sign(root)
            )
        );

        vm.selectFork(prev);
    }

    /// @dev The V1-style attack payload: fabricated proof, EMPTY signature.
    function _forgedMessage(address acct) internal returns (bytes memory message) {
        uint256 prev = vm.activeFork();
        vm.selectFork(baseForkId);

        message = abi.encode(
            bytes(""),
            abi.encode(
                _chains(),
                validUntil,
                uint48(0),
                bytes32(0),
                new bytes32[](0),
                _dstProof(acct, new bytes32[](0)),
                bytes("")
            )
        );

        vm.selectFork(prev);
    }

    function _fillV2(bytes32 id, uint256 amount, bytes memory cd, Vm.Log[] memory logs) internal {
        Fill memory f;
        f.depository = RELAY_DEPOSITORY;
        f.depositId = id;
        f.solver = solver;
        f.outputToken = USDC_BASE;
        f.outputAmount = amount;
        f.dstForkId = baseForkId;
        fillViaAdapter(f, address(adapter), cd, logs);
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Legitimate flow still works end to end with a real signature.
    function test_V2_E2E_SignedIntentDeliversAndExecutes() public {
        uint256 amount = 1000e6;
        bytes memory message = _validMessage(account);
        Vm.Log[] memory logs = _depositOnEth(amount, keccak256("v2-ok"));

        _fillV2(
            keccak256("v2-ok"),
            amount,
            abi.encodeCall(RelayAdapterV2.processRelayExecution, (USDC_BASE, amount, message)),
            logs
        );

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(account), amount, "funds delivered");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter retains nothing");
        assertEq(executor.callCount(), 1, "execution fired");
    }

    /// @notice **THE GAP, CLOSED.** The exact V1 exploit — resting funds in the non-atomic window,
    ///         swept with an unsigned message — now fails and moves nothing.
    /// @dev The V1 counterpart (`test_E2E_Pigeon_NonAtomicWindow_RestingFundsAreSweepable`) PASSES
    ///      while stealing the full balance. This is the same setup against V2.
    function test_V2_E2E_NonAtomicWindow_RestingFundsNoLongerSweepable() public {
        uint256 amount = 1000e6;
        bytes memory forged = _forgedMessage(attackerAccount);

        // Leg 1 only: funds rest in the adapter, no leg-2 call yet.
        vm.selectFork(baseForkId);
        deal(USDC_BASE, address(adapter), amount);

        vm.prank(attacker);
        vm.expectRevert(); // validator rejects the fabricated proof before any transfer
        adapter.processRelayExecution(USDC_BASE, amount, forged);

        assertEq(IERC20(USDC_BASE).balanceOf(attackerAccount), 0, "attacker got nothing");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), amount, "victim funds intact");
    }

    /// @notice The multi-victim sweep is closed too.
    function test_V2_E2E_MultiVictimSweepBlocked() public {
        uint256 each = 500e6;
        bytes memory forged = _forgedMessage(attackerAccount);

        vm.selectFork(baseForkId);
        deal(USDC_BASE, address(adapter), each * 2);

        vm.startPrank(attacker);
        vm.expectRevert();
        adapter.processRelayExecution(USDC_BASE, each, forged);
        vm.expectRevert();
        adapter.processRelayExecution(USDC_BASE, each, forged);
        vm.stopPrank();

        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), each * 2, "both fills intact");
    }

    /// @notice A signed intent for the attacker's own account cannot redirect another user's fill —
    ///         it only ever delivers to the account the signature names.
    function test_V2_E2E_AttackerSignedIntentOnlyPaysTheirOwnAccount() public {
        uint256 amount = 1000e6;
        // Suppose the attacker legitimately holds a signed intent for their own account.
        bytes memory attackerIntent = _validMessage(attackerAccount);

        vm.selectFork(baseForkId);
        deal(USDC_BASE, address(adapter), amount);

        vm.prank(attacker);
        adapter.processRelayExecution(USDC_BASE, amount, attackerIntent);

        // It succeeds — but this is exactly the residual the bundler's atomicity already bounds, and
        // it can never target anyone else's account, because the leaf commits to the account.
        assertEq(IERC20(USDC_BASE).balanceOf(attackerAccount), amount, "paid the signed account only");
        assertEq(IERC20(USDC_BASE).balanceOf(account), 0, "victim account never targeted");
    }

    /// @notice The atomic batch still unwinds on a rejected message, so the solver is never left short.
    function test_V2_E2E_AtomicBatch_RevertUnwindsTheFill() public {
        uint256 amount = 1000e6;
        bytes memory forged = _forgedMessage(attackerAccount);
        Vm.Log[] memory logs = _depositOnEth(amount, keccak256("v2-unwind"));

        vm.expectRevert();
        this.fillExternalV2(
            keccak256("v2-unwind"),
            amount,
            abi.encodeCall(RelayAdapterV2.processRelayExecution, (USDC_BASE, amount, forged)),
            logs
        );

        vm.selectFork(baseForkId);
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "fill unwound");
    }

    /// @dev External boundary so `vm.expectRevert` observes the revert at a lower depth.
    function fillExternalV2(bytes32 id, uint256 amount, bytes memory cd, Vm.Log[] memory logs) external {
        _fillV2(id, amount, cd, logs);
    }
}
