// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import "forge-std/StdJson.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

import "forge-std/console.sol";

abstract contract MerkleReader is StdCheats, Test {
    using stdJson for string;

    string private basePathForRoot = "/test/periphery/unit/up/merkle/target/jsGeneratedRoot0";
    string private basePathForTreeDump = "/test/periphery/unit/up/merkle/target/jsTreeDump0";

    string private prepend = ".values[";

    string private claimerQueryAppend = "].claimer";

    string private amountQueryAppend = "].amount";

    string private proofQueryAppend = "].proof";

    struct LocalVars {
        string rootJson;
        bytes encodedRoot;
        string treeJson;
        bytes encodedClaimer;
        bytes encodedAmount;
        bytes encodedProof;
        address claimer;
        uint256 amountClaimed;
    }

    struct MerkleArgs {
        address claimer_;
    }

    /// @dev read the merkle root and proof from js generated tree
    function _generateMerkleTree(MerkleArgs memory a)
        internal
        view
        returns (bytes32 root, bytes32[] memory proofsForIndex)
    {
        LocalVars memory v;

        v.rootJson = vm.readFile(string.concat(vm.projectRoot(), basePathForRoot, ".json"));
        v.encodedRoot = vm.parseJson(v.rootJson, ".root");
        root = abi.decode(v.encodedRoot, (bytes32));

        v.treeJson = vm.readFile(string.concat(vm.projectRoot(), basePathForTreeDump, ".json"));

        for (uint256 i; i < 2; ++i) {
            v.encodedClaimer = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), claimerQueryAppend));
            v.encodedAmount = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), amountQueryAppend));

            v.claimer = abi.decode(v.encodedClaimer, (address));
            v.amountClaimed = abi.decode(v.encodedAmount, (uint256));

            if (a.claimer_ != address(0) && v.claimer == a.claimer_) {
                v.encodedProof = vm.parseJson(v.treeJson, string.concat(prepend, Strings.toString(i), proofQueryAppend));
                proofsForIndex = abi.decode(v.encodedProof, (bytes32[]));

                break;
            }
        }
    }
}
