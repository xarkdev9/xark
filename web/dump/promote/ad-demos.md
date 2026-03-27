# Xark OS — Ad Demo Simulations

## Routes

| Route | Scene | Purpose |
|---|---|---|
| `/demo` | Dinner tonight (sushi) | 3 restaurant cards, single-rail |
| `/demo/travel` | Tokyo April 2026 | 3 Netflix rails: flights, hotels, rental cars |
| `/prototype` | Component lab | 10 interactive UI component prototypes |

## Recording Flow (same for both demos)

1. Open the demo route — pre-seeded chat history with 4 friends
2. Type `@xark dinner tonight` or `@xark plan tokyo trip` → send
3. Action Orange shimmer "thinking..." (1.5s)
4. @xark responds "found 3 spots nearby" / "found flights, hotels, and cars for tokyo"
5. Auto-switches to Decide tab (800ms)
6. Cards appear at score 0
7. Friends vote in real-time cascade:
   - +800ms: first friend votes → score 5
   - +1400ms: second friend votes → score 10
   - +2000ms: third friend votes → score 14 (85%)
8. User taps "love it" on the top item
9. Score jumps to 19, consensus 100% → GOLD BURST (3s radial gold bloom)

## 8-Second Blitz Edit (Video Production)

### Structure
```
[0:00-0:02] The Hook — Cinematic human shot (woman smiling at phone in dim sushi restaurant)
[0:02-0:06] The UI Blitz — Screen recording at 800% speed ramp
[0:05.5]    The Freeze — Drop to 100% speed on gold burst (half second)
[0:06-0:08] The Payoff — Friends clinking glasses, bassline peaks
```

### Speed Ramp Details
- Record at normal speed (the full flow takes ~8-10 seconds real-time)
- In CapCut/Premiere: speed ramp to 800% for the UI portion
- Freeze frame at 100% when gold burst triggers
- Hard cut to real-world celebration shot

### What the Viewer Sees at 800%
- Hyper-fast blur of typing "@xark dinner tonight"
- Cyan/orange intelligence pulse (shimmer)
- Restaurant/hotel/flight cards dealing in
- Scores climbing as friends vote
- FREEZE: Gold burst at 100% consensus (the win moment)

## Demo Scenes

### Dinner Tonight (`/demo`)
- **Space title**: dinner tonight
- **Friends**: ava, kai, zoe, leo
- **Chat history**: natural sushi conversation (5 messages)
- **@xark query**: "@xark dinner tonight"
- **Cards**: 3 sushi restaurants (nakazawa, omakase room, blue ribbon)
- **Consensus item**: sushi nakazawa

### Tokyo Travel (`/demo/travel`)
- **Space title**: tokyo april 2026
- **Friends**: kai, ava, leo, zoe
- **Chat history**: trip planning conversation (5 messages)
- **@xark query**: "@xark plan tokyo trip"
- **Rails**:
  - "flights to tokyo" — united sfo→nrt ($890), ana sfo→hnd ($1,240), japan airlines lax→nrt ($980)
  - "hotels in tokyo" — park hyatt ($650/nt), andaz ($420/nt), hoshinoya ($380/nt)
  - "rental cars" — toyota camry ($45/day), honda fit ($30/day)
- **Consensus item**: park hyatt tokyo

## Component Prototypes (`/prototype`)

Standalone showcase of 10 candidate UI components evaluated for Xark:

1. Contact Globe — 3D sphere with avatar nodes (Fibonacci distribution, drag + momentum)
2. Text Scramble — character-by-character message reveal
3. Shimmer Text — cyan sweep loading state
4. Typewriter — character-by-character placeholder cycling
5. Slide to Confirm — drag thumb to commit purchase
6. Feedback Reactions — love/okay/pass with spring animations
7. Animated Avatar Tooltips — spring-bounced name tooltips on hover
8. Member Selector — searchable people picker with avatar chips
9. Quick Tooltip Actions — hover avatar for chat/profile/mute
10. Fluid Menu — circular expanding menu

### Approved for Integration
- **Shimmer Text** → @xark "thinking..." state (Action Orange sweep) ✓ shipped
- **Typewriter** → ChatInput placeholder cycling @xark command examples ✓ shipped

## UI Confidence Fixes (shipped)

Raised contrast across the entire chat UI:
- Message text opacity: 0.55 floor → foveal system (0.78-0.95)
- Timestamps: 0.2 → 0.38
- Sender names: removed opacity reduction, full color
- Foveal dimming: oldest message 0.2 → 0.70
- Background: killed radial gradient fog, flat void
- Decision cards: 82%/340px → 72%/280px (compact)

## Future Demo Scenes (not yet built)

| Scene | Chat vibe | @xark query | Cards |
|---|---|---|---|
| Birthday | "maya turns 30!" / "what should we get her?" | @xark gift ideas for maya | perfume, concert tickets, spa day |
| Weekend | "let's do something saturday" / "outdoors?" | @xark things to do this weekend | hike, kayak, wine tasting |
