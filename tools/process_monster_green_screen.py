"""Convert generated green-screen monster masters into centered RGBA sprites.

The output contract is a 512x512 transparent PNG whose gameplay pivot is the
bottom-center point (256, 480). Re-running this script is enough to replace the
source art without touching Godot drawing code.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


SLIME_SOURCES = {
    "anemo_slime.png": "anemo_slime_sprite_master.png",
    "electro_slime.png": "electro_slime_sprite_master_jittery.png",
    "hydro_slime.png": "hydro_slime_sprite_master_surprised.png",
    "pyro_slime.png": "pyro_slime_sprite_master_grinning.png",
    "slime_king.png": "slime_king_boss_sprite_master.png",
}

CANVAS_SIZE = 512
PIVOT = (256, 480)
MAX_DRAW_SIZE = 440


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    value = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return value * value * (3.0 - 2.0 * value)


def remove_green_screen(source: Path) -> Image.Image:
    rgba = np.asarray(Image.open(source).convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    red, green, blue = (rgb[:, :, channel] for channel in range(3))

    # The generated backdrop is a bright, strongly dominant green. Measuring
    # dominance instead of hue preserves cyan Anemo details and yellow edges.
    dominance = green - np.maximum(red, blue)
    key_strength = smoothstep(18.0, 78.0, dominance) * smoothstep(92.0, 205.0, green)
    alpha = np.clip((1.0 - key_strength) * 255.0, 0.0, 255.0)
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.75)
    alpha[alpha < 7.0] = 0.0
    alpha[alpha > 248.0] = 255.0

    # Suppress green spill only where the key is active, leaving opaque art
    # untouched. This avoids a neon fringe after bilinear texture filtering.
    spill = key_strength[:, :, None]
    neutral_green = np.maximum(red, blue) + 8.0
    rgb[:, :, 1] = green * (1.0 - spill[:, :, 0]) + np.minimum(green, neutral_green) * spill[:, :, 0]

    result = np.dstack((np.clip(rgb, 0, 255), alpha)).astype(np.uint8)
    return Image.fromarray(result)


def center_on_contract(sprite: Image.Image) -> Image.Image:
    alpha = np.asarray(sprite.getchannel("A"))
    ys, xs = np.where(alpha > 12)
    if len(xs) == 0:
        raise ValueError("foreground mask is empty")
    crop = sprite.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    scale = min(MAX_DRAW_SIZE / crop.width, MAX_DRAW_SIZE / crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    crop = crop.resize(size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    position = (PIVOT[0] - crop.width // 2, PIVOT[1] - crop.height)
    canvas.alpha_composite(crop, position)
    return canvas


def process(source_root: Path, output_root: Path) -> None:
    output_root.mkdir(parents=True, exist_ok=True)
    for output_name, source_name in SLIME_SOURCES.items():
        source = source_root / source_name
        if not source.exists():
            raise FileNotFoundError(source)
        result = center_on_contract(remove_green_screen(source))
        result.save(output_root / output_name, optimize=True)
        print(f"wrote {output_root / output_name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_root", type=Path)
    parser.add_argument("output_root", type=Path)
    args = parser.parse_args()
    process(args.source_root, args.output_root)


if __name__ == "__main__":
    main()
