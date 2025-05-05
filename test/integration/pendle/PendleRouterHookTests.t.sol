// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";

import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IPendleRouterV4, TokenInput, SwapData, SwapType } from "../../../src/vendor/pendle/IPendleRouterV4.sol";
import { PendleRouterRedeemHook } from "../../../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
import { PendleRouterSwapHook } from "../../../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { ApproveERC20Hook } from "../../../src/core/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract PendleRouterHookTests is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;

    address public pendlePufETHMarket;

    ApproveERC20Hook public approveHook;
    PendleRouterSwapHook public swapHook;

    IERC20 public eUSDe;
    IERC20 public yt_eUSDe;
    IERC20 public pt_eUSDe;

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
        yt_eUSDe = IERC20(0x733Ee9Ba88f16023146EbC965b7A1Da18a322464);

        // PT Ethena USDe
        pt_eUSDe = IERC20(0x917459337CaAC939D41d7493B3999f571D20D667);

        deal(address(eUSDe), account, 10e18);

        redeemHook = new PendleRouterRedeemHook(PENDLE_ROUTERS[ETH]);

        token = CHAIN_1_USDC;
        pendlePufETHMarket = 0x58612beB0e8a126735b19BB222cbC7fC2C162D2a;

        approveHook = new ApproveERC20Hook();
        swapHook = new PendleRouterSwapHook(PENDLE_ROUTERS[ETH]);
    }

    // tx example: https://etherscan.io/tx/0x36b2c58e314e9d9bf73fc0d632ed228e35cd6b840066d12d39f72c633bad27a5
    function test_PendleRouterSwap_Token_To_Pt() public {
        if (!useRealOdosRouter) {
            return;
        }
        uint256 amount = 1e6;

        // get tokens
        deal(token, account, amount);
        IPendleMarket _market = IPendleMarket(pendlePufETHMarket);
        (address sy, address pt,) = _market.readTokens();
        // note syTokenIns [1] is WETH for this SY, which should have high liquidity
        address[] memory syTokenIns = IStandardizedYield(sy).getTokensIn();
        uint256 balance = IERC20(pt).balanceOf(account);
        assertEq(balance, 0);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = address(approveHook);
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, PENDLE_ROUTERS[ETH], amount, false);
        hookData[1] = _createPendleRouterSwapHookDataWithOdos(
            pendlePufETHMarket, account, false, 1 ether, false, amount, CHAIN_1_USDC, syTokenIns[1], ETH
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute)
        );

        executeOp(opData);

        balance = IERC20(pt).balanceOf(account);
        assertGt(balance, 0);
    }

    // mintPyFromToken tx example:https://etherscan.io/inputdatadecoder?tx=0xa5af7fe6016b5683f48e36e79bd300728b352fa45262d153426167d0d89862fa
    // redeemPyToToken tx example: https://etherscan.io/inputdatadecoder?tx=0xca0e4932ecb628b2996ba1f24089f9faa98ccc2451afa14fbb964336fa6351c0
    function test_PendleRouterRedeemHook() public {
        vm.warp(22_384_742);

        uint256 eUSDeBalance = eUSDe.balanceOf(account);
        uint256 ptBalance = pt_eUSDe.balanceOf(account); // 0

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
            address(yt_eUSDe), // YT
            0.7e18, // minPyOut
            tokenInput
        );

        assertEq(eUSDe.balanceOf(account), eUSDeBalance - 1e18);
        assertGt(pt_eUSDe.balanceOf(account), ptBalance);

        vm.warp(expiry + 1 days);

        address[] memory hooks = new address[](1);
        hooks[0] = address(redeemHook);

        bytes[] memory data = new bytes[](1);
        data[0] =
            _createPendleRedeemHookData(1e18, address(yt_eUSDe), address(pt_eUSDe), address(eUSDe), address(eUSDe), 1e17, false);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });

        UserOpData memory userOpData = _getExecOps(instance, superExecutor, abi.encode(entry));

        executeOp(userOpData);

        assertEq(eUSDe.balanceOf(account), eUSDeBalance);
        assertEq(pt_eUSDe.balanceOf(account), ptBalance);
    }
}