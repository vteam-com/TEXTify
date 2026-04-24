#!/usr/bin/env python3
"""
Generate english_words.dart from the NGSL (New General Service List).
Fetches the 2,801 headwords from eapfoundation.com and merges with
existing tech/domain words, then outputs the Dart file.
"""

import re
import urllib.request
import html

URL = "https://www.eapfoundation.com/vocab/general/ngsl/"

# Tech/domain words and common nouns to keep (not in NGSL)
EXTRA_WORDS = {
    'amazon', 'apple', 'banana', 'fox', 'gpt', 'macos', 'microsoft',
    'openai', 'node', 'robot', 'soccer', 'sudo', 'widget', 'widgets',
}

# Essential related forms from NGSL that are distinct common words
# (pronouns, articles, common verb forms not captured as headwords)
ESSENTIAL_RELATED = {
    # single-letter words that NGSL may list but scraping can miss
    'a', 'i',
    # from "be": am, are, is, was, were, been, being
    'am', 'are', 'been', 'being', 'was', 'were',
    # from "have": had, has, having
    'had', 'has', 'having',
    # from "do": did, does, doing, done
    'did', 'does', 'doing', 'done',
    # from "he": him, his
    'him', 'his',
    # from "she": her, hers
    'her', 'hers',
    # from "they": their, theirs, them
    'their', 'theirs', 'them',
    # from "we": our, ours, us
    'our', 'ours',
    # from "i": me, my
    'me', 'my',
    # from "you": your, yours
    'your', 'yours',
    # from "a": an
    'an',
    # from "it": its
    'its',
    # from "that": those
    'those',
    # from "this": these
    'these',
    # from "not": common contractions aren't useful for OCR
    # from "go": went, gone, goes
    'went', 'gone', 'goes',
    # from "say": said, says
    'said', 'says',
    # from "know": knew, known, knows
    'knew', 'known', 'knows',
    # from "get": got, gets
    'got', 'gets',
    # from "think": thought
    'thought',
    # from "make": made, makes
    'made', 'makes',
    # from "see": saw, seen, sees
    'saw', 'seen', 'sees',
    # from "come": came, comes
    'came', 'comes',
    # from "take": took, taken, takes
    'took', 'taken', 'takes',
    # from "give": gave, given, gives
    'gave', 'given', 'gives',
    # from "find": found, finds
    'found', 'finds',
    # from "tell": told, tells
    'told', 'tells',
    # from "become": became, becomes
    'became', 'becomes',
    # from "leave": left, leaves
    'left', 'leaves',
    # from "feel": felt
    'felt',
    # from "write": wrote, written, writes
    'wrote', 'written', 'writes',
    # from "begin": began, begun, begins
    'began', 'begun', 'begins',
    # from "run": ran, runs
    'ran', 'runs',
    # from "bring": brought, brings
    'brought', 'brings',
    # from "hold": held, holds
    'held', 'holds',
    # from "stand": stood, stands
    'stood', 'stands',
    # from "lose": lost, loses
    'lost', 'loses',
    # from "child": children
    'children',
    # from "man": men
    'men',
    # from "woman": women
    'women',
    # Common missing short words
    'at', 'be', 'by', 'do', 'go', 'he', 'if', 'in', 'is', 'it',
    'no', 'of', 'on', 'or', 'so', 'to', 'up', 'we', 'us',
    'ok',
}


def fetch_ngsl_headwords():
    """Fetch the NGSL page and extract headwords from the HTML table."""
    print("Fetching NGSL word list...")
    req = urllib.request.Request(URL, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as resp:
        content = resp.read().decode('utf-8')

    # Parse table rows: | NUMBER | HEADWORD | RELATED | SFI | U |
    # Look for <td> elements in the table
    # Pattern: table rows with headword in second <td>
    headwords = set()

    # Find all table rows
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', content, re.DOTALL)
    for row in rows:
        cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
        if len(cells) >= 2:
            # First cell is the number, second is the headword
            num_text = re.sub(r'<[^>]+>', '', cells[0]).strip()
            word_text = re.sub(r'<[^>]+>', '', cells[1]).strip()
            word_text = html.unescape(word_text)
            if num_text.isdigit() and word_text.isalpha():
                headwords.add(word_text.lower())

    print(f"  Extracted {len(headwords)} NGSL headwords")
    return headwords


def generate_dart_file(words, output_path):
    """Generate the Dart file with the word set."""
    sorted_words = sorted(words)
    lines = [
        "// ignore: fcheck_hardcode_strings",
        "// ignore: fcheck_code_size",
        "",
        "/// This library is part of the Textify package.",
        "/// Contains a set of high-frequency English words (NGSL + essential forms)",
        "/// used for dictionary-based text correction.",
        "///",
        "/// Based on the New General Service List (NGSL) by Browne, Culligan & Phillips",
        "/// (2013), covering ~92% of general English text, supplemented with essential",
        "/// inflected forms (pronouns, irregular verb forms) and technical terms.",
        "library;",
        "",
        "/// High-frequency English words for OCR dictionary correction",
        "Set<String> englishWords = {",
    ]
    for w in sorted_words:
        lines.append(f"  '{w}',")
    lines.append("};")
    lines.append("")  # trailing newline

    with open(output_path, 'w') as f:
        f.write('\n'.join(lines))

    print(f"  Wrote {len(sorted_words)} words to {output_path}")


def _generate_plurals(words):
    """Generate simple plural forms for words where the plural is not already present."""
    plurals = set()
    for w in words:
        if len(w) < 3:
            continue
        # Skip words that already end in 's' (plurals, mass nouns, etc.)
        if w.endswith('s'):
            continue
        plural = w + 's'
        if plural not in words:
            plurals.add(plural)
    return plurals


def main():
    headwords = fetch_ngsl_headwords()

    if len(headwords) < 2700:
        print(f"ERROR: Only got {len(headwords)} headwords, expected ~2801")
        return

    # Merge all word sources
    all_words = headwords | ESSENTIAL_RELATED | EXTRA_WORDS

    # Filter: only alphabetic, lowercase, length >= 2
    all_words = {w.lower() for w in all_words if w.isalpha() and len(w) >= 2}

    # Add simple plural forms to prevent dictionary over-correction
    # (e.g., STATES -> STATUS when 'states' is missing but 'status' exists)
    plurals = _generate_plurals(all_words)
    all_words |= plurals
    print(f"  Total after merge + plurals: {len(all_words)} words ({len(plurals)} plurals added)")

    output = "lib/models/english_words.dart"
    generate_dart_file(all_words, output)
    print("Done!")


if __name__ == '__main__':
    main()
