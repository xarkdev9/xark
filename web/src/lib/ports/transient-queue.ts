export interface EncryptedPayload {
  ciphertext: string;
  ratchetHeader?: string;
}

export interface QueuedMessage {
  messageId: string;
  payload: EncryptedPayload;
  enqueuedAt: number;
}

export interface TransientQueue {
  enqueue(recipientDeviceId: string, payload: EncryptedPayload): Promise<void>;
  dequeue(deviceId: string, limit?: number): Promise<QueuedMessage[]>;
  acknowledge(deviceId: string, messageIds: string[]): Promise<void>;
  getQueueDepth(deviceId: string): Promise<number>;
}
