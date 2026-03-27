# Xark OS — Antigravity v2 Architecture Plan

**Objective**: Deliver WhatsApp-scale end-to-end encryption (E2EE) security and speed across multiple devices, while seamlessly integrating `@xark` as a highly capable AI agent.

This document serves as the architectural blueprint to remediate the vulnerabilities in the v1 to v2 migration plan, establishing a cryptographic bedrock that mirrors Signal and WhatsApp while innovating in agent-driven E2EE environments.

---

## 1. THE CRYPTOGRAPHIC BEDROCK (Fixing the PWA Fallacy)

To achieve WhatsApp-scale security, the browser cannot be the sole anchor of trust. WebCrypto `extractable: false` in a Next.js PWA is insufficient due to browser storage purging (IndexedDB) and the inability to verify the JavaScript bundle at runtime.

### 1.1 The Primary Device Anchor
* **Architecture**: A lightweight Native App (iOS/Android/Electron) or a locally installed wrapper (tauri/React Native) serves as the persistent vault.
* **Key Storage**: Identity Keys are stored in the OS-level Secure Enclave (Keychain/Keystore), rendering them immune to browser cache purges.
* **Web Client Integration**: The PWA becomes a *linked device*, identical to "WhatsApp Web". It communicates with the Supabase backend via a session established and cryptographically signed by the Primary Device.
* **Code Verification**: If remaining purely web-based, we must implement Service Worker integrity checks and publish a "Code Verify" style browser extension to guarantee the JS bundle hasn't been altered by the CDN.

### 1.2 Multi-Device Synchronization (The WhatsApp Model)
* **Identity Key Signatures**: When a user links a new device (e.g., desktop browser) via QR code, the Primary Device does not send its Identity Key. Instead, it signs the new device's uniquely generated Identity Key.
* **Device specific keys**: E2EE messages are encrypted for *every active device* of a recipient, not just their user ID.
* **Result**: Browser cache clears no longer equal account loss. The user just re-links their browser.

---

## 2. THE METADATA VAULT (Fixing Layer 3 Overexposure)

The previous v2 plan leaked all semantic value (decisions, ledgers, itineraries) to Supabase in plaintext. To achieve WhatsApp-grade security, the metadata must be as secure as the chat.

### 2.1 Encrypted State Synchronization (E2EE CRDTs)
* **The Mechanism**: Settlement ledgers, upvotes, and decision cards do not exist as plaintext rows in Supabase. They are transmitted as E2EE payloads (just like messages) containing state updates (e.g., `{"action": "vote", "target": "nobu", "val": 1}`).
* **Local Materialization**: The client receives these E2EE packets, decrypts them, and materializes the local state (the Ledger UI, the Decide Tab) purely on the device.
* **Supabase Role**: Supabase remains an ignorant relay. It holds ciphertext blobs representing state mutations, knowing nothing about who owes what to whom.

### 2.2 Blinded Guest Mode (Zero-Knowledge Consensus)
* **The Vulnerability**: Allowing unauthenticated URLs to influence E2EE group state is a cryptographic contamination.
* **The Solution**: When an E2EE member shares a public invite link, they generate an ephemeral keypair for that link. When a guest votes, the vote is encrypted to the ephemeral key. The E2EE member's device (which holds the private ephemeral key) decrypts the guest's vote, permanently cryptographically signs it into the group's active state, and broadcasts the state update. The Guest never sees the plaintext state of other members, and E2EE integrity is maintained.

---

## 3. THE `@xark` AGENT INTEGRATION (Secure AI)

How do we integrate an AI agent into an environment where the server cannot read the messages? The AI must become a cryptographic participant.

### 3.1 The Agent as a Device (Permissioned Sub-Client)
* **The Concept**: `@xark` is not a server-side interceptor. It is treated as an automated "Device" that is explicitly invited into a Space by a user.
* **Key Exchange**: When a user invokes `@xark`, their client generates an ephemeral session key and establishes a secure tunnel directly with the API enclave running the LLM (Gemini).
* **Verifiable Compute Enclave**: The `@xark` agent runs inside a Trusted Execution Environment (TEE) like AWS Nitro Enclaves. The enclave provides a cryptographic attestation that it is running the exact, audited open-source agent code.
* **The Flow**:
  1. User types command in Spotlight.
  2. Client encrypts the query specifically for the TEE public key.
  3. Payload hits `/api/xark`.
  4. The TEE decrypts, processes via Gemini, encrypts the result with the group's Sender Key, and obliterates its memory.
  5. The ciphertext is relayed to Supabase just like a human message.

### 3.2 Tier 1: Local-First Agent Execution
* For simple parsing ("I paid $320 for nobu") or local state summarization, `@xark` runs *entirely in the browser* using WebGL-accelerated small LLMs (e.g., Llama-3-8B via WebGPU or local ONNX execution).
* Zero data leaves the device. Complete privacy, zero latency.

---

## 4. ASYNCHRONOUS E2EE RELIABILITY

### 4.1 Lazy Sender Key (SK) Rotation
* **The Issue**: "Enforced SK rotation" fails when members are offline.
* **The WhatsApp Fix**: We implement a "Tombstone" model. When Alice is removed, the server issues a tombstone for her device. 
* Any member sending a message sees the tombstone, immediately generates a new Sender Key, and distributes it *only to the remaining active members*.
* If Charlie comes online later, Supabase rejects his message encrypted with the old SK. Charlie's client automatically fetches the new device list, rotates his own SK, distributes it, and re-transmits. State heals asynchronously.

### 4.2 Signal Protocol Parameter Tuning
* **Pre-Keys**: Increase the pre-key upload batch size to 100 to prevent Key Exhaustion attacks.
* **Message Padding**: Pad all ciphertexts to standard block sizes (e.g., 256 bytes, 512 bytes) to obscure the length of `@xark` queries and ledger updates from traffic analysis.

---

## 5. REVISED v2 EXECUTION ROADMAP

### Phase 1: Native Anchoring & Multi-Device Prep
* Wrap the Next.js PWA in a lightweight Capacitor/React Native shell for iOS/Android to access securely isolated Keychains.
* Implement X3DH with support for linked-device signature verification.

### Phase 2: Encrypted State (The Metadata Vault)
* Refactor the Decisions and Settlement database tables to handle serialized ciphertext CRDT bundles.
* Move all "Spotlight" and "Ledger" calculations to client-side logic.

### Phase 3: The TEE Agent
* Deploy `@xark` in a Verifiable Compute Enclave.
* Client validates enclave attestation before transmitting any prompts/context.
* Implement local WebGPU parsing for offline/instant `@xark` commands.

### Phase 4: Decentralized Healing
* Implement Tombstone-based SK rotation.
* Add ciphertext padding and rate-limiting at the Supabase ingress layer.
