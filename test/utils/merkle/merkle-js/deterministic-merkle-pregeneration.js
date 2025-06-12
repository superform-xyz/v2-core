#!/usr/bin/env node

/**
 * Foundry-Compatible Merkle Tree Pre-Generation
 * 
 * This script replicates the exact same address calculation logic used in BaseTest.t.sol
 * by inheriting from BaseTest, calling setUp(), and extracting the calculated addresses.
 */

const fs = require('fs');
const { execSync } = require('child_process');

class DeterministicMerkleGen {
    constructor() {
        this.verbose = process.argv.includes('--verbose') || process.argv.includes('-v');
        this.force = process.argv.includes('--force') || process.argv.includes('-f');
        this.cacheFile = '../target/deterministic_addresses.json';
    }

    log(...args) {
        if (this.verbose) {
            console.log('[DETERMINISTIC]', ...args);
        }
    }

    /**
     * Get addresses using the BaseTest forge test method
     */
    calculateAllAddresses() {
        this.log('Getting addresses using BaseTest forge test...');
        return this.getAddressesViaTest();
    }



    /**
     * Parse console output from either script or test
     */
    parseConsoleOutput(output) {
        const lines = output.split('\n');
        const addresses = {
            vaults: {},
            hooks: {}
        };

        // Look for console.log output lines
        for (const line of lines) {
            if (line.includes('VAULT_globalSVStrategy:')) {
                addresses.vaults.globalSVStrategy = this.extractAddress(line);
            } else if (line.includes('VAULT_globalSVGearStrategy:')) {
                addresses.vaults.globalSVGearStrategy = this.extractAddress(line);
            } else if (line.includes('VAULT_globalRuggableVault:')) {
                addresses.vaults.globalRuggableVault = this.extractAddress(line);
            } else if (line.includes('HOOK_APPROVE_AND_REDEEM_4626_VAULT_HOOK:')) {
                addresses.hooks.APPROVE_AND_REDEEM_4626_VAULT_HOOK = this.extractAddress(line);
            } else if (line.includes('HOOK_APPROVE_AND_DEPOSIT_4626_VAULT_HOOK:')) {
                addresses.hooks.APPROVE_AND_DEPOSIT_4626_VAULT_HOOK = this.extractAddress(line);
            } else if (line.includes('HOOK_REDEEM_4626_VAULT_HOOK:')) {
                addresses.hooks.REDEEM_4626_VAULT_HOOK = this.extractAddress(line);
            } else if (line.includes('HOOK_APPROVE_AND_GEARBOX_STAKE_HOOK:')) {
                addresses.hooks.APPROVE_AND_GEARBOX_STAKE_HOOK = this.extractAddress(line);
            } else if (line.includes('HOOK_GEARBOX_UNSTAKE_HOOK:')) {
                addresses.hooks.GEARBOX_UNSTAKE_HOOK = this.extractAddress(line);
            }
        }

        // Validate the addresses
        this.validateAddresses(addresses);

        this.log('Retrieved addresses from console output:', JSON.stringify(addresses, null, 2));
        return addresses;
    }

    /**
     * Get addresses using forge test method via make
     */
    getAddressesViaTest() {
        this.log('Running forge test via make...');

        try {
            const result = execSync('make forge-test-internal TEST=test/utils/merkle/merkle-js/GetAddressesFromBaseTest.s.sol ARGS="--match-test test_getAddresses -vv"', {
                encoding: 'utf8',
                cwd: '../../../../', // Go back to project root
                timeout: 120000, // 2 minute timeout for setUp()
                env: { ...process.env, ENVIRONMENT: 'local' }
            });

            // Parse the console output
            return this.parseConsoleOutput(result);

        } catch (error) {
            this.log('Error getting addresses from BaseTest test:', error.message);
            if (this.verbose && error.stdout) {
                this.log('Forge stdout:', error.stdout);
            }
            if (this.verbose && error.stderr) {
                this.log('Forge stderr:', error.stderr);
            }

            // Fallback: try to extract from existing test artifacts
            return this.extractAddressesFromTestArtifacts();
        }
    }

    /**
     * Extract address from a console.log line
     */
    extractAddress(line) {
        // Look for pattern like "VAULT_globalSVStrategy: 0x1234..."
        const match = line.match(/0x[a-fA-F0-9]{40}/);
        return match ? match[0] : '';
    }

