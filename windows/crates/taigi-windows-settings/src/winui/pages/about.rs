//! The 關於 page: what the project is and where to find it. Port of
//! `AboutPage.swift`.
//!
//! What the tray menu's 關於 row opens (USER 2026-09-20): the name over the
//! three paragraphs the USER wrote and the sponsor button; the three
//! community links as cards; the attribution line. In
//! the same cards as every other pane (USER 2026-09-20 「用頁面式」). No app
//! icon and no version — the update row on 一般 already says which build
//! this is.

use crate::presentation::{DISCORD_URL, EMAIL_URL, GITHUB_URL, SPONSOR_URL};
use crate::winui::cards;
use crate::winui::font_awesome::FontAwesomeGlyph;
use crate::winui::window::{Message, SettingsWindow};
use taigi_windows_core::strings::{StringKey, StringResolver};
use windows_reactor::*;

/// `SubtitleTextBlockStyle`'s size: the name is a heading under the
/// window's own title, not a second title.
const NAME_FONT_SIZE: f64 = 20.0;
/// `CaptionTextBlockStyle`'s size, the attribution's fine print.
const CAPTION_FONT_SIZE: f64 = 12.0;
/// Between paragraphs of one text (`Metrics.paragraphSpacing`).
const PARAGRAPH_SPACING: f64 = 10.0;
/// Under the name, over its paragraphs (`Metrics.titleGap`).
const TITLE_GAP: f64 = 2.0;
/// Over the sponsor button, so it reads as the paragraphs' close rather
/// than a fourth one (`Metrics.buttonGap`).
const BUTTON_GAP: f64 = 6.0;
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
    let introduction = cards::frame(
        StackPanel::new().spacing(PARAGRAPH_SPACING).children((
            TextBlock::new()
                .text(strings.resolve(StringKey::HomeAppHeaderTitle))
                .font_size(NAME_FONT_SIZE)
                .font_weight(FontWeight::SEMI_BOLD)
                .margin(Thickness::new(0.0, 0.0, 0.0, TITLE_GAP)),
            paragraph(strings.resolve(StringKey::DesktopAboutIntroProject)),
            paragraph(strings.resolve(StringKey::DesktopAboutIntroFree)),
            paragraph(strings.resolve(StringKey::DesktopAboutIntroMaintainer)),
            // The one call to action on the page, in the accent fill
            // (`ExternalLinkButton.Style.prominent`).
            Button::new()
                .style(ButtonStyle::Accent)
                .on_click(context.callback(|()| Message::OpenUrl(SPONSOR_URL.to_owned())))
                .horizontal_alignment(HorizontalAlignment::Left)
                .margin(Thickness::new(0.0, BUTTON_GAP, 0.0, 0.0))
                .content(strings.resolve(StringKey::DesktopSponsorLink)),
        )),
    );
    View::fragment((
        introduction,
        cards::section_gap(),
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
