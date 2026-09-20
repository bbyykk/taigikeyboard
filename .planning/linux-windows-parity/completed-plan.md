# Linux Desktop Parity Planning

## Goal

Produce an implementation-ready roadmap that brings the Linux IBus and Fcitx
frontends from basic composition to Windows-level desktop product capability,
without changing behavior on iOS, Android, macOS, or Windows.

## Constraints

- Linux-only implementation scope. Other platforms are behavioral references.
- Shared engine behavior remains unchanged unless the user separately approves a
  cross-platform engine round.
- No release number, release date, or release inclusion is inferred.
- The user expects each Linux fix round to include modify, build, install,
  restart, and live verification.
- IBus is the primary frontend. Fcitx catch-up is low priority and does not
  block IBus rounds.

## Phases

### Phase 1: Inventory

- [x] Record the Linux/Windows capability gap.
- **Status:** complete

### Phase 2: Architecture and sequencing

- [x] Define dependency-ordered Linux workstreams.
- **Status:** complete

### Phase 3: Verification design

- [x] Define per-phase automated and dogfood gates.
- **Status:** complete

### Phase 4: Publish project roadmap

- [x] Add the durable L0–L9 plan to `docs/roadmap.md`.
- **Status:** complete

### Phase 5: Reprioritize frontends

- [x] Make IBus the primary delivery path and move Fcitx to a low-priority
  catch-up round.
- **Status:** complete

## Errors Encountered

| Error | Attempt | Resolution |
|---|---|---|
| Fcitx configure fails because `/usr/include/Fcitx5/Core` is absent | Linux Backspace deployment | IBus was built/installed/restarted; USER moved Fcitx dependency repair to the low-priority L8 catch-up round |
