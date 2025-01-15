const core = require('@actions/core');
const axios = require('axios');
const path = require('path');
const os = require('os');
const fs = require('fs/promises');

const API_BASE_URL = 'https://api.tenderly.co/api/v1';

async function createVirtualTestNet(inputs) {
    try {
        core.debug('Creating Virtual TestNet with inputs: ' + JSON.stringify(inputs));

        const slug = generateSlug(inputs.testnetName);
        console.log(slug);
        core.debug(`Making API request to create TestNet with slug: ${slug}`);

        const requestData = {
            slug,
            display_name: inputs.testnetName,
            fork_config: {
                network_id: parseInt(inputs.networkId),
                block_number: inputs.blockNumber
            },
            virtual_network_config: {
                chain_config: {
                    chain_id: parseInt(inputs.chainId)
                }
            },
            sync_state_config: {
                enabled: inputs.stateSync
            },
            explorer_page_config: {
                enabled: inputs.publicExplorer,
                verification_visibility: inputs.verificationVisibility
            }
        };

        console.log(requestData);

        core.debug('Request data: ' + JSON.stringify(requestData));

        const response = await axios({
            method: 'post',
            url: `${API_BASE_URL}/account/${inputs.accountName}/project/${inputs.projectName}/vnets`,
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'X-Access-Key': inputs.accessKey
            },
            data: requestData
        });

        const { data } = response;
        core.debug('API Response: ' + JSON.stringify(data));

        if (!data) {
            throw new Error('No data returned from Tenderly API');
        }
        if (!Array.isArray(data.rpcs)) {
            throw new Error(`Invalid RPC data in response: ${JSON.stringify(data)}`);
        }

        const adminRpc = data.rpcs.find(rpc => rpc.name === 'Admin RPC');
        const publicRpc = data.rpcs.find(rpc => rpc.name === 'Public RPC');

        if (!adminRpc || !publicRpc) {
            throw new Error(`Missing RPC endpoints in response: ${JSON.stringify(data.rpcs)}`);
        }

        return {
            id: data.id,
            adminRpcUrl: adminRpc.url,
            publicRpcUrl: publicRpc.url
        };

    } catch (error) {
        console.log(error);
        if (error.response) {
            core.debug('API Error Response: ' + JSON.stringify(error.response.data));
            const message = error.response.data.error?.message || JSON.stringify(error.response.data);
            throw new Error(`Failed to create TestNet: ${message}`);
        }
        core.debug('Error: ' + error.message);
        throw error;
    }
}

function generateSlug(testnetName) {
    const timestamp = Math.floor(Date.now() / 1000);
    const baseSlug = testnetName
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '-')
        .replace(/[^a-z0-9-]/g, '');

    return `${baseSlug}-${timestamp}`;
}


async function setupTenderlyConfig(accessKey) {
    try {
        const configDir = path.join(os.homedir(), '.tenderly');
        const configFile = path.join(configDir, 'config.yaml');

        await fs.mkdir(configDir, { recursive: true });
        await fs.writeFile(configFile, `access_key: ${accessKey}`);

        core.debug('Tenderly config file created successfully');
    } catch (error) {
        throw new Error(`Failed to create Tenderly config: ${error.message}`);
    }
}

async function stopVirtualTestNet(inputs) {
    try {
        core.debug('Stopping Virtual TestNet...');

        if (!inputs.testnetId) {
            throw new Error('TestNet ID is required for cleanup');
        }

        const response = await axios({
            method: 'patch',
            url: `${API_BASE_URL}/account/${inputs.accountName}/project/${inputs.projectName}/vnets/${inputs.testnetId}`,
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'X-Access-Key': inputs.accessKey
            },
            data: {
                status: 'stopped'
            }
        });

        core.debug('TestNet stopped successfully');
        return response.data;

    } catch (error) {
        if (error.response) {
            core.debug('API Error Response:', JSON.stringify(error.response.data, null, 2));
            const message = error.response.data.error?.message || JSON.stringify(error.response.data);
            throw new Error(`Failed to stop TestNet: ${message}`);
        }
        core.debug('Error:', error);
        throw error;
    }
}

module.exports = {
    createVirtualTestNet,
    stopVirtualTestNet,
    setupTenderlyConfig
};