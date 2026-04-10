# Feature Parity with WhatsApp

Target feature set. Architect for all from day one, even if not all ship in Phase 1.

**Engine** = this repo (`chat_engine`). **UI** = `~/chatF/`. The engine owns protocol, crypto, sync, and data. The UI owns rendering, interaction, and display.

## Messaging

| Feature | Engine (this repo) | UI (`~/chatF/`) |
|---|---|---|
| 1:1 encrypted messaging | Encrypt, send, receive, decrypt, store | Render message bubbles |
| Group chats (up to 1024) | Sender Key distribution, fan-out, sync | Group list, member UI |
| Delivered / Read receipts | Track receipt events, emit on stream | Double-tick display |
| Typing indicators | Send/receive ephemeral typing events | "typing..." label |
| Message reactions | Store/sync reaction events per message | Emoji picker, reaction bubbles |
| Reply-to / quote | Store `replyToMessageId` in payload | Render quoted bubble |
| Delete for me / everyone | Mark deleted, broadcast delete event | Remove from view, "deleted" placeholder |
| Message forwarding | Re-encrypt for new recipient | Forward action sheet |
| Starred messages | Persist starred flag per message | Starred messages view |
| Message search | Query decrypted content in local DB | Search bar, results list |

## Media

| Feature | Engine (this repo) | UI (`~/chatF/`) |
|---|---|---|
| Image send/receive | Compress, AES-GCM encrypt, upload blob, send key via ratchet | Image display, zoom, gallery |
| Video send/receive | Compress, encrypt, upload, stream key | Video player, streaming playback |
| Voice messages | Record PCM, encode Opus, encrypt, upload | Waveform display, playback speed |
| Document / file sharing | Encrypt, upload, metadata in ratchet message | File icon, download progress |
| View-once media | Set `viewOnce` flag, delete after first decrypt | "Tap to view" UI, block screenshot |
| Media gallery | Index all media per conversation in DB | Gallery grid view |

## Presence & Sync

| Feature | Engine (this repo) | UI (`~/chatF/`) |
|---|---|---|
| Online / Last seen | Track presence events, emit on stream | Status text under name |
| Push notifications | Platform-native decrypt (NSE/Service) | Notification tap routing |
| Background sync | Reconnect, drain queue on resume | None (transparent) |
| Conversation pin/archive/mute | Persist flags, emit on conversation stream | Pin/archive/mute toggles |
| Unread count | Track per-conversation + total, emit on stream | Badge count display |
| Link previews | Fetch via server-side proxy, include in payload | Render preview card |
| Disappearing messages | Auto-delete after timer expires, sync deletion | Timer selector, countdown badge |

## Security UX

| Feature | Engine (this repo) | UI (`~/chatF/`) |
|---|---|---|
| Safety number verification | Generate key fingerprint bytes | QR code scanner, numeric display |
| E2EE notice | Expose `isEncrypted` flag on session | Banner / lock icon |
| Sealed sender | Hide sender identity in transport envelope | None (transparent) |
| Screen security | None (platform-level) | Block screenshots in sensitive views |
| App lock (PIN / biometric) | Require unlock before DB open | PIN entry screen, biometric prompt |

## Advanced Social Constructs

| Feature | Engine (this repo) | UI (`~/chatF/`) |
|---|---|---|
| **Semantic Echo (Plan Resurrection)** | Search local DB for semantic group planning intents; yield JSON blueprint | Detect intent, render translucent "Echo Card" inline |
| **Z-Axis Time-Scrub** | Provide localized milestones / settled DecisionItem hashes via chronological query | Render iOS-Photos style vertical haptic scrubber; fade chat background to 10% opacity; float cinematic "Decision Milestone" cards centrally |
| **Plan Forking (GitHub for Social)** | Clone `DecisionItem` tree, strip votes, retain constraints & options | "Fork" swipe action on past plans; animates cloned widget into bottom of active chat stream |
