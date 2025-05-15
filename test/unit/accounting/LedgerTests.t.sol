// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

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

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_SetYieldSourceOracles() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigSet(
            oracleId, oracle, feePercent, feeRecipient, address(this), ledger
        );
        config.setYieldSourceOracles(configs);

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
        config.setYieldSourceOracles(configs);
    }

    function test_ProposeConfig() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Now propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500; // 15%
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_ProposeConfig_ZeroLength_Revert() public {
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](0);
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_LENGTH.selector);
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_ProposeConfig_NotFound_Revert() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: address(0x123),
            feePercent: 1000,
            feeRecipient: address(0x456),
            ledger: address(superLedger)
        });

        vm.expectRevert(ISuperLedgerConfiguration.CONFIG_NOT_FOUND.selector);
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_ProposeConfig_NotManager_Revert() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Try to propose as different address
        vm.prank(address(0x999));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_ProposeConfig_AlreadyProposed_Revert() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Propose first time
        config.proposeYieldSourceOracleConfig(configs);

        // Try to propose again
        vm.expectRevert(ISuperLedgerConfiguration.CHANGE_ALREADY_PROPOSED.selector);
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_ProposeConfig_InvalidFeePercent_Revert() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Try to propose with invalid fee percent (more than 50% change)
        configs[0].feePercent = 2000; // 20% (more than 50% change from 10%)
        vm.expectRevert(ISuperLedgerConfiguration.INVALID_FEE_PERCENT.selector);
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_ProposeConfig_Event_Emission() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigProposalSet(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.proposeYieldSourceOracleConfig(configs);
    }

    function test_AcceptConfigPropsal() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });
        config.proposeYieldSourceOracleConfig(configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        // Accept proposal
        bytes4[] memory oracleIds = new bytes4[](1);
        oracleIds[0] = oracleId;

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigAccepted(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.acceptYieldSourceOracleConfigProposal(oracleIds);

        // Verify new config
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(oracleId);
        assertEq(storedConfig.yieldSourceOracle, newOracle);
        assertEq(storedConfig.feePercent, newFeePercent);
        assertEq(storedConfig.feeRecipient, newFeeRecipient);
        assertEq(storedConfig.ledger, newLedger);
    }

    function test_AcceptConfigPropsal_ZeroLength_Revert() public {
        bytes4[] memory oracleIds = new bytes4[](0);
        vm.expectRevert(ISuperLedgerConfiguration.ZERO_LENGTH.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_AcceptConfigPropsal_NotManager_Revert() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Propose new config
        config.proposeYieldSourceOracleConfig(configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        // Try to accept as different address
        bytes4[] memory oracleIds = new bytes4[](1);
        oracleIds[0] = oracleId;

        vm.prank(address(0x999));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_AcceptConfigPropsal_InvalidTime_Revert() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Propose new config
        config.proposeYieldSourceOracleConfig(configs);

        // Try to accept before expiration
        bytes4[] memory oracleIds = new bytes4[](1);
        oracleIds[0] = oracleId;

        vm.expectRevert(ISuperLedgerConfiguration.CANNOT_ACCEPT_YET.selector);
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_AcceptConfigPropsal_Event_Emission() public {
        // First set initial config
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Propose new config
        address newOracle = address(0x789);
        uint256 newFeePercent = 1500;
        address newFeeRecipient = address(0xabc);
        address newLedger = address(flatFeeLedger);

        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: newOracle,
            feePercent: newFeePercent,
            feeRecipient: newFeeRecipient,
            ledger: newLedger
        });
        config.proposeYieldSourceOracleConfig(configs);

        // Fast forward past proposal expiration
        vm.warp(block.timestamp + 1 weeks + 1);

        // Accept proposal
        bytes4[] memory oracleIds = new bytes4[](1);
        oracleIds[0] = oracleId;

        vm.expectEmit(true, true, false, true);
        emit ISuperLedgerConfiguration.YieldSourceOracleConfigAccepted(
            oracleId, newOracle, newFeePercent, newFeeRecipient, address(this), newLedger
        );
        config.acceptYieldSourceOracleConfigProposal(oracleIds);
    }

    function test_GetYieldSourceConfig() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        ISuperLedgerConfiguration.YieldSourceOracleConfig memory storedConfig =
            config.getYieldSourceOracleConfig(oracleId);
        assertEq(storedConfig.yieldSourceOracle, oracle);
        assertEq(storedConfig.feePercent, feePercent);
        assertEq(storedConfig.feeRecipient, feeRecipient);
        assertEq(storedConfig.manager, address(this));
        assertEq(storedConfig.ledger, ledger);
    }

    function test_GetYieldSourceConfigs() public {
        bytes4 oracleId1 = bytes4(keccak256("test1"));
        bytes4 oracleId2 = bytes4(keccak256("test2"));
        address oracle1 = address(0x123);
        address oracle2 = address(0x456);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x789);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](2);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId1,
            yieldSourceOracle: oracle1,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId2,
            yieldSourceOracle: oracle2,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        bytes4[] memory oracleIds = new bytes4[](2);
        oracleIds[0] = oracleId1;
        oracleIds[1] = oracleId2;

        ISuperLedgerConfiguration.YieldSourceOracleConfig[] memory storedConfigs =
            config.getYieldSourceOracleConfigs(oracleIds);
        assertEq(storedConfigs.length, 2);
        assertEq(storedConfigs[0].yieldSourceOracle, oracle1);
        assertEq(storedConfigs[1].yieldSourceOracle, oracle2);
    }

    function test_TransferManagerRole() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferStarted(oracleId, address(this), newManager);
        config.transferManagerRole(oracleId, newManager);
    }

    function test_TransferManagerRole_NotManager() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        vm.prank(address(0x999));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_MANAGER.selector);
        config.transferManagerRole(oracleId, address(0x888));
    }

    function test_TransferManagerRole_Event_Emission() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        vm.expectEmit(true, true, true, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferStarted(oracleId, address(this), newManager);
        config.transferManagerRole(oracleId, newManager);
    }

    function test_AcceptManagerRole() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

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
        bytes4 oracleId = bytes4(keccak256("test"));
        vm.expectRevert(ISuperLedgerConfiguration.NOT_PENDING_MANAGER.selector);
        config.acceptManagerRole(oracleId);
    }

    function test_AcceptManagerRole_Event_Emission() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);
        address newManager = address(0x999);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        config.transferManagerRole(oracleId, newManager);

        vm.prank(newManager);
        vm.expectEmit(true, true, false, false);
        emit ISuperLedgerConfiguration.ManagerRoleTransferAccepted(oracleId, newManager);
        config.acceptManagerRole(oracleId);
    }

    function test_validateConfig_ZeroAddress_Oracle() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(configs);
    }

    function test_validateConfig_ZeroAddress_FeeRecipient() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(configs);
    }

    function test_validateConfig_ZeroAddress_Ledger() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(0);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ADDRESS_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(configs);
    }

    function test_validateConfig_InvalidFeePercent() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(0x123);
        uint256 feePercent = 5001; // More than MAX_FEE_PERCENT (5000)
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectRevert(ISuperLedgerConfiguration.INVALID_FEE_PERCENT.selector);
        config.setYieldSourceOracles(configs);
    }

    function test_validateConfig_ZeroId() public {
        bytes4 oracleId = bytes4(0);
        address oracle = address(0x123);
        uint256 feePercent = 1000;
        address feeRecipient = address(0x456);
        address ledger = address(superLedger);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });

        vm.expectRevert(ISuperLedgerConfiguration.ZERO_ID_NOT_ALLOWED.selector);
        config.setYieldSourceOracles(configs);
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
        bytes4 oracleId = bytes4(keccak256("test"));
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
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

        vm.prank(address(exec));
        uint256 feeAmount =
            mockBaseLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);

        assertEq(feeAmount, (amountAssets * feePercent) / 10_000, "Fee amount mismatch");
    }

    function test_BaseLedger_UpdateAccountingEvent() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;
        uint256 expectedFee = (amountAssets * feePercent) / 10_000;

        vm.prank(address(exec));
        vm.expectEmit(true, true, true, true);
        emit ISuperLedgerData.AccountingOutflow(user, address(mockOracle), yieldSource, usedShares, expectedFee);
        mockBaseLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);
    }

    /*//////////////////////////////////////////////////////////////
                        FLAT FEE LEDGER TESTS
    //////////////////////////////////////////////////////////////*/
    function test_FlatFeeLedger_ProcessOutflow() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Test flat fee calculation
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18; // 1000 tokens
        uint256 usedShares = 1000e18; // 1000 shares

        // Calculate expected fee (10% of amountAssets)
        uint256 expectedFee = (amountAssets * feePercent) / 10_000;

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

        assertEq(feeAmount, expectedFee, "Fee amount should be 10% of amountAssets");
    }

    function test_FlatFeeLedger_ProcessOutflow_ZeroFee() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 0; // 0%
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Test flat fee calculation with zero fee
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18; // 1000 tokens
        uint256 usedShares = 1000e18; // 1000 shares

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
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 5000; // 50% (max allowed)
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Test flat fee calculation with max fee
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18; // 1000 tokens
        uint256 usedShares = 1000e18; // 1000 shares

        // Calculate expected fee (50% of amountAssets)
        uint256 expectedFee = (amountAssets * feePercent) / 10_000;

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

        assertEq(feeAmount, expectedFee, "Fee amount should be 50% of amountAssets");
    }

    function test_FlatFeeLedger_ProcessOutflow_NotExecutor() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(flatFeeLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

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
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(superLedger); // Wrong ledger address

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Try to call updateAccounting
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

        vm.prank(address(exec));
        vm.expectRevert(ISuperLedgerData.INVALID_LEDGER.selector);
        flatFeeLedger.updateAccounting(user, yieldSource, oracleId, false, amountAssets, usedShares);
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIEW FEES TESTS
    //////////////////////////////////////////////////////////////*/
    function test_PreviewFees_NormalCase() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 0; // 0%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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

    function test_PreviewFees_InsufficientShares() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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

        // Test preview fees with insufficient shares
        vm.expectRevert(ISuperLedgerData.INSUFFICIENT_SHARES.selector);
        mockBaseLedger.previewFees(
            user,
            yieldSource,
            amountAssets,
            usedShares * 2, // Try to use more shares than available
            feePercent
        );
    }

    function test_PreviewFees_MaxFeePercent() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 5000; // 50% (max allowed)
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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
        uint256 costBasis = mockBaseLedger.calculateCostBasisView(user, yieldSource, usedShares / 2);

        // Expected cost basis should be half of the initial amount
        assertEq(costBasis, amountAssets / 2, "Cost basis calculation incorrect");
    }

    function test_CalculateCostBasisView_InsufficientShares() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 usedShares = 1000e18;

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

        // Test cost basis calculation with insufficient shares
        vm.expectRevert(ISuperLedgerData.INSUFFICIENT_SHARES.selector);
        mockBaseLedger.calculateCostBasisView(
            user,
            yieldSource,
            usedShares * 2 // Try to use more shares than available
        );
    }

    function test_CalculateCostBasisView_ZeroShares() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 usedShares = 1000e18;

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
        uint256 costBasis = mockBaseLedger.calculateCostBasisView(user, yieldSource, 0);

        assertEq(costBasis, 0, "Cost basis should be 0 for zero shares");
    }

    function test_CalculateCostBasisView_AllShares() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets = 1000e18;
        uint256 usedShares = 1000e18;

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
        uint256 costBasis = mockBaseLedger.calculateCostBasisView(user, yieldSource, usedShares);

        assertEq(costBasis, amountAssets, "Cost basis should equal total amount for all shares");
    }

    function test_CalculateCostBasisView_MultipleInflows() public {
        bytes4 oracleId = bytes4(keccak256("test"));
        address oracle = address(mockOracle);
        uint256 feePercent = 1000; // 10%
        address feeRecipient = address(this);
        address ledger = address(mockBaseLedger);

        // Set up config
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: oracleId,
            yieldSourceOracle: oracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            ledger: ledger
        });
        config.setYieldSourceOracles(configs);

        // Set up initial shares for the user
        address user = address(0x456);
        address yieldSource = address(0x789);
        uint256 amountAssets1 = 1000e18;
        uint256 amountAssets2 = 2000e18;
        uint256 usedShares1 = 1000e18;
        uint256 usedShares2 = 2000e18;

        // First inflow
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares1,
            0
        );

        // Second inflow
        vm.prank(address(exec));
        mockBaseLedger.updateAccounting(
            user,
            yieldSource,
            oracleId,
            true, // isInflow
            usedShares2,
            0
        );

        // Test cost basis calculation for half of total shares
        uint256 costBasis = mockBaseLedger.calculateCostBasisView(user, yieldSource, (usedShares1 + usedShares2) / 2);

        // Expected cost basis should be half of total amount
        assertEq(
            costBasis, (amountAssets1 + amountAssets2) / 2, "Cost basis calculation incorrect for multiple inflows"
        );
    }
}
