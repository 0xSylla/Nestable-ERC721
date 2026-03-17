"""
Convert all images in a folder to black & white (grayscale).

Usage:
    python scripts/convert_bw.py <input_folder> [output_folder]

If output_folder is omitted, creates <input_folder>_bw/ next to the input.
"""

import sys
import os
from pathlib import Path
from PIL import Image

SUPPORTED = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff"}


def convert_to_bw(input_dir: Path, output_dir: Path, suffix: str = "_bw") -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    files = [f for f in input_dir.iterdir() if f.suffix.lower() in SUPPORTED and suffix not in f.stem]
    if not files:
        print(f"No supported images found in {input_dir}")
        return

    for img_path in sorted(files):
        img = Image.open(img_path).convert("L")  # grayscale
        out_path = output_dir / f"{img_path.stem}{suffix}{img_path.suffix}"
        img.save(out_path)
        print(f"  {img_path.name} -> {out_path.name}")

    print(f"\nConverted {len(files)} images in {output_dir}")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python convert_bw.py <input_folder> [output_folder]")
        sys.exit(1)

    input_dir = Path(sys.argv[1])
    if not input_dir.is_dir():
        print(f"Error: {input_dir} is not a directory")
        sys.exit(1)

    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else input_dir

    convert_to_bw(input_dir, output_dir)


if __name__ == "__main__":
    main()
