// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";

// Aave V3
import { IPool } from "../../../src/vendor/aave-v3/IPool.sol";
import { AaveV3SupplyHook } from "../../../src/hooks/loan/aave-v3/AaveV3SupplyHook.sol";
import { AaveV3WithdrawHook } from "../../../src/hooks/loan/aave-v3/AaveV3WithdrawHook.sol";
import { AaveV3BorrowHook } from "../../../src/hooks/loan/aave-v3/AaveV3BorrowHook.sol";
import { AaveV3RepayHook } from "../../../src/hooks/loan/aave-v3/AaveV3RepayHook.sol";
import { AaveV3SupplyAndBorrowHook } from "../../../src/hooks/loan/aave-v3/AaveV3SupplyAndBorrowHook.sol";
import { AaveV3RepayAndWithdrawHook } from "../../../src/hooks/loan/aave-v3/AaveV3RepayAndWithdrawHook.sol";
import { AaveV3RepayWithATokensHook } from "../../../src/hooks/loan/aave-v3/AaveV3RepayWithATokensHook.sol";

// test utils
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";

/// @title AaveV3ChainForkBase
/// @notice Shared no-mock fork harness for the Aave V3 loan hooks on non-Ethereum chains. Concrete
///         per-chain contracts override the getters; forge runs the shared trimmed core lifecycle
///         (supply, borrow, full max repay, withdraw) against the real Pool for each chain.
/// @dev WETH collateral / USDC debt. aToken & variableDebtToken resolved via getReserveData in setUp.
abstract contract AaveV3ChainForkBase is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    uint8 internal constant VARIABLE = 2;
    uint256 internal constant SUPPLY_WETH = 1e18;
    uint256 internal constant BORROW_USDC = 200e6;

    // ---- per-chain overrides ----
    function _rpcKey() internal pure virtual returns (string memory);
    function _forkBlock() internal pure virtual returns (uint256);
    function _pool() internal pure virtual returns (address);
    function _weth() internal pure virtual returns (address);
    function _usdc() internal pure virtual returns (address);

    // ---- harness state ----
    address internal account;
    AccountInstance internal instance;
    ISuperExecutor internal superExecutor;
    ISuperNativePaymaster internal paymaster;

    AaveV3SupplyHook internal supplyHook;
    AaveV3WithdrawHook internal withdrawHook;
    AaveV3BorrowHook internal borrowHook;
    AaveV3RepayHook internal repayHook;
    AaveV3SupplyAndBorrowHook internal supplyAndBorrowHook;
    AaveV3RepayAndWithdrawHook internal repayAndWithdrawHook;
    AaveV3RepayWithATokensHook internal repayWithATokensHook;

    address internal aWeth;
    address internal vUsdc;
    address internal aUsdc;

    function setUp() public virtual {
        // Skip gracefully when this chain's RPC isn't configured (keeps ftest-ci green on partial setups).
        string memory rpc = vm.envOr(_rpcKey(), string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, _forkBlock());

        ISuperLedgerConfiguration ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        instance = makeAccountInstance(keccak256(abi.encode("aave-v3-chain-acc")));
        account = instance.account;

        superExecutor = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        supplyHook = new AaveV3SupplyHook();
        withdrawHook = new AaveV3WithdrawHook();
        borrowHook = new AaveV3BorrowHook();
        repayHook = new AaveV3RepayHook();
        supplyAndBorrowHook = new AaveV3SupplyAndBorrowHook();
        repayAndWithdrawHook = new AaveV3RepayAndWithdrawHook();
        repayWithATokensHook = new AaveV3RepayWithATokensHook();
        paymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        aWeth = IPool(_pool()).getReserveData(_weth()).aTokenAddress;
        vUsdc = IPool(_pool()).getReserveData(_usdc()).variableDebtTokenAddress;
        aUsdc = IPool(_pool()).getReserveData(_usdc()).aTokenAddress;
        require(aWeth != address(0) && vUsdc != address(0) && aUsdc != address(0), "reserves not found");

        _getTokens(_weth(), account, 10e18);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                           ENCODERS / EXEC
    //////////////////////////////////////////////////////////////*/
    function _hdr() private pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(0));
    }

    function _sw(address loan, address coll, uint256 amt) private view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loan, coll, _pool(), amt, false);
    }

    function _br(address loan, address coll, uint8 mode, uint256 amt) private view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loan, coll, _pool(), mode, amt, false);
    }

    // combined (supplyAndBorrow / repayAndWithdraw): ...pool, rate, amount1, amount2, usePrev
    function _cb(address loan, address coll, uint256 a1, uint256 a2) private view returns (bytes memory) {
        return abi.encodePacked(_hdr(), loan, coll, _pool(), VARIABLE, a1, a2, false);
    }

    function _exec(address hook, bytes memory data) private {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory datas = new bytes[](1);
        datas[0] = data;
        _execMany(hooks, datas);
    }

    function _execMany(address[] memory hooks, bytes[] memory datas) private {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: datas });
        UserOpData memory op = _getExecOps(instance, superExecutor, abi.encode(entry));
        executeOpsThroughPaymaster(op, paymaster, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                               TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Chain_Supply() external {
        _exec(address(supplyHook), _sw(_usdc(), _weth(), SUPPLY_WETH));
        assertApproxEqAbs(IERC20(aWeth).balanceOf(account), SUPPLY_WETH, 2, "aWETH minted");
    }

    function test_Chain_SupplyThenBorrow() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _sw(_usdc(), _weth(), SUPPLY_WETH);
        datas[1] = _br(_usdc(), _weth(), VARIABLE, BORROW_USDC);

        uint256 usdcBefore = IERC20(_usdc()).balanceOf(account);
        _execMany(hooks, datas);

        assertEq(IERC20(_usdc()).balanceOf(account) - usdcBefore, BORROW_USDC, "USDC borrowed");
        assertGt(IERC20(vUsdc).balanceOf(account), 0, "has debt");
    }

    function test_Chain_Repay_Full_Max() external {
        address[] memory hooks = new address[](2);
        hooks[0] = address(supplyHook);
        hooks[1] = address(borrowHook);
        bytes[] memory datas = new bytes[](2);
        datas[0] = _sw(_usdc(), _weth(), SUPPLY_WETH);
        datas[1] = _br(_usdc(), _weth(), VARIABLE, BORROW_USDC);
        _execMany(hooks, datas);

        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_000);
        _getTokens(_usdc(), account, IERC20(_usdc()).balanceOf(account) + 20e6);

        _exec(address(repayHook), _br(_usdc(), _weth(), VARIABLE, type(uint256).max));
        assertEq(IERC20(vUsdc).balanceOf(account), 0, "debt cleared, no dust");
    }

    function test_Chain_Withdraw_Partial() external {
        _exec(address(supplyHook), _sw(_usdc(), _weth(), SUPPLY_WETH));
        uint256 aBefore = IERC20(aWeth).balanceOf(account);
        _exec(address(withdrawHook), _sw(_usdc(), _weth(), SUPPLY_WETH / 2));
        assertApproxEqAbs(aBefore - IERC20(aWeth).balanceOf(account), SUPPLY_WETH / 2, 2, "aWETH burned");
    }

    /// @notice Combined SupplyAndBorrow in a single hook, per chain.
    function test_Chain_SupplyAndBorrow() external {
        uint256 usdcBefore = IERC20(_usdc()).balanceOf(account);
        _exec(address(supplyAndBorrowHook), _cb(_usdc(), _weth(), SUPPLY_WETH, BORROW_USDC));
        assertEq(IERC20(_usdc()).balanceOf(account) - usdcBefore, BORROW_USDC, "USDC borrowed");
        assertGt(IERC20(vUsdc).balanceOf(account), 0, "has debt");
        assertGt(IERC20(aWeth).balanceOf(account), 0, "has collateral");
    }

    /// @notice Combined RepayAndWithdraw: full repay (max) + full withdraw (max), per chain.
    function test_Chain_RepayAndWithdraw_Full() external {
        _exec(address(supplyAndBorrowHook), _cb(_usdc(), _weth(), SUPPLY_WETH, BORROW_USDC));

        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 50_000);
        _getTokens(_usdc(), account, IERC20(_usdc()).balanceOf(account) + 20e6); // cover interest

        _exec(address(repayAndWithdrawHook), _cb(_usdc(), _weth(), type(uint256).max, type(uint256).max));
        assertEq(IERC20(vUsdc).balanceOf(account), 0, "debt cleared");
        assertEq(IERC20(aWeth).balanceOf(account), 0, "collateral fully withdrawn");
    }

    /// @notice Leverage-unwind via repayWithATokens (aUSDC in the collateral slot; no approval), per chain.
    function test_Chain_RepayWithATokens() external {
        _exec(address(supplyAndBorrowHook), _cb(_usdc(), _weth(), SUPPLY_WETH, BORROW_USDC));
        // Supply the borrowed USDC back to mint aUSDC, so the account can repay debt with aTokens.
        _exec(address(supplyHook), _sw(_usdc(), _usdc(), BORROW_USDC));

        uint256 debtBefore = IERC20(vUsdc).balanceOf(account);
        assertGt(debtBefore, 0, "has USDC debt");
        assertGt(IERC20(aUsdc).balanceOf(account), 0, "has aUSDC");

        _exec(address(repayWithATokensHook), _br(_usdc(), aUsdc, VARIABLE, type(uint256).max));
        assertLt(IERC20(vUsdc).balanceOf(account), debtBefore, "debt reduced via aTokens");
    }
}
