#!/usr/bin/env python3
"""Generate a deterministic image-only Urban Company receipt PDF fixture.

The output PDF contains raster images only. It intentionally avoids PDF text
operators so the receipt parser must go through the PDF-rendering + OCR path.
"""

from __future__ import annotations

import argparse
import os
import zlib
from dataclasses import dataclass


FONT = {
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    "/": ["00001", "00010", "00100", "01000", "10000", "00000", "00000"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00001", "00001", "00001", "00001", "10001", "10001", "01110"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
}


@dataclass(frozen=True)
class Image:
    width: int
    height: int
    pixels: bytearray


def new_image(width: int, height: int) -> Image:
    return Image(width, height, bytearray([255]) * width * height * 3)


def fill_rect(image: Image, x: int, y: int, width: int, height: int, color: int) -> None:
    for row in range(max(0, y), min(image.height, y + height)):
        for col in range(max(0, x), min(image.width, x + width)):
            index = (row * image.width + col) * 3
            image.pixels[index : index + 3] = bytes((color, color, color))


def draw_text(image: Image, x: int, y: int, text: str, scale: int = 4) -> None:
    cursor = x
    for char in text.upper():
        glyph = FONT.get(char, FONT[" "])
        for glyph_y, row in enumerate(glyph):
            for glyph_x, bit in enumerate(row):
                if bit == "1":
                    fill_rect(
                        image,
                        cursor + glyph_x * scale,
                        y + glyph_y * scale,
                        scale,
                        scale,
                        0,
                    )
        cursor += 6 * scale


def receipt_page(lines: list[str], page_number: int) -> Image:
    image = new_image(900, 1200)
    fill_rect(image, 48, 48, 804, 1104, 245)
    fill_rect(image, 70, 70, 760, 1060, 255)
    fill_rect(image, 70, 70, 760, 8, 0)
    fill_rect(image, 70, 1122, 760, 8, 0)
    fill_rect(image, 70, 70, 8, 1060, 0)
    fill_rect(image, 822, 70, 8, 1060, 0)

    y = 120
    for index, line in enumerate(lines):
        scale = 5 if index == 0 else 4
        draw_text(image, 115, y, line, scale=scale)
        y += 58 if scale == 5 else 48

    draw_text(image, 115, 1060, f"PAGE {page_number} / 2", scale=3)
    return image


def pdf_bytes(images: list[Image]) -> bytes:
    objects: list[bytes] = []
    page_ids = []
    next_id = 3

    for image in images:
        page_id = next_id
        contents_id = next_id + 1
        image_id = next_id + 2
        next_id += 3
        page_ids.append(page_id)

        compressed = zlib.compress(bytes(image.pixels), level=9)
        image_object = (
            f"<< /Type /XObject /Subtype /Image /Width {image.width} "
            f"/Height {image.height} /ColorSpace /DeviceRGB "
            f"/BitsPerComponent 8 /Filter /FlateDecode /Length {len(compressed)} >>\n"
        ).encode("ascii") + b"stream\n" + compressed + b"\nendstream"

        commands = (
            f"q\n{image.width} 0 0 {image.height} 0 0 cm\n/Im0 Do\nQ\n"
        ).encode("ascii")
        contents_object = (
            f"<< /Length {len(commands)} >>\n".encode("ascii")
            + b"stream\n"
            + commands
            + b"endstream"
        )
        page_object = (
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {image.width} {image.height}] "
            f"/Resources << /XObject << /Im0 {image_id} 0 R >> >> "
            f"/Contents {contents_id} 0 R >>"
        ).encode("ascii")
        objects.extend([page_object, contents_object, image_object])

    kids = " ".join(f"{page_id} 0 R" for page_id in page_ids)
    objects.insert(0, b"<< /Type /Catalog /Pages 2 0 R >>")
    objects.insert(1, f"<< /Type /Pages /Kids [{kids}] /Count {len(page_ids)} >>".encode("ascii"))

    output = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for object_id, obj in enumerate(objects, start=1):
        offsets.append(len(output))
        output.extend(f"{object_id} 0 obj\n".encode("ascii"))
        output.extend(obj)
        output.extend(b"\nendobj\n")

    xref_offset = len(output)
    output.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    output.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    output.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF\n".encode("ascii")
    )
    return bytes(output)


def generate(output_path: str) -> None:
    pages = [
        receipt_page(
            [
                "URBAN COMPANY",
                "TAX INVOICE",
                "INVOICE NO UCIC260010284981",
                "ITEMS",
                "CONVENIENCE AND PLATFORM FEE - PLUMBER",
                "SAC 999799",
                "TAXABLE VALUE RS 7.63",
                "IGST 18 PERCENT RS 1.37",
                "TOTAL AMOUNT RS 9",
            ],
            1,
        ),
        receipt_page(
            [
                "URBAN COMPANY",
                "TAX INVOICE",
                "INVOICE NO UCIC260010284982",
                "ITEMS",
                "MINOR PLUMBING REPAIR",
                "SAC 998719",
                "TAXABLE VALUE RS 377.12",
                "IGST 18 PERCENT RS 68.88",
                "TOTAL AMOUNT RS 446",
                "GRAND TOTAL RS 455",
            ],
            2,
        ),
    ]
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    with open(output_path, "wb") as handle:
        handle.write(pdf_bytes(pages))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "output",
        nargs="?",
        default="artifacts/fixtures/uc_invoice_image_only.pdf",
        help="Output PDF path.",
    )
    args = parser.parse_args()
    generate(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
