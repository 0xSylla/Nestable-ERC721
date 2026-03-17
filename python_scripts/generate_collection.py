"""
Generate a collection of 100 unique CharacterNFTs from layer variants.

Prepares an IPFS-ready folder structure:
    output/
    ├── manifests/          ← CHARACTER_MANIFEST_URI
    │   ├── 0.json .. 99.json
    └── layers/
        ├── 0/              ← layers for character #0
        │   ├── background.png
        │   ├── rockets.png
        │   ├── body.png
        │   ├── face.png
        │   └── items.png
        ├── 1/ ...
        └── ...

Layer order (bottom to top):
    Background  (z=0)
    [MOON slot] (z=10)
    Rockets     (z=20)
    [PASSENGER] (z=30)
    Dirac Body  (z=40)
    Dirac Face  (z=50)
    Dirac Items (z=60)

Usage:
    python scripts/generate_collection.py [output_dir] [count] [--ipfs-cid CID]

    output_dir : where to write (default: ipfs_upload)
    count      : number of unique NFTs (default: 100)
    --ipfs-cid : if set, manifests use ipfs://CID/layers/... URIs
                 if omitted, manifests use relative paths (fill in CID after upload)

Example:
    python scripts/generate_collection.py ipfs_upload 100
    # upload ipfs_upload/ to IPFS -> get ROOT_CID
    # then: python scripts/generate_collection.py ipfs_upload 100 --ipfs-cid ROOT_CID
"""

import json
import random
import shutil
import sys
from pathlib import Path

# ─── Config ───────────────────────────────────────────────────────────────────

LAYERS_SOURCE = Path(__file__).resolve().parent.parent / "BeracPOL²"

# Layer definitions: (source_folder, output_filename, z_index)
# Slots are defined inline between layers
LAYER_DEFS = [
    ("Background",  "background.png", 0),
    # MOON slot at z=10
    ("Rockets",     "rockets.png",    20),
    # PASSENGER slot at z=30
    ("Dirac Body",  "body.png",       40),
    ("Dirac Face",  "face.png",       50),
    ("Dirac Items", "items.png",      60),
]

SLOTS = [
    {"slot": "MOON",      "z": 10},
    {"slot": "PASSENGER", "z": 30},
]

DEFAULT_COUNT = 100


def get_variants(layer_name: str) -> list[Path]:
    """Get all image files for a layer, sorted for determinism."""
    folder = LAYERS_SOURCE / layer_name
    if not folder.is_dir():
        raise FileNotFoundError(f"Layer folder not found: {folder}")
    variants = sorted(
        f for f in folder.iterdir()
        if f.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )
    if not variants:
        raise ValueError(f"No images found in {folder}")
    return variants


def generate_unique_combos(count: int) -> list[tuple]:
    """Generate `count` unique random combinations of layer variants."""
    all_variants = [get_variants(name) for name, _, _ in LAYER_DEFS]

    total_possible = 1
    for v in all_variants:
        total_possible *= len(v)

    if count > total_possible:
        raise ValueError(
            f"Requested {count} unique NFTs but only {total_possible} combinations possible"
        )

    seen = set()
    result = []
    attempts = 0
    max_attempts = count * 100

    while len(result) < count and attempts < max_attempts:
        combo = tuple(random.choice(v) for v in all_variants)
        key = tuple(f.name for f in combo)
        if key not in seen:
            seen.add(key)
            result.append(combo)
        attempts += 1

    if len(result) < count:
        raise RuntimeError(f"Could only generate {len(result)} unique combos after {max_attempts} attempts")

    return result


def build_manifest(token_id: int, ipfs_cid: str | None) -> dict:
    """Build the layer manifest JSON for a token."""
    layers = []

    if ipfs_cid:
        base = f"ipfs://{ipfs_cid}/layers/{token_id}"
    else:
        base = f"IPFS_CID_PLACEHOLDER/layers/{token_id}"

    for _, output_name, z in LAYER_DEFS:
        layers.append({"uri": f"{base}/{output_name}", "z": z})

    # Insert slots
    for slot in SLOTS:
        layers.append(dict(slot))  # copy

    # Sort by z for readability
    layers.sort(key=lambda l: l["z"])

    return {"layers": layers}


def main() -> None:
    args = sys.argv[1:]

    output_dir = Path(args[0]) if args else Path("ipfs_upload")
    count = int(args[1]) if len(args) > 1 else DEFAULT_COUNT

    ipfs_cid = None
    if "--ipfs-cid" in args:
        idx = args.index("--ipfs-cid")
        ipfs_cid = args[idx + 1]

    layers_dir = output_dir / "layers"
    manifests_dir = output_dir / "manifests"

    # ─── CID-only mode: just rewrite manifests using existing layers ─────────
    if ipfs_cid and manifests_dir.exists():
        print(f"Updating {count} manifests with CID: {ipfs_cid}")
        for token_id in range(count):
            manifest_path = manifests_dir / f"{token_id}.json"
            if not manifest_path.exists():
                print(f"  WARNING: {manifest_path} not found, skipping")
                continue

            existing = json.loads(manifest_path.read_text())
            # Rebuild manifest with real CID, keep traits
            manifest = build_manifest(token_id, ipfs_cid)
            manifest["traits"] = existing.get("traits", {})
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

        print(f"Done! Updated {count} manifests with ipfs://{ipfs_cid}/...")
        print(f"Re-upload {manifests_dir}/ to IPFS, then set:")
        print(f"  CHARACTER_MANIFEST_URI=ipfs://{ipfs_cid}/manifests/")
        return

    # ─── Full generation mode ────────────────────────────────────────────────
    print(f"Generating {count} unique characters from {LAYERS_SOURCE}")
    print(f"Output: {output_dir}")

    for name, _, z in LAYER_DEFS:
        variants = get_variants(name)
        print(f"  {name}: {len(variants)} variants (z={z})")
    print()

    random.seed(42)  # deterministic for reproducibility
    combos = generate_unique_combos(count)

    layers_dir.mkdir(parents=True, exist_ok=True)
    manifests_dir.mkdir(parents=True, exist_ok=True)

    for token_id, combo in enumerate(combos):
        char_dir = layers_dir / str(token_id)
        char_dir.mkdir(exist_ok=True)

        traits = {}
        for (layer_name, output_name, _), src_path in zip(LAYER_DEFS, combo):
            dst = char_dir / output_name
            shutil.copy2(src_path, dst)
            traits[layer_name] = src_path.stem

        manifest = build_manifest(token_id, None)
        manifest["traits"] = traits

        manifest_path = manifests_dir / f"{token_id}.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

        if token_id < 3 or token_id == count - 1:
            print(f"  #{token_id}: {', '.join(traits.values())}")
        elif token_id == 3:
            print(f"  ... ({count - 4} more)")

    print(f"\nDone! {count} characters generated in {output_dir}/")
    print(f"\nNext steps:")
    print(f"  1. Upload {output_dir}/ to IPFS -> get ROOT_CID")
    print(f"  2. Re-run to update manifest URIs:")
    print(f"     python scripts/generate_collection.py {output_dir} {count} --ipfs-cid ROOT_CID")
    print(f"  3. Re-upload {manifests_dir}/ (or the whole folder)")
    print(f"  4. Set CHARACTER_MANIFEST_URI=ipfs://ROOT_CID/manifests/ in renderer .env")


if __name__ == "__main__":
    main()
