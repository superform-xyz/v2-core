// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Vm } from "forge-std/Vm.sol";

import { ApproveAndHyperCoreDepositHook } from "../../../src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol";
import { HyperCoreSendAssetHook } from "../../../src/hooks/hypercore/HyperCoreSendAssetHook.sol";
import { HyperCoreUsdClassTransferHook } from "../../../src/hooks/hypercore/HyperCoreUsdClassTransferHook.sol";
import { Helpers } from "../../utils/Helpers.sol";

/// @title HyperCoreHooksFork
/// @notice Fork tests against the REAL HyperEVM mainnet contracts (chain 999).
/// @dev What a fork can and cannot verify here:
///      - CAN: that the deployed 544-byte CoreWriter accepts our exact calldata shape and echoes
///        the hook-built payload verbatim in its RawAction log; that the real USDC + deposit
///        gateway execute the approve/deposit/reset sequence without reverting and pull exactly
///        the approved amount; that the hardcoded deploy constants point at real contracts.
///      - CANNOT: observe the HyperCore-side credit. Hyperliquid's read precompiles are node
///        logic, not EVM state, so Core effects are invisible on a fork. The byte-exact unit
///        fixtures remain the payload-correctness defence; these tests pin the EVM leg.
/// @dev Runs against HYPEREVM_RPC_URL, defaulting to the public https://rpc.hyperliquid.xyz/evm.
///      Lives under test/integration/ so the standard unit-test commands skip it.
contract HyperCoreHooksFork is Helpers {
    /*//////////////////////////////////////////////////////////////
                          REAL MAINNET ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @dev Hyperliquid CoreWriter system contract
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;
    /// @dev The real USDC ERC-20 on HyperEVM — NOT what tokenInfo.evmContract returns
    address internal constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    /// @dev Per-token HyperCore deposit gateway for USDC (tokenInfo.evmContract)
    address internal constant GATEWAY = 0x6B9E773128f453f5c2C60935Ee2DE2CBc5390A24;
    /// @dev destinationDex 0 == perp dex 0 (perp margin); type(uint32).max would be spot.
    uint32 internal constant DESTINATION_DEX = 0;

    bytes32 internal constant RAW_ACTION_TOPIC = keccak256("RawAction(address,bytes)");

    uint256 internal forkId;
    address internal account;

    HyperCoreUsdClassTransferHook internal classTransfer;
    HyperCoreSendAssetHook internal sendAsset;
    ApproveAndHyperCoreDepositHook internal depositHook;

    function setUp() public {
        forkId = vm.createFork(envOr("HYPEREVM_RPC_URL", "https://rpc.hyperliquid.xyz/evm"));
        vm.selectFork(forkId);

        account = makeAddr("hyperAccount");

        classTransfer = new HyperCoreUsdClassTransferHook(CORE_WRITER);
        sendAsset = new HyperCoreSendAssetHook(CORE_WRITER);
        depositHook = new ApproveAndHyperCoreDepositHook(USDC, GATEWAY, DESTINATION_DEX);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _header() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(0));
    }

    /// @dev Executes a hook's built sequence exactly as the smart account would: every call,
    ///      including preExecute and postExecute, originates from `account`.
    function _executeAs(address account_, Execution[] memory executions) internal {
        for (uint256 i; i < executions.length; ++i) {
            vm.prank(account_);
            (bool ok, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            require(ok, string(ret));
        }
    }

    /// @dev Returns the payload CoreWriter's RawAction log carried for `user`, asserting exactly one
    function _rawActionPayload(Vm.Log[] memory logs, address user) internal pure returns (bytes memory payload) {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == CORE_WRITER && logs[i].topics[0] == RAW_ACTION_TOPIC
                    && logs[i].topics[1] == bytes32(uint256(uint160(user)))
            ) {
                payload = abi.decode(logs[i].data, (bytes));
                ++found;
            }
        }
        assertEq(found, 1, "expected exactly one RawAction for user");
    }

    /*//////////////////////////////////////////////////////////////
                        REAL-CONTRACT SANITY
    //////////////////////////////////////////////////////////////*/

    /// @dev The deploy constants must point at real, distinct contracts on chain 999.
    function test_Fork_RealContractsMatchDeployConstants() public view {
        assertEq(block.chainid, 999, "must fork HyperEVM mainnet");

        assertGt(CORE_WRITER.code.length, 0, "CoreWriter must have code");
        assertGt(USDC.code.length, 0, "USDC must have code");
        assertGt(GATEWAY.code.length, 0, "gateway must have code");
        assertTrue(USDC != GATEWAY, "token and gateway must never be the same address");

        // The real ERC-20, not the gateway: the gateway implements no ERC-20 views.
        assertEq(IERC20Metadata(USDC).decimals(), 6, "USDC decimals");
        assertEq(IERC20Metadata(USDC).symbol(), "USDC", "USDC symbol");
    }

    /*//////////////////////////////////////////////////////////////
                    COREWRITER — REAL BYTECODE ACCEPTS OUR SHAPE
    //////////////////////////////////////////////////////////////*/

    /// @dev The deployed CoreWriter must accept the hook's calldata (selector dispatch + non-payable
    ///      guards are its only reverts) and echo the payload verbatim in RawAction. This is the
    ///      strongest statement a fork can make: what we send is what HyperCore's indexer sees.
    function test_Fork_CoreWriter_EchoesClassTransferPayload() public {
        bytes memory data = abi.encodePacked(_header(), uint64(1_000_000), true);
        Execution[] memory executions = classTransfer.build(address(0), account, data);

        vm.recordLogs();
        _executeAs(account, executions);

        bytes memory payload = _rawActionPayload(vm.getRecordedLogs(), account);
        assertEq(
            payload,
            hex"01000007" hex"00000000000000000000000000000000000000000000000000000000000f4240"
            hex"0000000000000000000000000000000000000000000000000000000000000001",
            "real CoreWriter must log the hook payload byte-for-byte"
        );
    }

    /// @dev Withdraw-to-HyperEVM shape (token 0, USDC system address) against real CoreWriter.
    function test_Fork_CoreWriter_EchoesSendAssetWithdrawPayload() public {
        bytes memory data = abi.encodePacked(
            _header(), bytes20(0x2000000000000000000000000000000000000000), uint64(0), uint64(1_000_000)
        );
        Execution[] memory executions = sendAsset.build(address(0), account, data);

        vm.recordLogs();
        _executeAs(account, executions);

        bytes memory payload = _rawActionPayload(vm.getRecordedLogs(), account);
        assertEq(
            payload,
            hex"0100000d" hex"0000000000000000000000002000000000000000000000000000000000000000"
            hex"0000000000000000000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000000000000000ffffffff"
            hex"00000000000000000000000000000000000000000000000000000000ffffffff"
            hex"0000000000000000000000000000000000000000000000000000000000000000"
            hex"00000000000000000000000000000000000000000000000000000000000f4240",
            "real CoreWriter must log the withdraw payload byte-for-byte"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT — REAL USDC + REAL GATEWAY
    //////////////////////////////////////////////////////////////*/

    /// @dev The full six-execution sequence against the real token and gateway: the gateway must
    ///      accept deposit(amount, 0), pull exactly the approved amount, and leave no allowance.
    ///      Also empirically pins destinationDex = 0 (perp margin) as an accepted call shape.
    function test_Fork_Deposit_RealGatewayPullsExactAmount() public {
        uint256 amount = 5_000_000; // 5 USDC
        deal(USDC, account, amount);

        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), amount, false);
        Execution[] memory executions = depositHook.build(address(0), account, data);
        assertEq(executions.length, 6, "pre + approve/approve/deposit/approve + post");

        _executeAs(account, executions);

        assertEq(IERC20(USDC).balanceOf(account), 0, "gateway must pull exactly the deposit amount");
        assertEq(IERC20(USDC).allowance(account, GATEWAY), 0, "no standing allowance may survive");
        assertEq(depositHook.getOutAmount(account), amount, "outAmount must equal the tokens sent to Core");
        assertEq(depositHook.getOutToken(account), USDC, "outToken must be the pinned TOKEN");
    }

    /// @dev Partial-balance deposit: only the requested amount moves, the rest stays.
    function test_Fork_Deposit_LeavesRemainderUntouched() public {
        uint256 balance = 8_000_000;
        uint256 amount = 3_000_000;
        deal(USDC, account, balance);

        bytes memory data = abi.encodePacked(bytes32(0), bytes20(0), amount, false);
        _executeAs(account, depositHook.build(address(0), account, data));

        assertEq(IERC20(USDC).balanceOf(account), balance - amount, "remainder must stay with the account");
        assertEq(depositHook.getOutAmount(account), amount, "outAmount is the balance decrease");
    }
}
