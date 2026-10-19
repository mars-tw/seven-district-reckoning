"""Measure screenshot tone metrics for optimization evidence (R1).

Reports whole-frame luminance/saturation and an optional character crop gate:
brightness 0.30-0.75, near-black < 35 %, saturation >= 0.32 (character colour
pixels only, i.e. excluding very dark pixels), low-saturation < 20 %.
Usage: python tools/r1_visual_metrics.py image.png [x0 y0 x1 y1]
"""
import colorsys
import json
import sys

from PIL import Image


def stats(img):
    rgb = img.convert("RGB")
    px = list(rgb.get_flattened_data() if hasattr(rgb, "get_flattened_data") else rgb.getdata())
    n = len(px)
    lum = sat = 0.0
    near_black = low_sat = 0
    for r, g, b in px:
        r, g, b = r / 255, g / 255, b / 255
        y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        _, l, s = colorsys.rgb_to_hls(r, g, b)
        hsv_s = colorsys.rgb_to_hsv(r, g, b)[1]
        lum += y
        sat += hsv_s
        near_black += y < 0.12
        low_sat += hsv_s < 0.2
    return {"pixels": n, "mean_luminance": round(lum / n, 3), "mean_saturation": round(sat / n, 3),
            "near_black_ratio": round(near_black / n, 3), "low_saturation_ratio": round(low_sat / n, 3)}


def main():
    img = Image.open(sys.argv[1])
    out = {"image": sys.argv[1].replace("\\", "/"), "frame": stats(img)}
    if len(sys.argv) == 6:
        box = tuple(int(v) for v in sys.argv[2:6])
        out["crop_box"] = box
        out["crop"] = stats(img.crop(box))
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
