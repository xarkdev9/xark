import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export const maxDuration = 15;

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  if (!checkRateLimit(`taste:${auth.userId}`, 3, 60_000)) {
    return NextResponse.json({ error: "Rate limited" }, { status: 429 });
  }

  const { text } = await req.json();
  if (!text || typeof text !== "string" || text.length > 500) {
    return NextResponse.json({ error: "Invalid input" }, { status: 400 });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) return NextResponse.json({ error: "AI unavailable" }, { status: 503 });

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: "gemini-2.5-flash",
    generationConfig: { responseMimeType: "application/json" },
  });

  const prompt = `Parse the following user preference statement into a JSON array of short constraint tags.
Rules:
- Tags should be lowercase, underscore-separated (e.g., "vegan", "no_chains", "budget_under_200")
- Dietary: vegan, vegetarian, gluten_free, halal, kosher, no_seafood, no_spicy, etc.
- Style: no_chains, no_tourist_traps, local_only, fine_dining, casual, specialty_coffee, etc.
- Budget: budget_under_50, budget_under_100, budget_under_200, luxury, etc.
- Accessibility: wheelchair_accessible, no_stairs, etc.
- Return ONLY a JSON array of strings. Max 10 tags.

User says: "${text.slice(0, 500)}"

JSON:`;

  try {
    const result = await model.generateContent(prompt);
    const raw = result.response.text();
    const constraints: string[] = JSON.parse(raw);

    if (!Array.isArray(constraints) || constraints.some((c) => typeof c !== "string")) {
      return NextResponse.json({ error: "Parse failed" }, { status: 500 });
    }

    if (supabaseAdmin) {
      await supabaseAdmin.rpc("save_taste_profile", {
        p_user_id: auth.userId,
        p_constraints: JSON.stringify(constraints.slice(0, 10)),
        p_raw_text: text.slice(0, 500),
      });
    }

    return NextResponse.json({ constraints });
  } catch (err) {
    console.error("[taste] Parse failed:", err);
    return NextResponse.json({ error: "Parse failed" }, { status: 500 });
  }
}
