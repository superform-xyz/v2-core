// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockLedger {
    uint256 public feeAmount;

    function updateAccounting(address, address, bytes32, bool, uint256, uint256) external view returns (uint256) {
        return feeAmount;
    }

    function setFeeAmount(uint256 _feeAmount) external {
        feeAmount = _feeAmount;
    }
}

contract MockLedgerConfiguration {
    address public ledger;
    address public feeRecipient;
    address public yieldSourceOracle;
    uint256 public feePercent;
    address public manager;

    constructor(
        address _ledger,
        address _feeRecipient,
        address _yieldSourceOracle,
        uint256 _feePercent,
        address _manager
    ) {
        ledger = _ledger;
        feeRecipient = _feeRecipient;
        yieldSourceOracle = _yieldSourceOracle;
        feePercent = _feePercent;
        manager = _manager;
    }

    function getYieldSourceOracleConfig(bytes32) external view returns (YieldSourceOracleConfig memory) {
        return YieldSourceOracleConfig({
            yieldSourceOracle: yieldSourceOracle,
            feePercent: feePercent,
            feeRecipient: feeRecipient,
            manager: manager,
            ledger: ledger
        });
    }

    struct YieldSourceOracleConfig {
        address yieldSourceOracle;
        uint256 feePercent;
        address feeRecipient;
        address manager;
        address ledger;
    }
}
