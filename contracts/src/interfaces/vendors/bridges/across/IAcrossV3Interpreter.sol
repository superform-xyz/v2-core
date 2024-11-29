// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IAcrossV3Interpreter {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct Call {
        address target;
        bytes callData;
        uint256 value;
    }

    struct EntryPointData {
        address account;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
        address payable beneficiary;
    }

    struct Instructions {
        Call[] calls;
        EntryPointData entryPointData;
    }
}
