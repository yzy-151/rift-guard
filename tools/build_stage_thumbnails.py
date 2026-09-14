"""Build readable mission-card thumbnails from the Helltaker chapter backgrounds."""
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game" / "assets" / "helltaker" / "backgrounds"
OUTPUT = ROOT / "game" / "assets" / "ui" / "rift_v2" / "stage_thumbnails"
SIZE = (640, 190)


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    rgb = image.convert("RGB")
    mask = Image.new("L", image.size)
    source = rgb.load()
    target = mask.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b = source[x, y]
            target[x, y] = 255 if r > 34 and r > b * 0.78 else 0
    mask = mask.filter(ImageFilter.MaxFilter(15))
    return mask.getbbox() or (0, 0, image.width, image.height)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index in range(1, 9):
        source = SOURCE / f"chapterBG{index:04d}.png"
        image = Image.open(source).convert("RGBA")
        cropped = image.crop(content_box(image))
        cropped = ImageEnhance.Brightness(cropped).enhance(1.28)
        cropped = ImageEnhance.Contrast(cropped).enhance(1.12)
        canvas = Image.new("RGBA", SIZE, (9, 5, 16, 255))
        canvas.alpha_composite(cover(cropped, SIZE))
        canvas.save(OUTPUT / f"stage_{index:02d}.png")
    print(f"built 8 stage thumbnails in {OUTPUT}")


if __name__ == "__main__":
    main()
