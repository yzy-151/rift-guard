#!/usr/bin/env python3
"""Build stable, transparent V18 animation atlases from local green-screen media."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TRAVELER = Path(r"C:\Users\23081\Desktop\游戏素材\荧")
DEFAULT_MONSTER = Path(r"C:\Users\23081\Desktop\游戏素材\生成帧")
TRAVELER_OUT = ROOT / "game" / "assets" / "characters" / "traveler_v18"
MONSTER_OUT = ROOT / "game" / "assets" / "enemies" / "hilichurl_v18"
REVIEW_OUT = ROOT / "review" / "v18-assets"

CLIPS = {
    "idle": {"source": "idle.mov", "frames": 48, "fps": 24.0, "loop": True, "release": -1},
    "run": {"source": "run.mov", "frames": 48, "fps": 24.0, "loop": True, "release": -1},
    "attack": {"source": "attack.mov", "frames": 48, "fps": 48.0, "loop": False, "release": 18},
    "death": {"source": "death.mov", "frames": 48, "fps": 30.0, "loop": False, "release": -1},
}


def decode_video(path: Path) -> list[np.ndarray]:
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {path}")
    frames: list[np.ndarray] = []
    while True:
        ok, bgr = cap.read()
        if not ok:
            break
        frames.append(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGBA))
    cap.release()
    if not frames:
        raise RuntimeError(f"No frames decoded: {path}")
    return frames


def connected_chroma_key(rgba: np.ndarray) -> np.ndarray:
    """Remove green connected to the image border and retain internal green detail."""
    rgb = rgba[:, :, :3].astype(np.float32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    green_candidate = (g > 72.0) & (g > r * 1.20 + 12.0) & (g > b * 1.18 + 10.0)

    count, labels = cv2.connectedComponents(green_candidate.astype(np.uint8), connectivity=8)
    edge_labels = np.unique(
        np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1]))
    )
    background = np.isin(labels, edge_labels[edge_labels != 0]) if count > 1 else green_candidate

    foreground = (~background).astype(np.uint8) * 255
    # A short feather keeps hair and fabric edges clean after downscaling.
    foreground = cv2.GaussianBlur(foreground, (0, 0), 1.15)
    alpha = np.minimum(rgba[:, :, 3], foreground).astype(np.uint8)

    # Despill only translucent edge pixels; opaque green costume details remain intact.
    edge = (alpha > 0) & (alpha < 245)
    max_rb = np.maximum(r, b)
    corrected_g = np.minimum(g, max_rb * 1.08 + 8.0)
    rgb[:, :, 1][edge] = corrected_g[edge]

    out = np.dstack((np.clip(rgb, 0, 255).astype(np.uint8), alpha))
    return out


def alpha_bbox(frame: np.ndarray, threshold: int = 20) -> tuple[int, int, int, int]:
    ys, xs = np.where(frame[:, :, 3] > threshold)
    if xs.size == 0:
        return 0, 0, frame.shape[1], frame.shape[0]
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def sample_evenly(frames: list[np.ndarray], count: int) -> list[np.ndarray]:
    # Avoid duplicated generated-video bookend frames while preserving the complete motion.
    trim = max(1, round(len(frames) * 0.025))
    start, stop = trim, max(trim + 1, len(frames) - trim - 1)
    indices = np.linspace(start, stop, count, endpoint=True).round().astype(int)
    return [frames[min(len(frames) - 1, i)] for i in indices]


def stabilize_frames(
    frames: list[np.ndarray], cell: int, target_height: int, bottom: int
) -> list[Image.Image]:
    keyed = [connected_chroma_key(frame) for frame in frames]
    bboxes = [alpha_bbox(frame) for frame in keyed]
    heights = np.array([max(1, y1 - y0) for _, y0, _, y1 in bboxes], dtype=np.float32)
    reference_height = float(np.median(heights))
    scale = target_height / max(1.0, reference_height)

    result: list[Image.Image] = []
    for frame, (x0, y0, x1, y1) in zip(keyed, bboxes):
        crop = frame[y0:y1, x0:x1]
        new_w = max(1, round(crop.shape[1] * scale))
        new_h = max(1, round(crop.shape[0] * scale))
        resized = cv2.resize(crop, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)

        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        actor = Image.fromarray(resized)
        x = (cell - new_w) // 2
        y = bottom - new_h
        canvas.alpha_composite(actor, (x, y))
        result.append(canvas)
    return result


def write_atlas(frames: list[Image.Image], path: Path, columns: int = 8) -> tuple[int, int]:
    path.parent.mkdir(parents=True, exist_ok=True)
    cell = frames[0].width
    rows = math.ceil(len(frames) / columns)
    atlas = Image.new("RGBA", (columns * cell, rows * cell), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, ((index % columns) * cell, (index // columns) * cell))
    atlas.save(path, optimize=True)
    return columns, rows


def write_preview(frames: list[Image.Image], path: Path, fps: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    duration = max(20, round(1000.0 / fps))
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        disposal=2,
        optimize=False,
    )


def build_traveler(source: Path) -> dict:
    metadata = {
        "format": 1,
        "cell_size": 288,
        "columns": 8,
        "anchor": [144, 268],
        "clips": {},
    }
    for name, spec in CLIPS.items():
        decoded = decode_video(source / spec["source"])
        sampled = sample_evenly(decoded, spec["frames"])
        stable = stabilize_frames(sampled, cell=288, target_height=252, bottom=270)
        columns, rows = write_atlas(stable, TRAVELER_OUT / f"{name}.png")
        write_preview(stable, REVIEW_OUT / f"traveler-{name}.gif", spec["fps"])
        metadata["clips"][name] = {
            "atlas": f"{name}.png",
            "frames": len(stable),
            "fps": spec["fps"],
            "loop": spec["loop"],
            "release_frame": spec["release"],
            "columns": columns,
            "rows": rows,
        }
    (TRAVELER_OUT / "animation.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return metadata


def build_monster(source: Path) -> dict:
    paths = sorted(source.glob("sprite_*.png"))
    if not paths:
        raise RuntimeError(f"No sprite_*.png files in {source}")
    rgba_frames = [np.asarray(Image.open(path).convert("RGBA")) for path in paths]
    stable = stabilize_frames(rgba_frames, cell=256, target_height=218, bottom=242)
    columns, rows = write_atlas(stable, MONSTER_OUT / "run.png", columns=6)
    write_preview(stable, REVIEW_OUT / "hilichurl-run.gif", fps=20.0)
    metadata = {
        "format": 1,
        "cell_size": 256,
        "columns": columns,
        "rows": rows,
        "anchor": [128, 242],
        "clips": {
            "run": {
                "atlas": "run.png",
                "frames": len(stable),
                "fps": 20.0,
                "loop": True,
                "columns": columns,
                "rows": rows,
            }
        },
    }
    (MONSTER_OUT / "animation.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--traveler", type=Path, default=DEFAULT_TRAVELER)
    parser.add_argument("--monster", type=Path, default=DEFAULT_MONSTER)
    args = parser.parse_args()

    for path in (args.traveler, args.monster):
        if not path.exists():
            raise FileNotFoundError(path)
    traveler = build_traveler(args.traveler)
    monster = build_monster(args.monster)
    print(json.dumps({"traveler": traveler, "monster": monster}, ensure_ascii=False))


if __name__ == "__main__":
    main()
