from PIL import Image
import sys

def remove_white_smooth(img_path):
    img = Image.open(img_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            lum = (r + g + b) / 3.0
            
            if lum > 245:
                # pure white -> fully transparent
                pixels[x, y] = (r, g, b, 0)
            elif lum > 220:
                # soft blend the edges so they aren't jagged
                alpha_val = int(((245 - lum) / 25.0) * 255)
                # clamp
                alpha_val = max(0, min(255, alpha_val))
                pixels[x, y] = (r, g, b, alpha_val)
                
    img.save(img_path, "PNG")
    print(f"Processed {img_path}")

if __name__ == "__main__":
    for f in sys.argv[1:]:
        remove_white_smooth(f)
