const fs = require('fs');
const path = require('path');

// Define paths to the JSON files relative to this script's location
const yieldSourcesPath = path.join(__dirname, '../target/yield_sources_list.json');
const tokenListPath = path.join(__dirname, '../target/token_list.json');

/**
 * Updates a JSON file by adding a new vault entry if it doesn't already exist.
 * @param {string} filePath - The absolute path to the JSON file.
 * @param {string} chainId - The chain ID under which to add the vault.
 * @param {string} vaultName - The name (symbol) of the vault.
 * @param {string} vaultAddress - The address of the vault.
 * @returns {{success: boolean, modified: boolean, message: string}} - Result object.
 */
function updateJsonFile(filePath, chainId, vaultName, vaultAddress) {
  let fileContent;
  try {
    fileContent = fs.readFileSync(filePath, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') {
      fileContent = '{}'; // File doesn't exist, create it with an empty object
    } else {
      const errorMessage = `Error reading file ${filePath}: ${error.message}`;
      return { success: false, modified: false, message: errorMessage };
    }
  }

  let data;
  try {
    data = JSON.parse(fileContent);
  } catch (error) {
    const errorMessage = `Error parsing JSON from ${filePath}: ${error.message}`;
    return { success: false, modified: false, message: errorMessage };
  }

  if (!data[chainId]) {
    data[chainId] = [];
  }

  const vaultAddressLower = vaultAddress.toLowerCase();
  const vaultExists = data[chainId].some(entry => entry.address.toLowerCase() === vaultAddressLower);

  if (!vaultExists) {
    data[chainId].push({ symbol: vaultName, address: vaultAddress });
    try {
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf8');
      const successMessage = `Successfully added ${vaultName} (${vaultAddress}) to ${path.basename(filePath)} for chain ID ${chainId}.`;
      return { success: true, modified: true, message: successMessage };
    } catch (error) {
      const errorMessage = `Error writing to file ${filePath}: ${error.message}`;
      return { success: false, modified: false, message: errorMessage };
    }
  } else {
    const infoMessage = `${vaultName} (${vaultAddress}) already exists in ${path.basename(filePath)} for chain ID ${chainId}. No changes made.`;
    return { success: true, modified: false, message: infoMessage };
  }
}

// Main script execution
function main() {
  const args = process.argv.slice(2);

  if (args.length < 3) {
    process.stderr.write('Error: Insufficient arguments. Usage: node update-lists.js <vaultName> <vaultAddress> <chainId> OR node update-lists.js <numVaults> <name1>... <addr1>... <chainId>\n');
    process.exit(1);
  }

  const firstArg = args[0];
  const isBatchMode = !isNaN(parseInt(firstArg));

  let overallSuccess = true;
  let anyFileModified = false;
  let errorMessages = [];

  if (isBatchMode) {
    const numVaults = parseInt(firstArg);
    if (args.length !== 1 + numVaults * 2 + 1) {
      process.stderr.write(`Error: Incorrect number of arguments for batch mode. Expected ${1 + numVaults * 2 + 1}, got ${args.length}.\n`);
      process.exit(1);
    }

    const vaultNames = args.slice(1, 1 + numVaults);
    const vaultAddresses = args.slice(1 + numVaults, 1 + numVaults * 2);
    const chainId = args[1 + numVaults * 2];

    for (let i = 0; i < numVaults; i++) {
      const vaultName = vaultNames[i];
      const vaultAddress = vaultAddresses[i];

      const yieldResult = updateJsonFile(yieldSourcesPath, chainId, vaultName, vaultAddress);
      if (!yieldResult.success) {
        overallSuccess = false;
        errorMessages.push(`YieldSources (${vaultName}): ${yieldResult.message}`);
      } else if (yieldResult.modified) {
        anyFileModified = true;
      }

      const tokenResult = updateJsonFile(tokenListPath, chainId, vaultName, vaultAddress);
      if (!tokenResult.success) {
        overallSuccess = false;
        errorMessages.push(`TokenList (${vaultName}): ${tokenResult.message}`);
      } else if (tokenResult.modified) {
        anyFileModified = true;
      }
    }
  } else {
    const [vaultName, vaultAddress, chainId] = args;
    if (!vaultName || !vaultAddress || !chainId) {
      process.stderr.write('Error: vaultName, vaultAddress, and chainId are required for single vault mode.\n');
      process.exit(1);
    }

    const yieldResult = updateJsonFile(yieldSourcesPath, chainId, vaultName, vaultAddress);
    if (!yieldResult.success) {
      overallSuccess = false;
      errorMessages.push(`YieldSources: ${yieldResult.message}`);
    } else if (yieldResult.modified) {
      anyFileModified = true;
    }

    const tokenResult = updateJsonFile(tokenListPath, chainId, vaultName, vaultAddress);
    if (!tokenResult.success) {
      overallSuccess = false;
      errorMessages.push(`TokenList: ${tokenResult.message}`);
    } else if (tokenResult.modified) {
      anyFileModified = true;
    }
  }

  if (overallSuccess && anyFileModified) {
    process.stdout.write('true\n');
  } else {
    process.stdout.write('false\n');
    if (!overallSuccess) {
      errorMessages.forEach(msg => process.stderr.write(msg + '\n'));
    }
  }
}

main();
