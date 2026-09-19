// The 關於 page: the app's name and version, what the project is, and where to find it.

import SwiftUI

/// What the input-source menu's 關於 row opens (USER 2026-09-20): the name and
/// installed version, the three paragraphs the USER wrote, the community links
/// as bare glyphs, and the attribution line that used to foot the 一般 pane.
///
/// No app icon, by request; no `Form` either, because nothing here is a
/// setting — text in cards would read as controls that do nothing. Plain
/// text at the grouped form's own inset, so the page sits where the other
/// panes' forms do.
struct AboutPage: View {
    @Environment(DisplayLanguageStore.self) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: Metrics.lineSpacing) {
                    Text(language.string(.homeAppHeaderTitle))
                        .font(.title2.weight(.semibold))
                    Text(language.resolver.desktopUpdateCurrentVersionLabel(version: AppVersion.installed))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Metrics.paragraphSpacing) {
                    Text(language.string(.desktopAboutIntroProject))
                    Text(language.string(.desktopAboutIntroFree))
                    Text(language.string(.desktopAboutIntroMaintainer))
                }
                .fixedSize(horizontal: false, vertical: true)

                // The three community links as marks: a brand mark names
                // itself, and three words more would crowd the line. Each
                // carries its name as tooltip and accessibility label.
                HStack(spacing: Metrics.glyphSpacing) {
                    ExternalLinkButton(titleKey: .desktopGithubLink, url: Self.githubURL, style: .footerGlyph(.github))
                    ExternalLinkButton(titleKey: .desktopDiscordLink, url: Self.discordURL, style: .footerGlyph(.discord))
                    ExternalLinkButton(titleKey: .desktopEmailLink, url: Self.emailURL, style: .footerGlyph(.envelope))
                }
                .foregroundStyle(.secondary)

                // Small, grey, the link no louder than the text around it —
                // the project site's own footer.
                HStack(spacing: Metrics.lineSpacing) {
                    Text(language.string(.desktopCopyrightLine))
                    // Punctuation between two pieces, with nothing to say on its own.
                    Text(verbatim: "\u{00B7}")
                        .accessibilityHidden(true)
                    ExternalLinkButton(titleKey: .desktopSponsorLink, url: Self.sponsorURL, style: .footer)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.inset)
        }
    }

    private static let githubURL = URL(string: "https://github.com/taigikeyboard")
    private static let discordURL = URL(string: "https://discord.gg/kXhtQfWvK")
    private static let emailURL = URL(string: "mailto:info@taigikeyboard.tw")
    private static let sponsorURL = URL(string: "https://p.ecpay.com.tw/AA663DE")

    private enum Metrics {
        /// The grouped form's own content inset, so the text lines up with the other panes' cards.
        static let inset: CGFloat = 20

        /// Between the title block, the paragraphs, the links and the attribution line.
        static let sectionSpacing: CGFloat = 20

        /// Between paragraphs of one text.
        static let paragraphSpacing: CGFloat = 10

        /// Within a block: title over version; the attribution line's own phrase spacing.
        static let lineSpacing: CGFloat = 4

        /// Between the three glyphs: wide enough that each stays its own target.
        static let glyphSpacing: CGFloat = 12
    }
}
