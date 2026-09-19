// Brand and mail glyphs for the settings footer's community links.
//
// Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com
// License - https://fontawesome.com/license/free (Icons: CC BY 4.0)
// Copyright 2024 Fonticons, Inc.
//
// Path data from `svgs/brands/github.svg`, `svgs/brands/discord.svg` and
// `svgs/regular/envelope.svg`, rewritten as absolute commands and scaled to a
// 16-point height so the same string draws on Windows (`font_awesome.rs`).
// SF Symbols carry no brand marks.

import AppKit

/// A Font Awesome glyph; the view that shows it draws it as a template, in its own colour.
enum FontAwesomeGlyph {
    case github
    case discord
    case envelope

    /// The glyph's image; decoded once from its SVG, then shared.
    var image: NSImage {
        switch self {
        case .github: Self.githubImage
        case .discord: Self.discordImage
        case .envelope: Self.envelopeImage
        }
    }

    private static let githubImage = makeImage(width: 15.5, path: githubPath)
    private static let discordImage = makeImage(width: 20, path: discordPath)
    private static let envelopeImage = makeImage(width: 16, path: envelopePath)

    /// Wraps the path in the smallest SVG document AppKit will decode. The height is
    /// always 16; the width is the glyph's own, so the aspect survives resizing.
    private static func makeImage(width: Double, path: String) -> NSImage {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) 16"><path d="\(path)"/></svg>
        """
        guard let image = NSImage(data: Data(svg.utf8)) else {
            preconditionFailure("Font Awesome glyph SVG failed to decode")
        }
        return image
    }

    private static let githubPath = "M 5.18,12.41 C 5.18,12.48 5.11,12.53 5.02,12.53 C 4.91,12.54 4.84,12.49 4.84,12.41 C 4.84,12.35 4.91,12.3 5,12.3 C 5.1,12.29 5.18,12.34 5.18,12.41 M 4.21,12.27 C 4.19,12.34 4.25,12.41 4.34,12.43 C 4.42,12.46 4.52,12.43 4.54,12.36 C 4.55,12.3 4.5,12.23 4.4,12.2 C 4.32,12.18 4.23,12.21 4.21,12.27 M 5.59,12.22 C 5.5,12.24 5.44,12.3 5.45,12.37 C 5.45,12.44 5.54,12.48 5.63,12.45 C 5.72,12.43 5.78,12.37 5.77,12.31 C 5.76,12.25 5.68,12.21 5.59,12.22 M 7.65,0.25 C 3.31,0.25 8.88e-16,3.54 0,7.87 C 0,11.34 2.18,14.3 5.29,15.35 C 5.69,15.42 5.83,15.17 5.83,14.97 C 5.83,14.77 5.82,13.7 5.82,13.05 C 5.82,13.05 3.64,13.52 3.18,12.12 C 3.18,12.12 2.82,11.21 2.31,10.97 C 2.31,10.97 1.59,10.48 2.36,10.49 C 2.36,10.49 3.14,10.55 3.56,11.3 C 4.25,12.5 5.39,12.16 5.84,11.95 C 5.91,11.45 6.12,11.1 6.34,10.9 C 4.6,10.7 2.83,10.45 2.83,7.44 C 2.83,6.59 3.07,6.15 3.57,5.6 C 3.49,5.4 3.22,4.56 3.65,3.48 C 4.3,3.28 5.81,4.33 5.81,4.33 C 6.43,4.15 7.1,4.06 7.77,4.06 C 8.44,4.06 9.11,4.15 9.73,4.33 C 9.73,4.33 11.24,3.28 11.89,3.48 C 12.32,4.57 12.05,5.4 11.97,5.6 C 12.47,6.16 12.78,6.59 12.78,7.44 C 12.78,10.46 10.94,10.7 9.19,10.9 C 9.48,11.14 9.72,11.61 9.72,12.35 C 9.72,13.4 9.71,14.7 9.71,14.96 C 9.71,15.16 9.85,15.41 10.25,15.34 C 13.38,14.3 15.5,11.34 15.5,7.87 C 15.5,3.54 11.98,0.25 7.65,0.25 M 3.03,11.02 C 2.99,11.05 3,11.13 3.05,11.19 C 3.1,11.24 3.18,11.26 3.22,11.22 C 3.26,11.19 3.25,11.11 3.2,11.05 C 3.15,11 3.07,10.98 3.03,11.02 M 2.7,10.77 C 2.67,10.81 2.7,10.86 2.77,10.89 C 2.82,10.92 2.88,10.91 2.9,10.87 C 2.92,10.83 2.89,10.78 2.83,10.75 C 2.77,10.73 2.72,10.74 2.7,10.77 M 3.71,11.88 C 3.66,11.92 3.68,12.02 3.75,12.08 C 3.82,12.15 3.91,12.16 3.95,12.11 C 3.99,12.07 3.97,11.97 3.91,11.91 C 3.84,11.84 3.75,11.83 3.71,11.88 M 3.35,11.42 C 3.3,11.45 3.3,11.54 3.35,11.61 C 3.4,11.68 3.49,11.71 3.53,11.68 C 3.58,11.64 3.58,11.56 3.53,11.49 C 3.48,11.41 3.4,11.38 3.35,11.42"

    private static let discordPath = "M 16.39,2.18 A 0.04,0.04 0 0 0 16.36,2.16 A 15.15,15.15 0 0 0 12.62,1 A 0.05,0.05 0 0 0 12.56,1.02 A 10.54,10.54 0 0 0 12.1,1.98 A 13.99,13.99 0 0 0 7.9,1.98 A 9.67,9.67 0 0 0 7.42,1.02 A 0.05,0.05 0 0 0 7.36,1 A 15.11,15.11 0 0 0 3.62,2.16 A 0.05,0.05 0 0 0 3.6,2.18 C 1.22,5.73 0.56,9.2 0.88,12.63 A 0.06,0.06 0 0 0 0.91,12.67 A 15.23,15.23 0 0 0 5.5,14.99 A 0.05,0.05 0 0 0 5.56,14.97 A 10.88,10.88 0 0 0 6.5,13.45 A 0.05,0.05 0 0 0 6.47,13.36 A 10.03,10.03 0 0 1 5.03,12.68 A 0.05,0.05 0 0 1 5.03,12.58 C 5.12,12.51 5.22,12.44 5.31,12.36 A 0.05,0.05 0 0 1 5.37,12.35 C 8.38,13.72 11.63,13.72 14.61,12.35 A 0.05,0.05 0 0 1 14.67,12.36 C 14.76,12.44 14.85,12.51 14.95,12.58 A 0.05,0.05 0 0 1 14.95,12.68 A 9.41,9.41 0 0 1 13.51,13.36 A 0.05,0.05 0 0 0 13.48,13.45 A 12.22,12.22 0 0 0 14.42,14.97 A 0.05,0.05 0 0 0 14.48,14.99 A 15.18,15.18 0 0 0 19.08,12.67 A 0.05,0.05 0 0 0 19.1,12.63 C 19.49,8.67 18.46,5.23 16.39,2.18 M 6.95,10.54 C 6.04,10.54 5.3,9.71 5.3,8.69 C 5.3,7.67 6.03,6.84 6.95,6.84 C 7.87,6.84 8.61,7.68 8.6,8.69 C 8.6,9.71 7.87,10.54 6.95,10.54 M 13.05,10.54 C 12.15,10.54 11.4,9.71 11.4,8.69 C 11.4,7.67 12.13,6.84 13.05,6.84 C 13.98,6.84 14.72,7.68 14.7,8.69 C 14.7,9.71 13.98,10.54 13.05,10.54"

    private static let envelopePath = "M 2,3.5 C 1.72,3.5 1.5,3.72 1.5,4 L 1.5,4.69 L 6.89,9.11 C 7.53,9.64 8.46,9.64 9.11,9.11 L 14.5,4.69 L 14.5,4 C 14.5,3.72 14.27,3.5 14,3.5 L 2,3.5 M 1.5,6.63 L 1.5,12 C 1.5,12.27 1.72,12.5 2,12.5 L 14,12.5 C 14.27,12.5 14.5,12.27 14.5,12 L 14.5,6.63 L 10.06,10.27 C 8.86,11.25 7.13,11.25 5.93,10.27 L 1.5,6.63 M 0,4 C 0,2.89 0.89,2 2,2 L 14,2 C 15.1,2 16,2.89 16,4 L 16,12 C 16,13.1 15.1,14 14,14 L 2,14 C 0.89,14 0,13.1 0,12 L 0,4"
}
