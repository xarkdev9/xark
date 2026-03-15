"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence, LayoutGroup } from "framer-motion";
import { RecaptchaVerifier, signInWithPhoneNumber, type ConfirmationResult } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { supabase } from "@/lib/supabase";
import { setSupabaseToken } from "@/lib/supabase";
import { colors, timing } from "@/lib/theme";

// ── Phases ──
type Screen = "brand" | "field";
type FieldStep = "phone" | "otp" | "name" | "photo";
type PhoneAction = "idle" | "sending" | "verifying";

// ── Country codes (common ones first) ──
const COUNTRY_CODES = [
  { code: "+1", name: "united states", short: "us" },
  { code: "+91", name: "india", short: "in" },
  { code: "+44", name: "united kingdom", short: "uk" },
  { code: "+61", name: "australia", short: "au" },
  { code: "+81", name: "japan", short: "jp" },
  { code: "+49", name: "germany", short: "de" },
  { code: "+33", name: "france", short: "fr" },
  { code: "+86", name: "china", short: "cn" },
  { code: "+82", name: "south korea", short: "kr" },
  { code: "+55", name: "brazil", short: "br" },
  { code: "+52", name: "mexico", short: "mx" },
  { code: "+39", name: "italy", short: "it" },
  { code: "+34", name: "spain", short: "es" },
  { code: "+7", name: "russia", short: "ru" },
  { code: "+62", name: "indonesia", short: "id" },
  { code: "+90", name: "turkey", short: "tr" },
  { code: "+966", name: "saudi arabia", short: "sa" },
  { code: "+971", name: "uae", short: "ae" },
  { code: "+65", name: "singapore", short: "sg" },
  { code: "+60", name: "malaysia", short: "my" },
  { code: "+63", name: "philippines", short: "ph" },
  { code: "+27", name: "south africa", short: "za" },
  { code: "+234", name: "nigeria", short: "ng" },
  { code: "+254", name: "kenya", short: "ke" },
  { code: "+20", name: "egypt", short: "eg" },
  { code: "+64", name: "new zealand", short: "nz" },
  { code: "+353", name: "ireland", short: "ie" },
  { code: "+31", name: "netherlands", short: "nl" },
  { code: "+46", name: "sweden", short: "se" },
  { code: "+47", name: "norway", short: "no" },
];

// Detect country from locale
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

// ── Transition presets ──
const fieldTransition = {
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -12 },
  transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] as const },
};

