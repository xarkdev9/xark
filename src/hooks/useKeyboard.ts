// Tracks virtual keyboard height via visualViewport API.
// iOS 13+, all Android. Falls back to 0 height if unsupported.

"use client";

import { useState, useEffect } from "react";

interface KeyboardState {
  keyboardHeight: number;
  isKeyboardOpen: boolean;
}

export function useKeyboard(): KeyboardState {
  const [state, setState] = useState<KeyboardState>({
    keyboardHeight: 0,
    isKeyboardOpen: false,
  });

  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;

    const update = () => {
      const keyboardHeight = Math.max(0, window.innerHeight - vv.height);
      setState({
        keyboardHeight,
        isKeyboardOpen: keyboardHeight > 50,
      });
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
