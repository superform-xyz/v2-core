// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleStorage {
    uint256 public storedData;

    event DataStored(uint256 data, address sender);
    event DataAdded(uint256 data, address sender);

    function set(uint256 x) public {
        storedData = x;
        emit DataStored(x, msg.sender);
    }

    function add(uint256 x) public {
        storedData = storedData + x;
        emit DataAdded(x, msg.sender);
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}
