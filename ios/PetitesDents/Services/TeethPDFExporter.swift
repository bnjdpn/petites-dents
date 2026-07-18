import Foundation
import UIKit

@MainActor
enum TeethPDFExporter {
    private static let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 42

    static func create(snapshots: [ToothSnapshot]) throws -> URL {
        guard snapshots.count == 20 else {
            throw TeethPDFError.incompleteCatalog
        }

        let bounds = pageBounds
        let pageMargin = margin
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            var y = pageMargin
            var pageNumber = 0

            func beginPage() {
                context.beginPage()
                pageNumber += 1
                y = pageMargin
            }

            func drawFooter() {
                let value = "\(pageNumber)" as NSString
                value.draw(
                    at: CGPoint(x: bounds.width - pageMargin - 8, y: bounds.height - 28),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.secondaryLabel]
                )
            }

            func ensureSpace(_ height: CGFloat) {
                guard y + height > bounds.height - pageMargin else { return }
                drawFooter()
                beginPage()
            }

            func drawLine(_ value: String, font: UIFont, color: UIColor = .label, indent: CGFloat = 0) {
                let rect = CGRect(
                    x: pageMargin + indent,
                    y: y,
                    width: bounds.width - pageMargin * 2 - indent,
                    height: .greatestFiniteMagnitude
                )
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                ]
                let height = (value as NSString).boundingRect(
                    with: rect.size,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height
                ensureSpace(height + 4)
                (value as NSString).draw(in: CGRect(x: rect.minX, y: y, width: rect.width, height: height + 2), withAttributes: attributes)
                y += height + 4
            }

            beginPage()
            drawLine(
                String(localized: "pdf.title"),
                font: .systemFont(ofSize: 22, weight: .bold)
            )
            drawLine(
                String(
                    format: NSLocalizedString("pdf.generated", comment: "PDF generation date"),
                    Date().formatted(date: .long, time: .omitted)
                ),
                font: .systemFont(ofSize: 10.5),
                color: .secondaryLabel
            )
            y += 12

            let erupted = snapshots.filter { $0.status == .erupted }.count
            let teething = snapshots.filter { $0.status == .teething }.count
            let summary = String(
                format: NSLocalizedString("pdf.summary", comment: "Tooth status summary"),
                erupted,
                teething,
                snapshots.count - erupted - teething
            )
            drawLine(summary, font: .systemFont(ofSize: 14, weight: .semibold))
            y += 8
            drawMouth(snapshots: snapshots, context: context.cgContext, y: y)
            y += 116

            drawLine(String(localized: "history.title"), font: .systemFont(ofSize: 15, weight: .bold))
            y += 4

            for snapshot in snapshots {
                ensureSpace(66)
                drawLine(
                    "\(snapshot.definition.fdi) · \(snapshot.definition.localizedName)",
                    font: .systemFont(ofSize: 12.5, weight: .semibold)
                )
                let noDate = String(localized: "pdf.no_date")
                let teethingDate = snapshot.record?.teethingDate?.formatted(date: .abbreviated, time: .omitted) ?? noDate
                let eruptedDate = snapshot.record?.eruptedDate?.formatted(date: .abbreviated, time: .omitted) ?? noDate
                drawLine(
                    String(format: NSLocalizedString("pdf.teething", comment: "Teething date"), teethingDate),
                    font: .systemFont(ofSize: 10.5),
                    color: .secondaryLabel,
                    indent: 8
                )
                drawLine(
                    String(format: NSLocalizedString("pdf.erupted", comment: "Eruption date"), eruptedDate),
                    font: .systemFont(ofSize: 10.5),
                    color: .secondaryLabel,
                    indent: 8
                )
                if let note = snapshot.record?.note, !note.isEmpty {
                    drawLine(
                        String(format: NSLocalizedString("pdf.note", comment: "Tooth note"), note),
                        font: .systemFont(ofSize: 10.5),
                        color: .secondaryLabel,
                        indent: 8
                    )
                }
                y += 8
            }
            drawFooter()
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(String(localized: "pdf.filename"))
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func drawMouth(
        snapshots: [ToothSnapshot],
        context: CGContext,
        y: CGFloat
    ) {
        let cellWidth = (pageBounds.width - margin * 2) / 10
        for (row, arch) in [ToothArch.upper, .lower].enumerated() {
            let teeth = snapshots.filter { $0.definition.arch == arch }
            for (index, snapshot) in teeth.enumerated() {
                let x = margin + CGFloat(index) * cellWidth + (cellWidth - 30) / 2
                let rect = CGRect(x: x, y: y + CGFloat(row) * 48, width: 30, height: 30)
                let color: UIColor = switch snapshot.status {
                case .ghost: UIColor.systemGray5
                case .teething: UIColor(red: 1, green: 0.84, blue: 0.70, alpha: 1)
                case .erupted: UIColor(red: 0.51, green: 0.61, blue: 0.48, alpha: 1)
                }
                context.setFillColor(color.cgColor)
                context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 9).cgPath)
                context.fillPath()
                let label = "\(snapshot.definition.fdi)" as NSString
                label.draw(
                    in: rect.insetBy(dx: 0, dy: 8),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                        .foregroundColor: snapshot.status == .erupted ? UIColor.white : UIColor.label,
                        .paragraphStyle: centeredParagraphStyle,
                    ]
                )
            }
        }
    }

    private static var centeredParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
}

enum TeethPDFError: LocalizedError {
    case incompleteCatalog

    var errorDescription: String? {
        String(localized: "pdf.incomplete")
    }
}
