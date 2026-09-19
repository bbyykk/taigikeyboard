// The 關於 page: what the project is, how to reach it, and where to find it.

import SwiftUI

/// What the input-source menu's 關於 row opens (USER 2026-09-20): the name over
/// the three paragraphs the USER wrote and the sponsor button; the 問題回報
/// section; the three community links as rows; the attribution line.
///
/// A grouped `Form` like every other pane (USER 2026-09-20 「用頁面式」), so the
/// page sits where the settings do and reads in the same cards. No app icon and
/// no version — the update row on 一般 already says which build this is.
struct AboutPage: View {
    @Environment(DisplayLanguageStore.self) private var language

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Metrics.paragraphSpacing) {
                    Text(language.string(.homeAppHeaderTitle))
                        .font(.title2.weight(.semibold))
                        .padding(.bottom, Metrics.titleGap)
                    Text(language.string(.desktopAboutIntroProject))
                    Text(language.string(.desktopAboutIntroFree))
                    Text(language.string(.desktopAboutIntroMaintainer))
                    ExternalLinkButton(titleKey: .desktopSponsorLink, url: Self.sponsorURL, style: .prominent)
                        .padding(.top, Metrics.buttonGap)
                }
                .padding(.vertical, Metrics.cardInset)
            }

            Section(language.string(.desktopAboutFeedbackTitle)) {
                VStack(alignment: .leading, spacing: Metrics.paragraphSpacing) {
                    Text(language.string(.desktopAboutFeedbackBody))
                    ExternalLinkButton(titleKey: .desktopAboutFeedbackDiscord, url: Self.discordURL, style: .text)
                }
                .padding(.vertical, Metrics.cardInset)
            }

            // The attribution as the last card's footer: fine print on the
            // ground, where a form puts a note that is neither a setting nor
            // a link.
            Section {
                ExternalLinkButton(titleKey: .desktopGithubLink, url: Self.githubURL, style: .row(.github))
                ExternalLinkButton(titleKey: .desktopDiscordLink, url: Self.discordURL, style: .row(.discord))
                ExternalLinkButton(titleKey: .desktopEmailLink, url: Self.emailURL, style: .row(.envelope))
            } footer: {
                Text(language.string(.desktopCopyrightLine))
                    .frame(maxWidth: .infinity)
                    .padding(.top, Metrics.footerGap)
            }
        }
        .formStyle(.grouped)
    }

    private static let githubURL = URL(string: "https://github.com/taigikeyboard")
    private static let discordURL = URL(string: "https://discord.gg/kXhtQfWvK")
    private static let emailURL = URL(string: "mailto:info@taigikeyboard.tw")
    private static let sponsorURL = URL(string: "https://p.ecpay.com.tw/AA663DE")

    private enum Metrics {
        /// Between paragraphs of one text.
        static let paragraphSpacing: CGFloat = 10

        /// Under the name, over its paragraphs.
        static let titleGap: CGFloat = 2

        /// Over the sponsor button, so it reads as the paragraphs' close rather than a fourth one.
        static let buttonGap: CGFloat = 6

        /// Air above and below a card of running text; a row of one line needs none.
        static let cardInset: CGFloat = 4

        /// Between the last card and the attribution under it.
        static let footerGap: CGFloat = 8
    }
}
