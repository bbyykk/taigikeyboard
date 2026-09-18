"""Abbreviation keys live in their own FST family (`behavioral-invariants.md` §46).

`create_fst` used to put `tl_abbrev` / `poj_abbrev` / `tps_abbrev` under the
same `tl:` / `poj:` / `tps:` prefix as the phonetic readings, so every
continuous-input prefix scan met acronym keys and needed heuristics to
reject them. Since §46 the acronym face of each family goes under
`<family>-abbrev:` and nothing else does — the engine reads it only through
the whole-buffer abbreviation lookup, and Tab3 search unions both families.
"""

from __future__ import annotations

from build.create_fst import ABBREV_FAMILY_SUFFIX, romanization_keys
from build.dictionary_records import DictionaryRecord


def _record(**overrides) -> DictionaryRecord:
    base = dict(
        rowid=1,
        hanzi="鎖匙",
        tl="só-sî",
        frequency=100,
        tl_num="so2si5",
        tl_notone="sosi",
        tl_abbrev="ss",
        poj_num="so2si5",
        poj_notone="sosi",
        poj_abbrev="ss",
        tps_num="ㄙㄛˋㄒㄧˊ",
        tps_notone="ㄙㄛㄒㄧ",
        tps_abbrev="ㄙㄒ",
        tps_num_var=None,
        tps_notone_var=None,
        tps_abbrev_var=None,
        sources=(),
        syllable_count=2,
        kautian_subtag=0,
    )
    base.update(overrides)
    return DictionaryRecord(**base)


def test_abbreviation_keys_go_to_their_own_family():
    keys = romanization_keys(_record())
    assert f"tl{ABBREV_FAMILY_SUFFIX}:ss" in keys
    assert f"poj{ABBREV_FAMILY_SUFFIX}:ss" in keys
    assert f"tps{ABBREV_FAMILY_SUFFIX}:ㄙㄒ" in keys
    # The phonetic families keep the readings and never the acronym.
    assert "tl:sosi" in keys and "tl:so2si5" in keys
    assert "tl:ss" not in keys and "poj:ss" not in keys and "tps:ㄙㄒ" not in keys


def test_phonetic_families_hold_no_abbreviation_only_key():
    keys = romanization_keys(_record())
    phonetic = [k for k in keys if ABBREV_FAMILY_SUFFIX not in k.split(":", 1)[0]]
    abbrev = [k for k in keys if ABBREV_FAMILY_SUFFIX in k.split(":", 1)[0]]
    assert len(phonetic) + len(abbrev) == len(keys)
    assert {k.split(":", 1)[0] for k in abbrev} == {"tl-abbrev", "poj-abbrev", "tps-abbrev"}


def test_tps_abbreviation_variant_shares_the_family():
    # or-á: ㄜ primary, ㄛ dialect variant (C-3a) — both abbreviation faces
    # are emitted under `tps-abbrev:`.
    keys = romanization_keys(
        _record(
            tl="or-á",
            tl_num="or5a2",
            tl_notone="ora",
            tl_abbrev="oa",
            poj_num="o5a2",
            poj_notone="oa",
            poj_abbrev="oa",
            tps_num="ㄜˊㄚˋ",
            tps_notone="ㄜㄚ",
            tps_abbrev="ㄜㄚ",
            tps_num_var="ㄛˊㄚˋ",
            tps_notone_var="ㄛㄚ",
            tps_abbrev_var="ㄛㄚ",
        )
    )
    assert f"tps{ABBREV_FAMILY_SUFFIX}:ㄜㄚ" in keys
    assert f"tps{ABBREV_FAMILY_SUFFIX}:ㄛㄚ" in keys
    assert "tps:ㄜㄚ" in keys and "tps:ㄛㄚ" in keys  # the readings themselves


def test_single_syllable_row_has_no_abbreviation_key():
    keys = romanization_keys(
        _record(
            hanzi="燒",
            tl="sio",
            tl_num="sio1",
            tl_notone="sio",
            tl_abbrev="",
            poj_num="sio1",
            poj_notone="sio",
            poj_abbrev="",
            tps_num="ㄒㄧㄛ",
            tps_notone="ㄒㄧㄛ",
            tps_abbrev="",
            syllable_count=1,
        )
    )
    assert not [k for k in keys if ABBREV_FAMILY_SUFFIX in k]
