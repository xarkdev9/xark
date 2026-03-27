"use client";

// hello OS v2.0 — Add Decision Item Modal
// Screenshot/image → E2EE encrypt → Firebase upload → decision_items insert.
// Supports file picker, camera capture, and CMD+V paste from clipboard.

import { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, ink, text, surface } from "@/lib/theme";

interface AddItemModalProps {
  open: boolean;
  onClose: () => void;
  groupId: string;
  userId?: string;
  e2eeAvailable: boolean;
  e2eeDeviceId: number | null;
  encrypt: (text: string, groupId: string, media?: {
    mediaUrl: string; aesKeyBase64: string; ivBase64: string; mimeType: string; inlineThumbnail?: string;
  }) => Promise<unknown>;
}

export function AddItemModal({
  open,
  onClose,
  groupId,
  userId,
  e2eeAvailable,
  e2eeDeviceId,
  encrypt,
}: AddItemModalProps) {
  const [title, setTitle] = useState("");
  const [category, setCategory] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const titleRef = useRef<HTMLInputElement>(null);

  // Focus title input on open
  useEffect(() => {
    if (open) {
      setTimeout(() => titleRef.current?.focus(), 200);
    }
  }, [open]);

  // Clean up preview URL on unmount or file change
  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  // Handle file selection (from picker or paste)
  const handleFile = useCallback((f: File) => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setFile(f);
    setPreviewUrl(URL.createObjectURL(f));
    setError(null);
    // Auto-fill title from filename if empty
    if (!title) {
      const name = f.name.replace(/\.[^.]+$/, '').replace(/[-_]/g, ' ');
      if (name && name !== 'image') setTitle(name);
    }
  }, [previewUrl, title]);

  // Clipboard paste listener
  useEffect(() => {
    if (!open) return;
    const handler = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;
      for (const item of items) {
        if (item.type.startsWith('image/')) {
          const blob = item.getAsFile();
          if (blob) {
            e.preventDefault();
            handleFile(blob);
          }
          break;
        }
      }
    };
    document.addEventListener('paste', handler);
    return () => document.removeEventListener('paste', handler);
  }, [open, handleFile]);

  // Reset state on close
  useEffect(() => {
    if (!open) {
      setTitle("");
      setCategory("");
      setFile(null);
      if (previewUrl) URL.revokeObjectURL(previewUrl);
      setPreviewUrl(null);
      setError(null);
      setSaving(false);
    }
  }, [open]);

  const handleSubmit = async () => {
    console.log("[add-item] Submit clicked", { hasFile: !!file, title: title.trim(), e2eeAvailable, userId });
    if (!file || !title.trim()) {
      setError(!file ? "add a photo" : "add a title");
      return;
    }
    if (!e2eeAvailable || !userId) {
      console.warn("[add-item] Blocked:", { e2eeAvailable, userId });
      setError(e2eeAvailable ? "not logged in" : "encryption not ready — try again");
      return;
    }

    setSaving(true);
    setError(null);

    try {
      console.log("[add-item] Starting encryption pipeline...");
      const mimeType = file.type || 'application/octet-stream';

      // Generate inline thumbnail
      const { generateInlineThumbnail } = await import("@/lib/media/thumbnail-generator");
      const inlineThumbnail = await generateInlineThumbnail(file);
      console.log("[add-item] Thumbnail generated");

      // Encrypt the image
      const { encryptFile } = await import("@/lib/crypto/file-encryption");
      const { encryptedBlob, aesKeyBase64, ivBase64 } = await encryptFile(file);

      // Upload encrypted blob to Firebase
      const { storageAdapter } = await import("@/lib/storage");
      const mediaId = `decide_${crypto.randomUUID()}`;
      const storagePath = `spaces/${groupId}/media/${mediaId}.enc`;
      const downloadUrl = await storageAdapter.upload(storagePath, encryptedBlob, 'application/octet-stream');

      console.log("[add-item] Encrypted + uploaded to Firebase:", downloadUrl.slice(0, 60));

      // Build encrypted image payload
      const encryptedImage = {
        mediaUrl: downloadUrl,
        aesKeyBase64,
        ivBase64,
        mimeType,
        ...(inlineThumbnail && { inlineThumbnail }),
      };

      // Insert decision item with encrypted image metadata
      const { getSupabaseToken } = await import("@/lib/supabase");
      const { supabase } = await import("@/lib/supabase");
      const token = getSupabaseToken();

      const itemId = `item_${crypto.randomUUID()}`;
      const { error: insertError } = await supabase.from("decision_items").insert({
        id: itemId,
        group_id: groupId,
        title: title.trim(),
        category: category.trim().toLowerCase() || "shared",
        state: "proposed",
        proposed_by: userId,
        metadata: {
          encrypted_image: JSON.stringify(encryptedImage),
          source: "screenshot",
        },
      });

      if (insertError) {
        console.error("[add-item] Supabase insert error:", insertError.message);
        throw new Error(insertError.message);
      }

      console.log("[add-item] Success! Item inserted:", itemId);
      onClose();
    } catch (err) {
      console.error("[add-item] Failed:", err);
      setError("upload failed — try again");
      setSaving(false);
    }
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Overlay */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={onClose}
            style={{
              position: "fixed",
              inset: 0,
              background: "rgba(0,0,0,0.8)",
              zIndex: 70,
            }}
          />

          {/* Modal — centered via inset + margin auto (avoids Framer transform conflict) */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 40 }}
            transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            style={{
              position: "fixed",
              inset: 0,
              margin: "auto",
              width: "min(340px, calc(100vw - 48px))",
              height: "fit-content",
              maxHeight: "calc(100dvh - 80px)",
              overflowY: "auto",
              background: surface.chrome,
              borderRadius: "20px",
              padding: "20px",
              zIndex: 71,
            }}
          >
            {/* Header */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
              <span style={{ fontSize: "16px", fontWeight: 400, color: ink.primary }}>
                add to decide
              </span>
              <button
                onClick={onClose}
                style={{ background: "none", border: "none", fontSize: "20px", color: ink.tertiary, cursor: "pointer", padding: "4px", lineHeight: 1 }}
              >
                &times;
              </button>
            </div>

            {/* Image Drop Zone / Preview */}
            <input
              ref={fileRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) handleFile(f);
                e.target.value = "";
              }}
            />

            {previewUrl ? (
              <div
                onClick={() => fileRef.current?.click()}
                style={{
                  width: "100%",
                  aspectRatio: "16/10",
                  borderRadius: "12px",
                  overflow: "hidden",
                  cursor: "pointer",
                  position: "relative",
                  marginBottom: "12px",
                }}
              >
                <img
                  src={previewUrl}
                  alt=""
                  style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
                />
                <div style={{
                  position: "absolute",
                  bottom: "8px",
                  right: "8px",
                  background: "rgba(0,0,0,0.5)",
                  borderRadius: "6px",
                  padding: "2px 8px",
                  fontSize: "10px",
                  fontWeight: 300,
                  color: "rgba(255,255,255,0.8)",
                }}>
                  tap to change
                </div>
              </div>
            ) : (
              <div
                onClick={() => fileRef.current?.click()}
                style={{
                  width: "100%",
                  aspectRatio: "16/10",
                  borderRadius: "12px",
                  border: "1.5px dashed rgba(128,128,128,0.25)",
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: "6px",
                  cursor: "pointer",
                  marginBottom: "12px",
                  background: surface.recessed,
                }}
              >
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={ink.tertiary} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.5 }}>
                  <rect x="3" y="3" width="18" height="18" rx="2" />
                  <circle cx="8.5" cy="8.5" r="1.5" />
                  <path d="M21 15l-5-5L5 21" />
                </svg>
                <span style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary }}>
                  tap to add photo or paste screenshot
                </span>
              </div>
            )}

            {/* Title Input */}
            <input
              ref={titleRef}
              value={title}
              onChange={(e) => { setTitle(e.target.value); setError(null); }}
              onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSubmit(); } }}
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
                marginBottom: "12px",
              }}
            />

            {/* Category Input (free-form) */}
            <input
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              placeholder="category (e.g. hotels, decorations)"
              style={{
                width: "100%",
                background: surface.recessed,
                border: "none",
                borderRadius: "10px",
                padding: "10px 14px",
                fontSize: "13px",
                fontWeight: 300,
                color: ink.primary,
                outline: "none",
                marginBottom: "12px",
              }}
            />

            {/* Error */}
            {error && (
              <p style={{ fontSize: "12px", fontWeight: 300, color: colors.orange, marginBottom: "8px" }}>
                {error}
              </p>
            )}

            {/* Submit */}
            <button
              onClick={handleSubmit}
              disabled={saving || !file || !title.trim()}
              style={{
                width: "100%",
                padding: "12px",
                borderRadius: "12px",
                border: "none",
                background: saving || !file || !title.trim() ? "rgba(128,128,128,0.15)" : colors.accent,
                color: saving || !file || !title.trim() ? ink.tertiary : "#fff",
                fontSize: "14px",
                fontWeight: 400,
                cursor: saving ? "wait" : "pointer",
                transition: "background 0.2s",
              }}
            >
              {saving ? "encrypting & uploading..." : "add to decide"}
            </button>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
