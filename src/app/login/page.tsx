"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";

import { colors, opacity, timing, text } from "@/lib/theme";
import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { supabase } from "@/lib/supabase";

export default function LoginPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [phase, setPhase] = useState<"arrive" | "input" | "photo" | "transit">("arrive");
  const [mounted, setMounted] = useState(false);
  const [photoUploading, setPhotoUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setMounted(true);
    const t = setTimeout(() => setPhase("input"), 1800);
    return () => clearTimeout(t);
  }, []);

  // The Exhale — transit phase triggers redirect to Galaxy after 1.2s
  useEffect(() => {
    if (phase !== "transit") return;
    const t = setTimeout(() => {
      router.push(`/galaxy?name=${encodeURIComponent(name.trim())}`);
    }, 1200);
    return () => clearTimeout(t);
  }, [phase, name, router]);

  const handleEnter = useCallback(() => {
    if (name.trim().length > 0) {
      setPhase("photo");
    }
  }, [name]);

  const handleSkipPhoto = useCallback(() => {
    setPhase("transit");
  }, []);

  const handlePhotoSelect = useCallback(async (file: File) => {
    if (!storage) {
      setPhase("transit");
      return;
    }
    // Max 2MB
    if (file.size > 2 * 1024 * 1024) {
      console.warn("Photo too large (max 2MB)");
      setPhase("transit");
      return;
    }
    setPhotoUploading(true);
    try {
      const userId = `name_${name.trim().toLowerCase()}`;
      const storagePath = `profiles/${userId}/avatar`;
      const storageRef = ref(storage, storagePath);
      await uploadBytes(storageRef, file);
      const downloadUrl = await getDownloadURL(storageRef);
      // Save to users.photo_url in Supabase
      await supabase
        .from("users")
        .update({ photo_url: downloadUrl })
        .eq("id", userId);
    } catch (err) {
      console.error("Photo upload failed:", err);
    }
    setPhotoUploading(false);
    setPhase("transit");
  }, [name]);

  return (
    <div className="relative flex min-h-svh flex-col items-center justify-center overflow-hidden px-6">
      {/* ── Atmospheric Depth Layer ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background:
            "radial-gradient(ellipse 60% 50% at 50% 45%, rgba(var(--xark-accent-rgb), 0.03) 0%, transparent 70%)",
        }}
      />

      {/* ── Ambient Orb — breathes behind wordmark ── */}
      <div
        className="pointer-events-none absolute"
        style={{
          width: "500px",
          height: "500px",
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(var(--xark-accent-rgb), 0.04) 0%, transparent 60%)",
          animation: "orbBreathe 4.5s ease-in-out infinite",
          top: "50%",
          left: "50%",
          transform: "translate(-50%, -55%)",
        }}
      />

      {/* ── Wordmark — Inter light, scale = hierarchy ── */}
      <h1
        className="relative"
        style={{
          fontFamily: "var(--font-inter), sans-serif",
          fontWeight: 300,
          fontSize: "clamp(3.5rem, 8vw, 6rem)",
          letterSpacing: "-0.03em",
          color: colors.white,
          opacity: mounted ? 0.9 : 0,
          transform: mounted ? "translateY(0)" : "translateY(12px)",
          transition: "opacity 1.4s cubic-bezier(0.16, 1, 0.3, 1), transform 1.4s cubic-bezier(0.16, 1, 0.3, 1)",
        }}
      >
        xark
      </h1>

      {/* ── Brand Line ── */}
      <p
        className="relative mt-6"
        style={{
          fontSize: "clamp(0.95rem, 2.2vw, 1.15rem)",
          letterSpacing: "0.08em",
          color: colors.white,
          opacity: mounted ? 0.45 : 0,
          transform: mounted ? "translateY(0)" : "translateY(8px)",
          transition:
            "opacity 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.3s, transform 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.3s",
        }}
      >
        People. Plans. Memories.
      </p>

      {/* ── Sub-line ── */}
      <p
        className="relative mt-2"
        style={{
          fontSize: "clamp(0.65rem, 1.5vw, 0.8rem)",
          letterSpacing: "0.15em",
          color: colors.white,
          opacity: mounted ? 0.2 : 0,
          transform: mounted ? "translateY(0)" : "translateY(6px)",
          transition:
            "opacity 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.5s, transform 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.5s",
        }}
      >
        All private, effortlessly in sync.
      </p>

      {/* ── Input Phase ── */}
      {phase !== "transit" && phase !== "photo" && (
        <div
          className="relative mt-20 flex flex-col items-center"
          style={{
            opacity: phase === "input" ? 1 : 0,
            transform:
              phase === "input" ? "translateY(0)" : "translateY(16px)",
            transition:
              "opacity 1s cubic-bezier(0.16, 1, 0.3, 1), transform 1s cubic-bezier(0.16, 1, 0.3, 1)",
          }}
        >
          <div className="relative">
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") handleEnter();
              }}
              placeholder="your name"
              autoFocus
              spellCheck={false}
              autoComplete="off"
              className="bg-transparent text-center outline-none"
              style={{
                fontSize: "clamp(1.25rem, 3vw, 1.75rem)",
                letterSpacing: "0.08em",
                color: colors.white,
                caretColor: colors.cyan,
                width: "280px",
              }}
            />
            {/* ── Cyan Underline Breath ── */}
            <div
              className="absolute -bottom-3 left-1/2 h-px"
              style={{
                width: "60px",
                transform: "translateX(-50%)",
                background:
                  `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                animation: "ambientBreath 4.5s ease-in-out infinite",
              }}
            />
          </div>

          {/* ── Enter ── */}
          <button
            onClick={handleEnter}
            disabled={!name.trim()}
            className="mt-12 uppercase transition-all duration-700"
            style={{
              fontSize: "0.7rem",
              letterSpacing: "0.3em",
              color: colors.cyan,
              background: "transparent",
              border: "none",
              opacity: name.trim() ? 0.6 : 0.08,
              cursor: name.trim() ? "pointer" : "default",
              transform: name.trim() ? "translateY(0)" : "translateY(4px)",
            }}
            onMouseEnter={(e) => {
              if (name.trim()) e.currentTarget.style.opacity = "1";
            }}
            onMouseLeave={(e) => {
              if (name.trim()) e.currentTarget.style.opacity = "0.6";
            }}
          >
            enter
          </button>

          {/* ── Privacy Signal ── */}
          <div
            className="mt-16 flex items-center gap-2"
            style={{
              opacity: phase === "input" ? 0.2 : 0,
              transition: "opacity 1.6s ease 1.2s",
            }}
          >
            <svg
              width="12"
              height="12"
              viewBox="0 0 12 12"
              fill="none"
            >
              <path
                d="M6 1L3 3.5V5.5C3 7.98 4.28 10.28 6 11C7.72 10.28 9 7.98 9 5.5V3.5L6 1Z"
                stroke={colors.white}
                strokeWidth="0.8"
                strokeLinejoin="round"
              />
            </svg>
            <span
              style={{
                fontSize: "0.6rem",
                letterSpacing: "0.15em",
                color: colors.white,
                opacity: 0.9,
                textTransform: "uppercase" as const,
              }}
            >
              end-to-end encrypted
            </span>
          </div>
        </div>
      )}

      {/* ── Photo Phase — Optional profile photo ── */}
      {phase === "photo" && (
        <div
          className="mt-20 flex flex-col items-center"
          style={{
            animation: "revealUp 1.6s cubic-bezier(0.16, 1, 0.3, 1) forwards",
          }}
        >
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handlePhotoSelect(file);
              e.target.value = "";
            }}
          />

          {!photoUploading ? (
            <>
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
                add a photo
              </span>

              <span
                role="button"
                tabIndex={0}
                onClick={handleSkipPhoto}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleSkipPhoto();
                }}
                className="mt-6 cursor-pointer outline-none"
                style={{
                  ...text.hint,
                  color: colors.white,
                  opacity: 0.2,
                  transition: "opacity 0.3s ease",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.opacity = "0.35";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.opacity = "0.2";
                }}
              >
                skip
              </span>
            </>
          ) : (
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
      )}

      {/* ── Transit Phase — Welcome ── */}
      {phase === "transit" && (
        <div
          className="mt-20 flex flex-col items-center"
          style={{
            animation: "revealUp 1.6s cubic-bezier(0.16, 1, 0.3, 1) forwards",
          }}
        >
          <p
            style={{
              fontSize: "clamp(1.25rem, 3vw, 1.75rem)",
              letterSpacing: "0.04em",
              color: colors.white,
              opacity: 0.7,
            }}
          >
            welcome, {name.trim()}.
          </p>

          {/* ── Cyan pulse dot ── */}
          <div
            className="mt-8"
            style={{
              width: "4px",
              height: "4px",
              borderRadius: "50%",
              backgroundColor: colors.cyan,
              animation: "ambientBreath 4.5s ease-in-out infinite",
            }}
          />
        </div>
      )}

      <style jsx>{`
        input::placeholder {
          color: ${colors.white};
          opacity: 0.15;
          letter-spacing: 0.12em;
        }
        input:focus::placeholder {
          opacity: 0;
          transition: opacity 0.8s ease;
        }
        @keyframes orbBreathe {
          0%, 100% {
            opacity: 0.4;
            transform: translate(-50%, -55%) scale(1);
          }
          50% {
            opacity: 0.8;
            transform: translate(-50%, -55%) scale(1.08);
          }
        }
        @keyframes revealUp {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </div>
  );
}
