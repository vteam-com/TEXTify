#!/usr/bin/env python3
"""Generate 10 clean test PNG images for OCR evaluation.

Each image: black text on white background, no decorations.
Uses fonts bundled in the repository.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_TEST = os.path.join(REPO, 'assets', 'test')
EXAMPLE_SAMPLES = os.path.join(REPO, 'example', 'assets', 'samples')

FONTS = {
    'roboto': os.path.join(REPO, 'assets', 'fonts', 'Roboto-Regular.ttf'),
    'courier': os.path.join(REPO, 'assets', 'fonts', 'CourierPrime-Regular.ttf'),
    'arial': os.path.join(REPO, 'assets', 'test', 'arial.ttf'),
    'helvetica': os.path.join(REPO, 'assets', 'test', 'helvetica.ttf'),
    'times': os.path.join(REPO, 'assets', 'test', 'times_new_roman.ttf'),
    'courier_new': os.path.join(REPO, 'example', 'assets', 'fonts', 'courier_new.ttf'),
}

# Padding around text
PAD = 24


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONTS[name]
    return ImageFont.truetype(path, size)


def render_lines(lines: list[str], font: ImageFont.FreeTypeFont) -> Image.Image:
    """Render lines of text onto a white image with proper sizing."""
    dummy = Image.new('RGB', (1, 1), 'white')
    draw = ImageDraw.Draw(dummy)

    line_heights = []
    line_widths = []
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        line_heights.append(h)
        line_widths.append(w)

    line_spacing = max(line_heights) // 3 if line_heights else 0
    total_h = sum(line_heights) + line_spacing * (len(lines) - 1) + PAD * 2
    total_w = max(line_widths) + PAD * 2

    img = Image.new('RGB', (total_w, total_h), 'white')
    draw = ImageDraw.Draw(img)

    y = PAD
    for i, line in enumerate(lines):
        draw.text((PAD, y), line, fill='black', font=font)
        y += line_heights[i] + line_spacing

    return img


# ---------------------------------------------------------------------------
# 10 image specifications
# ---------------------------------------------------------------------------
IMAGES = [
    {
        'name': 'address-block',
        'font': 'roboto',
        'size': 28,
        'lines': [
            '350 MAIN STREET',
            'SAN FRANCISCO, CA 94105',
            'UNITED STATES',
        ],
    },
    {
        'name': 'receipt-items',
        'font': 'courier',
        'size': 36,
        'lines': [
            'ITEM        QTY  PRICE',
            'Widget A      3  12.99',
            'Widget B      1   7.50',
            'Gadget C      2  24.00',
            'TOTAL            57.48',
        ],
    },
    {
        'name': 'mixed-case-sentence',
        'font': 'arial',
        'size': 32,
        'lines': [
            'OpenAI Released GPT In 2020.',
            'Version 4 Arrived In March 2023.',
        ],
    },
    {
        'name': 'single-line-large',
        'font': 'helvetica',
        'size': 48,
        'lines': [
            'WAREHOUSE PICKUP 9AM',
        ],
    },
    {
        'name': 'numbers-grid',
        'font': 'courier_new',
        'size': 26,
        'lines': [
            '1001  2002  3003',
            '4004  5005  6006',
            '7007  8008  9009',
        ],
    },
    {
        'name': 'small-text-dense',
        'font': 'roboto',
        'size': 16,
        'lines': [
            'Name: John Smith',
            'Date: 2025-06-15',
            'Reference: TX-98432',
            'Amount: 1,250.75',
            'Status: CONFIRMED',
        ],
    },
    {
        'name': 'uppercase-short-words',
        'font': 'arial',
        'size': 30,
        'lines': [
            'GO BIG OR GO HOME',
            'BE THE BEST YOU CAN BE',
        ],
    },
    {
        'name': 'title-case-names',
        'font': 'times',
        'size': 34,
        'lines': [
            'Alice Johnson',
            'Bob Williams',
            'Charlie Brown',
        ],
    },
    {
        'name': 'codes-and-ids',
        'font': 'courier',
        'size': 24,
        'lines': [
            'ORD-20250615-0042',
            'SKU: AB12CD34EF56',
            'LOT: 2025/Q2/BATCH07',
        ],
    },
    {
        'name': 'paragraph-helvetica',
        'font': 'helvetica',
        'size': 22,
        'lines': [
            'Payment received on 03/15/2025.',
            'Your balance is now 0.00 USD.',
            'Thank you for your purchase.',
        ],
    },
]


def main() -> None:
    os.makedirs(ASSETS_TEST, exist_ok=True)
    os.makedirs(EXAMPLE_SAMPLES, exist_ok=True)

    for spec in IMAGES:
        name = spec['name']
        font = load_font(spec['font'], spec['size'])
        img = render_lines(spec['lines'], font)

        test_path = os.path.join(ASSETS_TEST, f'{name}.png')
        img.save(test_path, 'PNG')

        sample_path = os.path.join(EXAMPLE_SAMPLES, f'{name}.png')
        img.save(sample_path, 'PNG')

        print(f'  {name}.png  {img.width}x{img.height}  font={spec["font"]} size={spec["size"]}')

    print(f'\nGenerated {len(IMAGES)} images in:')
    print(f'  {ASSETS_TEST}/')
    print(f'  {EXAMPLE_SAMPLES}/')


if __name__ == '__main__':
    main()
