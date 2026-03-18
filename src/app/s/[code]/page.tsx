"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter, useParams } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  RecaptchaVerifier,
  signInWithPhoneNumber,
  type ConfirmationResult,
} from "firebase/auth";
import { auth } from "@/lib/firebase";
import { setSupabaseToken } from "@/lib/supabase";

// ── White-over-dark color tokens (same pattern as login page) ──
const W = "#fff";
const W90 = "rgba(255,255,255,0.9)";
const W70 = "rgba(255,255,255,0.7)";
const W50 = "rgba(255,255,255,0.5)";
const W40 = "rgba(255,255,255,0.4)";
const W25 = "rgba(255,255,255,0.25)";
const W12 = "rgba(255,255,255,0.12)";
const ACCENT = "#40E0FF";
const BRAND = "#FF6B35";
const ERROR = "#FF6B35";
const TEXT_SHADOW = "0 1px 4px rgba(0,0,0,0.5)";

// ── Country codes ──
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
  { code: "+65", name: "singapore", short: "sg" },
  { code: "+971", name: "uae", short: "ae" },
  { code: "+64", name: "new zealand", short: "nz" },
  { code: "+353", name: "ireland", short: "ie" },
  { code: "+31", name: "netherlands", short: "nl" },
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

// ── Transition preset ──
const fieldTransition = {
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -12 },
  transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] as const },
};

// ── Arrow icon ──
function ArrowIcon() {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <line x1="5" y1="12" x2="19" y2="12" />
      <polyline points="12 5 19 12 12 19" />
    </svg>
  );
}

