"use client";

import { useState, useRef } from "react";
import { uploadMedia } from "@/lib/media";
import { colors, text, textColor } from "@/lib/theme";

interface MediaUploadProps {
  spaceId: string;
  userId: string;
  onUpload?: () => void;
}

export function MediaUpload({ spaceId, userId, onUpload }: MediaUploadProps) {
  const [uploading, setUploading] = useState(false);
  const [caption, setCaption] = useState("");
  const [showCaption, setShowCaption] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);
  const pendingFile = useRef<File | null>(null);

  async function handleFile(file: File) {
    if (file.size > 5 * 1024 * 1024) {
      console.warn("File too large (max 5MB)");
      return;
    }
    pendingFile.current = file;
    setShowCaption(true);
  }

  async function handleUpload() {
    const file = pendingFile.current;
    if (!file) return;
    setUploading(true);
    await uploadMedia(file, spaceId, userId, caption || undefined);
    setUploading(false);
    setCaption("");
    setShowCaption(false);
    pendingFile.current = null;
    onUpload?.();
  }

  return (
    <div>
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleFile(file);
          e.target.value = "";
        }}
      />

      {!showCaption && !uploading && (
        <span
          role="button"
          tabIndex={0}
          onClick={() => fileRef.current?.click()}
          onKeyDown={(e) => {
            if (e.key === "Enter") fileRef.current?.click();
          }}
          className="cursor-pointer outline-none"
          style={{
            ...text.hint,
            color: colors.white,
            opacity: 0.35,
            transition: "opacity 0.3s ease",
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.opacity = "0.6";
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.opacity = "0.35";
          }}
        >
          add photo
        </span>
      )}

      {showCaption && !uploading && (
        <div className="flex items-center gap-4">
          <input
            type="text"
            value={caption}
            onChange={(e) => setCaption(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleUpload();
            }}
            placeholder="caption (optional)"
            className="bg-transparent outline-none"
            style={{
              ...text.input,
              color: colors.white,
              caretColor: colors.cyan,
              borderBottom: `1px solid ${textColor(0.1)}`,
            }}
            autoFocus
          />
          <span
            role="button"
            tabIndex={0}
            onClick={handleUpload}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleUpload();
            }}
            className="cursor-pointer outline-none"
            style={{
              ...text.hint,
              color: colors.cyan,
              opacity: 0.6,
            }}
          >
            upload
          </span>
          <span
            role="button"
            tabIndex={0}
            onClick={() => {
              setShowCaption(false);
              pendingFile.current = null;
              setCaption("");
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                setShowCaption(false);
                pendingFile.current = null;
                setCaption("");
              }
            }}
            className="cursor-pointer outline-none"
            style={{
              ...text.hint,
              color: colors.white,
              opacity: 0.2,
            }}
          >
            cancel
          </span>
        </div>
      )}

      {uploading && (
        <div className="flex items-center gap-3">
          <div
            style={{
              width: "6px",
              height: "6px",
              borderRadius: "50%",
              backgroundColor: colors.cyan,
              animation: "ambientBreath 4.5s ease-in-out infinite",
            }}
          />
          <span
            style={{
              ...text.hint,
              color: colors.white,
              opacity: 0.4,
            }}
          >
            uploading
          </span>
        </div>
      )}
    </div>
  );
}
