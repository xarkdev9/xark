// hello OS v2.0 — Voice Input Hook
// 2-step: Tap mic = dictation. Slide up = @hello listening.
// Unmissable recording state. Single tap always toggles off.
// Cleanup on unmount — mic never stays on silently.

import { useState, useRef, useCallback, useEffect } from "react";

type VoiceMode = "off" | "dictation" | "hello";

interface VoiceInputResult {
  isListening: boolean;
  ishelloListening: boolean;
  mode: VoiceMode;
  transcript: string;
  toggleDictation: () => void;
  starthelloMode: () => void;
  stop: () => void;
  error: string | null;
}

export function useVoiceInput(): VoiceInputResult {
  const [mode, setMode] = useState<VoiceMode>("off");
  const [transcript, setTranscript] = useState("");
  const [error, setError] = useState<string | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Clear safety timeout
  const clearSafetyTimeout = useCallback(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
  }, []);

  // Cleanup on unmount — critical for privacy
  useEffect(() => {
    return () => {
      clearSafetyTimeout();
      recognitionRef.current?.stop();
      recognitionRef.current = null;
    };
  }, [clearSafetyTimeout]);

  const stop = useCallback(() => {
    clearSafetyTimeout();
    try { recognitionRef.current?.stop(); } catch { /* already stopped */ }
    recognitionRef.current = null;
    setMode("off");
  }, [clearSafetyTimeout]);

  const startRecognition = useCallback((targetMode: VoiceMode) => {
    // Always stop any existing recognition first
    clearSafetyTimeout();
    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch { /* ignore */ }
      recognitionRef.current = null;
    }

    const SpeechRecognitionAPI =
      typeof window !== "undefined"
        ? window.SpeechRecognition || window.webkitSpeechRecognition
        : null;

    if (!SpeechRecognitionAPI) {
      setError("speech recognition not supported");
      return;
    }

    const recognition = new SpeechRecognitionAPI();
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = "en-US";

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      clearSafetyTimeout();
      const result = event.results[0][0].transcript;
      setTranscript(targetMode === "hello" ? `@hello ${result}` : result);
    };

    recognition.onerror = () => {
      clearSafetyTimeout();
      setMode("off");
      recognitionRef.current = null;
      setError("voice recognition failed");
    };

    recognition.onend = () => {
      clearSafetyTimeout();
      setMode("off");
      recognitionRef.current = null;
    };

    recognitionRef.current = recognition;
    recognition.start();
    setMode(targetMode);
    setError(null);
    setTranscript("");

    // Safety timeout — auto-stop after 10s to prevent stuck mic
    timeoutRef.current = setTimeout(() => {
      if (recognitionRef.current) {
        try { recognitionRef.current.stop(); } catch { /* ignore */ }
        recognitionRef.current = null;
        setMode("off");
      }
    }, 10_000);
  }, [clearSafetyTimeout]);

  const toggleDictation = useCallback(() => {
    if (mode !== "off") {
      stop();
    } else {
      startRecognition("dictation");
    }
  }, [mode, stop, startRecognition]);

  const starthelloMode = useCallback(() => {
    if (mode !== "off") {
      stop();
    } else {
      startRecognition("hello");
    }
  }, [mode, stop, startRecognition]);

  return {
    isListening: mode === "dictation",
    ishelloListening: mode === "hello",
    mode,
    transcript,
    toggleDictation,
    starthelloMode,
    stop,
    error,
  };
}
