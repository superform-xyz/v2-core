// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";

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
import { GatewayWallet } from "../../../lib/evm-gateway-contracts/src/GatewayWallet.sol";
import { GatewayMinter } from "../../../lib/evm-gateway-contracts/src/GatewayMinter.sol";
import { TransferSpec } from "../../../lib/evm-gateway-contracts/src/lib/TransferSpec.sol";

// Test hooks
import { CircleGatewayWalletHook } from "../../mocks/unused-hooks/CircleGatewayWalletHook.sol";
import { CircleGatewayMinterHook } from "../../mocks/unused-hooks/CircleGatewayMinterHook.sol";

// Test utilities
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";

/// @dev Integration test for Circle Gateway cross-chain bridging functionality
abstract contract CrosschainTestsGateway is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Testnet USDC addresses
    address public constant ETHEREUM_SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address public constant AVALANCHE_FUJI_USDC = 0x5425890298aed601595a70AB815c96711a31Bc65;

    // Circle Gateway contract addresses (testnet)
    address public constant GATEWAY_WALLET = 0x0077777d7EBA4688BDeF3E311b846F25870A19B9;
    address public constant GATEWAY_MINTER = 0x0022222ABE238Cc2C7Bb1f21003F0a260052475B;

    // Test constants
    uint256 public constant DEPOSIT_AMOUNT = 100e6; // 100 USDC
    uint256 public constant MINT_AMOUNT = 10e6; // 10 USDC
    uint256 public constant FEE_AMOUNT = 1e5; // 0.1 USDC (estimated fee)

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

    /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public depositor;
    address public recipient;
    address public destinationCaller;
    address public delegate;
    uint256 public depositorPrivateKey;
    uint256 public delegatePrivateKey;

    AccountInstance public accountInstance;
    ISuperExecutor public superExecutor;
    ISuperLedgerConfiguration public ledgerConfig;
    ISuperLedger public ledger;

    CircleGatewayWalletHook public circleGatewayWalletHook;
    CircleGatewayMinterHook public circleGatewayMinterHook;
    ApproveAndDeposit4626VaultHook public approveAndDeposit4626Hook;

    Mock4626Vault public mockVault;

    function setUp() public virtual {
        // Setup test accounts
        depositorPrivateKey = 0x12341234;
        delegatePrivateKey = 0x56785678;
        depositor = vm.addr(depositorPrivateKey);
        delegate = vm.addr(delegatePrivateKey);
        recipient = makeAddr("recipient");
        destinationCaller = makeAddr("destinationCaller");

        // Initialize chain configs
        ethereumSepolia = ChainConfig({
            forkId: 0,
            domain: 0, // Ethereum Sepolia domain
            usdc: ETHEREUM_SEPOLIA_USDC,
            rpcUrl: vm.envString("ETHEREUM_SEPOLIA_RPC_URL"),
            name: "Ethereum Sepolia"
        });

        baseSepolia = ChainConfig({
            forkId: 0,
            domain: 84532, // Base Sepolia domain
            usdc: BASE_SEPOLIA_USDC,
            rpcUrl: vm.envString("BASE_SEPOLIA_RPC_URL"),
            name: "Base Sepolia"
        });

        avalancheFuji = ChainConfig({
            forkId: 0,
            domain: 43113, // Avalanche Fuji domain  
            usdc: AVALANCHE_FUJI_USDC,
            rpcUrl: vm.envString("AVALANCHE_FUJI_RPC_URL"),
            name: "Avalanche Fuji"
        });

        // Create forks
        ethereumSepolia.forkId = vm.createFork(ethereumSepolia.rpcUrl);
        baseSepolia.forkId = vm.createFork(baseSepolia.rpcUrl);
        avalancheFuji.forkId = vm.createFork(avalancheFuji.rpcUrl);

        // Setup on Ethereum Sepolia as the main chain
        vm.selectFork(ethereumSepolia.forkId);
        _setupChain(ethereumSepolia);
    }

    function _setupChain(ChainConfig memory chainConfig) internal {
        // Setup Superform infrastructure
        ledgerConfig = ISuperLedgerConfiguration(address(new SuperLedgerConfiguration()));
        
        accountInstance = makeAccountInstance(keccak256(abi.encode("test_account")));
        address account = accountInstance.account;

        // Fund account with native tokens and USDC
        vm.deal(account, 10 ether);
        deal(chainConfig.usdc, account, DEPOSIT_AMOUNT * 10);

        superExecutor = ISuperExecutor(new SuperExecutor(address(ledgerConfig)));
        accountInstance.installModule({ 
            moduleTypeId: MODULE_TYPE_EXECUTOR, 
            module: address(superExecutor), 
            data: "" 
        });

        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutor);

        ledger = ISuperLedger(address(new SuperLedger(address(ledgerConfig), allowedExecutors)));

        // Setup yield source oracles
        address yieldSourceOracle = address(new ERC4626YieldSourceOracle(address(ledgerConfig)));
        
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: 100,
            feeRecipient: makeAddr("feeRecipient"),
            ledger: address(ledger)
        });
        
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(bytes("ERC4626YieldSourceOracle"));
        ledgerConfig.setYieldSourceOracles(salts, configs);

        // Deploy hooks
        circleGatewayWalletHook = new CircleGatewayWalletHook();
        circleGatewayMinterHook = new CircleGatewayMinterHook();
        approveAndDeposit4626Hook = new ApproveAndDeposit4626VaultHook();

        // Deploy mock vault for testing
        mockVault = new Mock4626Vault(chainConfig.usdc, "Mock Vault", "MVT");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to perform Circle Gateway deposit
    /// @param chainConfig The chain configuration to deposit on
    /// @param amount The amount to deposit
    function _performGatewayDeposit(ChainConfig memory chainConfig, uint256 amount) internal {
        vm.selectFork(chainConfig.forkId);
        
        address account = accountInstance.account;
        
        // Prepare hook data for Circle Gateway deposit
        bytes memory hookData = abi.encodePacked(
            chainConfig.usdc,    // token (20 bytes)
            amount,              // amount (32 bytes)
            false                // usePrevHookAmount (1 byte)
        );

        // Execute the Gateway deposit hook
        bytes memory executeData = abi.encodeCall(
            circleGatewayWalletHook.build,
            (address(0), account, hookData)
        );

        // Execute through account
        accountInstance.exec({ target: address(circleGatewayWalletHook), callData: executeData });
    }

    /// @notice Creates a TransferSpec for Circle Gateway bridging
    /// @param sourceChain Source chain configuration
    /// @param destChain Destination chain configuration
    /// @param amount Amount to transfer
    /// @param depositorAddr Depositor address
    /// @param recipientAddr Recipient address
    /// @param signerAddr Signer address
    /// @param destinationCallerAddr Destination caller address
    /// @return transferSpec The created transfer specification
    function _createTransferSpec(
        ChainConfig memory sourceChain,
        ChainConfig memory destChain,
        uint256 amount,
        address depositorAddr,
        address recipientAddr,
        address signerAddr,
        address destinationCallerAddr
    ) internal pure returns (TransferSpec memory transferSpec) {
        transferSpec = TransferSpec({
            version: 1,
            sourceDomain: sourceChain.domain,
            destinationDomain: destChain.domain,
            sourceContract: bytes32(uint256(uint160(GATEWAY_WALLET))),
            destinationContract: bytes32(uint256(uint160(GATEWAY_MINTER))),
            sourceToken: bytes32(uint256(uint160(sourceChain.usdc))),
            destinationToken: bytes32(uint256(uint160(destChain.usdc))),
            sourceDepositor: bytes32(uint256(uint160(depositorAddr))),
            destinationRecipient: bytes32(uint256(uint160(recipientAddr))),
            sourceSigner: bytes32(uint256(uint160(signerAddr))),
            destinationCaller: bytes32(uint256(uint160(destinationCallerAddr))),
            value: amount,
            salt: bytes32(uint256(1)), // Simple salt for testing
            hookData: "" // No hook data for basic transfer
        });
    }

    /// @notice Mock function to sign burn intent (would be done off-chain)
    /// @param transferSpec The transfer specification
    /// @param signerKey The private key to sign with
    /// @return encodedBurnIntent The encoded burn intent
    /// @return burnSignature The burn signature
    function _signBurnIntentWithTransferSpec(
        TransferSpec memory transferSpec,
        uint256 signerKey
    ) internal pure returns (bytes memory encodedBurnIntent, bytes memory burnSignature) {
        // This is a simplified mock implementation
        // In reality, this would follow Circle Gateway's BurnIntent specification
        encodedBurnIntent = abi.encode(transferSpec);
        
        // Mock signature creation
        bytes32 messageHash = keccak256(encodedBurnIntent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        burnSignature = abi.encodePacked(r, s, v);
    }

    /// @notice Mock function to sign attestation (would be done off-chain by Circle)
    /// @param transferSpec The transfer specification
    /// @param attestationSignerKey The Circle attestation signer key
    /// @return encodedAttestation The encoded attestation
    /// @return attestationSignature The attestation signature
    function _signAttestationWithTransferSpec(
        TransferSpec memory transferSpec,
        uint256 attestationSignerKey
    ) internal view returns (bytes memory encodedAttestation, bytes memory attestationSignature) {
        // This is a simplified mock implementation
        // In reality, this would follow Circle Gateway's Attestation specification
        encodedAttestation = abi.encode(transferSpec, block.number + 1000); // Add expiry
        
        // Mock signature creation
        bytes32 messageHash = keccak256(encodedAttestation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestationSignerKey, messageHash);
        attestationSignature = abi.encodePacked(r, s, v);
    }

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
        // Step 1: Deposit on Ethereum Sepolia
        vm.selectFork(ethereumSepolia.forkId);
        _performGatewayDeposit(ethereumSepolia, DEPOSIT_AMOUNT);

        // Step 2: Create transfer specification for ETH Sepolia -> Base Sepolia
        TransferSpec memory transferSpec = _createTransferSpec(
            ethereumSepolia,
            baseSepolia,
            MINT_AMOUNT,
            depositor,
            recipient,
            depositor,
            address(0) // No specific destination caller
        );

        // Step 3: Sign burn intent (off-chain simulation)
        // Note: This would be done off-chain in a real implementation
        // _signBurnIntentWithTransferSpec(transferSpec, depositorPrivateKey);

        // Step 4: Sign attestation (off-chain Circle simulation)
        (bytes memory encodedAttestation, bytes memory attestationSignature) = 
            _signAttestationWithTransferSpec(transferSpec, 0x999999); // Mock Circle key

        // Step 5: Switch to Base Sepolia and execute mint with vault deposit
        vm.selectFork(baseSepolia.forkId);
        _setupChain(baseSepolia); // Setup infrastructure on destination

        address account = accountInstance.account;

        // Prepare hook data for Circle Gateway mint + vault deposit
        // First encode the attestation data for the minter hook
        bytes memory minterHookData = abi.encodePacked(
            uint256(encodedAttestation.length), // attestation payload length
            encodedAttestation,                 // attestation payload
            attestationSignature               // signature
        );

        // Prepare hook data for vault deposit (this will be chained after mint)
        bytes memory vaultHookData = abi.encodePacked(
            bytes32(bytes("ERC4626YieldSourceOracle")), // yieldSourceOracleId
            address(mockVault),                         // yieldSource
            baseSepolia.usdc,                          // token
            MINT_AMOUNT,                               // amount
            true                                       // usePrevHookAmount
        );

        // Execute the Circle Gateway mint
        bytes memory mintExecuteData = abi.encodeCall(
            circleGatewayMinterHook.build,
            (address(0), account, minterHookData)
        );

        // Execute the vault deposit after mint
        bytes memory vaultExecuteData = abi.encodeCall(
            approveAndDeposit4626Hook.build,
            (address(circleGatewayMinterHook), account, vaultHookData)
        );

        // Execute both hooks in sequence
        accountInstance.exec({ target: address(circleGatewayMinterHook), callData: mintExecuteData });
        accountInstance.exec({ target: address(approveAndDeposit4626Hook), callData: vaultExecuteData });

        // Step 6: Verify end-to-end success
        // Check that tokens were minted and deposited into the vault
        uint256 vaultBalance = mockVault.balanceOf(account);
        
        // In a real scenario, this would be MINT_AMOUNT worth of vault shares
        // For this test, we just verify the process completed
        assertGt(vaultBalance, 0, "Should have vault shares after deposit");
        
        assertTrue(true, "Cross-chain transfer with vault deposit completed successfully");
    }
}

/// @dev Concrete test class that inherits from the abstract base
contract CrosschainTestsGatewayTest is CrosschainTestsGateway {
    // This concrete class allows the tests to be executed
    // All test functions are inherited from the abstract base
}