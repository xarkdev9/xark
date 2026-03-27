import { ICryptoProvider, CryptoProviderFactory, KeyPair } from './CryptoProvider';

export interface CryptographicTombstone {
  kickedUserId: string;
  tombstonedDeviceIds: string[];
  issuedAt: string;
  signature: ArrayBuffer; // Signed by an Admin of the group proving authorization
}

export interface GroupRosterState {
  activeMembers: Record<string, string[]>; // userId -> active deviceIds
  tombstones: CryptographicTombstone[];
}

export interface EncryptedMessagePayload {
  senderId: string;
  senderDeviceId: string;
  ciphertext: ArrayBuffer;
  senderKeyId: string; // ID of the Sender Key used for encryption
}

/**
 * Handles "Lazy" Asynchronous Sender Key (SK) Rotation using Tombstones.
 * Fixes the race condition of offline members not knowing someone was kicked.
 */
export class LazyRotator {
  private provider: ICryptoProvider;

  // The ID of the Sender Key this client is currently using to encrypt outbound traffic
  public currentActiveSenderKeyId: string = "sk_active_100"; 

  // The devices this client believes possess its currentActiveSenderKeyId
  private knownDistributedDevices: Set<string> = new Set(['dev_B', 'dev_C']);

  constructor() {
    this.provider = CryptoProviderFactory.getProvider();
  }

  /**
   * Called by a Group Admin to kick a member when offline devices might exist.
   */
  async issueTombstone(
    adminPrivateKey: CryptoKey, 
    kickedUserId: string, 
    deviceIds: string[]
  ): Promise<CryptographicTombstone> {
    
    const payloadStr = `${kickedUserId}:${deviceIds.join(',')}:${new Date().toISOString()}`;
    const data = new TextEncoder().encode(payloadStr).buffer;
    
    const signature = await this.provider.sign(adminPrivateKey, data);

    return {
      kickedUserId,
      tombstonedDeviceIds: deviceIds,
      issuedAt: new Date().toISOString(),
      signature
    };
  }

  /**
   * INGRESS MIDDLEWARE: Called immediately before encrypting any message.
   * Checks if the current Sender Key is compromised by resting on a tombstoned device.
   */
  async secureSend(
    messageText: string, 
    roster: GroupRosterState
  ): Promise<{
    payload: EncryptedMessagePayload,
    distributedNewKey?: boolean
  }> {
    
    let distributedNewKey = false;

    // 1. Check if our current SK is distributed to any tombstoned device
    const tombstonedSet = new Set(
      roster.tombstones.flatMap(t => t.tombstonedDeviceIds)
    );

    const isCurrentKeyCompromised = Array.from(this.knownDistributedDevices)
      .some(deviceId => tombstonedSet.has(deviceId));

    if (isCurrentKeyCompromised) {
      console.warn("[LazyRotator] 🛑 Aborting send! Current Sender Key is on a tombstoned device.");
      await this.rotateSenderKey(roster, tombstonedSet);
      distributedNewKey = true;
    }

    // 2. Encrypt the message with the safe key
    console.log(`[LazyRotator] Encrypting message with Sender Key: ${this.currentActiveSenderKeyId}`);
    const ciphertext = new TextEncoder().encode(`Encrypted(${messageText})`).buffer;

    return {
      payload: {
        senderId: 'user_A',
        senderDeviceId: 'dev_A',
        ciphertext,
        senderKeyId: this.currentActiveSenderKeyId
      },
      distributedNewKey
    };
  }

  /**
   * Generates a new SK and distributes it exclusively to NON-tombstoned active devices.
   */
  private async rotateSenderKey(roster: GroupRosterState, tombstonedSet: Set<string>): Promise<void> {
    
    console.log("[LazyRotator] 🔄 Generating new Sender Key...");
    this.currentActiveSenderKeyId = `sk_new_${crypto.randomUUID().split('-')[0]}`;
    
    // Clear out old distribution tracking
    this.knownDistributedDevices.clear();

    const safeDevicesToDistributeTo = Object.values(roster.activeMembers)
      .flat()
      .filter(deviceId => !tombstonedSet.has(deviceId));

    console.log(`[LazyRotator] Distributing new key to safe devices ONLY: [${safeDevicesToDistributeTo.join(', ')}]`);
    
    for (const device of safeDevicesToDistributeTo) {
      this.knownDistributedDevices.add(device);
      // Real implementation encrypts the new SK to each recipient's Identity Key here
    }
  }
}
