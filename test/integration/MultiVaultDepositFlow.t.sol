// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { IStandardizedYield } from "../../src/vendor/pendle/IStandardizedYield.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { Deposit5115VaultHook } from "../../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../../src/core/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract MultiVaultDepositFlow is MinimalBaseIntegrationTest {
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

        yieldSource7540AddressUSDC = CHAIN_1_CentrifugeUSDC;

        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);
    }

    function test_MultiVault_Deposit_Flow() public {
        uint256 amount = 1e8;
        uint256 amountPerVault = amount / 2;

        uint256 accountUSDCStartBalance = IERC20(underlyingEth_USDC).balanceOf(accountEth);
        uint256 accountSUSDEStartBalance = IERC20(underlyingETH_sUSDe).balanceOf(accountEth);

        address[] memory hooksAddresses = new address[](4);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(new RequestDeposit7540VaultHook());
        hooksAddresses[2] = approveHook;
        hooksAddresses[3] = address(new Deposit5115VaultHook());
        vm.mockCall(
            0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC,
            abi.encodeWithSelector(IRoot.endorsed.selector, accountEth),
            abi.encode(true)
        );
        bytes[] memory hooksData = new bytes[](4);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSource7540AddressUSDC, amountPerVault, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), yieldSource7540AddressUSDC, amountPerVault, true
        );
        hooksData[2] = _createApproveHookData(underlyingETH_sUSDe, yieldSource5115AddressSUSDe, amountPerVault, false);
        hooksData[3] = _createDeposit5115VaultHookData(
            bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
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
        emit IERC7540.DepositRequest(accountEth, accountEth, 0, accountEth, amountPerVault);
        vm.expectEmit(true, true, true, false);
        emit IStandardizedYield.Deposit(accountEth, accountEth, underlyingETH_sUSDe, amountPerVault, amountPerVault);
        executeOp(userOpData);

        // Check asset balances
        assertEq(IERC20(underlyingEth_USDC).balanceOf(accountEth), accountUSDCStartBalance - amountPerVault);
        assertEq(IERC20(underlyingETH_sUSDe).balanceOf(accountEth), accountSUSDEStartBalance - amountPerVault);

        // Check vault shares balances
        assertEq(vaultInstance5115ETH.balanceOf(accountEth), amountPerVault);

        vm.clearMockedCalls();
    }
}
