//! The 一般 pane, four groups: input script + tone keys; output script +
//! auto-space; the candidate window's two switches; display language + the
//! update row. Then the reset card and the attribution footer. Port of
//! `GeneralSettingsView.swift`.

use super::{choice_row, reset_row};
use crate::presentation::{display_language_label, SPONSOR_URL};
use crate::updates::INSTALLED_VERSION;
use crate::winui::cards;
use crate::winui::window::{Message, ResetScope, SettingsWindow, SettingsWrite};
use taigi_windows_core::keys::ToneInputScheme;
use taigi_windows_core::settings::{keys, InputMode, SettingChoice};
use taigi_windows_core::strings::{DisplayLanguage, StringKey, StringResolver};
use taigi_windows_update::checker;
use windows_reactor::*;

/// The spinner beside the 檢查更新 button.
const SPINNER_SIZE: f64 = 20.0;
/// Above the footer, so it sits off the last card.
const FOOTER_TOP_MARGIN: f64 = 24.0;
/// The footer's own line spacing.
const FOOTER_SPACING: f64 = 4.0;
/// The fine print's weight, as opacity — `PrimaryText` at less than full
/// is WinUI's secondary text, and it follows the theme.
const FOOTER_OPACITY: f64 = 0.65;

pub fn view(
    window: &SettingsWindow,
    strings: &StringResolver,
    context: &mut ViewContext<SettingsWindow>,
) -> View {
    let document = window.document();
    // Four groups in the order a keystroke travels (USER 2026-09-18 「排序
    // 「一般」設定，讓邏輯合理一點」): what is typed, what reaches the
    // document, the window in between, then the app itself. Gaps, no
    // titles — like 外觀; the order carries the logic
    // (`GeneralSettingsView.swift`).
    View::fragment((
        // A pop-up like the row under it, not a radio group (System
        // Settings' shape for a small mutually-exclusive choice). 輸入文字 /
        // 輸出文字 name the pair (USER 2026-09-18); mobile keeps 輸入模式,
        // whose picker also holds TPS.
        choice_row(
            strings.resolve(StringKey::SettingsInputScript),
            InputMode::ALL,
            document.choice(&keys::INPUT_MODE),
            true,
            |mode: InputMode| strings.resolve(mode.label_key()).to_owned(),
            |mode| Message::set_choice(mode, &keys::INPUT_MODE),
            context,
        ),
        // Directly under the romanization it belongs to: which keys type a
        // tone is a fact about how the syllable is spelled, not a shortcut
        // (USER 2026-09-08), and the slot keys follow from it rather than
        // being chosen on the shortcut pane (`GeneralSettingsView.swift`).
        choice_row(
            strings.resolve(StringKey::SettingsToneInputScheme),
            ToneInputScheme::ALL,
            document.choice(&keys::TONE_INPUT_SCHEME),
            true,
            |scheme: ToneInputScheme| strings.resolve(scheme.label_key()).to_owned(),
            |scheme| Message::set_choice(scheme, &keys::TONE_INPUT_SCHEME),
            context,
        ),
        // What reaches the document.
        cards::section_gap(),
        // Which script a commit writes (USER 2026-09-18): the same stored
        // swap the backtick shortcut toggles, so the two never disagree.
        // Disabled exactly where the shortcut is inert — 候選詞顯示 = 羅馬字
        // shows no Hanji to lead with (`allows_swap_toggle`); under 漢羅濫
        // both scripts are on screen and this only picks the punctuation
        // width, as the shortcut does there. A cleared pop-up writes nothing,
        // the rule `Message::set_choice` states for every other picker.
        choice_row(
            strings.resolve(StringKey::SettingsOutputScript),
            OUTPUT_SCRIPTS,
            document.bool(&keys::IS_TRANSLATE_SWAPPED),
            document
                .choice(&keys::CANDIDATE_DISPLAY_MODE)
                .allows_swap_toggle(),
            |is_hanji: bool| strings.resolve(output_script_label(is_hanji)).to_owned(),
            |is_hanji| match is_hanji {
                Some(is_hanji) => Message::SetSwitch(keys::IS_TRANSLATE_SWAPPED, is_hanji),
                None => Message::SetChoice(None),
            },
            context,
        ),
        cards::switch_row(
            strings.resolve(StringKey::SettingsAutoSpace),
            document.bool(&keys::IS_AUTO_SPACE_ENABLED),
            true,
            context.callback(|is_on| Message::SetSwitch(keys::IS_AUTO_SPACE_ENABLED, is_on)),
        ),
        // The candidate window.
        cards::section_gap(),
        // S33 (USER 2026-09-08): off means no window at all — the user types
        // romanization and Space / Enter write it as typed. Directly above
        // 顯示當咧拍的字, which describes the window's content and so reads
        // as its sub-option; that row stays enabled with the window off (one
        // plain switch, no greyed-out state to explain).
        cards::switch_row(
            strings.resolve(StringKey::SettingsCandidateWindow),
            document.bool(&keys::IS_CANDIDATE_WINDOW_ENABLED),
            true,
            context.callback(|is_on| Message::SetSwitch(keys::IS_CANDIDATE_WINDOW_ENABLED, is_on)),
        ),
        // §34/S22. On means candidate slot 0 is the preedit literal, so
        // Enter writes the typed romanization.
        cards::switch_row(
            strings.resolve(StringKey::SettingsLiteralRomanCandidate),
            document.bool(&keys::IS_LITERAL_ROMAN_CANDIDATE_ENABLED),
            true,
            context.callback(|is_on| {
                Message::SetSwitch(keys::IS_LITERAL_ROMAN_CANDIDATE_ENABLED, is_on)
            }),
        ),
        // The app itself: its language, then its version.
        cards::section_gap(),
        choice_row(
            strings.resolve(StringKey::SettingsDisplayLanguage),
            &DisplayLanguage::PICKER,
            DisplayLanguage::from_tag(&document.string(&keys::DISPLAY_LANGUAGE)),
            true,
            |language: DisplayLanguage| display_language_label(language, strings),
            |language| Message::SetChoice(language.map(SettingsWrite::display_language)),
            context,
        ),
        update_row(window, strings, context),
        // Not on the update row: it holds no setting of the user's to
        // restore.
        reset_row(strings, ResetScope::General, context),
        footer(strings, context),
    ))
}

