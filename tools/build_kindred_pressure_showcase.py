from pathlib import Path
from PIL import Image, ImageOps, ImageDraw

root = Path(r"C:\Users\23081\Desktop\codex\rift-guard\outputs\kindred-boss-pressure-showcase")
frames = sorted((root / "frames").glob("frame-*.png"))
if not frames:
    raise SystemExit("no frames")
images = [Image.open(path).convert("RGB") for path in frames]
quantized = [image.quantize(colors=112, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG) for image in images]
quantized[0].save(root / "kindred-boss-pressure-showcase.gif", save_all=True, append_images=quantized[1:], duration=83, loop=0, disposal=2, optimize=False)
indices = [round(index * (len(images)-1) / 14) for index in range(15)]
thumbs = [ImageOps.fit(images[index], (320, 180), method=Image.Resampling.LANCZOS) for index in indices]
sheet = Image.new("RGB", (1600, 540), (8, 8, 18))
draw = ImageDraw.Draw(sheet)
for slot, (index, thumb) in enumerate(zip(indices, thumbs)):
    x = (slot % 5) * 320
    y = (slot // 5) * 180
    sheet.paste(thumb, (x, y))
    draw.rectangle((x+4, y+4, x+86, y+26), fill=(6, 6, 14))
    draw.text((x+10, y+8), f"F{index:03d}", fill=(235, 225, 255))
sheet.save(root / "kindred-pressure-contact-sheet.jpg", quality=90, optimize=True)
print(f"built gif frames={len(frames)}")