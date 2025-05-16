const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");
const path = require("path");

// Load our JSON data files
const tokenList = require('../target/token_list.json');
const yieldSourcesList = require('../target/yield_sources_list.json');
const ownerList = require('../target/owner_list.json');

/**
 * @notice Hook definitions with metadata about their arguments and how they should be encoded
 * Each hook definition contains:
 * - argsInfo: which addresses are used as arguments and their semantic types
 */
const hookDefinitions = {
  ApproveAndRedeem4626VaultHook: {
    // Map argument names to their semantic types for proper list lookups
    argsInfo: {
      extractedAddresses: [
        { name: 'yieldSource', type: 'yieldSource' },
        { name: 'token', type: 'token' },
        { name: 'owner', type: 'beneficiary' }
      ]
    }
  }
};

/**
 * Get addresses for a specific semantic type and chainId
 * @param {string} type - Semantic type ('token', 'yieldSource', or 'beneficiary')
 * @param {number} chainId - Chain ID to get addresses for
 * @returns {Array<string>} Array of addresses
 */
function getAddressesForType(type, chainId) {
  switch (type) {
    case 'token':
      return (tokenList[chainId] || []).map(item => item.address);
    case 'yieldSource':
      return (yieldSourcesList[chainId] || []).map(item => item.address);
    case 'beneficiary':
      return ownerList;
    default:
      return [];
  }
}

/**
 * Generate all possible argument combinations for a hook
 * @param {Object} hookDef - Hook definition
 * @param {number} chainId - Chain ID to use for addresses
 * @returns {Array<Object>} Array of argument objects
 */
function generateArgCombinations(hookDef, chainId) {
  // Get lists of possible addresses for each argument type
  const argAddresses = {};
  
  // Map each extracted address to its list of possible values
  for (const argDef of hookDef.argsInfo.extractedAddresses) {
    argAddresses[argDef.name] = getAddressesForType(argDef.type, chainId);
  }
  
  // Generate all combinations (cartesian product)
  const argCombinations = [];
  
  // For the ApproveAndRedeem4626VaultHook:
  // We need combinations of yieldSource, token, and owner
  for (const yieldSource of argAddresses['yieldSource'] || []) {
    for (const token of argAddresses['token'] || []) {
      for (const owner of argAddresses['owner'] || []) {
        const argObj = { 
          yieldSource,
          token,
          owner 
        };
        argCombinations.push(argObj);
      }
    }
  }
  
  return argCombinations;
}

// Add ethers import at the top
const { ethers } = require('ethers');

/**
 * Encode args according to the hook's encoding scheme
 * @param {Object} args - Object containing argument addresses
 * @param {string} hookName - Name of the hook
 * @returns {string} Hex string of encoded args (packed, not ABI encoded)
 */
function encodeArgs(args, hookName) {
  if (hookName === 'ApproveAndRedeem4626VaultHook') {
    // Based on the hook's inspect() function:
    // argsEncoded = abi.encodePacked(yieldSource, token, owner)
    // We need to use solidityPack to match abi.encodePacked in Solidity
    return ethers.utils.solidityPack(
      ['address', 'address', 'address'], 
      [args.yieldSource, args.token, args.owner]
    );
  }
  
  // Default implementation for other hooks
  return '';
}

/**
 * Build Merkle tree for a specific hook
 * @param {string} hookName - Name of the hook
 * @param {number} chainId - Chain ID to use for addresses
 * @returns {Object} StandardMerkleTree and leaf data
 */
function buildMerkleTreeForHook(hookName, chainId) {
  const hookDef = hookDefinitions[hookName];
  if (!hookDef) throw new Error(`Unknown hook: ${hookName}`);
  
  const argCombinations = generateArgCombinations(hookDef, chainId);
  
  // Build leaves in the format expected by StandardMerkleTree.of()
  const leaves = [];
  const leafData = [];
  
  for (const args of argCombinations) {
    // Encode args according to the hook's specific encoding
    const encodedArgs = encodeArgs(args, hookName);
    
    // Store leaf data for later reference
    leafData.push({
      hookName,
      args,
      encodedArgs
    });
    
    // For StandardMerkleTree, we need to use a specific format
    // Each leaf is an array with a single value (the packed encoding)
    leaves.push([encodedArgs]);
  }
  
  // Create the merkle tree with StandardMerkleTree
  const tree = StandardMerkleTree.of(
    leaves, 
    ["bytes"] // Using bytes type for the solidityPack output
  );
  
  return { tree, leafData };
}

/**
 * Generate Merkle trees for hooks
 * @param {Array<string>} hookNames - Array of hook names to generate trees for
 * @param {number} chainId - Chain ID to use for addresses
 */
function generateMerkleTrees(hookNames, chainId) {
  console.log(`Generating global Merkle tree for chain ID ${chainId}...`);
  
  // Generate leaves for each hook but only for the global tree
  let allLeaves = [];
  let allLeafData = [];
  
  for (const hookName of hookNames) {
    const { tree, leafData } = buildMerkleTreeForHook(hookName, chainId);
    console.log(`Generated ${leafData.length} leaves for ${hookName}`);
    
    // Add to global leaves
    for (let i = 0; i < leafData.length; i++) {
      // Each leaf must be in array format for StandardMerkleTree
      allLeaves.push([leafData[i].encodedArgs]);
      allLeafData.push(leafData[i]);
    }
  }
  
  // Generate global Merkle tree with all leaves
  if (allLeaves.length > 0) {
    const globalTree = StandardMerkleTree.of(
      allLeaves, 
      ["bytes"] // Using bytes type for the solidityPack output
    );
    
    const globalTreeDump = globalTree.dump();
    
    // Enhance global tree dump with proofs for each leaf
    for (const [i, v] of globalTree.entries()) {
      // Only include essential information: value, treeIndex, hookName, and proof
      globalTreeDump.values[i] = {
        value: globalTreeDump.values[i].value,
        treeIndex: globalTreeDump.values[i].treeIndex,
        hookName: allLeafData[i].hookName,
        proof: globalTree.getProof(i)
      };
    }
    
    // Create output directory if it doesn't exist
    const outputDir = path.join(__dirname, '../output');
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    // Save root and tree dump separately (like in generateMerkleTree.js)
    const root = globalTree.root;
    
    fs.writeFileSync(
      path.join(outputDir, `jsGeneratedRoot_${chainId}.json`), 
      JSON.stringify({ "root": root })
    );
    
    fs.writeFileSync(
      path.join(outputDir, `jsTreeDump_${chainId}.json`), 
      JSON.stringify(globalTreeDump)
    );
    
    console.log(`Saved global Merkle tree with root: ${root}`);
    console.log(`Total leaves in global tree: ${allLeaves.length}`);
  }
}

// Main execution
const hookNames = Object.keys(hookDefinitions);
const chainId = 1; // Ethereum mainnet as specified in the requirements

generateMerkleTrees(hookNames, chainId);

module.exports = {
  buildMerkleTreeForHook,
  generateMerkleTrees,
  hookDefinitions
};