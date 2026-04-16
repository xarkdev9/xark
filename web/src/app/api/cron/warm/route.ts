// Pings the fli Python function every 5 minutes to prevent cold starts.

import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const baseUrl = process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : "http://localhost:3000";

  try {
    const res = await fetch(`${baseUrl}/api/fli`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        origin: "JFK",
        destination: "LAX",
        date: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10),
        max_results: 1,
      }),
      signal: AbortSignal.timeout(15000),
    });

    const ok = res.ok;
    console.log(`[warm] fli ping: ${ok ? "OK" : res.status}`);
    return NextResponse.json({ fli: ok ? "warm" : "cold", status: res.status });
  } catch (err) {
    console.warn("[warm] fli ping failed:", err instanceof Error ? err.message : String(err));
    return NextResponse.json({ fli: "error" }, { status: 200 });
  }
}
