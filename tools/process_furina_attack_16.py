from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/characters/furina_ai_frames/attack_16"
SOURCE = OUT / "furina-attack-16-green-source.png"
CELL = 512
TARGET_CHARACTER_HEIGHT = 420
BASELINE = 480


def remove_green(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    delta = green - np.maximum(red, blue)
    key = np.clip((delta - 20.0) / 60.0, 0.0, 1.0)
    key *= np.clip((green - 65.0) / 85.0, 0.0, 1.0)
    alpha = ((1.0 - key) * 255.0).astype(np.uint8)
    spill = key > 0.01
    rgb[..., 1][spill] = np.minimum(rgb[..., 1][spill], np.maximum(red, blue)[spill] + 6.0)
    return Image.fromarray(np.dstack((np.clip(rgb, 0, 255).astype(np.uint8), alpha)))


def character_bbox(frame: Image.Image):
    rgba = np.asarray(frame)
    alpha = rgba[..., 3] > 28
    red, green, blue = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    water = (blue > 175) & (green > 100) & (blue > red * 1.35) & (green > red * 1.2)
    ys, xs = np.where(alpha & ~water)
    if not len(xs):
        raise RuntimeError("No character silhouette found")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def normalize(raw: Image.Image) -> Image.Image:
    frame = remove_green(raw)
    bbox = character_bbox(frame)
    scale = TARGET_CHARACTER_HEIGHT / max(1, bbox[3] - bbox[1])
    scaled = frame.resize(
        (max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
        Image.Resampling.LANCZOS,
    )
    bbox = character_bbox(scaled)
    x = CELL // 2 - (bbox[0] + bbox[2]) // 2
    y = BASELINE - bbox[3]
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (x, y))
    return canvas


def detect_row_bounds(sheet: Image.Image):
    rgb = np.asarray(sheet.convert("RGB"), dtype=np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    foreground = ~((green - np.maximum(red, blue) > 35.0) & (green > 100.0))
    occupied = foreground.sum(axis=1) > 8
    bands = []
    start = None
    for y, value in enumerate(occupied):
        if value and start is None:
            start = y
        if start is not None and (not value or y == len(occupied) - 1):
            end = y if value else y - 1
            if end - start > 60:
                bands.append((start, end))
            start = None
    if len(bands) != 4:
        raise RuntimeError(f"Expected four figure rows, found {bands}")
    cuts = [0]
    for current, following in zip(bands, bands[1:]):
        cuts.append((current[1] + following[0]) // 2)
    cuts.append(sheet.height)
    return list(zip(cuts, cuts[1:]))


def main():
    source = Image.open(SOURCE).convert("RGB")
    width, height = source.size
    row_bounds = detect_row_bounds(source)
    frames = []
    for index in range(16):
        col, row = index % 4, index // 4
        left, right = round(col * width / 4), round((col + 1) * width / 4)
        top, bottom = row_bounds[row]
        frames.append(normalize(source.crop((left, top, right, bottom))))

    atlas = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    contact = Image.new("RGB", (256 * 4, 256 * 4), (28, 34, 53))
    draw = ImageDraw.Draw(contact)
    previews = []
    for index, frame in enumerate(frames):
        frame.save(OUT / f"attack-{index:02d}.png", optimize=True)
        atlas.alpha_composite(frame, ((index % 4) * CELL, (index // 4) * CELL))
        board = Image.new("RGBA", (CELL, CELL), (28, 34, 53, 255))
        board.alpha_composite(frame)
        preview = board.convert("RGB").resize((256, 256), Image.Resampling.LANCZOS)
        previews.append(preview)
        contact.paste(preview, ((index % 4) * 256, (index // 4) * 256))
        draw.text(((index % 4) * 256 + 6, (index // 4) * 256 + 6), str(index), fill="white")

    atlas.save(OUT / "furina-attack-16-atlas.png", optimize=True)
    contact.save(OUT / "furina-attack-16-contact-sheet.jpg", quality=90)
    previews[0].save(
        OUT / "furina-attack-16-preview.gif",
        save_all=True,
        append_images=previews[1:],
        duration=125,
        loop=0,
        disposal=2,
        optimize=True,
    )
    print(f"frames={len(frames)} fps=8 duration={len(frames) / 8:.2f}s atlas={atlas.size}")


if __name__ == "__main__":
    main()
