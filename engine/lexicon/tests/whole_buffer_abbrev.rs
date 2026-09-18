//! `fetch_abbrev_candidates` — the whole-buffer abbreviation lookup
//! (`behavioral-invariants.md` §46; USER 2026-09-18 `ss` → 鎖匙 `só-sî`).
//!
//! The one continuous fetch that accepts an FST `*_abbrev` acronym hit, and
//! only when the record's own abbreviation face equals the key body.
//! Hermetic wire-format fixtures; the production-artifact run is
//! `composing/tests/candidate_dump.rs`.

use lexicon::dictionary_reader::{DictionaryReader, KAUTIAN_BIT};
use lexicon::{fetch_abbrev_candidates, COVERAGE_KIND_ABBREV};
use phonetics::InputMode;
use ranking::{FrequencyData, FrequencyMap};

mod common;
use common::{build_tkdb_v3, build_wire_index, hanji_of, neutral_ctx, write_temp};

const DEFAULT_SOURCE: u16 = 1 << 11;

type DictRow = (u16, u32, u8, &'static str, &'static str);

/// Rows shared by every test; rowid = 1-based position.
///
/// trace: 鎖匙 só-sî → tl_abbrev "ss", poj_abbrev "ss", tps_abbrev ㄙㄒ;
/// 先生 sian-senn → "ss" (higher freq); 總鎖匙 tsóng-só-sî → "tss";
/// 食飯 tsia̍h-pn̄g → tl "tp", poj (chia̍h-pn̄g) "cp", tps ㄗㄅ;
/// 毋是 m̄-sī → tps_abbrev ㆬㄒ (syllabic nasal ㆬ, not the initial ㄇ);
/// 燒 sio (single syllable, no abbreviation) — keyed under `tl:ss` on
/// purpose to stand in for index drift.
fn rows() -> Vec<DictRow> {
    vec![
        (DEFAULT_SOURCE, 100, 2, "鎖匙", "só-sî"),
        (DEFAULT_SOURCE, 400, 2, "先生", "sian-senn"),
        (DEFAULT_SOURCE, 16, 3, "總鎖匙", "tsóng-só-sî"),
        (KAUTIAN_BIT, 144, 2, "食飯", "tsia̍h-pn̄g"),
        (DEFAULT_SOURCE, 27, 2, "毋是", "m̄-sī"),
        (DEFAULT_SOURCE, 9000, 1, "燒", "sio"),
    ]
}

fn open_dict(name: &str, rows: &[DictRow]) -> DictionaryReader {
    let path = write_temp(name, &build_tkdb_v3(b"TKDB", rows));
    DictionaryReader::open(&path).expect("dict.bin opens")
}

#[test]
fn tl_exact_abbreviation_hits_ranked_by_frequency_with_record_metadata() {
    let idx = build_wire_index(
        "abbrev-tl.fst",
        &[
            ("tl:ss", 1),
            ("tl:ss", 2),
            ("tl:tss", 3),
            ("tl:ss", 6), // drift: 燒's abbreviation face is "" — must be rejected
            ("tl:sosi", 1),
        ],
    );
    let dict = open_dict("abbrev-tl.dict.bin", &rows());
    let freq = FrequencyMap::new();
    let ctx = neutral_ctx(&idx, &dict, &freq, InputMode::Tl);
    let out = fetch_abbrev_candidates("tl:ss", 2, &ctx);
    assert_eq!(hanji_of(&out), vec!["先生", "鎖匙"], "{out:?}");
    let sosi = &out[1];
    assert_eq!(sosi.roman, "só-sî");
    assert_eq!(sosi.canonical_tl, "só-sî");
    assert_eq!(sosi.consumed_span, (0, 2));
    assert_eq!(sosi.syllable_count, 2, "record's own syllable count");
    assert_eq!(sosi.coverage_kind, COVERAGE_KIND_ABBREV);
    assert!(!sosi.is_custom);
}

#[test]
fn source_filter_applies() {
    let idx = build_wire_index("abbrev-filter.fst", &[("tl:tp", 4)]);
    let dict = open_dict("abbrev-filter.dict.bin", &rows());
    let freq = FrequencyMap::new();
    // Kautian on → 食飯 surfaces; only the default source on → dropped.
    let all = neutral_ctx(&idx, &dict, &freq, InputMode::Tl);
    assert_eq!(
        hanji_of(&fetch_abbrev_candidates("tl:tp", 2, &all)),
        vec!["食飯"]
    );
    let mut default_only = neutral_ctx(&idx, &dict, &freq, InputMode::Tl);
    default_only.enabled_sources_bitmask = u32::from(DEFAULT_SOURCE);
    assert!(fetch_abbrev_candidates("tl:tp", 2, &default_only).is_empty());
}

