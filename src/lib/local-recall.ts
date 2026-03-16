// XARK OS v2.0 — Tier 2: Recall Question Detection
// Detects memory/recall-intent @xark messages and routes to local search.
// Tuned to avoid false-positive against Tier 3 search commands.

// Patterns match recall-intent phrases (referencing past chat, people, or memory).
// "search for hotels in miami" is a Gemini search, NOT a recall question.
const RECALL_PATTERNS = [
  /what was that/i,
  /who said/i,
  /who mentioned/i,
  /remember when/i,
  /what did .+ (?:say|send|link|share|suggest|recommend)/i,
  /find .+ message/i,
  /when did .+ (?:say|send|mention)/i,
  /what .+ (?:link|place|hotel|restaurant|spot) .+ (?:link|share|send|mention|suggest)/i,
  /search (?:for )?(?:that|the) (?:message|thing|link|place)/i,
  /look up (?:that|the|what) (?:message|thing|link)/i,
];

export function isRecallQuestion(text: string): boolean {
  const cleaned = text.replace(/@xark\s*/i, "").trim();
  return RECALL_PATTERNS.some((p) => p.test(cleaned));
}

export interface RecallResult {
  messageId: string;
  content: string;
  senderName: string;
  timestamp: number;
}

export function getRecallWhisper(deviceTier: "high" | "low"): string {
  return deviceTier === "high"
    ? "couldn't find anything matching that in our recent chat history."
    : "couldn't find that exactly. local memory is keyword-only for now. try specific words like 'hotel' or 'marriott'.";
}
