import { readFileSync } from 'fs';
import { join } from 'path';

/**
 * Network information interface
 */
export interface NetworkInfo {
  id: string;
  name: string;
}

/**
 * Parse networks from networks-production.sh script
 * This reads the production networks configuration directly from the shell script
 */
export function getProductionNetworks(): NetworkInfo[] {
  try {
    const networkScriptPath = join(__dirname, '../../../../run/networks-production.sh');
    const scriptContent = readFileSync(networkScriptPath, 'utf8');
    
    const networks: NetworkInfo[] = [];
    
    // Parse network array from the NETWORKS declaration
    const networksMatch = scriptContent.match(/NETWORKS=\(\s*([^)]+)\s*\)/);
    if (!networksMatch) {
      console.error('Could not find NETWORKS array in networks-production.sh');
      return getDefaultNetworks();
    }
    
    const networksContent = networksMatch[1];
    const networkLines = networksContent.split('\n').map(line => line.trim()).filter(line => line && !line.startsWith('#'));
    
    for (const line of networkLines) {
      // Parse lines like: "ethereum:1:ETH_MAINNET"
      const parts = line.replace(/['"]/g, '').split(':');
      if (parts.length >= 3) {
        const name = parts[0];
        const id = parts[1];
        networks.push({
          id,
          name: name.charAt(0).toUpperCase() + name.slice(1) // Capitalize first letter
        });
      }
    }
    
    return networks.length > 0 ? networks : getDefaultNetworks();
    
  } catch (error) {
    console.error('Error reading networks from networks-production.sh:', error);
    return getDefaultNetworks();
  }
}

/**
 * Fallback network configuration if we can't read from the script
 */
function getDefaultNetworks(): NetworkInfo[] {
  return [
    { id: '1', name: 'Ethereum' },
    { id: '8453', name: 'Base' },
    { id: '56', name: 'BNB Chain' },
    { id: '42161', name: 'Arbitrum' },
    { id: '10', name: 'Optimism' },
    { id: '137', name: 'Polygon' },
    { id: '130', name: 'Unichain' },
    { id: '43114', name: 'Avalanche' },
    { id: '80094', name: 'Berachain' },
    { id: '146', name: 'Sonic' },
    { id: '100', name: 'Gnosis' },
    { id: '480', name: 'Worldchain' }
  ];
}

/**
 * Get network name by ID
 */
export function getNetworkName(networkId: string | number): string {
  const networks = getProductionNetworks();
  const network = networks.find(n => n.id === String(networkId));
  return network ? network.name : `Network ${networkId}`;
}

/**
 * Check if network is supported for monitoring
 */
export function isNetworkSupported(networkId: string | number): boolean {
  const networks = getProductionNetworks();
  return networks.some(n => n.id === String(networkId));
}