#[test]
fn user_selection_outranks_dictionary_frequency() {
    let idx = build_wire_index("abbrev-freq.fst", &[("tl:ss", 1), ("tl:ss", 2)]);
    let dict = open_dict("abbrev-freq.dict.bin", &rows());
    let mut freq = FrequencyMap::new();
    freq.insert(
        "鎖匙".to_string(),
        "só-sî".to_string(),
        FrequencyData {
            count: 3,
            last_used_ms: 1_000,
        },
    );
    let mut ctx = neutral_ctx(&idx, &dict, &freq, InputMode::Tl);
    ctx.now_ms = 2_000;
    let out = fetch_abbrev_candidates("tl:ss", 2, &ctx);
    assert_eq!(hanji_of(&out), vec!["鎖匙", "先生"], "{out:?}");
}

#[test]
fn poj_family_validates_the_poj_abbreviation_face() {
    // 食飯: POJ display `chia̍h-pn̄g` → "cp"; the TL acronym "tp" is not a
    // POJ face, so a `poj:tp` key (drift) is rejected.
    let idx = build_wire_index(
        "abbrev-poj.fst",
        &[("poj:cp", 4), ("poj:tp", 4), ("poj:ss", 1)],
    );
    let dict = open_dict("abbrev-poj.dict.bin", &rows());
    let freq = FrequencyMap::new();
    let ctx = neutral_ctx(&idx, &dict, &freq, InputMode::Poj);
    assert_eq!(
        hanji_of(&fetch_abbrev_candidates("poj:cp", 2, &ctx)),
        vec!["食飯"]
    );
    assert!(fetch_abbrev_candidates("poj:tp", 2, &ctx).is_empty());
    assert_eq!(
        hanji_of(&fetch_abbrev_candidates("poj:ss", 2, &ctx)),
        vec!["鎖匙"]
    );
}

#[test]
fn tps_family_validates_the_tps_abbreviation_face() {
    // 毋是's abbreviation is ㆬㄒ (syllabic nasal); a literal `tps:ㄇㄒ` key
    // pointing at it is not its face and is rejected — the §35 ambiguity
    // path, not this fetch, is how `ㄇㄒ` reaches 毋是.
    let idx = build_wire_index(
        "abbrev-tps.fst",
        &[("tps:ㄙㄒ", 1), ("tps:ㆬㄒ", 5), ("tps:ㄇㄒ", 5)],
    );
    let dict = open_dict("abbrev-tps.dict.bin", &rows());
    let freq = FrequencyMap::new();
    let ctx = neutral_ctx(&idx, &dict, &freq, InputMode::Tps);
    let sosi = fetch_abbrev_candidates("tps:ㄙㄒ", 6, &ctx);
    assert_eq!(hanji_of(&sosi), vec!["鎖匙"]);
    assert_eq!(sosi[0].consumed_span, (0, 6));
    assert_eq!(
        hanji_of(&fetch_abbrev_candidates("tps:ㆬㄒ", 6, &ctx)),
        vec!["毋是"]
    );
    assert!(fetch_abbrev_candidates("tps:ㄇㄒ", 6, &ctx).is_empty());
}

#[test]
fn pool_is_sorted_and_not_truncated() {
    // 40 rows all abbreviating to `kk`, ascending frequency → the whole pool
    // comes back most-frequent first; the caller truncates AFTER its
    // cross-batch exclude (Step 4c), so nothing may be cut here.
    let rows: Vec<DictRow> = (0..40u32)
        .map(|i| {
            let hanji: &'static str = Box::leak(format!("詞{i}").into_boxed_str());
            (DEFAULT_SOURCE, 100 + i, 2, hanji, "ka-ki")
        })
        .collect();
    let dict = open_dict("abbrev-pool.dict.bin", &rows);
    let entries: Vec<(&str, u32)> = (1..=40).map(|rowid| ("tl:kk", rowid)).collect();
    let idx = build_wire_index("abbrev-pool.fst", &entries);
    let freq = FrequencyMap::new();
    let ctx = neutral_ctx(&idx, &dict, &freq, InputMode::Tl);
    let out = fetch_abbrev_candidates("tl:kk", 2, &ctx);
    assert_eq!(out.len(), 40, "un-truncated pool");
    assert_eq!(out[0].hanji.as_deref(), Some("詞39"), "most frequent first");
    assert_eq!(out[39].hanji.as_deref(), Some("詞0"));
}
