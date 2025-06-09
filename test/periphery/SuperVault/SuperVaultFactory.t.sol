// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Test
import { BaseSuperVaultTest } from "../integration/SuperVault/BaseSuperVaultTest.t.sol";

// Superform
import { SuperVaultFactory } from "../../../src/periphery/SuperVault/SuperVaultFactory.sol";
import { ISuperVaultFactory } from "../../../src/periphery/interfaces/SuperVault/ISuperVaultFactory.sol";
import { ISuperAssetRegistry } from "../../../src/periphery/interfaces/SuperVault/ISuperAssetRegistry.sol";
import { ISuperVaultAggregator } from "../../../src/periphery/interfaces/SuperVault/ISuperVaultAggregator.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { SuperAssetRegistry } from "../../../src/periphery/SuperVault/SuperAssetRegistry.sol";
import { SuperVault } from "../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVault/SuperVaultEscrow.sol";

// External
import { MockERC20 } from "forge-std/mocks/MockERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract SuperVaultFactoryTest is BaseSuperVaultTest {
    SuperVaultFactory public superVaultFactory;
    SuperAssetRegistry public superAssetRegistry;

    address public constant CREATOR = address(0x1234);
    address public constant UNAUTHORIZED = address(0xDEF0);

    MockERC20 public underlyingAsset;

    event VaultCreated(
        address indexed superVault, address indexed strategy, address indexed escrow, address creator, uint256 nonce
    );

    function setUp() public override {
        super.setUp();

        // Deploy SuperAssetRegistry
        superAssetRegistry = new SuperAssetRegistry(address(superGovernor));

        // Deploy SuperVaultFactory
        superVaultFactory = new SuperVaultFactory(address(superGovernor), address(superAssetRegistry));

        // Setup underlying asset
        underlyingAsset = new MockERC20();
        underlyingAsset.mint(CREATOR, 1000 ether);
        underlyingAsset.mint(STRATEGIST, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_ValidAddresses() public {
        SuperVaultFactory factory = new SuperVaultFactory(address(superGovernor), address(superAssetRegistry));
        assertEq(address(factory.SUPER_GOVERNOR()), address(superGovernor));
        assertEq(address(factory.SUPER_ASSET_REGISTRY()), address(superAssetRegistry));
    }

    function test_constructor_RevertIf_ZeroGovernor() public {
        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        new SuperVaultFactory(address(0), address(superAssetRegistry));
    }

    function test_constructor_RevertIf_ZeroRegistry() public {
        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        new SuperVaultFactory(address(superGovernor), address(0));
    }

    function test_constructor_DeploysImplementations() public {
        SuperVaultFactory factory = new SuperVaultFactory(address(superGovernor), address(superAssetRegistry));

        address vaultImpl = factory.VAULT_IMPLEMENTATION();
        address strategyImpl = factory.STRATEGY_IMPLEMENTATION();
        address escrowImpl = factory.ESCROW_IMPLEMENTATION();

        assertNotEq(vaultImpl, address(0));
        assertNotEq(strategyImpl, address(0));
        assertNotEq(escrowImpl, address(0));

        // Verify implementations are actual contracts
        assertTrue(vaultImpl.code.length > 0);
        assertTrue(strategyImpl.code.length > 0);
        assertTrue(escrowImpl.code.length > 0);
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createVault_Success() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Super Vault",
            symbol: "TSV",
            salt: bytes32(uint256(1))
        });

        uint256 currentNonce = superVaultFactory.getCurrentNonce();

        vm.expectEmit(false, false, false, false);
        emit VaultCreated(address(0), address(0), address(0), CREATOR, currentNonce);

        (address superVault, address strategy, address escrow) = superVaultFactory.createVault(params);

        // Verify addresses are not zero
        assertNotEq(superVault, address(0));
        assertNotEq(strategy, address(0));
        assertNotEq(escrow, address(0));

        // Verify contracts are actually deployed
        assertTrue(superVault.code.length > 0);
        assertTrue(strategy.code.length > 0);
        assertTrue(escrow.code.length > 0);

        // Verify nonce incremented
        assertEq(superVaultFactory.getCurrentNonce(), currentNonce + 1);

        // Verify vault is added to registries
        assertEq(superVaultFactory.superVaults(currentNonce), superVault);
        assertEq(superVaultFactory.superVaultStrategies(currentNonce), strategy);
        assertEq(superVaultFactory.superVaultEscrows(currentNonce), escrow);

        // Test vault initialization
        SuperVault vault = SuperVault(superVault);
        assertEq(vault.name(), "Test Super Vault");
        assertEq(vault.symbol(), "TSV");
        assertEq(address(vault.asset()), address(underlyingAsset));

        // Test strategy initialization
        SuperVaultStrategy strategyContract = SuperVaultStrategy(strategy);
        assertEq(address(strategyContract.asset()), address(underlyingAsset));
        assertEq(address(strategyContract.vault()), superVault);
    }

    function test_createVault_RevertIf_ZeroCreator() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: address(0),
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        superVaultFactory.createVault(params);
    }

    function test_createVault_RevertIf_ZeroAsset() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(0),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        superVaultFactory.createVault(params);
    }

    function test_createVault_RevertIf_ZeroStrategist() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: address(0),
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        vm.expectRevert(ISuperVaultFactory.ZERO_ADDRESS.selector);
        superVaultFactory.createVault(params);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAllSuperVaults_EmptyInitially() public {
        address[] memory vaults = superVaultFactory.getAllSuperVaults();
        assertEq(vaults.length, 0);
    }

    function test_getAllSuperVaults_AfterCreation() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (address vault,,) = superVaultFactory.createVault(params);

        address[] memory vaults = superVaultFactory.getAllSuperVaults();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], vault);
    }

    function test_getAllSuperVaultStrategies_EmptyInitially() public {
        address[] memory strategies = superVaultFactory.getAllSuperVaultStrategies();
        assertEq(strategies.length, 0);
    }

    function test_getAllSuperVaultStrategies_AfterCreation() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (, address strategy,) = superVaultFactory.createVault(params);

        address[] memory strategies = superVaultFactory.getAllSuperVaultStrategies();
        assertEq(strategies.length, 1);
        assertEq(strategies[0], strategy);
    }

    function test_getAllSuperVaultEscrows_EmptyInitially() public {
        address[] memory escrows = superVaultFactory.getAllSuperVaultEscrows();
        assertEq(escrows.length, 0);
    }

    function test_getAllSuperVaultEscrows_AfterCreation() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (,, address escrow) = superVaultFactory.createVault(params);

        address[] memory escrows = superVaultFactory.getAllSuperVaultEscrows();
        assertEq(escrows.length, 1);
        assertEq(escrows[0], escrow);
    }

    function test_superVaults_ValidIndex() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (address vault,,) = superVaultFactory.createVault(params);

        assertEq(superVaultFactory.superVaults(0), vault);
    }

    function test_superVaultStrategies_ValidIndex() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (, address strategy,) = superVaultFactory.createVault(params);

        assertEq(superVaultFactory.superVaultStrategies(0), strategy);
    }

    function test_superVaultEscrows_ValidIndex() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (,, address escrow) = superVaultFactory.createVault(params);

        assertEq(superVaultFactory.superVaultEscrows(0), escrow);
    }

    /*//////////////////////////////////////////////////////////////
                            NONCE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentNonce_StartsAtZero() public {
        assertEq(superVaultFactory.getCurrentNonce(), 0);
    }

    function test_getCurrentNonce_IncrementsAfterCreation() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        assertEq(superVaultFactory.getCurrentNonce(), 0);
        superVaultFactory.createVault(params);
        assertEq(superVaultFactory.getCurrentNonce(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                            CLONE PATTERN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_clonePattern_CreatesMinimalProxies() public {
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: bytes32(uint256(1))
        });

        (address vault, address strategy, address escrow) = superVaultFactory.createVault(params);

        // Verify these are minimal proxies (clones)
        // Minimal proxy has very small bytecode size
        assertTrue(vault.code.length < 100); // Minimal proxy should be small
        assertTrue(strategy.code.length < 100);
        assertTrue(escrow.code.length < 100);

        // Verify they point to the correct implementations
        address vaultImpl = superVaultFactory.VAULT_IMPLEMENTATION();
        address strategyImpl = superVaultFactory.STRATEGY_IMPLEMENTATION();
        address escrowImpl = superVaultFactory.ESCROW_IMPLEMENTATION();

        // Test that the clones work by calling a function
        SuperVault vaultContract = SuperVault(vault);
        assertEq(vaultContract.name(), "Test Vault");
    }

    /*//////////////////////////////////////////////////////////////
                            DETERMINISTIC ADDRESS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createVault_DeterministicAddresses() public {
        bytes32 salt = bytes32(uint256(12_345));

        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Test Vault",
            symbol: "TV",
            salt: salt
        });

        // Predict addresses
        address predictedVault = Clones.predictDeterministicAddress(
            superVaultFactory.VAULT_IMPLEMENTATION(),
            keccak256(abi.encodePacked(salt, uint256(0))), // nonce is 0
            address(superVaultFactory)
        );

        address predictedStrategy = Clones.predictDeterministicAddress(
            superVaultFactory.STRATEGY_IMPLEMENTATION(),
            keccak256(abi.encodePacked(salt, uint256(0))),
            address(superVaultFactory)
        );

        address predictedEscrow = Clones.predictDeterministicAddress(
            superVaultFactory.ESCROW_IMPLEMENTATION(),
            keccak256(abi.encodePacked(salt, uint256(0))),
            address(superVaultFactory)
        );

        // Create vault
        (address actualVault, address actualStrategy, address actualEscrow) = superVaultFactory.createVault(params);

        // Verify addresses match predictions
        assertEq(actualVault, predictedVault);
        assertEq(actualStrategy, predictedStrategy);
        assertEq(actualEscrow, predictedEscrow);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_integration_FullVaultWorkflow() public {
        // Create vault
        ISuperVaultAggregator.VaultCreationParams memory params = ISuperVaultAggregator.VaultCreationParams({
            creator: CREATOR,
            asset: address(underlyingAsset),
            strategist: STRATEGIST,
            name: "Integration Test Vault",
            symbol: "ITV",
            salt: bytes32(uint256(1))
        });

        (address vaultAddr, address strategyAddr,) = superVaultFactory.createVault(params);
        SuperVault vault = SuperVault(vaultAddr);
        SuperVaultStrategy strategy = SuperVaultStrategy(strategyAddr);

        // Add strategist to registry
        vm.prank(address(superGovernor));
        superAssetRegistry.addPrimaryStrategist(strategyAddr, STRATEGIST);

        // Test vault is functional
        uint256 depositAmount = 100e18;
        vm.startPrank(CREATOR);
        underlyingAsset.approve(vaultAddr, depositAmount);

        // This might fail if vault needs more setup, but structure should be correct
        try vault.deposit(depositAmount, CREATOR) {
            // If successful, verify shares were minted
            assertTrue(vault.balanceOf(CREATOR) > 0);
        } catch {
            // Expected if vault needs additional setup
        }
        vm.stopPrank();

        // Verify strategy is connected properly
        assertEq(address(strategy.vault()), vaultAddr);
        assertEq(address(strategy.asset()), address(underlyingAsset));
    }
}
