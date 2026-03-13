// XARK OS v2.0 — Voice Input Hook
// Tap: on-device SpeechRecognition (instant, no network)
// Long-press: @xark listening mode (auto-prefixes "@xark")

import { useState, useRef, useCallback } from "react";

interface VoiceInputResult {
  isListening: boolean;
  isXarkListening: boolean;
  transcript: string;
  startListening: () => void;
  startXarkListening: () => void;
  stopListening: () => void;
  error: string | null;
}

export function useVoiceInput(): VoiceInputResult {
  const [isListening, setIsListening] = useState(false);
  const [isXarkListening, setIsXarkListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [error, setError] = useState<string | null>(null);
  const recognitionRef = useRef<SpeechRecognition | null>(null);

  const startListening = useCallback(() => {
    const SpeechRecognitionAPI =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognitionAPI) {
      setError("speech recognition not supported");
      return;
    }

    const recognition = new SpeechRecognitionAPI();
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = "en-US";

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      const result = event.results[0][0].transcript;
      setTranscript(result);
      setIsListening(false);
    };

    recognition.onerror = () => {
      setIsListening(false);
      setError("voice recognition failed");
    };

    recognition.onend = () => setIsListening(false);

    recognitionRef.current = recognition;
    recognition.start();
    setIsListening(true);
    setError(null);
    setTranscript("");
  }, []);

  const startXarkListening = useCallback(() => {
    const SpeechRecognitionAPI =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognitionAPI) {
      setError("speech recognition not supported");
      return;
    }

    const recognition = new SpeechRecognitionAPI();
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = "en-US";

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      const result = event.results[0][0].transcript;
      setTranscript(`@xark ${result}`);
      setIsXarkListening(false);
    };

    recognition.onerror = () => {
      setIsXarkListening(false);
      setError("voice recognition failed");
    };

    recognition.onend = () => setIsXarkListening(false);

    recognitionRef.current = recognition;
    recognition.start();
    setIsXarkListening(true);
    setError(null);
    setTranscript("");
  }, []);

  const stopListening = useCallback(() => {
    recognitionRef.current?.stop();
    setIsListening(false);
    setIsXarkListening(false);
  }, []);

  return {
    isListening,
    isXarkListening,
    transcript,
    startListening,
    startXarkListening,
    stopListening,
    error,
  };
}
