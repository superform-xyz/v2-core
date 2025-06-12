// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {MinimalBaseNexusIntegrationTest} from "./MinimalBaseNexusIntegrationTest.t.sol";
import {INexus} from "../../src/vendor/nexus/INexus.sol";
import {MockRegistry} from "../mocks/MockRegistry.sol";
import {ISuperExecutor} from "../../src/core/interfaces/ISuperExecutor.sol";

contract E2EExecutionTest is MinimalBaseNexusIntegrationTest {
    MockRegistry public nexusRegistry;
    address[] public attesters;
    uint8 public threshold;

    bytes public mockSignature;

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        nexusRegistry = new MockRegistry();
        attesters = new address[](1);
        attesters[0] = address(MANAGER);
        threshold = 1;

        mockSignature = abi.encodePacked(hex"41414141");
    }

    function test_AccountCreation_WithNexus() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoAttesters() public {
        address[] memory actualAttesters = new address[](0);
        address nexusAccount = _createWithNexus(address(nexusRegistry), actualAttesters, threshold, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoThreshold() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, 0, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_Multiple_Times() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        address nexusAccount2 = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount2);
        assertEq(nexusAccount, nexusAccount2, "Nexus accounts should be the same");

        address nexusAccount3 = _createWithNexus(address(nexusRegistry), attesters, 0, 0);
        _assertAccountCreation(nexusAccount3);
        assertNotEq(nexusAccount, nexusAccount3, "Nexus3 account should be different");

        address[] memory actualAttesters = new address[](0);
        address nexusAccount4 = _createWithNexus(address(nexusRegistry), actualAttesters, threshold, 0);
        _assertAccountCreation(nexusAccount4);
        assertNotEq(nexusAccount, nexusAccount4, "Nexus4 account should be different");
    }

    function test_Approval_With_Nexus(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        // fund account
        vm.deal(nexusAccount, LARGE);

        // assert account initialized with super executor
        _assertExecutorIsInitialized(nexusAccount);

        // add tokens to account
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = approveHook;
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 allowanceAmount = IERC20(CHAIN_1_WETH).allowance(nexusAccount, address(MANAGER));
        assertEq(allowanceAmount, amount, "Allowance should be set correctly");
    }

    function test_Approval_With_Existing_Account(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);
        _assertAccountCreation(nexusAccount);

        // "re-create" account
        nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 0);
        _assertAccountCreation(nexusAccount);

        _assertExecutorIsInitialized(nexusAccount);

        // add tokens to account
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = approveHook;
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 allowanceAmount = IERC20(CHAIN_1_WETH).allowance(nexusAccount, address(MANAGER));
        assertEq(allowanceAmount, amount, "Allowance should be set correctly");
    }

    function test_Deposit_To_Morpho_And_TransferShares(uint256 amount) public {
        amount = _bound(amount);
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold, 1e18);
        _assertAccountCreation(nexusAccount);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        uint256 obtainable = IERC4626(morphoVault).previewDeposit(amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        uint256 accSharesAfter = IERC4626(morphoVault).balanceOf(nexusAccount);
        assertApproxEqAbs(
            accSharesAfter,
            obtainable,
            /**
             * 10% max delta
             */
            amount * 1e5 / 1e6,
            "Shares should be close to obtainable"
        );
    }

    function testOrion_feesCauseChainedOperationFailures() public {
        uint256 amount = 100e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        address accountOwner = makeAddr("owner");

        // 1. Create account
        address nexusAccount = _createWithNexus(
            address(nexusRegistry),
            attesters,
            threshold,
            1e18
        );

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);
        // Mock account approval to vault
        vm.startPrank(nexusAccount);
        IERC20(CHAIN_1_USDC).approve(morphoVault, type(uint256).max);

        // 2. Create SuperExecutor data, with:
        // - approval
        // - deposit
        // - redemption, whose amount should be charged
        // - approval
        // - deposit
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = deposit4626Hook;

        bytes[] memory hooksData = new bytes[](1);

        hooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            morphoVault,
            amount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor
            .ExecutorEntry({
                hooksAddresses: hooksAddresses,
                hooksData: hooksData
            });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, entry);

        // Warp to mock interest accrual so that fees are applied
        vm.warp(block.timestamp + 10 weeks);

        {
            hooksAddresses = new address[](2);
            hooksAddresses[0] = redeem4626Hook;
            hooksAddresses[1] = deposit4626Hook;

            hooksData = new bytes[](2);

            hooksData[0] = _createRedeem4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                morphoVault,
                nexusAccount,
                IERC4626(morphoVault).convertToShares(amount),
                false
            );

            hooksData[1] = _createDeposit4626HookData(
                bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                morphoVault,
                amount,
                true, // use previous output amount set to true
                address(0),
                0
            );

            entry = ISuperExecutor.ExecutorEntry({
                hooksAddresses: hooksAddresses,
                hooksData: hooksData
            });

            // prepare data & execute through entry point
            _executeThroughEntrypoint(nexusAccount, entry);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _assertExecutorIsInitialized(address nexusAccount) internal view {
        bool isSuperExecutorInitialized = superExecutorModule.isInitialized(nexusAccount);
        assertTrue(isSuperExecutorInitialized, "SuperExecutor should be initialized");
    }

    function _assertAccountCreation(address nexusAccount) internal view {
        string memory accountId = INexus(nexusAccount).accountId();
        assertGt(bytes(accountId).length, 0);
        assertEq(accountId, NEXUS_ACCOUNT_IMPLEMENTATION_ID);
    }
}
