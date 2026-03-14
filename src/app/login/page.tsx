"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { RecaptchaVerifier, signInWithPhoneNumber, type ConfirmationResult } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { supabase } from "@/lib/supabase";
import { setSupabaseToken } from "@/lib/supabase";
import { colors, text, timing } from "@/lib/theme";

type Phase = "arrive" | "input" | "name" | "photo" | "transit";
type PhoneStep = "phone" | "otp" | "sending" | "verifying";

// ── Arrow icon ──
function ArrowIcon({ color, size = 20 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="5" y1="12" x2="19" y2="12" />
      <polyline points="12 5 19 12 12 19" />
    </svg>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const [phoneInput, setPhoneInput] = useState("");
  const [phoneStep, setPhoneStep] = useState<PhoneStep>("phone");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [authError, setAuthError] = useState("");
  const [phase, setPhase] = useState<Phase>("arrive");
  const [mounted, setMounted] = useState(false);
  const [photoUploading, setPhotoUploading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const recaptchaRef = useRef<RecaptchaVerifier | null>(null);
  const phoneNumberRef = useRef("");

  // Phone auth in production, dev auth when DEV_MODE=true
  const isDevMode = process.env.NEXT_PUBLIC_DEV_MODE === "true";
  const [authMode, setAuthMode] = useState<"phone" | "dev">(isDevMode ? "dev" : "phone");
  const usePhoneAuth = authMode === "phone" && !!auth;

  useEffect(() => {
    setMounted(true);
    const t = setTimeout(() => setPhase("input"), 1800);
    return () => clearTimeout(t);
  }, []);

  // Transit phase → redirect to Galaxy
  useEffect(() => {
    if (phase !== "transit") return;
    const t = setTimeout(() => {
      router.push(`/galaxy?name=${encodeURIComponent(name.trim())}`);
    }, 1200);
    return () => clearTimeout(t);
  }, [phase, name, router]);

  // ── Phone Auth: Send OTP ──
  const sendOtp = useCallback(async () => {
    if (!auth || !phoneInput.trim()) return;
    setAuthError("");
    setPhoneStep("sending");

    try {
      if (!recaptchaRef.current) {
        recaptchaRef.current = new RecaptchaVerifier(auth, "recaptcha-container", {
          size: "invisible",
        });
      }

      const formattedPhone = phoneInput.startsWith("+") ? phoneInput : `+1${phoneInput.replace(/\D/g, "")}`;
      phoneNumberRef.current = formattedPhone;
      const result = await signInWithPhoneNumber(auth, formattedPhone, recaptchaRef.current);
      confirmationRef.current = result;
      setPhoneInput("");
      setPhoneStep("otp");
      // Refocus the input after clearing
      setTimeout(() => inputRef.current?.focus(), 50);
    } catch (err) {
      const message = err instanceof Error ? err.message : "";
      setAuthError(message.includes("too-many-requests")
        ? "too many attempts. wait a moment."
        : "could not send code. check the number.");
      setPhoneStep("phone");
    }
  }, [phoneInput]);

  // ── Phone Auth: Verify OTP ──
  const verifyOtp = useCallback(async () => {
    if (!confirmationRef.current || !phoneInput.trim()) return;
    setAuthError("");
    setPhoneStep("verifying");

    try {
      const userCredential = await confirmationRef.current.confirm(phoneInput.trim());
      const firebaseToken = await userCredential.user.getIdToken();

      const res = await fetch("/api/phone-auth", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          firebaseToken,
          displayName: userCredential.user.displayName ?? undefined,
        }),
      });

      if (!res.ok) {
        setAuthError("verification failed. try again.");
        setPhoneStep("otp");
        return;
      }

      const data = await res.json();
      setSupabaseToken(data.token);

      if (typeof window !== "undefined") {
        sessionStorage.setItem("xark_session", JSON.stringify({
          token: data.token,
          user: { uid: data.user.id, displayName: data.user.displayName },
          expiresAt: Date.now() + 23 * 60 * 60 * 1000,
        }));
      }

      setName(data.user.displayName);

      // New user (name is just digits) → ask for name
      if (/^\d+$/.test(data.user.displayName)) {
        setPhase("name");
      } else {
        setPhase("photo");
      }
    } catch {
      setAuthError("wrong code. try again.");
      setPhoneStep("otp");
      setPhoneInput("");
    }
  }, [phoneInput]);

  // ── Unified phone action: send or verify based on step ──
  const handlePhoneAction = useCallback(() => {
    if (phoneStep === "phone") sendOtp();
    else if (phoneStep === "otp") verifyOtp();
  }, [phoneStep, sendOtp, verifyOtp]);

  // ── Save display name for new users ──
  const saveName = useCallback(async () => {
    if (!name.trim()) return;
    const cached = sessionStorage.getItem("xark_session");
    if (cached) {
      try {
        const session = JSON.parse(cached);
        await supabase
          .from("users")
          .update({ display_name: name.trim().toLowerCase() })
          .eq("id", session.user.uid);
        session.user.displayName = name.trim().toLowerCase();
        sessionStorage.setItem("xark_session", JSON.stringify(session));
      } catch {
        // Continue
      }
    }
    setPhase("photo");
  }, [name]);

  // ── Dev Auth ──
  const handleDevEnter = useCallback(() => {
    if (name.trim().length > 0 && password.trim().length > 0) {
      sessionStorage.setItem("xark_pass", password.trim());
      setAuthError("");
      setPhase("photo");
    }
  }, [name, password]);

  const handleSkipPhoto = useCallback(() => setPhase("transit"), []);

  const handlePhotoSelect = useCallback(async (file: File) => {
    if (!storage) { setPhase("transit"); return; }
    if (file.size > 2 * 1024 * 1024) { setPhase("transit"); return; }
    setPhotoUploading(true);
    try {
      const userId = `name_${name.trim().toLowerCase()}`;
      const storageRef = ref(storage, `profiles/${userId}/avatar`);
      await uploadBytes(storageRef, file);
      const downloadUrl = await getDownloadURL(storageRef);
      await supabase.from("users").update({ photo_url: downloadUrl }).eq("id", userId);
    } catch { /* continue */ }
    setPhotoUploading(false);
    setPhase("transit");
  }, [name]);

  // Phone input state
  const isPhoneBusy = phoneStep === "sending" || phoneStep === "verifying";
  const phoneReady = phoneStep === "phone"
    ? phoneInput.trim().length >= 10
    : phoneInput.trim().length === 6;

  return (
    <div className="relative flex min-h-svh flex-col items-center justify-center overflow-hidden px-6">
      <div id="recaptcha-container" />

      {/* ── Atmospheric Depth Layer ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background: "radial-gradient(ellipse 60% 50% at 50% 45%, rgba(var(--xark-accent-rgb), 0.03) 0%, transparent 70%)",
        }}
      />

      {/* ── Ambient Orb ── */}
      <div
        className="pointer-events-none absolute"
        style={{
          width: "500px", height: "500px", borderRadius: "50%",
          background: "radial-gradient(circle, rgba(var(--xark-accent-rgb), 0.04) 0%, transparent 60%)",
          animation: "orbBreathe 4.5s ease-in-out infinite",
          top: "50%", left: "50%", transform: "translate(-50%, -55%)",
        }}
      />

      {/* ── Wordmark ── */}
      <h1
        className="relative"
        style={{
          fontFamily: "var(--font-inter), sans-serif", fontWeight: 300,
          fontSize: "clamp(3.5rem, 8vw, 6rem)", letterSpacing: "-0.03em",
          color: colors.white,
          opacity: mounted ? 0.9 : 0, transform: mounted ? "translateY(0)" : "translateY(12px)",
          transition: "opacity 1.4s cubic-bezier(0.16, 1, 0.3, 1), transform 1.4s cubic-bezier(0.16, 1, 0.3, 1)",
        }}
      >
        xark
      </h1>

      <p className="relative mt-6" style={{
        fontSize: "clamp(0.95rem, 2.2vw, 1.15rem)", letterSpacing: "0.08em", color: colors.white,
        opacity: mounted ? 0.45 : 0, transform: mounted ? "translateY(0)" : "translateY(8px)",
        transition: "opacity 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.3s, transform 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.3s",
      }}>
        People. Plans. Memories.
      </p>

      <p className="relative mt-2" style={{
        fontSize: "clamp(0.65rem, 1.5vw, 0.8rem)", letterSpacing: "0.15em", color: colors.white,
        opacity: mounted ? 0.2 : 0, transform: mounted ? "translateY(0)" : "translateY(6px)",
        transition: "opacity 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.5s, transform 1.4s cubic-bezier(0.16, 1, 0.3, 1) 0.5s",
      }}>
        All private, effortlessly in sync.
      </p>

      {/* ══════════════════════════════════════════
          INPUT PHASE
          ══════════════════════════════════════════ */}
      {phase === "input" && (
        <div
          className="relative mt-20 flex flex-col items-center"
          style={{ animation: "revealUp 1s cubic-bezier(0.16, 1, 0.3, 1) forwards" }}
        >
          {usePhoneAuth ? (
            /* ── Phone: single field, phone → OTP ── */
            <>
              {/* Hint above field */}
              <p style={{
                ...text.hint, color: colors.white,
                opacity: phoneStep === "otp" ? 0.35 : 0,
                height: "20px",
                marginBottom: "8px",
                transition: `opacity ${timing.transition} ease`,
              }}>
                {phoneStep === "otp" ? `code sent to ${phoneNumberRef.current}` : ""}
              </p>

              <div className="relative flex items-center">
                <input
                  ref={inputRef}
                  type={phoneStep === "otp" ? "text" : "tel"}
                  inputMode={phoneStep === "otp" ? "numeric" : "tel"}
                  value={phoneInput}
                  onChange={(e) => {
                    if (phoneStep === "otp") {
                      setPhoneInput(e.target.value.replace(/\D/g, "").slice(0, 6));
                    } else {
                      setPhoneInput(e.target.value);
                    }
                    setAuthError("");
                  }}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" && phoneReady && !isPhoneBusy) handlePhoneAction();
                  }}
                  placeholder={phoneStep === "otp" ? "enter code" : "phone number"}
                  autoFocus
                  spellCheck={false}
                  autoComplete={phoneStep === "otp" ? "one-time-code" : "tel"}
                  disabled={isPhoneBusy}
                  className="bg-transparent text-center outline-none"
                  style={{
                    fontSize: phoneStep === "otp" ? "clamp(1.5rem, 4vw, 2rem)" : "clamp(1.25rem, 3vw, 1.75rem)",
                    letterSpacing: phoneStep === "otp" ? "0.3em" : "0.08em",
                    color: colors.white,
                    caretColor: colors.cyan,
                    width: "240px",
                    opacity: isPhoneBusy ? 0.3 : 1,
                    transition: `opacity ${timing.transition} ease, font-size ${timing.transition} ease, letter-spacing ${timing.transition} ease`,
                  }}
                />

                {/* Arrow button */}
                <span
                  role="button"
                  tabIndex={0}
                  onClick={() => { if (phoneReady && !isPhoneBusy) handlePhoneAction(); }}
                  onKeyDown={(e) => { if (e.key === "Enter" && phoneReady && !isPhoneBusy) handlePhoneAction(); }}
                  className="outline-none"
                  style={{
                    marginLeft: "8px",
                    opacity: phoneReady && !isPhoneBusy ? 0.6 : 0.08,
                    cursor: phoneReady && !isPhoneBusy ? "pointer" : "default",
                    transition: `opacity ${timing.transition} ease`,
                    flexShrink: 0,
                  }}
                  onMouseEnter={(e) => { if (phoneReady && !isPhoneBusy) e.currentTarget.style.opacity = "1"; }}
                  onMouseLeave={(e) => { if (phoneReady && !isPhoneBusy) e.currentTarget.style.opacity = "0.6"; }}
                >
                  <ArrowIcon color={colors.cyan} />
                </span>
              </div>

              {/* Underline */}
              <div
                className="mt-1 h-px"
                style={{
                  width: "60px",
                  background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                  animation: isPhoneBusy ? "none" : "ambientBreath 4.5s ease-in-out infinite",
                  opacity: isPhoneBusy ? 0.1 : 1,
                }}
              />
            </>
          ) : (
            /* ── Dev Auth: name + password ── */
            <>
              <div className="relative">
                <input
                  type="text" value={name}
                  onChange={(e) => setName(e.target.value)}
                  onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) document.getElementById("xark-pass")?.focus(); }}
                  placeholder="your name" autoFocus spellCheck={false} autoComplete="off"
                  className="bg-transparent text-center outline-none"
                  style={{
                    fontSize: "clamp(1.25rem, 3vw, 1.75rem)", letterSpacing: "0.08em",
                    color: colors.white, caretColor: colors.cyan, width: "280px",
                  }}
                />
                <div className="absolute -bottom-3 left-1/2 h-px" style={{
                  width: "60px", transform: "translateX(-50%)",
                  background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                  animation: "ambientBreath 4.5s ease-in-out infinite",
                }} />
              </div>

              <div className="relative mt-10">
                <input
                  id="xark-pass" type="password" value={password}
                  onChange={(e) => { setPassword(e.target.value); setAuthError(""); }}
                  onKeyDown={(e) => { if (e.key === "Enter") handleDevEnter(); }}
                  placeholder="password" spellCheck={false} autoComplete="off"
                  className="bg-transparent text-center outline-none"
                  style={{
                    fontSize: "clamp(0.9rem, 2vw, 1.1rem)", letterSpacing: "0.12em",
                    color: colors.white, caretColor: colors.cyan, width: "280px", opacity: 0.6,
                  }}
                />
              </div>

              <button
                onClick={handleDevEnter} disabled={!name.trim() || !password.trim()}
                className="mt-12 uppercase transition-all duration-700"
                style={{
                  fontSize: "0.7rem", letterSpacing: "0.3em", color: colors.cyan,
                  background: "transparent", border: "none",
                  opacity: name.trim() && password.trim() ? 0.6 : 0.08,
                  cursor: name.trim() && password.trim() ? "pointer" : "default",
                }}
                onMouseEnter={(e) => { if (name.trim() && password.trim()) e.currentTarget.style.opacity = "1"; }}
                onMouseLeave={(e) => { if (name.trim() && password.trim()) e.currentTarget.style.opacity = "0.6"; }}
              >
                enter
              </button>
            </>
          )}

          {authError && (
            <p className="mt-4" style={{ ...text.hint, color: colors.orange, opacity: 0.7 }}>
              {authError}
            </p>
          )}

          {/* Auth mode toggle (dev only) */}
          {isDevMode && !!auth && (
            <span
              role="button" tabIndex={0}
              onClick={() => { setAuthMode(authMode === "phone" ? "dev" : "phone"); setAuthError(""); }}
              onKeyDown={(e) => { if (e.key === "Enter") setAuthMode(authMode === "phone" ? "dev" : "phone"); }}
              className="mt-8 cursor-pointer outline-none"
              style={{ ...text.hint, color: colors.white, opacity: 0.2, transition: "opacity 0.3s ease" }}
              onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.4"; }}
              onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.2"; }}
            >
              {authMode === "phone" ? "use name + password" : "use phone number"}
            </span>
          )}

          {/* Privacy Signal */}
          <div className="mt-16 flex items-center gap-2" style={{ opacity: 0.2, transition: "opacity 1.6s ease 1.2s" }}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
              <path d="M6 1L3 3.5V5.5C3 7.98 4.28 10.28 6 11C7.72 10.28 9 7.98 9 5.5V3.5L6 1Z" stroke={colors.white} strokeWidth="0.8" strokeLinejoin="round" />
            </svg>
            <span style={{ fontSize: "0.6rem", letterSpacing: "0.15em", color: colors.white, opacity: 0.9, textTransform: "uppercase" as const }}>
              end-to-end encrypted
            </span>
          </div>
        </div>
      )}

      {/* ══════════════════════════════════════════
          NAME PHASE — New user picks a display name
          ══════════════════════════════════════════ */}
      {phase === "name" && (
        <div className="mt-20 flex flex-col items-center" style={{ animation: "revealUp 1s cubic-bezier(0.16, 1, 0.3, 1) forwards" }}>
          <p style={{ ...text.hint, color: colors.white, opacity: 0.4, marginBottom: "24px" }}>
            what should we call you?
          </p>
          <div className="relative flex items-center">
            <input
              type="text" value={name}
              onChange={(e) => setName(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) saveName(); }}
              placeholder="your name" autoFocus spellCheck={false} autoComplete="off"
              className="bg-transparent text-center outline-none"
              style={{
                fontSize: "clamp(1.25rem, 3vw, 1.75rem)", letterSpacing: "0.08em",
                color: colors.white, caretColor: colors.cyan, width: "240px",
              }}
            />
            <span
              role="button" tabIndex={0}
              onClick={() => { if (name.trim()) saveName(); }}
              onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) saveName(); }}
              className="outline-none"
              style={{
                marginLeft: "8px", opacity: name.trim() ? 0.6 : 0.08,
                cursor: name.trim() ? "pointer" : "default",
                transition: `opacity ${timing.transition} ease`, flexShrink: 0,
              }}
              onMouseEnter={(e) => { if (name.trim()) e.currentTarget.style.opacity = "1"; }}
              onMouseLeave={(e) => { if (name.trim()) e.currentTarget.style.opacity = "0.6"; }}
            >
              <ArrowIcon color={colors.cyan} />
            </span>
          </div>
          <div className="mt-1 h-px" style={{
            width: "60px",
            background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
            animation: "ambientBreath 4.5s ease-in-out infinite",
          }} />
        </div>
      )}

      {/* ══════════════════════════════════════════
          PHOTO PHASE
          ══════════════════════════════════════════ */}
      {phase === "photo" && (
        <div className="mt-20 flex flex-col items-center" style={{ animation: "revealUp 1.6s cubic-bezier(0.16, 1, 0.3, 1) forwards" }}>
          <input ref={fileRef} type="file" accept="image/*" className="hidden"
            onChange={(e) => { const file = e.target.files?.[0]; if (file) handlePhotoSelect(file); e.target.value = ""; }}
          />
          {!photoUploading ? (
            <>
              <span role="button" tabIndex={0}
                onClick={() => fileRef.current?.click()}
                onKeyDown={(e) => { if (e.key === "Enter") fileRef.current?.click(); }}
                className="cursor-pointer outline-none"
                style={{ ...text.hint, color: colors.white, opacity: 0.35, transition: "opacity 0.3s ease" }}
                onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.6"; }}
                onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.35"; }}
              >add a photo</span>
              <span role="button" tabIndex={0}
                onClick={handleSkipPhoto}
                onKeyDown={(e) => { if (e.key === "Enter") handleSkipPhoto(); }}
                className="mt-6 cursor-pointer outline-none"
                style={{ ...text.hint, color: colors.white, opacity: 0.2, transition: "opacity 0.3s ease" }}
                onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.35"; }}
                onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.2"; }}
              >skip</span>
            </>
          ) : (
            <div className="flex items-center gap-3">
              <div style={{ width: "6px", height: "6px", borderRadius: "50%", backgroundColor: colors.cyan, animation: "ambientBreath 4.5s ease-in-out infinite" }} />
              <span style={{ ...text.hint, color: colors.white, opacity: 0.4 }}>uploading</span>
            </div>
          )}
        </div>
      )}

      {/* ── Transit Phase ── */}
      {phase === "transit" && (
        <div className="mt-20 flex flex-col items-center" style={{ animation: "revealUp 1.6s cubic-bezier(0.16, 1, 0.3, 1) forwards" }}>
          <p style={{ fontSize: "clamp(1.25rem, 3vw, 1.75rem)", letterSpacing: "0.04em", color: colors.white, opacity: 0.7 }}>
            welcome, {name.trim()}.
          </p>
          <div className="mt-8" style={{ width: "4px", height: "4px", borderRadius: "50%", backgroundColor: colors.cyan, animation: "ambientBreath 4.5s ease-in-out infinite" }} />
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
          0%, 100% { opacity: 0.4; transform: translate(-50%, -55%) scale(1); }
          50% { opacity: 0.8; transform: translate(-50%, -55%) scale(1.08); }
        }
        @keyframes revealUp {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}
