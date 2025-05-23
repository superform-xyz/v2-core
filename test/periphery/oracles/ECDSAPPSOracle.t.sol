// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// External
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import { Test } from "forge-std/Test.sol";

// Superform
import { ISuperGovernor } from "../../../src/periphery/interfaces/ISuperGovernor.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { SuperVaultAggregator } from "../../../src/periphery/SuperVault/SuperVaultAggregator.sol";
import { ISuperVaultAggregator } from "../../../src/periphery/interfaces/ISuperVaultAggregator.sol";
import { ECDSAPPSOracle } from "../../../src/periphery/oracles/ECDSAPPSOracle.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { IECDSAPPSOracle } from "../../../src/periphery/interfaces/IECDSAPPSOracle.sol";
import { SuperVault } from "../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVault/SuperVaultStrategy.sol";

// Test
import { Helpers } from "../../utils/Helpers.sol";
import { BaseSuperVaultTest } from "../integration/SuperVault/BaseSuperVaultTest.t.sol";
import { TotalAssetHelper } from "../integration/SuperVault/TotalAssetHelper.sol";
import { console } from "forge-std/console.sol";

contract ECDSAPPSOracleTest is BaseSuperVaultTest {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Test accounts
    address public user;
    address public validator1;
    address public validator2;
    address public validator3;
    address public mockStrategist;
    address public governorAddress;

    // SuperVault
    address public sv;
    address public svStrategy;

    // Mock data
    uint256 public constant PPS = 1e18; // 1.0
    uint256 public constant PPS_STDEV = 1e16; // 0.01

    ECDSAPPSOracle public oracleECDSA;

    SuperGovernor public governor;
    SuperVaultAggregator public aggregatorSuperVault;

    function setUp() public override {
        super.setUp();

        // Set up test account
        user = _deployAccount(0x2, "User");

        // Create validators
        validator1 = _deployAccount(validator1PrivateKey, "Validator1");
        validator2 = _deployAccount(validator2PrivateKey, "Validator2");
        validator3 = _deployAccount(validator3PrivateKey, "Validator3");

        // Set up mock strategy for testing
        mockStrategist = _deployAccount(0x6, "MockStrategist");

        // Get the governor role to call validator-related functions
        governorAddress = _deployAccount(0x7, "GovernorRole");

        // Create a new governor specifically for these tests
        governor =
            new SuperGovernor(governorAddress, governorAddress, governorAddress, TREASURY, CHAIN_1_POLYMER_PROVER);

        aggregatorSuperVault = new SuperVaultAggregator(address(governor));

        (sv, svStrategy,) = aggregatorSuperVault.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                name: "TestVault",
                symbol: "TV",
                mainStrategist: mockStrategist,
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: TREASURY })
            })
        );

        // Create a new ECDSAPPSOracle with our custom governor
        oracleECDSA = new ECDSAPPSOracle(address(governor));

        vm.startPrank(governorAddress);
        governor.grantRole(governor.GOVERNOR_ROLE(), governorAddress);
        vm.stopPrank();

        // Add validators (requires GOVERNOR_ROLE)
        vm.startPrank(governorAddress);
        governor.addValidator(validator1);
        governor.addValidator(validator2);
        governor.addValidator(validator3);
        governor.setPPSOracleQuorum(2); // Set quorum to 2 validators

        // Set the SuperVaultAggregator
        governor.setAddress(governor.SUPER_VAULT_AGGREGATOR(), address(aggregatorSuperVault));

        // Set the active PPS Oracle
        governor.proposeActivePPSOracle(address(oracleECDSA));

        vm.warp(block.timestamp + 8 days);
        governor.executeActivePPSOracleChange();

        governor.proposeUpkeepPaymentsChange(false);
        vm.warp(block.timestamp + 8 days);
        governor.executeUpkeepPaymentsChange();

        vm.stopPrank();

        assertEq(governor.isActivePPSOracle(address(oracleECDSA)), true);
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Constructor() public view {
        // Test that constructor sets up the contract correctly
        assertEq(address(oracleECDSA.SUPER_GOVERNOR()), address(governor));
    }

    function test_Constructor_ZeroAddressReverts() public {
        // Test constructor reverts with invalid address
        vm.expectRevert(IECDSAPPSOracle.INVALID_VALIDATOR.selector);
        new ECDSAPPSOracle(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          UPDATE PPS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_UpdatePPS_Success() public {
        // Create valid proofs from multiple validators
        bytes[] memory proofs = _createValidProofs(
            address(svStrategy),
            PPS,
            PPS_STDEV,
            2, // validatorSet
            3, // totalValidators
            block.timestamp,
            new uint256[](0)
        );

        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(svStrategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 2,
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    function test_UpdatePPS_InvalidValidatorReverts() public {
        // Create valid proofs but with a non-validator
        uint256 nonValidatorPrivKey = 0x999;

        uint256[] memory signerKeys = new uint256[](2);
        signerKeys[0] = validator1PrivateKey;
        signerKeys[1] = nonValidatorPrivKey;

        // Create message hash with all parameters
        bytes32 messageHash =
            keccak256(abi.encodePacked(address(svStrategy), PPS, PPS_STDEV, uint256(2), uint256(3), block.timestamp));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Create proofs array
        bytes[] memory proofs = new bytes[](signerKeys.length);
        for (uint256 i = 0; i < signerKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKeys[i], ethSignedMessageHash);
            proofs[i] = abi.encodePacked(r, s, v);
        }

        // Call should revert because one signer is not a validator
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.INVALID_VALIDATOR.selector);
        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(svStrategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 2,
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    function test_UpdatePPS_QuorumNotMetReverts() public {
        // Create proof with only one validator when quorum requires two
        uint256[] memory signerKeys = new uint256[](1);
        signerKeys[0] = validator1PrivateKey;

        bytes[] memory proofs = _createValidProofs(
            address(strategy),
            PPS,
            PPS_STDEV,
            1, // validatorSet - only 1 validator signing
            3, // totalValidators
            block.timestamp,
            signerKeys
        );

        // Call should revert because quorum is not met (we set quorum to 2 in setUp)
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.QUORUM_NOT_MET.selector);
        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(strategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 1, // Only 1 validator signed
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    function test_UpdatePPS_DuplicateSignerReverts() public {
        // Create proof with the same validator signing twice
        bytes[] memory proofs = new bytes[](2);

        bytes32 messageHash =
            keccak256(abi.encodePacked(address(strategy), PPS, PPS_STDEV, uint256(2), uint256(3), block.timestamp));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Use validator1 to sign both proofs
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validator1PrivateKey, ethSignedMessageHash);
        proofs[0] = abi.encodePacked(r, s, v);
        proofs[1] = abi.encodePacked(r, s, v); // Same signature again

        // Call should revert because of duplicate signers
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.INVALID_PROOF.selector);
        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(strategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 2,
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    function test_UpdatePPS_ValidatorCountMismatchReverts() public {
        uint256[] memory signerKeys = new uint256[](2);
        signerKeys[0] = validator1PrivateKey;
        signerKeys[1] = validator2PrivateKey;

        // Create message hash with all parameters
        bytes32 messageHash =
            keccak256(abi.encodePacked(address(svStrategy), PPS, PPS_STDEV, uint256(2), uint256(3), block.timestamp));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Create proofs array
        bytes[] memory proofs = new bytes[](signerKeys.length);
        for (uint256 i = 0; i < signerKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKeys[i], ethSignedMessageHash);
            proofs[i] = abi.encodePacked(r, s, v);
        }

        vm.expectRevert(IECDSAPPSOracle.INVALID_VALIDATOR.selector);
        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(svStrategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 1,
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    function test_UpdatePPS_EmptyProofsReverts() public {
        // Create empty proofs array
        bytes[] memory proofs = new bytes[](0);

        // Call should revert because proofs array is empty
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.ZERO_LENGTH_ARRAY.selector);
        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(strategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 0,
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    function test_UpdatePPS_NotActivePPSOracleReverts() public {
        // First set another oracle as active
        address newOracle = address(0xABC);

        // For changing the oracle after first time, we need to use the timelock pattern
        vm.startPrank(governorAddress);
        governor.proposeActivePPSOracle(newOracle);
        vm.warp(block.timestamp + 7 days);
        governor.executeActivePPSOracleChange();
        vm.stopPrank();

        // Create valid proofs
        bytes[] memory proofs = _createValidProofs(
            address(strategy),
            PPS,
            PPS_STDEV,
            2, // validatorSet
            3, // totalValidators
            block.timestamp,
            new uint256[](0)
        );

        // Call should revert because this oracle is not the active one
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.NOT_ACTIVE_PPS_ORACLE.selector);
        oracleECDSA.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(strategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 2,
                totalValidators: 3,
                timestamp: block.timestamp
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                      BATCH UPDATE PPS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BatchUpdatePPS_Success() public {
        // Create two strategies and valid proofs for them
        address strategy1 = address(svStrategy);

        (, address strategy2,) = aggregatorSuperVault.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                name: "Secondary TestVault",
                symbol: "STV",
                mainStrategist: mockStrategist,
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: TREASURY })
            })
        );

        vm.warp(block.timestamp + 1 days);

        address[] memory strategies = new address[](2);
        strategies[0] = strategy1;
        strategies[1] = strategy2;

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = PPS;
        ppss[1] = PPS * 2;

        uint256[] memory ppsStdevs = new uint256[](2);
        ppsStdevs[0] = PPS_STDEV;
        ppsStdevs[1] = PPS_STDEV * 2;

        uint256[] memory validatorSets = new uint256[](2);
        validatorSets[0] = 2;
        validatorSets[1] = 2;

        uint256[] memory totalValidatorsList = new uint256[](2);
        totalValidatorsList[0] = 3;
        totalValidatorsList[1] = 3;

        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = block.timestamp;
        timestamps[1] = block.timestamp;

        bytes[][] memory proofsArray = new bytes[][](2);
        proofsArray[0] = _createValidProofs(
            strategy1, ppss[0], ppsStdevs[0], validatorSets[0], totalValidatorsList[0], timestamps[0], new uint256[](0)
        );
        proofsArray[1] = _createValidProofs(
            strategy2, ppss[1], ppsStdevs[1], validatorSets[1], totalValidatorsList[1], timestamps[1], new uint256[](0)
        );

        // Call batchUpdatePPS
        vm.prank(user);
        oracleECDSA.batchUpdatePPS(
            IECDSAPPSOracle.BatchUpdatePPSArgs({
                strategies: strategies,
                proofsArray: proofsArray,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidatorsList,
                timestamps: timestamps
            })
        );

        // Test passes if no revert occurs
    }

    function test_BatchUpdatePPS_EmptyArrayReverts() public {
        // Create empty arrays
        address[] memory strategies = new address[](0);
        bytes[][] memory proofsArray = new bytes[][](0);
        uint256[] memory ppss = new uint256[](0);
        uint256[] memory ppsStdevs = new uint256[](0);
        uint256[] memory validatorSets = new uint256[](0);
        uint256[] memory totalValidatorsList = new uint256[](0);
        uint256[] memory timestamps = new uint256[](0);

        // Call should revert because arrays are empty
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.ZERO_LENGTH_ARRAY.selector);
        oracleECDSA.batchUpdatePPS(
            IECDSAPPSOracle.BatchUpdatePPSArgs({
                strategies: strategies,
                proofsArray: proofsArray,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidatorsList,
                timestamps: timestamps
            })
        );
    }

    function test_BatchUpdatePPS_ArrayLengthMismatchReverts() public {
        // Create arrays with mismatched lengths
        address[] memory strategies = new address[](2);
        strategies[0] = address(0x111);
        strategies[1] = address(0x222);

        bytes[][] memory proofsArray = new bytes[][](1); // Only one proof set
        proofsArray[0] = _createValidProofs(strategies[0], PPS, PPS_STDEV, 2, 3, block.timestamp, new uint256[](0));

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = PPS;
        ppss[1] = PPS * 2;

        uint256[] memory ppsStdevs = new uint256[](2);
        ppsStdevs[0] = PPS_STDEV;
        ppsStdevs[1] = PPS_STDEV * 2;

        uint256[] memory validatorSets = new uint256[](2);
        validatorSets[0] = 2;
        validatorSets[1] = 2;

        uint256[] memory totalValidatorsList = new uint256[](2);
        totalValidatorsList[0] = 3;
        totalValidatorsList[1] = 3;

        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = block.timestamp;
        timestamps[1] = block.timestamp;

        // Call should revert because proofsArray length doesn't match strategies length
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracleECDSA.batchUpdatePPS(
            IECDSAPPSOracle.BatchUpdatePPSArgs({
                strategies: strategies,
                proofsArray: proofsArray,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidatorsList,
                timestamps: timestamps
            })
        );
    }

    function test_BatchUpdatePPS_ValidationFailureReverts() public {
        // Create two strategies
        address strategy1 = address(0x111);
        address strategy2 = address(0x222);

        address[] memory strategies = new address[](2);
        strategies[0] = strategy1;
        strategies[1] = strategy2;

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = PPS;
        ppss[1] = PPS * 2;

        uint256[] memory ppsStdevs = new uint256[](2);
        ppsStdevs[0] = PPS_STDEV;
        ppsStdevs[1] = PPS_STDEV * 2;

        uint256[] memory validatorSets = new uint256[](2);
        validatorSets[0] = 2;
        validatorSets[1] = 2;

        uint256[] memory totalValidatorsList = new uint256[](2);
        totalValidatorsList[0] = 3;
        totalValidatorsList[1] = 3;

        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = block.timestamp;
        timestamps[1] = block.timestamp;

        // First strategy has valid proofs
        bytes[][] memory proofsArray = new bytes[][](2);
        proofsArray[0] = _createValidProofs(
            strategy1, ppss[0], ppsStdevs[0], validatorSets[0], totalValidatorsList[0], timestamps[0], new uint256[](0)
        );

        // Second strategy has empty proofs array (should trigger ZERO_LENGTH_ARRAY error)
        proofsArray[1] = new bytes[](0);

        // Call should revert because validation fails on the second strategy
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.ZERO_LENGTH_ARRAY.selector);
        oracleECDSA.batchUpdatePPS(
            IECDSAPPSOracle.BatchUpdatePPSArgs({
                strategies: strategies,
                proofsArray: proofsArray,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidatorsList,
                timestamps: timestamps
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_UpdateSuperVaultPPS_Integration() public {
        // Set the VALIDATOR_KEY from the BaseSuperVaultTest as a valid validator
        vm.startPrank(governorAddress);
        governor.addValidator(vm.addr(VALIDATOR_KEY));
        governor.setPPSOracleQuorum(1); // Only need one validator
        vm.stopPrank();

        // Update the PPS using the helper function
        uint256 updatedPPS = _updateSuperVaultPPS(address(strategy), address(vault));

        // Test passes if no revert occurs
        assertEq(updatedPPS, 1e6);
    }
}
