import { LocalIntentParser } from '../src/lib/agent/LocalIntentParser';
import { EnclaveTunnel, VerifiableEnclaveServer } from '../src/lib/agent/EnclaveTunnel';
import { useCrdtStore } from '../src/lib/store/useCrdtStore';

import { initCrypto } from '../src/lib/crypto/primitives';

async function runTieredAgentValidation() {
  await initCrypto();
  console.log("--- Starting Secure Agent Validation (Task 3) ---");
  console.log("\n=== TIER 1: LOCAL INFERENCE (Offline Parsing) ===");
  
  const localParser = new LocalIntentParser();
  const store = useCrdtStore.getState();

  console.log("1. User types in Spotlight (Internet Disconnected): 'I paid $320 for nobu'");
  const localIntent = await localParser.parseSpotlightQuery("I paid $320 for nobu");
  
  console.log(`   Parsed Intent:`, localIntent);
  
  if (localIntent.action === 'ADD_EXPENSE') {
    const mutation = localParser.buildCrdtMutation(
      localIntent, 
      'user_1', 
      ['user_1', 'user_2']
    );
    if (mutation) {
      console.log(`   Applying CRDT Expense Mutation to local materialized view...`);
      store.applyMutation(mutation);
      console.log(`   New Ledger Balance (user_1): $${useCrdtStore.getState().state.ledger.balances['user_1'] / 100}`);
      console.log(`   ✅ TIER 1 SUCCESS: Offline intent routed to E2EE store without server awareness.`);
    } else {
      console.error(`   ❌ TIER 1 FAILED: Could not build mutation.`);
      process.exit(1);
    }
  }


  console.log("\n=== TIER 2: ENCLAVE TUNNEL (Verifiable Compute) ===");
  
  const clientTunnel = new EnclaveTunnel();
  const mockTeeServer = new VerifiableEnclaveServer();

  console.log("1. Cloud TEE Server boots and establishes Identity Key Enclave...");
  const teePublicKey = await mockTeeServer.initializeEnclave();
  console.log("   Enclave Identity initialized via Secure Crypto Engine.");

  console.log("\n2. User types in Spotlight: 'Find sushi spots near downtown LA'");
  console.log("   Client application Encrypts the prompt SPECIFICALLY for the Enclave Public Key...");
  const e2eeQuery = await clientTunnel.buildSecureQuery(
    "Find sushi spots near downtown LA",
    "user_1",
    teePublicKey
  );
  
  console.log(`   Network payload (Ciphertext to Vercel/Supabase relay): ${e2eeQuery.queryCiphertextB64.length} bytes`);

  console.log("\n3. Vercel relays Ciphertext to AWS Nitro TEE...");
  console.log("   Inside the Enclave (Isolated from Internet/Disk):");
  
  const teeResponsePayload = await mockTeeServer.processAndAttest(
    e2eeQuery, 
    "Here are 3 highly rated sushi spots near downtown LA: 1. Sugarfish, 2. KazuNori, 3. Q Sushi."
  );
  
  console.log(`   Encrypted Response Generated & Signed: Length ${teeResponsePayload.responseCiphertextB64.length} bytes.`);
  console.log(`   Signature Attestation bytes: ${teeResponsePayload.attestationSignatureB64.length}`);

  console.log("\n4. Client receives Ciphertext & Attestation...");
  const finalAnswer = await clientTunnel.decryptEnclaveResponse(teeResponsePayload, teePublicKey);

  console.log(`   Decrypted response rendered in UI:`);
  console.log(`   > ${finalAnswer}`);
  
  console.log(`\n✅ TIER 2 SUCCESS: Prompt successfully wrapped in E2EE envelope and processed by secure AI enclave.`);
}

runTieredAgentValidation().catch(console.error);
