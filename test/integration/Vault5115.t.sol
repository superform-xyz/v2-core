// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IStandardizedYield } from "../../src/vendor/pendle/IStandardizedYield.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { Deposit5115VaultHook } from "../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { Redeem5115VaultHook } from "../../src/hooks/vaults/5115/Redeem5115VaultHook.sol";
import "forge-std/console2.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract Redeem5115VaultBugTest is MinimalBaseIntegrationTest {
    IStandardizedYield public vaultInstance5115ETH;

    address public underlyingETH_sUSDe;

    address public yieldSource5115AddressSUSDe;

    address public yieldSource7540AddressUSDC;

    function setUp() public override {
        blockNumber = ETH_BLOCK;

        super.setUp();

        underlyingETH_sUSDe = CHAIN_1_SUSDE;
        _getTokens(underlyingETH_sUSDe, accountEth, 1e18);

        yieldSource5115AddressSUSDe = CHAIN_1_PendleEthena;

        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);
        address shareToken = address(vaultInstance5115ETH);
        _getTokens(shareToken, address(vaultInstance5115ETH), 1e8 / 2);
    }

    function test_IncorrectUsedSharesInRedeem5115VaultHook() public {
        uint256 amount = 1e8;
        uint256 amountPerVault = amount / 2;

        assertEq(vaultInstance5115ETH.balanceOf(address(vaultInstance5115ETH)), amountPerVault);

        uint256 accountSUSDEStartBalance = IERC20(underlyingETH_sUSDe).balanceOf(accountEth);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(new Deposit5115VaultHook());
        vm.mockCall(
            0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC,
            abi.encodeWithSelector(IRoot.endorsed.selector, accountEth),
            abi.encode(true)
        );
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_sUSDe, yieldSource5115AddressSUSDe, amountPerVault, false);
        hooksData[1] = _createDeposit5115VaultHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSource5115AddressSUSDe,
            underlyingETH_sUSDe,
            amountPerVault,
            0,
            true,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        vm.expectEmit(true, true, true, false);
        emit IStandardizedYield.Deposit(accountEth, accountEth, underlyingETH_sUSDe, amountPerVault, amountPerVault);
        executeOp(userOpData);

        // Check asset balances
        assertEq(IERC20(underlyingETH_sUSDe).balanceOf(accountEth), accountSUSDEStartBalance - amountPerVault);

        // Check vault shares balances
        assertEq(vaultInstance5115ETH.balanceOf(accountEth), amountPerVault);

        address[] memory hooksAddressesRedeem = new address[](1);
        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksAddressesRedeem[0] = address(new Redeem5115VaultHook());
        hooksDataRedeem[0] = _create5115RedeemHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            address(vaultInstance5115ETH),
            underlyingETH_sUSDe,
            amountPerVault,
            0,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryRedeem =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpDataRedeem = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryRedeem));
        executeOp(userOpDataRedeem);

        assertEq(vaultInstance5115ETH.balanceOf(accountEth), 0, "A");
        assertEq(vaultInstance5115ETH.balanceOf(address(vaultInstance5115ETH)), amountPerVault, "B");
        //TODO: compute exact fee
        assertLt(IERC20(underlyingETH_sUSDe).balanceOf(accountEth), accountSUSDEStartBalance, "C");
        vm.clearMockedCalls();
    }
}
