import AppKit

/// `MenuBarExtra` ignores multiline `Text` font modifiers, so render a bounded template image.
@MainActor
enum MenuBarLabelImageRenderer {
    private static let font = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
    private static let canvasHeight: CGFloat = 20
    private static let horizontalInset: CGFloat = 1

    static func render(_ label: String) -> NSImage {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = -1

        let attributedLabel = NSAttributedString(
            string: label,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraphStyle
            ]
        )
        let measured = attributedLabel.boundingRect(
            with: NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let canvasSize = NSSize(
            width: ceil(measured.width) + horizontalInset * 2,
            height: canvasHeight
        )
        let image = NSImage(size: canvasSize, flipped: true) { _ in
            let drawingRect = NSRect(
                x: horizontalInset,
                y: max((canvasHeight - measured.height) / 2, 0),
                width: ceil(measured.width),
                height: min(ceil(measured.height), canvasHeight)
            )
            attributedLabel.draw(
                with: drawingRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
