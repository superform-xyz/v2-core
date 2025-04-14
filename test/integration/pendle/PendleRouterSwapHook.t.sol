// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";

import "forge-std/console2.sol";

contract PendleRouterSwapHook is BaseTest {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;

    address public pendlePufETHMarket;

    function setUp() public override {
        useLatestFork = true;
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        token = CHAIN_1_USDC;
        pendlePufETHMarket = 0x58612beB0e8a126735b19BB222cbC7fC2C162D2a;
    }

    // tx example: https://etherscan.io/tx/0x36b2c58e314e9d9bf73fc0d632ed228e35cd6b840066d12d39f72c633bad27a5
    function test_PendleRouterSwap_Token_To_Pt() public {
        uint256 amount = 1e6;

        // get tokens
        deal(token, account, amount);
        IPendleMarket _market = IPendleMarket(pendlePufETHMarket);
        (address sy, address pt,) = _market.readTokens();
        // note syTokenIns [1] is WETH for this SY, which should have high liquidity
        address[] memory syTokenIns = IStandardizedYield(sy).getTokensIn();

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hookAddresses_[1] = _getHookAddress(ETH, PENDLE_ROUTER_SWAP_HOOK_KEY);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, PENDLE_ROUTERS[ETH], amount, false);
        hookData[1] = _createPendleRouterSwapHookDataWithOdos(
            pendlePufETHMarket, account, false, 1 ether, false, amount, CHAIN_1_USDC, syTokenIns[1], ETH
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });
        UserOpData memory opData = _getExecOps(
            instance, superExecutor, abi.encode(entryToExecute), _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY)
        );
        opData.userOp.paymasterAndData = bytes("");

        executeOp(opData);

        uint256 balance = IERC20(pt).balanceOf(account);
        assertGt(balance, 0);
    }

    /**
     * struct PendleRouterSwapHookData {
     *     bool ptToToken;
     *     uint256 value;
     *     bool usePrevHookAmount;
     *
     *     // pendle router swap params token to PT
     *     address receiver;
     *     address market;
     *     uint256 minPtOut;
     *     ApproxParams guessPtOut;
     *     TokenInput input;
     *     LimitOrderData limit;
     * }
     *
     * function _createExtCallDataOdos(address _account, uint256 _amount) internal view returns (bytes memory) {
     *     (,address pt,) = IPendleMarket(pendlePufETHMarket).readTokens();
     *     IOdosRouterV2.swapTokenInfo memory swapTokenInfo = _createOdosSwap(
     *         CHAIN_1_USDC, //inputToken
     *         _amount, //inputAmount
     *         _account, //inputReceiver
     *         pt, //outputToken
     *         1, //outputQuote
     *         1, //outputMin
     *         _account //outputReceiver
     *     );
     *     return abi.encodeWithSelector(
     *         IOdosRouterV2.swap.selector,
     *         swapTokenInfo,
     *         hex"020203000701010102423a1323c871abc9d89eb06855bf5347048fc4a5000000000000000000000496ff00000000000000000000000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831da10009cbd5d07dd0cecc66161fc93d7c9000da1",
     * // path definition; what?
     *         0xfb2139331532e3ee59777FBbcB14aF674f3fd671, // executor? what ? TODO: determinet this?
     *         0
     *     );
     * }
     */
}
