from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "research" / "furina-source" / "furina-parts-board-source.png"
OUTPUT = ROOT / "game" / "assets" / "characters" / "furina"
CHIBI_SOURCE = OUTPUT / "furina-chibi-v1.png"


def edge_connected_background(rgb: np.ndarray, minimum_value: int = 238, spread_limit: int = 18) -> np.ndarray:
    """Return near-white pixels connected to the canvas edge.

    Internal white clothing stays opaque because dark outlines isolate it from the
    edge-connected background.
    """
    minimum = rgb.min(axis=2)
    spread = rgb.max(axis=2) - minimum
    candidate = (minimum >= minimum_value) & (spread <= spread_limit)
    height, width = candidate.shape
    seen = np.zeros_like(candidate, dtype=np.bool_)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        if candidate[0, x]:
            queue.append((0, x))
        if candidate[height - 1, x]:
            queue.append((height - 1, x))
    for y in range(height):
        if candidate[y, 0]:
            queue.append((y, 0))
        if candidate[y, width - 1]:
            queue.append((y, width - 1))

    while queue:
        y, x = queue.popleft()
        if seen[y, x] or not candidate[y, x]:
            continue
        seen[y, x] = True
        if y:
            queue.append((y - 1, x))
        if y + 1 < height:
            queue.append((y + 1, x))
        if x:
            queue.append((y, x - 1))
        if x + 1 < width:
            queue.append((y, x + 1))
    return seen


def components(mask: np.ndarray, minimum_area: int = 220) -> list[dict[str, int]]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=np.bool_)
    found: list[dict[str, int]] = []
    for y in range(height):
        for x in range(width):
            if seen[y, x] or not mask[y, x]:
                continue
            queue = [(y, x)]
            seen[y, x] = True
            area = 0
            x0 = x1 = x
            y0 = y1 = y
            while queue:
                cy, cx = queue.pop()
                area += 1
                x0, x1 = min(x0, cx), max(x1, cx)
                y0, y1 = min(y0, cy), max(y1, cy)
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            if area >= minimum_area:
                found.append({"area": area, "x": x0, "y": y0, "width": x1 - x0 + 1, "height": y1 - y0 + 1})
    return sorted(found, key=lambda item: item["area"], reverse=True)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rgb = np.asarray(Image.open(SOURCE).convert("RGB"))
    background = edge_connected_background(rgb)
    alpha = np.where(background, 0, 255).astype(np.uint8)
    rgba = np.dstack((rgb, alpha))
    Image.fromarray(rgba, "RGBA").save(OUTPUT / "furina-parts-board-alpha.png", optimize=True)

    opaque = alpha > 0
    items = components(opaque)
    padding = 8
    for index, item in enumerate(items):
        x0 = max(0, item["x"] - padding)
        y0 = max(0, item["y"] - padding)
        x1 = min(rgba.shape[1], item["x"] + item["width"] + padding)
        y1 = min(rgba.shape[0], item["y"] + item["height"] + padding)
        filename = f"part-{index:02d}.png"
        Image.fromarray(rgba[y0:y1, x0:x1], "RGBA").save(OUTPUT / filename, optimize=True)
        item.update({"file": filename, "crop_x": x0, "crop_y": y0, "crop_width": x1 - x0, "crop_height": y1 - y0})

    manifest = {
        "source": str(SOURCE),
        "canvas": {"width": int(rgba.shape[1]), "height": int(rgba.shape[0])},
        "background_method": "edge-connected near-white pixels; threshold min>=238 and spread<=18",
        "parts": items,
    }
    (OUTPUT / "parts.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    build_contact_sheet(items)
    chibi = prepare_chibi() if CHIBI_SOURCE.exists() else None
    print(json.dumps({"output": str(OUTPUT), "parts": len(items), "largest": items[:8], "chibi": chibi}, ensure_ascii=False, indent=2))


def prepare_chibi() -> dict[str, object]:
    rgb = np.asarray(Image.open(CHIBI_SOURCE).convert("RGB"))
    background = edge_connected_background(rgb, minimum_value=220, spread_limit=12)
    alpha = np.where(background, 0, 255).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    padding = 24
    x0, x1 = max(0, int(xs.min()) - padding), min(rgb.shape[1], int(xs.max()) + padding + 1)
    y0, y1 = max(0, int(ys.min()) - padding), min(rgb.shape[0], int(ys.max()) + padding + 1)
    rgba = np.dstack((rgb, alpha))[y0:y1, x0:x1]
    target = OUTPUT / "furina-chibi-v1-alpha.png"
    Image.fromarray(rgba, "RGBA").save(target, optimize=True)
    return {
        "file": target.name,
        "width": int(rgba.shape[1]),
        "height": int(rgba.shape[0]),
        "transparent_ratio": round(float(np.mean(rgba[:, :, 3] == 0)), 4),
    }


def build_contact_sheet(items: list[dict[str, int]]) -> None:
    columns = 5
    cell_width, cell_height = 260, 260
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell_width, rows * cell_height), (27, 24, 34, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = ROOT / "game" / "assets" / "fonts" / "TiejiliSC-Regular.ttf"
    font = ImageFont.truetype(font_path, 22) if font_path.exists() else ImageFont.load_default()
    for index, item in enumerate(items):
        left = (index % columns) * cell_width
        top = (index // columns) * cell_height
        for cy in range(top + 34, top + cell_height, 20):
            for cx in range(left, left + cell_width, 20):
                shade = 64 if ((cx - left) // 20 + (cy - top - 34) // 20) % 2 == 0 else 82
                draw.rectangle((cx, cy, min(cx + 19, left + cell_width - 1), min(cy + 19, top + cell_height - 1)), fill=(shade, shade, shade, 255))
        image = Image.open(OUTPUT / item["file"]).convert("RGBA")
        image.thumbnail((cell_width - 24, cell_height - 58), Image.Resampling.LANCZOS)
        x = left + (cell_width - image.width) // 2
        y = top + 40 + (cell_height - 52 - image.height) // 2
        sheet.alpha_composite(image, (x, y))
        draw.rectangle((left, top, left + cell_width - 1, top + cell_height - 1), outline=(132, 101, 123, 255), width=2)
        label = "part-%02d  %dx%d  area %d" % (index, item["width"], item["height"], item["area"])
        draw.text((left + 8, top + 6), label, font=font, fill=(230, 207, 219, 255))
    sheet.convert("RGB").save(OUTPUT / "furina-parts-contact-sheet.jpg", quality=92, optimize=True)


if __name__ == "__main__":
    main()
