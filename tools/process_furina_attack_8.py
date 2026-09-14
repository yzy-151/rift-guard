from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game/assets/characters/furina_ai_frames/furina-attack-8-green-source.png"
OUT = ROOT / "game/assets/characters/furina_ai_frames/attack_8"
CELL = 512
TARGET_CHARACTER_HEIGHT = 420
BASELINE = 480


def remove_green(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green_delta = green - np.maximum(red, blue)
    key = np.clip((green_delta - 22.0) / 58.0, 0.0, 1.0)
    key *= np.clip((green - 70.0) / 80.0, 0.0, 1.0)
    alpha = ((1.0 - key) * 255.0).astype(np.uint8)

    # Remove green spill only near the keyed boundary.
    spill = key > 0.02
    rgb[..., 1][spill] = np.minimum(rgb[..., 1][spill], np.maximum(red, blue)[spill] + 8.0)
    rgba = np.dstack((np.clip(rgb, 0, 255).astype(np.uint8), alpha))
    return Image.fromarray(rgba, "RGBA")


def character_bbox(frame: Image.Image):
    rgba = np.asarray(frame)
    alpha = rgba[..., 3] > 24
    red, green, blue = rgba[..., 0], rgba[..., 1], rgba[..., 2]
    water = (blue > 180) & (green > 105) & (blue > red * 1.35) & (green > red * 1.25)
    mask = alpha & ~water
    ys, xs = np.where(mask)
    if not len(xs):
        raise RuntimeError("No character silhouette found")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def normalize(frame: Image.Image) -> Image.Image:
    bbox = character_bbox(frame)
    height = bbox[3] - bbox[1]
    scale = TARGET_CHARACTER_HEIGHT / max(height, 1)
    scaled = frame.resize(
        (max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
        Image.Resampling.LANCZOS,
    )
    scaled_bbox = character_bbox(scaled)
    character_center = (scaled_bbox[0] + scaled_bbox[2]) // 2
    x = CELL // 2 - character_center
    y = BASELINE - scaled_bbox[3]
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (x, y))
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGB")
    if source.size != (1536, 1024):
        raise RuntimeError(f"Unexpected source size: {source.size}")

    frames = []
    for index in range(8):
        column = index % 4
        row = index // 4
        raw = source.crop((column * 384, row * 512, (column + 1) * 384, (row + 1) * 512))
        frame = normalize(remove_green(raw))
        frame.save(OUT / f"attack-{index:02d}.png", optimize=True)
        frames.append(frame)

    atlas = Image.new("RGBA", (CELL * 8, CELL), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, (index * CELL, 0))
    atlas.save(OUT / "furina-attack-8-atlas.png", optimize=True)

    preview = []
    for frame in frames:
        board = Image.new("RGBA", frame.size, (28, 34, 53, 255))
        board.alpha_composite(frame)
        preview.append(board.convert("RGB"))
    preview[0].save(
        OUT / "furina-attack-8-preview.gif",
        save_all=True,
        append_images=preview[1:],
        duration=85,
        loop=0,
        disposal=2,
    )
    print(OUT)


if __name__ == "__main__":
    main()
