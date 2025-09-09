import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions';
import { EVENT_SIGNATURES, decodeEventLog } from '../utils/contractHelpers';
import { notifyIncidentIo } from '../utils/notifyIncidentIo';
import { isMonitoredOracle, getOracleNameFromId, getNetworkName } from '../utils/oracleHelpers';

/**
 * ManagerRoleTransferAccepted Event Monitor
 * 
 * Monitors ManagerRoleTransferAccepted events from SuperLedgerConfiguration
 * Severity: 3 (sev3Protocol)
 */
export const managerRoleTransferAccepted: ActionFn = async (context: Context, event: Event) => {
  const txEvent = event as TransactionEvent;
  
  console.log('=== ManagerRoleTransferAccepted Event Detected ===');
  
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
    if (topics.length < 3 || topics[0] !== EVENT_SIGNATURES.ManagerRoleTransferAccepted) {
      continue;
    }
    
    // Decode the event to get structured data
    const decodedEvent = decodeEventLog('ManagerRoleTransferAccepted', topics, log.data || '0x');
    if (!decodedEvent) {
      console.log('Failed to decode ManagerRoleTransferAccepted event');
      continue;
    }
    
    const yieldSourceOracleId = decodedEvent.yieldSourceOracleId;
    const newManager = decodedEvent.newManager;
    
    // Check if this is a monitored oracle
    if (!isMonitoredOracle(yieldSourceOracleId)) {
      console.log(`Skipping non-monitored oracle: ${yieldSourceOracleId}`);
      continue;
    }
    
    const oracleName = getOracleNameFromId(yieldSourceOracleId);
    const networkName = getNetworkName(txEvent.network);
    
    console.log(`✅ Manager Role Transfer Accepted: ${oracleName}`);
    console.log(`Network: ${networkName}`);
    console.log(`Oracle ID: ${yieldSourceOracleId}`);
    console.log(`New Manager: ${newManager}`);
    console.log(`Transaction: ${txEvent.hash}`);
    
    const title = `✅ Manager Role Transfer Accepted: ${oracleName} on ${networkName}`;
    const description = `
**Manager Role Transfer Completed**

**Network:** ${networkName}
**Oracle:** ${oracleName}
**Oracle ID:** ${yieldSourceOracleId}
**New Manager:** ${newManager}
**Transaction:** ${txEvent.hash}
**Block:** ${txEvent.blockNumber}

A manager role transfer has been completed for a yield source oracle. The new manager is now active.
`;
    
    const deduplicationKey = `manager-role-transfer-accepted-${yieldSourceOracleId}-${txEvent.hash}`;
    
    await notifyIncidentIo(
      'sev3Protocol',
      title,
      description,
      deduplicationKey,
      context
    );
    
    console.log('Incident sent to Incident.io');
  }
  
  console.log('=== ManagerRoleTransferAccepted Monitor Completed ===');
};