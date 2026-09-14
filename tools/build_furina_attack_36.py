from pathlib import Path
import shutil
import subprocess

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game/assets/characters/furina_ai_frames/attack_8"
OUT = ROOT / "game/assets/characters/furina_ai_frames/attack_36"
TEMP = OUT / "_temp_green"
CELL = 512
FRAME_COUNT = 36
FPS = 18
ATLAS_COLUMNS = 9


def on_green(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[..., 3:4] / 255.0
    green = np.zeros_like(rgba[..., :3])
    green[..., 1] = 255.0
    rgb = rgba[..., :3] * alpha + green * (1.0 - alpha)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def remove_green(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green_delta = green - np.maximum(red, blue)
    key = np.clip((green_delta - 18.0) / 58.0, 0.0, 1.0)
    key *= np.clip((green - 62.0) / 90.0, 0.0, 1.0)
    alpha = ((1.0 - key) * 255.0).astype(np.uint8)
    spill = key > 0.01
    rgb[..., 1][spill] = np.minimum(rgb[..., 1][spill], np.maximum(red, blue)[spill] + 6.0)
    return Image.fromarray(np.dstack((np.clip(rgb, 0, 255).astype(np.uint8), alpha)))


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    TEMP.mkdir(parents=True)

    keyframes = [Image.open(SOURCE / f"attack-{index:02d}.png") for index in range(8)]
    # Two wrapped keyframes give the bidirectional interpolator enough future
    # context to synthesize all 36 frames and keep the loop seam smooth.
    for index, frame in enumerate(keyframes + [keyframes[0], keyframes[1]]):
        on_green(frame).save(TEMP / f"key-{index:02d}.png")

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg was not found")
    subprocess.run(
        [
            ffmpeg,
            "-y",
            "-framerate",
            "4",
            "-i",
            str(TEMP / "key-%02d.png"),
            "-vf",
            "minterpolate=fps=18:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1",
            "-frames:v",
            str(FRAME_COUNT),
            str(TEMP / "flow-%02d.png"),
        ],
        check=True,
    )

    frames = []
    for index in range(FRAME_COUNT):
        frame = remove_green(Image.open(TEMP / f"flow-{index + 1:02d}.png"))
        frame.save(OUT / f"attack-{index:02d}.png", optimize=True)
        frames.append(frame)

    rows = (FRAME_COUNT + ATLAS_COLUMNS - 1) // ATLAS_COLUMNS
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * CELL, rows * CELL), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, ((index % ATLAS_COLUMNS) * CELL, (index // ATLAS_COLUMNS) * CELL))
    atlas.save(OUT / "furina-attack-36-atlas.png", optimize=True)

    preview = []
    for frame in frames:
        board = Image.new("RGBA", frame.size, (28, 34, 53, 255))
        board.alpha_composite(frame)
        preview.append(board.convert("RGB"))
    preview[0].save(
        OUT / "furina-attack-36-preview.gif",
        save_all=True,
        append_images=preview[1:],
        duration=round(1000 / FPS),
        loop=0,
        disposal=2,
    )

    shutil.rmtree(TEMP)
    print(f"frames={len(frames)} fps={FPS} duration={len(frames) / FPS:.2f}s atlas={atlas.size}")


if __name__ == "__main__":
    main()
