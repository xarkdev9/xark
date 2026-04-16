import sys
from rembg import remove
from PIL import Image

def process(img_path):
    print(f"Processing {img_path} with pure rembg API...")
    with open(img_path, 'rb') as i:
        input_data = i.read()
    
    output_data = remove(input_data)
    
    with open(img_path, 'wb') as o:
        o.write(output_data)
    print(f"Finished {img_path}")

if __name__ == "__main__":
    for path in sys.argv[1:]:
        process(path)
