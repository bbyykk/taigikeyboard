# Partial-tone input drops the typed tone (`teng5-sek` → wrong-tone candidates lead)

Status: **investigation only, nothing decided**. No round is open; no release scope is implied.
Root cause confirmed against production artifacts; the fix direction at the end is a proposal
awaiting USER approval.

## Symptom (USER report, 2026-09-14)

> 根據排序演算法，當我輸入 teng5-sek，為什麼 teng-sek 這個詞排第一個位置？têng-sek 反而排到第三

First keystroke sequence of a fresh session (no user frequency, no recency), reported on
**all four platforms** (Android / iOS / Windows / macOS).

## Reproduction

Dev harness `engine/composing/tests/candidate_dump.rs` against the production artifacts in
`dictionaries/` (real `Start → EnterContinuous → FetchAtPos` pipeline, zero user frequency):

```sh
# device default source toggles (see mask derivation below)
DUMP_INPUTS="teng5-sek,teng5sek4" DUMP_MODE=poj DUMP_BITMASK=67104195 \
  cargo test -p composing --test candidate_dump -- --ignored --nocapture
```

| input | candidates (leading slots) |
|---|---|
| `teng5-sek` | `[0] têng-sek` (roman-only) · `[1] 等式 téng-sek` · `[2] 中式 teng-sek` · `[3] 程式 têng-sek` |
| `teng5sek4` | `[0] teng5sek4` (roman-only) · `[1] 程式 têng-sek` — every other tone gone |

Four different tones compete for the toneless reading, and the tone-5 word the user actually
typed lands third. Typing the tone on **both** syllables fixes it outright — which isolates the
defect to tone handling, not to ranking or to dictionary frequency.

`DUMP_BITMASK=67104195` mirrors the shipped defaults (`android/.../ime/core/PrefHelper.kt`,
mirrored on the other platforms): sources `kautian` + `taigitv` + `kungge` + `stti` + `khpoo` +
`dev` + `lkk` on; `itaigi` / `sitbut` / `taihoa` / `taijit` / `khiin` / `variant` off; all kautian
subcollections on. Encoding per `engine/lexicon/src/dictionary_filters.rs::dictionary_filter_bitmask`.

**Source toggles are irrelevant to the defect** (USER 2026-09-14: 「我覺得跟台日大辭典沒有關係」).
With every source enabled the list is longer — `橙色 / 中式 / 等式 / 頂色 / 程式` — but the tone is
dropped identically. The toggles change only which rows survive the filter, never whether the
typed tone is honored.

## Mechanism

`engine/composing/src/shadow.rs:182` `fst_body_for_span` is all-or-nothing:

```rust
InputMode::Tl | InputMode::Poj if span_is_fully_toned_ascii(span) => span.to_string(), // poj:<poj_num>
_ => strip_tones_for_mode(span, mode),                                                 // whole-span strip
```

1. `dictionary/build/create_fst.py` emits exactly **two** key families per record — `poj:<poj_notone>`
   (`poj:tengsek`) and `poj:<poj_num>` (`poj:teng5sek4`). There is no key that can express
   "syllable 1 is tone 5, syllable 2 is any tone", so a partial-tone span has no family of its own.
2. `span_is_fully_toned_ascii` (`shadow.rs:81`) requires the `([a-z]+digit)+` grammar — every
   syllable group closed by an ASCII tone digit. `teng5sek` ends on a letter, so it returns `false`.
   Note POJ writes the tone-4 stop coda as `sek4`: `sek` *looks* complete but leaves its group open.
3. The `false` branch therefore takes the toneless key — and building that key strips **all** tone
   digits from the whole span, because `poj:teng5sek` exists in no index (a verbatim lookup would
   return zero candidates). The typed `5` is discarded at the lookup layer.
4. Nothing downstream reads the typed tone back. The toneless key legitimately returns every tone;
   the missing step is a post-lookup filter that re-applies the tones the user did type.

