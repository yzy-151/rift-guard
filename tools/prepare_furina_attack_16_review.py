from pathlib import Path
import json

import cv2
import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "review/furina_attack_16_v2"
SOURCE_A = OUT / "attack-frames-00-11-source.png"
SOURCE_B = OUT / "attack-frames-12-15-source.png"
MASTER_REFERENCE = OUT / "furina-new-master-reference.png"
CELL = 512
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


def clean_stray_components(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    binary = (rgba[..., 3] > 24).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8)
    if count <= 2:
        return image

    areas = stats[1:, cv2.CC_STAT_AREA]
    largest = int(np.argmax(areas)) + 1
    largest_area = stats[largest, cv2.CC_STAT_AREA]
    keep = {largest}
    largest_mask = (labels == largest).astype(np.uint8)
    near_largest = cv2.dilate(largest_mask, np.ones((25, 25), np.uint8), iterations=1).astype(bool)
    for label in range(1, count):
        if label == largest:
            continue
        component = labels == label
        area = stats[label, cv2.CC_STAT_AREA]
        near_body = bool(np.any(component & near_largest))
        substantial = area >= max(650, largest_area * 0.05)
        if near_body or substantial:
            keep.add(label)

    keep_mask = np.isin(labels, list(keep)).astype(np.uint8)
    keep_mask = cv2.dilate(keep_mask, np.ones((3, 3), np.uint8), iterations=1).astype(bool)
    rgba[~keep_mask] = 0
    return Image.fromarray(rgba)


def detect_rows(sheet: Image.Image, expected: int):
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
    if len(bands) != expected:
        raise RuntimeError(f"Expected {expected} rows, found {bands}")
    cuts = [0]
    for current, following in zip(bands, bands[1:]):
        cuts.append((current[1] + following[0]) // 2)
    cuts.append(sheet.height)
    return list(zip(cuts, cuts[1:]))


def split_sheet(sheet: Image.Image, columns: int, rows: int):
    row_bounds = detect_rows(sheet, rows)
    result = []
    for row, (top, bottom) in enumerate(row_bounds):
        for column in range(columns):
            left = round(column * sheet.width / columns)
            right = round((column + 1) * sheet.width / columns)
            keyed = remove_green(sheet.crop((left, top, right, bottom)))
            result.append(clean_stray_components(keyed))
    return result


def opaque_metrics(frame: Image.Image):
    alpha = np.asarray(frame.getchannel("A")) > 28
    ys, xs = np.where(alpha)
    if not len(xs):
        raise RuntimeError("Empty frame")
    return {
        "left": int(xs.min()),
        "top": int(ys.min()),
        "right": int(xs.max()) + 1,
        "bottom": int(ys.max()) + 1,
        "center_x": float(np.median(xs)),
    }


def normalize(frame: Image.Image, target_height: float):
    metrics = opaque_metrics(frame)
    height = metrics["bottom"] - metrics["top"]
    scale = target_height / height
    scaled = frame.resize(
        (max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
        Image.Resampling.LANCZOS,
    )
    metrics = opaque_metrics(scaled)
    x = round(CELL / 2 - metrics["center_x"])
    y = BASELINE - metrics["bottom"]
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (x, y))
    placed = opaque_metrics(canvas)
    if placed["left"] <= 3 or placed["right"] >= CELL - 3 or placed["top"] <= 3:
        raise RuntimeError(f"Frame touches safety edge: {placed}")
    return canvas, placed


def main():
    sheet_a = Image.open(SOURCE_A).convert("RGB")
    sheet_b = Image.open(SOURCE_B).convert("RGB")
    source_a = split_sheet(sheet_a, 4, 3)
    source_b = split_sheet(sheet_b, 4, 1)
    # Attack first, then recoil and settle. The fourth generated recovery pose lost
    # its blade, so omit it and close on the exact starting pose for a clean seam.
    raw = source_a[:8] + source_b[:3] + source_a[8:] + [source_a[0].copy()]
    if len(raw) != 16:
        raise RuntimeError(f"Expected 16 frames, got {len(raw)}")

    target_height = 380.0
    max_width = 0.0
    for frame in raw:
        metrics = opaque_metrics(frame)
        height = metrics["bottom"] - metrics["top"]
        width = metrics["right"] - metrics["left"]
        max_width = max(max_width, width * target_height / height)
    if max_width > 480:
        target_height *= 480 / max_width

    frame_dir = OUT / "frames_rgba"
    frame_dir.mkdir(exist_ok=True)
    frames = []
    checks = []
    for index, frame in enumerate(raw):
        normalized, metrics = normalize(frame, target_height)
        normalized.save(frame_dir / f"attack-{index:02d}.png", optimize=True)
        frames.append(normalized)
        checks.append({"frame": index, **metrics})

    transparent = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    green = Image.new("RGB", transparent.size, (0, 255, 0))
    contact = Image.new("RGB", (256 * 4, 256 * 4), (28, 34, 53))
    draw = ImageDraw.Draw(contact)
    previews = []
    for index, frame in enumerate(frames):
        x, y = (index % 4) * CELL, (index // 4) * CELL
        transparent.alpha_composite(frame, (x, y))
        green.paste(frame.convert("RGB"), (x, y), frame.getchannel("A"))
        board = Image.new("RGBA", (CELL, CELL), (28, 34, 53, 255))
        board.alpha_composite(frame)
        preview = board.convert("RGB").resize((256, 256), Image.Resampling.LANCZOS)
        previews.append(preview)
        contact.paste(preview, ((index % 4) * 256, (index // 4) * 256))
        draw.text(((index % 4) * 256 + 6, (index // 4) * 256 + 6), str(index), fill="white")

    transparent.save(OUT / "furina-attack-16-4x4-transparent.png", optimize=True)
    green.save(OUT / "furina-attack-16-4x4-green.png", optimize=True)
    contact.save(OUT / "furina-attack-16-contact-sheet.jpg", quality=92)
    previews[0].save(
        OUT / "furina-attack-16-preview.gif",
        save_all=True,
        append_images=previews[1:],
        duration=125,
        loop=0,
        disposal=2,
        optimize=True,
    )

    master = Image.open(MASTER_REFERENCE).convert("RGBA")
    master.thumbnail((900, 900), Image.Resampling.LANCZOS)
    video_reference = Image.new("RGB", (1024, 1024), (0, 255, 0))
    video_reference.paste(
        master.convert("RGB"),
        ((1024 - master.width) // 2, (1024 - master.height) // 2),
        master.getchannel("A"),
    )
    video_reference.save(OUT / "video-api-reference-green.png", optimize=True)
    (OUT / "validation.json").write_text(
        json.dumps({"frames": 16, "grid": "4x4", "fps": 8, "seconds": 2, "target_height": target_height, "checks": checks}, indent=2),
        encoding="utf-8",
    )
    print(f"frames=16 grid=4x4 target_height={target_height:.2f} max_width={max_width:.2f}")


if __name__ == "__main__":
    main()
