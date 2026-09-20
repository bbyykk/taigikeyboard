# Findings — Remote Taigi Dictionary Candidates

## Initial constraints

- Project rules require authoritative phonetic handling and pair-keyed word
  identity.
- Network calls need HTTPS, minimum permissions, private cache storage, and no
  sensitive logging.
- The user asked for a hotkey-triggered online lookup that adds candidates.

## Research notes

- The current continuous candidate pipeline is engine-authoritative: Android's
  `TaigiAutocompleteService.kt` and the corresponding iOS service wrap Rust
  candidates rather than independently ranking a second list.
- A remote result should therefore enter through an explicit remote-candidate
  merge seam, not through platform-side candidate sorting.
- `docs/CODE_SIGNING_POLICY.md` says mobile builds currently have no network
  permission, while desktop update code already uses HTTPS `URLSession`; this
  feature changes a deliberate product/security boundary.
- The iOS keyboard extension already has `RequestsOpenAccess` in its
  `Info.plist`, but that is not by itself product permission for arbitrary
  remote dictionary traffic; the UX and privacy contract still needs an
  explicit decision.
- The Education Ministry dictionary publishes downloadable text data and audio
  resources on its official related-resources page. The online source adapter
  should prefer an official structured/downloaded source or a stable official
  query contract, not scrape rendered HTML as the long-term protocol.

## Design decisions

- Network lookup is an explicit action, not part of the hot path. This protects
  latency, battery, privacy, and the current offline-first behavior.
- Exact full-buffer remote candidates are the safe first scope because the
  existing continuous commit contract already carries consumed spans; remote
  prefix/sub-string results would need new commit semantics.
- Remote candidates are an additive, labeled source block. Local ranking stays
  authoritative; online data is a retrieval aid, not a replacement dictionary.
- A source adapter boundary is required because the MOE public site exposes
  human-facing query pages and downloadable resources, but no stable API was
  established during this research pass.
- The public Oo Inn / 芋圓 page currently identifies the product as an app and
  links to the iOS and Android stores. Its store description says its content
  is based on the Education Ministry dictionary, but this pass did not find a
  supported public web query/API. Treat it as a source requiring cooperation
  or a documented endpoint; do not reverse-engineer private app traffic.
- A read-only `curl` probe of the public Portaly page found only the product
  page, app-store links, and image assets; guessed `tarodict.com` hosts did not
  resolve. This does not prove that no public web endpoint exists, but it does
  mean the next safe step is endpoint discovery/documentation, not assuming a
  URL or copying app traffic.
- MOE's official resource page directly links `kautian.ods`; the source URL is
  `https://sutian.moe.edu.tw/media/senn/ods/kautian.ods`. This is a better
  first adapter contract than scraping the rendered search pages.

## MOE snapshot design

- Hotkey checks the private snapshot first; it does not download the ODS for
  every query.
- On cache miss or explicit refresh, download the ODS once, verify the HTTPS
  response and size/hash, parse it, normalize TL through the authoritative
  converter, and build a private lookup index.
- Keep the downloaded ODS and derived index outside `dictionary/`; this is
  user cache, not a shipped dictionary artifact.
- Store source URL, fetched time, content hash, parser/schema version, and
  attribution/license metadata beside the cache.

## Additional dictionary sources

- `台日大辭典台語譯本` is available through Kemdict. Its page identifies the
  source as the ChhoeTaigi database and states CC BY-NC-SA 3.0 TW licensing.
  Prefer the public database/source rather than scraping Kemdict result HTML.
- `甘字典` has a public query page at `taigi.fhl.net/dick/`, with output
  choices for POJ/TL numeric or marked tones. The page attributes the work to
  the Academia Sinica / 台語信望愛 collaboration and states CC BY-SA 3.0 TW.
  It also links a public GitHub source, so a snapshot adapter is plausible.
- These two sources are dictionaries with different historical conventions;
  preserve source readings and source labels. Canonical TL conversion happens
  only at the shared candidate boundary, and ambiguous or unconvertible rows
  must remain source-only lookup results rather than entering candidates.

## Online corpus/resource map

- NAER's `臺灣台語語料庫應用檢索系統` is the strongest current match for real
  usage evidence: it supports Hanji/TL search, exact/partial matching,
  segmentation/continuous display, collocation, related words, grammar points,
  textbook lookup, and linked audio/dictionary entries.
- Academia Sinica's `閩客語辭典與文獻語料庫` is a research-oriented source for
  Min/Hakka dictionary and literature evidence, including historical material.
- MOE `kautian.ods`, 台日大辭典, and 甘字典 are dictionary/lexicon sources,
  not interchangeable with a corpus. They are suitable for candidate entries;
  corpus hits are better shown as source evidence or an optional details view.
- ChhoeTaigi / 台語信望愛 provides several public dictionary and historical
  resources; treat each source as a separately licensed adapter.

## Recommended UX contract

- One hotkey opens one online panel, with separate `可用詞` and `用例參考`
  sections.
- Only dictionary entries with a complete current-input span and valid
  `(hanzi, canonical TL)` can be selected and committed.
- Corpus hits are read-only evidence; they may show sentence, collocation,
  related word, grammar note, audio, and source link, but never silently become
  local candidates.

## Query-strategy decision

- The stable cross-source seam is not a shared URL/query syntax. It is
  `LookupContext → SourceAdapter → NormalizedResult`.
- MOE ODS can use a local indexed exact/prefix lookup after download.
- A web dictionary may support Hanji, TL, POJ, or wildcard independently; its
  adapter declares what it accepts and chooses the best bounded fallback.
- Cache keys include the source query form/strategy, because `tsitma`,
  `tsit4ma2`, `tsit-má`, and a wildcard expression are not interchangeable
  requests even when they refer to the same user intent.

## Scope adjustment

- User explicitly deferred iOS, Android, and Windows. The first plan targets
  the existing desktop candidate surface and shared engine only.
- The online list is independent from the current local candidate list. It has
  its own lifecycle: idle → loading → results / empty / stale / error.
