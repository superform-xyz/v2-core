import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions';
import { EVENT_SIGNATURES, SIGNATURE_TO_EVENT_NAME } from '../utils/contractHelpers';
import { yieldSourceOracleConfigSet } from './YieldSourceOracleConfigSet';
import { yieldSourceOracleConfigProposalSet } from './YieldSourceOracleConfigProposalSet';
import { yieldSourceOracleConfigAccepted } from './YieldSourceOracleConfigAccepted';
import { managerRoleTransferStarted } from './ManagerRoleTransferStarted';
import { managerRoleTransferAccepted } from './ManagerRoleTransferAccepted';
import { yieldSourceOracleConfigProposalCancelled } from './YieldSourceOracleConfigProposalCancelled';

/**
 * Combined SuperLedgerConfiguration Event Monitor
 * 
 * This single action monitors all relevant events from the SuperLedgerConfiguration contract
 * and routes them to appropriate handlers based on event signatures.
 */
export const trackLedgerConfigurationEvents: ActionFn = async (context: Context, event: Event) => {
  const txEvent = event as TransactionEvent;
  
  console.log('=== SuperLedgerConfiguration Event Monitor ===');
  console.log(`Network: ${txEvent.network}`);
  console.log(`Transaction: ${txEvent.hash}`);
  console.log(`Block: ${txEvent.blockNumber}`);
  console.log(`Contract: ${txEvent.to}`);
  
  if (!txEvent.logs || txEvent.logs.length === 0) {
    console.log('No logs found in transaction');
    return;
  }
  
  console.log('Event signatures loaded:', EVENT_SIGNATURES);
  
  let eventsProcessed = 0;
  
  for (const log of txEvent.logs) {
    // Only process logs from SuperLedgerConfiguration contract
    if (log.address?.toLowerCase() !== '0x2e2D71289CBA19f831856f85DEC7f194B0165e69'.toLowerCase()) {
      continue;
    }
    
    const topics = log.topics || [];
    if (topics.length === 0) continue;
    
    const eventSignature = topics[0];
    
    try {
      const eventSignature = topics[0];
      const eventName = SIGNATURE_TO_EVENT_NAME[eventSignature];
      
      if (!eventName) {
        console.log(`Unknown event signature: ${eventSignature}`);
        continue;
      }
      
      console.log(`Processing ${eventName} event`);
      
      // Route to appropriate event handler based on signature
      switch (eventName) {
        case 'YieldSourceOracleConfigSet':
          await yieldSourceOracleConfigSet(context, event);
          break;
        case 'YieldSourceOracleConfigProposalSet':
          await yieldSourceOracleConfigProposalSet(context, event);
          break;
        case 'YieldSourceOracleConfigAccepted':
          await yieldSourceOracleConfigAccepted(context, event);
          break;
        case 'ManagerRoleTransferStarted':
          await managerRoleTransferStarted(context, event);
          break;
        case 'ManagerRoleTransferAccepted':
          await managerRoleTransferAccepted(context, event);
          break;
        case 'YieldSourceOracleConfigProposalCancelled':
          await yieldSourceOracleConfigProposalCancelled(context, event);
          break;
        default:
          console.log(`No handler for event: ${eventName}`);
          continue;
      }
      
      eventsProcessed++;
      
    } catch (error) {
      console.error(`Error processing event: ${error}`);
    }
  }
  
  console.log(`Successfully processed ${eventsProcessed} SuperLedgerConfiguration events`);
  console.log('=== SuperLedgerConfiguration Event Monitor Completed ===');
};

// Export individual handlers for testing
export {
  yieldSourceOracleConfigSet,
  yieldSourceOracleConfigProposalSet,
  yieldSourceOracleConfigAccepted,
  managerRoleTransferStarted,
  managerRoleTransferAccepted,
  yieldSourceOracleConfigProposalCancelled
};