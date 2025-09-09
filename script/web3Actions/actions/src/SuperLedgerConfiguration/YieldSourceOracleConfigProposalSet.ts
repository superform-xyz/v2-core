import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions';
import { notifyIncidentIo } from '../utils/notifyIncidentIo';
import { isMonitoredOracle, getOracleNameFromId, getNetworkName } from '../utils/oracleHelpers';

/**
 * YieldSourceOracleConfigProposalSet Event Monitor
 * 
 * Monitors YieldSourceOracleConfigProposalSet events from SuperLedgerConfiguration
 * Severity: 3 (sev3Protocol)
 */
export const yieldSourceOracleConfigProposalSet: ActionFn = async (context: Context, event: Event) => {
  const txEvent = event as TransactionEvent;
  
  console.log('=== YieldSourceOracleConfigProposalSet Event Detected ===');
  
  if (!txEvent.logs || txEvent.logs.length === 0) {
    console.log('No logs found in transaction');
    return;
  }
  
  for (const log of txEvent.logs) {
    // Check if this log is from SuperLedgerConfiguration contract
    if (log.address?.toLowerCase() !== '0x2e2D71289CBA19f831856f85DEC7f194B0165e69'.toLowerCase()) {
      continue;
    }
    
    const topics = log.topics || [];
    if (topics.length < 3) continue;
    
    const yieldSourceOracleId = topics[1];
    const yieldSourceOracle = topics[2];
    
    // Check if this is a monitored oracle
    if (!isMonitoredOracle(yieldSourceOracleId)) {
      console.log(`Skipping non-monitored oracle: ${yieldSourceOracleId}`);
      continue;
    }
    
    const oracleName = getOracleNameFromId(yieldSourceOracleId);
    const networkName = getNetworkName(txEvent.network);
    
    console.log(`⏳ Oracle Config Proposal Set: ${oracleName}`);
    console.log(`Network: ${networkName}`);
    console.log(`Oracle ID: ${yieldSourceOracleId}`);
    console.log(`Oracle Address: ${yieldSourceOracle}`);
    console.log(`Transaction: ${txEvent.hash}`);
    
    const title = `⏳ Oracle Configuration Proposal Set: ${oracleName} on ${networkName}`;
    const description = `
**Oracle Configuration Proposal Created**

**Network:** ${networkName}
**Oracle:** ${oracleName}
**Oracle ID:** ${yieldSourceOracleId}
**Oracle Address:** ${yieldSourceOracle}
**Transaction:** ${txEvent.hash}
**Block:** ${txEvent.blockNumber}

A new yield source oracle configuration proposal has been created in the SuperLedgerConfiguration contract. This proposal will need to be accepted after the waiting period.
`;
    
    const deduplicationKey = `oracle-config-proposal-set-${yieldSourceOracleId}-${txEvent.hash}`;
    
    await notifyIncidentIo(
      'sev3Protocol',
      title,
      description,
      deduplicationKey,
      context
    );
    
    console.log('Incident sent to Incident.io');
  }
  
  console.log('=== YieldSourceOracleConfigProposalSet Monitor Completed ===');
};