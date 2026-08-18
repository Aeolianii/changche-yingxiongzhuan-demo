#!/usr/bin/env python3
"""Slice and verify the sea-overworld production master image."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageChops


MASTER_SIZE = (6528, 3604)
CHUNK_SIZE = (3344, 1882)
OVERLAP = 160
CHUNKS = {
    "a": (0, 0, 3344, 1882),
    "b": (3184, 0, 6528, 1882),
    "c": (0, 1722, 3344, 3604),
    "d": (3184, 1722, 6528, 3604),
}
OUTPUT_NAMES = {
    "a": "guangdong_sea_zone_a_v3.png",
    "b": "guangdong_sea_zone_b_v3.png",
    "c": "guangdong_sea_zone_c_v3.png",
    "d": "guangdong_sea_zone_d_v3.png",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Crop the approved 6528x3604 sea map into four verified chunks."
    )
    parser.add_argument("--source", type=Path, required=True, help="Production master PNG")
    parser.add_argument(
        "--output-dir", type=Path, required=True, help="Directory for the four runtime PNGs"
    )
    return parser.parse_args()


def require_equal(first: Image.Image, second: Image.Image, seam_name: str) -> None:
    if first.size != second.size:
        raise ValueError(
            f"{seam_name} seam size mismatch: {first.size} versus {second.size}"
        )
    if ImageChops.difference(first, second).getbbox() is not None:
        raise ValueError(f"{seam_name} overlap pixels do not match")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def main() -> int:
    args = parse_args()
    if not args.source.is_file():
        raise FileNotFoundError(f"Master image not found: {args.source}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    with Image.open(args.source) as source_image:
        source_image.load()
        if source_image.size != MASTER_SIZE:
            raise ValueError(
                f"Master must be {MASTER_SIZE[0]}x{MASTER_SIZE[1]}, got "
                f"{source_image.size[0]}x{source_image.size[1]}"
            )
        if source_image.mode not in {"RGB", "RGBA"}:
            source_image = source_image.convert("RGB")
        chunks = {name: source_image.crop(box) for name, box in CHUNKS.items()}

    for name, chunk in chunks.items():
        if chunk.size != CHUNK_SIZE:
            raise ValueError(f"Chunk {name.upper()} has unexpected size {chunk.size}")
        output_path = args.output_dir / OUTPUT_NAMES[name]
        chunk.save(output_path, format="PNG", optimize=True)

    require_equal(
        chunks["a"].crop((CHUNK_SIZE[0] - OVERLAP, 0, CHUNK_SIZE[0], CHUNK_SIZE[1])),
        chunks["b"].crop((0, 0, OVERLAP, CHUNK_SIZE[1])),
        "A/B",
    )
    require_equal(
        chunks["a"].crop((0, CHUNK_SIZE[1] - OVERLAP, CHUNK_SIZE[0], CHUNK_SIZE[1])),
        chunks["c"].crop((0, 0, CHUNK_SIZE[0], OVERLAP)),
        "A/C",
    )
    require_equal(
        chunks["b"].crop((0, CHUNK_SIZE[1] - OVERLAP, CHUNK_SIZE[0], CHUNK_SIZE[1])),
        chunks["d"].crop((0, 0, CHUNK_SIZE[0], OVERLAP)),
        "B/D",
    )
    require_equal(
        chunks["c"].crop((CHUNK_SIZE[0] - OVERLAP, 0, CHUNK_SIZE[0], CHUNK_SIZE[1])),
        chunks["d"].crop((0, 0, OVERLAP, CHUNK_SIZE[1])),
        "C/D",
    )

    for name in "abcd":
        output_path = args.output_dir / OUTPUT_NAMES[name]
        with Image.open(output_path) as saved:
            if saved.size != CHUNK_SIZE or saved.mode not in {"RGB", "RGBA"}:
                raise ValueError(
                    f"Saved chunk {name.upper()} invalid: size={saved.size}, mode={saved.mode}"
                )
        print(
            f"{name.upper()} {output_path.name} "
            f"{CHUNK_SIZE[0]}x{CHUNK_SIZE[1]} SHA256={sha256(output_path)}"
        )
    print("All four 160-pixel overlap seams match exactly.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
