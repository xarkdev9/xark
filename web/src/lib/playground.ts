// XARK OS v2.0 — GHOST PLAYGROUND
// Client-side sandbox for first-time users. 5 fake friends, 4 curated spaces.
// Zero database records. Vanishes when user creates first real space.

import type { SpaceAwareness } from "@/lib/home-feed";

// ── Types ──

export interface PlaygroundFriend {
  id: string;
  displayName: string;
  letter: string;
}

export interface PlaygroundItem {
  id: string;
  title: string;
  category: string;
  weighted_score: number;
  agreement_score: number;
  is_locked: boolean;
  state: string;
  metadata: {
    type?: string;
    options?: string[];
    assignee_id?: string;
    image_url?: string;
    price?: string;
    source?: string;
    search_label?: string;
  };
  created_at: string;
}

export interface PlaygroundMessage {
  id: string;
  role: "user" | "xark" | "system";
  content: string;
  timestamp: number;
  senderName?: string;
}

// ── The 5 Friends ──

export const PLAYGROUND_FRIENDS: Record<string, PlaygroundFriend> = {
  leo: { id: "pg_leo", displayName: "leo", letter: "L" },
  kai: { id: "pg_kai", displayName: "kai", letter: "K" },
  ava: { id: "pg_ava", displayName: "ava", letter: "A" },
  zoe: { id: "pg_zoe", displayName: "zoe", letter: "Z" },
  sam: { id: "pg_sam", displayName: "sam", letter: "S" },
};

const f = PLAYGROUND_FRIENDS;

// ── Timestamps (relative to now, minutes ago) ──
function ago(minutes: number): number {
  return Date.now() - minutes * 60 * 1000;
}

function agoISO(minutes: number): string {
  return new Date(ago(minutes)).toISOString();
}

// ── Space IDs ──
const SPACE_IDS = {
  tokyo: "pg_tokyo-neon-nights",
  dinner: "pg_dinner-tonight",
  maya: "pg_mayas-birthday",
  hike: "pg_weekend-hike",
};

// ── Space 1: "tokyo neon nights" — The Hook (94% consensus) ──

