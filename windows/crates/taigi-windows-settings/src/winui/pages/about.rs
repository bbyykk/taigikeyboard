//! The 關於 page: the app's name and version, and where to find the
//! project. Port of `AboutPage.swift`.
//!
//! What the tray menu's 關於 row opens (USER 2026-09-20): the name and
//! installed version, the community links as bare glyphs, and the
//! attribution line that used to foot the 一般 pane. No app icon and no
//! introduction text, by request; no cards either, because nothing here is
//! a setting — text in cards would read as controls that do nothing.

use crate::presentation::{DISCORD_URL, EMAIL_URL, GITHUB_URL, SPONSOR_URL};
use crate::updates::INSTALLED_VERSION;
use crate::winui::font_awesome::FontAwesomeGlyph;
use crate::winui::window::{Message, SettingsWindow};
use taigi_windows_core::strings::{StringKey, StringResolver};
use windows_reactor::*;

/// `SubtitleTextBlockStyle`'s size: the name is a heading under the
/// window's own title, not a second title.
const NAME_FONT_SIZE: f64 = 20.0;
/// `CaptionTextBlockStyle`'s size, the attribution's fine print.
const CAPTION_FONT_SIZE: f64 = 12.0;
/// Between the title block, the links and the attribution line
/// (`Metrics.sectionSpacing`).
const SECTION_SPACING: f64 = 20.0;
/// Within a block: name over version; the attribution's phrase spacing
/// (`Metrics.lineSpacing`).
const LINE_SPACING: f64 = 4.0;
/// The glyphs' height, the caption's cap height (`Metrics.glyphHeight`).
const GLYPH_HEIGHT: f64 = 11.0;
/// The fine print's weight, as opacity — `PrimaryText` at less than full
/// is WinUI's secondary text, and it follows the theme.
const SECONDARY_OPACITY: f64 = 0.65;

pub fn view(
    _window: &SettingsWindow,
    strings: &StringResolver,
    context: &mut ViewContext<SettingsWindow>,
) -> View {
    let name_block = StackPanel::new().spacing(LINE_SPACING).children((
        TextBlock::new()
            .text(strings.resolve(StringKey::HomeAppHeaderTitle))
            .font_size(NAME_FONT_SIZE)
            .font_weight(FontWeight::SEMI_BOLD),
        TextBlock::new()
            .text(strings.format(
                StringKey::DesktopUpdateCurrentVersionLabel,
                &[&INSTALLED_VERSION],
            ))
            .opacity(SECONDARY_OPACITY),
    ));
    // The three community links as marks: a brand mark names itself, and
    // three words more would crowd the line. No spacing of the stack's own:
    // each button already carries `ButtonPadding` (11 a side) that this
    // pinned `windows-reactor` exposes no way to shrink.
    let glyph_links = StackPanel::new()
        .orientation(Orientation::Horizontal)
        .children((
            glyph_link(
                strings,
                context,
                FontAwesomeGlyph::Github,
                StringKey::DesktopGithubLink,
                GITHUB_URL,
            ),
            glyph_link(
                strings,
                context,
                FontAwesomeGlyph::Discord,
                StringKey::DesktopDiscordLink,
                DISCORD_URL,
            ),
            glyph_link(
                strings,
                context,
                FontAwesomeGlyph::Envelope,
                StringKey::DesktopEmailLink,
                EMAIL_URL,
            ),
        ));
    // Small, grey, the link no louder than the text around it — the project
    // site's own footer.
    let attribution = StackPanel::new()
        .orientation(Orientation::Horizontal)
        .spacing(LINE_SPACING)
        .children((
            TextBlock::new()
                .text(strings.resolve(StringKey::DesktopCopyrightLine))
                .font_size(CAPTION_FONT_SIZE)
                .vertical_alignment(VerticalAlignment::Center)
                .opacity(SECONDARY_OPACITY),
            // Punctuation between two pieces, with nothing to say on its own.
            TextBlock::new()
                .text("\u{00B7}")
                .font_size(CAPTION_FONT_SIZE)
                .vertical_alignment(VerticalAlignment::Center)
                .opacity(SECONDARY_OPACITY),
            // Our own open, not the control's `navigate_uri`: a browser
            // that refuses must be reported, never swallowed
            // (`ExternalLinkButton.swift`).
            HyperlinkButton::new()
                .on_click(context.callback(|()| Message::OpenUrl(SPONSOR_URL.to_owned())))
                .content(strings.resolve(StringKey::DesktopSponsorLink)),
        ));
    StackPanel::new()
        .spacing(SECTION_SPACING)
        .children((name_block, glyph_links, attribution))
}

/// A link that shows a glyph: the title becomes the tooltip and the
/// automation name, so the mark alone carries the line and the words are
/// still there for whoever hovers or listens (`Style.footerGlyph`).
///
/// A subtle `Button` rather than the `HyperlinkButton` beside it: a
/// hyperlink paints its content accent, and three accent brand marks would
/// out-shout the one call to action on the page. Subtle draws the glyph in
/// the text colour — at the fine print's opacity, the same grey — and lifts
/// a rounded fill under the pointer, the hover cue the Mac gives with a
/// colour change.
fn glyph_link(
    strings: &StringResolver,
    context: &mut ViewContext<SettingsWindow>,
    glyph: FontAwesomeGlyph,
    title: StringKey,
    url: &'static str,
) -> View {
    let title = strings.resolve(title);
    Button::new()
        .style(ButtonStyle::Subtle)
        .on_click(context.callback(move |()| Message::OpenUrl(url.to_owned())))
        .automation_name(title)
        .opacity(SECONDARY_OPACITY)
        // A `Viewbox` rather than a height on the icon: `PathIcon` draws its
        // geometry at the geometry's own size, and a smaller frame would only
        // clip it.
        .content(
            Viewbox::new()
                .height(GLYPH_HEIGHT)
                .stretch(Stretch::Uniform)
                .slot(ViewboxSlot::Child, glyph.icon()),
        )
        .tooltip(title)
}
