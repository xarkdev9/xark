Category 1: The New Screens (Blank Canvases)
These are entirely new widgets and views that need to be architected from scratch, strictly adhering to our Zero-Box and No-Bold doctrines.

1. The Settings & Identity Suite

settings_page.dart: The root configuration spatial list.

profile_edit.dart: A screen to update the user's display name and edge-to-edge profile photo.

device_list.dart: A UI to view the 5-device limit registry and a swipe-to-unlink (revoke) mechanism.

2. The Missing Home Tabs

groups_tab_view.dart: Plugs into the second slot of our HomeLayout. Similar to the Chats tab, but filters the engine stream strictly for ConversationType.group.

memories_tab_view.dart: Plugs into the third slot. A high-performance, masonry-style grid rendering settled E2EE media using FileImage to prevent memory leaks.

3. The @hello AI Interface

spotlight_sheet.dart: A fluid, bottom-up modal sheet to display the SSE (Server-Sent Events) streaming responses from the AI.

ghost_input.dart: The specialized text input for querying the AI without sending data to the E2EE outbox.

4. The Social Growth Flow

invite_surface.dart: A visually stunning QR code and link generator for adding people to groups.

claim_sheet.dart: The interceptor UI that pops up when a user scans an invite link to join a new space.

Category 2: Core Chat Upgrades (Wiring the Engine Hooks)
These screens already exist, but we need to upgrade them with the newly unlocked Phase 2 engine streams.

1. The ChatView Micro-Interactions

Delivery Receipts: Upgrading the message bubbles to reflect session.receipts (sending, sent, delivered, read) using subtle, Zero-Box iconography.

Typing Indicators: A transient "typing..." animation block that appears just above the @hello composer when session.typing emits data.

Presence (1:1 Only): Wiring session.presence to smoothly fade in "Online" or "Last seen at..." directly under the App Bar title.

Pagination: Wiring a scroll controller to trigger session.loadMore(limit: 50) when the user hits the top of the reverse: true list.

2. The Media Pipeline UI

Upload/Download Progress: Wiring the EncryptedImageView to listen to the engine's background upload/download streams, rendering a sleek, borderless radial progress indicator over the blurred inlineThumbnail before the cross-fade finishes.

3. Global State Banners

Connection State: A beautifully animated, unobtrusive banner at the top of the Home screen that slides down only when engine.connectionState is disconnected or connecting.

Category 3: The Native Gateways (The Heavy Lifting)
This is where Flutter meets the bare metal of iOS and Android.

1. The Biometric App Lock (locked_app.dart)

We need to build a completely separate, isolated UI (a pristine PIN pad or FaceID prompt) that intercepts the main.dart boot sequence. If this fails, the main Flutter app tree never even mounts.

2. Push Notification Decryption Bridging

This isn't purely UI, but the frontend team must write the native Swift (iOS NotificationServiceExtension) and Kotlin (Android FirebaseMessagingService) bridges that wake up the headless Dart isolate to decrypt background messages before displaying the OS notification.