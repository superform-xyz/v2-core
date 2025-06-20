// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import "forge-std/Test.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ModuleKitHelpers, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import "forge-std/console2.sol";
import { Redeem4626VaultHook } from "../../src/core/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { ISuperLedgerData } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";

/// @dev Forked mainnet test with deposit and redeem flow for a real ERC4626 vault
contract ERC4626DepositRedeemFlowTest is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
    }

    function test_failsToRedeemFullBalance() public {
        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingInflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, amount, 1e18);
        executeOp(userOpData);

        // user transfers some shares from other account to op's sender
        deal(address(vaultInstanceEth), address(this), 10);
        IERC4626(vaultInstanceEth).transfer(accountEth, 10);

        uint256 accSharesAfter = vaultInstanceEth.balanceOf(accountEth);

        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;
        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressEth,
            accountEth,
            accSharesAfter,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});

        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingOutflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, accSharesAfter, 0);

        executeOp(userOpData);
        // ^ does not revert anymore
        
        // ASSERTIONS
        
        uint256 finalShareBalance = vaultInstanceEth.balanceOf(accountEth);
        assertEq(finalShareBalance, 0);
        
        uint256 expectedTokensReturned = IERC4626(yieldSourceAddressEth).convertToAssets(accSharesAfter);
        uint256 actualTokenBalance = IERC20(underlyingEth_USDC).balanceOf(accountEth);
        assertGt(actualTokenBalance, 0);
        

    }

    function test_Deposit_4626_Mainnet_Flow() public {
        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function test_Deposit_Redeem_4626_Mainnet_Flow() public {
        uint256 amount = 1e8;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSourceAddressEth, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingInflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, amount, 1e18);
        executeOp(userOpData);

        uint256 accSharesAfter = vaultInstanceEth.balanceOf(accountEth);
        assertEq(accSharesAfter, vaultInstanceEth.previewDeposit(amount));

        hooksAddresses = new address[](1);
        hooksAddresses[0] = redeem4626Hook;
        hooksData = new bytes[](1);
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressEth,
            accountEth,
            accSharesAfter / 2, // temporary
            false
        );

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryWithdraw));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerData.AccountingOutflow(accountEth, yieldSourceOracle, yieldSourceAddressEth, accSharesAfter, 0);

        executeOp(userOpData);
    }

    function test_ShareBalance_NotMiscalculated() public {
        uint256 amount = IERC20(underlyingEth_USDC).balanceOf(accountEth);
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = approveAndDeposit4626Hook;
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceAddressEth,
            underlyingEth_USDC,
            amount,
            false,
            address(0),
            0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);

        uint256 yieldSourceBal = IERC20(yieldSourceAddressEth).balanceOf(accountEth);

        address accountEth2 = instanceOnEth2.account;

        vm.startPrank(accountEth);
        IERC20(yieldSourceAddressEth).transfer(accountEth2, yieldSourceBal);
        vm.stopPrank();

        vm.startPrank(accountEth2);
        IERC20(yieldSourceAddressEth).approve(accountEth, yieldSourceBal);
        vm.stopPrank();

        hooksAddresses[0] = redeem4626Hook;
        hooksData[0] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSourceAddressEth, accountEth2, yieldSourceBal, false
        );
        entry = ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        uint256 expectedFee = ledger.previewFees(accountEth, yieldSourceAddressEth, IERC4626(yieldSourceAddressEth).convertToAssets(yieldSourceBal), yieldSourceBal, 100);

        executeOp(userOpData);

        uint256 outAmount = Redeem4626VaultHook(redeem4626Hook).outAmount();
        uint256 usedShares = Redeem4626VaultHook(redeem4626Hook).usedShares();
        vm.assertGt(usedShares, 0);
        vm.assertGt(outAmount, 0);

        vm.assertEq(expectedFee, IERC20(underlyingEth_USDC).balanceOf(makeAddr("feeRecipient")));
    }
}
