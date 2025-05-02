// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import "forge-std/Test.sol";
import "../../mocks/GasBenchmarking.sol";

contract GasBenchmarkingTest is Test {
    GasBenchmarker public benchmarker;
    ValidatorSimulation public validator;

    function setUp() public {
        validator = new ValidatorSimulation();
        benchmarker = new GasBenchmarker(address(validator));
    }

    function testGasHandleUserOpStore() public {
        // Create test data with signature at the end
        bytes memory signature = hex"deadbeef00000000000000000000000000000000000000000000000000000000"; // 32 bytes signature
        bytes memory userOpCalldata = bytes.concat(
            bytes("Some test data"), // base data
            signature
        );

        uint256 gasBefore = gasleft();
        benchmarker.handleUserOpStore(userOpCalldata);
        uint256 gasAfter = gasleft();
        
        console.log("Gas used by handleUserOpStore:", gasBefore - gasAfter);
    }

    function testGasHandleUserOpReplace() public {
        // Base data that will be partially replaced
        bytes memory baseData = "Hello World! Testing Replace Operation!";
        
        // Create test data for replace operation
        GasBenchmarker.Info[] memory infoArray = new GasBenchmarker.Info[](2);
        
        // First replacement info
        infoArray[0] = GasBenchmarker.Info({
            hookIndex: 0,
            startBytes: 5,
            endBytes: 10
        });

        // Second replacement info
        infoArray[1] = GasBenchmarker.Info({
            hookIndex: 1,
            startBytes: 15,
            endBytes: 20
        });

        // 8 bytes signature - must be long enough to cover all replacements
        bytes memory signature = hex"1234567890abcdef1234567890abcdef";

        // Construct the full userOpCalldata
        bytes memory userOpCalldata = bytes.concat(
            baseData,                                    // Base data
            abi.encode(infoArray),                      // Info array
            signature,                                   // Signature data
            abi.encode(uint256(infoArray.length)),      // Info length (32 bytes)
            bytes1(uint8(signature.length))             // Signature length (1 byte)
        );

        uint256 gasBefore = gasleft();
        benchmarker.handleUserOpReplace(userOpCalldata);
        uint256 gasAfter = gasleft();
        
        console.log("Gas used by handleUserOpReplace:", gasBefore - gasAfter);
    }
}
