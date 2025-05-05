// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IPendleRouterV4, TokenInput, SwapData, SwapType } from "../../../src/vendor/pendle/IPendleRouterV4.sol";
import { PendleRouterRedeemHook } from "../../../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PendleRouterRedeemHookTest is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    IERC20 public eUSDe;
    IERC20 public yt;
    IERC20 public pt;

    uint256 public constant expiry = 22_411_332;

    PendleRouterRedeemHook public redeemHook;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        // Token Out = Token Redeem Sy = Ethena USDe
        eUSDe = IERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3);

        // YT Ethena USDe
        yt = IERC20(0x733Ee9Ba88f16023146EbC965b7A1Da18a322464);

        // PT Ethena USDe
        pt = IERC20(0x917459337CaAC939D41d7493B3999f571D20D667);

        deal(address(eUSDe), account, 10e18);

        redeemHook = new PendleRouterRedeemHook(PENDLE_ROUTERS[ETH]);
    }

    function test_PendleRouterRedeemHook() public {
        vm.warp(22_384_742);

        uint256 eUSDeBalance = eUSDe.balanceOf(account);
        uint256 ptBalance = pt.balanceOf(account);

        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(eUSDe),
            netTokenIn: 1e18,
            tokenMintSy: address(eUSDe),
            pendleSwap: address(0),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: bytes(""), needScale: false })
        });

        vm.startPrank(account);
        eUSDe.approve(address(IPendleRouterV4(PENDLE_ROUTERS[ETH])), 1e18);
        IPendleRouterV4(PENDLE_ROUTERS[ETH]).mintPyFromToken(
            account, // receiver
            address(yt), // YT
            0.7e18, // minPyOut
            tokenInput
        );

        assertEq(eUSDe.balanceOf(account), eUSDeBalance - 1e18);
        assertGt(pt.balanceOf(account), ptBalance);

        vm.warp(expiry + 1 days);

        address[] memory hooks = new address[](1);
        hooks[0] = address(redeemHook);

        bytes[] memory data = new bytes[](1);
        data[0] =
            _createPendleRedeemHookData(1e18, address(yt), address(pt), address(eUSDe), address(eUSDe), 1e17, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });

        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));

        executeOp(userOpData);

        assertEq(eUSDe.balanceOf(account), eUSDeBalance);
        assertEq(pt.balanceOf(account), ptBalance);
    }
}
