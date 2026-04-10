"use client";

// hello OS v2.0 — E2EE Link Preview Card
// Renders OG metadata (title, description, domain) with an optional
// encrypted preview image via EncryptedMediaRenderer.

import { EncryptedMediaRenderer } from "@/components/os/EncryptedMedia";
import { ink } from "@/lib/theme";

interface LinkPreviewProps {
  url: string;
  title?: string;
  description?: string;
  mediaUrl?: string;
  aesKeyBase64?: string;
  ivBase64?: string;
  mimeType?: string;
  inlineThumbnail?: string;
}

export function LinkPreviewCard({ url, title, description, mediaUrl, aesKeyBase64, ivBase64, mimeType, inlineThumbnail }: LinkPreviewProps) {
  let domain = '';
  try { domain = new URL(url).hostname.replace(/^www\./, ''); } catch { domain = url; }

  const hasEncryptedImage = mediaUrl && aesKeyBase64 && ivBase64 && mimeType;

  return (
    <div
      style={{
        marginTop: "6px",
        borderRadius: "10px",
        overflow: "hidden",
        background: "rgba(128,128,128,0.06)",
        borderLeft: "3px solid rgba(128,128,128,0.15)",
      }}
    >
      {hasEncryptedImage && (
        <div style={{ maxHeight: "160px", overflow: "hidden" }}>
          <EncryptedMediaRenderer
            mediaUrl={mediaUrl}
            aesKeyBase64={aesKeyBase64}
            ivBase64={ivBase64}
            mimeType={mimeType}
            inlineThumbnail={inlineThumbnail}
          />
        </div>
      )}
      <div style={{ padding: "8px 10px" }}>
        <div style={{
          fontSize: "10px",
          fontWeight: 300,
          color: ink.tertiary,
          marginBottom: "2px",
          textTransform: "uppercase",
          letterSpacing: "0.04em",
        }}>
          {domain}
        </div>
        {title && (
          <div style={{
            fontSize: "13px",
            fontWeight: 400,
            color: ink.primary,
            lineHeight: "16px",
            overflow: "hidden",
            display: "-webkit-box",
            WebkitLineClamp: 2,
            WebkitBoxOrient: "vertical",
          }}>
            {title}
          </div>
        )}
        {description && (
          <div style={{
            fontSize: "11px",
            fontWeight: 300,
            color: ink.secondary,
            lineHeight: "14px",
            marginTop: "2px",
            overflow: "hidden",
            display: "-webkit-box",
            WebkitLineClamp: 2,
            WebkitBoxOrient: "vertical",
          }}>
            {description}
          </div>
        )}
      </div>
    </div>
  );
}
