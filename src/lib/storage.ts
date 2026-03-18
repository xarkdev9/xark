// XARK OS v2.0 — Storage Adapter
// Provider-agnostic storage interface. Firebase implementation is default.
// To switch providers: implement StorageAdapter, swap the export.

import { storage } from "@/lib/firebase";
import { ref, uploadBytes, getDownloadURL, deleteObject } from "firebase/storage";

export interface StorageAdapter {
  upload(path: string, file: File | Blob, contentType?: string): Promise<string>; // returns public URL
  delete(path: string): Promise<void>;
}

class FirebaseStorageAdapter implements StorageAdapter {
  async upload(path: string, file: File | Blob, contentType?: string): Promise<string> {
    if (!storage) throw new Error("Firebase Storage not configured");
    const storageRef = ref(storage, path);
    await uploadBytes(storageRef, file, contentType ? { contentType } : undefined);
    return getDownloadURL(storageRef);
  }

  async delete(path: string): Promise<void> {
    if (!storage) throw new Error("Firebase Storage not configured");
    await deleteObject(ref(storage, path));
  }
}

export const storageAdapter: StorageAdapter = new FirebaseStorageAdapter();
