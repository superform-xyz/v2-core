// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { NativeFeeSponsorship } from "../../../src/sponsorship/NativeFeeSponsorship.sol";
import { INativeFeeSponsorship } from "../../../src/interfaces/INativeFeeSponsorship.sol";
import { FetchNativeFeeHook } from "../../../src/hooks/sponsorship/FetchNativeFeeHook.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { MockEntryPoint } from "../../mocks/MockEntryPoint.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/*//////////////////////////////////////////////////////////////
                     STARGATE STRUCTS (minimal)
//////////////////////////////////////////////////////////////*/

struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

/*//////////////////////////////////////////////////////////////
                        MOCK STARGATE POOL
//////////////////////////////////////////////////////////////*/

/// @notice Simulates Stargate V2 IStargate.sendToken() consuming msg.value for LayerZero messaging fees
contract MockStargatePool {
    address public immutable token;
    uint256 public totalNativeReceived;
    uint256 public totalTokensReceived;

    constructor(address token_) {
        token = token_;
    }

    function sendToken(
        SendParam calldata p,
        MessagingFee calldata fee,
        address refund
    )
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory)
    {
        require(msg.value >= fee.nativeFee, "insufficient native fee");

        IERC20(token).transferFrom(msg.sender, address(this), p.amountLD);

        totalNativeReceived += fee.nativeFee;
        totalTokensReceived += p.amountLD;

        // Refund excess native to refundAddress
        uint256 excess = msg.value - fee.nativeFee;
        if (excess > 0) {
            (bool ok,) = payable(refund).call{ value: excess }("");
            require(ok, "refund failed");
        }

        MessagingReceipt memory receipt = MessagingReceipt({
            guid: keccak256(abi.encodePacked(block.timestamp, p.dstEid)),
            nonce: 1,
            fee: fee
        });

        OFTReceipt memory oftReceipt =
            OFTReceipt({ amountSentLD: p.amountLD, amountReceivedLD: p.amountLD });

        return (receipt, oftReceipt);
    }
}

/*//////////////////////////////////////////////////////////////
                    SMART ACCOUNT MOCK
//////////////////////////////////////////////////////////////*/

/// @notice Minimal smart account that can receive ETH and execute arbitrary calls
contract MockSmartAccount {
    receive() external payable { }

    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{ value: value }(data);
        require(ok, "execution failed");
        return ret;
    }
}

/*//////////////////////////////////////////////////////////////
                   INTEGRATION TEST
//////////////////////////////////////////////////////////////*/

