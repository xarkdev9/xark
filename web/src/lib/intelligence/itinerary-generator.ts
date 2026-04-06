// web/src/lib/intelligence/itinerary-generator.ts
// Three-pass itinerary generation:
//   Pass 1: AI generates day-by-day skeleton
//   Pass 2: Geospatial validation (Distance Matrix)
//   Pass 3: Fill slots with real data (fli, SearchAPI)
// Supports dream mode (date-less) and re-hydration when dates arrive.

import { getAIProvider } from "./ai-provider-factory";
import type { AIProvider, ItinerarySkeleton } from "./ai-provider";
import { validateDaySlots, buildTravelBlock, type TravelValidation } from "./geospatial";
import { searchFlightsFli } from "./fli-client";
import type { ApifyResult } from "./apify-client";

// ── Types ──

export interface ItinerarySlot {
  date: string; // "2026-06-10" or "Day 1" (dream mode)
  time: string; // "morning" | "afternoon" | "evening" | "travel"
  type: string; // "hotel" | "restaurant" | "activity" | "flight" | "travel"
  label: string; // Day label: "Arrival Day", "Temples & Rice Terraces"
  query: string; // Search query used to fill the slot
  note: string; // AI-generated context note
  // Filled in Pass 3:
  title?: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  bookingUrl?: string;
  rating?: number;
  source?: string;
  recentReview?: string;
  // Travel block fields:
  durationMinutes?: number;
  mode?: string;
  mapsUrl?: string;
  fromLocation?: string;
  toLocation?: string;
  // Alternatives (collapsed overflow):
  alternatives?: Array<{
    title: string;
    price?: string;
    imageUrl?: string;
    description?: string;
    externalUrl?: string;
    rating?: number;
    source?: string;
  }>;
}

export interface GeneratedItinerary {
  destination: string;
  startDate: string | null; // null = dream mode
  endDate: string | null;
  isDreamMode: boolean;
  slots: ItinerarySlot[];
  generatedAt: number;
}

export interface GenerateItineraryInput {
  destination: string;
  startDate?: string; // YYYY-MM-DD, omit for dream mode
  endDate?: string;
  tripDays?: number; // For dream mode: "5 days in Bali"
  groupSize: number;
  constraints: string; // Budget, dietary, accessibility from taste profiles
  tasteContext: string; // Taste profile summary
  lockedDecisions: string; // Already-committed items (grounding)
}

// ── Pass 1: Generate skeleton via AI ──

async function generateSkeleton(
  provider: AIProvider,
  input: GenerateItineraryInput
): Promise<ItinerarySkeleton> {
  const isDream = !input.startDate || !input.endDate;
  const days = input.tripDays || (
    input.startDate && input.endDate
      ? Math.ceil((new Date(input.endDate).getTime() - new Date(input.startDate).getTime()) / 86400000) + 1
      : 5
  );

  const dateInstruction = isDream
    ? `Generate a ${days}-day plan using "Day 1", "Day 2", etc. as dates. Do NOT use real dates.`
    : `Generate a plan from ${input.startDate} to ${input.endDate} (${days} days). Use actual dates as YYYY-MM-DD.`;

  const prompt = `You are a world-class travel concierge. Plan a ${days}-day trip to ${input.destination}.

${dateInstruction}

GROUP SIZE: ${input.groupSize} travelers
CONSTRAINTS: ${input.constraints || "none specified"}
TASTE PROFILE: ${input.tasteContext || "general interests"}
ALREADY BOOKED: ${input.lockedDecisions || "nothing yet"}

RULES:
- Day 1 should start with arrival logistics (hotel check-in, first meal)
- Last day should end with departure logistics
- Each day has 2-4 slots: morning, afternoon, evening (not more)
- Mix activities, restaurants, and culture — don't overload any single day
- Consider travel time between locations — keep consecutive slots geographically close
- For hotel: include ONLY on Day 1 (check-in) — don't repeat every day
- For flights: include on Day 1 (arrival) and last day (departure) ONLY if not already booked
- Use real, specific place names — no generic "explore the area" slots
- Each slot query should be specific enough for a Google Local search (e.g., "best seafood restaurant Seminyak Bali")
${isDream ? "- Since there are no dates, do NOT include flight slots (prices are date-dependent)" : ""}

Return ONLY valid JSON matching this schema:
{
  "days": [
    {
      "date": "${isDream ? "Day 1" : input.startDate}",
      "label": "Arrival Day",
      "slots": [
        { "time": "afternoon", "type": "hotel", "query": "beachfront resorts Seminyak Bali", "note": "check in, decompress" },
        { "time": "evening", "type": "restaurant", "query": "sunset dinner Seminyak beach Bali", "note": "first night dinner with ocean view" }
      ]
    }
  ]
}`;

  try {
    const result = await provider.generateJson(prompt);
    const skeleton = result as unknown as ItinerarySkeleton;

    // Validate structure
    if (!skeleton.days || !Array.isArray(skeleton.days)) {
      console.error("[itinerary] Invalid skeleton structure — no days array");
      return { days: [] };
    }

    return skeleton;
  } catch (err) {
    console.error("[itinerary] Skeleton generation failed:", err instanceof Error ? err.message : String(err));
    return { days: [] };
  }
}

