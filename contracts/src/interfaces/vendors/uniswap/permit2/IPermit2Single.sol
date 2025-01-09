// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IAllowanceTransfer } from "./IAllowanceTransfer.sol";

interface IPermit2Single {
    function permit(address owner, IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) external;
    function transferFrom(address from, address to, uint160 amount, address token) external;
}