This is the documented §17 behaviour, not a regression: `docs/architecture/behavioral-invariants.md`
§17 case 3 states a *mixed / partial-tone* span "has no fully-toned FST family, so it stays on the
toneless key (no regression)". PR #367 closed the fully-toned case (`tai5` must not surface
`tai2`/`tai3`) and deliberately scoped out the middle state; §17 has no clause requiring the typed
tones of a partial-tone span to filter anything.

TPS already has the missing half at the candidate layer: A3 (§41) keeps the toneless lookup but
filters readings via `lexicon::continuous::reading_passes_space_pin` when the span closes on the
keyboard's space. TL / POJ have no equivalent.

## Ranking is not the cause

With the typed tone gone, the survivors are ordered by the Phase 9.1 lexicographic `SortKey`
(`engine/lexicon/src/continuous.rs:1851`): `coverage_kind → tier → recency_rank → neg_score →
neg_freq → neg_coverage → source_rank → stable_idx`, where `score = freq × syll_bias × user_boost`
(`engine/ranking/src/score.rs::calculate_continuous_score`). Tone is not a dimension, and cannot be
one — by the time the candidates exist the tone has already been stripped from the key.

`程式 / tîng-sik` carries `frequency = 1` in `dictionary/output/dictionary.csv` while `中式` /
`等式` / `橙色` / `頂色` all carry 25. That is a separate data smell, **not** the blocker: under the
shipped default toggles a working tone filter leaves `程式` as the only tone-5 survivor, so it leads
regardless of its low frequency (proven by the `teng5sek4` row above). The frequency only matters if
the user enables 台日大辭典, where `橙色` (25) would outrank `程式` (1) within tone 5.

## Scope — all four platforms, single engine path

Every platform reaches this through the same `fetch_at_pos` entry; §17 records "Engine is the single
source — iOS / Android inherit via FFI; there is no platform-side tone filtering":

- `ios/Sources/TaigiKeyboard/Engine/RustEngineBridge+Composing.swift`
- `android/app/src/main/java/com/siansiansu/taigikeyboard/engine/ComposingBridge.kt`
- `macos/Sources/TaigiInputMethodCore/Engine/RustEngineBridge+Composing.swift`
- `windows/crates/taigi-windows-core/src/composing/manager.rs`

One engine-side fix covers all four; no per-platform port, and no platform can work around it.

**Dictionary-search tab (Tab3) behaves differently.** `lexicon::search` builds its key through
`key_normalizer::build` → `phonetics::normalize_input`, which **keeps** the tone digits, then runs
exact + prefix lookup (`engine/lexicon/src/search.rs:109-112`). `poj:teng5sek` is a byte prefix of
`poj:teng5sek4`, so the search tab honors the partial tone that the keyboard candidate strip drops.
Same input, two different answers.

## Proposed fix direction (not approved)

Keep the toneless lookup — the no-tone "show all tones" affordance is the feature (§17 case 2) — and
add the missing post-lookup filter: for a partial-tone TL/POJ span, pin each syllable the user *did*
tone and drop readings that disagree, leaving un-toned syllables unconstrained. This is the TL/POJ
analogue of TPS's `reading_passes_space_pin`, applied in
`lexicon::continuous::exact_candidates_for_key`.

Deliberately **not** at the syllabifier: per `.claude/rules/taigi-incidents.md` the fix-location rule
puts display-side candidate restrictions in the span-local key builder / candidate layer, never in
`syllabifier::valid_span_endings` (that primitive's last change reintroduced the
`span_min_syllable_count("tania")` regression).

Work the proposal implies, for costing when a round opens:

- candidate-layer per-syllable tone pin for TL / POJ (mode-aware; English has no tone semantics)
- the same pin on the walker slot-0 synth path, or slot 0 re-surfaces a wrong-tone word
  (`engine/composing/src/continuous.rs` Step 4) and on the partial-prefix path
- fixture rule: any new syllabifier / continuous-fetch / golden fixture for `teng5sek` must also
  carry every production syllable that is a strict prefix of it and assert presence/absence
- §17 case 3 in `behavioral-invariants.md` rewritten from "stays toneless (no regression)" to the
  partial-pin contract, plus a dogfood `Sn` item
- optional and independent: revisit `程式 / tîng-sik` `frequency = 1` in the dictionary pipeline
