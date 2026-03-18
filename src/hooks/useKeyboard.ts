// Tracks virtual keyboard height via visualViewport API.
// iOS: viewport doesn't resize, keyboard overlaps — need explicit offset.
// Android: viewport resizes with keyboard — no extra offset needed.
// Detects platform to avoid double-offset on Android.

"use client";

import { useState, useEffect, useRef } from "react";

interface KeyboardState {
  keyboardHeight: number;
  isKeyboardOpen: boolean;
}

export function useKeyboard(): KeyboardState {
  const [state, setState] = useState<KeyboardState>({
    keyboardHeight: 0,
    isKeyboardOpen: false,
  });
  const initialHeight = useRef(0);

  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;

    // Capture initial viewport height (before keyboard)
    initialHeight.current = vv.height;

    // Detect if Android (viewport resizes with keyboard — no extra offset needed)
    const isAndroid = /android/i.test(navigator.userAgent);

    const update = () => {
      if (isAndroid) {
        // Android: viewport resizes, so CSS `bottom` values already work correctly.
        // Only report isKeyboardOpen for conditional logic, but keyboardHeight stays 0.
        const heightDrop = initialHeight.current - vv.height;
        setState({
          keyboardHeight: 0, // Don't offset — viewport already resized
          isKeyboardOpen: heightDrop > 100,
        });
      } else {
        // iOS: viewport doesn't resize, keyboard overlaps content.
        // Need explicit offset to push input above keyboard.
        const keyboardHeight = Math.max(0, window.innerHeight - vv.height);
        setState({
          keyboardHeight,
          isKeyboardOpen: keyboardHeight > 50,
        });
      }
    };

    vv.addEventListener("resize", update);
    vv.addEventListener("scroll", update);

    return () => {
      vv.removeEventListener("resize", update);
      vv.removeEventListener("scroll", update);
    };
  }, []);

  return state;
}
