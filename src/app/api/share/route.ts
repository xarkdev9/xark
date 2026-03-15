import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const title = formData.get("title") as string || "";
    const text = formData.get("text") as string || "";
    const url = formData.get("url") as string || "";

    const params = new URLSearchParams();
    if (title) params.set("title", title);
    if (text) params.set("text", text);
    if (url) params.set("url", url);

    return NextResponse.redirect(
      new URL(`/share?${params.toString()}`, req.url)
    );
  } catch {
    return NextResponse.redirect(new URL("/galaxy", req.url));
  }
}
