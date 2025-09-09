import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions';
import { notifyIncidentIo } from '../utils/notifyIncidentIo';
import { isMonitoredOracle, getOracleNameFromId, getNetworkName } from '../utils/oracleHelpers';

/**
 * YieldSourceOracleConfigSet Event Monitor
 * 
 * Monitors YieldSourceOracleConfigSet events from SuperLedgerConfiguration
 * Severity: 3 (sev3Protocol)
 */
export const yieldSourceOracleConfigSet: ActionFn = async (context: Context, event: Event) => {
  const txEvent = event as TransactionEvent;
  
  console.log('=== YieldSourceOracleConfigSet Event Detected ===');
  
  // Parse event logs to find YieldSourceOracleConfigSet events
  const targetEventSignature = '0x'; // Event signature hash for YieldSourceOracleConfigSet
  
  if (!txEvent.logs || txEvent.logs.length === 0) {
    console.log('No logs found in transaction');
    return;
  }
  
  for (const log of txEvent.logs) {
    // Check if this log is from SuperLedgerConfiguration contract
    if (log.address?.toLowerCase() !== '0x2e2D71289CBA19f831856f85DEC7f194B0165e69'.toLowerCase()) {
      continue;
    }
    
    // Parse the event data (simplified - in production you'd use proper ABI decoding)
    const topics = log.topics || [];
    if (topics.length < 3) continue;
    
    // topics[0] = event signature
    // topics[1] = yieldSourceOracleId (indexed)
    // topics[2] = yieldSourceOracle address (indexed)
    const yieldSourceOracleId = topics[1];
    const yieldSourceOracle = topics[2];
    
    // Check if this is a monitored oracle
    if (!isMonitoredOracle(yieldSourceOracleId)) {
      console.log(`Skipping non-monitored oracle: ${yieldSourceOracleId}`);
      continue;
    }
    
    const oracleName = getOracleNameFromId(yieldSourceOracleId);
    const networkName = getNetworkName(txEvent.network);
    
    console.log(`✅ Monitored Oracle Config Set: ${oracleName}`);
    console.log(`Network: ${networkName}`);
    console.log(`Oracle ID: ${yieldSourceOracleId}`);
    console.log(`Oracle Address: ${yieldSourceOracle}`);
    console.log(`Transaction: ${txEvent.hash}`);
    
    const title = `🔧 Oracle Configuration Set: ${oracleName} on ${networkName}`;
    const description = `
**Oracle Configuration Updated**

**Network:** ${networkName}
**Oracle:** ${oracleName}
**Oracle ID:** ${yieldSourceOracleId}
**Oracle Address:** ${yieldSourceOracle}
**Transaction:** ${txEvent.hash}
**Block:** ${txEvent.blockNumber}

A yield source oracle configuration has been successfully set in the SuperLedgerConfiguration contract.
`;
    
    const deduplicationKey = `oracle-config-set-${yieldSourceOracleId}-${txEvent.hash}`;
    
    await notifyIncidentIo(
      'sev3Protocol',
      title,
      description,
      deduplicationKey,
      context
    );
    
    console.log('Incident sent to Incident.io');
  }
  
  console.log('=== YieldSourceOracleConfigSet Monitor Completed ===');
};