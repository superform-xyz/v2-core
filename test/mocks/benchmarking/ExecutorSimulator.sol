// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { GasBenchmarkingSignatureStorage } from "./GasBenchmarkingSignatureStorage.sol";
import { GasBenchmarkingSignatureReplace } from "./GasBenchmarkingSignatureReplace.sol";

contract ExecutorSimulator {
    event EmitTheData(address indexed account, bytes data);
    
    address public benchmarker;
    address public benchmarkerReplace;  
    constructor (address _benchmarker, address _benchmarkerReplace) {
        benchmarker = _benchmarker;
        benchmarkerReplace = _benchmarkerReplace;
    }
    
    function executeWithReplace(PackedUserOperation calldata userOp) external {
        GasBenchmarkingSignatureReplace(benchmarkerReplace).validateAndExecute(userOp, bytes32(0));
        emit EmitTheData(userOp.sender, userOp.signature);
    }


    function executeWithStorage(PackedUserOperation calldata userOp) external {
        GasBenchmarkingSignatureStorage(benchmarker).validateAndExecute(userOp, bytes32(0));
        bytes memory data = GasBenchmarkingSignatureStorage(benchmarker).loadSignature();
        emit EmitTheData(userOp.sender, data);
    }
}  