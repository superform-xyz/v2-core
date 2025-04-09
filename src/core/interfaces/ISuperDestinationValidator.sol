// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperDestinationValidator {
    function isValidDestinationSignature(address sender, bytes calldata data) external view returns (bytes4);
}

