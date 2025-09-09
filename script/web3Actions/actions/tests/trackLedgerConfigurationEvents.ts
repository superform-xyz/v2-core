import * as TActions from '@tenderly/actions-test';
import { trackLedgerConfigurationEvents } from '../src/index';
import SuperLedgerConfigurationPayload from './fixtures/superLedgerConfigurationYieldSourceOracleConfigSet.json';

/**
 * Test SuperLedgerConfiguration Event Monitoring
 * 
 * This test uses real Ethereum transaction data from block 23318032
 * which contains 4 YieldSourceOracleConfigSet events for different oracle types:
 * - ERC4626YieldSourceOracle
 * - ERC7540YieldSourceOracle  
 * - ERC5115YieldSourceOracle
 * - StakingYieldSourceOracle
 */
export const main = async () => {
  console.log('=== Testing SuperLedgerConfiguration Event Monitor ===');
  
  const runtime = new TActions.TestRuntime();

  // Cast the fixture to the expected event type
  const txEvent = SuperLedgerConfigurationPayload as TActions.TestTransactionEvent;

  console.log(`Testing transaction: ${txEvent.hash}`);
  console.log(`Block: ${txEvent.blockNumber}`);
  console.log(`From: ${txEvent.from} (Fireblocks sender)`);
  console.log(`To: ${txEvent.to} (SuperLedgerConfiguration)`);
  console.log(`Event logs: ${txEvent.logs.length}`);
  
  // Log event details for verification
  txEvent.logs.forEach((log, index) => {
    console.log(`Event ${index + 1}:`);
    console.log(`  - Address: ${log.address}`);
    console.log(`  - Event signature: ${log.topics[0]}`);
    console.log(`  - Oracle ID: ${log.topics[1]}`);
    console.log(`  - Oracle address: ${log.topics[2]}`);
  });

  try {
    // Execute the Web3 Action function
    console.log('\n--- Executing trackLedgerConfigurationEvents ---');
    await runtime.execute(trackLedgerConfigurationEvents, txEvent);
    console.log('✅ Test completed successfully!');
  } catch (error) {
    console.error('❌ Test failed:', error);
    throw error;
  }
};

// Run the test
(async () => {
  try {
    await main();
  } catch (error) {
    console.error('Test execution failed:', error);
    process.exit(1);
  }
})();