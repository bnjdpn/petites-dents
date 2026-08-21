import Foundation
import UIKit

struct KeepsakePhoto: Identifiable, Sendable {
    let id: String
    let data: Data
    let caption: String
}

struct KeepsakeEvent: Identifiable, Sendable {
    enum Kind: Sendable {
        case erupted
        case shed
        case permanentErupted

        var localizedLabel: String {
            switch self {
            case .erupted: NSLocalizedString("keepsake.event.erupted", comment: "")
            case .shed: NSLocalizedString("keepsake.event.shed", comment: "")
            case .permanentErupted: NSLocalizedString("keepsake.event.permanent", comment: "")
            }
        }

        var accentColor: UIColor {
            switch self {
            case .erupted: PetitesDentsStyle.uiSage
            case .shed: PetitesDentsStyle.uiCoral
            case .permanentErupted: ToothFamilyOutline.canine.uiColor
            }
        }
    }

    let id: String
    let date: Date
    let fdi: Int
    let toothName: String
    let kind: Kind
    let note: String
}

struct KeepsakeDocument: Sendable {
    let profileName: String
    let birthDate: Date?
    let primary: [KeepsakeToothMark]
    let permanent: [KeepsakeToothMark]
    let photos: [KeepsakePhoto]
    let events: [KeepsakeEvent]

    var eruptedCount: Int { primary.filter { $0.status != .ghost && $0.status != .teething }.count }
    var shedCount: Int { primary.filter { $0.status == .shed }.count }
    var permanentCount: Int { permanent.filter { $0.status == .erupted }.count }
    var isEmpty: Bool { events.isEmpty && photos.isEmpty }
}

/// The minimum a drawn tooth needs, detached from SwiftData so the renderer
/// stays a pure function of its input and is testable.
struct KeepsakeToothMark: Sendable {
    let fdi: Int
    let arch: ToothArch
    let kind: ToothKind
    let status: ToothStatus
}

@MainActor
enum KeepsakeDocumentBuilder {
    static let maximumPhotos = 8

    static func make(
        profileName: String,
        birthDate: Date?,
        childID: String,
        primary: [ToothSnapshot],
        permanent: [ToothSnapshot],
        photoRoot: URL = ToothPhotoStore.defaultRootDirectory()
    ) -> KeepsakeDocument {
        let all = primary + permanent
        var events: [KeepsakeEvent] = []
        for snapshot in all {
            guard let record = snapshot.record else { continue }
            let name = snapshot.definition.localizedName
            if let eruptedDate = record.eruptedDate {
                events.append(
                    KeepsakeEvent(
                        id: "\(snapshot.id)-erupted",
                        date: eruptedDate,
                        fdi: snapshot.definition.fdi,
                        toothName: name,
                        kind: snapshot.definition.phase == .permanent ? .permanentErupted : .erupted,
                        note: record.note
                    )
                )
            }
            if let sheddingDate = record.sheddingDate {
                events.append(
                    KeepsakeEvent(
                        id: "\(snapshot.id)-shed",
                        date: sheddingDate,
                        fdi: snapshot.definition.fdi,
                        toothName: name,
                        kind: .shed,
                        note: record.note
                    )
                )
            }
        }
        events.sort { $0.date == $1.date ? $0.fdi < $1.fdi : $0.date < $1.date }

        var photos: [KeepsakePhoto] = []
        for snapshot in all {
            guard let record = snapshot.record else { continue }
            for photoID in record.photoIDs {
                guard photos.count < maximumPhotos else { break }
                guard let data = ToothPhotoStore.data(
                    photoID: photoID,
                    childID: childID,
                    toothID: snapshot.definition.id,
                    root: photoRoot
                ) else { continue }
                let date = record.sheddingDate ?? record.eruptedDate ?? record.teethingDate
                let caption = date.map {
                    "\(snapshot.definition.fdi) · \(CivilDate.formatted($0, style: .medium))"
                } ?? "\(snapshot.definition.fdi)"
                photos.append(KeepsakePhoto(id: photoID, data: data, caption: caption))
            }
        }

        return KeepsakeDocument(
            profileName: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: birthDate,
            primary: primary.map(mark),
            permanent: permanent.map(mark),
            photos: photos,
            events: events
        )
    }

