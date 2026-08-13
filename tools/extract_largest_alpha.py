from collections import deque
from pathlib import Path
import sys

from PIL import Image


source_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
image = Image.open(source_path).convert("RGBA")
alpha = image.getchannel("A")
width, height = image.size
solid = bytearray(1 if value > 24 else 0 for value in alpha.getdata())
visited = bytearray(width * height)
largest: list[int] = []

for start in range(width * height):
    if not solid[start] or visited[start]:
        continue
    visited[start] = 1
    queue = deque([start])
    component: list[int] = []
    while queue:
        index = queue.popleft()
        component.append(index)
        x, y = index % width, index // width
        for ny in range(max(0, y - 1), min(height, y + 2)):
            for nx in range(max(0, x - 1), min(width, x + 2)):
                neighbor = ny * width + nx
                if solid[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    queue.append(neighbor)
    if len(component) > len(largest):
        largest = component

mask = Image.new("L", image.size, 0)
mask_pixels = mask.load()
xs: list[int] = []
ys: list[int] = []
for index in largest:
    x, y = index % width, index // width
    mask_pixels[x, y] = alpha.getpixel((x, y))
    xs.append(x)
    ys.append(y)

isolated = Image.new("RGBA", image.size, (0, 0, 0, 0))
isolated.paste(image, mask=mask)
bounds = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
cropped = isolated.crop(bounds)
canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
scale = min(224 / cropped.width, 224 / cropped.height)
size = (round(cropped.width * scale), round(cropped.height * scale))
cropped = cropped.resize(size, Image.Resampling.NEAREST)
canvas.alpha_composite(cropped, ((256 - size[0]) // 2, (256 - size[1]) // 2))
canvas.save(output_path)