// ── Pass 2: Geospatial validation ──

async function validateGeospatial(
  provider: AIProvider,
  skeleton: ItinerarySkeleton,
  destination: string
): Promise<ItinerarySkeleton> {
  const validatedDays = [];

  for (const day of skeleton.days) {
    if (day.slots.length < 2) {
      validatedDays.push(day);
      continue;
    }

    const validations = await validateDaySlots(day.slots);
    const newSlots: Array<{ time: string; type: string; query: string; note: string }> = [];

    for (let i = 0; i < day.slots.length; i++) {
      newSlots.push(day.slots[i]);

      // Check if there's a validation for the gap between this slot and the next
      if (i < validations.length) {
        const validation = validations[i];
        if (validation && validation.exceedsThreshold) {
          console.log(`[itinerary] Travel gap: ${validation.from} → ${validation.to} = ${validation.durationMinutes}min (>${60}min threshold)`);

          // Try to get a closer alternative from the AI
          const repromptResult = await tryRepromptCloser(provider, day.slots[i], day.slots[i + 1], destination);

          if (repromptResult) {
            // Replace the next slot with the closer alternative
            day.slots[i + 1] = repromptResult;
            console.log(`[itinerary] Replaced far slot with closer alternative: "${repromptResult.query}"`);
          } else {
            // Insert a travel block between slots
            const travelBlock = buildTravelBlock(validation);
            newSlots.push({
              time: "travel",
              type: "travel",
              query: travelBlock.note,
              note: `${validation.durationText} ${validation.mode}`,
            });
          }
        }
      }
    }

    validatedDays.push({ ...day, slots: newSlots });
  }

  return { days: validatedDays };
}

async function tryRepromptCloser(
  provider: AIProvider,
  currentSlot: { query: string; time: string },
  farSlot: { query: string; time: string; type: string },
  destination: string
): Promise<{ time: string; type: string; query: string; note: string } | null> {
  try {
    const prompt = `The ${farSlot.time} activity "${farSlot.query}" is too far from the ${currentSlot.time} activity "${currentSlot.query}" in ${destination}.
Find a highly-rated alternative ${farSlot.type} within 5km of "${currentSlot.query}".
Return ONLY JSON: {"time":"${farSlot.time}","type":"${farSlot.type}","query":"specific search query","note":"why this is a good alternative"}`;

    const result = await provider.generateJson(prompt);
    if (result.query && result.type) {
      return result as unknown as { time: string; type: string; query: string; note: string };
    }
    return null;
  } catch {
    return null;
  }
}

// ── Pass 3: Fill slots with real data ──

async function fillSlots(
  skeleton: ItinerarySkeleton,
  input: GenerateItineraryInput
): Promise<ItinerarySlot[]> {
  const allSlots: ItinerarySlot[] = [];

  for (const day of skeleton.days) {
    for (const slot of day.slots) {
      const itinerarySlot: ItinerarySlot = {
        date: day.date,
        time: slot.time,
        type: slot.type,
        label: day.label,
        query: slot.query,
        note: slot.note,
      };

      // Travel blocks don't need filling
      if (slot.type === "travel") {
        allSlots.push(itinerarySlot);
        continue;
      }

      // Dream mode: no flights (prices are date-dependent)
      const isDream = !input.startDate;
      if (isDream && slot.type === "flight") {
        itinerarySlot.note = "Set dates to see flight prices";
        allSlots.push(itinerarySlot);
        continue;
      }

      // Fill the slot with real search data
      try {
        const results = await searchForSlot(slot, input);

        if (results.length > 0) {
          const hero = results[0];
          itinerarySlot.title = hero.title;
          itinerarySlot.price = isDream && slot.type === "hotel" ? "Set dates for pricing" : hero.price;
          itinerarySlot.imageUrl = hero.imageUrl;
          itinerarySlot.description = hero.description;
          itinerarySlot.externalUrl = hero.externalUrl;
          itinerarySlot.rating = hero.rating;
          itinerarySlot.source = hero.source;

          // Alternatives (collapsed overflow in UI)
          if (results.length > 1) {
            itinerarySlot.alternatives = results.slice(1, 4).map((r) => ({
              title: r.title,
              price: r.price,
              imageUrl: r.imageUrl,
              description: r.description,
              externalUrl: r.externalUrl,
              rating: r.rating,
              source: r.source,
            }));
          }
        }
      } catch (err) {
        console.warn(`[itinerary] Failed to fill slot "${slot.query}":`, err instanceof Error ? err.message : String(err));
      }

      allSlots.push(itinerarySlot);
    }
  }

  return allSlots;
}

