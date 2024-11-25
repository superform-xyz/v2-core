// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

contract ComposabilityStorageMock {
    uint256 public amount;
    uint256 public obtained;

    function setAmount(uint256 _amount) external {
        amount = _amount;
    }

    function setObtained(uint256 _currentAmount) external {
        // deposit / withdraw
        obtained = _currentAmount > amount ? _currentAmount - amount : amount - _currentAmount;
    }
}
