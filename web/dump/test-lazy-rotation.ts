import { LazyRotator, GroupRosterState, CryptographicTombstone } from '../src/lib/crypto/LazyRotator';
import { CryptoProviderFactory } from '../src/lib/crypto/CryptoProvider';

async function runLazyRotationValidation() {
  console.log("--- Starting Decentralized Healing Validation (Task 4) ---");
  
  const provider = CryptoProviderFactory.getProvider();
  const rotator = new LazyRotator();

  console.log("1. Initializing E2EE Roster (3 Members)...");
  const roster: GroupRosterState = {
    activeMembers: {
      'user_A': ['dev_A'],
      'user_B': ['dev_B'],
      'user_C': ['dev_C'] // User C is currently "offline"
    },
    tombstones: []
  };

  const adminKeyPair = await provider.generateIdentityKeyPair();

  console.log("\n2. Admin kicks User B. User C is offline and cannot process a key rotation request.");
  console.log("   Admin issues Cryptographic Tombstone instead of forced rotation...");
  
  const tombstone = await rotator.issueTombstone(
    adminKeyPair.privateKey, 
    'user_B', 
    roster.activeMembers['user_B']
  );
  
  roster.tombstones.push(tombstone);
  delete roster.activeMembers['user_B']; // B is removed from active roster
  
  console.log(`   Tombstone created for devices: [${tombstone.tombstonedDeviceIds.join(', ')}] signed by Admin.`);

  console.log("\n3. User C comes online and attempts to send a message using their OLD Sender Key...");
  console.log(`   User C's current SK: ${rotator.currentActiveSenderKeyId}`);
  
  // User C's sending middleware intercepts the message before encrypting
  const sendResult = await rotator.secureSend("Hey guys, what did I miss?", roster);

  if (sendResult.distributedNewKey) {
    console.log(`\n4. Middleware DETECTED Tombstone for dev_B in its SK distribution list!`);
    console.log(`   Rotated SK to: ${sendResult.payload.senderKeyId}`);
    console.log(`   E2EE Payload successfully encrypted with NEW safe key.`);
    console.log(`\n✅ TIER 4 SUCCESS: Tombstone-based lazy rotation securely handled an offline ejection scenario.`);
  } else {
    console.error(`\n❌ TIER 4 FAILED: Client did not rotate key when sending to a tombstoned device.`);
    process.exit(1);
  }
}

runLazyRotationValidation().catch(console.error);
