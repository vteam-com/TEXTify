# RULES TO FOLLOW

## Input image constraints

This library targets **clean digital text only**. All design decisions, algorithms, and optimizations must assume these constraints:

- **Digital text only** — computer-generated/rendered text (e.g., PDFs, screenshots, UI captures)
- **No handwriting** — no cursive, no freehand, no variable-stroke input
- **No italic fonts** — upright (roman) typefaces only; no slanted/oblique glyphs
- **No touching characters** — minimal to no kerning overlap; characters have clear pixel gaps between them. Minor touching (e.g., serifs meeting at baselines) is tolerated: detect artifacts significantly wider than the line average, attempt valley-based splitting, and re-match the pieces
- **No images, art, or photos** — input contains only text on a plain background
- **No decorative lines or borders** — no frames, boxes, rules, or separator lines
- **Clean background** — white or uniform background with no noise, gradients, or watermarks
- **Single text color** — dark text on light background (no colored or multi-tone text)

These constraints mean:

- Characters are isolated connected components (except multi-part glyphs like `i`, `j`, `:`, `;`, `!`, `%`, `=`, `"`)
- Binary thresholding (Otsu) produces near-perfect foreground/background separation
- Vertical histogram projection within a text line yields zero-valued gaps between every character
- No skew/rotation correction is needed

## Clean build

- no build warning
- run tool/check.sh
- fcheck output must reach 100% compliant
- never hardcode specific OCR words/phrases to forced replacements (for example `"HELP" -> "HELLO"`). prefer structural normalization and model/dictionary-driven fixes.
- never map specific noisy token signatures to fixed target words (for example `IlIe -> The`).
- image source to test with
  - ./assets/test/bank_statement_test.png
  - ./assets/test/input_test_image.png
  - ./assets/test/the-quick-brown-fox.png
  - ./assets/test/lines-circles.png

## TESTS

- Test Coverage must not regress, its currently at 83% (update this value if it improves)
- test result shall be capture in the file test_resutl_<current_version>.txt
- compare new result Overall char-accuracy: 80% with previouse the result should improve (update this value if it improves)
