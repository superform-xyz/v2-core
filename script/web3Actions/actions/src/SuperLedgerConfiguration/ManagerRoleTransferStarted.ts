import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions';
import { notifyIncidentIo } from '../utils/notifyIncidentIo';
import { isMonitoredOracle, getOracleNameFromId, getNetworkName } from '../utils/oracleHelpers';

/**
 * ManagerRoleTransferStarted Event Monitor
 * 
 * Monitors ManagerRoleTransferStarted events from SuperLedgerConfiguration
 * Severity: 3 (sev3Protocol)
 */
export const managerRoleTransferStarted: ActionFn = async (context: Context, event: Event) => {
  const txEvent = event as TransactionEvent;
  
  console.log('=== ManagerRoleTransferStarted Event Detected ===');
  
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
    if (topics.length < 4) continue;
    
    const yieldSourceOracleId = topics[1];
    const currentManager = topics[2];
    const newManager = topics[3];
    
    // Check if this is a monitored oracle
    if (!isMonitoredOracle(yieldSourceOracleId)) {
      console.log(`Skipping non-monitored oracle: ${yieldSourceOracleId}`);
      continue;
    }
    
    const oracleName = getOracleNameFromId(yieldSourceOracleId);
    const networkName = getNetworkName(txEvent.network);
    
    console.log(`🔄 Manager Role Transfer Started: ${oracleName}`);
    console.log(`Network: ${networkName}`);
    console.log(`Oracle ID: ${yieldSourceOracleId}`);
    console.log(`Current Manager: ${currentManager}`);
    console.log(`New Manager: ${newManager}`);
    console.log(`Transaction: ${txEvent.hash}`);
    
    const title = `🔄 Manager Role Transfer Started: ${oracleName} on ${networkName}`;
    const description = `
**Manager Role Transfer Initiated**

**Network:** ${networkName}
**Oracle:** ${oracleName}
**Oracle ID:** ${yieldSourceOracleId}
**Current Manager:** ${currentManager}
**New Manager:** ${newManager}
**Transaction:** ${txEvent.hash}
**Block:** ${txEvent.blockNumber}

A manager role transfer has been initiated for a yield source oracle. The new manager must accept the role for the transfer to complete.
`;
    
    const deduplicationKey = `manager-role-transfer-started-${yieldSourceOracleId}-${txEvent.hash}`;
    
    await notifyIncidentIo(
      'sev3Protocol',
      title,
      description,
      deduplicationKey,
      context
    );
    
    console.log('Incident sent to Incident.io');
  }
  
  console.log('=== ManagerRoleTransferStarted Monitor Completed ===');
};