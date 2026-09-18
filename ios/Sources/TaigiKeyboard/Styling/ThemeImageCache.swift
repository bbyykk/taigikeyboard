// Per-process decoded-photo cache for ThemeBackgroundSurface, keyed by the theme image file name.

import UIKit

/// Decodes a theme photo from the App Group `ThemeImageStore` directory once per process
/// and keeps it decoded (`preparingForDisplay`, so a redraw never re-decodes the JPEG).
/// `NSCache` evicts by cost under memory pressure — the keyboard extension lives under a
/// 64 MB cap; one 1280 px photo is ~5 MB, `totalCostLimit` holds about three. A replaced
/// photo gets a new file name, so a stale entry is never served.
final class ThemeImageCache {
    static let shared = ThemeImageCache(store: ThemeImageStore(containerURL: SharedSettings.sharedContainerURL))
    private static let totalCostLimitBytes = 16 * 1024 * 1024

    /// The one store both the host app (writer) and this cache (reader) resolve photos through.
    let store: ThemeImageStore
    private let cache = NSCache<NSString, UIImage>()

    init(store: ThemeImageStore) {
        self.store = store
        cache.totalCostLimit = Self.totalCostLimitBytes
    }

    /// The decoded photo, or nil when the file is missing / undecodable.
    func image(for file: String) -> UIImage? {
        if let cached = cache.object(forKey: file as NSString) {
            return cached
        }
        guard let url = store.url(for: file),
              let image = UIImage(contentsOfFile: url.path)?.preparingForDisplay() else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: file as NSString, cost: cost)
        return image
    }

    /// Drops every decoded photo (after a sweep removed files, so a deleted theme's photo
    /// does not linger in the host process).
    func removeAll() {
        cache.removeAllObjects()
    }
}
