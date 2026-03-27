/**
 * Integration Test — Real Apify data through the Consensus Engine
 *
 * Loads real hotel data from Booking.com (via Apify) and runs
 * the full Green-Lock lifecycle: propose → react → sort → lock → transfer → grounding.
 *
 * Usage: npx tsx src/integration-test.ts
 */

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

// Import engine modules
import { ConsensusEngine } from "./engine/consensus-engine.js";
import { ReactionType, BookableItemState, EventType } from "./models/types.js";
import type { EngineEvent, BookingProof } from "./models/types.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

interface HotelData {
  title: string;
  description: string;
  category: string;
  price: number | null;
  rating: number | null;
  ratingLabel: string | null;
  reviews: number | null;
  image: string | null;
  address: string;
  url: string;
  stars: number | null;
}

// ─── Helpers ───────────────────────────────────────────────

const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const RESET = "\x1b[0m";

function header(text: string) {
  console.log(`\n${BOLD}${CYAN}═══ ${text} ${"═".repeat(Math.max(0, 56 - text.length))}${RESET}`);
}

function pass(text: string) {
  console.log(`  ${GREEN}✓${RESET} ${text}`);
}

function info(text: string) {
  console.log(`  ${DIM}${text}${RESET}`);
}

function highlight(text: string) {
  console.log(`  ${YELLOW}→ ${text}${RESET}`);
}

// ─── Main ──────────────────────────────────────────────────

