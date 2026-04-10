"use client";

// hello OS v2.0 — Share Target Page
// Handles two share paths:
// 1. URL/text share: redirected from /api/share with query params
// 2. File share: intercepted by SW, file stashed in CacheStorage, read client-side
// Files go through the full E2EE pipeline (encrypt → Firebase → decision_items).

import { useSearchParams, useRouter } from "next/navigation";
import { Suspense, useState, useEffect, useRef } from "react";
import { SpacePicker } from "@/components/os/SpacePicker";
import { colors, text, ink, surface } from "@/lib/theme";
import { getSupabaseToken } from "@/lib/supabase";
import { useAuth } from "@/hooks/useAuth";
import { useE2EE } from "@/hooks/useE2EE";

function ShareContent() {
  const params = useSearchParams();
  const router = useRouter();
  const [saving, setSaving] = useState(false);

  const title = params.get("title") || "";
  const sharedText = params.get("text") || "";
  const url = params.get("url") || "";
  const hasLocalFile = params.get("has_local_file") === "true";

  // ── File share state ──
  const [sharedFile, setSharedFile] = useState<File | null>(null);
  const [filePreviewUrl, setFilePreviewUrl] = useState<string | null>(null);
  const [itemTitle, setItemTitle] = useState(title || "");
  const fileLoaded = useRef(false);

  // Auth + E2EE (needed for file encryption)
  const { user } = useAuth();
  const resolvedUserId = user?.uid ?? undefined;
  const e2ee = useE2EE(resolvedUserId ?? null);

  // ── Read shared file from CacheStorage (placed there by SW) ──
  useEffect(() => {
    if (!hasLocalFile || fileLoaded.current) return;
    fileLoaded.current = true;

    (async () => {
      try {
        const cache = await caches.open("hello-shared-files");
        const res = await cache.match("/shared-image");
        if (!res) return;

        const blob = await res.blob();
        const filename = decodeURIComponent(
          res.headers.get("X-Filename") || "shared.jpg"
        );
        const file = new File([blob], filename, { type: blob.type });

        setSharedFile(file);
        setFilePreviewUrl(URL.createObjectURL(file));

        // Auto-fill title from filename if empty
        if (!itemTitle) {
          const name = filename.replace(/\.[^.]+$/, "").replace(/[-_]/g, " ");
          if (name && name !== "shared") setItemTitle(name);
        }

        // Clean up the cache entry
        await cache.delete("/shared-image");
      } catch (err) {
        console.warn("[share] Failed to read shared file from cache:", err);
      }
    })();
  }, [hasLocalFile, itemTitle]);

  // Clean up preview URL on unmount
  useEffect(() => {
    return () => {
      if (filePreviewUrl) URL.revokeObjectURL(filePreviewUrl);
    };
  }, [filePreviewUrl]);

  // ── URL/text share handler (existing flow) ──
  const handleUrlShare = async (spaceId: string) => {
    setSaving(true);
    try {
      const token = getSupabaseToken();
      await fetch("/api/og", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          url,
          title: title || sharedText.slice(0, 100),
          text: sharedText,
          spaceId,
          insertAsItem: true,
        }),
      });
    } catch { /* proceed to space regardless */ }
    router.push(`/space/${spaceId}`);
  };

  // ── File share handler (E2EE pipeline) ──
  const handleFileShare = async (spaceId: string) => {
    if (!sharedFile || !resolvedUserId || !e2ee.available) return;
    setSaving(true);

    try {
      const mimeType = sharedFile.type || "application/octet-stream";

      // Generate inline thumbnail
      const { generateInlineThumbnail } = await import("@/lib/media/thumbnail-generator");
      const inlineThumbnail = await generateInlineThumbnail(sharedFile);

      // Encrypt the file
      const { encryptFile } = await import("@/lib/crypto/file-encryption");
      const { encryptedBlob, aesKeyBase64, ivBase64 } = await encryptFile(sharedFile);

      // Upload encrypted blob to Firebase
      const { storageAdapter } = await import("@/lib/storage");
      const mediaId = `share_${crypto.randomUUID()}`;
      const storagePath = `spaces/${spaceId}/media/${mediaId}.enc`;
      const downloadUrl = await storageAdapter.upload(storagePath, encryptedBlob, "application/octet-stream");

      // Build encrypted image payload
      const encryptedImage = {
        mediaUrl: downloadUrl,
        aesKeyBase64,
        ivBase64,
        mimeType,
        ...(inlineThumbnail && { inlineThumbnail }),
      };

      // Insert as decision item
      const { supabase } = await import("@/lib/supabase");
      const itemId = `item_${crypto.randomUUID()}`;
      await supabase.from("decision_items").insert({
        id: itemId,
        space_id: spaceId,
        title: itemTitle.trim() || sharedFile.name || "shared item",
        category: "shared",
        state: "proposed",
        proposed_by: resolvedUserId,
        metadata: {
          encrypted_image: JSON.stringify(encryptedImage),
          source: "share_target",
        },
      });
    } catch (err) {
      console.warn("[share] E2EE upload failed:", err);
    }

    router.push(`/space/${spaceId}?view=decide`);
  };

  // ── File share UI ──
  if (hasLocalFile) {
    return (
      <div style={{ minHeight: "100dvh", background: colors.void }}>
        <div style={{ padding: "calc(env(safe-area-inset-top, 0px) + 48px) 24px 16px" }}>
          <p style={{ fontSize: "16px", fontWeight: 400, color: ink.primary, marginBottom: "16px" }}>
            add to decide
          </p>

          {/* Image preview */}
          {filePreviewUrl ? (
            <div style={{
              width: "100%",
              aspectRatio: "16/10",
              borderRadius: "12px",
              overflow: "hidden",
              marginBottom: "12px",
            }}>
              <img
                src={filePreviewUrl}
                alt=""
                style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
              />
            </div>
          ) : (
            <div style={{
              width: "100%",
              aspectRatio: "16/10",
              borderRadius: "12px",
              background: surface.recessed,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              marginBottom: "12px",
            }}>
              <span style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary }}>
                loading image...
              </span>
            </div>
          )}

          {/* Title input */}
          <input
            value={itemTitle}
            onChange={(e) => setItemTitle(e.target.value)}
            placeholder="what is this?"
            style={{
              width: "100%",
              background: surface.recessed,
              border: "none",
              borderRadius: "10px",
              padding: "10px 14px",
              fontSize: "15px",
              fontWeight: 400,
              color: ink.primary,
              outline: "none",
              marginBottom: "16px",
            }}
          />

          {/* E2EE status */}
          {!e2ee.available && (
            <p style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary, marginBottom: "8px" }}>
              initializing encryption...
            </p>
          )}

          {saving && (
            <p style={{ ...text.recency, color: ink.tertiary, marginBottom: "8px" }}>
              encrypting & uploading...
            </p>
          )}

          <p style={{ fontSize: "13px", fontWeight: 300, color: ink.tertiary, marginBottom: "8px" }}>
            pick a space
          </p>
        </div>

        {!saving && (
          <SpacePicker onSelect={(spaceId) => handleFileShare(spaceId)} />
        )}
      </div>
    );
  }

  // ── URL/text share UI (existing) ──
  return (
    <div style={{ minHeight: "100dvh", background: colors.void }}>
      <div style={{ padding: "calc(env(safe-area-inset-top, 0px) + 48px) 24px 16px" }}>
        <p style={{ ...text.body, color: ink.primary }}>
          {url ? `sharing: ${title || url}` : `sharing: ${title || sharedText.slice(0, 50)}`}
        </p>
        {saving && (
          <p style={{ ...text.recency, color: ink.tertiary, marginTop: 8 }}>
            adding...
          </p>
        )}
      </div>
      {!saving && <SpacePicker onSelect={(spaceId) => handleUrlShare(spaceId)} />}
    </div>
  );
}

export default function SharePage() {
  return (
    <Suspense>
      <ShareContent />
    </Suspense>
  );
}
