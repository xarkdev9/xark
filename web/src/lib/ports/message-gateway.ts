export type SyncDirection = 'forward' | 'backward';

export interface MessageEnvelope {
  messageId: string;
  groupId: string;
  senderId: string;
  senderDeviceId: number;
  messageType: string;
  ciphertexts: Array<{
    recipientId: string;
    recipientDeviceId: number;
    ciphertext: string;
    ratchetHeader?: string;
  }>;
  distributions?: Array<{
    recipientId: string;
    recipientDeviceId: number;
    ciphertext: string;
    ratchetHeader?: string;
  }>;
  sk_acks?: Array<{ group_id: string; sender_id: string }>;
}

export interface SendResult {
  messageId: string;
  serverSeq: number;
  createdAt: string;
  status: 'inserted' | 'deduplicated';
}

export interface MessageRecord {
  id: string;
  groupId: string;
  senderId: string;
  senderDeviceId: number;
  messageType: string;
  serverSeq: number;
  createdAt: string;
}

export interface MessagePage {
  messages: MessageRecord[];
  nextCursor: string | null;
}

export interface Ciphertext {
  recipientId: string;
  recipientDeviceId: number;
  ciphertext: string;
  ratchetHeader?: string;
}

export interface MessageGateway {
  sendMessage(envelope: MessageEnvelope): Promise<SendResult>;
  fetchMessages(groupId: string, cursor: string | null, direction: SyncDirection, limit?: number): Promise<MessagePage>;
  fetchCiphertexts(messageId: string, recipientId: string, deviceId: number): Promise<Ciphertext[]>;
  acknowledgeDelivery(messageId: string, deviceId: number): Promise<void>;
}
