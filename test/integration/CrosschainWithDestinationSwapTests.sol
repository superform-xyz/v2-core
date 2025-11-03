// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IDlnSource } from "../../src/vendor/bridges/debridge/IDlnSource.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import "modulekit/test/RhinestoneModuleKit.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { BytesLib } from "../../src/vendor/BytesLib.sol";
import { ModeLib, ModeCode } from "modulekit/accounts/common/lib/ModeLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { INexusBootstrap } from "../../src/vendor/nexus/INexusBootstrap.sol";
import { IPermit2 } from "../../src/vendor/uniswap/permit2/IPermit2.sol";
import { IPermit2Batch } from "../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperLedger, ISuperLedgerData } from "../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperDestinationExecutor } from "../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../src/interfaces/ISuperValidator.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutorBase } from "../../src/executors/SuperExecutorBase.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { AcrossV3Adapter } from "../../src/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../../src/adapters/DebridgeAdapter.sol";
import { SuperValidatorBase } from "../../src/validators/SuperValidatorBase.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { BaseLedger } from "../../src/accounting/BaseLedger.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { SwapUniswapV4Hook } from "../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { UniswapV4Parser } from "../utils/parsers/UniswapV4Parser.sol";
import { UniswapV4QuoteHelper } from "./uniswap-v4/UniswapV4QuoteHelper.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency } from "v4-core/types/Currency.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { PoolId, PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

contract CrosschainWithDestinationSwapTests is BaseTest {
    // Test account must include receive() function to handle EntryPoint fee refunds
    receive() external payable { }

    using ModuleKitHelpers for *;
    using ExecutionLib for *;
    using StateLibrary for IPoolManager;

    address public rootManager;

    INexusBootstrap nexusBootstrap;

    IAllowanceTransfer public permit2;
    IPermit2Batch public permit2Batch;
    bytes32 public permit2DomainSeparator;

    address public validatorSigner;
    uint256 public validatorSignerPrivateKey;

    uint256 public CHAIN_1_TIMESTAMP;
    uint256 public CHAIN_10_TIMESTAMP;
    uint256 public CHAIN_8453_TIMESTAMP;
    uint256 public WARP_START_TIME; // Sep 11, 2025 - after market lastUpdate

    // ACCOUNTS PER CHAIN
    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;
    address public accountBase;
    address public accountETH;
    address public accountOP;

    // VAULTS/LOGIC related contracts
    address public underlyingETH_USDC;
    address public underlyingBase_USDC;
    address public underlyingOP_USDC;
    address public underlyingOP_USDCe;
    address public underlyingBase_WETH;

    IERC4626 public vaultInstance4626OP;
    IERC4626 public vaultInstance4626Base_USDC;
    IERC4626 public vaultInstance4626Base_WETH;
    IERC4626 public vaultInstanceEth;
    IERC4626 public vaultInstanceMorphoBase;
    address public yieldSource4626AddressOP_USDCe;
    address public yieldSource4626AddressBase_USDC;
    address public yieldSource4626AddressBase_WETH;
    address public yieldSourceUsdcAddressEth;
    address public yieldSourceMorphoUsdcAddressBase;
    address public yieldSourceSparkUsdcAddressBase;

    address public addressOracleOP;
    address public addressOracleETH;
    address public addressOracleBase;
    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleOP;

    uint256 public balance_Base_USDC_Before;

    string public constant YIELD_SOURCE_4626_BASE_USDC_KEY = "ERC4626_BASE_USDC";
    string public constant YIELD_SOURCE_4626_BASE_WETH_KEY = "ERC4626_BASE_WETH";

    string public constant YIELD_SOURCE_4626_OP_USDCe_KEY = "YieldSource_4626_OP_USDCe";
    string public constant YIELD_SOURCE_ORACLE_4626_KEY = "YieldSourceOracle_4626";

    // SUPERFORM CONTRACTS PER CHAIN
    // -- executors
    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;
    ISuperDestinationExecutor public superTargetExecutorOnBase;
    ISuperDestinationExecutor public superTargetExecutorOnETH;
    ISuperDestinationExecutor public superTargetExecutorOnOP;

    // -- crosschain adapter
    AcrossV3Adapter public acrossV3AdapterOnBase;
    AcrossV3Adapter public acrossV3AdapterOnETH;
    AcrossV3Adapter public acrossV3AdapterOnOP;
    DebridgeAdapter public debridgeAdapterOnBase;
    DebridgeAdapter public debridgeAdapterOnETH;
    DebridgeAdapter public debridgeAdapterOnOP;

    // -- validators
    IValidator public destinationValidatorOnBase;
    IValidator public destinationValidatorOnETH;
    IValidator public destinationValidatorOnOP;
    IValidator public sourceValidatorOnBase;
    IValidator public sourceValidatorOnETH;
    IValidator public sourceValidatorOnOP;

    // -- ledgers
    ISuperLedger public superLedgerETH;
    ISuperLedger public superLedgerOP;

    // -- paymasters
    ISuperNativePaymaster public superNativePaymasterOnBase;
    ISuperNativePaymaster public superNativePaymasterOnETH;
    ISuperNativePaymaster public superNativePaymasterOnOP;

    // UniswapV4 pool configuration for this test
    PoolKey public wethUsdcPoolKey;
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    int24 public constant TICK_SPACING_MEDIUM = 60;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        useLatestFork = true;
        super.setUp();

        // CORE CHAIN CONTEXT
        vm.selectFork(FORKS[ETH]);
        CHAIN_1_TIMESTAMP = block.timestamp;

        vm.selectFork(FORKS[OP]);
        CHAIN_10_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[BASE]);
        CHAIN_8453_TIMESTAMP = block.timestamp;
        vm.selectFork(FORKS[ETH]);

        // ROOT/NEXUS/SIGNER
        nexusBootstrap = INexusBootstrap(CHAIN_1_NEXUS_BOOTSTRAP);
        vm.label(address(nexusBootstrap), "NexusBootstrap");

        (validatorSigner, validatorSignerPrivateKey) = makeAddrAndKey("The signer");
        vm.label(validatorSigner, "The signer");

        rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        // ACCOUNTS PER CHAIN
        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;
        accountOP = accountInstances[OP].account;

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];
        instanceOnOP = accountInstances[OP];

        // VAULTS/LOGIC related contracts
        underlyingBase_WETH = existingUnderlyingTokens[BASE][WETH_KEY];
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDC = existingUnderlyingTokens[OP][USDC_KEY];
        vm.label(underlyingOP_USDC, "underlyingOP_USDC");
        underlyingOP_USDCe = existingUnderlyingTokens[OP][USDCE_KEY];
        vm.label(underlyingOP_USDCe, "underlyingOP_USDCe");

        yieldSource4626AddressOP_USDCe = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCE_KEY];
        vaultInstance4626OP = IERC4626(yieldSource4626AddressOP_USDCe);
        vm.label(yieldSource4626AddressOP_USDCe, YIELD_SOURCE_4626_OP_USDCe_KEY);

        yieldSource4626AddressBase_USDC =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstance4626Base_USDC = IERC4626(yieldSource4626AddressBase_USDC);
        vm.label(yieldSource4626AddressBase_USDC, YIELD_SOURCE_4626_BASE_USDC_KEY);

        yieldSource4626AddressBase_WETH = realVaultAddresses[BASE][ERC4626_VAULT_KEY][AAVE_BASE_WETH][WETH_KEY];
        vaultInstance4626Base_WETH = IERC4626(yieldSource4626AddressBase_WETH);
        vm.label(yieldSource4626AddressBase_WETH, YIELD_SOURCE_4626_BASE_WETH_KEY);

        yieldSourceUsdcAddressEth = 0xe0a80d35bB6618CBA260120b279d357978c42BCE; // SuperVault on ETH
        vaultInstanceEth = IERC4626(yieldSourceUsdcAddressEth);
        vm.label(yieldSourceUsdcAddressEth, "EULER_VAULT");

        yieldSourceMorphoUsdcAddressBase =
            realVaultAddresses[BASE][ERC4626_VAULT_KEY][MORPHO_GAUNTLET_USDC_PRIME_KEY][USDC_KEY];
        vaultInstanceMorphoBase = IERC4626(yieldSourceMorphoUsdcAddressBase);
        vm.label(yieldSourceMorphoUsdcAddressBase, "YIELD_SOURCE_MORPHO_USDC_BASE");

        yieldSourceSparkUsdcAddressBase = realVaultAddresses[BASE][ERC4626_VAULT_KEY][SPARK_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSourceSparkUsdcAddressBase, "YIELD_SOURCE_SPARK_USDC_BASE");

        // ORACLES
        addressOracleETH = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        yieldSourceOracleETH = IYieldSourceOracle(addressOracleETH);

        addressOracleOP = _getContract(OP, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        yieldSourceOracleOP = IYieldSourceOracle(addressOracleOP);

        // SUPERFORM CONTRACTS PER CHAIN
        // -- executors
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));

        superTargetExecutorOnBase = ISuperDestinationExecutor(_getContract(BASE, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnETH = ISuperDestinationExecutor(_getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY));
        superTargetExecutorOnOP = ISuperDestinationExecutor(_getContract(OP, SUPER_DESTINATION_EXECUTOR_KEY));

        // -- crosschain adapter
        acrossV3AdapterOnBase = AcrossV3Adapter(_getContract(BASE, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnETH = AcrossV3Adapter(_getContract(ETH, ACROSS_V3_ADAPTER_KEY));
        acrossV3AdapterOnOP = AcrossV3Adapter(_getContract(OP, ACROSS_V3_ADAPTER_KEY));

        debridgeAdapterOnBase = DebridgeAdapter(_getContract(BASE, DEBRIDGE_ADAPTER_KEY));
        debridgeAdapterOnETH = DebridgeAdapter(_getContract(ETH, DEBRIDGE_ADAPTER_KEY));
        debridgeAdapterOnOP = DebridgeAdapter(_getContract(OP, DEBRIDGE_ADAPTER_KEY));

        // -- validators
        destinationValidatorOnBase = IValidator(_getContract(BASE, SUPER_DESTINATION_VALIDATOR_KEY));
        destinationValidatorOnETH = IValidator(_getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY));
        destinationValidatorOnOP = IValidator(_getContract(OP, SUPER_DESTINATION_VALIDATOR_KEY));

        sourceValidatorOnBase = IValidator(_getContract(BASE, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnETH = IValidator(_getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY));
        sourceValidatorOnOP = IValidator(_getContract(OP, SUPER_MERKLE_VALIDATOR_KEY));

        // -- paymasters
        superNativePaymasterOnBase = ISuperNativePaymaster(_getContract(BASE, SUPER_NATIVE_PAYMASTER_KEY));
        superNativePaymasterOnETH = ISuperNativePaymaster(_getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY));
        superNativePaymasterOnOP = ISuperNativePaymaster(_getContract(OP, SUPER_NATIVE_PAYMASTER_KEY));

        // -- ledgers
        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        superLedgerOP = ISuperLedger(_getContract(OP, SUPER_LEDGER_KEY));

        // -- UniswapV4 pool setup for this test
        vm.selectFork(FORKS[ETH]);
        wethUsdcPoolKey = PoolKey({
            currency0: Currency.wrap(underlyingETH_USDC), // USDC
            currency1: Currency.wrap(underlyingETH_WETH), // WETH
            fee: FEE_MEDIUM,
            tickSpacing: TICK_SPACING_MEDIUM,
            hooks: IHooks(address(0))
        });

        // BALANCES
        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test bridge from BASE to ETH with destination UniswapV4 swap and deposit
    /// @dev Bridge USDC from BASE to ETH, swap WETH to USDC via UniswapV4, then deposit USDC to vault
    /// @dev Real user flow: Bridge WETH, approve WETH (with 20% fee reduction), swap WETH to USDC via V4,
    /// approve USDC, deposit USDC
    /// @dev This test demonstrates real UniswapV4 integration in crosschain context with proper hook chaining
    function test_Bridge_To_ETH_With_UniswapV4_Swap_And_Deposit() public {
        uint256 amountPerVault = 0.01 ether; // 0.01 WETH (18 decimals)
        WARP_START_TIME = block.timestamp;
        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA - 4 hooks: approve WETH (with 20% reduction), swap WETH to USDC, approve USDC, deposit USDC
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;
        uint256 feeReductionPercentage = 2000; // 20% reduction
        {
            // Calculate the amount after 20% fee reduction for the swap
            uint256 adjustedWETHAmount = amountPerVault - (amountPerVault * feeReductionPercentage / 10_000); // 20%
            // reduction

            (, accountToUse) = _createAccountCreationData_DestinationExecutor(
                AccountCreationParams({
                    senderCreatorOnDestinationChain: _getContract(ETH, SUPER_SENDER_CREATOR_KEY),
                    validatorOnDestinationChain: _getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY),
                    superMerkleValidator: _getContract(ETH, SUPER_MERKLE_VALIDATOR_KEY),
                    theSigner: validatorSigner,
                    executorOnDestinationChain: _getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY),
                    superExecutor: _getContract(ETH, SUPER_EXECUTOR_KEY),
                    nexusFactory: CHAIN_1_NEXUS_FACTORY,
                    nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                    is7702: false
                })
            );

            address[] memory dstHookAddresses = new address[](4);
            dstHookAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            dstHookAddresses[1] = _getHookAddress(ETH, SWAP_UNISWAP_V4_HOOK_KEY);
            dstHookAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            dstHookAddresses[3] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

            // Create real hook data with the actual account
            bytes[] memory dstHookData = new bytes[](4);

            // Hook 1: Approve WETH (first hook after bridging receives the actual bridged amount)
            dstHookData[0] = _createApproveHookData(
                getWETHAddress(), // WETH (received from bridge)
                _getHookAddress(ETH, SWAP_UNISWAP_V4_HOOK_KEY), // Approve to UniswapV4 hook
                adjustedWETHAmount, // amount (the exact amount that will be received from bridge after fees)
                false // usePrevHookAmount = false
            );

            // Hook 2: Generate UniswapV4 quote and calldata for WETH -> USDC swap
            bool zeroForOne = getWETHAddress() < underlyingETH_USDC; // Determine swap direction based on token ordering
            SwapUniswapV4Hook uniV4Hook = SwapUniswapV4Hook(payable(_getHookAddress(ETH, SWAP_UNISWAP_V4_HOOK_KEY)));

            // Calculate appropriate price limit with 1% slippage tolerance
            uint160 priceLimit = _calculatePriceLimit(wethUsdcPoolKey, zeroForOne, 100);

            // Get realistic minimum using UniswapV4 quote helper
            UniswapV4QuoteHelper.QuoteResult memory quote = UniswapV4QuoteHelper.getQuote(
                IPoolManager(MAINNET_V4_POOL_MANAGER),
                UniswapV4QuoteHelper.QuoteParams({
                    poolKey: wethUsdcPoolKey,
                    zeroForOne: zeroForOne,
                    amountIn: adjustedWETHAmount,
                    sqrtPriceLimitX96: priceLimit
                })
            );
            uint256 expectedMinUSDC = quote.amountOut * 995 / 1000; // Apply 0.5% additional slippage buffer

            // Generate swap calldata using the parser (inherited from BaseTest)
            dstHookData[1] = generateSingleHopSwapCalldata(
                UniswapV4Parser.SingleHopParams({
                    poolKey: wethUsdcPoolKey,
                    dstReceiver: accountToUse,
                    sqrtPriceLimitX96: priceLimit,
                    originalAmountIn: adjustedWETHAmount,
                    originalMinAmountOut: expectedMinUSDC,
                    maxSlippageDeviationBps: feeReductionPercentage, // 20% max deviation
                    zeroForOne: zeroForOne,
                    additionalData: ""
                }),
                true // usePrevHookAmount = true (use approved WETH amount from previous hook)
            );

            // Hook 3: Approve USDC to vault (use prev hook amount = USDC from swap)
            dstHookData[2] = _createApproveHookData(
                underlyingETH_USDC, // USDC (output from swap)
                yieldSourceUsdcAddressEth, // USDC vault address
                0, // amount (will use prev hook output)
                true // usePrevHookAmount
            );

            // Hook 4: Deposit USDC to vault (use prev hook amount)
            dstHookData[3] = _createDeposit4626HookData(
                _getYieldSourceOracleId(bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), MANAGER),
                yieldSourceUsdcAddressEth,
                0, // amount (will use prev hook output)
                true, // usePrevHookAmount
                address(0), // receiver (account)
                0 // minShares
            );

            messageData = TargetExecutorMessage({
                hooksAddresses: dstHookAddresses,
                hooksData: dstHookData,
                validator: _getContract(ETH, SUPER_DESTINATION_VALIDATOR_KEY),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: _getContract(ETH, SUPER_DESTINATION_EXECUTOR_KEY),
                nexusFactory: CHAIN_1_NEXUS_FACTORY,
                nexusBootstrap: CHAIN_1_NEXUS_BOOTSTRAP,
                chainId: uint64(ETH),
                amount: adjustedWETHAmount,
                account: address(0), // Pass address(0) so account creation data is included
                tokenSent: getWETHAddress()
            });
            address finalAccount;
            (targetExecutorMessage, finalAccount) = _createTargetExecutorMessage(messageData, false);
            assertEq(finalAccount, accountToUse, "Account mismatch");
        }

        console2.log(
            " ETH[DST] WETH account balance before (should be 0)", IERC20(getWETHAddress()).balanceOf(accountToUse)
        );
        console2.log(
            " ETH[DST] USDC account balance before (should be 0)", IERC20(underlyingETH_USDC).balanceOf(accountToUse)
        );
        console2.log(
            " ETH[DST] Vault balance for dst account before (should be 0)",
            IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountToUse)
        );

        // BASE IS SRC
        SELECT_FORK_AND_WARP(BASE, WARP_START_TIME);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] = _createApproveHookData(
            underlyingBase_WETH, // approve BASE WETH
            SPOKE_POOL_V3_ADDRESSES[BASE], // to Across pool
            amountPerVault,
            false
        );
        // Use the new helper with fee reduction capability
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookDataWithFeeReduction(
            underlyingBase_WETH, // from BASE WETH
            getWETHAddress(), // to ETH WETH
            amountPerVault,
            amountPerVault,
            ETH,
            false, // usePrevHookAmount = false for bridge
            feeReductionPercentage,
            targetExecutorMessage
        );

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE, true);
        bytes memory signatureData = _createMerkleRootAndSignature(
            messageData, srcUserOpData.userOpHash, accountToUse, ETH, address(sourceValidatorOnBase)
        );
        srcUserOpData.userOp.signature = signatureData;

        console2.log("[SRC] Account", srcUserOpData.userOp.sender);
        console2.log("[DST] Account  ", accountToUse);

        // EXECUTE BASE
        ExecutionReturnData memory executionData =
            executeOpsThroughPaymaster(srcUserOpData, superNativePaymasterOnBase, 1e18);

        _processAcrossV3Message(
            ProcessAcrossV3MessageParams({
                srcChainId: BASE,
                dstChainId: ETH,
                warpTimestamp: WARP_START_TIME + 1 minutes,
                executionData: executionData,
                relayerType: RELAYER_TYPE.ENOUGH_BALANCE,
                errorMessage: bytes4(0),
                errorReason: "",
                root: bytes32(0),
                account: accountToUse,
                relayerGas: 0
            })
        );

        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME + 2 minutes);

        uint256 finalWETHBalance = IERC20(getWETHAddress()).balanceOf(accountToUse);
        uint256 finalUSDCBalance = IERC20(underlyingETH_USDC).balanceOf(accountToUse);
        uint256 finalVaultBalance = IERC4626(yieldSourceUsdcAddressEth).balanceOf(accountToUse);

        console2.log(" ETH[DST] WETH account balance after (should be 0 - all swapped)", finalWETHBalance);
        console2.log(" ETH[DST] USDC account balance after (should be 0 - all deposited)", finalUSDCBalance);
        console2.log(" ETH[DST] Vault balance for dst account after (should be > 0)", finalVaultBalance);

        // Verify the crosschain swap and deposit worked
        assertEq(finalUSDCBalance, 0, "USDC should be fully deposited");
        assertGt(finalVaultBalance, 0, "Should have vault shares from USDC deposit");
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create UserOpData for given chain and hooks
    /// @param hooksAddresses Array of hook addresses to execute
    /// @param hooksData Array of encoded hook data
    /// @param chainId Chain ID to execute on
    /// @param withValidator Whether to use validator
    /// @return UserOpData struct ready for execution
    function _createUserOpData(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        uint64 chainId,
        bool withValidator
    )
        internal
        returns (UserOpData memory)
    {
        if (chainId == ETH) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(
                    instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute), address(sourceValidatorOnETH)
                );
            }
            return _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));
        } else if (chainId == OP) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(
                    instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute), address(sourceValidatorOnOP)
                );
            }
            return _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute));
        } else {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            if (withValidator) {
                return _getExecOpsWithValidator(
                    instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute), address(sourceValidatorOnBase)
                );
            }
            return _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        }
    }

    /// @notice WETH address on Ethereum
    address public constant underlyingETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Get WETH from existing tokens mapping
    /// @dev Using WETH_KEY from BaseTest which should be defined in token mappings
    function getWETHAddress() internal pure returns (address) {
        // Try to get WETH from existing mappings first, fallback to hardcoded mainnet address
        return underlyingETH_WETH;
    }

    /// @notice Calculate appropriate sqrtPriceLimitX96 based on current pool price and slippage tolerance
    /// @param poolKey The pool to get current price from
    /// @param zeroForOne Direction of the swap
    /// @param slippageToleranceBps Slippage tolerance in basis points (e.g., 50 = 0.5%)
    /// @return sqrtPriceLimitX96 The calculated price limit
    function _calculatePriceLimit(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint256 slippageToleranceBps
    )
        internal
        view
        returns (uint160 sqrtPriceLimitX96)
    {
        PoolId poolId = PoolIdLibrary.toId(poolKey);

        // Get current pool price
        (uint160 currentSqrtPriceX96,,,) = IPoolManager(MAINNET_V4_POOL_MANAGER).getSlot0(poolId);

        // Handle uninitialized pools - use a reasonable default
        if (currentSqrtPriceX96 == 0) {
            currentSqrtPriceX96 = 79_228_162_514_264_337_593_543_950_336; // 1:1 price ratio
        }

        // Calculate slippage factor (10000 = 100%)
        uint256 slippageFactor = zeroForOne
            ? 10_000 - slippageToleranceBps  // Price goes down
            : 10_000 + slippageToleranceBps; // Price goes up

        // Apply square root to slippage factor (since we're dealing with sqrt prices)
        uint256 sqrtSlippageFactor = _sqrt(slippageFactor * 1e18 / 10_000);
        uint256 adjustedPrice = (uint256(currentSqrtPriceX96) * sqrtSlippageFactor) / 1e9;

        // Enforce TickMath boundaries
        if (zeroForOne) {
            sqrtPriceLimitX96 =
                adjustedPrice < TickMath.MIN_SQRT_PRICE + 1 ? TickMath.MIN_SQRT_PRICE + 1 : uint160(adjustedPrice);
        } else {
            sqrtPriceLimitX96 =
                adjustedPrice > TickMath.MAX_SQRT_PRICE - 1 ? TickMath.MAX_SQRT_PRICE - 1 : uint160(adjustedPrice);
        }
    }

    /// @notice Integer square root using Babylonian method
    /// @param x The number to calculate square root of
    /// @return The square root of x
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
