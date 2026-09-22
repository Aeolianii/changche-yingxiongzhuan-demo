"""Extract the unused white-sail merchant from the user's enemy ship sheets."""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from extract_player_ship_directional_assets import extract


# Third row only; never sample the center top-down deck column.
# Sheet 1 faces west; sheet 2 faces east. End views follow the same
# north/south convention as the transport and flagship in these sheets.
CROPS = {
    "w": (0, (200, 935, 920, 1395)),
    "n": (0, (1750, 935, 1995, 1395)),
    "e": (1, (1200, 935, 1920, 1395)),
    "s": (1, (135, 935, 350, 1395)),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_west_north", type=Path)
    parser.add_argument("source_east_south", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    with Image.open(args.source_west_north) as first, Image.open(args.source_east_south) as second:
        if first.size != (2048, 2048) or second.size != (2048, 2048):
            raise ValueError("Expected two 2048x2048 source sheets")
        sources = [first.convert("RGBA"), second.convert("RGBA")]
        args.output_dir.mkdir(parents=True, exist_ok=True)
        for direction, (source_index, crop_box) in CROPS.items():
            output = extract(sources[source_index], crop_box)
            if (output.width > output.height) != (direction in {"e", "w"}):
                raise ValueError(f"Unexpected {direction} aspect ratio: {output.size}")
            path = args.output_dir / f"enemy_merchant_{direction}.png"
            output.save(path)
            print(f"{path.name}: {output.width}x{output.height}")


if __name__ == "__main__":
    main()
