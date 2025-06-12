#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Efficient Merkle Proof Lookup Script
 * 
 * This script pre-builds lookup indices for fast proof retrieval,
 * avoiding the need to load and search the entire merkle tree in Solidity.
 */

class EfficientProofLookup {
    constructor(chainId = 1) {
        this.chainId = chainId;
        this.lookupMap = new Map();
        this.initialized = false;
    }

    /**
     * Initialize the lookup system by loading cached indices or building from scratch
     */
    init() {
        if (this.initialized) return;

        const outputDir = path.join(__dirname, '../output');
        const lookupCachePath = path.join(outputDir, `lookup_cache_${this.chainId}.json`);

        // Try to load from cache first
        if (fs.existsSync(lookupCachePath)) {
            try {
                if (process.env.NODE_ENV !== 'test' && !process.env.SOLIDITY_CALL) {
                    console.log('Loading lookup cache...');
                }
                const cacheData = JSON.parse(fs.readFileSync(lookupCachePath, 'utf8'));

                // Convert cached object back to Map
                this.lookupMap = new Map();
                for (const [key, value] of Object.entries(cacheData.lookupMap)) {
                    this.lookupMap.set(key, value);
                }

                if (process.env.NODE_ENV !== 'test' && !process.env.SOLIDITY_CALL) {
                    console.log(`Loaded ${this.lookupMap.size} entries from cache`);
                }
                this.initialized = true;
                return;
            } catch (error) {
                if (process.env.NODE_ENV !== 'test') {
                    console.log('Cache load failed, building from tree dump:', error.message);
                }
            }
        }

        // Fallback: build from tree dump (legacy/development mode)
        this.buildFromTreeDump();
    }

    /**
     * Build lookup indices from tree dump (fallback method)
     */
    buildFromTreeDump() {
        const outputDir = path.join(__dirname, '../output');
        const treeDumpPath = path.join(outputDir, `jsTreeDump_${this.chainId}.json`);

        if (!fs.existsSync(treeDumpPath)) {
            throw new Error(`Tree dump file not found: ${treeDumpPath}. Run deterministic merkle generation first.`);
        }

        if (process.env.NODE_ENV !== 'test') {
            console.log('Loading merkle tree data...');
        }
        const treeDump = JSON.parse(fs.readFileSync(treeDumpPath, 'utf8'));

        if (process.env.NODE_ENV !== 'test') {
            console.log(`Building lookup indices for ${treeDump.count} entries...`);
        }

        // Build efficient lookup map: "hookAddress:encodedArgs" -> proof
        for (let i = 0; i < treeDump.values.length; i++) {
            const entry = treeDump.values[i];
            const hookAddress = entry.hookAddress.toLowerCase();
            const encodedArgs = entry.value[0]; // The encoded args are the first (and only) value

            // Create composite key for O(1) lookup
            const lookupKey = `${hookAddress}:${encodedArgs}`;

            this.lookupMap.set(lookupKey, {
                proof: entry.proof,
                hookName: entry.hookName,
                hookAddress: entry.hookAddress,
                encodedArgs: encodedArgs
            });
        }

        if (process.env.NODE_ENV !== 'test') {
            console.log(`Lookup indices built. ${this.lookupMap.size} entries indexed.`);
        }
        this.initialized = true;
    }

    /**
     * Get proofs for multiple hooks efficiently
     * @param {string[]} hookAddresses - Array of hook addresses
     * @param {string[]} encodedHookArgs - Array of encoded hook arguments (as hex strings)
     * @returns {string[][]} Array of proof arrays (as hex strings)
     */
    getProofsForHooks(hookAddresses, encodedHookArgs) {
        this.init();

        if (hookAddresses.length !== encodedHookArgs.length) {
            throw new Error('Hook addresses and encoded args arrays must have the same length');
        }

        if (hookAddresses.length === 0) {
            throw new Error('Empty input arrays');
        }

        const results = [];

        for (let i = 0; i < hookAddresses.length; i++) {
            const hookAddress = hookAddresses[i].toLowerCase();
            const encodedArgs = encodedHookArgs[i];

            // Create lookup key
            const lookupKey = `${hookAddress}:${encodedArgs}`;

            // O(1) lookup
            const entry = this.lookupMap.get(lookupKey);

            if (!entry) {
                console.error(`No proof found for hook: ${hookAddresses[i]}, args: ${encodedArgs}`);
                throw new Error(`No proof found for hook address: ${hookAddresses[i]}`);
            }

            results.push(entry.proof);
        }

        return results;
    }

    /**
     * Get a single proof for debugging/testing
     */
    getSingleProof(hookAddress, encodedArgs) {
        const proofs = this.getProofsForHooks([hookAddress], [encodedArgs]);
        return proofs[0];
    }

    /**
     * List all available hooks for debugging
     */
    listAvailableHooks() {
        this.init();

        const hooks = new Map();

        for (const [key, value] of this.lookupMap) {
            const hookAddress = value.hookAddress;
            if (!hooks.has(hookAddress)) {
                hooks.set(hookAddress, {
                    name: value.hookName,
                    address: hookAddress,
                    argsCount: 0
                });
            }
            hooks.get(hookAddress).argsCount++;
        }

        if (process.env.NODE_ENV !== 'test') {
            console.log('\nAvailable hooks:');
            for (const [address, info] of hooks) {
                console.log(`  ${info.name}: ${address} (${info.argsCount} combinations)`);
            }
        }

        return Array.from(hooks.values());
    }
}

// CLI interface
if (require.main === module) {
    const args = process.argv.slice(2);

    if (args.length === 0) {
        console.log('Usage:');
        console.log('  node efficient-proof-lookup.js list                    # List available hooks');
        console.log('  node efficient-proof-lookup.js get <addr> <args>       # Get single proof');
        console.log('  node efficient-proof-lookup.js batch <addrs> <args>    # Get multiple proofs');
        console.log('');
        console.log('For batch mode:');
        console.log('  <addrs>: comma-separated hook addresses');
        console.log('  <args>:  comma-separated encoded arguments');
        process.exit(1);
    }

    const lookup = new EfficientProofLookup(1);

    try {
        if (args[0] === 'list') {
            lookup.listAvailableHooks();
        } else if (args[0] === 'get' && args.length === 3) {
            const [, hookAddress, encodedArgs] = args;
            const proof = lookup.getSingleProof(hookAddress, encodedArgs);
            console.log(JSON.stringify(proof));
        } else if (args[0] === 'batch' && args.length >= 3) {
            // Suppress logs for batch mode (typically called from Solidity)
            process.env.SOLIDITY_CALL = 'true';

            const addressesStr = args[1];
            const argsStr = args[2];
            const addresses = addressesStr.split(',');
            const argsList = argsStr.split(',');

            const proofs = lookup.getProofsForHooks(addresses, argsList);
            console.log(JSON.stringify(proofs));
        } else {
            console.error('Invalid arguments');
            process.exit(1);
        }
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

module.exports = EfficientProofLookup; 