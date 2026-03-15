// XARK OS v2.0 — Media Service
// Firebase Storage for blobs, Supabase for metadata.

import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { supabase } from "@/lib/supabase";

function generateId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export interface MediaItem {
  id: string;
  spaceId: string;
  uploadedBy: string;
  storagePath: string;
  thumbnailUrl?: string;
  caption?: string;
  createdAt: string;
}

export async function uploadMedia(
  file: File,
  spaceId: string,
  userId: string,
  caption?: string
): Promise<MediaItem | null> {
  if (!storage) {
    console.warn("Firebase Storage not configured");
    return null;
  }

  const mediaId = `media_${generateId()}`;
  const storagePath = `spaces/${spaceId}/media/${mediaId}`;
  const storageRef = ref(storage, storagePath);

  // Upload to Firebase Storage
  await uploadBytes(storageRef, file);
  const downloadUrl = await getDownloadURL(storageRef);

  // Save metadata to Supabase
  const { error } = await supabase.from("media").insert({
    id: mediaId,
    space_id: spaceId,
    uploaded_by: userId,
    storage_path: storagePath,
    thumbnail_url: downloadUrl,
    mime_type: file.type,
    caption: caption ?? null,
  });

  if (error) {
    console.error("Failed to save media metadata:", error.message);
    return null;
  }

  return {
    id: mediaId,
    spaceId,
    uploadedBy: userId,
    storagePath,
    thumbnailUrl: downloadUrl,
    caption,
    createdAt: new Date().toISOString(),
  };
}

export async function fetchMedia(spaceId: string): Promise<MediaItem[]> {
  const { data, error } = await supabase
    .from("media")
    .select("*")
    .eq("space_id", spaceId)
    .order("created_at", { ascending: true });

  if (error || !data) return [];

  return data.map((m) => ({
    id: m.id,
    spaceId: m.space_id,
    uploadedBy: m.uploaded_by,
    storagePath: m.storage_path,
    thumbnailUrl: m.thumbnail_url,
    caption: m.caption,
    createdAt: m.created_at,
  }));
}
