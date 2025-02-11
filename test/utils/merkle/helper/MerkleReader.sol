// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import "forge-std/StdJson.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { BaseTest } from "../../../BaseTest.t.sol";

abstract contract MerkleReader is StdCheats, BaseTest {
    using stdJson for string;

    string private basePathForRoot = "/test/utils/merkle/target/jsGeneratedRoot";
    string private basePathForTreeDump = "/test/utils/merkle/target/jsTreeDump";

    string private prepend = ".values[";

    string private hooksAddressQueryAppend = "].hookAddress";

    string private proofQueryAppend = "].proof";

    struct LocalVars {
        string rootJson;
        bytes encodedRoot;
        string treeJson;
        bytes encodedHookAddress;
        bytes encodedProof;
    }

    function _getMerkleRoot() internal view returns (bytes32 root) {
        LocalVars memory v;

        v.rootJson = vm.readFile(string.concat(vm.projectRoot(), basePathForRoot, Strings.toString(0), ".json"));
        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));
    }

    /// @dev read the merkle root and proof from js generated tree
    function _generateMerkleTree()
        internal
        view
        returns (bytes32 root, bytes32[][] memory proofsForHooks, address[] memory hooksAddresses)
    {
        LocalVars memory v;

        v.rootJson = vm.readFile(string.concat(vm.projectRoot(), basePathForRoot, Strings.toString(0), ".json"));
        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, Strings.toString(0), ".json"));

        bytes memory encodedValuesJson = vm.parseJson(v.treeJson, ".values[*]");
        string[] memory valuesArr = abi.decode(encodedValuesJson, (string[]));
        proofsForHooks = new bytes32[][](valuesArr.length);
        hooksAddresses = new address[](valuesArr.length);
        for (uint256 i; i < valuesArr.length; ++i) {
            v.encodedHookAddress =
                vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), hooksAddressQueryAppend));
            v.encodedProof = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));

            hooksAddresses[i] = abi.decode(v.encodedHookAddress, (address));
            proofsForHooks[i] = abi.decode(v.encodedProof, (bytes32[]));
        }
    }
}