/// The 輸出 pop-up's roster: the stored swap as the two scripts it picks
/// between, Hanji (the default) first.
const OUTPUT_SCRIPTS: &[bool] = &[true, false];

fn output_script_label(is_hanji: bool) -> StringKey {
    if is_hanji {
        StringKey::SettingsOutputScriptHanji
    } else {
        StringKey::SettingsOutputScriptRoman
    }
}

/// One row, never two (`GeneralSettingsView.swift:89-117`): a known update
/// replaces the version-and-check row rather than sitting under it, and its
/// trailing control is whatever the user's next move is; the note appears
/// only when something went wrong.
fn update_row(
    window: &SettingsWindow,
    strings: &StringResolver,
    context: &mut ViewContext<SettingsWindow>,
) -> View {
    let updates = window.updates();
    let Some(manifest) = checker::pending_update(window.document(), INSTALLED_VERSION) else {
        let label = strings.format(
            StringKey::DesktopUpdateCurrentVersionLabel,
            &[&INSTALLED_VERSION],
        );
        let is_checking = updates.is_checking();
        return cards::row(
            &label,
            StackPanel::new()
                .orientation(Orientation::Horizontal)
                .spacing(cards::CARD_SPACING)
                .children((
                    Button::new()
                        .is_enabled(!is_checking)
                        .on_click(context.callback(|()| Message::CheckForUpdates))
                        .content(strings.resolve(StringKey::DesktopUpdateCheckNow)),
                    if is_checking {
                        spinner()
                    } else {
                        View::empty()
                    },
                )),
        );
    };
    let offer = updates.installation.offer(&manifest);
    let label = strings.format(
        StringKey::DesktopUpdatePendingVersionLabel,
        &[&manifest.version],
    );
    let control = match offer.action_key() {
        Some(key) => Button::new()
            .on_click(context.callback(|()| Message::ActOnOffer))
            .content(strings.resolve(key)),
        None => spinner(),
    };
    let note = match offer.note_key() {
        Some(key) => TextBlock::new()
            .text(strings.resolve(key))
            .text_wrapping(TextWrapping::Wrap)
            .opacity(FOOTER_OPACITY)
            .into(),
        None => View::empty(),
    };
    View::fragment((cards::row(&label, control), note))
}

fn spinner() -> View {
    ProgressRing::new()
        .is_active(true)
        .width(SPINNER_SIZE)
        .height(SPINNER_SIZE)
        .into()
}

/// Centred at the foot of the pane rather than inside the form: it is
/// neither a setting nor a note about one (`sponsorFooter`).
fn footer(strings: &StringResolver, context: &mut ViewContext<SettingsWindow>) -> View {
    StackPanel::new()
        .orientation(Orientation::Horizontal)
        .spacing(FOOTER_SPACING)
        .horizontal_alignment(HorizontalAlignment::Center)
        .margin(Thickness::new(0.0, FOOTER_TOP_MARGIN, 0.0, 0.0))
        .children((
            TextBlock::new()
                .text(strings.resolve(StringKey::DesktopCopyrightLine))
                .vertical_alignment(VerticalAlignment::Center)
                .opacity(FOOTER_OPACITY),
            TextBlock::new()
                .text("\u{00B7}")
                .vertical_alignment(VerticalAlignment::Center)
                .opacity(FOOTER_OPACITY),
            // Our own open, not the control's `navigate_uri`: a browser
            // that refuses must be reported, never swallowed
            // (`ExternalLinkButton.swift:740-744`).
            HyperlinkButton::new()
                .on_click(context.callback(|()| Message::OpenUrl(SPONSOR_URL.to_owned())))
                .content(strings.resolve(StringKey::DesktopSponsorLink)),
        ))
}
