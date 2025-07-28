// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IStandardizedYield } from "../../src/vendor/pendle/IStandardizedYield.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { Deposit5115VaultHook } from "../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { CancelDepositRequest7540Hook } from "../../src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from
    "../../src/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";

interface IRoot {
    function endorsed(address user) external view returns (bool);
}

contract MultiVaultDepositFlow is MinimalBaseIntegrationTest {
    IStandardizedYield public vaultInstance5115ETH;

    address public underlyingETH_sUSDe;
    address public yieldSource5115AddressSUSDe;
    address public yieldSource7540AddressUSDC;
    ISuperNativePaymaster public superNativePaymaster;
    IERC7540 public vaultInstance7540ETH;

    function setUp() public override {
        blockNumber = ETH_BLOCK;

        super.setUp();

        underlyingETH_sUSDe = CHAIN_1_SUSDE;
        _getTokens(underlyingETH_sUSDe, accountEth, 1e18);

        yieldSource5115AddressSUSDe = CHAIN_1_PendleEthena;
        yieldSource7540AddressUSDC = CHAIN_1_CentrifugeUSDC;
        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);
        vaultInstance7540ETH = IERC7540(yieldSource7540AddressUSDC);

        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
    }
    receive() external payable {}

    function test_ClaimCancelDepositRequest7540Hook_WrongReceiver() public {
        address receiver = address(1_271_927);
        uint256 amount = 100e6;
        
        // Setup mocks and hooks
        (RequestDeposit7540VaultHook requestHook, CancelDepositRequest7540Hook cancelHook, ClaimCancelDepositRequest7540Hook claimHook) = 
            _setupClaimCancelDepositHooks();
        
        // Execute deposit request and cancellation
        _executeDepositRequestAndCancel(requestHook, cancelHook, amount);
        
        // Execute claim canceled deposit request
        _executeClaimCanceledDepositRequest(claimHook, receiver);
        
        // Fulfill the cancel deposit request (simulates Centrifuge chain response)
        IInvestmentManager investmentManager = _fulfillCancelDepositRequest(amount);
        
        // Verify the state after cancellation
        _verifyDepositRequestCancelled(investmentManager, amount);
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
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(this)), yieldSource7540AddressUSDC, amountPerVault, true
        );
        hooksData[2] = _createApproveHookData(underlyingETH_sUSDe, yieldSource5115AddressSUSDe, amountPerVault, false);
        hooksData[3] = _createDeposit5115VaultHookData(
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

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
     /// @notice Sets up hooks for the claim cancel deposit request test
    /// @return requestHook The request deposit hook
    /// @return cancelHook The cancel deposit request hook
    /// @return claimHook The claim cancel deposit request hook
    function _setupClaimCancelDepositHooks() private returns (
        RequestDeposit7540VaultHook,
        CancelDepositRequest7540Hook,
        ClaimCancelDepositRequest7540Hook
    ) {
        vm.mockCall(
            0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC,
            abi.encodeWithSelector(IRoot.endorsed.selector, accountEth),
            abi.encode(true)
        );

        RequestDeposit7540VaultHook requestHook = new RequestDeposit7540VaultHook();
        CancelDepositRequest7540Hook cancelHook = new CancelDepositRequest7540Hook();
        ClaimCancelDepositRequest7540Hook claimHook = new ClaimCancelDepositRequest7540Hook();
        
        return (requestHook, cancelHook, claimHook);
    }
    
    /// @notice Executes a deposit request followed by a cancellation
    /// @param requestHook_ The request deposit hook to use
    /// @param cancelHook_ The cancel deposit request hook to use
    /// @param amount_ The amount to request and cancel
    function _executeDepositRequestAndCancel(
        RequestDeposit7540VaultHook requestHook_,
        CancelDepositRequest7540Hook cancelHook_,
        uint256 amount_
    ) private {
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(requestHook_);
        hooksAddresses[2] = address(cancelHook_);

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlyingEth_USDC, yieldSource7540AddressUSDC, amount_, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSource7540AddressUSDC,
            amount_,
            true
        );
        hooksData[2] = abi.encodePacked(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSource7540AddressUSDC
        );

        // 1. Approve USDC
        // 2. Request deposit
        // 3. Cancel deposit request
        UserOpData memory userOpData = _getExecOps(
            instanceOnEth,
            superExecutorOnEth,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData }))
        );
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }
    
    /// @notice Executes claiming a canceled deposit request
    /// @param claimHook_ The claim hook to use
    /// @param receiver_ The receiver address
    function _executeClaimCanceledDepositRequest(
        ClaimCancelDepositRequest7540Hook claimHook_,
        address receiver_
    ) private {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(claimHook_);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = abi.encodePacked(
            _getYieldSourceOracleId(bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(this)),
            yieldSource7540AddressUSDC,
            receiver_
        );

        // Claim canceled deposit request
        UserOpData memory userOpData = _getExecOps(
            instanceOnEth,
            superExecutorOnEth,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData }))
        );
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }
    
    /// @notice Fulfills the cancel deposit request, simulating a Centrifuge chain response
    /// @param amount_ The amount to fulfill
    /// @return investmentManager The investment manager instance
    function _fulfillCancelDepositRequest(uint256 amount_) private returns (IInvestmentManager) {
        IInvestmentManager investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);
        address rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
        uint64 poolId = vaultInstance7540ETH.poolId();
        bytes16 trancheId = vaultInstance7540ETH.trancheId();
        IPoolManager poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);
        uint128 assetId = poolManager.assetToId(CHAIN_1_USDC);
        
        vm.startPrank(rootManager);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(amount_), uint128(amount_)
        );
        vm.stopPrank();
        
        return investmentManager;
    }
    
    /// @notice Verifies the state after a deposit request cancellation
    /// @param investmentManager_ The investment manager to check
    /// @param amount_ The original deposit amount
    function _verifyDepositRequestCancelled(
        IInvestmentManager investmentManager_,
        uint256 amount_
    ) private view {
        // Check that there's no pending deposit request after cancellation
        bool isPending = investmentManager_.pendingCancelDepositRequest(yieldSource7540AddressUSDC, accountEth);
        assertFalse(isPending, "request should be cancelled");
        
        // Check that the cancel deposit request has been processed
        uint256 pendingRequest = investmentManager_.pendingDepositRequest(yieldSource7540AddressUSDC, accountEth);
        assertEq(pendingRequest, 0, "no pending request");
        
        // Check claimable cancelled amount
        uint256 claimable = investmentManager_.claimableCancelDepositRequest(yieldSource7540AddressUSDC, accountEth);
        assertEq(claimable, amount_, "claimable cancelled amount should match the initial amount");
    }
}
