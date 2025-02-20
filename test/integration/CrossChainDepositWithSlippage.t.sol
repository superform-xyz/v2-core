// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { SuperRegistry } from "../../src/core/settings/SuperRegistry.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IOdosRouterV2 } from "../../src/vendor/odos/IOdosRouterV2.sol";

// Two briding actions to the same chain, Across gateway waits for both to arrive
// Two target vaults where one requires a swap due to underlying mismatch which incurs slippage
contract CrossChainDepositWithSlippage is BaseTest {
    IERC4626 public vaultInstance4626Base_USDC;
    IERC4626 public vaultInstance4626Base_WETH;

    address public addressOracleBase_4626;

    address public underlyingBase_USDC;
    address public underlyingBase_WETH;
    address public underlyingETH_USDC;
    address public underlyingOP_USDC;

    address public swapRouter;

    address public feeRecipientBase;

    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;

    IYieldSourceOracle public yieldSourceOracleBase_4626;
    IYieldSourceOracle public yieldSourceOracleBase_WETH;

    address public accountOP;
    address public accountETH;
    address public accountBase;

    AccountInstance public instanceOnOP;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnBase;

    ISuperExecutor public superExecutorOnOP;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnBase;

    SuperRegistry public superRegistryBase;

    string public constant YIELD_SOURCE_ORACLE_4626_BASE = "YieldSourceOracle_4626";

    string public constant YIELD_SOURCE_4626_BASE_USDC_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_BASE_WETH_KEY = "ERC4626_BASE_WETH";

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[BASE]);

        superRegistryBase = SuperRegistry(_getContract(BASE, SUPER_REGISTRY_KEY));

        feeRecipientBase = superRegistryBase.getAddress(keccak256(bytes(PAYMASTER_ID)));

        vm.selectFork(FORKS[ETH]);

        // Set up the underlying tokens
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];

        // Set up the 4626 USDC yield source on BASE
        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];

        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);

        // Set up the 4626 WETH yield source on BASE
        yieldSource4626AddressBase_WETH =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_WETH_CORE_KEY][WETH_KEY];

        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);

        // Set up the yield source oracle
        addressOracleBase_4626 = _getContract(BASE, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleBase_4626, YIELD_SOURCE_ORACLE_4626_BASE);
        yieldSourceOracleBase_4626 = IYieldSourceOracle(addressOracleBase_4626);

        // Set up the accounts
        accountOP = accountInstances[OP].account;
        accountETH = accountInstances[ETH].account;
        accountBase = accountInstances[BASE].account;

        instanceOnOP = accountInstances[OP];
        instanceOnETH = accountInstances[ETH];
        instanceOnBase = accountInstances[BASE];

        // Set up the Super Executors
        superExecutorOnOP = ISuperExecutor(_getContract(OP, "SuperExecutor"));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, "SuperExecutor"));
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, "SuperExecutor"));

        vm.selectFork(FORKS[BASE]);

        // Set up the 1inch swap router
        deal(underlyingBase_WETH, odosRouters[BASE], 1e12);
    }

    /*//////////////////////////////////////////////////////////////
                           FULL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CrossChainDepositWithSlippage() public {
        _sendFundsFromOpToBase();
        _sendFundsFromEthToBase();
    }

    /*//////////////////////////////////////////////////////////////
                           PARTIAL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Must be called before _sendFundsFromEthToBase
    function _sendFundsFromOpToBase() internal {
        uint256 intentAmount = 1e10;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // Transfer users USDC to this contract so that balance checks are correct
        uint256 amountToRemove = IERC20(underlyingBase_USDC).balanceOf(accountBase);
        vm.prank(accountBase);
        IERC20(underlyingBase_USDC).transfer(address(this), amountToRemove);

        // PREPARE DST DATA
        address[] memory dstHooksAddresses = new address[](2);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory dstHooksData = new bytes[](2);
        dstHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, yieldSource4626AddressBase_USDC, intentAmount / 2, false);
        dstHooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressBase_USDC,
            intentAmount / 2,
            false,
            false
        );

        UserOpData memory dstUserOpData = _createUserOpData(dstHooksAddresses, dstHooksData, BASE);

        // OP IS SRC1
        vm.selectFork(FORKS[OP]);

        // PREPARE SRC1 DATA
        address[] memory src1HooksAddresses = new address[](2);
        src1HooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        src1HooksAddresses[1] = _getHookAddress(OP, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory src1HooksData = new bytes[](2);
        src1HooksData[0] =
            _createApproveHookData(underlyingOP_USDC, SPOKE_POOL_V3_ADDRESSES[OP], intentAmount / 2, false);
        src1HooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingOP_USDC,
            underlyingBase_USDC,
            intentAmount / 2,
            intentAmount / 2,
            BASE,
            false,
            intentAmount,
            dstUserOpData
        );

        UserOpData memory src1UserOpData = _createUserOpData(src1HooksAddresses, src1HooksData, OP);

        // not enough balance is received
        _processAcrossV3Message(OP, BASE, executeOp(src1UserOpData), RELAYER_TYPE.NOT_ENOUGH_BALANCE, accountBase);
    }

    function _sendFundsFromEthToBase() internal {
        uint256 intentAmount = 1e10;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        // PREPARE DST DATA
        address[] memory dstHooksAddresses = new address[](4);
        dstHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[1] = _getHookAddress(BASE, SWAP_ODOS_HOOK_KEY);
        dstHooksAddresses[2] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        dstHooksAddresses[3] = _getHookAddress(BASE, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory dstHooksData = new bytes[](4);
        dstHooksData[0] = _createApproveHookData(underlyingBase_USDC, odosRouters[BASE], intentAmount / 2, false);
        dstHooksData[1] = _createOdosSwapHookData(
            underlyingBase_USDC,
            intentAmount / 2,
            address(this),
            underlyingBase_WETH,
            intentAmount / 2,
            0,
            bytes(""),
            odosRouters[BASE],
            0,
            true
        );
        dstHooksData[2] =
            _createApproveHookData(underlyingBase_WETH, yieldSource4626AddressBase_WETH, intentAmount / 2, true);
        dstHooksData[3] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressBase_WETH,
            intentAmount / 2,
            true,
            false
        );

        UserOpData memory dstUserOpData = _createUserOpData(dstHooksAddresses, dstHooksData, BASE);

        // ETH IS SRC1
        vm.selectFork(FORKS[ETH]);

        // PREPARE SRC1 DATA
        address[] memory src1HooksAddresses = new address[](2);
        src1HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        src1HooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory src1HooksData = new bytes[](2);
        src1HooksData[0] = _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], intentAmount, false);
        src1HooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC,
            underlyingBase_USDC,
            intentAmount / 2,
            intentAmount / 2,
            BASE,
            false,
            intentAmount,
            dstUserOpData
        );

        UserOpData memory src1UserOpData = _createUserOpData(src1HooksAddresses, src1HooksData, ETH);

        // enough balance is received
        _processAcrossV3Message(ETH, BASE, executeOp(src1UserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);

        vm.selectFork(FORKS[BASE]);

        uint256 sharesExpectedWETH 
        = vaultInstance4626Base_WETH.convertToShares((intentAmount / 2) - ((intentAmount / 2) * 50 / 10_000));

        uint256 sharesWETH = IERC4626(yieldSource4626AddressBase_WETH).balanceOf(accountBase);
        assertEq(sharesWETH, sharesExpectedWETH);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    // Creates userOpData for the given chainId
    function _createUserOpData(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        uint64 chainId
    )
        internal
        returns (UserOpData memory)
    {
        if (chainId == ETH) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));
        } else if (chainId == OP) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute));
        } else {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        }
    }
}
