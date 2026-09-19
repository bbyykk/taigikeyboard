//! The 關於 page: what the project is and where to find it. Port of
//! `AboutPage.swift`.
//!
//! What the tray menu's 關於 row opens (USER 2026-09-20): two lines the
//! USER wrote; the sponsor and the four community links as cards; the attribution line. In
//! the same cards as every other pane (USER 2026-09-20 「用頁面式」). No app
//! icon, no name and no version — the update row on 一般 already says which build
//! this is.

use crate::presentation::{DISCORD_URL, EMAIL_URL, GITHUB_URL, SPONSOR_URL, WEBSITE_URL};
use crate::winui::cards;
use crate::winui::font_awesome::FontAwesomeGlyph;
use crate::winui::window::{Message, SettingsWindow};
use taigi_windows_core::strings::{StringKey, StringResolver};
use windows_reactor::*;

/// `CaptionTextBlockStyle`'s size, the attribution's fine print.
const CAPTION_FONT_SIZE: f64 = 12.0;
/// Between paragraphs of one text (`Metrics.paragraphSpacing`).
const PARAGRAPH_SPACING: f64 = 10.0;
/// A link card's mark, the size of a sidebar icon (`Metrics.rowGlyphSize`).
const MARK_SIZE: f64 = 16.0;
/// Between the last card and the attribution under it (`Metrics.footerGap`).
const FOOTER_GAP: f64 = 8.0;
/// The fine print's weight, as opacity — `PrimaryText` at less than full
/// is WinUI's secondary text, and it follows the theme.
const SECONDARY_OPACITY: f64 = 0.65;

pub fn view(
    _window: &SettingsWindow,
    strings: &StringResolver,
    context: &mut ViewContext<SettingsWindow>,
) -> View {
    // Centred, no heading (USER 2026-09-20 「不需要『台語齒盤』標題」
    // 「文案置中」): the window title already names the page, and the two
    // lines read as a statement rather than a form.
    let introduction = cards::frame(StackPanel::new().spacing(PARAGRAPH_SPACING).children((
        paragraph(strings.resolve(StringKey::DesktopAboutIntroProject)),
        paragraph(strings.resolve(StringKey::DesktopAboutIntroMaintainer)),
    )));
    View::fragment((
        introduction,
        cards::section_gap(),
        // Every action a row, the sponsor link first (USER 2026-09-20: no
        // lone button on the page).
        link_card(
            strings,
            context,
            FontAwesomeGlyph::Heart,
            StringKey::DesktopSponsorLink,
            SPONSOR_URL,
        ),
        link_card(
            strings,
            context,
            FontAwesomeGlyph::Globe,
            StringKey::DesktopWebsiteLink,
            WEBSITE_URL,
        ),
        link_card(
            strings,
            context,
            FontAwesomeGlyph::Github,
            StringKey::DesktopGithubLink,
            GITHUB_URL,
        ),
        link_card(
            strings,
            context,
            FontAwesomeGlyph::Discord,
            StringKey::DesktopDiscordLink,
            DISCORD_URL,
        ),
        link_card(
            strings,
            context,
            FontAwesomeGlyph::Envelope,
            StringKey::DesktopEmailLink,
            EMAIL_URL,
        ),
        // Fine print on the ground under the last card: neither a setting
        // nor a link.
        TextBlock::new()
            .text(strings.resolve(StringKey::DesktopCopyrightLine))
            .font_size(CAPTION_FONT_SIZE)
            .horizontal_alignment(HorizontalAlignment::Center)
            .margin(Thickness::new(0.0, FOOTER_GAP, 0.0, 0.0))
            .opacity(SECONDARY_OPACITY),
    ))
}

fn paragraph(text: &str) -> View {
    TextBlock::new()
        .text(text)
        .text_wrapping(TextWrapping::Wrap)
        // The block centred, not each line: this pinned `windows-reactor`
        // exposes no `TextAlignment`, so a paragraph that wraps stays
        // ragged-right while a short one centres. Not a departure the Mac
        // shares — revisit when the pin moves.
        .horizontal_alignment(HorizontalAlignment::Center)
        .into()
}

/// A card that opens one of the community links, its Font Awesome mark at
/// the left (`ExternalLinkButton.Style.row`).
fn link_card(
    strings: &StringResolver,
    context: &mut ViewContext<SettingsWindow>,
    glyph: FontAwesomeGlyph,
    title: StringKey,
    url: &'static str,
) -> View {
    // A `Viewbox` rather than a size on the icon: `PathIcon` draws its
    // geometry at the geometry's own size, and a smaller frame would only
    // clip it.
    let mark = Viewbox::new()
        .height(MARK_SIZE)
        .stretch(Stretch::Uniform)
        .opacity(SECONDARY_OPACITY)
        .slot(ViewboxSlot::Child, glyph.icon());
    cards::link_card(
        mark,
        strings.resolve(title),
        context.callback(move |()| Message::OpenUrl(url.to_owned())),
    )
}
