// Shared appearance-control-row components (color row, slider row) for the
// custom theme editor draft (ThemeEditorView).

import PhotosUI
import SwiftUI

/// Shared slider ranges/steps for the user-theme editor draft.
enum ThemeSliderRanges {
    static let scale: ClosedRange<Double> = 0.85 ... 1.15
    static let scaleStep: Double = 0.01
    static let radius: ClosedRange<Double> = 0 ... 15
    static let radiusStep: Double = 0.5
    static let borderWidth: ClosedRange<Double> = 0 ... 3
    static let borderWidthStep: Double = 0.5
    static let shadow: ClosedRange<Double> = 0 ... 4
    static let shadowStep: Double = 0.5
}

/// A labeled `ColorPicker` row with a trailing reset button shown while `onReset`
/// is non-nil (the caller passes nil when the value already equals its default).
/// Used by the user-theme editor (`ThemeEditorView`, where the binding mutates an
/// in-memory draft); `onReset` is the single writer of the reset value.
struct ThemeColorRow: View {
    let label: String
    @Binding var color: Color
    let onReset: (() -> Void)?

    var body: some View {
        HStack {
            ColorPicker(label, selection: $color, supportsOpacity: false)

            if let onReset {
                Button(action: onReset) {
                    Image(latinSystemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A labeled `Slider` row with a trailing reset button shown when the value
/// differs from `defaultValue`. Used by the user-theme editor.
struct ThemeSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double
    let onChanged: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                if value != defaultValue {
                    Button {
                        value = defaultValue
                        onChanged(defaultValue)
                    } label: {
                        Image(latinSystemName: "arrow.counterclockwise")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Slider(value: $value, in: range, step: step)
                .onChange(of: value) { _, newValue in
                    onChanged(newValue)
                }
        }
    }
}

// MARK: - Gradient direction

/// A labeled row of the eight gradient direction presets as arrow buttons, ↑ (0°)
/// first and clockwise in 45° steps (CSS angle convention, see `ThemeGradient.angle`);
/// the selected preset is filled with the accent color. Used by the user-theme
/// editor's 背景 › 漸層 rows.
struct ThemeGradientDirectionRow: View {
    let label: String
    @Binding var angle: Double

    private struct DirectionPreset: Identifiable {
        let angle: Double
        let symbol: String
        var id: Double {
            angle
        }
    }

    private static let presets = [
        DirectionPreset(angle: 0, symbol: "arrow.up"),
        DirectionPreset(angle: 45, symbol: "arrow.up.right"),
        DirectionPreset(angle: 90, symbol: "arrow.right"),
        DirectionPreset(angle: 135, symbol: "arrow.down.right"),
        DirectionPreset(angle: 180, symbol: "arrow.down"),
        DirectionPreset(angle: 225, symbol: "arrow.down.left"),
        DirectionPreset(angle: 270, symbol: "arrow.left"),
        DirectionPreset(angle: 315, symbol: "arrow.up.left"),
    ]
    private static let buttonSize: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            HStack(spacing: 6) {
                ForEach(Self.presets) { preset in
                    let isSelected = angle == preset.angle
                    Button {
                        angle = preset.angle
                    } label: {
                        Image(latinSystemName: preset.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(width: Self.buttonSize, height: Self.buttonSize)
                            .background(
                                Circle().fill(isSelected ? AppStyle.accentBlue : Color(.tertiarySystemFill)),
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Photo row

/// A `PhotosPicker` row: a thumbnail of the current theme photo (or a placeholder while
/// none is picked) beside the 選擇照片 / 更換照片 label. Tapping anywhere on the row opens
/// the system picker (images only; no photo-library permission is required).
struct ThemePhotoRow: View {
    let label: String
    /// The current theme photo's file name, or nil.
    let file: String?
    @Binding var selection: PhotosPickerItem?

    private static let thumbnailSize: CGFloat = 44
    /// Row-sized thumbnail, prepared once per photo off the main actor (the cached photo is
    /// 1280 px; scaling it every body evaluation is waste).
    @State private var thumbnail: UIImage?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            HStack(spacing: 12) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                    } else {
                        Color(.tertiarySystemFill)
                    }
                }
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius))
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
                Image(latinSystemName: "photo.on.rectangle")
                    .foregroundColor(.secondary)
            }
        }
        .task(id: file) {
            guard let file, let image = ThemeImageCache.shared.image(for: file) else {
                thumbnail = nil
                return
            }
            let side = Self.thumbnailSize * UIScreen.main.scale
            thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: side, height: side))
        }
    }
}

// MARK: - Font Picker

/// Font-selection subpage listing `FontType.allCases`. Opened from the theme
/// page's font entry to pick the GLOBAL keyboard font (font is not part of a theme).
struct ThemeFontPickerView: View {
    @Environment(DisplayLanguageStore.self) private var lang
    @Binding var selectedFont: FontType
    var onChange: (FontType) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(FontType.allCases, id: \.self) { font in
                    Button {
                        selectedFont = font
                        onChange(font)
                    } label: {
                        HStack {
                            Text(lang.string(font.displayNameKey))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedFont == font {
                                Image(latinSystemName: "checkmark")
                                    .foregroundColor(AppStyle.accentBlue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(lang.string(.themeCustomFont))
        .navigationBarTitleDisplayMode(.inline)
    }
}
