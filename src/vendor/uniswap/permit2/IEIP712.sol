// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