/// @title NativeFeeSponsorshipE2E
/// @notice End-to-end integration tests for the native fee sponsorship flow:
///         bundler sponsors ETH -> paymaster deposits to sponsorship -> account withdraws via hook -> bridge uses ETH
contract NativeFeeSponsorshipE2E is Test {
    NativeFeeSponsorship public sponsorship;
    FetchNativeFeeHook public fetchHook;
    SuperNativePaymaster public paymaster;
    MockEntryPoint public mockEntryPoint;
    MockStargatePool public stargatePool;
    MockERC20 public usdc;

    MockSmartAccount public account;
    MockSmartAccount public account2;
    address public bundler;

    function setUp() public {
        // Deploy core contracts
        sponsorship = new NativeFeeSponsorship();
        mockEntryPoint = new MockEntryPoint();
        paymaster = new SuperNativePaymaster(IEntryPoint(address(mockEntryPoint)));
        fetchHook = new FetchNativeFeeHook(address(sponsorship));

        // Deploy mock bridge
        usdc = new MockERC20("USDC", "USDC", 6);
        stargatePool = new MockStargatePool(address(usdc));

        // Deploy smart accounts
        account = new MockSmartAccount();
        account2 = new MockSmartAccount();
        vm.label(address(account), "SmartAccount1");
        vm.label(address(account2), "SmartAccount2");

        // Setup bundler
        bundler = makeAddr("bundler");
        vm.deal(bundler, 100 ether);
        vm.deal(address(mockEntryPoint), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
              TEST 1: Deposit then hook withdraw
    //////////////////////////////////////////////////////////////*/

    /// @notice Bundler deposits to sponsorship, account withdraws via FetchNativeFeeHook
    function test_deposit_then_hookWithdraw() public {
        uint256 sponsorAmount = 0.1 ether;

        // 1. Bundler deposits to sponsorship for account
        vm.prank(bundler);
        sponsorship.depositForAccount{ value: sponsorAmount }(bundler, address(account));

        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), sponsorAmount);

        // 2. Build hook executions
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), bundler, sponsorAmount);
        Execution[] memory executions = fetchHook.build(address(0), address(account), hookData);

        // 3. Account executes the hook chain
        uint256 accountBalBefore = address(account).balance;
        _executePrank(executions, address(account));

        // 4. Verify: account received ETH, sponsorship drained
        assertEq(address(account).balance - accountBalBefore, sponsorAmount);
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), 0);
    }

    /*//////////////////////////////////////////////////////////////
              TEST 2: FetchHook then mock Stargate bridge
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain: FetchNativeFeeHook -> MockStargatePool.sendToken
    function test_fetchHook_then_mockStargateBridge() public {
        uint256 nativeFee = 0.05 ether;
        uint256 bridgeAmount = 1000e6; // 1000 USDC

        // 1. Deposit sponsorship
        vm.prank(bundler);
        sponsorship.depositForAccount{ value: nativeFee }(bundler, address(account));

        // 2. Mint USDC to account and approve stargate pool
        usdc.mint(address(account), bridgeAmount);
        vm.prank(address(account));
        usdc.approve(address(stargatePool), bridgeAmount);

        // 3. Build & execute FetchNativeFeeHook
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), bundler, nativeFee);
        Execution[] memory fetchExecs = fetchHook.build(address(0), address(account), hookData);
        _executePrank(fetchExecs, address(account));

        assertEq(address(account).balance, nativeFee);

        // 4. Account calls MockStargatePool.sendToken with native fee
        SendParam memory sendParam = SendParam({
            dstEid: 30_101,
            to: bytes32(uint256(uint160(address(account)))),
            amountLD: bridgeAmount,
            minAmountLD: bridgeAmount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory msgFee = MessagingFee({ nativeFee: nativeFee, lzTokenFee: 0 });

        vm.prank(address(account));
        account.execute(
            address(stargatePool),
            nativeFee,
            abi.encodeCall(MockStargatePool.sendToken, (sendParam, msgFee, address(account)))
        );

        // 5. Verify: pool received native fee and tokens
        assertEq(stargatePool.totalNativeReceived(), nativeFee);
        assertEq(stargatePool.totalTokensReceived(), bridgeAmount);
        assertEq(address(account).balance, 0); // all native used
    }

    /*//////////////////////////////////////////////////////////////
              TEST 3: Paymaster deposits to sponsorship
    //////////////////////////////////////////////////////////////*/

    /// @notice sponsorNativeAndHandleOps deposits correct amounts per account into NativeFeeSponsorship
    function test_paymaster_deposits_to_sponsorship() public {
        uint256 nativeAmount = 0.5 ether;

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(address(account));

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: nativeAmount });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(sponsorship));

        // Verify sponsorship received the deposit (bundler is sponsor of record)
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), nativeAmount);
        assertEq(address(sponsorship).balance, nativeAmount);
    }

    /*//////////////////////////////////////////////////////////////
              TEST 4: Full paymaster to hook withdraw
    //////////////////////////////////////////////////////////////*/

    /// @notice Full flow: paymaster deposits via sponsorNativeAndHandleOps -> account FetchNativeFeeHook withdraws
    function test_full_paymaster_to_hookWithdraw() public {
        uint256 nativeAmount = 0.2 ether;

        // 1. Paymaster deposits sponsorship
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(address(account));

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: nativeAmount });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.2 ether }(ops, deposits, address(sponsorship));

        // 2. Verify sponsorship balance (bundler is sponsor of record)
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), nativeAmount);

        // 3. Account withdraws via FetchNativeFeeHook (sponsor = bundler)
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), bundler, nativeAmount);
        Execution[] memory executions = fetchHook.build(address(0), address(account), hookData);

        uint256 accountBalBefore = address(account).balance;
        _executePrank(executions, address(account));

        // 4. Verify: account has ETH, sponsorship is empty
        assertEq(address(account).balance - accountBalBefore, nativeAmount);
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), 0);
    }

    /*//////////////////////////////////////////////////////////////
              TEST 5: Multiple accounts separate sponsorship
    //////////////////////////////////////////////////////////////*/

    /// @notice Two accounts with independent sponsorship balances
    function test_multiple_accounts_separate_sponsorship() public {
        uint256 amount1 = 0.3 ether;
        uint256 amount2 = 0.2 ether;

        // 1. Paymaster deposits for both accounts
        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _createUserOp(address(account));
        ops[1] = _createUserOp(address(account2));

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](2);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: amount1 });
        deposits[1] = ISuperNativePaymaster.NativeFeeDeposit({ account: address(account2), amount: amount2 });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(sponsorship));

        // 2. Verify independent balances (bundler is sponsor of record)
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), amount1);
        assertEq(sponsorship.sponsoredAmount(bundler, address(account2)), amount2);

        // 3. Account1 withdraws via hook (set execution context like SuperExecutor does)
        fetchHook.setExecutionContext(address(account));
        bytes memory hookData1 = abi.encodePacked(bytes32(0), address(0), bundler, amount1);
        Execution[] memory execs1 = fetchHook.build(address(0), address(account), hookData1);
        _executePrank(execs1, address(account));

        assertEq(address(account).balance, amount1);
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), 0);

        // 4. Account2 still has its balance intact
        assertEq(sponsorship.sponsoredAmount(bundler, address(account2)), amount2);

        // 5. Account2 withdraws via hook (fresh execution context)
        fetchHook.setExecutionContext(address(account2));
        bytes memory hookData2 = abi.encodePacked(bytes32(0), address(0), bundler, amount2);
        Execution[] memory execs2 = fetchHook.build(address(0), address(account2), hookData2);
        _executePrank(execs2, address(account2));

        assertEq(address(account2).balance, amount2);
        assertEq(sponsorship.sponsoredAmount(bundler, address(account2)), 0);
    }

    /*//////////////////////////////////////////////////////////////
              TEST 6: Sponsor reclaims unused deposit
    //////////////////////////////////////////////////////////////*/

    /// @notice Bundler deposits for account, then reclaims via withdrawSponsorDeposit
    function test_sponsor_reclaims_unused() public {
        uint256 depositAmount = 0.5 ether;

        // 1. Deposit
        vm.prank(bundler);
        sponsorship.depositForAccount{ value: depositAmount }(bundler, address(account));
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), depositAmount);

        // 2. Reclaim
        uint256 bundlerBalBefore = bundler.balance;
        vm.prank(bundler);
        sponsorship.withdrawSponsorDeposit(address(account), payable(bundler), depositAmount);

        // 3. Verify
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), 0);
        assertEq(bundler.balance - bundlerBalBefore, depositAmount);
    }

    /*//////////////////////////////////////////////////////////////
              TEST 7: FetchHook reverts on insufficient balance
    //////////////////////////////////////////////////////////////*/

    /// @notice FetchNativeFeeHook execution reverts when sponsorship balance < requested amount
    function test_fetchHook_reverts_insufficient_balance() public {
        uint256 depositAmount = 0.1 ether;
        uint256 requestAmount = 0.5 ether;

        // 1. Deposit less than what hook will request
        vm.prank(bundler);
        sponsorship.depositForAccount{ value: depositAmount }(bundler, address(account));

        // 2. Build hook with larger amount
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), bundler, requestAmount);
        Execution[] memory executions = fetchHook.build(address(0), address(account), hookData);

        // 3. Execute: preExecute succeeds, but withdrawal call (index 1) reverts
        vm.startPrank(address(account));

        // preExecute succeeds
        (bool ok0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(ok0, "preExecute should succeed");

        // Withdrawal reverts due to insufficient balance
        (bool ok1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertFalse(ok1, "withdrawal should fail with insufficient balance");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
              TEST 8: Excess native stays on account
    //////////////////////////////////////////////////////////////*/

    /// @notice Account fetches more ETH than bridge needs; excess stays on account
    function test_excess_native_stays_on_account() public {
        uint256 sponsorAmount = 0.1 ether;
        uint256 bridgeNativeFee = 0.03 ether;
        uint256 bridgeAmount = 500e6; // 500 USDC

        // 1. Deposit sponsorship
        vm.prank(bundler);
        sponsorship.depositForAccount{ value: sponsorAmount }(bundler, address(account));

        // 2. Mint USDC and approve
        usdc.mint(address(account), bridgeAmount);
        vm.prank(address(account));
        usdc.approve(address(stargatePool), bridgeAmount);

        // 3. Withdraw full sponsored amount via hook
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), bundler, sponsorAmount);
        Execution[] memory execs = fetchHook.build(address(0), address(account), hookData);
        _executePrank(execs, address(account));

        assertEq(address(account).balance, sponsorAmount);

        // 4. Bridge with only part of the native ETH
        SendParam memory sendParam = SendParam({
            dstEid: 30_101,
            to: bytes32(uint256(uint160(address(account)))),
            amountLD: bridgeAmount,
            minAmountLD: bridgeAmount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory msgFee = MessagingFee({ nativeFee: bridgeNativeFee, lzTokenFee: 0 });

        vm.prank(address(account));
        account.execute(
            address(stargatePool),
            bridgeNativeFee,
            abi.encodeCall(MockStargatePool.sendToken, (sendParam, msgFee, address(account)))
        );

        // 5. Verify: excess native stays on account, not recoverable by bundler
        uint256 excess = sponsorAmount - bridgeNativeFee;
        assertEq(address(account).balance, excess);
        assertEq(stargatePool.totalNativeReceived(), bridgeNativeFee);

        // Bundler cannot reclaim — sponsorship is already drained
        assertEq(sponsorship.sponsoredAmount(bundler, address(account)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes an array of Execution structs as the given caller (prank pattern from CCTP fork tests)
    function _executePrank(Execution[] memory executions, address caller) internal {
        vm.startPrank(caller);
        for (uint256 i; i < executions.length; i++) {
            (bool ok,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            require(ok, "execution failed");
        }
        vm.stopPrank();
    }

    /// @notice Creates a minimal PackedUserOperation for testing with paymaster
    function _createUserOp(address sender) internal view returns (PackedUserOperation memory) {
        PackedUserOperation memory op;
        op.sender = sender;
        op.nonce = uint256(1);
        op.initCode = "";
        op.callData = "";
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(100_000), uint128(150_000)));
        op.preVerificationGas = 50_000;
        op.gasFees = bytes32(abi.encodePacked(uint128(10 gwei), uint128(5 gwei)));
        op.paymasterAndData = abi.encodePacked(address(paymaster));
        op.signature = "";
        return op;
    }
}
