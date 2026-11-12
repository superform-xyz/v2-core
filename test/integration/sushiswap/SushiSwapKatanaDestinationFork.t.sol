// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

// Superform
import { SwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/SwapSushiSwapHook.sol";
import { ApproveAndSwapSushiSwapHook } from "../../../src/hooks/swappers/sushiswap/ApproveAndSwapSushiSwapHook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";

import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { ExecutingERC7579Account } from "../../unit/simulationHelpers/AcrossDestinationExecutionE2E.t.sol";
import { SushiKatanaFixtures } from "./SushiKatanaFixtures.sol";

/// @title SushiSwapKatanaDestinationFork
/// @author Superform Labs
/// @notice Bridge -> destination SushiSwap swap into Katana through the normal account flow: the REAL
///         `SuperDestinationExecutor` + `SuperDestinationValidator` on a pinned Katana fork, a genuinely signed
///         single-leaf destination intent, the live RedSnwapper / executor / liquidity and the UNMODIFIED Sushi v7
///         calldata. The bridge adapter is a stand-in caller: every production adapter ends by delivering the funds
///         to the account and calling `processBridgedExecution`, which has no caller restriction (the signature is
///         what gates it), so "funds landed" is modelled by `deal`.
/// @dev Runs against KATANA_RPC_URL (default public RPC); skips without connectivity; excluded from `ftest-ci`.
contract SushiSwapKatanaDestinationFork is MerkleTreeHelper, SushiKatanaFixtures {
    uint48 internal constant VALID_UNTIL = type(uint48).max;

    address internal owner;
    uint256 internal ownerPk;
    address internal adapter = makeAddr("bridge-adapter");

    SuperDestinationValidator internal validator;
    SuperDestinationExecutor internal executor;
    ExecutingERC7579Account internal account;
    SwapSushiSwapHook internal swapHook;
    ApproveAndSwapSushiSwapHook internal approveHook;
    ApproveERC20Hook internal approveErc20Hook;
    bool internal forked;

    receive() external payable { }

    function setUp() public {
        string memory rpc = envOr("KATANA_RPC_URL", "https://rpc.katana.network");
        if (bytes(rpc).length == 0) return;
        try vm.createSelectFork(rpc, KATANA_BLOCK) {
            forked = true;
        } catch {
            return;
        }

        (owner, ownerPk) = makeAddrAndKey("accountOwner");
        validator = new SuperDestinationValidator();
        executor = new SuperDestinationExecutor(address(new SuperLedgerConfiguration()), address(validator));

        account = new ExecutingERC7579Account();
        account.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(owner));
        account.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));

        swapHook = new SwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
        approveHook = new ApproveAndSwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
        approveErc20Hook = new ApproveERC20Hook();
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    /*//////////////////////////////////////////////////////////////
                              DESTINATION LEG
    //////////////////////////////////////////////////////////////*/

    /// @notice Bridged vbUSDC lands, the signed intent runs `ApproveAndSwapSushiSwapHook` (flag off) and the KAT
    ///         output reaches the account; the root is consumed; nothing rests on the hook.
    function test_Destination_ApproveAndSwap_FlagOff() public {
        _requireFork();
        uint256 bridged = QUOTE_USDC_KAT_IN;
        deal(VB_USDC, address(account), bridged); // "funds landed"

        bytes memory executorCalldata = _executorCalldata1(address(approveHook), _usdcKatData(false));
        (bytes memory sigData, bytes32 root) = _signed(executorCalldata, bridged);

        vm.prank(adapter);
        executor.processBridgedExecution(
            VB_USDC, address(account), _one(VB_USDC), _one(bridged), bytes(""), executorCalldata, sigData
        );

        assertEq(IERC20(VB_USDC).balanceOf(address(account)), 0, "bridged input fully swapped");
        assertGe(IERC20(KAT).balanceOf(address(account)), OUTER_MIN_USDC_KAT, "output reached the account");
        assertEq(IERC20(KAT).balanceOf(address(account)), QUOTE_USDC_KAT_OUT, "cap binds at the quote");
        assertEq(IERC20(VB_USDC).allowance(address(account), RED_SNWAPPER), 0, "allowance reset");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
        _assertNoDustOnHooks();
    }

    /// @notice The bundler's destination shape: the bridge delivered less than the quote (fees), the approve hook
    ///         is trimmed to the actual amount with the swap header + payload left at the original quote and
    ///         `usePrevHookAmount` enabled. The hook rescales both heads on the destination and swaps exactly the
    ///         delivered amount.
    function test_Destination_ApproveHook_PlusPlainSwap_FlagOn_Below95() public {
        _requireFork();
        uint256 bridged = QUOTE_USDC_KAT_IN * 95 / 100;
        deal(VB_USDC, address(account), bridged);

        bytes memory executorCalldata = _executorCalldata2(
            address(approveErc20Hook), _approveData(bridged), address(swapHook), _usdcKatData(true)
        );
        (bytes memory sigData, bytes32 root) = _signed(executorCalldata, bridged);

        vm.prank(adapter);
        executor.processBridgedExecution(
            VB_USDC, address(account), _one(VB_USDC), _one(bridged), bytes(""), executorCalldata, sigData
        );

        assertEq(IERC20(VB_USDC).balanceOf(address(account)), 0, "exactly the delivered amount was swapped");
        uint256 out = IERC20(KAT).balanceOf(address(account));
        assertGe(out, Math.mulDiv(OUTER_MIN_USDC_KAT, 95, 100, Math.Rounding.Ceil), "scaled floor");
        assertEq(out, Math.mulDiv(QUOTE_USDC_KAT_OUT, 95, 100, Math.Rounding.Ceil), "scaled cap binds");
        assertTrue(executor.isMerkleRootUsed(address(account), root));
        _assertNoDustOnHooks();
    }

    /// @notice The approve variant with the flag on, upsized: the bridge delivered more than quoted.
    function test_Destination_ApproveAndSwap_FlagOn_Above105() public {
        _requireFork();
        uint256 bridged = QUOTE_USDC_KAT_IN * 105 / 100;
        deal(VB_USDC, address(account), bridged);

        // the approve hook only supplies the predecessor context here; the approve variant re-approves itself
        bytes memory executorCalldata = _executorCalldata2(
            address(approveErc20Hook), _approveData(bridged), address(approveHook), _usdcKatData(true)
        );
        (bytes memory sigData, bytes32 root) = _signed(executorCalldata, bridged);

        vm.prank(adapter);
        executor.processBridgedExecution(
            VB_USDC, address(account), _one(VB_USDC), _one(bridged), bytes(""), executorCalldata, sigData
        );

        assertEq(IERC20(VB_USDC).balanceOf(address(account)), 0);
        uint256 out = IERC20(KAT).balanceOf(address(account));
        assertGe(out, Math.mulDiv(OUTER_MIN_USDC_KAT, 105, 100, Math.Rounding.Ceil), "scaled floor");
        assertGt(out, QUOTE_USDC_KAT_OUT, "more delivered, more output");
        assertLe(out, Math.mulDiv(QUOTE_USDC_KAT_OUT, 105, 100, Math.Rounding.Ceil), "scaled nested cap");
        assertEq(IERC20(VB_USDC).allowance(address(account), RED_SNWAPPER), 0);
        assertTrue(executor.isMerkleRootUsed(address(account), root));
        _assertNoDustOnHooks();
    }

    /// @notice Not enough bridged balance for the signed intent: the executor returns without executing, the root
    ///         stays unused (re-drivable), no swap happens.
    function test_Destination_InsufficientBalance_SkipsWithoutExecuting() public {
        _requireFork();
        uint256 intent = QUOTE_USDC_KAT_IN;
        deal(VB_USDC, address(account), intent / 2);

        bytes memory executorCalldata = _executorCalldata1(address(approveHook), _usdcKatData(false));
        (bytes memory sigData, bytes32 root) = _signed(executorCalldata, intent);

        vm.prank(adapter);
        executor.processBridgedExecution(
            VB_USDC, address(account), _one(VB_USDC), _one(intent), bytes(""), executorCalldata, sigData
        );

        assertEq(IERC20(VB_USDC).balanceOf(address(account)), intent / 2, "nothing moved");
        assertEq(IERC20(KAT).balanceOf(address(account)), 0, "no swap");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root untouched");
    }

    /// @notice A tampered intent (payload executor swapped after signing) is rejected by the validator before any
    ///         hook runs.
    function test_Destination_TamperedCalldata_Rejected() public {
        _requireFork();
        uint256 bridged = QUOTE_USDC_KAT_IN;
        deal(VB_USDC, address(account), bridged);

        bytes memory executorCalldata = _executorCalldata1(address(approveHook), _usdcKatData(false));
        (bytes memory sigData,) = _signed(executorCalldata, bridged);
        bytes memory tampered = _executorCalldata1(address(swapHook), _usdcKatData(false));

        vm.prank(adapter);
        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        executor.processBridgedExecution(
            VB_USDC, address(account), _one(VB_USDC), _one(bridged), bytes(""), tampered, sigData
        );
        assertEq(IERC20(VB_USDC).balanceOf(address(account)), bridged);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _usdcKatData(bool flag) internal view returns (bytes memory) {
        return _hookData(
            VB_USDC,
            KAT,
            QUOTE_USDC_KAT_IN,
            QUOTE_USDC_KAT_OUT,
            OUTER_MIN_USDC_KAT,
            flag,
            _withRecipient(TX_USDC_KAT, address(account))
        );
    }

    function _approveData(uint256 amount) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes(new bytes(52)), VB_USDC, RED_SNWAPPER, amount, false);
    }

    function _executorCalldata1(address hook, bytes memory data) internal pure returns (bytes memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        return abi.encodeCall(
            ISuperExecutor.execute,
            (abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas })))
        );
    }

    function _executorCalldata2(
        address hookA,
        bytes memory dataA,
        address hookB,
        bytes memory dataB
    )
        internal
        pure
        returns (bytes memory)
    {
        address[] memory hooks = new address[](2);
        hooks[0] = hookA;
        hooks[1] = hookB;
        bytes[] memory datas = new bytes[](2);
        datas[0] = dataA;
        datas[1] = dataB;
        return abi.encodeCall(
            ISuperExecutor.execute,
            (abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas })))
        );
    }

    /// @dev Single-leaf destination intent (root == leaf, empty proof), signed by the account owner the validator
    ///      was installed with; shape copied from the real adapters / DestinationSimulationTestBase.
    function _signed(
        bytes memory executorCalldata,
        uint256 intentAmount
    )
        internal
        view
        returns (bytes memory sigData, bytes32 root)
    {
        root = _createDestinationValidatorLeaf(
            executorCalldata,
            uint64(KATANA_CHAIN_ID),
            address(account),
            address(executor),
            _one(VB_USDC),
            _one(intentAmount),
            VALID_UNTIL,
            address(validator)
        );
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        bytes memory signature = abi.encodePacked(r, s, v);

        ISuperValidator.DstProof[] memory proofs = new ISuperValidator.DstProof[](1);
        proofs[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(KATANA_CHAIN_ID),
            info: ISuperValidator.DstInfo({
                account: address(account),
                executor: address(executor),
                dstTokens: _one(VB_USDC),
                intentAmounts: _one(intentAmount),
                validator: address(validator),
                data: executorCalldata
            })
        });
        uint64[] memory chains = new uint64[](1);
        chains[0] = uint64(KATANA_CHAIN_ID);
        sigData = abi.encode(chains, VALID_UNTIL, uint48(0), root, new bytes32[](0), proofs, signature);
    }

    function _one(address v) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = v;
    }

    function _one(uint256 v) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = v;
    }

    function _assertNoDustOnHooks() internal view {
        assertEq(IERC20(VB_USDC).balanceOf(address(swapHook)), 0);
        assertEq(IERC20(KAT).balanceOf(address(swapHook)), 0);
        assertEq(IERC20(VB_USDC).balanceOf(address(approveHook)), 0);
        assertEq(IERC20(KAT).balanceOf(address(approveHook)), 0);
        assertEq(IERC20(VB_USDC).balanceOf(address(executor)), 0, "destination executor holds nothing");
    }
}
