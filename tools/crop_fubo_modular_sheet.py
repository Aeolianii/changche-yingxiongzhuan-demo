from pathlib import Path
from collections import deque

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/fubo_guling/generated/modular_sheet_source.png"
OUTPUT = ROOT / "assets/fubo_guling/generated/modular_raw"
NAMES = [
    "guard_house",
    "grain_store",
    "banyan_tree",
    "lychee_tree",
    "coastal_tree",
    "canal_marker",
    "drum",
    "flag_yellow",
    "flag_red",
    "flag_blue",
]


def is_subject(pixel: tuple[int, ...]) -> bool:
    red, green, blue = pixel[:3]
    return not (red > 220 and blue > 190 and green < 75)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE).convert("RGB")
    pixels = list(sheet.getdata())
    mask = bytearray(1 if is_subject(pixel) else 0 for pixel in pixels)
    seen = bytearray(len(mask))
    components: list[tuple[int, int, int, int, int]] = []
    width, height = sheet.size
    for start, active in enumerate(mask):
        if not active or seen[start]:
            continue
        queue = deque([start])
        seen[start] = 1
        count = 0
        min_x = max_x = start % width
        min_y = max_y = start // width
        while queue:
            current = queue.popleft()
            x = current % width
            y = current // width
            count += 1
            min_x, max_x = min(min_x, x), max(max_x, x)
            min_y, max_y = min(min_y, y), max(max_y, y)
            for neighbor in (current - 1, current + 1, current - width, current + width):
                if neighbor < 0 or neighbor >= len(mask) or seen[neighbor] or not mask[neighbor]:
                    continue
                neighbor_x = neighbor % width
                if abs(neighbor_x - x) > 1:
                    continue
                seen[neighbor] = 1
                queue.append(neighbor)
        if count > 1200:
            components.append((min_x, min_y, max_x + 1, max_y + 1, count))
    components.sort(key=lambda item: (0 if (item[1] + item[3]) / 2 < height / 2 else 1, (item[0] + item[2]) / 2))
    if len(components) != len(NAMES):
        raise RuntimeError(f"Expected 10 modular subjects, found {len(components)}: {components}")
    for name, bounds in zip(NAMES, components):
        left, top, right, bottom, _count = bounds
        padding = 8
        crop_box = (
            max(0, left - padding),
            max(0, top - padding),
            min(sheet.width, right + padding),
            min(sheet.height, bottom + padding),
        )
        sheet.crop(crop_box).save(OUTPUT / f"{name}_key.png")
        print(f"{name}: {crop_box}")


if __name__ == "__main__":
    main()
