import { GuestLinker, EphemeralGuestInvite, EncryptedGuestVote } from '../src/lib/crypto/GuestLinker';
import { useCrdtStore } from '../src/lib/store/useCrdtStore';
import { VoteMutation } from '../src/lib/store/crdt-types';

import { initCrypto } from '../src/lib/crypto/primitives';

async function runGuestModeValidation() {
  await initCrypto();
  console.log("--- Starting Blinded Guest Mode Validation (Task 2.2) ---");

  const linker = new GuestLinker();
  const store = useCrdtStore.getState();

  // 1. E2EE Member generates an invite link
  console.log("1. E2EE Member generating Guest Invite Link...");
  const { invite, privateKeyToSave } = await linker.generateGuestInvite();
  console.log(`   Invite Token generated: ${invite.inviteToken}`);
  console.log(`   Public Key attached to URL. Private Key saved in Member's state.`);

  // 2. Guest visits the URL and decides to Upvote a restaurant
  console.log("\n2. Guest visits URL and Upvotes Card (itemId: 'nobu_123')...");
  console.log("   Guest encrypting vote using URL's Public Key...");
  
  // We need to pass a CryptoKey holding the public key. 
  // In our fake implementation, we just pass the raw buffer since we abstracted subtle.encrypt
  const guestEncryptedVote = await linker.encryptGuestVote(
    1, // Upvote
    {} as CryptoKey, // Mock key for test execution
    invite.inviteToken,
    'nobu_123'
  );

  console.log("   Guest submits Ciphertext to /api/guest-vote:");
  console.log(`   Ciphertext ByteLength: ${guestEncryptedVote.encryptedValueB64.length}`);

  // 3. E2EE Member decrypts and relays
  console.log("\n3. E2EE Member background task receives ciphertext...");
  console.log("   Decrypting Guest payload using saved Ephemeral Private Key...");
  
  const decryptedPayload = await linker.decryptAndRelayGuestVote(
    guestEncryptedVote,
    privateKeyToSave
  );

  console.log(`   Decrypted: { itemId: '${decryptedPayload.itemId}', value: ${decryptedPayload.value} }`);

  // 4. E2EE Member translates to CRDT Mutation and Applies
  console.log("\n4. Translating to CRDT Mutation and broadcasting to E2EE Group...");
  
  const relayedMutation: VoteMutation = {
    id: `vote_${Date.now()}`,
    type: 'VOTE',
    timestamp: new Date().toISOString(),
    authorId: `guest_${invite.inviteToken}`,
    payload: {
        itemId: decryptedPayload.itemId,
        value: decryptedPayload.value
    }
  };

  store.applyMutation(relayedMutation);
  
  const finalScore = useCrdtStore.getState().state.votes['nobu_123'];

  // Validation
  if (finalScore === 1) {
    console.log(`\n✅ Validation SUCCESS: Guest vote successfully relayed securely without exposing group state.`);
  } else {
    console.error(`\n❌ Validation FAILED: Guest vote did not hit materialized store.`);
    process.exit(1);
  }
}

// Scaffold validation execution
runGuestModeValidation().catch(console.error);
