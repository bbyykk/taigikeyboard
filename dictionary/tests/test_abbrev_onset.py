"""`extract_abbrev` — one leading spelling unit per syllable (§46).

The abbreviation face used to be the first LETTER of each syllable, which
read `ph` as `p` + `h` and made 披頭巾 unreachable through `phthk`. It is
now the longest initial the syllable starts with (TL `ts`/`tsh`, POJ
`ch`/`chh`, the shared `ph`/`th`/`kh`/`ng`, …) or the first letter of a
zero-initial syllable — the same rule TPS always had with its one-glyph
initials. Runtime mirror: `phonetics::derive_abbrev`; every CSV row is
compared against it by `engine/lexicon/tests/roman_num_face_parity.rs`.
"""

from __future__ import annotations

import pytest

from common.abbrev import extract_abbrev


@pytest.mark.parametrize(
    ("reading", "expected"),
    [
        ("phi-thâu-kin", "phthk"),  # 披頭巾 — aspirates whole
        ("tshut-khì", "tshkh"),  # 出去 (TL)
        ("chhut-khì", "chhkh"),  # 出去 (POJ)
        ("tsia̍h-pn̄g", "tsp"),  # 食飯 (TL)
        ("chia̍h-pn̄g", "chp"),  # 食飯 (POJ)
        ("só-sî", "ss"),  # 鎖匙 — unchanged from the first-letter face
        ("âng-enn-á", "aea"),  # 紅嬰仔 — zero initials take the vowel
        ("io̍k-iù-īnn", "iii"),  # 育幼院
        ("m̄-sī", "ms"),  # 毋是
        ("n̂g-sng", "ngs"),  # 黃酸 — syllabic ng stays whole (longest match)
        ("nn̄g-á", "na"),  # 卵仔 — `nng` starts with `n`, not `ng`
        ("ngiau-ti", "ngt"),
        ("ji̍t-thâu", "jth"),  # 日頭 — `j` kept, never folded to `l`
        ("Guá SĪ", "gs"),  # case-insensitive, space delimiter
        ("o͘-á", "oa"),  # POJ `o͘` strips to `o`
    ],
)
def test_leading_unit_per_syllable(reading: str, expected: str) -> None:
    assert extract_abbrev(reading) == expected


def test_single_syllable_and_empty_have_no_abbreviation() -> None:
    assert extract_abbrev("tâi") == ""
    assert extract_abbrev("") == ""
    assert extract_abbrev(None) == ""  # type: ignore[arg-type]
