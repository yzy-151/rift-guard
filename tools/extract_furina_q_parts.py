from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from extract_furina_parts import components, edge_connected_background


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "research" / "furina-q-source" / "furina-q-parts-source.png"
OUTPUT = ROOT / "game" / "assets" / "characters" / "furina_q_rig"


def contact_sheet(items: list[dict[str, int]]) -> None:
    columns = 5
    cell_width, cell_height = 260, 250
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell_width, rows * cell_height), (27, 24, 34, 255))
    draw = ImageDraw.Draw(sheet)
    font_path = ROOT / "game" / "assets" / "fonts" / "TiejiliSC-Regular.ttf"
    font = ImageFont.truetype(font_path, 20) if font_path.exists() else ImageFont.load_default()
    for index, item in enumerate(items):
        left = index % columns * cell_width
        top = index // columns * cell_height
        for y in range(top + 32, top + cell_height, 20):
            for x in range(left, left + cell_width, 20):
                shade = 59 if ((x - left) // 20 + (y - top - 32) // 20) % 2 == 0 else 76
                draw.rectangle((x, y, min(x + 19, left + cell_width - 1), min(y + 19, top + cell_height - 1)), fill=(shade, shade, shade, 255))
        image = Image.open(OUTPUT / item["file"]).convert("RGBA")
        image.thumbnail((cell_width - 20, cell_height - 50), Image.Resampling.LANCZOS)
        sheet.alpha_composite(image, (left + (cell_width - image.width) // 2, top + 38 + (cell_height - 48 - image.height) // 2))
        draw.rectangle((left, top, left + cell_width - 1, top + cell_height - 1), outline=(132, 101, 123, 255), width=2)
        label = "q-part-%02d  %dx%d" % (index, item["width"], item["height"])
        draw.text((left + 8, top + 5), label, font=font, fill=(230, 207, 219, 255))
    sheet.convert("RGB").save(OUTPUT / "furina-q-parts-contact-sheet.jpg", quality=92, optimize=True)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rgb = np.asarray(Image.open(SOURCE).convert("RGB"))
    background = edge_connected_background(rgb, minimum_value=238, spread_limit=18)
    alpha = np.where(background, 0, 255).astype(np.uint8)
    rgba = np.dstack((rgb, alpha))
    Image.fromarray(rgba, "RGBA").save(OUTPUT / "furina-q-board-alpha.png", optimize=True)
    items = components(alpha > 0, minimum_area=180)
    padding = 8
    for index, item in enumerate(items):
        x0 = max(0, item["x"] - padding)
        y0 = max(0, item["y"] - padding)
        x1 = min(rgba.shape[1], item["x"] + item["width"] + padding)
        y1 = min(rgba.shape[0], item["y"] + item["height"] + padding)
        filename = "q-part-%02d.png" % index
        Image.fromarray(rgba[y0:y1, x0:x1], "RGBA").save(OUTPUT / filename, optimize=True)
        item.update({"file": filename, "crop_x": x0, "crop_y": y0, "crop_width": x1 - x0, "crop_height": y1 - y0})
    manifest = {
        "source": str(SOURCE),
        "canvas": {"width": int(rgba.shape[1]), "height": int(rgba.shape[0])},
        "background_method": "edge-connected near-white pixels",
        "parts": items,
    }
    (OUTPUT / "parts.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    contact_sheet(items)
    print(json.dumps({"output": str(OUTPUT), "parts": len(items), "largest": items[:12]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
