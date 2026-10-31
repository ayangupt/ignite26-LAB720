#!/usr/bin/env python3
"""Render source-pixel guide crops, callouts, manifests and review sheets.

Requires Pillow. Run from any directory:
  python3 img/guide-annotations/render.py --review-dir /path/to/review
"""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
WIDTH = 960
PADDING = 24
INK = "#162c43"
BLUE = "#0067b8"
PAPER = "#ffffff"
RULE = "#c8d3df"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def lines_for(text, font, available):
    lines, line = [], ""
    for word in text.split():
        candidate = f"{line} {word}".strip()
        if font.getlength(candidate) > available:
            if not line:
                raise ValueError(f"Label word is too wide: {word}")
            lines.append(line)
            line = word
        else:
            line = candidate
    if line:
        lines.append(line)
    return lines


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def save_immutable(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() != data:
        raise ValueError(f"Refusing to overwrite different bytes: {path}")
    path.write_bytes(data)


def validate_crop(crop, image):
    left, top, right, bottom = crop
    if not (0 <= left < right <= image.width and 0 <= top < bottom <= image.height):
        raise ValueError(f"Invalid crop {crop} for {image.size}")


def render_panel(source, panel, number, regular, bold):
    crops = panel.get("crops", [panel.get("crop")])
    for crop in crops:
        validate_crop(crop, source)
    vertical = panel.get("layout") == "vertical"
    gap = 24 if len(crops) > 1 else 0
    total_width = sum(box[2] - box[0] for box in crops)
    scale = min(3.0, (WIDTH - 2 * PADDING - gap * (len(crops) - 1)) / total_width)
    rendered, scales = [], []
    for box in crops:
        crop = source.crop(box)
        piece_scale = min(3.0, (WIDTH - 2 * PADDING) / crop.width) if vertical else scale
        size = (round(crop.width * piece_scale), round(crop.height * piece_scale))
        rendered.append(crop.resize(size, Image.Resampling.LANCZOS))
        scales.append(piece_scale)
    labels = lines_for(panel["label"], bold, WIDTH - 112)
    header_height = max(60, len(labels) * 44) + 22
    image_height = (
        sum(image.height for image in rendered) + gap * (len(rendered) - 1)
        if vertical else max(image.height for image in rendered)
    )
    result = Image.new("RGB", (WIDTH, header_height + image_height + 28), PAPER)
    draw = ImageDraw.Draw(result)
    draw.rectangle((PADDING, 8, PADDING + 52, 60), fill=BLUE)
    draw.text((PADDING + 26, 34), str(number), font=regular, fill=PAPER, anchor="mm")
    for index, line in enumerate(labels):
        draw.text((92, 12 + index * 44), line, font=bold, fill=INK)
    content_width = (
        max(image.width for image in rendered)
        if vertical else sum(image.width for image in rendered) + gap * (len(crops) - 1)
    )
    x = (WIDTH - content_width) // 2
    y = header_height
    covered_boxes = 0
    for crop_box, image, piece_scale in zip(crops, rendered, scales):
        if vertical:
            x = (WIDTH - image.width) // 2
        result.paste(image, (x, y))
        draw.rectangle((x, y, x + image.width - 1, y + image.height - 1), outline=RULE, width=1)
        for box in panel.get("boxes", []):
            if (
                crop_box[0] <= box[0] < box[2] <= crop_box[2]
                and crop_box[1] <= box[1] < box[3] <= crop_box[3]
            ):
                target = (
                    x + round((box[0] - crop_box[0]) * piece_scale),
                    y + round((box[1] - crop_box[1]) * piece_scale),
                    x + round((box[2] - crop_box[0]) * piece_scale),
                    y + round((box[3] - crop_box[1]) * piece_scale),
                )
                draw.rectangle(target, outline=PAPER, width=8)
                draw.rectangle(target, outline=BLUE, width=4)
                covered_boxes += 1
        if vertical:
            y += image.height + gap
        else:
            x += image.width + gap
    if covered_boxes != len(panel.get("boxes", [])):
        raise ValueError(f"Highlight falls outside its crop: {panel['label']}")
    return result


def render_image(source, item, regular, bold):
    panels = [
        render_panel(source, panel, index, regular, bold)
        for index, panel in enumerate(item["panels"], 1)
    ]
    footer = item.get("credit", "")
    footer_lines = lines_for(footer, regular, WIDTH - PADDING * 2) if footer else []
    footer_height = len(footer_lines) * 42 + (20 if footer_lines else 0)
    height = sum(panel.height for panel in panels) + 16 * (len(panels) - 1) + footer_height
    result = Image.new("RGB", (WIDTH, height), PAPER)
    draw, top = ImageDraw.Draw(result), 0
    for panel in panels:
        result.paste(panel, (0, top))
        top += panel.height + 16
        if top < height - footer_height:
            draw.line((PADDING, top - 8, WIDTH - PADDING, top - 8), fill=RULE, width=2)
    top -= 16
    for line in footer_lines:
        draw.text((PADDING, top + 8), line, font=regular, fill=INK)
        top += 42
    return result


def fit(image, width, height):
    result = image.copy()
    result.thumbnail((width, height), Image.Resampling.LANCZOS)
    return result


def review_sheets(records, sources, outputs, review_dir, font_path):
    review_dir.mkdir(parents=True, exist_ok=True)
    small = ImageFont.truetype(str(font_path), 22)
    caption = ImageFont.truetype(str(font_path), 18)
    cell_width, cell_height = 520, 430
    contact = Image.new("RGB", (cell_width * 5, cell_height * 5), PAPER)
    draw = ImageDraw.Draw(contact)
    for index, (record, before, after) in enumerate(zip(records, sources, outputs)):
        x, y = (index % 5) * cell_width, (index // 5) * cell_height
        draw.text((x + 14, y + 10), f"{index + 1:02}  {record['name']}", font=small, fill=INK)
        draw.text((x + 14, y + 42), "Original", font=caption, fill=INK)
        label = "Unchanged" if record["decision"] == "unchanged" else "Annotated"
        draw.text((x + 270, y + 42), label, font=caption, fill=INK)
        for image, column in [(before, 14), (after, 270)]:
            thumb = fit(image, 236, 310)
            contact.paste(thumb, (x + column, y + 75))
        draw.line((x + 8, y + 416, x + 510, y + 416), fill=RULE, width=1)
    contact.save(review_dir / "before-after-contact-sheet.png")
    for index in range(0, len(outputs), 2):
        selected = outputs[index:index + 2]
        for width, label in [(450, "guide-450"), (WIDTH, "full")]:
            scaled = [
                image.resize(
                    (width, round(image.height * width / image.width)),
                    Image.Resampling.LANCZOS,
                )
                for image in selected
            ]
            height = max(image.height for image in scaled) + 64
            board = Image.new("RGB", (2 * width + 48, height), "#edf2f7")
            board_draw = ImageDraw.Draw(board)
            for slot, image in enumerate(scaled):
                x = 16 + slot * (width + 16)
                board_draw.text(
                    (x, 12),
                    f"{index + slot + 1:02}  {records[index + slot]['name']}",
                    font=small,
                    fill=INK,
                )
                board.paste(image, (x, 52))
            board.save(review_dir / f"{label}-{index // 2 + 1:02}.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-dir", type=Path, required=True)
    parser.add_argument("--font", type=Path, default=Path("/System/Library/Fonts/Supplemental/Arial.ttf"))
    parser.add_argument("--bold-font", type=Path, default=Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
    args = parser.parse_args()
    regular = ImageFont.truetype(str(args.font), 36)
    bold = ImageFont.truetype(str(args.bold_font), 38)
    specs = json.loads((ROOT / "recipes.json").read_text())
    records, sources, outputs = [], [], []
    for item in specs["images"]:
        source_path = ROOT / item["source"]
        original_bytes = source_path.read_bytes()
        source = Image.open(io.BytesIO(original_bytes)).convert("RGB")
        if digest(original_bytes) != item["sourceSha256"]:
            raise ValueError(f"Source hash changed: {source_path}")
        record = dict(item)
        record["sourceSize"] = list(source.size)
        if item["decision"] == "unchanged":
            image = source
            record.update({
                "nativeReference": item["originalNativeReference"],
                "uploadRequired": False,
                "outputSha256": item["sourceSha256"],
            })
        else:
            if not 1 <= len(item["panels"]) <= 3:
                raise ValueError("Use one to three focused callouts per image")
            image = render_image(source, item, regular, bold)
            data = png_bytes(image)
            filename = f"{item['slug']}-annotated-{digest(data)[:12]}.png"
            save_immutable(ROOT / "annotated" / filename, data)
            record.update({
                "output": f"annotated/{filename}",
                "outputSize": list(image.size),
                "outputSha256": digest(data),
                "nativeReference": f"instructions362436/{filename}",
                "uploadRequired": True,
            })
        records.append(record)
        sources.append(source)
        outputs.append(image)
    manifest = {
        "baselineManualSha256": specs["baselineManualSha256"],
        "targetInstructionsSetId": 362436,
        "status": "assets-prepared-not-published",
        "renderer": {
            "file": "render.py",
            "sha256": digest(Path(__file__).read_bytes()),
            "recipesSha256": digest((ROOT / "recipes.json").read_bytes()),
            "fontSha256": digest(args.font.read_bytes()),
            "boldFontSha256": digest(args.bold_font.read_bytes()),
            "outputWidth": WIDTH,
            "labelPixelsAt450Width": 38 * 450 / WIDTH,
            "method": "Original pixel crops, explicit crop gutters, Lanczos resizing, outside labels and two-tone outlines. No generated or reconstructed UI.",
        },
        "imageCount": len(records),
        "changedCount": sum(record["uploadRequired"] for record in records),
        "unchangedCount": sum(not record["uploadRequired"] for record in records),
        "images": records,
    }
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    review_sheets(records, sources, outputs, args.review_dir, args.font)
    print(json.dumps({key: manifest[key] for key in ["imageCount", "changedCount", "unchangedCount"]}))
    print(f"Review sheets: {args.review_dir}")


if __name__ == "__main__":
    main()