async function searchForSlot(
  slot: { type: string; query: string },
  input: GenerateItineraryInput
): Promise<ApifyResult[]> {
  // Dynamic import to avoid circular dependencies
  const { searchHotels, searchLocal } = await import("./searchapi-client");

  switch (slot.type) {
    case "hotel":
      return searchHotels({
        location: input.destination,
        query: slot.query,
        checkIn: input.startDate,
        checkOut: input.endDate,
      });

    case "restaurant":
    case "activity":
      return searchLocal({
        query: slot.query,
        location: input.destination,
      });

    case "flight":
      if (input.startDate) {
        const fliResults = await searchFlightsFli({
          origin: "", // Needs to come from group logistics
          destination: input.destination,
          date: input.startDate,
        });
        return fliResults.map((f) => ({
          title: f.title,
          price: f.price,
          imageUrl: f.imageUrl,
          description: f.description,
          externalUrl: f.bookingUrl,
          source: "fli",
        }));
      }
      return [];

    default:
      return searchLocal({
        query: slot.query,
        location: input.destination,
      });
  }
}

// ── Main entry point ──

/**
 * Generate a complete itinerary for a trip.
 * Three passes: skeleton → geospatial → fill.
 * Supports dream mode (no dates — "Day 1, Day 2...").
 */
export async function generateItinerary(
  input: GenerateItineraryInput
): Promise<GeneratedItinerary> {
  const provider = getAIProvider();
  if (!provider) {
    return {
      destination: input.destination,
      startDate: input.startDate || null,
      endDate: input.endDate || null,
      isDreamMode: !input.startDate,
      slots: [],
      generatedAt: Date.now(),
    };
  }

  const isDream = !input.startDate || !input.endDate;
  console.log(`[itinerary] Generating ${isDream ? "dream" : "real"} itinerary for ${input.destination}`);

  // Pass 1: Generate skeleton
  console.log("[itinerary] Pass 1: Generating skeleton...");
  const skeleton = await generateSkeleton(provider, input);
  if (skeleton.days.length === 0) {
    console.error("[itinerary] Pass 1 failed — empty skeleton");
    return {
      destination: input.destination,
      startDate: input.startDate || null,
      endDate: input.endDate || null,
      isDreamMode: isDream,
      slots: [],
      generatedAt: Date.now(),
    };
  }
  console.log(`[itinerary] Pass 1 complete: ${skeleton.days.length} days, ${skeleton.days.reduce((sum, d) => sum + d.slots.length, 0)} slots`);

  // Pass 2: Geospatial validation
  console.log("[itinerary] Pass 2: Geospatial validation...");
  const validated = await validateGeospatial(provider, skeleton, input.destination);
  const travelBlocks = validated.days.reduce((sum, d) => sum + d.slots.filter((s) => s.type === "travel").length, 0);
  console.log(`[itinerary] Pass 2 complete: ${travelBlocks} travel blocks inserted`);

  // Pass 3: Fill slots with real data
  console.log("[itinerary] Pass 3: Filling slots with real data...");
  const slots = await fillSlots(validated, input);
  const filledCount = slots.filter((s) => s.title).length;
  console.log(`[itinerary] Pass 3 complete: ${filledCount}/${slots.length} slots filled`);

  return {
    destination: input.destination,
    startDate: input.startDate || null,
    endDate: input.endDate || null,
    isDreamMode: isDream,
    slots,
    generatedAt: Date.now(),
  };
}

/**
 * Re-hydrate a dream itinerary with real dates and prices.
 * Called when user sets dates on a space that already has dream-mode recommendations.
 */
