// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { SuperExecutor } from "../../../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../../../src/paymaster/SuperNativePaymaster.sol";
import { NativeFeeSponsorship } from "../../../../src/sponsorship/NativeFeeSponsorship.sol";
import { ISuperNativePaymaster } from "../../../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperExecutor } from "../../../../src/interfaces/ISuperExecutor.sol";
import { FetchNativeFeeHook } from "../../../../src/hooks/sponsorship/FetchNativeFeeHook.sol";
import { HyperCoreGasTopUpHook } from "../../../../src/hooks/hypercore/HyperCoreGasTopUpHook.sol";
import { NativeTransferHook } from "../../../../src/hooks/tokens/NativeTransferHook.sol";
import { TransferERC20Hook } from "../../../../src/hooks/tokens/erc20/TransferERC20Hook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockLedger, MockLedgerConfiguration } from "../../../mocks/MockLedger.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { GasTopUpReceiver, GasTopUpSourceHook } from "./HyperCoreGasTopUpHook.t.sol";

/// @notice RPC-free real EntryPoint/paymaster/account/executor tests; the system receiver is mocked.
/// @dev These prove EVM funding identity and pipeline behavior, not actual HyperCore credit or finality.
contract HyperCoreGasTopUpUserOpTest is Helpers, RhinestoneModuleKit {
    using ModuleKitHelpers for *;

    address private constant HYPE_SYSTEM = 0x2222222222222222222222222222222222222222;
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant PRINCIPAL = 7 ether;
    uint256 private constant TOP_UP = 0.01 ether;

    AccountInstance private instance;
    SuperExecutor private executor;
    SuperNativePaymaster private paymaster;
    NativeFeeSponsorship private sponsorship;
    FetchNativeFeeHook private fetch;
    HyperCoreGasTopUpHook private topUp;
    GasTopUpReceiver private receiver;
    address private recipient;

    receive() external payable { }

    function setUp() public {
        instance = makeAccountInstance(keccak256("HyperCoreGasTopUpUserOp"));
        recipient = makeAddr("principal recipient");
        MockLedgerConfiguration ledgerConfig =
            new MockLedgerConfiguration(address(new MockLedger()), recipient, address(0), 0, address(this));
        executor = new SuperExecutor(address(ledgerConfig));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(executor), data: "" });
        paymaster = new SuperNativePaymaster(IEntryPoint(address(instance.aux.entrypoint)));
        sponsorship = new NativeFeeSponsorship();
        fetch = new FetchNativeFeeHook(address(sponsorship));
        topUp = new HyperCoreGasTopUpHook();
        vm.etch(HYPE_SYSTEM, address(new GasTopUpReceiver()).code);
        receiver = GasTopUpReceiver(payable(HYPE_SYSTEM));
        vm.deal(address(this), 100 ether);
        vm.deal(instance.account, 0);
    }

    function _run(address token, address consumer, bytes memory consumerData) private {
        GasTopUpSourceHook source = new GasTopUpSourceHook(token, PRINCIPAL);
        address[] memory hooks = new address[](4);
        hooks[0] = address(source);
        hooks[1] = address(fetch);
        hooks[2] = address(topUp);
        hooks[3] = consumer;
        bytes[] memory data = new bytes[](4);
        data[0] = "";
        data[1] = abi.encodePacked(bytes32(0), address(0), address(this), TOP_UP);
        data[2] = abi.encodePacked(bytes32(0), address(0), TOP_UP);
        data[3] = consumerData;
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry(hooks, data);
        UserOpData memory userOp = instance.getExecOps(
            address(executor),
            0,
            abi.encodeCall(executor.execute, (abi.encode(entry))),
            address(instance.defaultValidator)
        );
        // Same paymaster envelope as the existing bundler/UserOp test helpers.
        userOp.userOp.paymasterAndData = abi.encodePacked(
            address(paymaster), uint128(2e6), uint128(1e6), abi.encode(uint256(2e6), uint256(0), uint256(1e5))
        );
        userOp = userOp.signDefault();
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp.userOp;
        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits = new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit(instance.account, TOP_UP);
        paymaster.sponsorNativeAndHandleOps{ value: TOP_UP + 1 ether }(ops, deposits, address(sponsorship));
    }

    function _nativeConsumerData() private view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), address(0), recipient, PRINCIPAL);
    }

    function _assertSuccessfulFunding(address token) private view {
        assertEq(receiver.lastSender(), instance.account, "Core actor must be the executing account");
        assertEq(receiver.lastValue(), TOP_UP);
        assertEq(receiver.lastData().length, 0);
        assertEq(receiver.totalReceived(), TOP_UP);
        assertEq(sponsorship.sponsoredAmount(address(this), instance.account), 0);
        assertEq(address(topUp).balance, 0);
        assertEq(topUp.getOutAmount(instance.account), PRINCIPAL);
        assertEq(topUp.getOutToken(instance.account), token);
        assertEq(topUp.lastCaller(), address(executor));
    }

    function test_UserOpFetchAndTopUpPreserveNativePrincipal() public {
        vm.deal(instance.account, PRINCIPAL);
        _run(NATIVE_TOKEN, address(new NativeTransferHook()), _nativeConsumerData());
        _assertSuccessfulFunding(NATIVE_TOKEN);
        assertEq(recipient.balance, PRINCIPAL, "signed principal must not fund the top-up");
    }

    function test_UserOpFetchAndTopUpPreserveERC20Principal() public {
        MockERC20 token = new MockERC20("Test principal", "TST", 18);
        token.mint(instance.account, PRINCIPAL);
        bytes memory consumerData =
            abi.encodePacked(bytes32(0), address(0), address(token), recipient, uint256(0), true);
        _run(address(token), address(new TransferERC20Hook()), consumerData);
        _assertSuccessfulFunding(address(token));
        assertEq(token.balanceOf(recipient), PRINCIPAL);
        assertEq(token.balanceOf(instance.account), 0);
    }

    function test_CaughtUserOpFailureLeavesUnusedAdvanceReclaimable() public {
        // Funding the fee cannot make up missing original principal. EntryPoint
        // catches execution failure, so the outer predeposit remains in the ledger.
        _run(NATIVE_TOKEN, address(new NativeTransferHook()), _nativeConsumerData());
        assertEq(receiver.totalReceived(), 0, "the reverted account transfer must roll back");
        assertEq(recipient.balance, 0);
        assertEq(sponsorship.sponsoredAmount(address(this), instance.account), TOP_UP);
        sponsorship.withdrawSponsorDeposit(instance.account, payable(address(this)), TOP_UP);
        assertEq(sponsorship.sponsoredAmount(address(this), instance.account), 0);
    }
}
