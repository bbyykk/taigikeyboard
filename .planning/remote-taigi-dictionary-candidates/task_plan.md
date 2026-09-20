# Remote Taigi Dictionary Candidates

## Objective

Design a safe, cross-platform feature that uses an explicit hotkey/action to
query an online Taiwanese dictionary and merge authoritative results into the
current candidate list without changing normal offline input behavior.

## Scope

- Design only in this phase; no product code changes yet.
- First target: the existing desktop candidate surface / shared engine. Defer
  iOS, Android, and Windows entirely for now; do not add platform adapters for
  them in the first slice.
- Dictionary data must remain outside the committed `dictionary/` source tree.

## Phases

- [complete] 1. Map current candidate, action, network, and cache seams.
- [complete] 2. Choose query contract, source policy, and candidate-merge semantics.
- [complete] 3. Design platform hotkey/action adapters and permission behavior.
- [complete] 4. Define cache, privacy, failure, rate-limit, and offline UX.
- [complete] 5. Write implementation slices, tests, and rollout gates.

## Recommended design

1. Explicit action only: `Lookup Online` is a configurable desktop hotkey.
   Never issue a network request from per-keystroke candidate refresh.
2. Independent candidate surface: keep the current local candidate list
   untouched. Show a separate online-results list in the same candidate-area
   family, with its own loading/error/empty state and source label.
3. Network adapter: the first desktop shell owns HTTPS, cancellation, timeout,
   cache, and permission handling. The adapter returns a neutral
   `RemoteDictionaryEntry` DTO; the Rust engine owns canonical TL validation,
   `(hanzi, canonical_tl)` identity, full-span eligibility, dedupe, and merge.
4. MVP query is exact full-buffer lookup. The remote entry must consume the
   current composing buffer completely; longer prefix suggestions and arbitrary
   substring results are not candidates yet.
5. Initial source is the Education Ministry dictionary through a dedicated
   source adapter that downloads the official `kautian.ods` snapshot. Do not
   scrape the search HTML. The official resource page links the ODS directly;
   the runtime imports it into the private online-dictionary cache and queries
   that local snapshot on later hotkeys.
6. Additional sources are `台日大辭典台語譯本` and `甘字典`. Prefer their
   public ChhoeTaigi/Kemdict data or documented query pages over scraping a
   private app. Keep each source's original reading system and provenance
   until the canonical-TL normalization boundary.
7. Cache by `(source, normalized query, input mode, tone policy, schema
   version)`, private to the app, with a bounded size and a short freshness TTL.
   A stale cache may be shown with an `offline/stale` label after a failed
   request.
8. Selection of a remote candidate follows the normal commit path and records
   its pair identity in user frequency. Fetching alone never teaches the ranker.

## Final source-role design

- One hotkey opens one independent Online panel; it does not mutate the local
  candidate list.
- `dictionary` sources (MOE, 台日, 甘) may emit selectable full-span
  candidates.
- `corpus` sources (NAER, Academia Sinica) emit usage evidence: examples,
  collocations, related words, grammar notes, and audio/source links. They do
  not enter the commit candidate list automatically.
- The panel has two subsections when available: `可用詞` and `用例參考`.
- A dictionary result selected from `可用詞` commits through the normal path;
  a corpus example is read-only and opens its source/details view.
- Each source has an independent adapter and cache namespace. Results carry
  `source_id`, attribution URL, license metadata, and source-native reading;
  only selectable entries pass canonical-TL validation.

## Source-specific query design

- Do not force every site through one query string or one search protocol.
- Every source declares capabilities and owns a query strategy. Shared code
  owns only the input context, cancellation, cache envelope, and normalized
  result contract.
- Input context may carry raw input plus authoritative renderings available
  from the converter: Hanji (if present), TL numeric, TL marked, POJ, and
  tone-less form. An adapter chooses only forms its source supports.
- A strategy may try a bounded fallback sequence, such as exact TL → exact
  Hanji → source-supported wildcard/prefix. No unbounded query expansion.
- A source may expose a small source-specific control (exact / prefix /
  wildcard), while the default hotkey path remains predictable per source.
- A source that cannot produce trustworthy canonical TL remains reference-only;
  it cannot become a commit candidate.

## Neutral result shape

```text
OnlineLookupResult {
  source_id,
  query,
  selectable_entries[],
  evidence_items[],
  fetched_at,
  stale,
}
```

## Capability contract

```text
SourceCapabilities {
  accepts_hanzi,
  accepts_tl_numeric,
  accepts_tl_marked,
  accepts_poj,
  accepts_toneless,
  supports_exact,
  supports_prefix,
  supports_wildcard,
  supports_examples,
}
```

## Implementation slices

- Slice A: proto/domain DTO and Rust merge/dedupe contract; engine-only tests.
- Slice B: first desktop hotkey/action, network adapter, permission copy,
  cache, and cancellation.
- Slice C: independent online candidate surface and selection metadata.
- Slice D: MOE, 台日大辭典, and 甘字典 adapter contract tests; record source
  licenses and attribution in the configuration/cache metadata.
- Slice E: fixture replay, dogfood, privacy, rate-limit, and source-license
  review. No dictionary source/artifact edits.

## Decisions to preserve

- The feature is explicit user action, never an automatic network lookup on
  every keystroke.
- Online results are labeled as remote and must not silently replace local
  candidates.
- Word identity is `(漢字, canonical TL)`; POJ/TPS are renderings, not keys.

## Errors encountered

| Error | Attempt | Resolution |
|---|---:|---|
| None | 0 | — |
