# Taigi Keyboard for Linux

This is the Linux desktop front end for the shared Rust engine. It provides an
Fcitx 5 addon and an IBus engine, covering Ubuntu GNOME as well as other X11
and Wayland desktops.

## Build and install

From the repository root:

```sh
cargo build --manifest-path engine/Cargo.toml -p linux-ffi --release
cmake -S linux -B build/linux -DCMAKE_BUILD_TYPE=Release
cmake --build build/linux -j
sudo cmake --install build/linux
```

For Fcitx, restart Fcitx 5, open `fcitx5-config-qt`, add **Taigi Keyboard**,
and switch to it with the normal Fcitx shortcut. For Ubuntu GNOME, select IBus
as the input framework, restart the session if necessary, and add **Taigi
Keyboard** in the system input-source settings. Type romanization;
Space selects the first candidate, number keys or a mouse click select a
candidate, Enter commits the current preedit, Backspace edits it, and Escape
cancels it. `Ctrl+Shift+1`, `Ctrl+Shift+2`, and `Ctrl+Shift+3` select TL, POJ,
and TPS respectively.
In the IBus engine, tap Shift on its own (under 500 ms, with no other key in
between) to switch between Taigi and English input; holding Shift for a capital
letter does not switch modes. Caps Lock remains the desktop's letter-case
control.
While the candidate list is visible, `q w d f z x v y ;` select candidates 1–9;
numeric keys remain available for TL/POJ tone input.
Press `Ctrl+Shift+D` while composing to open a separate online lookup list for
the current preedit. The prototype searches the 台日大辭典台語譯本 through
Kemdict; Escape restores the local candidate list, and selecting a remote row
commits its Hanji form. The network request is intentionally hotkey-triggered,
not performed on every keystroke.

Online sources are configured at
`~/.config/taigi-keyboard/online-dictionaries.json` (or
`$XDG_CONFIG_HOME/taigi-keyboard/online-dictionaries.json`). If the file does
not exist, the built-in 台日 source is used. The cache is kept under
`~/.cache/taigi-keyboard/online-dictionary.json`.

The package currently installs the bundled dictionary artifacts and the
`dictionary/LICENSE` file must accompany any redistribution. The repository's
merged dictionary is non-commercial because its source licenses are mixed.

## Scope of this first Linux port

Both native input paths support normal composition, candidate selection, and
TL/POJ/TPS switching. Settings UI, user-frequency learning, and continuous
next-word prediction are planned follow-ups; the Rust engine already contains
most of the reusable logic for those features.
