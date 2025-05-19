const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");
const path = require("path");

// Load our JSON data files
const tokenList = require('../target/token_list.json');
const yieldSourcesList = require('../target/yield_sources_list.json');
const ownerList = require('../target/owner_list.json');

/**
 * @notice Parse command line arguments for hook addresses
 * Format: address1,address2,address3
 * Order: ApproveAndRedeem4626VaultHook,ApproveAndDeposit4626VaultHook,Redeem4626VaultHook
 */
let customAddresses = {};

// Default hook addresses from deployment
const hookAddresses = {
  'ApproveAndRedeem4626VaultHook': '0x66e1Ed81804cd6c574f18cA88123B3284868D845',
  'ApproveAndDeposit4626VaultHook': '0x95C5A10d9C6d27985b7bad85635060C0AEcBf356',
  'Redeem4626VaultHook': '0x7692d9e0d10799199c8285E4c99E1fBC5C64fBf3'
};

// Check if addresses were provided as a command line argument
if (process.argv.length > 2) {
  const addressArg = process.argv[2];
  const addresses = addressArg.split(',');
  
  // If we have the correct number of addresses, use them
  if (addresses.length >= 3) {
    console.log("Using provided hook addresses from command line:");
    customAddresses = {
      'ApproveAndRedeem4626VaultHook': addresses[0],
      'ApproveAndDeposit4626VaultHook': addresses[1],
      'Redeem4626VaultHook': addresses[2]
    };
    
    // Log the addresses being used
    console.log("ApproveAndRedeem4626VaultHook:", customAddresses['ApproveAndRedeem4626VaultHook']);
    console.log("ApproveAndDeposit4626VaultHook:", customAddresses['ApproveAndDeposit4626VaultHook']);
    console.log("Redeem4626VaultHook:", customAddresses['Redeem4626VaultHook']);
    
    // Override the default addresses
    Object.assign(hookAddresses, customAddresses);
  } else {
    console.log("Invalid number of addresses provided. Expected format: address1,address2,address3");
    console.log("Using default hook addresses.");
  }
}

const hookDefinitions = {
  ApproveAndRedeem4626VaultHook: {
    // Contract address of the deployed hook
    address: hookAddresses['ApproveAndRedeem4626VaultHook'],
    // Map argument names to their semantic types for proper list lookups
    argsInfo: {
      extractedAddresses: [
        { name: 'yieldSource', type: 'yieldSource' },
        { name: 'token', type: 'token' },
        { name: 'owner', type: 'beneficiary' }
      ]
    }
  },
  ApproveAndDeposit4626VaultHook: {
    // Contract address of the deployed hook
    address: hookAddresses['ApproveAndDeposit4626VaultHook'],
    // Map argument names to their semantic types for proper list lookups
    argsInfo: {
      extractedAddresses: [
        { name: 'yieldSource', type: 'yieldSource' },
        { name: 'token', type: 'token' }
      ]
    }
  },
  Redeem4626VaultHook: {
    // Contract address of the deployed hook
    address: hookAddresses['Redeem4626VaultHook'],
    // Map argument names to their semantic types for proper list lookups
    argsInfo: {
      extractedAddresses: [
        { name: 'yieldSource', type: 'yieldSource' },
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
 * Generate all possible argument combinations for a hook using a dynamic approach
 * @param {Object} hookDef - Hook definition
 * @param {number} chainId - Chain ID to use for addresses
 * @returns {Array<Object>} Array of argument objects
 */
function generateArgCombinations(hookDef, chainId) {
  // Get the argument definitions from the hook
  const argDefs = hookDef.argsInfo.extractedAddresses;

  // Create a map of argument names to their possible values
  const argValues = {};
  for (const argDef of argDefs) {
    argValues[argDef.name] = getAddressesForType(argDef.type, chainId);
  }

  // Helper function to generate combinations recursively
  function generateCombinationsRecursive(argNames, currentIndex, currentCombination) {
    // Base case: we've processed all argument names
    if (currentIndex === argNames.length) {
      return [currentCombination];
    }

    // Get the current argument name
    const argName = argNames[currentIndex];

    // Get the possible values for this argument
    const possibleValues = argValues[argName] || [];

    // If there are no possible values, skip this argument
    if (possibleValues.length === 0) {
      return generateCombinationsRecursive(argNames, currentIndex + 1, currentCombination);
    }

    // Generate combinations for each possible value
    let combinations = [];
    for (const value of possibleValues) {
      // Create a new combination with this value
      const newCombination = { ...currentCombination, [argName]: value };

      // Recursively generate combinations for the remaining arguments
      const remainingCombinations = generateCombinationsRecursive(
        argNames,
        currentIndex + 1,
        newCombination
      );

      // Add these combinations to our result
      combinations = combinations.concat(remainingCombinations);
    }

    return combinations;
  }

  // Get all argument names from the argDefs
  const argNames = argDefs.map(def => def.name);

  // Generate combinations for all arguments
  return generateCombinationsRecursive(argNames, 0, {});
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
  // Get hook definition
  const hookDef = hookDefinitions[hookName];
  if (!hookDef) {
    console.warn(`No hook definition found for ${hookName}`);
    return '';
  }

  // Get argument definitions in the correct order
  const argDefs = hookDef.argsInfo.extractedAddresses;

  // Build the types and values arrays for solidityPack
  const types = [];
  const values = [];

  for (const argDef of argDefs) {
    const argName = argDef.name;
    if (args[argName] !== undefined) {
      types.push('address'); // All our args are addresses
      values.push(args[argName]);
    }
  }

  // If we have no arguments, return empty string
  if (types.length === 0) {
    return '';
  }

  // Use solidityPack to match abi.encodePacked in Solidity
  return ethers.utils.solidityPack(types, values);
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

    // Add count element to the tree dump for easier access in Solidity
    globalTreeDump.count = allLeaves.length;

    // Enhance global tree dump with proofs for each leaf
    for (const [i, v] of globalTree.entries()) {
      const currentHookName = allLeafData[i].hookName;

      // Verify the hook definition exists
      if (!hookDefinitions[currentHookName]) {
        throw new Error(`Hook definition not found for ${currentHookName}. Please add it to the hookDefinitions object.`);
      }

      // Verify the hook address exists
      const hookAddress = hookDefinitions[currentHookName].address;
      if (!hookAddress) {
        throw new Error(`Hook address not found for ${currentHookName}. Please add it to the hookAddresses object.`);
      }

      // Only include essential information: value, treeIndex, hookName, address, and proof
      globalTreeDump.values[i] = {
        value: globalTreeDump.values[i].value,
        treeIndex: globalTreeDump.values[i].treeIndex,
        hookName: currentHookName,
        hookAddress: hookAddress, // Add hook contract address for validation
        encodedHookArgs: allLeafData[i].encodedArgs, // Add this for easy reference
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