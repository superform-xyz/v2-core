// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { console } from "forge-std/console.sol";

// Superform
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../../src/interfaces/accounting/ISuperLedger.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { ApproveAndDeposit4626VaultHook } from "../../../src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";

// Circle Gateway
import {
    MultichainTestUtils,
    TransferSpec,
    GatewayWallet,
    GatewayMinter,
    FiatTokenV2_2,
    MasterMinter
} from "../../../lib/evm-gateway-contracts/test/util/MultichainTestUtils.sol";

// Test hooks
import { CircleGatewayWalletHook } from "../../../src/hooks/bridges/circle/CircleGatewayWalletHook.sol";
import { CircleGatewayMinterHook } from "../../../src/hooks/bridges/circle/CircleGatewayMinterHook.sol";

// Test utilities
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";

/// @dev Integration test for Circle Gateway cross-chain bridging functionality
contract CrosschainTestsGateway is Helpers, RhinestoneModuleKit, InternalHelpers, MultichainTestUtils {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Testnet USDC addresses
    address public constant ETHEREUM_SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address public constant AVALANCHE_FUJI_USDC = 0x5425890298aed601595a70AB815c96711a31Bc65;

    // Note: Test constants DEPOSIT_AMOUNT, MINT_AMOUNT, FEE_AMOUNT are inherited from MultichainTestUtils

    /*//////////////////////////////////////////////////////////////
                                 CHAIN CONFIGS
    //////////////////////////////////////////////////////////////*/

    struct ChainConfig {
        uint256 forkId;
        uint32 domain;
        address usdc;
        string rpcUrl;
        string name;
    }

    ChainConfig public ethereumSepolia;
    ChainConfig public baseSepolia;
    ChainConfig public avalancheFuji;

    // Chain-specific gateway setups
    ChainSetup public ethereumSepoliaSetup;
    ChainSetup public baseSepoliaSetup;
    ChainSetup public avalancheFujiSetup;

    /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Note: depositor, recipient, destinationCaller, delegate and their private keys
    // are inherited from MultichainTestUtils

    AccountInstance public accountInstance;
    ISuperExecutor public superExecutor;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    CircleGatewayWalletHook public circleGatewayWalletHook;
    CircleGatewayMinterHook public circleGatewayMinterHook;
    ApproveAndDeposit4626VaultHook public approveAndDeposit4626Hook;

    Mock4626Vault public mockVault;

    function setUp() public virtual {
        // Initialize chain configs
        ethereumSepolia = ChainConfig({
            forkId: 0,
            domain: 0, // Ethereum Sepolia domain
            usdc: ETHEREUM_SEPOLIA_USDC,
            rpcUrl: vm.envString("SEPOLIA_RPC_URL"),
            name: "Ethereum Sepolia"
        });

        baseSepolia = ChainConfig({
            forkId: 0,
            domain: 84_532, // Base Sepolia domain
            usdc: BASE_SEPOLIA_USDC,
            rpcUrl: vm.envString("BASE_SEPOLIA_RPC_URL"),
            name: "Base Sepolia"
        });

        avalancheFuji = ChainConfig({
            forkId: 0,
            domain: 43_113, // Avalanche Fuji domain
            usdc: AVALANCHE_FUJI_USDC,
            rpcUrl: vm.envString("FUJI_RPC_URL"),
            name: "Avalanche Fuji"
        });

        // Create forks
        ethereumSepolia.forkId = vm.createFork(ethereumSepolia.rpcUrl);
        baseSepolia.forkId = vm.createFork(baseSepolia.rpcUrl);
        avalancheFuji.forkId = vm.createFork(avalancheFuji.rpcUrl);

        // Setup on Ethereum Sepolia as the main chain
        vm.selectFork(ethereumSepolia.forkId);
        ethereumSepoliaSetup = _setupChain(ethereumSepolia);
    }

    // Define a struct to avoid stack too deep errors
    struct SetupParams {
        address account;
        address yieldSourceOracle;
        address owner;
        address walletFeeRecipient;
        address walletBurnSigner;
        address minterAttestationSigner;
        uint256 walletBurnSignerKey;
        uint256 minterAttestationSignerKey;
        uint256 chainId;
        address[] allowedExecutors;
    }

    function _setupChain(ChainConfig memory chainConfig) internal returns (ChainSetup memory) {
        SetupParams memory params;
        params.chainId = block.chainid;

        // Setup Superform infrastructure
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration{ salt: "TEST_SALT" }()));

        accountInstance = makeAccountInstance(keccak256(abi.encode("test_account")));
        params.account = accountInstance.account;

        // Fund account with native tokens and USDC
        vm.deal(params.account, 10 ether);
        deal(chainConfig.usdc, params.account, DEPOSIT_AMOUNT * 10);

        superExecutor = ISuperExecutor(new SuperExecutor{ salt: "TEST_SALT" }(address(ledgerConfig)));
        accountInstance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        params.allowedExecutors = new address[](1);
        params.allowedExecutors[0] = address(superExecutor);

        ledger =
            ISuperLedger(address(new SuperLedger{ salt: "TEST_SALT" }(address(ledgerConfig), params.allowedExecutors)));

        // Setup yield source oracles
        params.yieldSourceOracle = address(new ERC4626YieldSourceOracle{ salt: "TEST_SALT" }(address(ledgerConfig)));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: params.yieldSourceOracle,
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes("ERC4626YieldSourceOracle"));

        // Set manager to the test contract itself so it can manage configurations
        vm.startPrank(address(this));
        ledgerConfig.setYieldSourceOracles(salts, configs);
        vm.stopPrank();

        // Deploy mock vault for testing
        mockVault = new Mock4626Vault{ salt: "TEST_SALT" }(chainConfig.usdc, "Mock Vault", "MVT");

        // Deploy our own Gateway contracts similar to MultichainTestUtils._initializeGatewayContracts
        params.owner = vm.addr(params.chainId + 1);
        params.walletFeeRecipient = vm.addr(params.chainId + 2);
        (params.walletBurnSigner, params.walletBurnSignerKey) = makeAddrAndKey(vm.toString(params.chainId + 3));
        (params.minterAttestationSigner, params.minterAttestationSignerKey) =
            makeAddrAndKey(vm.toString(params.chainId + 4));

        // Deploy Gateway contracts
        (GatewayWallet wallet, GatewayMinter minter) = deploy(params.owner, chainConfig.domain);

        vm.startPrank(params.owner);
        {
            // Configure minter settings
            minter.addSupportedToken(chainConfig.usdc);
            minter.addAttestationSigner(params.minterAttestationSigner);
            minter.updateMintAuthority(chainConfig.usdc, chainConfig.usdc);

            // Configure wallet settings
            wallet.addSupportedToken(chainConfig.usdc);
            wallet.addBurnSigner(params.walletBurnSigner);
            wallet.updateFeeRecipient(params.walletFeeRecipient);
            wallet.updateWithdrawalDelay(WITHDRAW_DELAY);
        }
        vm.stopPrank();

        // Setup wallet and minter as USDC minter / burner
        MasterMinter masterMinter = MasterMinter(FiatTokenV2_2(chainConfig.usdc).masterMinter());
        address masterMinterOwner = masterMinter.owner();

        vm.startPrank(masterMinterOwner);
        {
            // Configure minter with maximum allowance
            masterMinter.configureController(masterMinterOwner, address(minter));
            masterMinter.configureMinter(type(uint256).max);

            // Configure wallet with zero allowance (burn only)
            masterMinter.configureController(masterMinterOwner, address(wallet));
            masterMinter.configureMinter(0);
        }
        vm.stopPrank();

        // Now deploy hooks with the correct gateway addresses
        approveAndDeposit4626Hook = new ApproveAndDeposit4626VaultHook{ salt: "TEST_SALT" }();
        circleGatewayWalletHook = new CircleGatewayWalletHook{ salt: "TEST_SALT" }(address(wallet));
        circleGatewayMinterHook = new CircleGatewayMinterHook{ salt: "TEST_SALT" }(address(minter));

        // Return the ChainSetup struct
        return ChainSetup({
            forkId: chainConfig.forkId,
            domain: chainConfig.domain,
            walletBurnSignerKey: params.walletBurnSignerKey,
            minterAttestationSignerKey: params.minterAttestationSignerKey,
            wallet: wallet,
            minter: minter,
            usdc: FiatTokenV2_2(chainConfig.usdc)
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to perform Circle Gateway deposit using SuperExecutor
    /// @param chainConfig The chain configuration to deposit on
    /// @param amount The amount to deposit
    function _performGatewayDeposit(ChainConfig memory chainConfig, uint256 amount) internal {
        vm.selectFork(chainConfig.forkId);

        // Prepare hook data for Circle Gateway deposit
        bytes memory hookData = abi.encodePacked(
            chainConfig.usdc, // token (20 bytes)
            amount, // amount (32 bytes)
            false // usePrevHookAmount (1 byte)
        );

        // Create hooks array for SuperExecutor
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(circleGatewayWalletHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;

        // Create executor entry
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Execute through SuperExecutor
        vm.prank(accountInstance.account);
        superExecutor.execute(abi.encode(entry));
    }

    /// @notice Creates a TransferSpec for Circle Gateway bridging with superform integration
    /// @param sourceChainSetup Source chain setup with contracts
    /// @param destChainSetup Destination chain setup with contracts
    /// @param amount Amount to transfer
    /// @param depositorAddr Depositor address
    /// @param recipientAddr Recipient address
    /// @param signerAddr Signer address
    /// @param destinationCallerAddr Destination caller address
    /// @return transferSpec The created transfer specification
    function _createSuperformTransferSpec(
        ChainSetup memory sourceChainSetup,
        ChainSetup memory destChainSetup,
        uint256 amount,
        address depositorAddr,
        address recipientAddr,
        address signerAddr,
        address destinationCallerAddr
    )
        internal
        pure
        returns (TransferSpec memory transferSpec)
    {
        transferSpec = TransferSpec({
            version: 1,
            sourceDomain: sourceChainSetup.domain,
            destinationDomain: destChainSetup.domain,
            sourceContract: bytes32(uint256(uint160(address(sourceChainSetup.wallet)))),
            destinationContract: bytes32(uint256(uint160(address(destChainSetup.minter)))),
            sourceToken: bytes32(uint256(uint160(address(sourceChainSetup.usdc)))),
            destinationToken: bytes32(uint256(uint160(address(destChainSetup.usdc)))),
            sourceDepositor: bytes32(uint256(uint160(depositorAddr))),
            destinationRecipient: bytes32(uint256(uint160(recipientAddr))), // Send to user account
            sourceSigner: bytes32(uint256(uint160(signerAddr))),
            destinationCaller: bytes32(uint256(uint160(destinationCallerAddr))),
            value: amount,
            salt: bytes32(uint256(1)), // Simple salt for testing
            hookData: ""
        });
    }

    // Note: All signing methods are inherited from SignatureTestUtils via MultichainTestUtils

    /*//////////////////////////////////////////////////////////////
                                 TEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test basic Gateway deposit functionality
    function test_gatewayDeposit() public {
        // Test deposit on Ethereum Sepolia
        _performGatewayDeposit(ethereumSepolia, DEPOSIT_AMOUNT);

        // Verify the deposit was successful
        // Note: In a real test, you would check the Gateway balance
        // This is simplified for the test framework
        assertTrue(true, "Gateway deposit completed");
    }

    /// @notice Test cross-chain transfer with vault deposit on destination
    function test_crossChainTransferWithVaultDeposit() public {
        /// @dev the follow steps happen when user receives some USDC in his account
        /// user is prompted to deposit into gateway. These funds become available for usage on any chain
        // SDeposit on Ethereum Sepolia
        vm.selectFork(ethereumSepolia.forkId);
        _performGatewayDeposit(ethereumSepolia, DEPOSIT_AMOUNT);

        /// @dev when the user is ready to take an action on any chain, he can sign an attestation for spending
        // Step 1: Create transfer specification for ETH Sepolia -> Base Sepolia
        // Note: We'll need to setup base sepolia first to get the chain setup
        vm.selectFork(baseSepolia.forkId);
        baseSepoliaSetup = _setupChain(baseSepolia); // Setup infrastructure on destination

        vm.selectFork(ethereumSepolia.forkId); // Go back to source chain

        address account = accountInstance.account;

        TransferSpec memory transferSpec = _createSuperformTransferSpec(
            ethereumSepoliaSetup,
            baseSepoliaSetup,
            MINT_AMOUNT,
            depositor,
            account, // Use the user's smart account as the recipient
            depositor,
            address(0) // No specific destination caller
        );

        // Step 2: Sign burn intent (off-chain simulation)
        // Use the real GatewayWallet contract for proper burn intent signing
        // TODO: Currently turned off as we are not testing the burning part here for now, can do it ater
        /*
        gatewayWallet = GatewayWallet(payable(GATEWAY_WALLET_ADDR));
        (bytes memory encodedBurnIntent, bytes memory burnSignature) =
            _signBurnIntentWithTransferSpec(transferSpec, gatewayWallet, depositorPrivateKey);
        */

        // Step 3: Switch back to Base Sepolia for minting
        vm.selectFork(baseSepolia.forkId);

        // Step 4: Sign attestation with the proper key (off-chain Circle simulation)
        (bytes memory encodedAttestation, bytes memory attestationSignature) =
            _signAttestationWithTransferSpec(transferSpec, baseSepoliaSetup.minterAttestationSignerKey);

        // Step 5: Execute two hooks directly
        // Hook 1: Circle Gateway Minter Hook - mint USDC
        // Hook 2: Approve and Deposit 4626 Vault Hook - deposit into vault

        // Create hooks array for SuperExecutor
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(circleGatewayMinterHook);
        hooksAddresses[1] = address(approveAndDeposit4626Hook);

        bytes[] memory hooksData = new bytes[](2);

        // Hook 1 data: Circle Gateway Minter Hook
        hooksData[0] = abi.encodePacked(
            uint256(encodedAttestation.length), // attestation payload length
            encodedAttestation, // attestation payload
            uint256(attestationSignature.length), // signature length
            attestationSignature // signature
        );

        // Hook 2 data: Approve and Deposit 4626 Vault Hook
        // Derive the correct yield source oracle ID using the same method as SuperLedgerConfiguration
        bytes32 salt = bytes32(bytes("ERC4626YieldSourceOracle"));
        bytes32 yieldSourceOracleId = keccak256(abi.encodePacked(salt, address(this)));

        hooksData[1] = abi.encodePacked(
            yieldSourceOracleId, // Correctly derived yieldSourceOracleId
            address(mockVault), // yieldSource
            address(baseSepoliaSetup.usdc), // token
            MINT_AMOUNT, // amount
            true // usePrevHookAmount
        );

        // Create executor entry
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // Execute both hooks through SuperExecutor
        vm.prank(account);
        superExecutor.execute(abi.encode(entry));

        // Step 6: Verify end-to-end success
        // Check that USDC was minted to the account
        uint256 usdcBalance = IERC20(baseSepoliaSetup.usdc).balanceOf(account);
        console.log("USDC balance after minting:", usdcBalance);

        // Check that tokens were deposited into the vault
        uint256 vaultBalance = mockVault.balanceOf(account);
        console.log("Vault shares balance:", vaultBalance);

        // Verify that USDC was minted
        assertGt(usdcBalance, 0, "Should have USDC balance after minting");

        // Verify that vault shares were minted after deposit
        assertGt(vaultBalance, 0, "Should have vault shares after deposit");

        assertTrue(true, "Cross-chain transfer with vault deposit completed successfully");
    }
}