// ── Arrow icon ──
function ArrowIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#FF6B35" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
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
  const [showPicker, setShowPicker] = useState(false);
  const [pickerSearch, setPickerSearch] = useState("");
  const [phoneInput, setPhoneInput] = useState("");
  const [otpInput, setOtpInput] = useState("");
  const [name, setName] = useState("");
  const [authError, setAuthError] = useState("");
  const [photoUploading, setPhotoUploading] = useState(false);
  const [mounted, setMounted] = useState(false);

  const inputRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const recaptchaRef = useRef<RecaptchaVerifier | null>(null);

  // Dev mode
  const isDevMode = process.env.NEXT_PUBLIC_DEV_MODE === "true";
  const [password, setPassword] = useState("");
  const [authMode, setAuthMode] = useState<"phone" | "dev">(isDevMode ? "dev" : "phone");
  const usePhoneAuth = authMode === "phone" && !!auth;

  useEffect(() => {
    setMounted(true);
    setCountryCode(detectCountryCode());
  }, []);

  // Focus input when field step changes
  useEffect(() => {
    if (screen === "field") {
      setTimeout(() => inputRef.current?.focus(), 400);
    }
  }, [screen, fieldStep, showPicker]);

  // ── Begin → transition to field ──
  const handleBegin = useCallback(() => {
    setScreen("field");
  }, []);

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
      setAuthError(message.includes("too-many-requests") ? "too many attempts. wait a moment." : "could not send code. check the number.");
      setPhoneAction("idle");
    }
  }, [phoneInput, countryCode]);

  // ── Phone: Verify OTP ──
  const verifyOtp = useCallback(async () => {
    if (!confirmationRef.current || otpInput.length < 6) return;
    setAuthError("");
    setPhoneAction("verifying");

    try {
      const userCredential = await confirmationRef.current.confirm(otpInput);
      const firebaseToken = await userCredential.user.getIdToken();
      const res = await fetch("/api/phone-auth", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ firebaseToken, displayName: userCredential.user.displayName ?? undefined }),
      });

      if (!res.ok) { setAuthError("verification failed."); setPhoneAction("idle"); return; }

      const data = await res.json();
      setSupabaseToken(data.token);
      if (typeof window !== "undefined") {
        sessionStorage.setItem("xark_session", JSON.stringify({
          token: data.token, user: { uid: data.user.id, displayName: data.user.displayName },
          expiresAt: Date.now() + 23 * 60 * 60 * 1000,
        }));
      }
      setName(data.user.displayName);
      setPhoneAction("idle");
      // New user → name, returning → photo
      if (/^\d+$/.test(data.user.displayName)) { setFieldStep("name"); } else { setFieldStep("photo"); }
    } catch {
      setAuthError("wrong code. try again.");
      setOtpInput("");
      setPhoneAction("idle");
    }
  }, [otpInput]);

  // Auto-submit OTP on 6th digit
  useEffect(() => {
    if (otpInput.length === 6 && fieldStep === "otp" && phoneAction === "idle") {
      const t = setTimeout(() => verifyOtp(), 300);
      return () => clearTimeout(t);
    }
  }, [otpInput, fieldStep, phoneAction, verifyOtp]);

  // ── Save name ──
  const saveName = useCallback(async () => {
    if (!name.trim()) return;
    const cached = sessionStorage.getItem("xark_session");
    if (cached) {
      try {
        const session = JSON.parse(cached);
        await supabase.from("users").update({ display_name: name.trim().toLowerCase() }).eq("id", session.user.uid);
        session.user.displayName = name.trim().toLowerCase();
        sessionStorage.setItem("xark_session", JSON.stringify(session));
      } catch { /* continue */ }
    }
    setFieldStep("photo");
  }, [name]);

  // ── Dev auth ──
  const handleDevEnter = useCallback(() => {
    if (name.trim().length > 0 && password.trim().length > 0) {
      sessionStorage.setItem("xark_pass", password.trim());
      setAuthError("");
      setFieldStep("photo");
    }
  }, [name, password]);

  // ── Photo ──
  const handlePhotoSelect = useCallback(async (file: File) => {
    if (!storage) { goToGalaxy(); return; }
    if (file.size > 2 * 1024 * 1024) { goToGalaxy(); return; }
    setPhotoUploading(true);
    try {
      const userId = `name_${name.trim().toLowerCase()}`;
      const storageRef = ref(storage, `profiles/${userId}/avatar`);
      await uploadBytes(storageRef, file);
      const downloadUrl = await getDownloadURL(storageRef);
      await supabase.from("users").update({ photo_url: downloadUrl }).eq("id", userId);
    } catch { /* continue */ }
    setPhotoUploading(false);
    goToGalaxy();
  }, [name]);

  const goToGalaxy = useCallback(() => {
    router.push(`/galaxy?name=${encodeURIComponent(name.trim())}`);
  }, [name, router]);

  // ── Country picker filter ──
  const filteredCodes = pickerSearch
    ? COUNTRY_CODES.filter((c) =>
        c.name.includes(pickerSearch.toLowerCase()) ||
        c.code.includes(pickerSearch) ||
        c.short.includes(pickerSearch.toLowerCase())
      )
    : COUNTRY_CODES;

  // ── Computed states ──
  const phoneReady = phoneInput.replace(/\D/g, "").length >= 7;
  const isBusy = phoneAction !== "idle";
  const accentWashIntensity = fieldStep === "phone" ? 0.03 : fieldStep === "otp" ? 0.035 : fieldStep === "name" ? 0.04 : 0.05;

  return (
    <LayoutGroup>
      <div className="relative flex min-h-svh flex-col overflow-hidden" style={{ background: "#F8F7F4" }}>
        <div id="recaptcha-container" />

        {/* ── Progressive accent wash ── */}
        <div
          className="pointer-events-none fixed inset-0"
          style={{
            background: `radial-gradient(ellipse 80% 60% at 50% 40%, rgba(255,107,53,${accentWashIntensity}) 0%, transparent 60%)`,
            transition: "background 1s ease",
          }}
        />

        {/* ── Grain ── */}
        <div
          className="pointer-events-none fixed inset-0"
          style={{
            opacity: 0.02, zIndex: 50,
            backgroundImage: "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")",
            backgroundSize: "128px",
          }}
        />

        {/* ══════════════════════════════════════
            BRAND SCREEN
            ══════════════════════════════════════ */}
        <AnimatePresence mode="wait">
          {screen === "brand" && (
            <motion.div
              key="brand"
              className="flex flex-1 flex-col justify-center px-9"
              style={{ zIndex: 10 }}
              exit={{ opacity: 0, transition: { duration: 0.3 } }}
            >
              {/* Wordmark */}
              <motion.span
                layoutId="wordmark"
                style={{
                  fontSize: "64px", fontWeight: 300, letterSpacing: "-0.03em",
                  color: "#111111",
                  opacity: mounted ? 0.88 : 0,
                  display: "inline-block",
                }}
                transition={{ layout: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } }}
              >
                xark
              </motion.span>

              {/* Three lines */}
              <div style={{ marginTop: "36px" }}>
                <motion.p
                  initial={{ opacity: 0, y: 14 }}
                  animate={{ opacity: mounted ? 0.45 : 0, y: mounted ? 0 : 14 }}
                  transition={{ delay: 0.5, duration: 1, ease: [0.16, 1, 0.3, 1] }}
                  style={{ fontSize: "14px", fontWeight: 400, color: "#111111", lineHeight: 2, letterSpacing: "0.02em" }}
                >
                  people, plans and memories.
                </motion.p>
                <motion.p
                  initial={{ opacity: 0, y: 14 }}
                  animate={{ opacity: mounted ? 0.28 : 0, y: mounted ? 0 : 14 }}
                  transition={{ delay: 1.0, duration: 1, ease: [0.16, 1, 0.3, 1] }}
                  style={{ fontSize: "14px", fontWeight: 400, color: "#111111", lineHeight: 2, letterSpacing: "0.02em" }}
                >
                  decide together, effortlessly.
                </motion.p>
                <motion.p
                  initial={{ opacity: 0, y: 14 }}
                  animate={{ opacity: mounted ? 0.15 : 0, y: mounted ? 0 : 14 }}
                  transition={{ delay: 1.5, duration: 1, ease: [0.16, 1, 0.3, 1] }}
                  style={{ fontSize: "14px", fontWeight: 400, color: "#111111", lineHeight: 2, letterSpacing: "0.02em" }}
                >
                  encrypted, always.
                </motion.p>
              </div>

              {/* Begin */}
              <motion.div
                initial={{ opacity: 0, y: 14 }}
                animate={{ opacity: mounted ? 1 : 0, y: mounted ? 0 : 14 }}
                transition={{ delay: 2.2, duration: 1, ease: [0.16, 1, 0.3, 1] }}
                style={{ marginTop: "56px" }}
              >
                <span
                  role="button"
                  tabIndex={0}
                  onClick={handleBegin}
                  onKeyDown={(e) => { if (e.key === "Enter") handleBegin(); }}
                  className="cursor-pointer outline-none"
                  style={{
                    fontSize: "11px", fontWeight: 300, letterSpacing: "0.15em",
                    color: "#FF6B35", opacity: 0.5,
                    transition: `opacity ${timing.transition} ease`,
                  }}
                  onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.9"; }}
                  onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.5"; }}
                >
                  begin
                </span>
              </motion.div>
            </motion.div>
          )}

          {/* ══════════════════════════════════════
              FIELD SCREEN
              ══════════════════════════════════════ */}
          {screen === "field" && (
            <motion.div
              key="field"
              className="flex flex-1 flex-col px-9"
              style={{ zIndex: 10 }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.3 }}
            >
              {/* Wordmark — morphs from brand via layoutId */}
              <div style={{ paddingTop: "80px" }}>
                <motion.span
                  layoutId="wordmark"
                  style={{
                    fontSize: "28px", fontWeight: 300, letterSpacing: "-0.03em",
                    color: "#111111", opacity: 0.5,
                    display: "inline-block",
                  }}
                  transition={{ layout: { duration: 0.6, ease: [0.22, 1, 0.36, 1] } }}
                >
                  xark
                </motion.span>
              </div>

              {/* THE FIELD — fixed position, content morphs */}
              <div style={{ marginTop: "100px" }}>
                <AnimatePresence mode="wait">

                  {/* ── PHONE ── */}
                  {fieldStep === "phone" && !showPicker && (
                    <motion.div key="phone" {...fieldTransition}>
                      {usePhoneAuth ? (
                        <>
                          <p style={{ fontSize: "13px", fontWeight: 300, color: "#111111", opacity: 0.25, letterSpacing: "0.04em", marginBottom: "16px" }}>
                            your number
                          </p>
                          <div style={{ display: "flex", alignItems: "center" }}>
                            {/* Country code */}
                            <div
                              role="button" tabIndex={0}
                              onClick={() => { setShowPicker(true); setPickerSearch(""); }}
                              onKeyDown={(e) => { if (e.key === "Enter") { setShowPicker(true); setPickerSearch(""); } }}
                              className="cursor-pointer outline-none"
                              style={{
                                display: "flex", alignItems: "center", gap: "3px",
                                paddingRight: "10px", position: "relative",
                              }}
                            >
                              <span style={{ fontSize: "22px", fontWeight: 400, color: "#111111", opacity: 0.5 }}>{countryCode}</span>
                              <svg width="8" height="8" viewBox="0 0 8 8" fill="none" style={{ opacity: 0.2, marginTop: "2px" }}>
                                <path d="M2 3L4 5L6 3" stroke="#111111" strokeWidth="0.8" strokeLinecap="round" strokeLinejoin="round"/>
                              </svg>
                              <div style={{ position: "absolute", right: 0, top: "4px", bottom: "4px", width: "1px", background: "#111111", opacity: 0.06 }} />
                            </div>

                            <input
                              ref={inputRef}
                              type="tel" inputMode="tel"
                              value={phoneInput}
                              onChange={(e) => { setPhoneInput(e.target.value); setAuthError(""); }}
                              onKeyDown={(e) => { if (e.key === "Enter" && phoneReady && !isBusy) sendOtp(); }}
                              placeholder="phone number"
                              autoFocus spellCheck={false} autoComplete="tel"
                              disabled={isBusy}
                              className="flex-1 bg-transparent outline-none"
                              style={{
                                fontSize: "22px", fontWeight: 400, color: "#111111", letterSpacing: "0.06em",
                                paddingLeft: "10px", caretColor: "#FF6B35",
                                opacity: isBusy ? 0.3 : 0.85,
                                transition: `opacity ${timing.transition} ease`,
                              }}
                            />

                            <span
                              role="button" tabIndex={0}
                              onClick={() => { if (phoneReady && !isBusy) sendOtp(); }}
                              onKeyDown={(e) => { if (e.key === "Enter" && phoneReady && !isBusy) sendOtp(); }}
                              className="outline-none"
                              style={{
                                opacity: phoneReady && !isBusy ? 0.5 : 0.08,
                                cursor: phoneReady && !isBusy ? "pointer" : "default",
                                transition: `opacity ${timing.transition} ease`, flexShrink: 0,
                              }}
                            >
                              <ArrowIcon />
                            </span>
                          </div>
                        </>
                      ) : (
                        /* Dev auth */
                        <>
                          <p style={{ fontSize: "13px", fontWeight: 300, color: "#111111", opacity: 0.25, letterSpacing: "0.04em", marginBottom: "16px" }}>
                            your name
                          </p>
                          <div style={{ display: "flex", alignItems: "center", marginBottom: "24px" }}>
                            <input
                              ref={inputRef}
                              type="text" value={name}
                              onChange={(e) => setName(e.target.value)}
                              onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) document.getElementById("xark-pass")?.focus(); }}
                              placeholder="name" autoFocus spellCheck={false} autoComplete="off"
                              className="flex-1 bg-transparent outline-none"
                              style={{ fontSize: "22px", fontWeight: 400, color: "#111111", letterSpacing: "0.04em", caretColor: "#FF6B35" }}
                            />
                          </div>
                          <p style={{ fontSize: "13px", fontWeight: 300, color: "#8A8A94", letterSpacing: "0.04em", marginBottom: "16px" }}>
                            password
                          </p>
                          <div style={{ display: "flex", alignItems: "center" }}>
                            <input
                              id="xark-pass" type="password" value={password}
                              onChange={(e) => { setPassword(e.target.value); setAuthError(""); }}
                              onKeyDown={(e) => { if (e.key === "Enter") handleDevEnter(); }}
                              placeholder="password" spellCheck={false} autoComplete="off"
                              className="flex-1 bg-transparent outline-none"
                              style={{ fontSize: "16px", fontWeight: 400, color: "#111111", letterSpacing: "0.08em", caretColor: "#FF6B35", opacity: 0.6 }}
                            />
                            <span
                              role="button" tabIndex={0}
                              onClick={handleDevEnter}
                              onKeyDown={(e) => { if (e.key === "Enter") handleDevEnter(); }}
                              className="outline-none"
                              style={{
                                opacity: name.trim() && password.trim() ? 0.5 : 0.08,
                                cursor: name.trim() && password.trim() ? "pointer" : "default",
                                transition: `opacity ${timing.transition} ease`, flexShrink: 0,
                              }}
                            >
                              <ArrowIcon />
                            </span>
                          </div>
                        </>
                      )}
                    </motion.div>
                  )}

                  {/* ── COUNTRY PICKER ── */}
                  {fieldStep === "phone" && showPicker && (
                    <motion.div key="picker" {...fieldTransition}>
                      <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "20px" }}>
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#111111" strokeWidth="1.5" opacity="0.2">
                          <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
                        </svg>
                        <input
                          ref={inputRef}
                          type="text" value={pickerSearch}
                          onChange={(e) => setPickerSearch(e.target.value)}
                          onKeyDown={(e) => {
                            if (e.key === "Enter" && filteredCodes.length > 0) {
                              setCountryCode(filteredCodes[0].code);
                              setShowPicker(false);
                            }
                            if (e.key === "Escape") setShowPicker(false);
                          }}
                          placeholder="search country"
                          autoFocus spellCheck={false} autoComplete="off"
                          className="flex-1 bg-transparent outline-none"
                          style={{ fontSize: "15px", fontWeight: 400, color: "#111111", letterSpacing: "0.02em", caretColor: "#FF6B35" }}
                        />
                        <span
                          role="button" tabIndex={0}
                          onClick={() => setShowPicker(false)}
                          onKeyDown={(e) => { if (e.key === "Enter") setShowPicker(false); }}
                          className="cursor-pointer outline-none"
                          style={{ fontSize: "11px", fontWeight: 300, color: "#111111", opacity: 0.2 }}
                        >
                          cancel
                        </span>
                      </div>
                      <div style={{ maxHeight: "280px", overflowY: "auto" }}>
                        {filteredCodes.slice(0, 10).map((c) => (
                          <div
                            key={c.code}
                            role="button" tabIndex={0}
                            onClick={() => { setCountryCode(c.code); setShowPicker(false); }}
                            onKeyDown={(e) => { if (e.key === "Enter") { setCountryCode(c.code); setShowPicker(false); } }}
                            className="cursor-pointer outline-none"
                            style={{
                              display: "flex", alignItems: "baseline", justifyContent: "space-between",
                              padding: "10px 0",
                              borderBottom: "1px solid rgba(20,20,20,0.03)",
                            }}
                          >
                            <span style={{ fontSize: "14px", fontWeight: 400, color: "#111111", opacity: 0.6 }}>{c.name}</span>
                            <span style={{ fontSize: "13px", fontWeight: 300, color: "#FF6B35", opacity: 0.5 }}>{c.code}</span>
                          </div>
                        ))}
                      </div>
                    </motion.div>
                  )}

                  {/* ── OTP ── */}
                  {fieldStep === "otp" && (
                    <motion.div key="otp" {...fieldTransition}>
                      <p style={{ fontSize: "13px", fontWeight: 300, color: "#111111", opacity: 0.2, letterSpacing: "0.04em", marginBottom: "16px" }}>
                        <span style={{ opacity: 0.6 }}>{countryCode} {phoneInput}</span> · enter code
                      </p>
                      <div style={{ display: "flex", alignItems: "center" }}>
                        <input
                          ref={inputRef}
                          type="text" inputMode="numeric"
                          value={otpInput}
                          onChange={(e) => setOtpInput(e.target.value.replace(/\D/g, "").slice(0, 6))}
                          placeholder="······"
                          autoFocus spellCheck={false} autoComplete="one-time-code"
                          disabled={isBusy}
                          className="flex-1 bg-transparent outline-none"
                          style={{
                            fontSize: "32px", fontWeight: 400, color: "#111111", letterSpacing: "0.3em",
                            caretColor: "#FF6B35",
                            opacity: isBusy ? 0.3 : 0.9,
                            transition: `opacity ${timing.transition} ease`,
                          }}
                        />
                      </div>
                    </motion.div>
                  )}

                  {/* ── NAME ── */}
                  {fieldStep === "name" && (
                    <motion.div key="name" {...fieldTransition}>
                      <p style={{ fontSize: "13px", fontWeight: 300, color: "#111111", opacity: 0.25, letterSpacing: "0.04em", marginBottom: "16px" }}>
                        your friends call you
                      </p>
                      <div style={{ display: "flex", alignItems: "center" }}>
                        <input
                          ref={inputRef}
                          type="text" value={name}
                          onChange={(e) => setName(e.target.value)}
                          onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) saveName(); }}
                          placeholder="name"
                          autoFocus spellCheck={false} autoComplete="off"
                          className="flex-1 bg-transparent outline-none"
                          style={{ fontSize: "26px", fontWeight: 400, color: "#111111", letterSpacing: "0.02em", caretColor: "#FF6B35", opacity: 0.88 }}
                        />
                        <span
                          role="button" tabIndex={0}
                          onClick={() => { if (name.trim()) saveName(); }}
                          onKeyDown={(e) => { if (e.key === "Enter" && name.trim()) saveName(); }}
                          className="outline-none"
                          style={{
                            opacity: name.trim() ? 0.5 : 0.08,
                            cursor: name.trim() ? "pointer" : "default",
                            transition: `opacity ${timing.transition} ease`, flexShrink: 0,
                          }}
                        >
                          <ArrowIcon />
                        </span>
                      </div>
                    </motion.div>
                  )}

                  {/* ── PHOTO ── */}
                  {fieldStep === "photo" && (
                    <motion.div key="photo" {...fieldTransition}>
                      <p style={{ fontSize: "13px", fontWeight: 300, color: "#111111", opacity: 0.25, letterSpacing: "0.04em", marginBottom: "16px" }}>
                        hey {name.trim().toLowerCase()} — add a face?
                      </p>
                      <input ref={fileRef} type="file" accept="image/*" className="hidden"
                        onChange={(e) => { const f = e.target.files?.[0]; if (f) handlePhotoSelect(f); e.target.value = ""; }}
                      />
                      {!photoUploading ? (
                        <div style={{ display: "flex", alignItems: "center", gap: "20px" }}>
                          <div
                            role="button" tabIndex={0}
                            onClick={() => fileRef.current?.click()}
                            onKeyDown={(e) => { if (e.key === "Enter") fileRef.current?.click(); }}
                            className="cursor-pointer outline-none"
                            style={{ width: "56px", height: "56px", borderRadius: "50%", position: "relative" }}
                          >
                            <svg width="56" height="56" viewBox="0 0 56 56" fill="none" style={{ position: "absolute", inset: 0 }}>
                              <circle cx="28" cy="28" r="26" stroke="#111111" strokeWidth="0.6" strokeDasharray="4 5" opacity="0.12"/>
                            </svg>
                            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
                              <svg width="14" height="14" viewBox="0 0 16 16" fill="none" opacity="0.15">
                                <line x1="8" y1="3" x2="8" y2="13" stroke="#111111" strokeWidth="0.8"/>
                                <line x1="3" y1="8" x2="13" y2="8" stroke="#111111" strokeWidth="0.8"/>
                              </svg>
                            </div>
                          </div>
                          <span
                            role="button" tabIndex={0}
                            onClick={goToGalaxy}
                            onKeyDown={(e) => { if (e.key === "Enter") goToGalaxy(); }}
                            className="cursor-pointer outline-none"
                            style={{
                              fontSize: "11px", fontWeight: 300, color: "#8A8A94", letterSpacing: "0.04em",
                              transition: `opacity ${timing.transition} ease`,
                            }}
                            onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.3"; }}
                            onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.12"; }}
                          >
                            skip
                          </span>
                        </div>
                      ) : (
                        <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                          <div style={{ width: "6px", height: "6px", borderRadius: "50%", background: "#FF6B35", animation: "ambientBreath 4.5s ease-in-out infinite" }} />
                          <span style={{ fontSize: "12px", fontWeight: 300, color: "#111111", opacity: 0.35 }}>uploading</span>
                        </div>
                      )}
                    </motion.div>
                  )}

                </AnimatePresence>

                {/* ── Accent line — always present, width morphs ── */}
                <motion.div
                  style={{
                    marginTop: fieldStep === "photo" ? "18px" : "10px",
                    height: "1px",
                    background: "linear-gradient(90deg, #FF6B35, transparent)",
                    animation: isBusy ? "none" : "ambientBreath 4.5s ease-in-out infinite",
                    opacity: isBusy ? 0.1 : 0.3,
                  }}
                  animate={{ width: fieldStep === "otp" ? "100px" : fieldStep === "name" ? "60px" : fieldStep === "photo" ? "56px" : "100px" }}
                  transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
                />

                {/* Auth error */}
                <AnimatePresence>
                  {authError && (
                    <motion.p
                      initial={{ opacity: 0, y: 4 }}
                      animate={{ opacity: 0.7, y: 0 }}
                      exit={{ opacity: 0 }}
                      style={{ fontSize: "11px", fontWeight: 300, color: "#C43D08", marginTop: "12px", letterSpacing: "0.02em" }}
                    >
                      {authError}
                    </motion.p>
                  )}
                </AnimatePresence>
              </div>

              {/* Dev mode toggle */}
              {isDevMode && !!auth && fieldStep === "phone" && !showPicker && (
                <span
                  role="button" tabIndex={0}
                  onClick={() => { setAuthMode(authMode === "phone" ? "dev" : "phone"); setAuthError(""); }}
                  onKeyDown={(e) => { if (e.key === "Enter") setAuthMode(authMode === "phone" ? "dev" : "phone"); }}
                  className="cursor-pointer outline-none"
                  style={{
                    fontSize: "13px", fontWeight: 300, color: "#8A8A94", letterSpacing: "0.04em",
                    marginTop: "32px", transition: `opacity ${timing.transition} ease`,
                  }}
                  onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.25"; }}
                  onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.12"; }}
                >
                  {authMode === "phone" ? "use name + password" : "use phone number"}
                </span>
              )}

              {/* Encrypted badge — persistent */}
              <div style={{ position: "fixed", bottom: "56px", left: "36px", display: "flex", alignItems: "center", gap: "6px", zIndex: 10 }}>
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M6 1L3 3.5V5.5C3 7.98 4.28 10.28 6 11C7.72 10.28 9 7.98 9 5.5V3.5L6 1Z" stroke="#8A8A94" strokeWidth="0.8" strokeLinejoin="round"/>
                </svg>
                <span style={{ fontSize: "11px", letterSpacing: "0.12em", color: "#8A8A94", textTransform: "uppercase" as const }}>
                  encrypted
                </span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        <style jsx>{`
          input::placeholder {
            color: #8A8A94;
            opacity: 1;
            letter-spacing: 0.08em;
          }
          input:focus::placeholder {
            opacity: 0.4;
            transition: opacity 0.6s ease;
          }
        `}</style>
      </div>
    </LayoutGroup>
  );
}
