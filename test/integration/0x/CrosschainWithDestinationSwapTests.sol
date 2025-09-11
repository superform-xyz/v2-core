// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";
import { IDlnSource } from "../../../src/vendor/bridges/debridge/IDlnSource.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import "modulekit/test/RhinestoneModuleKit.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { ModeLib, ModeCode } from "modulekit/accounts/common/lib/ModeLib.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { INexus } from "../../../src/vendor/nexus/INexus.sol";
import { INexusBootstrap } from "../../../src/vendor/nexus/INexusBootstrap.sol";
import { IPermit2 } from "../../../src/vendor/uniswap/permit2/IPermit2.sol";
import { IPermit2Batch } from "../../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { ISuperLedger, ISuperLedgerData } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperExecutorBase } from "../../../src/executors/SuperExecutorBase.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { AcrossV3Adapter } from "../../../src/adapters/AcrossV3Adapter.sol";
import { DebridgeAdapter } from "../../../src/adapters/DebridgeAdapter.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { BaseLedger } from "../../../src/accounting/BaseLedger.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { BaseTest } from "../../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// 0x Settler Interfaces
import { IAllowanceHolder, ALLOWANCE_HOLDER } from "../../../lib/0x-settler/src/allowanceholder/IAllowanceHolder.sol";
import { ISettlerTakerSubmitted } from "../../../lib/0x-settler/src/interfaces/ISettlerTakerSubmitted.sol";
import { ISettlerBase } from "../../../lib/0x-settler/src/interfaces/ISettlerBase.sol";

contract CrosschainWithDestinationSwapTests is BaseTest {
    // Test account must include receive() function to handle EntryPoint fee refunds
    receive() external payable { }

    using ModuleKitHelpers for *;
    using ExecutionLib for *;

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

    // AllowanceHolder constant
    address public constant ALLOWANCE_HOLDER_ADDRESS = 0x0000000000001fF3684f28c67538d4D072C22734;

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

        // BALANCES
        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test bridge from BASE to ETH with destination 0x swap and deposit
    /// @dev Bridge USDC from BASE to ETH, swap USDC to WETH via 0x, then deposit WETH to USDC vault (for testing)
    /// @dev Real user flow: Bridge WETH, approve WETH (with 5% fee reduction), swap WETH to USDC, approve USDC, deposit
    /// USDC
    /// @dev This test demonstrates real 0x API integration in crosschain context with proper hook chaining
    function test_Bridge_To_ETH_With_0x_Swap_And_Deposit() public {
        uint256 amountPerVault = 0.01 ether; // 0.01 WETH (18 decimals)
        WARP_START_TIME = block.timestamp;
        // ETH IS DST
        SELECT_FORK_AND_WARP(ETH, WARP_START_TIME);

        // PREPARE ETH DATA - 4 hooks: approve WETH (with 5% reduction), swap WETH to USDC, approve USDC, deposit USDC
        bytes memory targetExecutorMessage;
        address accountToUse;
        TargetExecutorMessage memory messageData;

        {
            // Calculate the amount after 5% fee reduction for the swap
            uint256 adjustedWETHAmount = amountPerVault - (amountPerVault * 500 / 10_000); // 5% reduction

            (, accountToUse) = _createAccountCreationData_DestinationExecutor(
                AccountCreationParams({
                    senderCreatorOnDestinationChain: _getContract(ETH, SUPER_SENDER_CREATOR_KEY),
                    validatorOnDestinationChain: address(destinationValidatorOnETH),
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
            dstHookAddresses[1] = _getHookAddress(ETH, SWAP_0X_HOOK_KEY);
            dstHookAddresses[2] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            dstHookAddresses[3] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

            // Create real hook data with the actual account
            bytes[] memory dstHookData = new bytes[](4);

            // Hook 1: Approve WETH (first hook after bridging receives the actual bridged amount)
            dstHookData[0] = _createApproveHookData(
                getWETHAddress(), // WETH (received from bridge)
                ALLOWANCE_HOLDER_ADDRESS, // Approve to 0x AllowanceHolder
                adjustedWETHAmount, // amount (the exact amount that will be received from bridge after fees)
                false // usePrevHookAmount = false
            );

            // Hook 2: Get real 0x API quote for WETH -> USDC swap using the actual account
            ZeroExQuoteResponse memory quote = getZeroExQuote(
                getWETHAddress(), // sell WETH
                underlyingETH_USDC, // buy USDC
                adjustedWETHAmount, // sell amount (after fee reduction)
                accountToUse, // use the actual executing account
                1, // chainId (ETH mainnet)
                ZEROX_API_KEY
            );

            dstHookData[1] = createHookDataFromQuote(
                quote,
                address(0), // dstReceiver (0 = account)
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
                validator: address(destinationValidatorOnETH),
                signer: validatorSigner,
                signerPrivateKey: validatorSignerPrivateKey,
                targetAdapter: address(acrossV3AdapterOnETH),
                targetExecutor: address(superTargetExecutorOnETH),
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
            500, // 5% fee reduction (500 basis points)
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
}