const TOKYO_ITEMS: PlaygroundItem[] = [
  {
    id: "pg_item_hyatt",
    title: "park hyatt tokyo",
    category: "hotel",
    weighted_score: 18,
    agreement_score: 0.94,
    is_locked: false,
    state: "ranked",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&h=500&fit=crop",
      price: "$650/nt",
      source: "booking.com",
      search_label: "hotels",
    },
    created_at: agoISO(45),
  },
  {
    id: "pg_item_t4",
    title: "Get balloons and party hats",
    category: "task",
    weighted_score: 99,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: { type: "task" },
    created_at: agoISO(20),
  },
  {
    id: "pg_item_t5",
    title: "Book the Uber to Narita",
    category: "task",
    weighted_score: 98,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: { type: "task", price: "≈ $80" },
    created_at: agoISO(18),
  },
  {
    id: "pg_item_t6",
    title: "Pick up pocket wifi at airport",
    category: "task",
    weighted_score: 97,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: { type: "task", assignee_id: "pg_leo" },
    created_at: agoISO(15),
  },
  {
    id: "pg_item_t7",
    title: "Which weekend works best for Kyoto?",
    category: "poll",
    weighted_score: 96,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: { type: "poll", options: ["Aug 12 - 15", "Aug 19 - 22", "Sept 2 - 5"] },
    created_at: agoISO(10),
  },
  {
    id: "pg_item_andaz",
    title: "andaz tokyo",
    category: "hotel",
    weighted_score: 8,
    agreement_score: 0.60,
    is_locked: false,
    state: "ranked",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=400&h=500&fit=crop",
      price: "$420/nt",
      source: "hyatt.com",
      search_label: "hotels",
    },
    created_at: agoISO(44),
  },
  {
    id: "pg_item_hoshinoya",
    title: "hoshinoya tokyo",
    category: "hotel",
    weighted_score: 3,
    agreement_score: 0.30,
    is_locked: false,
    state: "ranked",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=400&h=500&fit=crop",
      price: "$380/nt",
      source: "hoshinoya.com",
      search_label: "hotels",
    },
    created_at: agoISO(43),
  },
  {
    id: "pg_item_t4",
    title: "Aman Tokyo",
    category: "hotel",
    weighted_score: 15,
    agreement_score: 0.85,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$900/nt", source: "aman.com", search_label: "hotels" },
    created_at: agoISO(42),
  },
  {
    id: "pg_item_t5",
    title: "Mandarin Oriental Tokyo",
    category: "hotel",
    weighted_score: 12,
    agreement_score: 0.70,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$700/nt", source: "booking.com", search_label: "hotels" },
    created_at: agoISO(41),
  },
  {
    id: "pg_item_t6",
    title: "The Ritz-Carlton Tokyo",
    category: "hotel",
    weighted_score: 14,
    agreement_score: 0.75,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$850/nt", source: "marriott.com", search_label: "hotels" },
    created_at: agoISO(40),
  },
  {
    id: "pg_item_t7",
    title: "Shangri-La Tokyo",
    category: "hotel",
    weighted_score: 10,
    agreement_score: 0.65,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$550/nt", source: "shangri-la.com", search_label: "hotels" },
    created_at: agoISO(39),
  },
  {
    id: "pg_item_t8",
    title: "Palace Hotel Tokyo",
    category: "hotel",
    weighted_score: 16,
    agreement_score: 0.88,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$600/nt", source: "palacehoteltokyo.com", search_label: "hotels" },
    created_at: agoISO(38),
  },
  {
    id: "pg_item_t9",
    title: "The Peninsula Tokyo",
    category: "hotel",
    weighted_score: 13,
    agreement_score: 0.72,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$750/nt", source: "peninsula.com", search_label: "hotels" },
    created_at: agoISO(37),
  },
  {
    id: "pg_item_t10",
    title: "Conrad Tokyo",
    category: "hotel",
    weighted_score: 9,
    agreement_score: 0.55,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$450/nt", source: "hilton.com", search_label: "hotels" },
    created_at: agoISO(36),
  },
  {
    id: "pg_item_t11",
    title: "Four Seasons Hotel Tokyo at Otemachi",
    category: "hotel",
    weighted_score: 17,
    agreement_score: 0.90,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$800/nt", source: "fourseasons.com", search_label: "hotels" },
    created_at: agoISO(35),
  },
  {
    id: "pg_item_t12",
    title: "K5 Tokyo",
    category: "hotel",
    weighted_score: 7,
    agreement_score: 0.40,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$300/nt", source: "booking.com", search_label: "hotels" },
    created_at: agoISO(34),
  },
  {
    id: "pg_item_t13",
    title: "Trunk Hotel",
    category: "hotel",
    weighted_score: 11,
    agreement_score: 0.68,
    is_locked: false,
    state: "ranked",
    metadata: { price: "$350/nt", source: "trunk-hotel.com", search_label: "hotels" },
    created_at: agoISO(33),
  },
];

const TOKYO_MESSAGES: PlaygroundMessage[] = [
  { id: "pg_msg_t1", role: "user", content: "found a few hotels for tokyo", timestamp: ago(50), senderName: "leo" },
  { id: "pg_msg_t2", role: "user", content: "park hyatt looks incredible", timestamp: ago(48), senderName: "kai" },
  { id: "pg_msg_t3", role: "user", content: "is it in budget though?", timestamp: ago(46), senderName: "ava" },
  { id: "pg_msg_t4", role: "user", content: "it's worth it for the views", timestamp: ago(44), senderName: "leo" },
  { id: "pg_msg_t5", role: "system", content: "sam reacted love to park hyatt", timestamp: ago(42) },
  { id: "pg_msg_t6", role: "user", content: "just need your vote", timestamp: ago(40), senderName: "kai" },
];

// ── Space 2: "dinner tonight" — The Magic Trick (fresh chat) ──

const DINNER_ITEMS: PlaygroundItem[] = [];

const DINNER_MESSAGES: PlaygroundMessage[] = [
  { id: "pg_msg_d1", role: "user", content: "where should we eat?", timestamp: ago(15), senderName: "zoe" },
  { id: "pg_msg_d2", role: "user", content: "somewhere walkable", timestamp: ago(12), senderName: "leo" },
];

// ── Space 3: "maya's birthday" — The Friction Killer (ready stage) ──