    /**
     * Validate calculated addresses
     */
    validateAddresses(addresses) {
        const requiredVaults = ['globalSVStrategy', 'globalSVGearStrategy', 'globalRuggableVault'];
        const requiredHooks = [
            'APPROVE_AND_REDEEM_4626_VAULT_HOOK',
            'APPROVE_AND_DEPOSIT_4626_VAULT_HOOK',
            'REDEEM_4626_VAULT_HOOK',
            'APPROVE_AND_GEARBOX_STAKE_HOOK',
            'GEARBOX_UNSTAKE_HOOK'
        ];

        // Check vaults
        if (!addresses.vaults) {
            throw new Error('Missing vaults object');
        }
        for (const vault of requiredVaults) {
            if (!addresses.vaults[vault] || addresses.vaults[vault] === '0x0000000000000000000000000000000000000000') {
                throw new Error(`Invalid or missing vault address for ${vault}: ${addresses.vaults[vault]}`);
            }
        }

        // Check hooks  
        if (!addresses.hooks) {
            throw new Error('Missing hooks object');
        }
        for (const hook of requiredHooks) {
            if (!addresses.hooks[hook] || addresses.hooks[hook] === '0x0000000000000000000000000000000000000000') {
                throw new Error(`Invalid or missing hook address for ${hook}: ${addresses.hooks[hook]}`);
            }
        }

        this.log('Address validation passed');
    }

    /**
     * Fallback: extract addresses from existing test artifacts
     */
    extractAddressesFromTestArtifacts() {
        this.log('Attempting to extract addresses from test artifacts...');

        // Try to read from existing owner_list.json to get the original addresses
        const originalOwnerListPath = '../target/owner_list.json';

        if (fs.existsSync(originalOwnerListPath)) {
            try {
                const originalOwnerList = JSON.parse(fs.readFileSync(originalOwnerListPath, 'utf8'));

                if (originalOwnerList.length >= 8) {
                    this.log('Found original owner list with', originalOwnerList.length, 'addresses');

                    // Map back to the expected structure based on the original order
                    // The order typically is: strategies first, then hooks
                    return {
                        vaults: {
                            globalSVStrategy: originalOwnerList[0], // First three are strategies
                            globalSVGearStrategy: originalOwnerList[1],
                            globalRuggableVault: originalOwnerList[2]
                        },
                        hooks: {
                            // The remaining are hooks in the order they appear in globalMerkleHooks
                            APPROVE_AND_REDEEM_4626_VAULT_HOOK: originalOwnerList[3] || originalOwnerList[0],
                            APPROVE_AND_DEPOSIT_4626_VAULT_HOOK: originalOwnerList[4] || originalOwnerList[0],
                            REDEEM_4626_VAULT_HOOK: originalOwnerList[5] || originalOwnerList[0],
                            APPROVE_AND_GEARBOX_STAKE_HOOK: originalOwnerList[6] || originalOwnerList[0],
                            GEARBOX_UNSTAKE_HOOK: originalOwnerList[7] || originalOwnerList[0]
                        }
                    };
                }
            } catch (error) {
                this.log('Error reading original owner list:', error.message);
            }
        }

        throw new Error('Could not extract addresses from test artifacts');
    }

    /**
     * Check if regeneration is needed
     */
    needsRegeneration(currentAddresses) {
        if (!fs.existsSync(this.cacheFile)) {
            this.log('No cache file found - regeneration needed');
            return true;
        }

        try {
            const cached = JSON.parse(fs.readFileSync(this.cacheFile, 'utf8'));

            // Compare calculated addresses with cached ones
            const currentHash = this.hashAddresses(currentAddresses);
            if (cached.addressHash !== currentHash) {
                this.log('Addresses changed - regeneration needed');
                return true;
            }

            // Check if merkle tree files exist
            if (!fs.existsSync('../output/jsGeneratedRoot_1.json')) {
                this.log('Merkle tree files missing - regeneration needed');
                return true;
            }

            // Check if lookup cache exists
            if (!fs.existsSync('../output/lookup_cache_1.json')) {
                this.log('Lookup cache missing - regeneration needed');
                return true;
            }

            return false;
        } catch (error) {
            this.log('Error reading cache:', error.message);
            return true;
        }
    }

