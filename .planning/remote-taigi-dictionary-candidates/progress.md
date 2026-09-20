# Progress — Remote Taigi Dictionary Candidates

## Session log

- Started design phase; created persistent planning files.
- Mapped the candidate seam, current network policy, and official MOE resource
  surface. No product source files changed.
- Completed the design: explicit action, exact full-span query, labeled remote
  candidate block, platform-owned HTTPS/cache, Rust-owned identity/merge, and
  staged cross-platform implementation slices.
- User narrowed scope: defer iOS, Android, and Windows; keep local candidates
  untouched; add a separate online candidate surface; configure sources and
  cache results; start with MOE and investigate Oo Inn's supported interface.
- Confirmed the MOE resource page exposes the official `kautian.ods` download;
  changed the first-source plan from web-query scraping to snapshot download +
  private local index.
- User selected the next source set: 台日大辭典台語譯本 and 甘字典. Confirmed
  public Kemdict/ChhoeTaigi and 甘字典 query/source surfaces; replaced Oo Inn
  in the plan.
- Confirmed that `curl`/`wget` can inspect public web interfaces; the current
  芋圓 Portaly page exposes the app landing page, not a dictionary query form
  or documented endpoint. Keep 芋圓 as an optional adapter pending a public
  query contract.
- No product source files changed.
- Researched major online resources: NAER Taiwan Taigi Corpus, Academia Sinica
  Min/Hakka Dictionary and Literature Corpus, MOE dictionary, and
  ChhoeTaigi/台語信望愛 resources. Classified corpus evidence separately from
  candidate dictionaries.
- Finalized the source-role design: one online panel with selectable dictionary
  entries plus read-only corpus evidence; local candidate ranking remains
  untouched.
- Refined the architecture for heterogeneous sites: shared normalized result
  contract, source-declared capabilities, bounded source-specific strategies,
  and strategy-aware cache keys; no forced universal query syntax.
