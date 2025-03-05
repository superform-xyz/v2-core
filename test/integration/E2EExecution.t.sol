// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { BaseE2ETest } from "../BaseE2ETest.t.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { SuperExecutor } from "../../src/core/executors/SuperExecutor.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";

contract E2EExecutionTest is BaseE2ETest {
    MockRegistry nexusRegistry;
    address[] attesters;
    uint8 threshold;

    SuperExecutor superExecutor;
    bytes mockSignature;

    function setUp() public override {
        super.setUp();
        nexusRegistry = new MockRegistry();
        attesters = new address[](1);
        attesters[0] = address(MANAGER);
        threshold = 1;

        mockSignature = abi.encodePacked(hex"41414141");

        superExecutor = SuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
    }

    function test_AccountCreation_WithNexus() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoAttesters() public {
        address[] memory actualAttesters = new address[](0);
        address nexusAccount = _createWithNexus(address(nexusRegistry), actualAttesters, threshold);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_WithNexus_WithNoThreshold() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, 0);
        _assertAccountCreation(nexusAccount);
    }

    function test_AccountCreation_Multiple_Times() public {
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        _assertAccountCreation(nexusAccount);

        address nexusAccount2 = _createWithNexus(address(nexusRegistry), attesters, threshold);
        _assertAccountCreation(nexusAccount2);
        assertEq(nexusAccount, nexusAccount2, "Nexus accounts should be the same");

        address nexusAccount3 = _createWithNexus(address(nexusRegistry), attesters, 0);
        _assertAccountCreation(nexusAccount3);
        assertNotEq(nexusAccount, nexusAccount3, "Nexus3 account should be different");

        address[] memory actualAttesters = new address[](0);
        address nexusAccount4 = _createWithNexus(address(nexusRegistry), actualAttesters, threshold);
        _assertAccountCreation(nexusAccount4);
        assertNotEq(nexusAccount, nexusAccount4, "Nexus4 account should be different");
    }

    function test_Approval_With_Nexus(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
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
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

        uint256 allowanceAmount = IERC20(CHAIN_1_WETH).allowance(nexusAccount, address(MANAGER));
        assertEq(allowanceAmount, amount, "Allowance should be set correctly");
    }

    function test_Approval_With_Existing_Account(uint256 amount) public {
        amount = _bound(amount);

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        _assertAccountCreation(nexusAccount);

        // "re-create" account
        nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        _assertAccountCreation(nexusAccount);

        _assertExecutorIsInitialized(nexusAccount);

        // add tokens to account
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

        uint256 allowanceAmount = IERC20(CHAIN_1_WETH).allowance(nexusAccount, address(MANAGER));
        assertEq(allowanceAmount, amount, "Allowance should be set correctly");
    }

    function test_Deposit_To_Morpho_And_TransferShares(uint256 amount) public {
        amount = _bound(amount);
        address underlyingToken = existingUnderlyingTokens[ETH][USDC_KEY];
        address morphoVault = realVaultAddresses[ETH][ERC4626_VAULT_KEY][MORPHO_VAULT_KEY][USDC_KEY];

        // create account
        address nexusAccount = _createWithNexus(address(nexusRegistry), attesters, threshold);
        _assertAccountCreation(nexusAccount);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        uint256 obtainable = IERC4626(morphoVault).previewDeposit(amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        // prepare data & execute through entry point
        _executeThroughEntrypoint(nexusAccount, mockSignature, entry);

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

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _assertExecutorIsInitialized(address nexusAccount) internal view {
        bool isSuperExecutorInitialized = superExecutor.isInitialized(nexusAccount);
        assertTrue(isSuperExecutorInitialized, "SuperExecutor should be initialized");
    }

    function _assertAccountCreation(address nexusAccount) internal view {
        string memory accountId = INexus(nexusAccount).accountId();
        assertGt(bytes(accountId).length, 0);
        assertEq(accountId, NEXUS_ACCOUNT_IMPLEMENTATION_ID);
    }
}
