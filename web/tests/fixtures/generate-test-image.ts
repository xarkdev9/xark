// Generate a minimal valid PNG file for E2E testing.
// Creates a 100x100 colored PNG with a unique pixel pattern per index
// so each file is cryptographically distinct (different AES ciphertexts).

import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { deflateSync } from 'zlib';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const WIDTH = 100;
const HEIGHT = 100;

/** Create a minimal PNG from raw RGBA pixel data */
function createPNG(pixels: Uint8Array): Buffer {
  // PNG uses zlib-compressed IDAT chunks. For simplicity, use an uncompressed
  // deflate block (valid zlib). Each row is prefixed with filter byte 0 (None).
  const rowSize = 1 + WIDTH * 4; // filter byte + RGBA
  const rawData = Buffer.alloc(rowSize * HEIGHT);

  for (let y = 0; y < HEIGHT; y++) {
    const rowOffset = y * rowSize;
    rawData[rowOffset] = 0; // filter: None
    const rowPixels = pixels.slice(y * WIDTH * 4, (y + 1) * WIDTH * 4);
    rawData.set(rowPixels, rowOffset + 1);
  }

  // Compress with Node's zlib
  const compressed = deflateSync(rawData);

  // Build PNG file
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  function chunk(type: string, data: Buffer): Buffer {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const typeBytes = Buffer.from(type, 'ascii');
    const crcInput = Buffer.concat([typeBytes, data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(crcInput));
    return Buffer.concat([len, typeBytes, data, crc]);
  }

  // IHDR
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(WIDTH, 0);
  ihdr.writeUInt32BE(HEIGHT, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // color type: RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace

  const idat = compressed;
  const iend = Buffer.alloc(0);

  return Buffer.concat([
    signature,
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', iend),
  ]);
}

/** CRC-32 for PNG chunks */
function crc32(buf: Buffer): number {
  let crc = 0xFFFFFFFF;
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) {
      c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c;
  }
  for (let i = 0; i < buf.length; i++) {
    crc = table[(crc ^ buf[i]) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

export function generateTestImages(count: number): string[] {
  const dir = join(__dirname, 'images');
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

  const paths: string[] = [];

  for (let i = 0; i < count; i++) {
    // Generate unique colored pixels per image
    const pixels = new Uint8Array(WIDTH * HEIGHT * 4);
    const r = (i * 51) % 256;
    const g = (i * 97 + 80) % 256;
    const b = (i * 153 + 160) % 256;

    for (let p = 0; p < WIDTH * HEIGHT; p++) {
      const offset = p * 4;
      pixels[offset] = r;
      pixels[offset + 1] = g;
      pixels[offset + 2] = b;
      pixels[offset + 3] = 255; // fully opaque
    }

    const png = createPNG(pixels);
    const filePath = join(dir, `test-image-${i}.png`);
    writeFileSync(filePath, png);
    paths.push(filePath);
  }

  return paths;
}

// CLI: npx tsx tests/fixtures/generate-test-image.ts
const isDirectRun = typeof process !== 'undefined' && process.argv[1]?.includes('generate-test-image');
if (isDirectRun) {
  const paths = generateTestImages(5);
  console.log(`Generated ${paths.length} test images:`);
  paths.forEach(p => console.log(`  ${p}`));
}