export async function rehydrateItinerary(
  existingSlots: ItinerarySlot[],
  startDate: string,
  endDate: string,
  destination: string
): Promise<ItinerarySlot[]> {
  const totalDays = Math.ceil((new Date(endDate).getTime() - new Date(startDate).getTime()) / 86400000) + 1;

  const rehydrated: ItinerarySlot[] = [];

  for (const slot of existingSlots) {
    const newSlot = { ...slot };

    // Convert "Day N" to actual date
    const dayMatch = slot.date.match(/Day (\d+)/i);
    if (dayMatch) {
      const dayNum = parseInt(dayMatch[1], 10) - 1;
      if (dayNum < totalDays) {
        const date = new Date(startDate);
        date.setDate(date.getDate() + dayNum);
        newSlot.date = date.toISOString().slice(0, 10);
      }
    }

    // Re-fill price-dependent slots
    if (slot.type === "hotel" && slot.price === "Set dates for pricing") {
      try {
        const { searchHotels } = await import("./searchapi-client");
        const results = await searchHotels({
          location: destination,
          query: slot.query,
          checkIn: startDate,
          checkOut: endDate,
        });
        if (results.length > 0) {
          newSlot.price = results[0].price;
          newSlot.imageUrl = results[0].imageUrl || newSlot.imageUrl;
        }
      } catch {
        // Keep existing data
      }
    }

    // Add flights for arrival/departure days
    if (slot.type === "flight" && slot.note === "Set dates to see flight prices") {
      try {
        const fliResults = await searchFlightsFli({
          origin: "", // TODO: resolve from group logistics
          destination,
          date: newSlot.date,
        });
        if (fliResults.length > 0) {
          const hero = fliResults[0];
          newSlot.title = hero.title;
          newSlot.price = hero.price;
          newSlot.imageUrl = hero.imageUrl;
          newSlot.description = hero.description;
          newSlot.bookingUrl = hero.bookingUrl;
        }
      } catch {
        // Keep placeholder
      }
    }

    rehydrated.push(newSlot);
  }

  return rehydrated;
}

/**
 * Modify a single slot in an existing itinerary.
 * Used for conversational mutations: "@hello swap Tuesday morning for something chill"
 */
export async function modifyItinerarySlot(
  existingSlots: ItinerarySlot[],
  targetDay: string, // "2026-06-11" or "Day 2" or "Tuesday"
  targetTime: string | "all", // "morning" | "afternoon" | "evening" | "all"
  instruction: string, // "more adventurous", "closer to hotel", "chill"
  destination: string
): Promise<{ updatedSlots: ItinerarySlot[]; summary: string }> {
  const provider = getAIProvider();
  if (!provider) {
    return { updatedSlots: existingSlots, summary: "ai not configured" };
  }

  // Find matching slots
  const targetSlots = existingSlots.filter((s) => {
    const dayMatch = s.date === targetDay ||
      s.date.toLowerCase().includes(targetDay.toLowerCase()) ||
      s.label.toLowerCase().includes(targetDay.toLowerCase());
    const timeMatch = targetTime === "all" || s.time === targetTime;
    return dayMatch && timeMatch && s.type !== "travel";
  });

  if (targetSlots.length === 0) {
    return { updatedSlots: existingSlots, summary: `couldn't find slots matching "${targetDay}" ${targetTime}` };
  }

  // Ask AI for replacement suggestions
  const slotDescriptions = targetSlots.map((s) => `${s.time}: "${s.title || s.query}" (${s.type})`).join(", ");

  const prompt = `Current itinerary slots for ${targetDay} in ${destination}: ${slotDescriptions}

User wants: "${instruction}"

Generate replacement slots that satisfy the user's request. Keep the same time structure.
Stay geographically close to the other activities that day.
Return ONLY JSON array: [{"time":"morning","type":"activity","query":"specific search query","note":"why this fits"}]`;

  try {
    const result = await provider.generateJson(prompt);
    const replacements = Array.isArray(result) ? result : (result as any).slots || [result];

    // Fill replacements with real data
    const { searchLocal } = await import("./searchapi-client");
    const updated = [...existingSlots];
    let changedCount = 0;

    for (const replacement of replacements) {
      if (!replacement.time || !replacement.query) continue;

      const idx = updated.findIndex((s) =>
        (s.date === targetDay || s.date.toLowerCase().includes(targetDay.toLowerCase())) &&
        s.time === replacement.time &&
        s.type !== "travel"
      );

      if (idx === -1) continue;

      // Search for the replacement
      const results = await searchLocal({
        query: String(replacement.query),
        location: destination,
      });

      if (results.length > 0) {
        const hero = results[0];
        updated[idx] = {
          ...updated[idx],
          query: String(replacement.query),
          note: String(replacement.note || ""),
          title: hero.title,
          price: hero.price,
          imageUrl: hero.imageUrl,
          description: hero.description,
          externalUrl: hero.externalUrl,
          rating: hero.rating,
          source: hero.source,
          alternatives: results.slice(1, 4).map((r) => ({
            title: r.title,
            price: r.price,
            imageUrl: r.imageUrl,
            description: r.description,
            externalUrl: r.externalUrl,
            rating: r.rating,
            source: r.source,
          })),
        };
        changedCount++;
      }
    }

    const summary = changedCount > 0
      ? `swapped ${changedCount} slot${changedCount > 1 ? "s" : ""}. ${targetSlots[0]?.title ? `replaced "${targetSlots[0].title}"` : "updated the plan"}.`
      : "couldn't find good replacements. keeping the current plan.";

    return { updatedSlots: updated, summary };
  } catch (err) {
    console.error("[itinerary] Modify failed:", err instanceof Error ? err.message : String(err));
    return { updatedSlots: existingSlots, summary: "couldn't find a replacement. keeping the current plan." };
  }
}
