from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


PADDING = 16

# Both user sheets are 2048x2048. Only the lowest perspective row is sampled;
# rows 1 and 3 contain forbidden top-down deck views.
# The two middle hulls share the single medium north/south end-view pair.
CROPS: dict[tuple[str, str], tuple[int, tuple[int, int, int, int]]] = {
    ("transport", "e"): (0, (0, 1650, 350, 2048)),
    ("transport", "s"): (0, (340, 1650, 500, 2048)),
    ("transport", "w"): (1, (1720, 1650, 2048, 2048)),
    ("transport", "n"): (1, (1580, 1650, 1720, 2048)),
    ("frigate", "e"): (0, (500, 1650, 870, 2048)),
    ("frigate", "s"): (0, (870, 1650, 1000, 2048)),
    ("frigate", "w"): (1, (1200, 1650, 1540, 2048)),
    ("frigate", "n"): (1, (1060, 1650, 1210, 2048)),
    ("merchant", "e"): (0, (1000, 1650, 1530, 2048)),
    ("merchant", "s"): (0, (870, 1650, 1000, 2048)),
    ("merchant", "w"): (1, (540, 1650, 1030, 2048)),
    ("merchant", "n"): (1, (1060, 1650, 1210, 2048)),
    ("flagship", "e"): (0, (1530, 1650, 1895, 2048)),
    ("flagship", "s"): (0, (1895, 1650, 2048, 2048)),
    ("flagship", "w"): (1, (180, 1650, 530, 2048)),
    ("flagship", "n"): (1, (0, 1650, 185, 2048)),
}


def keep_largest_alpha_component(image: Image.Image) -> Image.Image:
    width, height = image.size
    alpha = bytearray(image.getchannel("A").tobytes())
    active = bytearray(1 if value > 0 else 0 for value in alpha)
    largest: list[int] = []

    for start in range(width * height):
        if not active[start]:
            continue
        active[start] = 0
        queue = deque([start])
        component: list[int] = []
        while queue:
            index = queue.popleft()
            component.append(index)
            x = index % width
            y = index // width
            for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                row = neighbor_y * width
                for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = row + neighbor_x
                    if active[neighbor]:
                        active[neighbor] = 0
                        queue.append(neighbor)
        if len(component) > len(largest):
            largest = component

    isolated_alpha = bytearray(width * height)
    for index in largest:
        isolated_alpha[index] = alpha[index]
    isolated = image.copy()
    isolated.putalpha(Image.frombytes("L", image.size, bytes(isolated_alpha)))
    return isolated


def extract(source: Image.Image, crop_box: tuple[int, int, int, int]) -> Image.Image:
    region = source.crop(crop_box)
    region = keep_largest_alpha_component(region)
    used = region.getchannel("A").getbbox()
    if used is None:
        raise ValueError(f"crop {crop_box} contains no visible pixels")
    sprite = region.crop(used)
    output = Image.new("RGBA", (sprite.width + PADDING * 2, sprite.height + PADDING * 2))
    output.alpha_composite(sprite, (PADDING, PADDING))
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract four player hulls from complementary four-view sheets.")
    parser.add_argument("source_east_south", type=Path)
    parser.add_argument("source_west_north", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    sources = [
        Image.open(args.source_east_south).convert("RGBA"),
        Image.open(args.source_west_north).convert("RGBA"),
    ]
    try:
        for source in sources:
            if source.size != (2048, 2048):
                raise ValueError(f"expected 2048x2048 source sheet, got {source.size}")

        args.output_dir.mkdir(parents=True, exist_ok=True)
        for (ship_type, direction), (source_index, crop_box) in CROPS.items():
            output = extract(sources[source_index], crop_box)
            horizontal = direction in {"e", "w"}
            if (output.width > output.height) != horizontal:
                raise ValueError(f"{ship_type}_{direction} has an unexpected aspect ratio: {output.size}")
            output_path = args.output_dir / f"player_{ship_type}_{direction}.png"
            output.save(output_path)
            print(f"{output_path.name}: {output.width}x{output.height}")
    finally:
        for source in sources:
            source.close()


if __name__ == "__main__":
    main()
