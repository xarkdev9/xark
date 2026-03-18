"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence, LayoutGroup } from "framer-motion";
import { RecaptchaVerifier, signInWithPhoneNumber, type ConfirmationResult } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { supabase } from "@/lib/supabase";
import { setSupabaseToken } from "@/lib/supabase";
import { timing, colors, surface, ink, text } from "@/lib/theme";
import { spring, tap } from "@/lib/motion";
import { makeUserId } from "@/lib/user-id";
import { storageAdapter } from "@/lib/storage";
import { setDevPassword } from "@/hooks/useAuth";
import { WelcomeScreen } from "@/components/os/WelcomeScreen";
import { GlobalMesh } from "@/components/os/GlobalMesh";

// ── Phases ──
type Screen = "brand" | "field";
type FieldStep = "phone" | "otp" | "name" | "photo";
type PhoneAction = "idle" | "sending" | "verifying";

const COUNTRY_CODES = [
  { code: "+1", name: "united states", short: "us" },
  { code: "+91", name: "india", short: "in" },
  { code: "+44", name: "united kingdom", short: "uk" },
  { code: "+61", name: "australia", short: "au" },
];

function detectCountryCode(): string {
  try {
    const locale = Intl.DateTimeFormat().resolvedOptions().locale;
    const region = locale.split("-").pop()?.toUpperCase();
    const match = COUNTRY_CODES.find((c) => c.short.toUpperCase() === region);
    return match?.code ?? "+1";
  } catch {
    return "+1";
  }
}

