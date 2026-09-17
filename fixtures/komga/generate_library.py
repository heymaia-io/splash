#!/usr/bin/env python3
"""Generates the deterministic Komga test fixture described in Phase 0 of the port plan.

Layout (under fixtures/komga/data/libraries):
  Comics/<series>/<series> v0N.cbz   - regular series (LTR comics)
  Comics/_oneshots/<name>.cbz        - oneshot (Komga "oneshotsDirectory")
  Manga/<series>/<series> v0N.cbz    - second library; one series has ComicInfo Manga=YesAndRightToLeft
  Webtoon/<series>/...               - tall pages, ComicInfo Format=Webtoon
"""
import io
import sys
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent / "data" / "libraries"

COMIC_INFO = """<?xml version="1.0" encoding="utf-8"?>
<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Title>{title}</Title>
  <Series>{series}</Series>
  <Number>{number}</Number>
  <Year>{year}</Year>
  <Writer>Fixture Writer</Writer>
  <Penciller>Fixture Artist</Penciller>
  <Genre>{genre}</Genre>
  <Tags>fixture</Tags>
  <Manga>{manga}</Manga>
  {extra}
</ComicInfo>
"""


def page(text: str, size: tuple[int, int], color: tuple[int, int, int], fmt: str) -> bytes:
    img = Image.new("RGB", size, color)
    draw = ImageDraw.Draw(img)
    # White border (so crop-borders logic has something to find) + label.
    draw.rectangle([0, 0, size[0] - 1, size[1] - 1], outline=(255, 255, 255), width=24)
    draw.text((60, 60), text, fill=(255, 255, 255))
    buf = io.BytesIO()
    img.save(buf, format=fmt, quality=85)
    return buf.getvalue()


def cbz(path: Path, series: str, number: int, pages: int, size, manga="No", genre="Action",
        extra="", fmt="JPEG"):
    path.parent.mkdir(parents=True, exist_ok=True)
    ext = "jpg" if fmt == "JPEG" else fmt.lower()
    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
        z.writestr("ComicInfo.xml", COMIC_INFO.format(
            title=f"{series} #{number}", series=series, number=number, year=2000 + number,
            genre=genre, manga=manga, extra=extra))
        for p in range(1, pages + 1):
            color = ((number * 50) % 255, (p * 20) % 255, 120)
            z.writestr(f"{p:03d}.{ext}", page(f"{series} v{number} p{p}", size, color, fmt))


def main():
    if ROOT.exists() and "--force" not in sys.argv:
        print(f"{ROOT} exists, skipping (use --force)")
        return
    portrait = (1200, 1800)
    for n in range(1, 4):
        cbz(ROOT / "Comics" / "Fixture Hero" / f"Fixture Hero v{n:02d}.cbz", "Fixture Hero", n, 12, portrait)
    for n in range(1, 3):
        cbz(ROOT / "Comics" / "Second Series" / f"Second Series v{n:02d}.cbz", "Second Series", n, 8, portrait,
            genre="Drama", fmt="PNG")
    cbz(ROOT / "Comics" / "_oneshots" / "Standalone Story.cbz", "Standalone Story", 1, 6, portrait)
    for n in range(1, 4):
        cbz(ROOT / "Manga" / "Fixture Manga" / f"Fixture Manga v{n:02d}.cbz", "Fixture Manga", n, 10, portrait,
            manga="YesAndRightToLeft", genre="Shonen")
    # Spread page (double width) to exercise double-page layout.
    cbz(ROOT / "Manga" / "Spread Manga" / "Spread Manga v01.cbz", "Spread Manga", 1, 6, (2400, 1800),
        manga="YesAndRightToLeft")
    for n in range(1, 3):
        cbz(ROOT / "Webtoon" / "Fixture Webtoon" / f"Fixture Webtoon ep{n:02d}.cbz", "Fixture Webtoon", n, 5,
            (800, 6000), extra="<Format>Webtoon</Format>")
    print("fixture generated at", ROOT)


if __name__ == "__main__":
    main()
