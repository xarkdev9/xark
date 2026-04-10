// hello OS v2.0 — Inline Thumbnail Generator
// Generates tiny Base64 thumbnails (max 100px, JPEG q=0.4) client-side.
// Thumbnails travel inside the E2EE payload so recipients see an instant
// blurry preview while the full encrypted blob downloads and decrypts.

const MAX_THUMB_SIZE = 100; // px
const JPEG_QUALITY = 0.4;

/**
 * Generate a tiny inline thumbnail from an image or video file.
 * Returns a data:image/jpeg;base64,... string, or null if generation fails.
 *
 * Images: drawn to canvas at ≤100px, exported as JPEG.
 * Videos: seek to 0.1s, capture first frame to canvas, export as JPEG.
 */
export async function generateInlineThumbnail(file: File): Promise<string | null> {
  try {
    if (file.type.startsWith('image/')) {
      return await generateImageThumbnail(file);
    }
    if (file.type.startsWith('video/')) {
      return await generateVideoThumbnail(file);
    }
    return null;
  } catch (err) {
    console.warn('[thumbnail] Generation failed:', err);
    return null;
  }
}

function generateImageThumbnail(file: File): Promise<string | null> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const img = new Image();

    img.onload = () => {
      try {
        const dataUrl = drawToCanvas(img, img.naturalWidth, img.naturalHeight);
        resolve(dataUrl);
      } catch {
        resolve(null);
      } finally {
        URL.revokeObjectURL(url);
      }
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      resolve(null);
    };

    img.src = url;
  });
}

function generateVideoThumbnail(file: File): Promise<string | null> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement('video');
    video.preload = 'metadata';
    video.muted = true;
    video.playsInline = true;

    // Timeout: if video never loads, give up after 5s
    const timeout = setTimeout(() => {
      cleanup();
      resolve(null);
    }, 5000);

    const cleanup = () => {
      clearTimeout(timeout);
      video.removeAttribute('src');
      video.load(); // release resources
      URL.revokeObjectURL(url);
    };

    video.onloadeddata = () => {
      // Seek slightly in to avoid potential black first frame
      video.currentTime = 0.1;
    };

    video.onseeked = () => {
      try {
        const dataUrl = drawToCanvas(video, video.videoWidth, video.videoHeight);
        resolve(dataUrl);
      } catch {
        resolve(null);
      } finally {
        cleanup();
      }
    };

    video.onerror = () => {
      cleanup();
      resolve(null);
    };

    video.src = url;
  });
}

/**
 * Draw an image or video frame to a canvas scaled to MAX_THUMB_SIZE,
 * then export as a compressed JPEG data URL.
 */
function drawToCanvas(
  source: HTMLImageElement | HTMLVideoElement,
  sourceWidth: number,
  sourceHeight: number
): string | null {
  if (sourceWidth === 0 || sourceHeight === 0) return null;

  // Scale down to fit within MAX_THUMB_SIZE box
  const scale = Math.min(MAX_THUMB_SIZE / sourceWidth, MAX_THUMB_SIZE / sourceHeight, 1);
  const width = Math.round(sourceWidth * scale);
  const height = Math.round(sourceHeight * scale);

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext('2d');
  if (!ctx) return null;

  ctx.drawImage(source, 0, 0, width, height);

  return canvas.toDataURL('image/jpeg', JPEG_QUALITY);
}