    /**
     * Hash addresses for comparison (simple string hash)
     */
    hashAddresses(addresses) {
        const allAddresses = [
            ...Object.values(addresses.vaults),
            ...Object.values(addresses.hooks)
        ];
        // Simple string hash for comparison
        return JSON.stringify(allAddresses.sort());
    }

    /**
     * Save address cache
     */
    saveAddressCache(addresses) {
        try {
            // Ensure directory exists
            const dir = '../target';
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }

            const cacheData = {
                timestamp: Date.now(),
                addressHash: this.hashAddresses(addresses),
                addresses: addresses
            };

            fs.writeFileSync(this.cacheFile, JSON.stringify(cacheData, null, 2));
            this.log('Saved address cache');
        } catch (error) {
            this.log('Could not save cache:', error.message);
        }
    }

    /**
     * Generate merkle tree using existing script
     */
    async generateMerkleTree(addresses) {
        const hookAddresses = Object.values(addresses.hooks);
        const vaultAddresses = Object.values(addresses.vaults);

        this.log(`Generating merkle tree with ${hookAddresses.length} hooks and ${vaultAddresses.length} vaults`);

        const scriptPath = 'test/utils/merkle/merkle-js/build-hook-merkle-trees.js';
        const localScriptPath = './build-hook-merkle-trees.js';

        if (!fs.existsSync(localScriptPath)) {
            throw new Error(`Merkle generation script not found: ${localScriptPath}`);
        }

        const hooksString = hookAddresses.join(',');
        const vaultsString = vaultAddresses.join(',');

        try {
            execSync(
                `node ${scriptPath} "${hooksString}" "${vaultsString}"`,
                {
                    encoding: 'utf8',
                    cwd: '../../../../', // Go back to project root for merkle generation
                    stdio: this.verbose ? 'inherit' : 'pipe'
                }
            );
            this.log('Merkle tree generation completed');
        } catch (error) {
            throw new Error(`Merkle generation failed: ${error.message}`);
        }
    }

    /**
     * Generate optimized lookup cache from merkle tree
     */
    async generateLookupCache() {
        this.log('Generating optimized lookup cache...');

        const EfficientProofLookup = require('./efficient-proof-lookup.js');
        const lookup = new EfficientProofLookup(1);

        try {
            // Force initialization to build the lookup map
            lookup.init();

            // Convert the Map to a plain object for JSON serialization
            const lookupData = {};
            for (const [key, value] of lookup.lookupMap) {
                lookupData[key] = value;
            }

            // Save the optimized lookup cache
            const outputDir = '../output';
            if (!fs.existsSync(outputDir)) {
                fs.mkdirSync(outputDir, { recursive: true });
            }

            const lookupCachePath = `${outputDir}/lookup_cache_1.json`;
            const cacheData = {
                timestamp: Date.now(),
                chainId: 1,
                entryCount: Object.keys(lookupData).length,
                lookupMap: lookupData
            };

            fs.writeFileSync(lookupCachePath, JSON.stringify(cacheData));

            this.log(`Lookup cache generated with ${cacheData.entryCount} entries`);
            this.log(`Cache saved to: ${lookupCachePath}`);

        } catch (error) {
            throw new Error(`Lookup cache generation failed: ${error.message}`);
        }
    }

    async run() {
        try {
            console.log('🌲 Pre-generating merkle tree using BaseTest...');

            // Get addresses from BaseTest
            const addresses = this.calculateAllAddresses();

            // Check if regeneration needed
            if (!this.force && !this.needsRegeneration(addresses)) {
                console.log('✅ Merkle tree already generated for current addresses');
                return true;
            }

            // Generate merkle tree
            await this.generateMerkleTree(addresses);

            // Generate optimized lookup cache
            await this.generateLookupCache();

            // Save address cache
            this.saveAddressCache(addresses);

            console.log('✅ Deterministic merkle tree pre-generation completed');
            return true;

        } catch (error) {
            console.error('❌ Error:', error.message);
            if (this.verbose) {
                console.error(error.stack);
            }
            return false;
        }
    }
}

// Run if called directly
if (require.main === module) {
    const generator = new DeterministicMerkleGen();
    generator.run().then(success => {
        process.exit(success ? 0 : 1);
    });
}

module.exports = { DeterministicMerkleGen }; 