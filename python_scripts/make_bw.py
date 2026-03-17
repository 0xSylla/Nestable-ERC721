"""
Convert all images in a folder to grayscale copies.

Usage:
    python scripts/make_bw.py <input_folder> [output_folder]

If output_folder is omitted, creates a sibling folder named <input_folder>_bw.
"""

import sys
from pathlib import Path
from PIL import Image

SUPPORTED = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff"}


def convert(src: Path, dst: Path):
    img = Image.open(src).convert("LA")  # grayscale + alpha
    if src.suffix.lower() in {".jpg", ".jpeg"}:
        img = img.convert("L")  # no alpha for JPEG
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst)
    print(f"  {src.name} -> {dst}")


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        sys.exit(1)

    in_dir = Path(sys.argv[1])
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else in_dir.parent / f"{in_dir.name}_bw"

    if not in_dir.is_dir():
        print(f"Error: {in_dir} is not a directory")
        sys.exit(1)

    files = sorted(f for f in in_dir.iterdir() if f.suffix.lower() in SUPPORTED)
    if not files:
        print(f"No supported images found in {in_dir}")
        sys.exit(1)

    print(f"Converting {len(files)} images -> {out_dir}")
    for f in files:
        convert(f, out_dir / f.name)
    print("Done.")


if __name__ == "__main__":
    main()
