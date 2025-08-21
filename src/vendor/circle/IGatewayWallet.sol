// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Circle Gateway
interface IGatewayWallet {
    function deposit(address token, uint256 value) external;
    function addDelegate(address token, address delegate) external;
    function removeDelegate(address token, address delegate) external;
}
