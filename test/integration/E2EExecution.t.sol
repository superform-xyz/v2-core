// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { MinimalBaseNexusIntegrationTest } from "./MinimalBaseNexusIntegrationTest.t.sol";
import { INexus } from "../../src/vendor/nexus/INexus.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";

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
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

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
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

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
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

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

    function test_feeBypassByCustomHook_Reverts() public {
        uint256 amount = 10_000e6;
        address underlyingToken = CHAIN_1_USDC;
        address morphoVault = CHAIN_1_MorphoVault;

        address accountOwner = makeAddr("owner");
        MaliciousHook maliciousHook = new MaliciousHook(accountOwner, underlyingToken);

        // Step 1: Create account and install custom malicious hook
        address nexusAccount = _createWithNexusWithMaliciousHook(
            address(nexusRegistry), attesters, threshold, 1e18, address(maliciousHook)
        );

        maliciousHook.setAccount(nexusAccount);

        // Step 2: Account approval to the hook
        vm.startPrank(nexusAccount);
        IERC4626(underlyingToken).approve(address(maliciousHook), type(uint256).max);

        // add tokens to account
        _getTokens(underlyingToken, nexusAccount, amount);

        // 3. Create SuperExecutor data, with:
        // - approval
        // - deposit
        // - redemption, whose amount should be charged
        address[] memory hooksAddresses = new address[](3);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = deposit4626Hook;
        hooksAddresses[2] = redeem4626Hook;

        bytes[] memory hooksData = new bytes[](3);
        hooksData[0] = _createApproveHookData(underlyingToken, morphoVault, amount, false);
        hooksData[1] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), morphoVault, amount, false, address(0), 0
        );
        hooksData[2] = _createRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            morphoVault,
            nexusAccount,
            IERC4626(morphoVault).convertToShares(amount),
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        address feeRecipient = makeAddr("feeRecipient"); // this is the recipient configured in base tests.

        // Fetch the fee recipient balance before execution
        uint256 feeReceiverBalanceBefore = IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient);

        // prepare data & execute through entry point
        _executeThroughEntrypointWithMaliciousHook(nexusAccount, entry);

        // Ensure fee obtained is 0
        assertEq(IERC4626(CHAIN_1_USDC).balanceOf(feeRecipient) - feeReceiverBalanceBefore, 0);
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

contract MaliciousHook {
    address public owner;
    address public account;
    address public underlying;
    uint256 count;
    uint256 constant MODULE_TYPE_HOOK = 4;

    constructor(address _owner, address _underlying) {
        owner = _owner;
        underlying = _underlying;
    }

    function setAccount(address _account) external {
        account = _account;
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        returns (bytes memory hookData)
    {
        // do nothing in precheck
    }

    function postCheck(bytes calldata /*hookData*/ ) external {
        // This check isn't really necessary. However in our poc we batch
        // the approve, deposit and redeem calls in the same execution. Because of this, this postCheck
        // is called three times, after approving, after depositing and after redeeming, so we only want to call this
        // after redeeming. We limit it with a simple, unoptimized solution.
        if (count < 2) {
            count++;
            return;
        }
        // We directly transfer our balance. This will set `outAmount` to 0 in Superform's postExecute call to
        // ERC4626 redeem hook, instead of the actual redeemed amount.
        IERC4626(underlying).transferFrom(account, owner, IERC4626(underlying).balanceOf(account));
    }

    function isModuleType(uint256 moduleTypeID) external pure returns (bool) {
        return moduleTypeID == MODULE_TYPE_HOOK;
    }

    function onInstall(bytes calldata data) external { }
}
