import { createHash } from 'crypto';
import * as config from '../config/oracleConfig.json';
import { getNetworkName as getNetworkNameFromScript } from './networkHelpers';

/**
 * Derives oracle ID with sender address (replicates Solidity _deriveWithSender)
 * Computes keccak256(abi.encodePacked(salt, sender))
 */
export function deriveWithSender(saltString: string, sender: string): string {
  // Convert salt string to bytes32 (left-padded to 32 bytes)
  const saltBytes = Buffer.from(saltString, 'utf8');
  const salt = Buffer.alloc(32);
  saltBytes.copy(salt, 0);
  
  // Convert sender address to bytes (remove 0x prefix)
  const senderBytes = Buffer.from(sender.slice(2), 'hex');
  
  // Concatenate salt + sender (equivalent to abi.encodePacked)
  const packed = Buffer.concat([salt, senderBytes]);
  
  // Compute keccak256
  const hash = createHash('sha3-256').update(packed).digest();
  return '0x' + hash.toString('hex');
}

/**
 * Get all monitored oracle IDs (derived with Fireblocks sender)
 * Supports multiple salts per oracle type
 */
export function getMonitoredOracleIds(): { [key: string]: string[] } {
  const oracleIds: { [key: string]: string[] } = {};
  
  Object.entries(config.yieldSourceOracles).forEach(([name, oracleConfig]) => {
    oracleIds[name] = oracleConfig.salts.map(salt => 
      deriveWithSender(salt, config.fireblocksSender)
    );
  });
  
  return oracleIds;
}

/**
 * Check if an oracle ID is one we're monitoring
 */
export function isMonitoredOracle(oracleId: string): boolean {
  const monitoredIds = Object.values(getMonitoredOracleIds()).flat();
  return monitoredIds.some(id => id.toLowerCase() === oracleId.toLowerCase());
}

/**
 * Get oracle name from ID
 */
export function getOracleNameFromId(oracleId: string): string | null {
  const oracleIds = getMonitoredOracleIds();
  
  for (const [name, ids] of Object.entries(oracleIds)) {
    if (ids.some(id => id.toLowerCase() === oracleId.toLowerCase())) {
      return name;
    }
  }
  
  return null;
}

/**
 * Get network name from chain ID (reads from networks-production.sh)
 */
export function getNetworkName(chainId: string | number): string {
  return getNetworkNameFromScript(chainId);
}