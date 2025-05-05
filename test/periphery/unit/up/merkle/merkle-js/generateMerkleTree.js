const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");


/// read all the files in target folder
let files = fs.readdirSync('test/merkle/target/');
let filteredFiles = files.filter(file => file.startsWith("input"))
let constructedData = [];

for (let i = 0; i < filteredFiles.length; ++i) {
  const jsonTreeData = require(`../target/${filteredFiles[i]}`);
  console.log(`Processing file: ${filteredFiles[i]}`);
  for (let j = 0; j < jsonTreeData.count; ++j) {
    constructedData.push(
      [jsonTreeData.values[j][0].toString(), jsonTreeData.values[j][1].toString()]
    )
  }

  /// step 2: construct the merkle tree
  const tree = StandardMerkleTree.of(constructedData, ["address", "uint256"]);

  /// step 3: construct the root
  const root = tree.root;
  const treeDump = tree.dump();

  /// step 4: construct the root for each index
  for (const [i, v] of tree.entries()) {
    const proof = tree.getProof(i);
    treeDump.values[i].claimer = treeDump.values[i].value[0];
    treeDump.values[i].amount = parseInt(treeDump.values[i].value[1]);
    treeDump.values[i].proof = proof;

  }

  /// step 4: write the tree and root for further use
  fs.writeFileSync(`test/merkle/target/jsGeneratedRoot${i}.json`, JSON.stringify({ "root": root }));
  fs.writeFileSync(`test/merkle/target/jsTreeDump${i}.json`, JSON.stringify(treeDump));
  constructedData = [];
  console.log(' Processed ')
}