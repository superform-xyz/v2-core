// test/ReplaceBenchmarkTest.t.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import "forge-std/Test.sol";
import "../../mocks/ReplaceBenchmark.sol";

contract ReplaceBenchmarkTest is Test {
    ReplaceBenchmark bench;

    function setUp() public {
        bench = new ReplaceBenchmark();
    }

    function testGasComparison() public view {
        // Build a 500‐byte payload with a 65‐byte “signature” in the middle
        bytes memory prefix = new bytes(200);
        bytes memory sig = new bytes(65);
        bytes memory suffix = new bytes(235);

        // Fill with nonzero data so optimizer can't elide
        for (uint256 i; i < prefix.length; i++) {
            prefix[i] = bytes1(uint8(i));
        }
        for (uint256 i; i < sig.length; i++) {
            sig[i] = bytes1(uint8(200 + i));
        }
        for (uint256 i; i < suffix.length; i++) {
            suffix[i] = bytes1(uint8(265 + i));
        }

        bytes memory payload = abi.encodePacked(prefix, sig, suffix);

        uint256 start = prefix.length;
        uint256 length = sig.length;

        // Gas for naive
        uint256 gasBeforeNaive = gasleft();
        bench.naiveReplace(payload, start, length, sig);
        uint256 gasAfterNaive = gasleft();
        console.log("naiveReplace gas:", gasBeforeNaive - gasAfterNaive);

        // Gas for optimized
        uint256 gasBeforeOpt = gasleft();
        bench.optimizedReplace(payload, start, length, sig);
        uint256 gasAfterOpt = gasleft();
        console.log("optimizedReplace gas:", gasBeforeOpt - gasAfterOpt);
    }
}
