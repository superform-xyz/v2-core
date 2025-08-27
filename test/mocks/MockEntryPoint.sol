// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IStakeManager } from "@ERC4337/account-abstraction/contracts/interfaces/IStakeManager.sol";
import { UserOperationLib } from "../../src/vendor/account-abstraction/UserOperationLib.sol";
import { IEntryPointSimulations } from "modulekit/external/ERC4337.sol";

import "forge-std/console2.sol";

contract MockEntryPoint {
    using UserOperationLib for PackedUserOperation;

    uint256 public depositAmount;
    address public withdrawAddress;
    uint256 public withdrawAmount;

    struct DepositInfo {
        uint112 deposit;
        bool staked;
        uint112 stake;
        uint32 unstakeDelaySec;
        uint48 withdrawTime;
    }

    // Define the missing structs
    struct ExecutionResult {
        uint256 preOpGas;
        uint256 paid;
        uint256 validAfter;
        uint256 validUntil;
        bool targetSuccess;
        bytes targetResult;
    }

    mapping(address => DepositInfo) public deposits;
    mapping(bytes32 => bool) public userOpHashes;

    uint256 private constant PAYMASTER_VALIDATION_GAS = 100_000;
    uint256 private constant SIG_VALIDATION_GAS = 50_000;

    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );
    event Deposited(address indexed account, uint256 totalDeposit);
    event StakeLocked(address indexed account, uint256 totalStaked, uint256 unstakeDelaySec);
    event StakeUnlocked(address indexed account, uint256 withdrawTime);
    event StakeWithdrawn(address indexed account, address withdrawAddress, uint256 amount);
    event AccountDeployed(bytes32 indexed userOpHash, address indexed sender, address factory, address paymaster);

    // Variables for tracking simulation calls
    bytes32 public lastOpHash;
    address public lastSimulationTarget;
    bytes public lastSimulationCallData;
    IEntryPointSimulations.ExecutionResult private simulationResult;
    bool public validationReturnValue;

    fallback() external payable virtual {
        depositAmount += msg.value;
        deposits[msg.sender].deposit += uint112(msg.value);
    }

    receive() external payable virtual {
        depositAmount += msg.value;
        deposits[msg.sender].deposit += uint112(msg.value);
    }

    function setValidationReturnValue(bool val) external {
        validationReturnValue = val;
    }

    function supportsInterface(bytes4) public pure returns (bool) {
        return true;
    }

    function depositTo(address account) external payable {
        deposits[account].deposit += uint112(msg.value);
    }

    function withdrawTo(address payable withdrawAddress_, uint256 amount) external {
        DepositInfo storage info = deposits[msg.sender];
        require(info.deposit >= amount, "Insufficient deposit");

        withdrawAddress = withdrawAddress_;
        withdrawAmount = amount;
        info.deposit -= uint112(amount);

        (bool success,) = withdrawAddress_.call{ value: amount }("");
        require(success, "Failed to withdraw");
    }

    function getDepositInfo(address account) external view returns (DepositInfo memory) {
        return deposits[account];
    }

    function handleOps(PackedUserOperation[] calldata ops, address payable beneficiary) external {
        uint256 opsLen = ops.length;
        console2.log("---------------C", opsLen);
        for (uint256 i = 0; i < opsLen; i++) {
            PackedUserOperation calldata op = ops[i];
            bytes32 userOpHash = getUserOpHash(op);
            userOpHashes[userOpHash] = true;

            // Get the paymaster address from the first 20 bytes of paymasterAndData
            address paymaster = address(bytes20(op.paymasterAndData));

            // Calculate requiredPreFund similar to EntryPoint
            uint256 requiredPreFund = _getRequiredPrefund(op);
            console2.log("---------------A", requiredPreFund);

            // Try to decrement deposit and revert if insufficient
            DepositInfo storage paymasterInfo = deposits[paymaster];
            console2.log("---------------B", paymasterInfo.deposit);
            if (paymasterInfo.deposit < requiredPreFund) {
                revert(string(abi.encodePacked("AA31 paymaster deposit too low")));
            }

            // Decrement the deposit
            paymasterInfo.deposit -= uint112(requiredPreFund);

            // Emit event
            emit UserOperationEvent(userOpHash, op.sender, uint256(op.nonce), true, 0, 0);
        }

        // Pay the beneficiary
        if (beneficiary != address(0)) {
            (bool success,) = beneficiary.call{ value: 0.01 ether }("");
            require(success, "Failed to pay beneficiary");
        }
    }

    function simulateHandleOp(
        PackedUserOperation calldata op,
        address target,
        bytes calldata callData
    )
        external
        payable
        returns (IEntryPointSimulations.ExecutionResult memory result)
    {
        // Track the call parameters
        lastOpHash = op.hash();
        lastSimulationTarget = target;
        lastSimulationCallData = callData;

        // Return the predefined simulation result
        return simulationResult;
    }

    function setSimulationResult(IEntryPointSimulations.ExecutionResult memory result) external {
        simulationResult = result;
    }

    function simulateValidation(PackedUserOperation calldata userOp)
        external
        pure
        returns (IEntryPointSimulations.ValidationResult memory)
    {
        uint256 preOpGas = PAYMASTER_VALIDATION_GAS + SIG_VALIDATION_GAS;
        uint256 prefund = _getRequiredPrefund(userOp);

        return IEntryPointSimulations.ValidationResult({
            returnInfo: IEntryPoint.ReturnInfo({
                preOpGas: preOpGas,
                prefund: prefund,
                accountValidationData: uint256(1),
                paymasterValidationData: uint256(1),
                paymasterContext: ""
            }),
            senderInfo: IStakeManager.StakeInfo({ stake: 0, unstakeDelaySec: 0 }),
            factoryInfo: IStakeManager.StakeInfo({ stake: 0, unstakeDelaySec: 0 }),
            paymasterInfo: IStakeManager.StakeInfo({ stake: 2e6, unstakeDelaySec: 0 }),
            aggregatorInfo: IEntryPoint.AggregatorStakeInfo({
                aggregator: address(0),
                stakeInfo: IStakeManager.StakeInfo({ stake: 2e6, unstakeDelaySec: 0 })
            })
        });
    }

    function _getRequiredPrefund(PackedUserOperation calldata userOp) internal pure returns (uint256) {
        uint256 maxGasPrice = userOp.unpackMaxFeePerGas();
        uint256 gasLimit = 2e6 + 2e6 + 2e6;
        return gasLimit * maxGasPrice;
    }

    function getUserOpHash(PackedUserOperation calldata userOp) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                2e6,
                2e6,
                2e6,
                2e6,
                2e6,
                keccak256(userOp.paymasterAndData)
            )
        );
    }

    function addStake(uint32 unstakeDelaySec) external payable {
        require(unstakeDelaySec > 0, "Must specify unstake delay");
        deposits[msg.sender].stake += uint112(msg.value);
        deposits[msg.sender].unstakeDelaySec = unstakeDelaySec;
        deposits[msg.sender].staked = true;
        emit StakeLocked(msg.sender, deposits[msg.sender].stake, unstakeDelaySec);
    }

    function unlockStake() external {
        DepositInfo storage info = deposits[msg.sender];
        require(info.staked, "Not staked");
        info.withdrawTime = uint48(block.timestamp) + uint48(info.unstakeDelaySec);
        info.staked = false;
        emit StakeUnlocked(msg.sender, info.withdrawTime);
    }

    function withdrawStake(address payable withdrawAddress_) external {
        DepositInfo storage info = deposits[msg.sender];
        require(!info.staked, "Still staked");
        require(info.withdrawTime <= block.timestamp, "Stake withdrawal not due");
        uint256 amount = info.stake;
        info.stake = 0;
        emit StakeWithdrawn(msg.sender, withdrawAddress_, amount);
        (bool success,) = withdrawAddress_.call{ value: amount }("");
        require(success, "Failed to withdraw stake");
    }

    // Required interface implementations
    function getSenderAddress(bytes calldata initCode) external { }

    // Stub implementations for interface compatibility
    function handleAggregatedOps(
        PackedUserOperation[][] calldata opsPerAggregator,
        address payable beneficiary
    )
        external
    {
        // Not implemented
    }

    function innerHandleOp(
        bytes calldata,
        PackedUserOperation calldata,
        bytes calldata
    )
        external
        pure
        returns (uint256)
    {
        return 0;
    }

    function setDeposit(address account, uint256 amount) external {
        deposits[account].deposit = uint112(amount);
    }
}

contract MockEntryPointRejectETH is MockEntryPoint {
    // Override the receive function to reject ETH
    receive() external payable override {
        // Always revert to simulate ETH transfer failure
        revert("ETH transfer rejected");
    }

    // Override the fallback function as well to ensure all transfers fail
    fallback() external payable override {
        revert("ETH transfer rejected");
    }
}
