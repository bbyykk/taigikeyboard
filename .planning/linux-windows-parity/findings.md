# Findings

## Current Linux capability

- IBus and Fcitx frontends exist.
- TL, POJ, TPS, shared dictionary lookup, continuous composing, candidates,
  selection, commit, reset, and Backspace are exposed.
- Linux configuration is hard-coded in `engine/linux-ffi/src/lib.rs`.
- Linux has no settings UI, persistent user-frequency integration, custom
  dictionary, source toggles, next-word UI, formal package, or GUI test matrix.
- IBus has a small Python unit-test surface; Fcitx event handling has no direct
  regression-test seam.
- Current development machine uses IBus. Fcitx native compilation is blocked by
  missing development headers.

## Windows reference capability

- Per-context TSF orchestration and candidate UI.
- Persistent settings, user frequency, associations, and custom dictionary.
- General, appearance, shortcuts, custom dictionary, dictionary sources, font
  management, and dictionary-search settings panes.
- Next-word integration, configurable candidate presentation, installer,
  update checks, and release validation.

## Direction

- Stabilize the Linux host contract before adding features.
- Keep platform adapters thin; Linux-only state/storage/configuration belongs in
  Linux crates/modules, while phonetic and ranking behavior continues to come
  from existing shared-engine APIs.
- Implement one frontend-neutral Linux application service through IBus first.
- Fcitx is a low-priority catch-up frontend and does not gate IBus delivery.
