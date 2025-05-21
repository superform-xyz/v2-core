// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// External
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import { Test } from "forge-std/Test.sol";

// Superform
import { ISuperGovernor } from "../../../src/periphery/interfaces/ISuperGovernor.sol";
import { SuperGovernor } from "../../../src/periphery/SuperGovernor.sol";
import { ISuperVaultAggregator } from "../../../src/periphery/interfaces/ISuperVaultAggregator.sol";
import { ECDSAPPSOracle } from "../../../src/periphery/oracles/ECDSAPPSOracle.sol";
import { IECDSAPPSOracle } from "../../../src/periphery/interfaces/IECDSAPPSOracle.sol";
import { SuperVault } from "../../../src/periphery/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVault/SuperVaultStrategy.sol";

// Test
import { Helpers } from "../../utils/Helpers.sol";
import { console } from "forge-std/console.sol";
import { TotalAssetHelper } from "../integration/SuperVault/TotalAssetHelper.sol";
import { BaseSuperVaultTest } from "../integration/SuperVault/BaseSuperVaultTest.t.sol";

contract ECDSAPPSOracleTest is BaseSuperVaultTest {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public validator1PrivateKey;
    uint256 public validator2PrivateKey;
    uint256 public validator3PrivateKey;

    // Test accounts
    address public user;
    address public deployer;
    address public validator1;
    address public validator2;
    address public validator3;
    address public mockStrategist;
    address public governorAddress;

    // Mock data
    uint256 public constant PPS = 1e18; // 1.0
    uint256 public constant PPS_STDEV = 1e16; // 0.01

    ECDSAPPSOracle public oracle;

    function setUp() public override {
        super.setUp();

        // Set up test accounts
        deployer = _deployAccount(0x1, "Deployer");
        user = _deployAccount(0x2, "User");

        // Create validators
        validator1PrivateKey = 0x3;
        validator2PrivateKey = 0x4;
        validator3PrivateKey = 0x5;
        validator1 = _deployAccount(validator1PrivateKey, "Validator1");
        validator2 = _deployAccount(validator2PrivateKey, "Validator2");
        validator3 = _deployAccount(validator3PrivateKey, "Validator3");

        // Set up mock strategy for testing
        mockStrategist = _deployAccount(0x6, "MockStrategist");

        // Get the governor role to call validator-related functions
        governorAddress = _deployAccount(0x7, "GovernorRole");

        // Create a new SuperGovernor specifically for these tests
        superGovernor =
            new SuperGovernor(governorAddress, governorAddress, governorAddress, TREASURY, CHAIN_1_POLYMER_PROVER);

        // Create a new ECDSAPPSOracle with our custom SuperGovernor
        oracle = new ECDSAPPSOracle(address(superGovernor));

        vm.startPrank(governorAddress);
        superGovernor.grantRole(superGovernor.GOVERNOR_ROLE(), governorAddress);
        vm.stopPrank();

        // Add validators (requires GOVERNOR_ROLE)
        vm.startPrank(governorAddress);
        superGovernor.addValidator(validator1);
        superGovernor.addValidator(validator2);
        superGovernor.addValidator(validator3);
        superGovernor.setPPSOracleQuorum(2); // Set quorum to 2 validators

        // Set the active PPS Oracle
        superGovernor.setActivePPSOracle(address(oracle));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Constructor() public view {
        // Test that constructor sets up the contract correctly
        assertEq(address(oracle.SUPER_GOVERNOR()), address(superGovernor));
    }

    function test_Constructor_ZeroAddressReverts() public {
        // Test constructor reverts with invalid address
        vm.expectRevert(IECDSAPPSOracle.INVALID_VALIDATOR.selector);
        new ECDSAPPSOracle(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATEPPS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_UpdatePPS_Success() public {
        // Create valid proofs from multiple validators
        bytes[] memory proofs = _createValidProofs(
            address(strategy),
            PPS,
            PPS_STDEV,
            2, // validatorSet
            3, // totalValidators
            block.timestamp,
            new uint256[](0)
        );

        // Call updatePPS
        vm.prank(user);
        oracle.updatePPS(
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

    function test_UpdatePPS_InvalidValidatorReverts() public {
        // Create valid proofs but with a non-validator
        uint256 nonValidatorPrivKey = 0x999;
        address nonValidator = vm.addr(nonValidatorPrivKey);

        uint256[] memory signerKeys = new uint256[](2);
        signerKeys[0] = validator1PrivateKey;
        signerKeys[1] = nonValidatorPrivKey;

        bytes[] memory proofs = _createValidProofs(
            address(strategy),
            PPS,
            PPS_STDEV,
            2, // validatorSet
            3, // totalValidators
            block.timestamp,
            signerKeys
        );

        // Call should revert because one signer is not a validator
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.INVALID_VALIDATOR.selector);
        oracle.updatePPS(
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
        oracle.updatePPS(
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
        oracle.updatePPS(
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
        // Create valid proofs from 2 validators
        bytes[] memory proofs = _createValidProofs(
            address(strategy),
            PPS,
            PPS_STDEV,
            2, // validatorSet - 2 validators signing
            3, // totalValidators
            block.timestamp,
            new uint256[](0)
        );

        // Call should revert because validatorSet doesn't match proof count
        vm.prank(user);
        vm.expectRevert(IECDSAPPSOracle.VALIDATOR_COUNT_MISMATCH.selector);
        oracle.updatePPS(
            IECDSAPPSOracle.UpdatePPSArgs({
                strategy: address(strategy),
                proofs: proofs,
                pps: PPS,
                ppsStdev: PPS_STDEV,
                validatorSet: 3, // Reporting 3 validators when only 2 signed
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
        oracle.updatePPS(
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
        superGovernor.proposeActivePPSOracle(newOracle);
        vm.warp(block.timestamp + 7 days);
        superGovernor.executeActivePPSOracleChange();
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
        oracle.updatePPS(
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
                      BATCHUPDATEPPS TESTS
    //////////////////////////////////////////////////////////////*/
    function test_BatchUpdatePPS_Success() public {
        // Create two strategies and valid proofs for them
        address strategy1 = address(0x111);
        address strategy2 = address(0x222);

        address[] memory strategies = new address[](2);
        strategies[0] = strategy1;
        strategies[1] = strategy2;

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = PPS;
        ppss[1] = PPS * 2; // Different PPS for second strategy

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
        oracle.batchUpdatePPS(
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
        oracle.batchUpdatePPS(
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
        oracle.batchUpdatePPS(
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
        oracle.batchUpdatePPS(
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
        address strategyAddr = address(strategy);
        address vaultAddr = address(vault);

        // Set the VALIDATOR_KEY from the BaseSuperVaultTest as a valid validator
        vm.startPrank(governorAddress);
        superGovernor.addValidator(vm.addr(VALIDATOR_KEY));
        superGovernor.setPPSOracleQuorum(1); // Only need one validator
        vm.stopPrank();

        // Update the PPS using the helper function
        uint256 updatedPPS = _updateSuperVaultPPS(strategyAddr, vaultAddr);

        // Test passes if no revert occurs
        assertGt(updatedPPS, 0, "PPS should be greater than 0");
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _createValidProofs(
        address strategy,
        uint256 pps,
        uint256 ppsStdev,
        uint256 validatorSet,
        uint256 totalValidators,
        uint256 timestamp,
        uint256[] memory specificSignerKeys
    )
        internal
        view
        returns (bytes[] memory)
    {
        // Create message hash with all parameters
        bytes32 messageHash =
            keccak256(abi.encodePacked(strategy, pps, ppsStdev, validatorSet, totalValidators, timestamp));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // If specific signer keys are provided, use them; otherwise, use default validators
        uint256[] memory signerKeys;
        if (specificSignerKeys.length > 0) {
            signerKeys = specificSignerKeys;
        } else {
            // Use as many validators as needed based on validatorSet
            signerKeys = new uint256[](validatorSet);

            // Assign default validator keys based on the validatorSet count
            for (uint256 i = 0; i < validatorSet; i++) {
                if (i == 0) signerKeys[i] = validator1PrivateKey;
                else if (i == 1) signerKeys[i] = validator2PrivateKey;
                else if (i == 2) signerKeys[i] = validator3PrivateKey;
            }
        }

        // Create proofs array
        bytes[] memory proofs = new bytes[](signerKeys.length);
        for (uint256 i = 0; i < signerKeys.length; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKeys[i], ethSignedMessageHash);
            proofs[i] = abi.encodePacked(r, s, v);
        }

        return proofs;
    }
}
