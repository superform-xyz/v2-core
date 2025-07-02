// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { MockLedger } from "../../mocks/MockLedger.sol";
import { MockExecutorModule } from "../../mocks/MockExecutorModule.sol";
import { SuperLedger } from "../../../src/core/accounting/SuperLedger.sol";
import { FlatFeeLedger } from "../../../src/core/accounting/FlatFeeLedger.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperLedgerConfiguration } from "../../../src/core/accounting/SuperLedgerConfiguration.sol";
import { ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedger } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { BaseLedger } from "../../../src/core/accounting/BaseLedger.sol";
import "forge-std/console.sol";

import "forge-std/console2.sol";

contract MockYieldSourceOracle {
    uint256 public pricePerShare = 1e18;
    uint8 public constant DECIMALS = 18;

    function getPricePerShare(address) external view returns (uint256) {
        return pricePerShare;
    }

    function setPricePerShare(uint256 pps) external {
        pricePerShare = pps;
    }

    function decimals(address) external pure returns (uint8) {
        return DECIMALS;
    }
}

// Mock BaseLedger for testing abstract contract functionality
contract MockBaseLedger is BaseLedger {
    constructor(
        address superLedgerConfiguration_,
        address[] memory allowedExecutors_
    )
        BaseLedger(superLedgerConfiguration_, allowedExecutors_)
    { }

    // Implement abstract function for testing
    function _processOutflow(
        address,
        address,
        uint256 amountAssets,
        uint256,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
        internal
        pure
        override
        returns (uint256 feeAmount)
    {
        // Simple implementation for testing
        feeAmount = (amountAssets * config.feePercent) / 10_000;
    }
}

contract LedgerTests is Helpers {
    // Struct to handle stack too deep errors
    struct ConfigTestData {
        bytes32 oracleId;
        address oracle;
        uint256 feePercent;
        address feeRecipient;
        address ledger;
    }
    
    // Additional struct for user data in tests
    struct UserTestData {
        address user;
        address yieldSource;
        uint256 amountAssets1;
        uint256 amountAssets2;
        uint256 usedShares1;
        uint256 usedShares2;
    }
    
    MockLedger public mockLedger;
    MockExecutorModule public exec;
    SuperLedger public superLedger;
    FlatFeeLedger public flatFeeLedger;
    SuperLedgerConfiguration public config;
    MockBaseLedger public mockBaseLedger;
    MockYieldSourceOracle public mockOracle;

    function setUp() public {
        exec = new MockExecutorModule();
        mockLedger = new MockLedger(); // ToDo: update to inherit BaseLedger
        config = new SuperLedgerConfiguration();
        mockOracle = new MockYieldSourceOracle();

        address[] memory executors = new address[](1);
        executors[0] = address(exec);

        superLedger = new SuperLedger(address(config), executors);
        flatFeeLedger = new FlatFeeLedger(address(config), executors);
        mockBaseLedger = new MockBaseLedger(address(config), executors);
    }

    function testOutflowWithZeroFeeSkipsAccounting() public {
        uint256 INITIAL_SHARES = 100 ether; // Amount of shares to deposit initially
        uint256 PPS = 1 ether; // Mock Price Per Share (1 token = 1 share)
        uint8 DECIMALS = 18; // Mock Token decimals

        address user = makeAddr("user");
        address yieldSource = makeAddr("yieldSource");
        bytes32 yieldSourceOracleId = bytes32(keccak256("TEST_ORACLE_ID"));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: yieldSource,
            feePercent: 0,
            feeRecipient: address(this),
            ledger: address(flatFeeLedger)
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = yieldSourceOracleId;
        config.setYieldSourceOracles(salts, configs);

        vm.mockCall(yieldSource, abi.encodeWithSignature("getPricePerShare(address)"), abi.encode(PPS));
        vm.mockCall(yieldSource, abi.encodeWithSignature("decimals(address)"), abi.encode(DECIMALS));

        // User wants to withdraw all shares
        uint256 outflowShares = INITIAL_SHARES;
        // Asset value of the shares (assuming pps hasn't changed)
        uint256 outflowAssets = outflowShares * PPS / (10 ** DECIMALS); // 100e18

        // Initiate the withdrawal transaction (outflow)
        // updateAccounting function has onlyExecutor modifier, so call from executor address
        vm.startPrank(address(exec));
        flatFeeLedger.updateAccounting(
            user,
            yieldSource,
            _getYieldSourceOracleId(yieldSourceOracleId, address(this)),
            false, // isInflow = false (outflow)
            outflowAssets, // amountSharesOrAssets (assets for outflow)
            outflowShares // usedShares (shares used for outflow)
        );
        vm.stopPrank();

        // If the bug exists: The user's internal share and cost basis balances should NOT have been reduced
        // These asserts will PASS if the bug exists.
        // If the bug is fixed, these asserts will FAIL.
        //those now fail
        //assertEq(flatFeeLedger.usersAccumulatorShares(user, yieldSource), INITIAL_SHARES, "BUG: Shares were NOT
        // deducted during zero-fee outflow");
        //assertEq(flatFeeLedger.usersAccumulatorCostBasis(user, yieldSource), INITIAL_SHARES, "BUG: Cost basis was NOT
        // deducted during zero-fee outflow");

        assertEq(flatFeeLedger.usersAccumulatorShares(user, yieldSource), 0, "BUG fixed: this should be 0 now");

        console2.log("PoC Successful: Accounting skipped for zero-fee outflow.");
        console2.log("User Shares (Expected: 0, Actual: %s)", flatFeeLedger.usersAccumulatorShares(user, yieldSource));
        console2.log(
            "User Cost Basis (Expected: 0, Actual: %s)", flatFeeLedger.usersAccumulatorCostBasis(user, yieldSource)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_TransferManagerRole_ToZeroAddress_Vulnerability() public {
        // Setup a configuration first
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        // Initial verification
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory initialConfig =
            config.getYieldSourceOracleConfig(oracleId);
        assertEq(initialConfig.manager, address(this), "Initial manager should be test contract");

        // VULNERABILITY: Transfer manager role to zero address - this should be prevented but isn't
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        // fixed ^
        config.transferManagerRole(oracleId, address(0));

        console.log("VULNERABILITY DEMONSTRATION: Transferred manager role to zero address without revert");

        // Try to make a proposal as the current manager - should still work because the transfer isn't complete
        address newOracle = address(0x999);
        configs[0].yieldSourceOracle = newOracle;
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        console.log("Current manager can still make proposals");

        // Demonstrate that the role transfer is now stuck - no one can accept it
        console.log("VULNERABILITY IMPACT: The role transfer is now stuck because:");
        console.log("1. The pending manager is address(0)");
        console.log("2. address(0) cannot call acceptManagerRole()");
        console.log("3. No other address is authorized to accept the role");

        // Verify our current state
        address currentManager = config.getYieldSourceOracleConfig(oracleId).manager;
        assertEq(currentManager, address(this), "Original manager should still be in control");

        // Try to initiate another transfer to fix the situation
        address validNewManager = address(0x888);
        config.transferManagerRole(oracleId, validNewManager);

        // Have the new valid manager accept the role
        vm.prank(validNewManager);
        config.acceptManagerRole(oracleId);

        // Verify the transfer succeeded
        address finalManager = config.getYieldSourceOracleConfig(oracleId).manager;
        assertEq(finalManager, validNewManager, "New valid manager should now be in control");

        console.log("VULNERABILITY MITIGATION: Current manager was able to overwrite the zero address transfer");
        console.log("But this requires the manager to realize the issue and take corrective action");
    }

    function test_AcceptManagerRole_PendingProposal() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // Propose new config
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        bytes32[] memory oracleIds = new bytes32[](1);
        oracleIds[0] = oracleId;

        config.transferManagerRole(oracleId, newManager);

        vm.prank(newManager);
        vm.expectEmit(true, true, false, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferAccepted(oracleId, newManager);
        // manager acceptance before proposal acceptance
        config.acceptManagerRole(oracleId);

        vm.prank(newManager);
        // manager not updated in proposal config
        //vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        //^ fixed
        config.acceptYieldSourceOracleConfigProposal(oracleIds);

        // manager updated in oracle config
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(oracleId);
        assertEq(storedConfig.manager, newManager);
    }

    function test_SetYieldSourceOracles() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigSet(
            _getYieldSourceOracleId(oracleId, address(this)), oracle, feePercent, feeRecipient, address(this), ledger
        );
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(oracleId);
        assertEq(storedConfig.yieldSourceOracle, oracle);
        assertEq(storedConfig.feePercent, feePercent);
        assertEq(storedConfig.feeRecipient, feeRecipient);
        assertEq(storedConfig.manager, address(this));
        assertEq(storedConfig.ledger, ledger);
    }

    function test_SetYieldSourceOracles_ZeroLength_Revert() public {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](0);
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_LENGTH.selector);
        bytes32[] memory salts = new bytes32[](0);
        config.setYieldSourceOracles(salts, configs);
    }

    function test_ProposeConfig() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Now propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500; // 15%
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_ProposeConfig_ZeroLength_Revert() public {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](0);
        bytes32[] memory yieldSourceOracleIds = new bytes32[](0);
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_LENGTH.selector);
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_ProposeConfig_NotFound_Revert() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(0x123),
            feePercent: 1000,
            feeRecipient: address(0x456),
            ledger: address(superLedger)
        });
        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.CONFIG_NOT_FOUND.selector);
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_ProposeConfig_NotManager_Revert() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Try to propose as different address
        vm.startPrank(address(0x999));
        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
        vm.stopPrank();
    }

    function test_ProposeConfig_AlreadyProposed_Revert() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        // Propose first time
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Try to propose again
        vm.expectRevert(ISuperLedgerConfiguration.CHANGE_ALREADY_PROPOSED.selector);
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_ProposeConfig_InvalidFeePercent_Revert() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Try to propose with invalid fee percent (more than 50% change)
        configs[0].feePercent = 2000; // 20% (more than 50% change from 10%)
        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.INVALID_FEE_PERCENT.selector);
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_ProposeConfig_Event_Emission() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_AcceptConfigPropsal() public {
        // First set initial config
        ConfigTestData memory initialConfig;
        initialConfig.oracleId = bytes32(keccak256("test"));
        initialConfig.oracle = address(0x123);
        initialConfig.feePercent = 1000;
        initialConfig.feeRecipient = address(0x456);
        initialConfig.ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: initialConfig.oracle,
            feePercent: initialConfig.feePercent,
            feeRecipient: initialConfig.feeRecipient,
            ledger: initialConfig.ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = initialConfig.oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Propose new config
        ConfigTestData memory newConfig;
        newConfig.oracle = address(0x789);
        newConfig.feePercent = 1500;
        newConfig.feeRecipient = address(0xabc);
        newConfig.ledger = address(flatFeeLedger);
        
        // Get the complete oracle ID
        newConfig.oracleId = _getYieldSourceOracleId(initialConfig.oracleId, address(this));
        
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newConfig.oracle,
            feePercent: newConfig.feePercent,
            feeRecipient: newConfig.feeRecipient,
            ledger: newConfig.ledger
        });
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = newConfig.oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        // Accept proposal
        bytes32[] memory oracleIds = new bytes32[](1);
        oracleIds[0] = newConfig.oracleId;

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigAccepted(
            newConfig.oracleId, newConfig.oracle, newConfig.feePercent, newConfig.feeRecipient, address(this), newConfig.ledger
        );
        config.acceptYieldSourceOracleConfigProposal(oracleIds);

        // Verify new config
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(newConfig.oracleId);
        assertEq(storedConfig.yieldSourceOracle, newConfig.oracle);
        assertEq(storedConfig.feePercent, newConfig.feePercent);
        assertEq(storedConfig.feeRecipient, newConfig.feeRecipient);
        assertEq(storedConfig.ledger, newConfig.ledger);
    }

    function test_AcceptConfigPropsal_ZeroLength_Revert() public {
        bytes32[] memory oracleIds = new bytes32[](0);
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_LENGTH.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_AcceptConfigPropsal_NotManager_Revert() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        // Propose new config
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        // Try to accept as different address
        bytes32[] memory oracleIds = new bytes32[](1);
        oracleIds[0] = oracleId;

        vm.prank(address(0x999));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_AcceptConfigPropsal_InvalidTime_Revert() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        // Propose new config
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Try to accept before expiration
        bytes32[] memory oracleIds = new bytes32[](1);
        oracleIds[0] = oracleId;

        vm.expectRevert(ISuperLedgerConfiguration.CANNOT_ACCEPT_YET.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_GetAllCreatedIds() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        bytes32[] memory oracleIds = config.getAllYieldSourceOracleIdsByOwner(address(this));
        assertEq(oracleIds.length, 1);
        assertEq(oracleIds[0], _getYieldSourceOracleId(oracleId, address(this)));

        oracleIds = config.getAllYieldSourceOracleIdsByOwner(address(0x1));
        assertEq(oracleIds.length, 0);
    }

    function test_AcceptConfigPropsal_Event_Emission() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(salts, configs);

        // Propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        // Accept proposal
        bytes32[] memory oracleIds = new bytes32[](1);
        oracleIds[0] = oracleId;

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigAccepted(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_GetYieldSourceConfig() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(_getYieldSourceOracleId(oracleId, address(this)));
        assertEq(storedConfig.yieldSourceOracle, oracle);
        assertEq(storedConfig.feePercent, feePercent);
        assertEq(storedConfig.feeRecipient, feeRecipient);
        assertEq(storedConfig.manager, address(this));
        assertEq(storedConfig.ledger, ledger);
    }

    function test_GetYieldSourceConfigs() public {
        bytes32 oracleId1 = bytes32(keccak256("test1"));
        bytes32 oracleId2 = bytes32(keccak256("test2"));
        address oracle1 = address(0x123);
        address oracle2 = address(0x456);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x789);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](2);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle1,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle2,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](2);
        salts[0] = oracleId1;
        salts[1] = oracleId2;
        config.setYieldSourceOracles(salts, configs);

        bytes32[] memory oracleIds = new bytes32[](2);
        oracleIds[0] = _getYieldSourceOracleId(oracleId1, address(this));
        oracleIds[1] = _getYieldSourceOracleId(oracleId2, address(this));

        ISuperLedgerConfiguration.YieldSourceOracleConfig[] memory storedConfigs =
            config.getYieldSourceOracleConfigs(oracleIds);
        assertEq(storedConfigs.length, 2);
        assertEq(storedConfigs[0].yieldSourceOracle, oracle1);
        assertEq(storedConfigs[1].yieldSourceOracle, oracle2);
    }

    function test_TransferManagerRole() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferStarted(oracleId, address(this), newManager);
        config.transferManagerRole(oracleId, newManager);
    }

    function test_TransferManagerRole_NotManager() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        vm.prank(address(0x999));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        config.transferManagerRole(oracleId, address(0x888));
    }

    function test_TransferManagerRole_Event_Emission() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferStarted(oracleId, address(this), newManager);
        config.transferManagerRole(oracleId, newManager);
    }

    function test_AcceptManagerRole() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        config.transferManagerRole(oracleId, newManager);

        vm.prank(newManager);
        vm.expectEmit(true, true, false, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferAccepted(oracleId, newManager);
        config.acceptManagerRole(oracleId);

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(oracleId);
        assertEq(storedConfig.manager, newManager);
    }

    function test_AcceptManagerRole_NotPending() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_PENDING_MANAGER.selector);
        config.acceptManagerRole(oracleId);
    }

    function test_AcceptManagerRole_Event_Emission() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        config.transferManagerRole(oracleId, newManager);

        vm.prank(newManager);
        vm.expectEmit(true, true, false, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferAccepted(oracleId, newManager);
        config.acceptManagerRole(oracleId);
    }

    function test_validateConfig_ZeroAddress_Oracle() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(salts, configs);
    }

    function test_validateConfig_ZeroAddress_FeeRecipient() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(salts, configs);
    }

    function test_validateConfig_ZeroAddress_Ledger() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(0);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(salts, configs);
    }

    function test_validateConfig_InvalidFeePercent() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 5001; // More than MAX_FEE_PERCENT (5000)
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.INVALID_FEE_PERCENT.selector);
        config.setYieldSourceOracles(salts, configs);
    }

    function test_validateConfig_ZeroId() public {
        bytes32 oracleId = bytes32(0);
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ID_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(salts, configs);
    }

    function test_setYieldSourceOracles_LedgerCollision_DoS() public {
        // Honest user setup
        address honestUser = makeAddr("honestUser");

        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = honestUser;
        address honestLedger = address(0xA1);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory honestConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        honestConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: honestLedger
        });

        // Malicious user uses same oracleId but different ledger address
        address maliciousUser = makeAddr("maliciousUser");
        address fakeLedger = address(0xA2);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory maliciousConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        maliciousConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: 3000,
            feeRecipient: maliciousUser,
            ledger: fakeLedger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;

        // Malicious config is front-run
        vm.prank(maliciousUser);
        config.setYieldSourceOracles(salts, maliciousConfigs);

        // Honest user now attempts to set original config
        vm.startPrank(honestUser);
        config.setYieldSourceOracles(salts, honestConfigs);

        // Verify that the malicious configuration did NOT persist
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(_getYieldSourceOracleId(oracleId, honestUser));

        assertEq(storedConfig.feePercent, feePercent);
        assertEq(storedConfig.feeRecipient, feeRecipient);
        assertEq(storedConfig.ledger, honestLedger);
    }


    function testOrion_setYieldSourceOracles_Invalid_Id_DoS_works() public {
        // Step 1: Honest user sets up oracle configuration
        address honestUser = makeAddr("honestUser");

        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        // Step 2: Malicious user frontruns honest user, changing parameters forcing the call to revert
        address maliciousUser = makeAddr("maliciousUser");
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory maliciousConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        maliciousConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: 5000, // 50% fee instead of 10% fee
            feeRecipient: maliciousUser, // fee recipient is now set to malicious user
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;

        // Frontrunning transaction
        vm.prank(maliciousUser);
        config.setYieldSourceOracles(salts, maliciousConfigs);

        // Actual transaction from honest user, which reverts
        vm.startPrank(honestUser);
        //vm.expectRevert("CONFIG_EXISTS()");
        // ^ this doesn't revert anymore
        config.setYieldSourceOracles(salts, configs);

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(_getYieldSourceOracleId(oracleId, honestUser));
        assertEq(storedConfig.feeRecipient, feeRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                          BASE LEDGER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BaseLedger_Constructor() public {
        address[] memory executors = new address[](1);
        executors[0] = address(exec);
        MockBaseLedger newLedger = new MockBaseLedger(address(config), executors);

        assertEq(address(newLedger.superLedgerConfiguration()), address(config), "Config address mismatch");
        assertTrue(newLedger.allowedExecutors(address(exec)), "Executor not set");
    }

    function test_BaseLedger_OnlyExecutor() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

        // Try to call updateAccounting as non-executor
        vm.prank(address(0x999));
        vm.expectRevert(ISuperLedgerData.NOT_AUTHORIZED.selector);
        mockBaseLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);
    }

    function test_BaseLedger_UpdateAccountValidation() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        vm.prank(address(exec));
        uint256 feeAmount =
            mockBaseLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);

        assertEq(feeAmount, (amountAssets * feePercent) / 10_000, "Fee amount mismatch");
    }

    function test_BaseLedger_UpdateAccountingEvent() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        uint256 expectedFee = (amountAssets * feePercent) / 10_000;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        vm.prank(address(exec));
        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingOutflow(user, address(mockOracle), yieldSource, usedShares, expectedFee);
        mockBaseLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);
    }

    /*//////////////////////////////////////////////////////////////
                        FLAT FEE LEDGER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_FlatFeeLedger_ProcessOutflow() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // Calculate expected fee (10% of amountAssets)
        uint256 expectedFee = (1000e18 * feePercent) / 10_000;

        // Call updateAccounting through the executor
        vm.prank(address(exec));
        uint256 feeAmount = flatFeeLedger.updateAccounting(
            address(0x456),
            address(0x789),
            oracleId,
            false, // isInflow
            1000e18,
            1000e18
        );

        assertEq(feeAmount, expectedFee, "Fee amount should be 10% of amountAssets");
    }

    function test_FlatFeeLedger_ProcessOutflow_ZeroFee() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 0; // 0%
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Test flat fee calculation with zero fee
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18; // 1000 tokens
        uint256 usedShares = 1000e18; // 1000 shares
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // Call updateAccounting through the executor
        vm.prank(address(exec));
        uint256 feeAmount = flatFeeLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            false, // isInflow
            amountAssets,
            usedShares
        );

        assertEq(feeAmount, 0, "Fee amount should be 0 when feePercent is 0");
    }

    function test_FlatFeeLedger_ProcessOutflow_MaxFee() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 5000; // 50% (max allowed)
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Calculate expected fee (50% of amountAssets)
        uint256 expectedFee = (1000e18 * feePercent) / 10_000;

        // Call updateAccounting through the executor
        vm.prank(address(exec));
        uint256 feeAmount = flatFeeLedger.updateAccounting(
            address(0x456),
            address(0x789),
            _getYieldSourceOracleId(oracleId, address(this)),
            false, // isInflow
            1000e18,
            1000e18
        );

        assertEq(feeAmount, expectedFee, "Fee amount should be 50% of amountAssets");
    }

    function test_FlatFeeLedger_ProcessOutflow_NotExecutor() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Try to call updateAccounting as non-executor
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

        vm.prank(address(0x999)); // Random address that's not an executor
        vm.expectRevert(ISuperLedgerData.NOT_AUTHORIZED.selector);
        flatFeeLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);
    }

    function test_FlatFeeLedger_ProcessOutflow_InvalidLedger() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(superLedger); // Wrong ledger address

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Try to call updateAccounting
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        vm.prank(address(exec));
        vm.expectRevert(ISuperLedgerData.INVALID_LEDGER.selector);
        flatFeeLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIEW FEES TESTS
    //////////////////////////////////////////////////////////////*/
    function test_PreviewFees_NormalCase() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test preview fees with profit
        uint256 previewFee = mockBaseLedger.previewFees(
            user,
            yieldSource,
            amountAssets * 2, // Double the assets to ensure profit
            usedShares,
            feePercent
        );

        // Expected fee should be 10% of the profit
        uint256 expectedFee = (amountAssets * feePercent) / 10_000;
        assertEq(previewFee, expectedFee, "Preview fee calculation incorrect");
    }

    function test_PreviewFees_NoProfit() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test preview fees with no profit (amountAssets equals cost basis)
        uint256 previewFee = mockBaseLedger.previewFees(
            user,
            yieldSource,
            amountAssets, // Same as cost basis
            usedShares,
            feePercent
        );

        assertEq(previewFee, 0, "Preview fee should be 0 when there's no profit");
    }

    function test_PreviewFees_ZeroFeePercent() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 0; // 0%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test preview fees with zero fee percent
        oracleId = _getYieldSourceOracleId(oracleId, address(this));
        vm.expectRevert(ISuperLedgerData.FEE_NOT_SET.selector);
        uint256 previewFee = mockBaseLedger.previewFees(
            user,
            yieldSource,
            amountAssets * 2, // Double the assets to ensure profit
            usedShares,
            feePercent
        );

        assertEq(previewFee, 0, "Preview fee should be 0 when fee percent is 0");
    }

    function test_PreviewFees_MaxFeePercent() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 5000; // 50% (max allowed)
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test preview fees with max fee percent
        uint256 previewFee = mockBaseLedger.previewFees(
            user,
            yieldSource,
            amountAssets * 2, // Double the assets to ensure profit
            usedShares,
            feePercent
        );

        // Expected fee should be 50% of the profit
        uint256 expectedFee = (amountAssets * feePercent) / 10_000;
        assertEq(previewFee, expectedFee, "Preview fee calculation incorrect with max fee percent");
    }

    /*//////////////////////////////////////////////////////////////
                    CALCULATE COST BASIS VIEW TESTS
    //////////////////////////////////////////////////////////////*/
    function test_CalculateCostBasisView_NormalCase() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test cost basis calculation for half the shares
        (uint256 costBasis,) = mockBaseLedger.calculateCostBasisView(user, yieldSource, usedShares / 2);

        // Expected cost basis should be half of the initial amount
        assertEq(costBasis, amountAssets / 2, "Cost basis calculation incorrect");
    }

    function test_CalculateCostBasisView_ZeroShares() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 usedShares = 1000e18;
        oracleId = _getYieldSourceOracleId(oracleId, address(this));


        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test cost basis calculation with zero shares
        (uint256 costBasis,) = mockBaseLedger.calculateCostBasisView(user, yieldSource, 0);

        assertEq(costBasis, 0, "Cost basis should be 0 for zero shares");
    }

    function test_CalculateCostBasisView_AllShares() public {
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        // First do an inflow to set up shares
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares,
            0
        );

        // Test cost basis calculation for all shares
        (uint256 costBasis,) = mockBaseLedger.calculateCostBasisView(user, yieldSource, usedShares);

        assertEq(costBasis, amountAssets, "Cost basis should equal total amount for all shares");
    }

    function test_CalculateCostBasisView_MultipleInflows() public {
        // Set up config data
        ConfigTestData memory configData;
        configData.oracleId = bytes32(keccak256("test"));
        configData.oracle = address(mockOracle);
        configData.feePercent = 1000; // 10%
        configData.feeRecipient = address(this);
        configData.ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: configData.oracle,
            feePercent: configData.feePercent,
            feeRecipient: configData.feeRecipient,
            ledger: configData.ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = configData.oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Set up user test data
        UserTestData memory userData;
        userData.user = address(0x456);
        userData.yieldSource = address(0x789);
        userData.amountAssets1 = 1000e18;
        userData.amountAssets2 = 2000e18;
        userData.usedShares1 = 1000e18;
        userData.usedShares2 = 2000e18;

        // Get complete oracle ID
        configData.oracleId = _getYieldSourceOracleId(configData.oracleId, address(this));

        // First inflow
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            userData.user,
            userData.yieldSource,
            configData.oracleId,
            true, // isInflow
            userData.usedShares1,
            0
        );

        // Second inflow
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            userData.user,
            userData.yieldSource,
            configData.oracleId,
            true, // isInflow
            userData.usedShares2,
            0
        );

        // Test cost basis calculation for half of total shares
        (uint256 costBasis,) = mockBaseLedger.calculateCostBasisView(
            userData.user, 
            userData.yieldSource, 
            (userData.usedShares1 + userData.usedShares2) / 2
        );

        // Expected cost basis should be half of total amount
        assertEq(
            costBasis, 
            (userData.amountAssets1 + userData.amountAssets2) / 2, 
            "Cost basis calculation incorrect for multiple inflows"
        );
    }

    function test_CancelConfigProposal() public {
        // First set initial config
        bytes32 oracleId = bytes32(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        // Now propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500; // 15%
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });

        // Create proposal
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        // Check proposal exists by attempting to accept before expiration (should revert)
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.CANNOT_ACCEPT_YET.selector);
        config.acceptYieldSourceOracleConfigProposal(ids);

        // Cancel the proposal
        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalCancelled(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.cancelYieldSourceOracleConfigProposal(oracleId);

        // Verify proposal was cancelled by checking it can't be accepted
        vm.warp(block.timestamp + 1 weeks + 1); // Move past timelock period
        vm.expectRevert(ISuperLedgerConfiguration.CONFIG_NOT_FOUND.selector);
        config.acceptYieldSourceOracleConfigProposal(ids);
    }

    function test_YieldSourceOracleConfigSet_EventFields() public {
        bytes32 oracleId = bytes32(keccak256("testFieldOrder"));
        address oracle = address(0xABCD);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(0xDEF0);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigSet(
            _getYieldSourceOracleId(oracleId, address(this)), oracle, feePercent, feeRecipient, address(this), ledger
        );
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);
    }

    function test_YieldSourceOracleConfigProposalSet_EventFields() public {
        bytes32 oracleId = bytes32(keccak256("testFieldOrder"));
        address oracle = address(0xABCD);
        uint256 feePercent = 1000;
        address feeRecipient = address(0xDEF0);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        address newOracle = address(0x1234);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0x5678);
        address newLedger = address(flatFeeLedger);

        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);
    }

    function test_YieldSourceOracleConfigAccepted_EventFields() public {
        bytes32 oracleId = bytes32(keccak256("testFieldOrder"));
        address oracle = address(0xABCD);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(0xDEF0);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = oracleId;
        config.setYieldSourceOracles(salts, configs);

        address newOracle = address(0x1234);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0x5678);
        address newLedger = address(flatFeeLedger);
        oracleId = _getYieldSourceOracleId(oracleId, address(this));

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });
        bytes32[] memory yieldSourceOracleIds = new bytes32[](1);
        yieldSourceOracleIds[0] = oracleId;
        config.proposeYieldSourceOracleConfig(yieldSourceOracleIds, configs);

        vm.warp(block.timestamp + 1 weeks + 1);

        bytes32[] memory oracleIds = new bytes32[](1);
        oracleIds[0] = oracleId;

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigAccepted(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_ProposeYieldSourceOracleConfig_NewProposalAfterExpiration() public {
        ConfigTestData memory initialConfig;
        initialConfig.oracleId = bytes32(keccak256("test"));
        initialConfig.oracle = address(mockOracle);
        initialConfig.feePercent = 1000; // 10%
        initialConfig.feeRecipient = makeAddr("initialRecipient");
        initialConfig.ledger = address(mockBaseLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory initialConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        initialConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: initialConfig.oracle,
            feePercent: initialConfig.feePercent,
            feeRecipient: initialConfig.feeRecipient,
            ledger: initialConfig.ledger
        });
        bytes32[] memory salts = new bytes32[](1);
        salts[0] = initialConfig.oracleId;
        config.setYieldSourceOracles(salts, initialConfigs);

        initialConfig.oracleId = _getYieldSourceOracleId(initialConfig.oracleId, address(this));

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory existingConfig =
            config.getYieldSourceOracleConfig(initialConfig.oracleId);
        assertEq(existingConfig.yieldSourceOracle, initialConfig.oracle);
        assertEq(existingConfig.feePercent, initialConfig.feePercent);
        assertEq(existingConfig.feeRecipient, initialConfig.feeRecipient);
        assertEq(existingConfig.manager, address(this));
        assertEq(existingConfig.ledger, initialConfig.ledger);

        // 1st proposal
        ConfigTestData memory firstProposal;
        firstProposal.oracleId = initialConfig.oracleId; // Same oracle ID
        firstProposal.oracle = initialConfig.oracle; // Same oracle
        firstProposal.feePercent = 1200; // 12%
        firstProposal.feeRecipient = makeAddr("proposalRecipient1");
        firstProposal.ledger = initialConfig.ledger; // Same ledger

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory firstProposalConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        firstProposalConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: firstProposal.oracle,
            feePercent: firstProposal.feePercent,
            feeRecipient: firstProposal.feeRecipient,
            ledger: firstProposal.ledger
        });
        bytes32[] memory firstProposalIds = new bytes32[](1);
        firstProposalIds[0] = firstProposal.oracleId;

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            firstProposal.oracleId,
            firstProposal.oracle,
            firstProposal.feePercent,
            firstProposal.feeRecipient,
            address(this),
            firstProposal.ledger
        );
        config.proposeYieldSourceOracleConfig(firstProposalIds, firstProposalConfigs);

        vm.warp(block.timestamp + 7 days + 1);

        // 2nd proposal data
        ConfigTestData memory secondProposal;
        secondProposal.oracleId = initialConfig.oracleId; // Same oracle ID
        secondProposal.oracle = initialConfig.oracle; // Same oracle
        secondProposal.feePercent = 1300; // 13%
        secondProposal.feeRecipient = makeAddr("proposalRecipient2");
        secondProposal.ledger = address(flatFeeLedger); // Different ledger

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory secondProposalConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        secondProposalConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: secondProposal.oracle,
            feePercent: secondProposal.feePercent,
            feeRecipient: secondProposal.feeRecipient,
            ledger: secondProposal.ledger
        });

        bytes32[] memory secondProposalIds = new bytes32[](1);
        secondProposalIds[0] = secondProposal.oracleId;

        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            secondProposal.oracleId,
            secondProposal.oracle,
            secondProposal.feePercent,
            secondProposal.feeRecipient,
            address(this),
            secondProposal.ledger
        );
        config.proposeYieldSourceOracleConfig(secondProposalIds, secondProposalConfigs);

        // accept 2nd but fails
        bytes32[] memory oracleIdsToAccept = new bytes32[](1);
        oracleIdsToAccept[0] = secondProposal.oracleId;
        vm.expectRevert(ISuperLedgerConfiguration.CANNOT_ACCEPT_YET.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIdsToAccept);

        vm.warp(block.timestamp + 7 days + 1);

        // now works
        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigAccepted(
            secondProposal.oracleId,
            secondProposal.oracle,
            secondProposal.feePercent,
            secondProposal.feeRecipient,
            address(this),
            secondProposal.ledger
        );
        config.acceptYieldSourceOracleConfigProposal(oracleIdsToAccept);

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory finalConfig =
            config.getYieldSourceOracleConfig(secondProposal.oracleId);
        assertEq(finalConfig.yieldSourceOracle, secondProposal.oracle);
        assertEq(finalConfig.feePercent, secondProposal.feePercent);
        assertEq(finalConfig.feeRecipient, secondProposal.feeRecipient);
        assertEq(finalConfig.manager, address(this));
        assertEq(finalConfig.ledger, secondProposal.ledger);
    }

    function _getYieldSourceOracleId(bytes32 id, address sender) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, sender));
    }

}
