import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions';
import { EVENT_SIGNATURES, decodeEventLog } from '../utils/contractHelpers';
import { notifyIncidentIo } from '../utils/notifyIncidentIo';
import { isMonitoredOracle, getOracleNameFromId, getNetworkName } from '../utils/oracleHelpers';

/**
 * YieldSourceOracleConfigProposalCancelled Event Monitor
 * 
 * Monitors YieldSourceOracleConfigProposalCancelled events from SuperLedgerConfiguration
 * Severity: 4 (sev4Protocol)
 */
export const yieldSourceOracleConfigProposalCancelled: ActionFn = async (context: Context, event: Event) => {
  const txEvent = event as TransactionEvent;
  
  console.log('=== YieldSourceOracleConfigProposalCancelled Event Detected ===');
  
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
    if (topics.length < 2 || topics[0] !== EVENT_SIGNATURES.YieldSourceOracleConfigProposalCancelled) {
      continue;
    }
    
    // Decode the event to get structured data
    const decodedEvent = decodeEventLog('YieldSourceOracleConfigProposalCancelled', topics, log.data || '0x');
    if (!decodedEvent) {
      console.log('Failed to decode YieldSourceOracleConfigProposalCancelled event');
      continue;
    }
    
    const yieldSourceOracleId = decodedEvent.yieldSourceOracleId;
    
    // Check if this is a monitored oracle
    if (!isMonitoredOracle(yieldSourceOracleId)) {
      console.log(`Skipping non-monitored oracle: ${yieldSourceOracleId}`);
      continue;
    }
    
    const oracleName = getOracleNameFromId(yieldSourceOracleId);
    const networkName = getNetworkName(txEvent.network);
    
    console.log(`❌ Oracle Config Proposal Cancelled: ${oracleName}`);
    console.log(`Network: ${networkName}`);
    console.log(`Oracle ID: ${yieldSourceOracleId}`);
    console.log(`Oracle Address: ${decodedEvent.yieldSourceOracle}`);
    console.log(`Manager: ${decodedEvent.manager}`);
    console.log(`Transaction: ${txEvent.hash}`);
    
    const title = `❌ Oracle Configuration Proposal Cancelled: ${oracleName} on ${networkName}`;
    const description = `
**Oracle Configuration Proposal Cancelled**

**Network:** ${networkName}
**Oracle:** ${oracleName}
**Oracle ID:** ${yieldSourceOracleId}
**Oracle Address:** ${decodedEvent.yieldSourceOracle}
**Manager:** ${decodedEvent.manager}
**Fee Percent:** ${decodedEvent.feePercent.toString()}
**Fee Recipient:** ${decodedEvent.feeRecipient}
**Ledger:** ${decodedEvent.ledger}
**Transaction:** ${txEvent.hash}
**Block:** ${txEvent.blockNumber}

A yield source oracle configuration proposal has been cancelled in the SuperLedgerConfiguration contract.
`;
    
    const deduplicationKey = `oracle-config-proposal-cancelled-${yieldSourceOracleId}-${txEvent.hash}`;
    
    await notifyIncidentIo(
      'sev4Protocol',
      title,
      description,
      deduplicationKey,
      context
    );
    
    console.log('Incident sent to Incident.io');
  }
  
  console.log('=== YieldSourceOracleConfigProposalCancelled Monitor Completed ===');
};