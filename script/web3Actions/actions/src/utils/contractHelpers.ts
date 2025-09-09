import { Interface } from 'ethers';
import { readFileSync } from 'fs';
import { join } from 'path';

// Load the SuperLedgerConfiguration contract artifact
function loadContractArtifact() {
  const artifactPath = join(__dirname, '../../../../locked-bytecode/SuperLedgerConfiguration.json');
  const artifactContent = readFileSync(artifactPath, 'utf8');
  return JSON.parse(artifactContent);
}

// Load the SuperLedgerConfiguration contract interface
export const SuperLedgerConfigurationInterface = new Interface(loadContractArtifact().abi);

// Get event signature hashes using ethers v6
export const EVENT_SIGNATURES = {
  YieldSourceOracleConfigSet: SuperLedgerConfigurationInterface.getEvent('YieldSourceOracleConfigSet')!.topicHash,
  YieldSourceOracleConfigProposalSet: SuperLedgerConfigurationInterface.getEvent('YieldSourceOracleConfigProposalSet')!.topicHash,
  YieldSourceOracleConfigAccepted: SuperLedgerConfigurationInterface.getEvent('YieldSourceOracleConfigAccepted')!.topicHash,
  ManagerRoleTransferStarted: SuperLedgerConfigurationInterface.getEvent('ManagerRoleTransferStarted')!.topicHash,
  ManagerRoleTransferAccepted: SuperLedgerConfigurationInterface.getEvent('ManagerRoleTransferAccepted')!.topicHash,
  YieldSourceOracleConfigProposalCancelled: SuperLedgerConfigurationInterface.getEvent('YieldSourceOracleConfigProposalCancelled')!.topicHash,
};

// Event name mapping for reverse lookup
export const SIGNATURE_TO_EVENT_NAME: Record<string, string> = {
  [EVENT_SIGNATURES.YieldSourceOracleConfigSet]: 'YieldSourceOracleConfigSet',
  [EVENT_SIGNATURES.YieldSourceOracleConfigProposalSet]: 'YieldSourceOracleConfigProposalSet',
  [EVENT_SIGNATURES.YieldSourceOracleConfigAccepted]: 'YieldSourceOracleConfigAccepted',
  [EVENT_SIGNATURES.ManagerRoleTransferStarted]: 'ManagerRoleTransferStarted',
  [EVENT_SIGNATURES.ManagerRoleTransferAccepted]: 'ManagerRoleTransferAccepted',
  [EVENT_SIGNATURES.YieldSourceOracleConfigProposalCancelled]: 'YieldSourceOracleConfigProposalCancelled',
};

/**
 * Decode event log using the contract interface
 */
export function decodeEventLog(eventName: string, topics: string[], data: string) {
  try {
    return SuperLedgerConfigurationInterface.decodeEventLog(eventName, data, topics);
  } catch (error) {
    console.error(`Failed to decode ${eventName} event:`, error);
    return null;
  }
}