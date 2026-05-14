#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def make_icon(root: Path) -> None:
    source = root / "Assets" / "appIcon.png"
    if not source.exists():
        raise SystemExit("missing appIcon.png")

    build = root / "build-assets"
    iconset = build / "AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)

    foreground = crop_to_content(Image.open(source).convert("RGBA"))
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    for filename, size in sizes.items():
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        background = Image.new("RGBA", (size, size), (255, 255, 255, 255))
        mask = Image.new("L", (size, size), 0)
        radius = max(3, int(size * 0.22))
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
        canvas.paste(background, (0, 0), mask)

        inset = max(1, int(size * 0.16))
        icon_size = size - inset * 2
        icon = foreground.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        canvas.alpha_composite(icon, (inset, inset))
        canvas.save(iconset / filename)

    output = build / "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(output)], check=True)


def crop_to_content(image: Image.Image) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


if __name__ == "__main__":
    make_icon(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve())
