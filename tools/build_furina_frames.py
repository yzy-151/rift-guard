from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game" / "assets" / "characters" / "furina_q_rig" / "q-part-00.png"
OUTPUT = ROOT / "game" / "assets" / "characters" / "furina_frames"
FRAME = 256
GROUND_Y = 228
ANIMATIONS = {
    "idle": {"frames": 8, "fps": 6.0, "loop": True},
    "move": {"frames": 8, "fps": 12.0, "loop": True},
    "attack": {"frames": 8, "fps": 16.0, "loop": False},
    "hurt": {"frames": 4, "fps": 14.0, "loop": False},
    "down": {"frames": 8, "fps": 12.0, "loop": False},
}


def pose(name: str, frame: int, count: int) -> tuple[float, float, float, float, float]:
    phase = frame * math.tau / count
    if name == "idle":
        return 0.0, 1.0 - math.sin(phase) * 0.008, 1.0 + math.sin(phase) * 0.012, 0.0, -abs(math.sin(phase)) * 1.5
    if name == "move":
        stride = math.sin(phase)
        return stride * 2.5, 1.0 + abs(stride) * 0.025, 1.0 - abs(stride) * 0.035, stride * 2.0, -abs(math.cos(phase)) * 5.0
    if name == "attack":
        angles = [0.0, 1.5, -2.0, -5.5, -6.0, -3.0, 1.0, 0.0]
        shifts = [0.0, -2.0, 2.0, 8.0, 11.0, 7.0, 2.0, 0.0]
        squash = [0.0, -0.02, 0.02, 0.05, 0.06, 0.03, -0.01, 0.0]
        return angles[frame], 1.0 + squash[frame], 1.0 - squash[frame] * 0.5, shifts[frame], -abs(shifts[frame]) * 0.18
    if name == "hurt":
        angles = [-2.0, 2.0, -1.0, 0.0]
        shifts = [-3.0, 3.0, -1.0, 0.0]
        return angles[frame], 1.0, 1.0, shifts[frame], 0.0
    angles = [0.0, 10.0, 24.0, 42.0, 61.0, 76.0, 86.0, 90.0]
    shifts = [0.0, 2.0, 5.0, 9.0, 15.0, 22.0, 28.0, 31.0]
    return angles[frame], 1.0, 1.0, shifts[frame], 0.0


def make_frame(source: Image.Image, spec: tuple[float, float, float, float, float]) -> Image.Image:
    angle, scale_x, scale_y, offset_x, offset_y = spec
    height = max(1, round(190 * scale_y))
    width = max(1, round(height * source.width / source.height * scale_x / scale_y))
    image = source.resize((width, height), Image.Resampling.LANCZOS)
    image = image.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = round((FRAME - image.width) / 2 + offset_x)
    y = round(GROUND_Y - image.height + offset_y)
    canvas.alpha_composite(image, (x, y))
    return canvas


def connected_components(mask: np.ndarray) -> list[int]:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=np.bool_)
    areas: list[int] = []
    for y in range(height):
        for x in range(width):
            if seen[y, x] or not mask[y, x]:
                continue
            stack = [(y, x)]
            seen[y, x] = True
            area = 0
            while stack:
                cy, cx = stack.pop()
                area += 1
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            areas.append(area)
    return sorted(areas, reverse=True)


def validate(frames: dict[str, list[Image.Image]]) -> dict[str, object]:
    issues: list[str] = []
    minimum_iou: dict[str, float] = {}
    for name, images in frames.items():
        previous = None
        animation_iou = 1.0
        for index, image in enumerate(images):
            alpha = np.asarray(image.getchannel("A")) > 8
            areas = connected_components(alpha)
            coverage = areas[0] / max(1, sum(areas))
            if coverage < 0.97:
                issues.append(f"{name}[{index}] detached coverage {coverage:.4f}")
            if previous is not None:
                union = np.logical_or(previous, alpha).sum()
                iou = np.logical_and(previous, alpha).sum() / max(1, union)
                animation_iou = min(animation_iou, float(iou))
            previous = alpha
        minimum_iou[name] = round(animation_iou, 4)
        threshold = 0.48 if name == "down" else 0.72
        if animation_iou < threshold:
            issues.append(f"{name} minimum consecutive silhouette IoU {animation_iou:.4f}")
    return {"passed": not issues, "minimum_iou": minimum_iou, "issues": issues}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    frames: dict[str, list[Image.Image]] = {}
    for name, config in ANIMATIONS.items():
        count = int(config["frames"])
        frames[name] = [make_frame(source, pose(name, index, count)) for index in range(count)]
    sheet = Image.new("RGBA", (FRAME * 8, FRAME * len(ANIMATIONS)), (0, 0, 0, 0))
    for row, (name, images) in enumerate(frames.items()):
        for column, image in enumerate(images):
            sheet.alpha_composite(image, (column * FRAME, row * FRAME))
    sheet.save(OUTPUT / "furina-motion-sheet.png", optimize=True)

    preview = Image.new("RGB", sheet.size, (42, 38, 49))
    draw = ImageDraw.Draw(preview)
    font_path = ROOT / "game" / "assets" / "fonts" / "TiejiliSC-Regular.ttf"
    font = ImageFont.truetype(font_path, 24) if font_path.exists() else ImageFont.load_default()
    for row, name in enumerate(ANIMATIONS):
        draw.text((8, row * FRAME + 8), name, font=font, fill=(238, 214, 225))
    preview.paste(sheet, mask=sheet.getchannel("A"))
    preview.save(OUTPUT / "furina-motion-preview.jpg", quality=92, optimize=True)

    result = validate(frames)
    manifest = {"frame_width": FRAME, "frame_height": FRAME, "ground_y": GROUND_Y, "animations": ANIMATIONS, "validation": result}
    (OUTPUT / "frames.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    if not result["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