    private static func mark(_ snapshot: ToothSnapshot) -> KeepsakeToothMark {
        KeepsakeToothMark(
            fdi: snapshot.definition.fdi,
            arch: snapshot.definition.arch,
            kind: snapshot.definition.kind,
            status: snapshot.status
        )
    }
}

enum KeepsakePDFError: LocalizedError {
    case nothingToPrint

    var errorDescription: String? {
        NSLocalizedString("keepsake.error_empty", comment: "Nothing to print yet")
    }
}

/// The illustrated A4 keepsake — the only document of the app that carries the
/// child's photos. The free clinical sheet (`TeethPDFExporter`) is a different
/// document, frozen, and never contains an image.
@MainActor
enum KeepsakePDFRenderer {
    static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 44

    static func render(_ document: KeepsakeDocument) throws -> URL {
        guard !document.isEmpty else { throw KeepsakePDFError.nothingToPrint }
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let data = renderer.pdfData { context in
            context.beginPage()
            drawPlate(document, in: bounds, context: context.cgContext)
            drawTimelinePages(document, in: bounds, context: context)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(for: document.profileName))
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The plate exactly as it will print, rendered as an image so the paywall
    /// can show the parent their own page before they pay for it.
    static func plateImage(_ document: KeepsakeDocument, width: CGFloat) -> UIImage {
        let scale = width / pageSize.width
        let size = CGSize(width: width, height: pageSize.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            drawPlate(
                document,
                in: CGRect(origin: .zero, size: pageSize),
                context: context.cgContext
            )
        }
    }

    // MARK: - Plate

    private static func drawPlate(
        _ document: KeepsakeDocument,
        in bounds: CGRect,
        context: CGContext
    ) {
        PetitesDentsStyle.uiCream.setFill()
        context.fill(bounds)

        let frame = bounds.insetBy(dx: 26, dy: 26)
        context.setStrokeColor(PetitesDentsStyle.uiCoralSoft.cgColor)
        context.setLineWidth(1.5)
        context.addPath(UIBezierPath(roundedRect: frame, cornerRadius: 18).cgPath)
        context.strokePath()

        let contentWidth = bounds.width - margin * 2
        var y = margin + 22

        y += drawText(
            NSLocalizedString("keepsake.eyebrow", comment: "Keepsake eyebrow"),
            in: CGRect(x: margin, y: y, width: contentWidth, height: 20),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: PetitesDentsStyle.uiCoral,
            alignment: .center,
            kerning: 2.4
        ) + 8

        let title = document.profileName.isEmpty
            ? NSLocalizedString("keepsake.untitled_child", comment: "")
            : document.profileName
        y += drawText(
            title,
            in: CGRect(x: margin, y: y, width: contentWidth, height: 46),
            font: .systemFont(ofSize: 30, weight: .bold),
            color: PetitesDentsStyle.uiInk,
            alignment: .center
        ) + 4

        if let birthDate = document.birthDate {
            y += drawText(
                String(
                    format: NSLocalizedString("pdf.birth_date", comment: ""),
                    CivilDate.formatted(birthDate, style: .long)
                ),
                in: CGRect(x: margin, y: y, width: contentWidth, height: 20),
                font: .systemFont(ofSize: 10.5),
                color: PetitesDentsStyle.uiInkSoft,
                alignment: .center
            )
        }
        y += 18

        drawStatRow(document, x: margin, y: y, width: contentWidth, context: context)
        y += 60

        let panelWidth = (contentWidth - 18) / 2
        drawMouthPanel(
            title: NSLocalizedString("phase.primary", comment: ""),
            marks: document.primary,
            slots: DentalArchGeometry.primarySlots,
            expectedFDIs: [
                DentalArchGeometry.expectedFDIs(for: .upper),
                DentalArchGeometry.expectedFDIs(for: .lower),
            ],
            origin: CGPoint(x: margin, y: y),
            width: panelWidth,
            context: context
        )
        drawMouthPanel(
            title: NSLocalizedString("phase.permanent", comment: ""),
            marks: document.permanent,
            slots: DentalArchGeometry.permanentSlots,
            expectedFDIs: [
                PermanentToothCatalog.expectedFDIs(for: .upper),
                PermanentToothCatalog.expectedFDIs(for: .lower),
            ],
            origin: CGPoint(x: margin + panelWidth + 18, y: y),
            width: panelWidth,
            context: context
        )
        y += 18 + panelWidth * 0.52 * 2 + 20

        drawPhotoGrid(document, x: margin, y: &y, width: contentWidth, context: context)

        drawFooter(bounds: bounds, page: 1, context: context)
    }

    private static func drawStatRow(
        _ document: KeepsakeDocument,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        context: CGContext
    ) {
        let stats: [(String, String)] = [
            ("\(document.eruptedCount)", NSLocalizedString("keepsake.stat.erupted", comment: "")),
            ("\(document.shedCount)", NSLocalizedString("keepsake.stat.shed", comment: "")),
            ("\(document.permanentCount)", NSLocalizedString("keepsake.stat.permanent", comment: "")),
        ]
        let tileWidth = (width - 20) / 3
        for (index, stat) in stats.enumerated() {
            let rect = CGRect(
                x: x + CGFloat(index) * (tileWidth + 10),
                y: y,
                width: tileWidth,
                height: 50
            )
            PetitesDentsStyle.uiCoralSoft.withAlphaComponent(0.42).setFill()
            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 12).cgPath)
            context.fillPath()
            _ = drawText(
                stat.0,
                in: CGRect(x: rect.minX, y: rect.minY + 7, width: rect.width, height: 24),
                font: .systemFont(ofSize: 19, weight: .bold),
                color: PetitesDentsStyle.uiInk,
                alignment: .center
            )
            _ = drawText(
                stat.1,
                in: CGRect(x: rect.minX + 4, y: rect.minY + 30, width: rect.width - 8, height: 16),
                font: .systemFont(ofSize: 8.5, weight: .medium),
                color: PetitesDentsStyle.uiInkSoft,
                alignment: .center
            )
        }
    }

    private static func drawMouthPanel(
        title: String,
        marks: [KeepsakeToothMark],
        slots: Int,
        expectedFDIs: [[Int]],
        origin: CGPoint,
        width: CGFloat,
        context: CGContext
    ) {
        _ = drawText(
            title,
            in: CGRect(x: origin.x, y: origin.y, width: width, height: 16),
            font: .systemFont(ofSize: 9.5, weight: .semibold),
            color: PetitesDentsStyle.uiSage,
            alignment: .center,
            kerning: 1.1
        )
        let archHeight = width * 0.52
        let marksByFDI = Dictionary(uniqueKeysWithValues: marks.map { ($0.fdi, $0) })
        for (row, arch) in [ToothArch.upper, .lower].enumerated() {
            let rect = CGRect(
                x: origin.x,
                y: origin.y + 18 + CGFloat(row) * archHeight,
                width: width,
                height: archHeight
            )
            context.setStrokeColor(
                PetitesDentsStyle.uiCoralSoft.withAlphaComponent(0.85).cgColor
            )
            context.setLineWidth(archHeight * 0.19)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(GumOutline.cgPath(in: rect, arch: arch))
            context.strokePath()
            context.setLineCap(.butt)

            let placements = DentalArchGeometry.placements(for: arch, slots: slots)
            for (index, fdi) in expectedFDIs[row].enumerated() {
                guard placements.indices.contains(index), let mark = marksByFDI[fdi] else { continue }
                drawTooth(
                    mark,
                    placement: placements[index],
                    in: rect,
                    scale: width / 320,
                    context: context
                )
            }
        }
    }

    private static func drawTooth(
        _ mark: KeepsakeToothMark,
        placement: DentalArchPlacement,
        in rect: CGRect,
        scale: CGFloat,
        context: CGContext
    ) {
        let size = CGSize(
            width: mark.kind.glyphSize.width * scale,
            height: mark.kind.glyphSize.height * scale
        )
        let center = CGPoint(
            x: rect.minX + rect.width * placement.xFraction,
            y: rect.minY + rect.height * placement.yFraction
        )
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: placement.rotationDegrees * .pi / 180)
        let box = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        let path = ToothOutline.cgPath(in: box)
        switch mark.status {
        case .erupted:
            context.addPath(path)
            context.setFillColor(UIColor.white.cgColor)
            context.fillPath()
            context.addPath(path)
            context.setStrokeColor(mark.kind.familyOutline.uiColor.cgColor)
            context.setLineWidth(max(1.1, 1.6 * scale))
            context.strokePath()
        case .teething:
            context.addPath(path)
            context.setFillColor(PetitesDentsStyle.uiApricot.cgColor)
            context.fillPath()
            context.addPath(path)
            context.setStrokeColor(mark.kind.familyOutline.uiColor.cgColor)
            context.setLineWidth(max(1.1, 1.6 * scale))
            context.strokePath()
        case .shed:
            context.addPath(path)
            context.setStrokeColor(
                PetitesDentsStyle.uiCoral.withAlphaComponent(0.85).cgColor
            )
            context.setLineWidth(max(1, 1.4 * scale))
            context.setLineDash(phase: 0, lengths: [2.4 * scale, 1.8 * scale])
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        case .ghost:
            context.addPath(path)
            context.setStrokeColor(
                mark.kind.familyOutline.uiColor.withAlphaComponent(0.32).cgColor
            )
            context.setLineWidth(max(0.8, 1.1 * scale))
            context.setLineDash(phase: 0, lengths: [1.8 * scale, 1.6 * scale])
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        }
        context.restoreGState()
    }

    private static func drawPhotoGrid(
        _ document: KeepsakeDocument,
        x: CGFloat,
        y: inout CGFloat,
        width: CGFloat,
        context: CGContext
    ) {
        _ = drawText(
            NSLocalizedString("keepsake.photos_title", comment: ""),
            in: CGRect(x: x, y: y, width: width, height: 18),
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: PetitesDentsStyle.uiInk,
            alignment: .natural,
            kerning: 0.6
        )
        y += 20

        guard !document.photos.isEmpty else {
            _ = drawText(
                NSLocalizedString("keepsake.photos_empty", comment: ""),
                in: CGRect(x: x, y: y, width: width, height: 18),
                font: .systemFont(ofSize: 9.5),
                color: PetitesDentsStyle.uiInkSoft,
                alignment: .natural
            )
            y += 24
            return
        }

        let columns = 4
        let spacing: CGFloat = 10
        let cellWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let imageHeight = cellWidth * 0.78
        for (index, photo) in document.photos.enumerated() {
            let column = index % columns
            let row = index / columns
            let cell = CGRect(
                x: x + CGFloat(column) * (cellWidth + spacing),
                y: y + CGFloat(row) * (imageHeight + 26),
                width: cellWidth,
                height: imageHeight
            )
            let clip = UIBezierPath(roundedRect: cell, cornerRadius: 8)
            context.saveGState()
            clip.addClip()
            if let image = UIImage(data: photo.data) {
                let scale = max(cell.width / image.size.width, cell.height / image.size.height)
                let drawn = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                image.draw(
                    in: CGRect(
                        x: cell.midX - drawn.width / 2,
                        y: cell.midY - drawn.height / 2,
                        width: drawn.width,
                        height: drawn.height
                    )
                )
            } else {
                PetitesDentsStyle.uiCoralSoft.setFill()
                context.fill(cell)
            }
            context.restoreGState()
            context.addPath(clip.cgPath)
            context.setStrokeColor(PetitesDentsStyle.uiCoralSoft.cgColor)
            context.setLineWidth(1)
            context.strokePath()
            _ = drawText(
                photo.caption,
                in: CGRect(x: cell.minX, y: cell.maxY + 5, width: cell.width, height: 14),
                font: .systemFont(ofSize: 8),
                color: PetitesDentsStyle.uiInkSoft,
                alignment: .center
            )
        }
        let rows = (document.photos.count + columns - 1) / columns
        y += CGFloat(rows) * (imageHeight + 26)
    }

    // MARK: - Timeline

    private static func drawTimelinePages(
        _ document: KeepsakeDocument,
        in bounds: CGRect,
        context: UIGraphicsPDFRendererContext
    ) {
        guard !document.events.isEmpty else { return }
        var page = 1
        var y = bounds.height

        func beginPage() {
            context.beginPage()
            page += 1
            PetitesDentsStyle.uiCream.setFill()
            context.cgContext.fill(bounds)
            y = margin + 12
            y += drawText(
                NSLocalizedString("keepsake.timeline_title", comment: ""),
                in: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 26),
                font: .systemFont(ofSize: 17, weight: .bold),
                color: PetitesDentsStyle.uiInk,
                alignment: .natural
            ) + 12
            drawFooter(bounds: bounds, page: page, context: context.cgContext)
        }

        beginPage()
        for event in document.events {
            if y + 34 > bounds.height - margin - 16 {
                beginPage()
            }
            drawTimelineRow(
                event,
                birthDate: document.birthDate,
                x: margin,
                y: y,
                width: bounds.width - margin * 2,
                context: context.cgContext
            )
            y += 34
        }
    }

    private static func drawTimelineRow(
        _ event: KeepsakeEvent,
        birthDate: Date?,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        context: CGContext
    ) {
        let badge = CGRect(x: x, y: y + 3, width: 26, height: 22)
        event.kind.accentColor.withAlphaComponent(0.16).setFill()
        context.addPath(UIBezierPath(roundedRect: badge, cornerRadius: 7).cgPath)
        context.fillPath()
        _ = drawText(
            "\(event.fdi)",
            in: CGRect(x: badge.minX, y: badge.minY + 5, width: badge.width, height: 14),
            font: .systemFont(ofSize: 9, weight: .bold),
            color: event.kind.accentColor,
            alignment: .center
        )
        _ = drawText(
            "\(event.kind.localizedLabel) · \(event.toothName)",
            in: CGRect(x: x + 34, y: y + 2, width: width - 34, height: 14),
            font: .systemFont(ofSize: 10.5, weight: .semibold),
            color: PetitesDentsStyle.uiInk,
            alignment: .natural
        )
        let dateText = CivilDate.formatted(event.date, style: .long)
        let line = birthDate
            .flatMap { CalendarAgeFormatter.string(birthDate: $0, eventDate: event.date) }
            .map { String(format: NSLocalizedString("keepsake.date_with_age", comment: ""), dateText, $0) }
            ?? dateText
        _ = drawText(
            line,
            in: CGRect(x: x + 34, y: y + 16, width: width - 34, height: 14),
            font: .systemFont(ofSize: 9.5),
            color: PetitesDentsStyle.uiInkSoft,
            alignment: .natural
        )
        context.setStrokeColor(PetitesDentsStyle.uiCoralSoft.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: x, y: y + 32))
        context.addLine(to: CGPoint(x: x + width, y: y + 32))
        context.strokePath()
    }

    private static func drawFooter(bounds: CGRect, page: Int, context: CGContext) {
        _ = drawText(
            String(
                format: NSLocalizedString("keepsake.footer", comment: ""),
                Date().formatted(date: .long, time: .omitted)
            ),
            in: CGRect(
                x: margin,
                y: bounds.height - margin + 4,
                width: bounds.width - margin * 2,
                height: 14
            ),
            font: .systemFont(ofSize: 7.5),
            color: PetitesDentsStyle.uiInkSoft,
            alignment: .center
        )
    }

    // MARK: - Text

    @discardableResult
    private static func drawText(
        _ value: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment,
        kerning: CGFloat = 0
    ) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if kerning != 0 {
            attributes[.kern] = kerning
        }
        let text = NSAttributedString(string: value, attributes: attributes)
        text.draw(in: rect)
        let measured = text.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height
        return min(measured, rect.height)
    }

    private static func filename(for profileName: String) -> String {
        let localized = NSLocalizedString("keepsake.filename", comment: "")
        let slug = profileName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
            .split(separator: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        guard !slug.isEmpty else { return localized }
        let separator = localized.lastIndex(of: ".")
        let stem = separator.map { String(localized[..<$0]) } ?? localized
        let ext = separator.map { String(localized[$0...]) } ?? ".pdf"
        return "\(stem)-\(slug)\(ext)"
    }
}
