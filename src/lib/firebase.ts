// XARK OS v2.0 — FIREBASE CLIENT
// Phone OTP Authentication + E2EE Multimedia Storage.
// Database is Supabase Postgres (see supabase.ts). Do NOT use Firebase for DB.
// Safe initialization: when env vars are missing, exports null for auth/storage.

import { initializeApp, getApps } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";
import { getStorage, type FirebaseStorage } from "firebase/storage";

const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? "";

const firebaseConfig = {
  apiKey,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? "",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? "",
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET ?? "",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID ?? "",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID ?? "",
};

// Guard: Firebase requires a valid API key. Skip initialization when unconfigured.
const isConfigured = apiKey.length > 0;

const app = isConfigured
  ? getApps().length === 0
    ? initializeApp(firebaseConfig)
    : getApps()[0]
  : null;

// Phone OTP — the only auth provider for Xark OS
export const auth: Auth | null = app ? getAuth(app) : null;

// E2EE Multimedia — binary blob storage with bucket-level security rules
export const storage: FirebaseStorage | null = app ? getStorage(app) : null;

export default app;
