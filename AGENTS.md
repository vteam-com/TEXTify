# RULES TO FOLLOW

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
