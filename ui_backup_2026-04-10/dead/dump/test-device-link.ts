import { CryptoProviderFactory } from '../src/lib/crypto/CryptoProvider';
import { DeviceLinker, DeviceLinkRequest, DeviceLinkPayload } from '../src/lib/crypto/DeviceLinker';

import { initCrypto } from '../src/lib/crypto/primitives';

async function runDeviceLinkingValidation() {
  await initCrypto();
  console.log("--- Starting Device Linking Validation (Task 1.2) ---");

  const provider = CryptoProviderFactory.getProvider();
  const linker = new DeviceLinker();

  // 1. Native Device Initialization
  console.log("1. Initializing Native Primary Device (Secure Enclave)...");
  const primaryKeyPair = await provider.generateIdentityKeyPair();
  console.log("   Primary Identity Keypair generated.");

  // 2. Web App (Secondary) Initialization
  console.log("2. Initializing Web Browser PWA...");
  const webEphemeralKeyPair = await provider.generateIdentityKeyPair();
  console.log("   Web Ephemeral Identity Keypair generated.");

  // 3. Web App generates Link Request (QR Code Payload)
  console.log("3. Web App generating Link Request (QR Payload)...");
  const linkRequest = await linker.createLinkRequest(webEphemeralKeyPair);
  console.log(`   Link Request generated. Public Key string length: ${linkRequest.linkingPublicKeyB64.length}`);

  // 4. Native Device scans QR and signs the Web App's key
  console.log("4. Native Device approving Link Request...");
  const approvedPayload = await linker.approveLinkRequest(primaryKeyPair, linkRequest);
  console.log(`   Approved Payload generated.`);
  console.log(`   DeviceId: ${approvedPayload.deviceId}`);
  console.log(`   Signature string length: ${approvedPayload.signatureB64.length}`);

  // 5. Verification Phase (What Supabase or the network would do)
  console.log("5. Verifying Signature and Linkage...");
  // We need the primary's public key to verify
  const primaryPublicKeyRaw = await provider.exportPublicKey(primaryKeyPair.publicKey);
  
  // Re-importing just for the sake of the test isolation (simulating what a server would do if it holds public keys)
  const { fromBase64 } = await import('../src/lib/crypto/primitives');
  const isVerified = await provider.verify(
    primaryKeyPair.publicKey, 
    fromBase64(approvedPayload.signatureB64).buffer as ArrayBuffer, 
    fromBase64(approvedPayload.signedPublicKeyB64).buffer as ArrayBuffer
  );

  if (isVerified) {
    console.log("✅ Validation SUCCESS: Web Device is cryptographically linked to Primary Native Device.");
  } else {
    console.error("❌ Validation FAILED: Cryptographic signature verification rejected the linkage.");
    process.exit(1);
  }
}

// In a real TS environment we'd execute this directly, but since we are just scaffolding 
// the logic for the V2 architecture PR, we will build it.
runDeviceLinkingValidation().catch(console.error);
