// XARK OS v2.0 — Media Service
// Firebase Storage for blobs, Supabase for metadata.

import { storageAdapter } from "@/lib/storage";
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
  groupId: string;
  uploadedBy: string;
  storagePath: string;
  thumbnailUrl?: string;
  caption?: string;
  createdAt: string;
}

export async function uploadMedia(
  file: File,
  groupId: string,
  userId: string,
  caption?: string
): Promise<MediaItem | null> {
  const mediaId = `media_${generateId()}`;
  const storagePath = `spaces/${groupId}/media/${mediaId}`;
  let downloadUrl: string;
  try {
    downloadUrl = await storageAdapter.upload(storagePath, file, file.type);
  } catch {
    console.warn("Storage not configured");
    return null;
  }

  // Save metadata to Supabase
  const { error } = await supabase.from("media").insert({
    id: mediaId,
    group_id: groupId,
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
    groupId,
    uploadedBy: userId,
    storagePath,
    thumbnailUrl: downloadUrl,
    caption,
    createdAt: new Date().toISOString(),
  };
}

export async function fetchMedia(groupId: string): Promise<MediaItem[]> {
  const { data, error } = await supabase
    .from("media")
    .select("*")
    .eq("group_id", groupId)
    .order("created_at", { ascending: true });

  if (error || !data) return [];

  return data.map((m) => ({
    id: m.id,
    groupId: m.group_id,
    uploadedBy: m.uploaded_by,
    storagePath: m.storage_path,
    thumbnailUrl: m.thumbnail_url,
    caption: m.caption,
    createdAt: m.created_at,
  }));
}
