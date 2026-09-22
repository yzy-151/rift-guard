from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


ROOT = Path(r"C:\Users\23081\Desktop\codex\rift-guard\outputs\galio-boss-showcase-v1")
FRAME_DIR = ROOT / "frames"
frames = sorted(FRAME_DIR.glob("frame-*.png"))
if not frames:
    raise SystemExit("no Galio frames")

images = [Image.open(path).convert("RGB") for path in frames]
quantized = [
    image.quantize(colors=112, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    for image in images
]
gif_path = ROOT / "galio-dual-boss-showcase.gif"
quantized[0].save(
    gif_path,
    save_all=True,
    append_images=quantized[1:],
    duration=83,
    loop=0,
    disposal=2,
    optimize=False,
)

indices = [round(index * (len(images) - 1) / 11) for index in range(12)]
thumbs = [ImageOps.fit(images[index], (320, 180), method=Image.Resampling.LANCZOS) for index in indices]
sheet = Image.new("RGB", (1280, 540), (8, 8, 18))
draw = ImageDraw.Draw(sheet)
for slot, (index, thumb) in enumerate(zip(indices, thumbs)):
    x = (slot % 4) * 320
    y = (slot // 4) * 180
    sheet.paste(thumb, (x, y))
    draw.rectangle((x + 4, y + 4, x + 88, y + 26), fill=(6, 6, 14))
    draw.text((x + 10, y + 8), f"F{index:03d}", fill=(235, 225, 255))
sheet.save(ROOT / "galio-contact-sheet.jpg", quality=90, optimize=True)
print(f"built {gif_path} frames={len(images)} size={gif_path.stat().st_size}")