const MAYA_ITEMS: PlaygroundItem[] = [
  {
    id: "pg_item_nobu",
    title: "dinner at nobu",
    category: "dining",
    weighted_score: 15,
    agreement_score: 1.0,
    is_locked: true,
    state: "purchased",
    metadata: {
      price: "$320",
      source: "nobu.com",
      image_url: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&h=500&fit=crop",
    },
    created_at: agoISO(120),
  },
  {
    id: "pg_item_cake",
    title: "surprise cake",
    category: "activity",
    weighted_score: 12,
    agreement_score: 1.0,
    is_locked: true,
    state: "locked",
    metadata: {
      price: "$85",
      image_url: "https://images.unsplash.com/photo-1558636508-e0db3814bd1d?w=400&h=500&fit=crop",
    },
    created_at: agoISO(110),
  },
];

const MAYA_MESSAGES: PlaygroundMessage[] = [
  { id: "pg_msg_m1", role: "user", content: "i'll get the cake", timestamp: ago(100), senderName: "ava" },
  { id: "pg_msg_m2", role: "user", content: "nobu is booked for 8pm", timestamp: ago(95), senderName: "leo" },
  { id: "pg_msg_m3", role: "user", content: "this is going to be so good", timestamp: ago(90), senderName: "zoe" },
  { id: "pg_msg_m4", role: "user", content: "dinner was $320, splitting 4 ways", timestamp: ago(85), senderName: "leo" },
];

// ── Space 4: "weekend hike" — The Afterglow (settled) ──

const HIKE_ITEMS: PlaygroundItem[] = [
  {
    id: "pg_item_trail",
    title: "sunrise trail",
    category: "activity",
    weighted_score: 20,
    agreement_score: 1.0,
    is_locked: true,
    state: "purchased",
    metadata: { price: "free" },
    created_at: agoISO(2880),
  },
  {
    id: "pg_item_campsite",
    title: "oak grove campsite",
    category: "activity",
    weighted_score: 15,
    agreement_score: 1.0,
    is_locked: true,
    state: "purchased",
    metadata: { price: "$45/night" },
    created_at: agoISO(2870),
  },
  {
    id: "pg_item_gear",
    title: "gear rental",
    category: "activity",
    weighted_score: 10,
    agreement_score: 1.0,
    is_locked: true,
    state: "purchased",
    metadata: { price: "$60" },
    created_at: agoISO(2860),
  },
];

const HIKE_MESSAGES: PlaygroundMessage[] = [
  { id: "pg_msg_h1", role: "user", content: "that sunrise was unreal", timestamp: ago(1440), senderName: "kai" },
  { id: "pg_msg_h2", role: "user", content: "we need to do this again", timestamp: ago(1430), senderName: "ava" },
  { id: "pg_msg_h3", role: "user", content: "best weekend in a while", timestamp: ago(1420), senderName: "sam" },
  { id: "pg_msg_h4", role: "user", content: "next time let's try camping", timestamp: ago(1410), senderName: "kai" },
  { id: "pg_msg_h5", role: "user", content: "already planning it", timestamp: ago(1400), senderName: "ava" },
];

const HIKE_PHOTOS: string[] = [
  "https://images.unsplash.com/photo-1551632811-561732d1e306?w=600&h=400&fit=crop", // hiking trail
  "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=600&h=400&fit=crop", // campfire
  "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=600&h=400&fit=crop", // sunset valley
  "https://images.unsplash.com/photo-1527631746610-bca00a040d60?w=600&h=400&fit=crop", // group outdoors
  "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600&h=400&fit=crop", // mountain vista
  "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=600&h=400&fit=crop", // road trip
];

// ── Hardcoded @hello restaurant results for playground ──

export const PLAYGROUND_XARK_RESTAURANTS: PlaygroundItem[] = [
  {
    id: "pg_xark_r1",
    title: "sushi nakazawa",
    category: "restaurant",
    weighted_score: 0,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=400&h=500&fit=crop",
      price: "$45/person",
      source: "google",
      search_label: "sushi spots",
    },
    created_at: new Date().toISOString(),
  },
  {
    id: "pg_xark_r2",
    title: "omakase room",
    category: "restaurant",
    weighted_score: 0,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1553621042-f6e147245754?w=400&h=500&fit=crop",
      price: "$65/person",
      source: "google",
      search_label: "sushi spots",
    },
    created_at: new Date().toISOString(),
  },
  {
    id: "pg_xark_r3",
    title: "blue ribbon sushi",
    category: "restaurant",
    weighted_score: 0,
    agreement_score: 0,
    is_locked: false,
    state: "proposed",
    metadata: {
      image_url: "https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?w=400&h=500&fit=crop",
      price: "$35/person",
      source: "google",
      search_label: "sushi spots",
    },
    created_at: new Date().toISOString(),
  },
];

