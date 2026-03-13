"use client";
import { colors, text } from "@/lib/theme";
interface XarkChatProps { spaceId: string; userId?: string; spaceTitle?: string; }
export function XarkChat({ spaceTitle }: XarkChatProps) {
  return (
    <div className="px-6 pt-28 pb-40">
      <div className="mx-auto" style={{ maxWidth: "640px" }}>
        <p style={{ ...text.body, color: colors.white, opacity: 0.2 }}>
          {spaceTitle ? `@xark is ready for ${spaceTitle}` : "chat loading..."}
        </p>
      </div>
    </div>
  );
}
