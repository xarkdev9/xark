export interface PresenceState {
  userId: string;
  status: 'online' | 'away' | 'offline';
  lastSeenAt?: string;
}

export type RealtimeEvent =
  | { type: 'message'; payload: any }
  | { type: 'presence'; payload: PresenceState }
  | { type: 'typing'; payload: { userId: string } }
  | { type: 'sk_recovery'; payload: { groupId: string; senderId: string } };

export interface Subscription {
  id: string;
  groupId: string;
  unsubscribe(): void;
}

export interface RealtimeGateway {
  subscribe(groupId: string, handler: (event: RealtimeEvent) => void): Subscription;
  unsubscribe(subscription: Subscription): void;
  publishPresence(groupId: string, userId: string, state: PresenceState): void;
  publishTyping(groupId: string, userId: string): void;
}