// ── Members per space ──

const SPACE_MEMBERS: Record<string, PlaygroundFriend[]> = {
  [SPACE_IDS.tokyo]: [f.leo, f.kai, f.ava, f.sam],
  [SPACE_IDS.dinner]: [f.zoe, f.leo, f.kai],
  [SPACE_IDS.maya]: [f.leo, f.ava, f.zoe],
  [SPACE_IDS.hike]: [f.kai, f.ava, f.sam],
};

// ── Items per space ──

const SPACE_ITEMS: Record<string, PlaygroundItem[]> = {
  [SPACE_IDS.tokyo]: TOKYO_ITEMS,
  [SPACE_IDS.dinner]: DINNER_ITEMS,
  [SPACE_IDS.maya]: MAYA_ITEMS,
  [SPACE_IDS.hike]: HIKE_ITEMS,
};

// ── Messages per space ──

const SPACE_MESSAGES: Record<string, PlaygroundMessage[]> = {
  [SPACE_IDS.tokyo]: TOKYO_MESSAGES,
  [SPACE_IDS.dinner]: DINNER_MESSAGES,
  [SPACE_IDS.maya]: MAYA_MESSAGES,
  [SPACE_IDS.hike]: HIKE_MESSAGES,
};

// ══════════════════════════════════════════════════════════
//  PUBLIC API
// ══════════════════════════════════════════════════════════

/** Returns true when user has zero real spaces and zero personal chats */
export function isPlaygroundMode(
  realSpaces: { groupId?: string; id?: string }[],
  realChats: { groupId?: string }[]
): boolean {
  return realSpaces.length === 0 && realChats.length === 0;
}

/** Check if a groupId is a playground space */
export function isPlaygroundSpace(groupId: string): boolean {
  return Object.values(SPACE_IDS).includes(groupId);
}

/** Get all 4 playground spaces formatted for AwarenessStream */
export function getPlaygroundSpaces(): SpaceAwareness[] {
  return [
    {
      groupId: SPACE_IDS.tokyo,
      spaceTitle: "tokyo neon nights",
      lastActivityAt: ago(40),
      actionNeeded: true,
      locked: 0,
      needsVote: 1,
      exploring: 2,
      total: 3,
      needsFlight: false,
      priority: 0.95,
    },
    {
      groupId: SPACE_IDS.dinner,
      spaceTitle: "dinner tonight",
      lastActivityAt: ago(12),
      actionNeeded: false,
      locked: 0,
      needsVote: 0,
      exploring: 0,
      total: 0,
      needsFlight: false,
      priority: 0.5,
    },
    {
      groupId: SPACE_IDS.maya,
      spaceTitle: "maya's birthday",
      lastActivityAt: ago(85),
      actionNeeded: true,
      locked: 2,
      needsVote: 0,
      exploring: 0,
      total: 2,
      needsFlight: false,
      priority: 0.7,
    },
    {
      groupId: SPACE_IDS.hike,
      spaceTitle: "weekend hike",
      lastActivityAt: ago(1400),
      actionNeeded: false,
      locked: 3,
      needsVote: 0,
      exploring: 0,
      total: 3,
      needsFlight: false,
      priority: 0.3,
    },
  ];
}

/** Get decision items for a playground space */
export function getPlaygroundItems(groupId: string): PlaygroundItem[] {
  return SPACE_ITEMS[groupId] ?? [];
}

/** Get chat messages for a playground space */
export function getPlaygroundMessages(groupId: string): PlaygroundMessage[] {
  return SPACE_MESSAGES[groupId] ?? [];
}

/** Get members for a playground space */
export function getPlaygroundMembers(groupId: string): PlaygroundFriend[] {
  return SPACE_MEMBERS[groupId] ?? [];
}

/** Get photo URLs for the settled "weekend hike" space */
export function getPlaygroundPhotos(groupId: string): string[] {
  if (groupId === SPACE_IDS.hike) return HIKE_PHOTOS;
  return [];
}

/** Exported space IDs for choreography matching */
export { SPACE_IDS as PLAYGROUND_SPACE_IDS };