// ── Icons ──
function ArrowIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="5" y1="12" x2="19" y2="12" />
      <polyline points="12 5 19 12 12 19" />
    </svg>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const [screen, setScreen] = useState<Screen>("brand");
  const [fieldStep, setFieldStep] = useState<FieldStep>("phone");
  const [phoneAction, setPhoneAction] = useState<PhoneAction>("idle");
  const [countryCode, setCountryCode] = useState("+1");
  const [phoneInput, setPhoneInput] = useState("");
  const [name, setName] = useState("");
  const [authError, setAuthError] = useState("");
  const [photoUploading, setPhotoUploading] = useState(false);
  const [isPhoneFocused, setIsPhoneFocused] = useState(false);
  const [isNameFocused, setIsNameFocused] = useState(false);

  // OTP Array state
  const [otpArray, setOtpArray] = useState<string[]>(Array(6).fill(""));
  const otpRefs = useRef<(HTMLInputElement | null)[]>([]);

  const inputRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const recaptchaRef = useRef<RecaptchaVerifier | null>(null);

  // Dev mode
  const isDevMode = process.env.NODE_ENV !== "production" && process.env.NEXT_PUBLIC_DEV_MODE === "true";
  const [password, setPassword] = useState("");
  const [authMode, setAuthMode] = useState<"phone" | "dev">(isDevMode ? "dev" : "phone");
  const usePhoneAuth = authMode === "phone" && !!auth;

  useEffect(() => {
    setCountryCode(detectCountryCode());
  }, []);

  // Autofocus management
  useEffect(() => {
    if (screen === "field") {
      if (fieldStep === "phone" || fieldStep === "name") {
        setTimeout(() => inputRef.current?.focus(), 400);
      } else if (fieldStep === "otp") {
        setTimeout(() => otpRefs.current[0]?.focus(), 400);
      }
    }
  }, [screen, fieldStep]);

  const handleBegin = useCallback(() => setScreen("field"), []);

  // ── Phone: Send OTP ──
  const sendOtp = useCallback(async () => {
    if (!auth || !phoneInput.trim()) return;
    setAuthError("");
    setPhoneAction("sending");

    try {
      if (!recaptchaRef.current) {
        recaptchaRef.current = new RecaptchaVerifier(auth, "recaptcha-container", { size: "invisible" });
      }
      const fullNumber = `${countryCode}${phoneInput.replace(/\D/g, "")}`;
      const result = await signInWithPhoneNumber(auth, fullNumber, recaptchaRef.current);
      confirmationRef.current = result;
      setFieldStep("otp");
      setPhoneAction("idle");
    } catch (err) {
      const message = err instanceof Error ? err.message : "";
      setAuthError(message.includes("too-many-requests") ? "too many attempts. wait a moment." : "could not send code.");
      setPhoneAction("idle");
    }
  }, [phoneInput, countryCode]);

  // ── OTP Handlers ──
  const handleOtpChange = (index: number, value: string) => {
    if (value.length > 1) {
      // Handle paste
      const pasted = value.replace(/\D/g, "").slice(0, 6);
      const newOtp = [...otpArray];
      for (let i = 0; i < pasted.length; i++) {
        if (index + i < 6) newOtp[index + i] = pasted[i];
      }
      setOtpArray(newOtp);
      const nextFocus = Math.min(index + pasted.length, 5);
      otpRefs.current[nextFocus]?.focus();
      return;
    }

    const digit = value.replace(/\D/g, "");
    const newOtp = [...otpArray];
    newOtp[index] = digit;
    setOtpArray(newOtp);

    // Auto-advance
    if (digit && index < 5) {
      otpRefs.current[index + 1]?.focus();
    }
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Backspace" && !otpArray[index] && index > 0) {
      otpRefs.current[index - 1]?.focus();
    }
  };

  const verifyOtp = useCallback(async (code: string) => {
    if (!confirmationRef.current || code.length < 6) return;
    setAuthError("");
    setPhoneAction("verifying");

    try {
      const userCredential = await confirmationRef.current.confirm(code);
      const firebaseToken = await userCredential.user.getIdToken();
      const res = await fetch("/api/phone-auth", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ firebaseToken, displayName: userCredential.user.displayName ?? undefined }),
      });

      if (!res.ok) throw new Error("Verification failed");

      const data = await res.json();
      setSupabaseToken(data.token);
      sessionStorage.setItem("xark_session", JSON.stringify({
        token: data.token, user: { uid: data.user.id, displayName: data.user.displayName },
        expiresAt: Date.now() + 23 * 60 * 60 * 1000,
      }));
      setName(data.user.displayName || "");
      setPhoneAction("idle");
      
      if (/^\d+$/.test(data.user.displayName || "")) setFieldStep("name");
      else setFieldStep("photo");
    } catch {
      setAuthError("wrong code. try again.");
      setOtpArray(Array(6).fill(""));
      otpRefs.current[0]?.focus();
      setPhoneAction("idle");
    }
  }, []);

  // Auto-submit OTP
  useEffect(() => {
    const code = otpArray.join("");
    if (code.length === 6 && fieldStep === "otp" && phoneAction === "idle") {
      verifyOtp(code);
    }
  }, [otpArray, fieldStep, phoneAction, verifyOtp]);

  // ── Save Name ──
  const saveName = useCallback(async () => {
    if (!name.trim()) return;
    const cached = sessionStorage.getItem("xark_session");
    if (cached) {
      try {
        const session = JSON.parse(cached);
        await supabase.from("users").update({ display_name: name.trim().toLowerCase() }).eq("id", session.user.uid);
        session.user.displayName = name.trim().toLowerCase();
        sessionStorage.setItem("xark_session", JSON.stringify(session));
      } catch {}
    }
    setFieldStep("photo");
  }, [name]);

  // ── Dev Enter ──
  const handleDevEnter = useCallback(() => {
    if (name.trim() && password.trim()) {
      setDevPassword(password.trim());
      setAuthError("");
      setFieldStep("photo");
    }
  }, [name, password]);

  // ── Photo / Finalize ──
  const goToGalaxy = useCallback(() => {
    router.push(`/galaxy?name=${encodeURIComponent(name.trim())}`);
  }, [name, router]);

  const handlePhotoSelect = useCallback(async (file: File) => {
    if (file.size > 2 * 1024 * 1024) { goToGalaxy(); return; }
    setPhotoUploading(true);
    try {
      const userId = makeUserId("name", name.trim().toLowerCase());
      const downloadUrl = await storageAdapter.upload(`profiles/${userId}/avatar`, file);
      await supabase.from("users").update({ photo_url: downloadUrl }).eq("id", userId);
    } catch {}
    setPhotoUploading(false);
    goToGalaxy();
  }, [name, goToGalaxy]);

  const phoneReady = phoneInput.replace(/\D/g, "").length >= 7;
  const isBusy = phoneAction !== "idle";

  return (
    <div className="relative flex min-h-svh flex-col overflow-hidden bg-[var(--xark-void)]">
      <GlobalMesh />
      <div id="recaptcha-container" />

      {/* ── Brand / Welcome Phase ── */}
      <AnimatePresence>
        {screen === "brand" && <WelcomeScreen onBegin={handleBegin} />}
      </AnimatePresence>

      <LayoutGroup>
        <AnimatePresence mode="wait">
          {screen === "field" && (
            <motion.div
              key="field"
              className="flex flex-1 flex-col justify-center px-9"
              style={{ zIndex: 10, paddingBottom: "env(safe-area-inset-bottom, 20dvh)" }}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={spring.snappy}
            >
              {/* Massive Welcome Header - Off black, no halation */}
              <motion.h1
                layoutId="header-label"
                style={{
                  fontSize: "32px",
                  fontWeight: 600,
                  color: ink.primary,
                  letterSpacing: "-0.03em",
                  marginBottom: "40px",
                }}
              >
                Welcome to Xark.
              </motion.h1>

              {/* ── PHONE → OTP MORPHING CONTAINER ── */}
              <div style={{ position: "relative" }}>
                <AnimatePresence mode="popLayout">
                  
                  {/* PHONE INPUT */}
                  {fieldStep === "phone" && (
                    <motion.div
                      key="phone-box"
                      layoutId="phone-otp-container"
                      initial={{ opacity: 0, scale: 0.95 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.95 }}
                      transition={spring.fluid}
                    >
                      <p style={{ ...text.label, color: ink.secondary, marginBottom: "12px" }}>
                        Enter your number
                      </p>
                      {usePhoneAuth ? (
                      <motion.div
                        className="flex items-center"
                        style={{
                          background: surface.recessed,
                          borderRadius: "99px",
                          padding: "16px 24px",
                          border: `2px solid ${isPhoneFocused ? colors.accent : "transparent"}`,
                          transition: `border ${timing.transition} ease`,
                        }}
                      >
                        <span style={{ fontSize: "18px", color: ink.primary, marginRight: "12px", fontWeight: 500 }}>
                          {countryCode}
                        </span>
                        <input
                          ref={inputRef}
                          type="tel"
                          value={phoneInput}
                          onChange={(e) => { setPhoneInput(e.target.value); setAuthError(""); }}
                          onFocus={() => setIsPhoneFocused(true)}
                          onBlur={() => setIsPhoneFocused(false)}
                          onKeyDown={(e) => { if (e.key === "Enter" && phoneReady && !isBusy) sendOtp(); }}
                          placeholder="(555) 000-0000"
                          disabled={isBusy}
                          className="flex-1 bg-transparent outline-none w-full"
                          style={{
                            fontSize: "18px",
                            fontWeight: 500,
                            color: ink.primary,
                            caretColor: colors.accent,
                            letterSpacing: "0.02em",
                          }}
                        />

                        {/* Orange Continue Button */}
                        <AnimatePresence>
                          {phoneReady && (
                            <motion.button
                              initial={{ opacity: 0, scale: 0.8 }}
                              animate={{ opacity: 1, scale: 1 }}
                              exit={{ opacity: 0, scale: 0.8 }}
                              whileTap={tap.micro}
                              onClick={sendOtp}
                              disabled={isBusy}
                              style={{
                                background: colors.accent,
                                color: "#FFF",
                                borderRadius: "50%",
                                width: "36px",
                                height: "36px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                marginLeft: "12px",
                                flexShrink: 0,
                                border: "none",
                                cursor: "pointer",
                                opacity: isBusy ? 0.5 : 1,
                              }}
                            >
                              <ArrowIcon />
                            </motion.button>
                          )}
                        </AnimatePresence>
                      </motion.div>
                      ) : (
                        <div className="flex flex-col gap-4">
                          <motion.div
                            className="flex items-center"
                            style={{ background: surface.recessed, borderRadius: "99px", padding: "16px 24px", border: `2px solid ${isNameFocused ? colors.accent : "transparent"}`, transition: `border ${timing.transition} ease` }}
                          >
                            <input
                              type="text" value={name} onChange={(e) => setName(e.target.value)} onFocus={() => setIsNameFocused(true)} onBlur={() => setIsNameFocused(false)}
                              onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) document.getElementById("dev-pass")?.focus(); }}
                              placeholder="Developer Name" className="flex-1 bg-transparent outline-none w-full"
                              style={{ fontSize: "16px", fontWeight: 500, color: ink.primary, caretColor: colors.accent }}
                            />
                          </motion.div>
                          <motion.div
                            className="flex items-center"
                            style={{ background: surface.recessed, borderRadius: "99px", padding: "16px 24px" }}
                          >
                            <input
                              id="dev-pass" type="password" value={password} onChange={(e) => { setPassword(e.target.value); setAuthError(""); }}
                              onKeyDown={(e) => { if (e.key === "Enter") handleDevEnter(); }}
                              placeholder="Dev Password" className="flex-1 bg-transparent outline-none w-full"
                              style={{ fontSize: "16px", fontWeight: 500, color: ink.primary, caretColor: colors.accent }}
                            />
                            <motion.button
                              whileTap={tap.micro} onClick={handleDevEnter}
                              style={{ background: colors.accent, color: "#FFF", borderRadius: "50%", width: "36px", height: "36px", display: "flex", alignItems: "center", justifyContent: "center", marginLeft: "12px", border: "none", cursor: "pointer", opacity: (name && password) ? 1 : 0.5 }}
                            >
                              <ArrowIcon />
                            </motion.button>
                          </motion.div>
                        </div>
                      )}
                    </motion.div>
                  )}

                  {/* OTP CELLS */}
                  {fieldStep === "otp" && (
                    <motion.div
                      key="otp-box"
                      layoutId="phone-otp-container"
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={spring.fluid}
                    >
                      <div className="flex items-center justify-between mb-4">
                        <span style={{ ...text.label, color: ink.secondary }}>
                          Sent to {countryCode} {phoneInput}
                        </span>
                        <span
                          role="button"
                          onClick={() => { setFieldStep("phone"); setOtpArray(Array(6).fill("")); }}
                          style={{ ...text.hint, color: colors.accent, cursor: "pointer", fontWeight: 500 }}
                        >
                          Edit
                        </span>
                      </div>
                      
                      <div className="flex items-center gap-3 w-full justify-between">
                        {otpArray.map((digit, i) => (
                          <motion.input
                            key={i}
                            ref={el => { otpRefs.current[i] = el; }}
                            type="text"
                            inputMode="numeric"
                            maxLength={6}
                            value={digit}
                            onChange={(e) => handleOtpChange(i, e.target.value)}
                            onKeyDown={(e) => handleOtpKeyDown(i, e)}
                            disabled={isBusy}
                            whileFocus={{ scale: 1.05, borderColor: colors.accent }}
                            style={{
                              width: "100%",
                              aspectRatio: "1/1.2",
                              background: surface.recessed,
                              borderRadius: "16px",
                              border: `2px solid transparent`,
                              fontSize: "24px",
                              fontWeight: 600,
                              color: ink.primary,
                              textAlign: "center",
                              caretColor: colors.accent,
                              outline: "none",
                              transition: `background ${timing.transition} ease`,
                            }}
                          />
                        ))}
                      </div>
                    </motion.div>
                  )}

                  {/* NAME INPUT */}
                  {fieldStep === "name" && (
                    <motion.div
                      key="name-box"
                      layoutId="phone-otp-container"
                      initial={{ opacity: 0, scale: 0.95 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={spring.fluid}
                    >
                      <p style={{ ...text.label, color: ink.secondary, marginBottom: "12px" }}>
                        What do your friends call you?
                      </p>
                      <motion.div
                        className="flex items-center"
                        style={{
                          background: surface.recessed,
                          borderRadius: "99px",
                          padding: "16px 24px",
                          border: `2px solid ${isNameFocused ? colors.accent : "transparent"}`,
                          transition: `border ${timing.transition} ease`,
                        }}
                      >
                        <input
                          ref={inputRef}
                          type="text"
                          value={name}
                          onChange={(e) => { setName(e.target.value); setAuthError(""); }}
                          onFocus={() => setIsNameFocused(true)}
                          onBlur={() => setIsNameFocused(false)}
                          onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) saveName(); }}
                          placeholder="Your name"
                          autoCapitalize="words"
                          className="flex-1 bg-transparent outline-none w-full"
                          style={{
                            fontSize: "18px",
                            fontWeight: 500,
                            color: ink.primary,
                            caretColor: colors.accent,
                          }}
                        />
                        <AnimatePresence>
                          {name.trim() && (
                            <motion.button
                              initial={{ opacity: 0, scale: 0.8 }}
                              animate={{ opacity: 1, scale: 1 }}
                              exit={{ opacity: 0, scale: 0.8 }}
                              whileTap={tap.micro}
                              onClick={saveName}
                              style={{
                                background: colors.accent,
                                color: "#FFF",
                                borderRadius: "50%",
                                width: "36px",
                                height: "36px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                marginLeft: "12px",
                                flexShrink: 0,
                                border: "none",
                                cursor: "pointer",
                              }}
                            >
                              <ArrowIcon />
                            </motion.button>
                          )}
                        </AnimatePresence>
                      </motion.div>
                    </motion.div>
                  )}

                  {/* PHOTO INPUT */}
                  {fieldStep === "photo" && (
                    <motion.div
                      key="photo-box"
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={spring.fluid}
                      className="flex flex-col items-center justify-center text-center"
                    >
                      <p style={{ ...text.label, color: ink.primary, fontSize: "20px", marginBottom: "32px", fontWeight: 500 }}>
                        Hey {name.trim()}, add a face?
                      </p>
                      
                      <input 
                        ref={fileRef} type="file" accept="image/*" className="hidden"
                        onChange={(e) => { const f = e.target.files?.[0]; if (f) handlePhotoSelect(f); e.target.value = ""; }}
                      />
                      
                      <motion.div
                        role="button"
                        whileHover={{ scale: 1.05 }}
                        whileTap={tap.micro}
                        onClick={() => fileRef.current?.click()}
                        style={{
                          width: "100px",
                          height: "100px",
                          borderRadius: "50%",
                          background: surface.recessed,
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          color: colors.accent,
                          cursor: "pointer",
                          marginBottom: "24px",
                          border: `2px dashed ${colors.accent}`,
                        }}
                      >
                         {!photoUploading ? (
                           <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                             <line x1="12" y1="5" x2="12" y2="19" />
                             <line x1="5" y1="12" x2="19" y2="12" />
                           </svg>
                         ) : (
                           <motion.div
                             animate={{ rotate: 360 }}
                             transition={{ repeat: Infinity, ease: "linear", duration: 1 }}
                             style={{ width: "24px", height: "24px", borderRadius: "50%", border: "2px solid", borderTopColor: "transparent" }}
                           />
                         )}
                      </motion.div>

                      <span
                        role="button"
                        onClick={goToGalaxy}
                        style={{ ...text.hint, color: ink.secondary, cursor: "pointer", letterSpacing: "0.05em", textTransform: "uppercase" }}
                      >
                        Skip for now
                      </span>
                    </motion.div>
                  )}

                </AnimatePresence>
              </div>

              {/* Dev mode toggle */}
              {isDevMode && !!auth && fieldStep === "phone" && (
                <div className="mt-12 text-center">
                  <span
                    role="button"
                    onClick={() => { setAuthMode(authMode === "phone" ? "dev" : "phone"); setAuthError(""); }}
                    style={{ ...text.hint, color: ink.tertiary, cursor: "pointer" }}
                  >
                    {authMode === "phone" ? "Use Name + Password (Dev)" : "Use Firebase Auth"}
                  </span>
                </div>
              )}

              {/* Error messages */}
              <AnimatePresence>
                {authError && (
                  <motion.p
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                    style={{ ...text.hint, color: colors.orange, marginTop: "16px", textAlign: "center" }}
                  >
                    {authError}
                  </motion.p>
                )}
              </AnimatePresence>
            </motion.div>
          )}
        </AnimatePresence>
      </LayoutGroup>

      {/* Encrypted Badge — Grounded */}
      <div style={{ position: "fixed", bottom: "40px", left: 0, right: 0, display: "flex", justifyContent: "center", alignItems: "center", gap: "6px", pointerEvents: "none" }}>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" style={{ color: ink.tertiary }}>
          <path d="M6 1L3 3.5V5.5C3 7.98 4.28 10.28 6 11C7.72 10.28 9 7.98 9 5.5V3.5L6 1Z" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round"/>
        </svg>
        <span style={{ fontSize: "11px", letterSpacing: "0.12em", color: ink.tertiary, textTransform: "uppercase", fontWeight: 600 }}>
          E2E Encrypted
        </span>
      </div>

    </div>
  );
}
