"use client";

// hello OS v2.0 — Encrypted Media Renderer
// Downloads encrypted blob from Firebase, decrypts with AES-GCM key from E2EE channel,
// renders as <img> or <video>. Revokes object URL on unmount to prevent memory leaks.
// Phase 4: Shows blurry inline thumbnail while full blob downloads + decrypts.

import { useState, useEffect, useRef } from "react";

interface EncryptedMediaRendererProps {
  mediaUrl: string;
  aesKeyBase64: string;
  ivBase64: string;
  mimeType: string;
  inlineThumbnail?: string;
  /** When true, fills parent container (absolute inset-0, object-fit cover). Used by DecisionCard. */
  fillContainer?: boolean;
}

export function EncryptedMediaRenderer({
  mediaUrl,
  aesKeyBase64,
  ivBase64,
  mimeType,
  inlineThumbnail,
  fillContainer = false,
}: EncryptedMediaRendererProps) {
  const [objectUrl, setObjectUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const objectUrlRef = useRef<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      try {
        // Download encrypted blob from Firebase
        const res = await fetch(mediaUrl);
        if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
        const encryptedBlob = await res.blob();

        if (cancelled) return;

        // Decrypt with AES key from E2EE channel
        const { decryptFile } = await import("@/lib/crypto/file-encryption");
        const url = await decryptFile(encryptedBlob, aesKeyBase64, ivBase64, mimeType);

        if (cancelled) {
          URL.revokeObjectURL(url);
          return;
        }

        objectUrlRef.current = url;
        setObjectUrl(url);
        setLoading(false);
      } catch (err) {
        console.warn("[encrypted-media] Decrypt failed:", err);
        if (!cancelled) {
          setError(true);
          setLoading(false);
        }
      }
    })();

    return () => {
      cancelled = true;
      // CRITICAL: revoke object URL on unmount to prevent memory leaks
      if (objectUrlRef.current) {
        URL.revokeObjectURL(objectUrlRef.current);
        objectUrlRef.current = null;
      }
    };
  }, [mediaUrl, aesKeyBase64, ivBase64, mimeType]);

  // ── Shared style for fillContainer vs chat bubble mode ──
  const containerStyle = fillContainer
    ? { position: "absolute" as const, inset: 0 }
    : { width: "100%", maxWidth: "260px" };

  const imgStyle = fillContainer
    ? { width: "100%", height: "100%", objectFit: "cover" as const, display: "block" as const }
    : { width: "100%", borderRadius: "12px", display: "block" as const };

  // ── Loading state: blurry thumbnail preview or skeleton ──
  if (loading) {
    if (inlineThumbnail) {
      return (
        <div style={{ position: "relative", overflow: "hidden", borderRadius: fillContainer ? undefined : "12px", ...containerStyle }}>
          <img
            src={inlineThumbnail}
            alt=""
            style={{
              ...imgStyle,
              filter: "blur(8px)",
              transform: "scale(1.05)",
            }}
          />
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              background: "rgba(0,0,0,0.15)",
            }}
          >
            <span style={{ fontSize: "11px", fontWeight: 300, color: "rgba(255,255,255,0.9)", letterSpacing: "0.02em" }}>
              decrypting...
            </span>
          </div>
        </div>
      );
    }

    return (
      <div
        style={{
          ...containerStyle,
          ...(fillContainer ? {} : { aspectRatio: "4/3" }),
          borderRadius: fillContainer ? undefined : "12px",
          background: "rgba(128,128,128,0.1)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <span style={{ fontSize: "12px", fontWeight: 300, color: "var(--hello-ink-tertiary)", letterSpacing: "0.02em" }}>
          decrypting media...
        </span>
      </div>
    );
  }

  if (error || !objectUrl) {
    return (
      <div
        style={{
          ...containerStyle,
          ...(fillContainer ? { display: "flex", alignItems: "center", justifyContent: "center" } : { padding: "12px" }),
          borderRadius: fillContainer ? undefined : "12px",
          background: "rgba(128,128,128,0.08)",
          ...(fillContainer ? {} : { display: "flex", alignItems: "center", gap: "6px" }),
        }}
      >
        <svg width="14" height="14" viewBox="0 0 12 12" fill="none" style={{ flexShrink: 0, opacity: 0.4 }}>
          <rect x="1" y="5" width="10" height="6.5" rx="1.5" stroke="currentColor" strokeWidth="1" />
          <path d="M3.5 5V3.5C3.5 2.12 4.4 1 5.9 1C7.4 1 8.5 2.12 8.5 3.5V5" stroke="currentColor" strokeWidth="1" strokeLinecap="round" />
        </svg>
        <span style={{ fontSize: "12px", fontWeight: 300, color: "var(--hello-ink-tertiary)" }}>
          media unavailable
        </span>
      </div>
    );
  }

  const isVideo = mimeType.startsWith("video/");

  if (isVideo) {
    return (
      <video
        src={objectUrl}
        controls
        playsInline
        preload="metadata"
        style={fillContainer
          ? { width: "100%", height: "100%", objectFit: "cover", display: "block" }
          : { width: "100%", maxWidth: "260px", borderRadius: "12px", display: "block" }
        }
      />
    );
  }

  return (
    <img
      src={objectUrl}
      alt=""
      loading="lazy"
      style={fillContainer
        ? { width: "100%", height: "100%", objectFit: "cover", display: "block" }
        : { width: "100%", maxWidth: "260px", borderRadius: "12px", display: "block" }
      }
    />
  );
}