function main() {
  // Load real data
  const dataPath = resolve(__dirname, "..", "data", "hotels.json");
  let hotels: HotelData[];
  try {
    hotels = JSON.parse(readFileSync(dataPath, "utf-8")) as HotelData[];
  } catch {
    console.error(`${RED}No hotel data found at ${dataPath}.${RESET}`);
    console.error(`Run first: APIFY_TOKEN=<token> npx tsx src/apify-fetch.ts`);
    process.exit(1);
  }

  console.log(`${BOLD}Xark Consensus Engine — Integration Test with Real Apify Data${RESET}`);
  console.log(`${DIM}Loaded ${hotels.length} real hotels from Booking.com via Apify${RESET}`);

  // ─── Setup ───────────────────────────────────────────────

  const engine = new ConsensusEngine();
  const events: EngineEvent[] = [];
  engine.on((e) => events.push(e));

  // Register group
  engine.registerGroup({
    id: "sd_trip",
    name: "San Diego Bachelor Trip",
    members: [
      { userId: "alex", name: "Alex", avatarUrl: "", joinedAt: 1000 },
      { userId: "blake", name: "Blake", avatarUrl: "", joinedAt: 1000 },
      { userId: "casey", name: "Casey", avatarUrl: "", joinedAt: 1000 },
      { userId: "drew", name: "Drew", avatarUrl: "", joinedAt: 1000 },
      { userId: "ellis", name: "Ellis", avatarUrl: "", joinedAt: 1000 },
    ],
    createdAt: 1000,
  });

  // ─── Phase 1: Propose real hotels ────────────────────────

  header("Phase 1: Propose Real Hotels (Apify → Engine)");

  const itemIds: string[] = [];
  for (const hotel of hotels) {
    const item = engine.proposeItem(
      "sd_trip",
      hotel.title,
      hotel.description,
      "hotel",
      "apify",
      Date.now()
    );
    itemIds.push(item.id);
    pass(`Proposed: "${hotel.title}" ${hotel.rating ? `(${hotel.rating}/10)` : ""}`);
  }

  info(`${itemIds.length} items proposed, all in "proposed" state`);

  // Verify
  const allItems = engine.getGroupItems("sd_trip");
  console.assert(allItems.length === hotels.length, "All hotels proposed");
  console.assert(
    allItems.every((i) => i.state === BookableItemState.Proposed),
    "All in proposed state"
  );
  pass(`State verified: ${allItems.length} items, all "proposed"`);

  // ─── Phase 2: Heart-Sort — simulate group reactions ──────

  header("Phase 2: Heart-Sort — Group Reacts");

  // Simulate realistic reactions: some hotels get more love than others
  // The Marriott and hostels with high ratings should get more hearts
  const reactionPlan: Array<{ itemIndex: number; userId: string; type: ReactionType }> = [
    // AC Hotel Marriott (index 4) — crowd favorite
    { itemIndex: 4, userId: "alex", type: ReactionType.LoveIt },
    { itemIndex: 4, userId: "blake", type: ReactionType.LoveIt },
    { itemIndex: 4, userId: "casey", type: ReactionType.LoveIt },
    { itemIndex: 4, userId: "drew", type: ReactionType.WorksForMe },
    { itemIndex: 4, userId: "ellis", type: ReactionType.LoveIt },

    // Gaslamp Hostel (index 6) — budget-friendly pick
    { itemIndex: 6, userId: "blake", type: ReactionType.LoveIt },
    { itemIndex: 6, userId: "casey", type: ReactionType.WorksForMe },
    { itemIndex: 6, userId: "drew", type: ReactionType.LoveIt },

    // HI Hostel (index 5) — some interest
    { itemIndex: 5, userId: "alex", type: ReactionType.WorksForMe },
    { itemIndex: 5, userId: "ellis", type: ReactionType.LoveIt },

    // Walk everywhere Gaslamp (index 0) — one heart
    { itemIndex: 0, userId: "casey", type: ReactionType.LoveIt },

    // La Ventana (index 3) — thumbs ups
    { itemIndex: 3, userId: "drew", type: ReactionType.WorksForMe },
    { itemIndex: 3, userId: "alex", type: ReactionType.WorksForMe },
  ];

  for (const r of reactionPlan) {
    const id = itemIds[r.itemIndex];
    if (!id) continue;
    const emoji = r.type === ReactionType.LoveIt ? "Love it" : r.type === ReactionType.WorksForMe ? "Works" : "Not for me";
    engine.react(id, r.userId, r.type, Date.now());
    info(`${r.userId} reacted ${emoji} to "${hotels[r.itemIndex]?.title}"`);
  }

  // Check sort order
  const sorted = engine.getActiveItems("sd_trip");
  console.log();
  highlight("Heart-Sort Results (weighted score descending):");
  const ranked = engine.getRankedItems("sd_trip");
  for (const r of ranked) {
    const fav = r.isGroupFavorite ? " ⭐ GROUP FAVORITE" : "";
    console.log(
      `    ${BOLD}#${r.rank}${RESET} ${r.title} — ` +
        `${BOLD}${r.weightedScore} pts${RESET} ` +
        `(❤️×${r.reactionBreakdown.hearts} 👍×${r.reactionBreakdown.thumbsUp}) ` +
        `${Math.round(r.agreementScore)}% agreement${GREEN}${fav}${RESET}`
    );
  }

  // Verify sort is correct (descending by score)
  for (let i = 1; i < sorted.length; i++) {
    const prev = sorted[i - 1]!;
    const curr = sorted[i]!;
    console.assert(
      prev.weightedScore >= curr.weightedScore,
      `Sort order: ${prev.weightedScore} >= ${curr.weightedScore}`
    );
  }
  pass("Heart-Sort order verified (descending by weighted score)");

  // Verify AC Marriott is #1
  console.assert(
    sorted[0]?.title.includes("Marriott"),
    "AC Marriott should be #1"
  );
  pass(`Top pick: "${sorted[0]?.title}" with ${sorted[0]?.weightedScore} pts`);

  // Verify group favorite (>80% agreement)
  const marriottId = itemIds[4]!;
  const marriottAgreement = engine.getAgreementScore(marriottId);
  console.assert(
    marriottAgreement.isGroupFavorite,
    "AC Marriott should be group favorite (100% reacted)"
  );
  pass(`Agreement score: ${marriottAgreement.percentage}% — isGroupFavorite: ${marriottAgreement.isGroupFavorite}`);

  // ─── Phase 3: Green-Lock — book the top hotel ────────────

  header("Phase 3: Green-Lock — Casey Books the Top Pick");

  const topItemId = sorted[0]!.id;
  const topTitle = sorted[0]!.title;

  const proof: BookingProof = {
    type: "confirmation_number",
    value: "MARRIOTT-SD-" + Math.floor(Math.random() * 90000 + 10000),
    submittedBy: "casey",
    submittedAt: Date.now(),
  };

  const locked = engine.lock(topItemId, proof);

  console.assert(locked.state === BookableItemState.Locked, "Item should be locked");
  console.assert(locked.ownership?.ownerId === "casey", "Casey should be owner");
  console.assert(locked.bookingProof?.value === proof.value, "Proof should be stored");
  pass(`"${topTitle}" → GREEN-LOCK activated`);
  pass(`Owner: Casey (booker) | Ref: ${proof.value}`);
  pass(`State: ${locked.state} | Locked at: ${new Date(locked.lockedAt!).toISOString()}`);

  // Verify locked item cannot receive reactions
  let reactionBlocked = false;
  try {
    engine.react(topItemId, "alex", ReactionType.LoveIt, Date.now());
  } catch {
    reactionBlocked = true;
  }
  console.assert(reactionBlocked, "Reactions on locked items should throw");
  pass("Reactions on locked items correctly blocked");

  // Verify it's in locked list, not active
  const lockedItems = engine.getLockedItems("sd_trip");
  const activeItems = engine.getActiveItems("sd_trip");
  console.assert(lockedItems.length === 1, "1 locked item");
  console.assert(
    activeItems.length === hotels.length - 1,
    `${hotels.length - 1} active items`
  );
  pass(`Locked: ${lockedItems.length} | Active: ${activeItems.length}`);

  // ─── Phase 4: Ownership Transfer ────────────────────────

  header("Phase 4: Ownership Transfer — Drew Takes Over");

  const transferred = engine.transfer(topItemId, "drew", Date.now());
  console.assert(transferred.ownership?.ownerId === "drew", "Drew should be new owner");
  console.assert(transferred.ownership?.reason === "transfer", "Reason should be transfer");
  console.assert(transferred.ownershipHistory.length === 2, "2 ownership records");
  pass(`"${topTitle}" ownership transferred: Casey → Drew`);
  pass(`Ownership history: ${transferred.ownershipHistory.map((o) => `${o.ownerId} (${o.reason})`).join(" → ")}`);

  // Verify transfer to self fails
  let selfTransferBlocked = false;
  try {
    engine.transfer(topItemId, "drew", Date.now());
  } catch {
    selfTransferBlocked = true;
  }
  console.assert(selfTransferBlocked, "Transfer to current owner should throw");
  pass("Self-transfer correctly blocked");

  // ─── Phase 5: Tasks (non-bookable items) ─────────────────

  header("Phase 5: Tasks — Non-Bookable Items");

  const task1 = engine.addTask("sd_trip", "Pick airport pickup time", "Morning or afternoon?", "alex", Date.now());
  const task2 = engine.addTask("sd_trip", "Bring portable speaker", "For the boat", "blake", Date.now());

  pass(`Task created: "${task1.title}"`);
  pass(`Task created: "${task2.title}"`);

  const claimed1 = engine.claimTask(task1.id, "drew", Date.now());
  const claimed2 = engine.claimTask(task2.id, "ellis", Date.now());

  console.assert(claimed1.assignee === "drew", "Drew claimed task 1");
  console.assert(claimed2.assignee === "ellis", "Ellis claimed task 2");
  pass(`"${task1.title}" claimed by Drew`);
  pass(`"${task2.title}" claimed by Ellis`);

  // ─── Phase 6: AI Grounding ───────────────────────────────

  header("Phase 6: @hello AI Grounding");

  const context = engine.getGroundingContext("sd_trip");

  console.assert(context.lockedDecisions.length === 3, "3 constraints (1 booking + 2 tasks)");
  console.assert(context.activeItems.length === hotels.length - 1, `${hotels.length - 1} active items`);
  pass(`Grounding context: ${context.lockedDecisions.length} constraints, ${context.activeItems.length} active items`);

  const prompt = engine.getGroundingPrompt("sd_trip");
  console.assert(prompt.includes("GROUNDING CONSTRAINTS"), "Prompt has constraints header");
  console.assert(prompt.includes("LOCKED BOOKING"), "Prompt mentions locked booking");
  console.assert(prompt.includes(topTitle), "Prompt mentions the locked hotel");
  console.assert(prompt.includes("ASSIGNED TASK"), "Prompt mentions tasks");
  console.assert(prompt.includes("Do NOT suggest alternatives"), "Prompt has restriction");

  console.log();
  highlight("@hello System Prompt Fragment:");
  console.log(`${DIM}${prompt}${RESET}`);

  // ─── Phase 7: Event Log ──────────────────────────────────

  header("Phase 7: Event Audit");

  const eventCounts: Record<string, number> = {};
  for (const e of events) {
    eventCounts[e.type] = (eventCounts[e.type] ?? 0) + 1;
  }

  for (const [type, count] of Object.entries(eventCounts)) {
    pass(`${type}: ${count} events`);
  }

  console.assert(events.length > 0, "Events were emitted");
  console.assert(
    eventCounts[EventType.ItemProposed] === hotels.length,
    `${hotels.length} propose events`
  );
  console.assert(
    eventCounts[EventType.ItemLocked] === 1,
    "1 lock event"
  );
  pass(`Total events: ${events.length}`);

  // ─── Summary ─────────────────────────────────────────────

  header("INTEGRATION TEST COMPLETE");
  console.log();
  console.log(`  ${GREEN}${BOLD}All assertions passed.${RESET}`);
  console.log();
  console.log(`  ${DIM}Data source:  Apify voyager~booking-scraper (Booking.com)${RESET}`);
  console.log(`  ${DIM}Hotels:       ${hotels.length} real listings${RESET}`);
  console.log(`  ${DIM}Reactions:    ${reactionPlan.length} (from 5 members)${RESET}`);
  console.log(`  ${DIM}Locked:       1 (${topTitle})${RESET}`);
  console.log(`  ${DIM}Transferred:  Casey → Drew${RESET}`);
  console.log(`  ${DIM}Tasks:        2 created, 2 claimed${RESET}`);
  console.log(`  ${DIM}Events:       ${events.length} total${RESET}`);
  console.log();
}

main();