// ── Shield icon ──
function ShieldIcon() {
  return (
    <svg
      width="12"
      height="12"
      viewBox="0 0 12 12"
      fill="none"
      style={{ opacity: 0.7 }}
    >
      <path
        d="M6 1L3 3.5V5.5C3 7.98 4.28 10.28 6 11C7.72 10.28 9 7.98 9 5.5V3.5L6 1Z"
        stroke="currentColor"
        strokeWidth="0.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}

// ── Screen types ──
type Screen = "loading" | "error" | "invite" | "auth" | "claiming";
type AuthStep = "phone" | "otp" | "name";
type PhoneAction = "idle" | "sending" | "verifying";

export default function SummonPage() {
  const router = useRouter();
  const params = useParams();
  const code = typeof params.code === "string" ? params.code : "";

  // ── Validation state ──
  const [screen, setScreen] = useState<Screen>("loading");
  const [creatorName, setCreatorName] = useState("someone");
  const [errorReason, setErrorReason] = useState("");

  // ── Auth state ──
  const [authStep, setAuthStep] = useState<AuthStep>("phone");
  const [phoneAction, setPhoneAction] = useState<PhoneAction>("idle");
  const [countryCode, setCountryCode] = useState("+1");
  const [showPicker, setShowPicker] = useState(false);
  const [pickerSearch, setPickerSearch] = useState("");
  const [phoneInput, setPhoneInput] = useState("");
  const [otpInput, setOtpInput] = useState("");
  const [nameInput, setNameInput] = useState("");
  const [authError, setAuthError] = useState("");

  // ── Firebase refs ──
  const inputRef = useRef<HTMLInputElement>(null);
  const confirmationRef = useRef<ConfirmationResult | null>(null);
  const recaptchaRef = useRef<RecaptchaVerifier | null>(null);

  // ── Mount: detect country + validate code ──
  useEffect(() => {
    setCountryCode(detectCountryCode());
  }, []);

  useEffect(() => {
    if (!code) {
      setErrorReason("invalid link");
      setScreen("error");
      return;
    }

    (async () => {
      try {
        const res = await fetch(`/api/summon/validate?code=${encodeURIComponent(code)}`);
        const data = await res.json();

        if (data.valid) {
          setCreatorName(data.creatorName ?? "someone");
          setScreen("invite");
        } else {
          const reason = data.reason ?? "unknown";
          if (reason === "already claimed") {
            setErrorReason("this link was already used");
          } else if (reason === "expired") {
            setErrorReason("this link has expired");
          } else {
            setErrorReason("something went wrong");
          }
          setScreen("error");
        }
      } catch {
        setErrorReason("something went wrong");
        setScreen("error");
      }
    })();
  }, [code]);

  // ── Focus input when auth step changes ──
  useEffect(() => {
    if (screen === "auth") {
      const t = setTimeout(() => inputRef.current?.focus(), 400);
      return () => clearTimeout(t);
    }
  }, [screen, authStep, showPicker]);

  // ── Phone: Send OTP ──
  const sendOtp = useCallback(async () => {
    if (!auth || !phoneInput.trim()) return;
    setAuthError("");
    setPhoneAction("sending");

    try {
      if (!recaptchaRef.current) {
        recaptchaRef.current = new RecaptchaVerifier(auth, "recaptcha-container", {
          size: "invisible",
        });
      }
      const fullNumber = `${countryCode}${phoneInput.replace(/\D/g, "")}`;
      const result = await signInWithPhoneNumber(auth, fullNumber, recaptchaRef.current);
      confirmationRef.current = result;
      setAuthStep("otp");
      setPhoneAction("idle");
    } catch (err) {
      const message = err instanceof Error ? err.message : "";
      setAuthError(
        message.includes("too-many-requests")
          ? "too many attempts. wait a moment."
          : "could not send code. check the number."
      );
      setPhoneAction("idle");
    }
  }, [phoneInput, countryCode]);

  // ── OTP: Verify ──
  const verifyOtp = useCallback(async () => {
    if (!confirmationRef.current || otpInput.length < 6) return;
    setAuthError("");
    setPhoneAction("verifying");

    try {
      const userCredential = await confirmationRef.current.confirm(otpInput);
      const firebaseToken = await userCredential.user.getIdToken();

      // Store token for claim step; check if existing user has a display name
      const displayName = userCredential.user.displayName;
      if (displayName && !/^\d+$/.test(displayName)) {
        setNameInput(displayName);
        setPhoneAction("idle");
        await claimLink(firebaseToken, displayName);
      } else {
        // New user — ask for name
        (window as unknown as Record<string, unknown>)["__xark_summon_token"] = firebaseToken;
        setPhoneAction("idle");
        setAuthStep("name");
      }
    } catch {
      setAuthError("wrong code. try again.");
      setOtpInput("");
      setPhoneAction("idle");
    }
  }, [otpInput]); // claimLink added via useCallback below

  // ── Claim link after auth ──
  const claimLink = useCallback(
    async (firebaseToken: string, displayName: string) => {
      setScreen("claiming");

      try {
        const res = await fetch("/api/summon/claim", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ code, firebaseToken }),
        });

        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          setErrorReason(data.error ?? "something went wrong");
          setScreen("error");
          return;
        }

        const data = await res.json();
        const { token, user, spaceId } = data as {
          token: string;
          user: { id: string; displayName: string };
          spaceId: string | null;
        };

        // Store session (matches login page pattern)
        setSupabaseToken(token);
        if (typeof window !== "undefined") {
          sessionStorage.setItem(
            "xark_session",
            JSON.stringify({
              token,
              user: { uid: user.id, displayName: user.displayName },
              expiresAt: Date.now() + 23 * 60 * 60 * 1000,
            })
          );
        }

        // 800ms breathing pause before redirect
        await new Promise((r) => setTimeout(r, 800));

        const resolvedName = displayName || user.displayName;
        if (spaceId) {
          router.push(`/space/${spaceId}?name=${encodeURIComponent(resolvedName)}`);
        } else {
          router.push(`/galaxy?name=${encodeURIComponent(resolvedName)}`);
        }
      } catch {
        setErrorReason("something went wrong");
        setScreen("error");
      }
    },
    [code, router]
  );

  // ── Name submit: claim with stored token ──
  const submitName = useCallback(async () => {
    if (!nameInput.trim()) return;
    const storedToken = (window as unknown as Record<string, unknown>)["__xark_summon_token"] as
      | string
      | undefined;
    if (!storedToken) {
      setAuthError("session lost. please try again.");
      setAuthStep("phone");
      return;
    }
    await claimLink(storedToken, nameInput.trim().toLowerCase());
  }, [nameInput, claimLink]);

  // ── Auto-submit OTP on 6th digit ──
  useEffect(() => {
    if (otpInput.length === 6 && authStep === "otp" && phoneAction === "idle") {
      const t = setTimeout(() => verifyOtp(), 300);
      return () => clearTimeout(t);
    }
  }, [otpInput, authStep, phoneAction, verifyOtp]);

  // ── Computed ──
  const phoneReady = phoneInput.replace(/\D/g, "").length >= 7;
  const isBusy = phoneAction !== "idle";

  const filteredCodes = pickerSearch
    ? COUNTRY_CODES.filter(
        (c) =>
          c.name.includes(pickerSearch.toLowerCase()) ||
          c.code.includes(pickerSearch) ||
          c.short.includes(pickerSearch.toLowerCase())
      )
    : COUNTRY_CODES;

  return (
    <div
      className="relative flex min-h-svh flex-col overflow-hidden"
      style={{ background: "#050508" }}
    >
      <div id="recaptcha-container" />

      <AnimatePresence mode="wait">

        {/* ── LOADING ── */}
        {screen === "loading" && (
          <motion.div
            key="loading"
            className="flex flex-1 flex-col items-center justify-center"
            style={{ zIndex: 10 }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
          >
            <div
              style={{
                width: "6px",
                height: "6px",
                borderRadius: "50%",
                background: BRAND,
                animation: "ambientBreath 4.5s ease-in-out infinite",
              }}
            />
          </motion.div>
        )}

        {/* ── ERROR ── */}
        {screen === "error" && (
          <motion.div
            key="error"
            className="flex flex-1 flex-col items-center justify-center px-9"
            style={{ zIndex: 10 }}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
          >
            <p
              style={{
                fontSize: "1rem",
                fontWeight: 300,
                color: W,
                opacity: 0.5,
                textShadow: TEXT_SHADOW,
                textAlign: "center",
                letterSpacing: "0.02em",
              }}
            >
              {errorReason}
            </p>
          </motion.div>
        )}

        {/* ── INVITE ── */}
        {screen === "invite" && (
          <motion.div
            key="invite"
            className="flex flex-1 flex-col items-center justify-center px-9"
            style={{ zIndex: 10 }}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
          >
            <motion.p
              style={{
                fontSize: "2rem",
                fontWeight: 300,
                color: W,
                opacity: 0.9,
                textShadow: TEXT_SHADOW,
                textAlign: "center",
                letterSpacing: "-0.01em",
                marginBottom: "12px",
              }}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 0.9, y: 0 }}
              transition={{ duration: 0.5, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
            >
              {creatorName}
            </motion.p>

            <motion.p
              style={{
                fontSize: "1rem",
                fontWeight: 300,
                color: W,
                opacity: 0.5,
                textShadow: TEXT_SHADOW,
                textAlign: "center",
                letterSpacing: "0.01em",
                marginBottom: "56px",
              }}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 0.5, y: 0 }}
              transition={{ duration: 0.5, delay: 0.2, ease: [0.22, 1, 0.36, 1] }}
            >
              wants to plan with you
            </motion.p>

            <motion.span
              role="button"
              tabIndex={0}
              onClick={() => setScreen("auth")}
              onKeyDown={(e) => {
                if (e.key === "Enter") setScreen("auth");
              }}
              className="cursor-pointer outline-none"
              style={{
                fontSize: "1rem",
                fontWeight: 300,
                color: W,
                opacity: 0.4,
                textShadow: TEXT_SHADOW,
                letterSpacing: "0.12em",
                transition: "opacity 0.3s ease, letter-spacing 0.3s ease",
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.opacity = "0.8";
                e.currentTarget.style.letterSpacing = "0.2em";
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.opacity = "0.4";
                e.currentTarget.style.letterSpacing = "0.12em";
              }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.4 }}
              transition={{ duration: 0.5, delay: 0.35 }}
            >
              begin
            </motion.span>
          </motion.div>
        )}

        {/* ── AUTH ── */}
        {screen === "auth" && (
          <motion.div
            key="auth"
            className="flex flex-1 flex-col justify-center px-9"
            style={{ zIndex: 10, paddingBottom: "env(safe-area-inset-bottom, 0px)" }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
          >
            {/* xark wordmark */}
            <div style={{ marginBottom: "32px" }}>
              <span
                style={{
                  fontSize: "28px",
                  fontWeight: 300,
                  letterSpacing: "-0.03em",
                  color: W,
                  opacity: 0.8,
                  textShadow: TEXT_SHADOW,
                  display: "inline-block",
                }}
              >
                xark
              </span>
            </div>

            <AnimatePresence mode="wait">

              {/* ── PHONE step ── */}
              {authStep === "phone" && !showPicker && auth && (
                <motion.div key="phone" {...fieldTransition}>
                  <p
                    style={{
                      fontSize: "13px",
                      fontWeight: 300,
                      color: W,
                      opacity: 0.9,
                      letterSpacing: "0.04em",
                      marginBottom: "16px",
                      textShadow: TEXT_SHADOW,
                    }}
                  >
                    your number
                  </p>
                  <div style={{ display: "flex", alignItems: "center", gap: "4px" }}>
                    {/* Country code picker trigger */}
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={() => {
                        setShowPicker(true);
                        setPickerSearch("");
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") {
                          setShowPicker(true);
                          setPickerSearch("");
                        }
                      }}
                      className="cursor-pointer outline-none"
                      style={{
                        display: "flex",
                        alignItems: "center",
                        gap: "3px",
                        paddingRight: "8px",
                        position: "relative",
                        flexShrink: 0,
                      }}
                    >
                      <span
                        style={{
                          fontSize: "18px",
                          fontWeight: 400,
                          color: W,
                          opacity: 1,
                          textShadow: TEXT_SHADOW,
                        }}
                      >
                        {countryCode}
                      </span>
                      <svg
                        width="8"
                        height="8"
                        viewBox="0 0 8 8"
                        fill="none"
                        style={{ opacity: 0.7, marginTop: "2px", color: W }}
                      >
                        <path
                          d="M2 3L4 5L6 3"
                          stroke="currentColor"
                          strokeWidth="0.8"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                      <div
                        style={{
                          position: "absolute",
                          right: 0,
                          top: "4px",
                          bottom: "4px",
                          width: "1px",
                          background: W,
                          opacity: 0.1,
                        }}
                      />
                    </div>

                    <input
                      ref={inputRef}
                      type="tel"
                      inputMode="tel"
                      value={phoneInput}
                      onChange={(e) => {
                        setPhoneInput(e.target.value);
                        setAuthError("");
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && phoneReady && !isBusy) sendOtp();
                      }}
                      placeholder="phone number"
                      autoFocus
                      spellCheck={false}
                      autoComplete="tel"
                      disabled={isBusy}
                      className="flex-1 bg-transparent outline-none"
                      style={{
                        fontSize: "18px",
                        fontWeight: 400,
                        color: W,
                        letterSpacing: "0.06em",
                        paddingLeft: "8px",
                        caretColor: ACCENT,
                        textShadow: TEXT_SHADOW,
                        minWidth: 0,
                        opacity: isBusy ? 0.4 : 1,
                        transition: "opacity 0.2s ease",
                      }}
                    />

                    <span
                      role="button"
                      tabIndex={0}
                      onClick={() => {
                        if (phoneReady && !isBusy) sendOtp();
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && phoneReady && !isBusy) sendOtp();
                      }}
                      className="outline-none"
                      style={{
                        color: W,
                        opacity: phoneReady && !isBusy ? 0.9 : 0.15,
                        cursor: phoneReady && !isBusy ? "pointer" : "default",
                        transition: "opacity 0.2s ease",
                        flexShrink: 0,
                        padding: "8px",
                        marginRight: "-8px",
                      }}
                    >
                      <ArrowIcon />
                    </span>
                  </div>
                </motion.div>
              )}

              {/* ── COUNTRY PICKER ── */}
              {authStep === "phone" && showPicker && (
                <motion.div key="picker" {...fieldTransition}>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "8px",
                      marginBottom: "20px",
                    }}
                  >
                    <svg
                      width="14"
                      height="14"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke={W}
                      strokeWidth="1.5"
                      opacity="0.8"
                    >
                      <circle cx="11" cy="11" r="8" />
                      <line x1="21" y1="21" x2="16.65" y2="16.65" />
                    </svg>
                    <input
                      ref={inputRef}
                      type="text"
                      value={pickerSearch}
                      onChange={(e) => setPickerSearch(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && filteredCodes.length > 0) {
                          setCountryCode(filteredCodes[0].code);
                          setShowPicker(false);
                        }
                        if (e.key === "Escape") setShowPicker(false);
                      }}
                      placeholder="search country"
                      autoFocus
                      spellCheck={false}
                      autoComplete="off"
                      className="flex-1 bg-transparent outline-none"
                      style={{
                        fontSize: "15px",
                        fontWeight: 400,
                        color: W,
                        letterSpacing: "0.02em",
                        caretColor: ACCENT,
                        textShadow: TEXT_SHADOW,
                      }}
                    />
                    <span
                      role="button"
                      tabIndex={0}
                      onClick={() => setShowPicker(false)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") setShowPicker(false);
                      }}
                      className="cursor-pointer outline-none"
                      style={{
                        fontSize: "11px",
                        fontWeight: 300,
                        color: W,
                        opacity: 0.8,
                        textShadow: TEXT_SHADOW,
                      }}
                    >
                      cancel
                    </span>
                  </div>
                  <div style={{ maxHeight: "280px", overflowY: "auto" }}>
                    {filteredCodes.slice(0, 10).map((c) => (
                      <div
                        key={c.code}
                        role="button"
                        tabIndex={0}
                        onClick={() => {
                          setCountryCode(c.code);
                          setShowPicker(false);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") {
                            setCountryCode(c.code);
                            setShowPicker(false);
                          }
                        }}
                        className="cursor-pointer outline-none"
                        style={{
                          display: "flex",
                          alignItems: "baseline",
                          justifyContent: "space-between",
                          padding: "10px 0",
                          borderBottom: `1px solid ${W12}`,
                        }}
                      >
                        <span
                          style={{
                            fontSize: "14px",
                            fontWeight: 400,
                            color: W,
                            opacity: 1,
                            textShadow: TEXT_SHADOW,
                          }}
                        >
                          {c.name}
                        </span>
                        <span
                          style={{
                            fontSize: "13px",
                            fontWeight: 300,
                            color: ACCENT,
                            opacity: 0.9,
                          }}
                        >
                          {c.code}
                        </span>
                      </div>
                    ))}
                  </div>
                </motion.div>
              )}

              {/* ── OTP step ── */}
              {authStep === "otp" && (
                <motion.div key="otp" {...fieldTransition}>
                  <p
                    style={{
                      fontSize: "13px",
                      fontWeight: 300,
                      color: W,
                      opacity: 0.9,
                      letterSpacing: "0.04em",
                      marginBottom: "16px",
                      textShadow: TEXT_SHADOW,
                    }}
                  >
                    {countryCode} {phoneInput} · enter code
                  </p>
                  <div style={{ display: "flex", alignItems: "center" }}>
                    <input
                      ref={inputRef}
                      type="text"
                      inputMode="numeric"
                      value={otpInput}
                      onChange={(e) =>
                        setOtpInput(e.target.value.replace(/\D/g, "").slice(0, 6))
                      }
                      placeholder="······"
                      autoFocus
                      spellCheck={false}
                      autoComplete="one-time-code"
                      disabled={isBusy}
                      className="flex-1 bg-transparent outline-none"
                      style={{
                        fontSize: "32px",
                        fontWeight: 400,
                        color: W,
                        letterSpacing: "0.3em",
                        caretColor: ACCENT,
                        textShadow: TEXT_SHADOW,
                        opacity: isBusy ? 0.4 : 1,
                        transition: "opacity 0.2s ease",
                      }}
                    />
                  </div>
                </motion.div>
              )}

              {/* ── NAME step ── */}
              {authStep === "name" && (
                <motion.div key="name" {...fieldTransition}>
                  <p
                    style={{
                      fontSize: "13px",
                      fontWeight: 300,
                      color: W,
                      opacity: 0.9,
                      letterSpacing: "0.04em",
                      marginBottom: "16px",
                      textShadow: TEXT_SHADOW,
                    }}
                  >
                    your friends call you
                  </p>
                  <div style={{ display: "flex", alignItems: "center" }}>
                    <input
                      ref={inputRef}
                      type="text"
                      value={nameInput}
                      onChange={(e) => setNameInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && nameInput.trim()) submitName();
                      }}
                      placeholder="name"
                      autoFocus
                      spellCheck={false}
                      autoComplete="off"
                      className="flex-1 bg-transparent outline-none"
                      style={{
                        fontSize: "26px",
                        fontWeight: 400,
                        color: W,
                        letterSpacing: "0.02em",
                        caretColor: ACCENT,
                        opacity: 1,
                        textShadow: TEXT_SHADOW,
                      }}
                    />
                    <span
                      role="button"
                      tabIndex={0}
                      onClick={() => {
                        if (nameInput.trim()) submitName();
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" && nameInput.trim()) submitName();
                      }}
                      className="outline-none"
                      style={{
                        color: W,
                        opacity: nameInput.trim() ? 0.9 : 0.15,
                        cursor: nameInput.trim() ? "pointer" : "default",
                        transition: "opacity 0.2s ease",
                        flexShrink: 0,
                      }}
                    >
                      <ArrowIcon />
                    </span>
                  </div>
                </motion.div>
              )}

            </AnimatePresence>

            {/* Accent line */}
            <div
              style={{
                marginTop: "10px",
                height: "1px",
                width: authStep === "otp" ? "100px" : authStep === "name" ? "60px" : "100px",
                background: `linear-gradient(90deg, ${ACCENT}, transparent)`,
                animation: isBusy ? "none" : "ambientBreath 4.5s ease-in-out infinite",
                opacity: isBusy ? 0.2 : 0.6,
                transition: "width 0.5s ease",
              }}
            />

            {/* Auth error */}
            <AnimatePresence>
              {authError && (
                <motion.p
                  initial={{ opacity: 0, y: 4 }}
                  animate={{ opacity: 0.9, y: 0 }}
                  exit={{ opacity: 0 }}
                  style={{
                    fontSize: "11px",
                    fontWeight: 300,
                    color: ERROR,
                    marginTop: "12px",
                    letterSpacing: "0.02em",
                  }}
                >
                  {authError}
                </motion.p>
              )}
            </AnimatePresence>
          </motion.div>
        )}

        {/* ── CLAIMING ── */}
        {screen === "claiming" && (
          <motion.div
            key="claiming"
            className="flex flex-1 flex-col items-center justify-center"
            style={{ zIndex: 10 }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4 }}
          >
            <motion.div
              style={{
                width: "10px",
                height: "10px",
                borderRadius: "50%",
                background: BRAND,
              }}
              animate={{ opacity: [0.4, 0.9, 0.4] }}
              transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
            />
            <motion.p
              style={{
                fontSize: "13px",
                fontWeight: 300,
                color: W,
                opacity: 0.5,
                marginTop: "20px",
                letterSpacing: "0.04em",
                textShadow: TEXT_SHADOW,
              }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.5 }}
              transition={{ delay: 0.3 }}
            >
              creating your space...
            </motion.p>
          </motion.div>
        )}

      </AnimatePresence>

      {/* ── Encrypted badge — persistent ── */}
      <div
        style={{
          position: "fixed",
          bottom: "56px",
          left: "36px",
          display: "flex",
          alignItems: "center",
          gap: "6px",
          zIndex: 10,
          color: W,
        }}
      >
        <ShieldIcon />
        <span
          style={{
            fontSize: "11px",
            letterSpacing: "0.12em",
            color: W,
            opacity: 0.7,
            textTransform: "uppercase",
            textShadow: TEXT_SHADOW,
          }}
        >
          encrypted
        </span>
      </div>

      <style jsx>{`
        input::placeholder {
          color: rgba(255, 255, 255, 0.6);
          opacity: 1;
          letter-spacing: 0.08em;
          text-shadow: 0 1px 4px rgba(0, 0, 0, 0.5);
        }
        input:focus::placeholder {
          opacity: 0.7;
          transition: opacity 0.6s ease;
        }
      `}</style>
    </div>
  );
}
