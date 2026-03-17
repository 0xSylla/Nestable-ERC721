"""
Generate layer manifests for CharacterNFT tokens.

Usage:
    python scripts/generate_manifests.py <character_images_cid> <output_dir> <count>

Example (flat images — wraps each as a single base layer with gear slots on top):
    python scripts/generate_manifests.py QmTLofHoNveoW9UCLPe7GQkfJ8N4S3raPb5YfCNqxw4ZTT renderer/manifests 10

Example output (renderer/manifests/0.json):
    {
      "layers": [
        { "uri": "ipfs://QmXxx/0.png", "z": 0 },
        { "slot": "PASSENGER",         "z": 10 },
        { "slot": "MOON",              "z": 20 }
      ]
    }

For multi-layer characters, create manifests manually or modify this script
to reference individual layer PNGs:
    {
      "layers": [
        { "uri": "ipfs://CID/0/background.png", "z": 0  },
        { "uri": "ipfs://CID/0/body.png",       "z": 10 },
        { "slot": "PASSENGER",                   "z": 15 },
        { "uri": "ipfs://CID/0/jacket.png",      "z": 20 },
        { "uri": "ipfs://CID/0/head.png",        "z": 30 },
        { "slot": "MOON",                        "z": 35 }
      ]
    }
"""

import json
import sys
from pathlib import Path


def generate_flat_manifest(cid: str, token_id: int) -> dict:
    """Wrap a flat character image as a single-layer manifest with gear slots."""
    return {
        "layers": [
            {"uri": f"ipfs://{cid}/{token_id}.png", "z": 0},
            {"slot": "PASSENGER", "z": 10},
            {"slot": "MOON", "z": 20},
        ]
    }


def main() -> None:
    if len(sys.argv) < 4:
        print("Usage: python generate_manifests.py <character_images_cid> <output_dir> <count>")
        sys.exit(1)

    cid = sys.argv[1]
    output_dir = Path(sys.argv[2])
    count = int(sys.argv[3])

    output_dir.mkdir(parents=True, exist_ok=True)

    for i in range(count):
        manifest = generate_flat_manifest(cid, i)
        out_path = output_dir / f"{i}.json"
        out_path.write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"  {out_path}")

    print(f"\nGenerated {count} manifests in {output_dir}")


if __name__ == "__main__":
    main()
