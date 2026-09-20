# Taigi Keyboard Linux/Ubuntu Port

## Purpose

This document records the work completed to make the Taigi Keyboard usable on
current Ubuntu Linux desktops. The implementation reuses the upstream Taigi
Keyboard Rust engine and adds a native Fcitx 5 desktop front end.

## Starting point

The upstream project supports iOS, Android, macOS, and Windows. Its core input
logic is shared in Rust and contains:

- Taiwanese romanization and tone processing
- TL, POJ, and TPS handling
- Composition state management
- Dictionary lookup and candidate ranking
- FST/mmap dictionary loading
- Next-word prediction and learning infrastructure

The missing piece was a Linux desktop integration layer. Ubuntu desktop input
methods are normally provided through IBus or Fcitx. Fcitx 5 was implemented
first because it supports both X11 and Wayland and exposes a native
shared-library addon API. A second IBus adapter was then added for Ubuntu GNOME
and IBus-native deployments.

## Work completed

### Shared Rust Linux interface

Added [`engine/linux-ffi/src/lib.rs`](../engine/linux-ffi/src/lib.rs), a small
C-compatible dynamic library around the existing Rust engine.

It provides:

- Dictionary initialization from an installed dictionary directory
- Composition commands: append, backspace, reset, and commit
- Candidate fetching through the existing continuous-input engine
- Candidate selection by index
- TL, POJ, and TPS mode switching
- A simple UTF-8 response protocol for the C++ Fcitx addon

The interface deliberately keeps protobuf and Rust implementation details out
of the Fcitx code. The addon sends commands such as `append=t` and receives
preedit, candidate, and commit records.

### Fcitx 5 addon

Added [`linux/taigi.cpp`](../linux/taigi.cpp).

The addon:

- Registers “Taigi Keyboard” with Fcitx 5
- Displays the current preedit
- Displays ranked candidates
- Supports candidate selection by mouse click
- Supports candidate selection by number keys
- Commits the first candidate with Space
- Commits the current preedit with Enter
- Handles Backspace and Escape
- Avoids intercepting Ctrl, Alt, and Super shortcuts
- Supports mode switching with `Ctrl+Shift+1/2/3`

### IBus engine

Added [`ibus/ibus-taigi`](../ibus/ibus-taigi) and its component descriptor
[`ibus/taigi.xml`](../ibus/taigi.xml).

The IBus adapter uses Python GObject bindings for the desktop protocol and
`ctypes` for the existing Rust Linux FFI library. It provides the same
composition, candidate, commit, and mode-switch behavior as the Fcitx path,
without duplicating the Taigi engine.

It also handles IBus's `--xml` discovery request so the engine can be indexed
by `ibus write-cache` and shown to desktop input-source selectors.

### Build and installation support

Added [`linux/CMakeLists.txt`](../linux/CMakeLists.txt), which installs:

- The Fcitx addon shared library
- The Rust Linux engine library
- Fcitx addon and input-method metadata
- The compiled dictionary artifacts
- The dictionary license information

Added [`linux/README.md`](../linux/README.md) with build, installation, and
usage instructions.

Added Make targets:

```sh
make linux-build
make linux-install
```

The root README now links to the Linux documentation.

## Packages installed for development

The Ubuntu machine was missing the native build dependencies, so these were
installed:

- `cargo`
- `rustc`
- `cmake`
- `protobuf-compiler`
- `fcitx5`
- `fcitx5-config-qt`
- Fcitx 5 core, config, utility, GTK, and Qt development packages

IBus and its Python GObject bindings are installed for the IBus path (`ibus`,
`python3-gi`, and `gir1.2-ibus-1.0`).

The tested system is Ubuntu 26.04 LTS, GNOME, Wayland, x86-64.

## Installed files

The implementation was installed under the standard system prefix:

```text
/usr/lib/x86_64-linux-gnu/fcitx5/libtaigi.so
/usr/lib/x86_64-linux-gnu/taigi-keyboard/liblinux_ffi.so
/usr/share/fcitx5/addon/taigi.conf
/usr/share/fcitx5/inputmethod/taigi.conf
/usr/share/taigi-keyboard/dictionaries/
/usr/share/doc/taigi-keyboard/LICENSE
```

## User operation

Open the Fcitx configuration tool:

```sh
fcitx5-config-qt
```

Add **Taigi Keyboard** to the active input-method group. Normal controls are:

| Input | Action |
|---|---|
| Letters and punctuation | Extend composition |
| Space | Select the first candidate |
| Number keys | Select a visible candidate |
| PageUp / PageDown | Previous / next candidate page |
| `[` / `]` | Previous / next candidate page |
| Candidate click | Select the clicked candidate |
| Enter | Commit current preedit |
| Backspace | Delete the previous composing character |
| Escape | Cancel composition |
| Ctrl+Shift+1 | TL mode |
| Ctrl+Shift+2 | POJ mode |
| Ctrl+Shift+3 | TPS mode |

Ubuntu GNOME can use the installed IBus engine directly. Users choosing Fcitx
must select Fcitx as the desktop input-method framework; users staying with the
Ubuntu default can select the IBus engine named “Taigi Keyboard”.

## Validation performed

### Rust engine

The Linux-specific smoke test passed:

```sh
cargo test --manifest-path engine/Cargo.toml -p linux-ffi
```

The test initializes the dictionary, appends a composing character, and
confirms that preedit and candidate output are produced.

### Native addon

The Fcitx addon compiled successfully:

```sh
cmake --build build/linux-system -j2
```

Fcitx diagnostics found the installed addon, and a test profile selecting
`taigi` showed that Fcitx loaded it successfully on the Ubuntu Wayland
session.

### Upstream test caveat

A broader upstream composing test suite contains one existing dictionary-data
drift failure: the hard-coded corpus frequency total differs from the current
dictionary CSV total. The Linux-specific test and build paths pass; this drift
should be corrected separately in the upstream engine data/constants.

## Deliberate scope of this first port

The first Linux release focuses on the complete interactive composition path.
The following upstream capabilities are not yet exposed through Linux UI:

- Settings window and persistent mode/configuration editor
- Persistent user-frequency database integration
- Next-word prediction UI
- Full dictionary-source toggle UI
- Packaged `.deb` or Ubuntu PPA distribution
- Automated GUI tests under both GNOME Wayland and X11

These are follow-up features, not blockers for basic Taigi input through
Fcitx 5.

## Recommended next steps

1. Add a real Fcitx configuration schema for mode, tone, display, and
   dictionary settings.
2. Move user frequency and custom dictionary storage into an XDG-compliant
   Linux data directory.
3. Add next-word candidate handling using the existing Rust `nextword` crate.
4. Build a Debian package that separates Apache-licensed code from the
   separately licensed merged dictionary data.
5. Add automated tests using a small GTK or Qt text client under X11 and
   Wayland.
