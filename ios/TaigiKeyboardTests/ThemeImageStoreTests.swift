@testable import TaigiKeyboard
import UIKit
import XCTest

/// Tests for `ThemeImageStore` — the App Group photo files behind a photo theme background:
/// downscale-on-save, the sweep that removes photos no saved theme references, and the
/// nil-container degradation. Each test uses a fresh temp directory.
final class ThemeImageStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThemeImageStoreTests.\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    /// Encoded JPEG data of a solid red `width`×`height` image — what the photo picker hands over.
    private func jpegData(width: CGFloat, height: CGFloat) throws -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }

    // trace: a 4000×2000 photo saves as a JPEG whose long edge is maxLongEdge (1280) — 1280×640
    func testSave_downsamplesLongEdge() throws {
        let store = ThemeImageStore(containerURL: tempDir)
        let file = try XCTUnwrap(try store.save(jpegData(width: 4000, height: 2000)))
        XCTAssertTrue(file.hasSuffix(".jpg"))
        let url = try XCTUnwrap(store.url(for: file))
        let saved = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        XCTAssertEqual(saved.size.width * saved.scale, ThemeImageStore.maxLongEdge)
        XCTAssertEqual(saved.size.height * saved.scale, ThemeImageStore.maxLongEdge / 2)
    }

    // trace: a small photo is never upscaled; non-image data is rejected
    func testDownsampled_neverUpscales_rejectsNonImage() throws {
        let small = try XCTUnwrap(try ThemeImageStore.downsampled(jpegData(width: 300, height: 200), maxLongEdge: 1280))
        XCTAssertEqual(small.size, CGSize(width: 300, height: 200))
        XCTAssertNil(ThemeImageStore.downsampled(Data("not an image".utf8), maxLongEdge: 1280))
        XCTAssertNil(ThemeImageStore(containerURL: tempDir).save(Data("not an image".utf8)))
    }

    // trace: sweep keeps the referenced file and removes the orphan
    func testSweep_removesUnreferencedFiles() throws {
        let store = ThemeImageStore(containerURL: tempDir)
        let keep = try XCTUnwrap(try store.save(jpegData(width: 10, height: 10)))
        let drop = try XCTUnwrap(try store.save(jpegData(width: 10, height: 10)))

        store.sweep(keeping: [keep])

        XCTAssertTrue(try FileManager.default.fileExists(atPath: XCTUnwrap(store.url(for: keep)).path))
        XCTAssertFalse(try FileManager.default.fileExists(atPath: XCTUnwrap(store.url(for: drop)).path))
    }

    // trace: no container → save returns nil, sweep is a no-op, url is nil
    func testNilContainer_degrades() throws {
        let store = ThemeImageStore(containerURL: nil)
        XCTAssertNil(try store.save(jpegData(width: 10, height: 10)))
        XCTAssertNil(store.url(for: "x.jpg"))
        store.sweep(keeping: [])
    }
}
