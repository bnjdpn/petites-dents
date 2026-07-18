import Foundation

enum ToothArch: String, Codable, CaseIterable, Sendable {
    case upper
    case lower

    var localizedName: String {
        NSLocalizedString("arch.\(rawValue)", comment: "Tooth arch")
    }
}

enum ToothSide: String, Codable, CaseIterable, Sendable {
    case left
    case right

    var localizedName: String {
        NSLocalizedString("side.\(rawValue)", comment: "Tooth side")
    }
}

enum ToothKind: String, Codable, CaseIterable, Sendable {
    case centralIncisor = "central_incisor"
    case lateralIncisor = "lateral_incisor"
    case canine
    case firstMolar = "first_molar"
    case secondMolar = "second_molar"

    var localizedName: String {
        NSLocalizedString("kind.\(rawValue)", comment: "Tooth kind")
    }
}

enum ToothStatus: String, Codable, CaseIterable, Sendable {
    case ghost
    case teething
    case erupted

    var localizedName: String {
        NSLocalizedString("state.\(rawValue)", comment: "Tooth status")
    }
}

struct ToothDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let fdi: Int
    let arch: ToothArch
    let side: ToothSide
    let kind: ToothKind
    let minMonths: Int
    let maxMonths: Int

    var localizedName: String {
        String(
            format: NSLocalizedString("tooth.full_name", comment: "Full tooth name"),
            arch.localizedName,
            side.localizedName,
            kind.localizedName
        )
    }

    var typicalAge: String {
        String(
            format: NSLocalizedString("tooth.typical_age", comment: "Typical eruption age"),
            minMonths,
            maxMonths
        )
    }
}

enum ToothCatalog {
    static let upper: [ToothDefinition] = [
        tooth(65, .upper, .left, .secondMolar, 25, 33),
        tooth(64, .upper, .left, .firstMolar, 13, 19),
        tooth(63, .upper, .left, .canine, 16, 22),
        tooth(62, .upper, .left, .lateralIncisor, 9, 13),
        tooth(61, .upper, .left, .centralIncisor, 8, 12),
        tooth(51, .upper, .right, .centralIncisor, 8, 12),
        tooth(52, .upper, .right, .lateralIncisor, 9, 13),
        tooth(53, .upper, .right, .canine, 16, 22),
        tooth(54, .upper, .right, .firstMolar, 13, 19),
        tooth(55, .upper, .right, .secondMolar, 25, 33),
    ]

    static let lower: [ToothDefinition] = [
        tooth(75, .lower, .left, .secondMolar, 25, 33),
        tooth(74, .lower, .left, .firstMolar, 13, 19),
        tooth(73, .lower, .left, .canine, 16, 22),
        tooth(72, .lower, .left, .lateralIncisor, 10, 16),
        tooth(71, .lower, .left, .centralIncisor, 6, 10),
        tooth(81, .lower, .right, .centralIncisor, 6, 10),
        tooth(82, .lower, .right, .lateralIncisor, 10, 16),
        tooth(83, .lower, .right, .canine, 16, 22),
        tooth(84, .lower, .right, .firstMolar, 13, 19),
        tooth(85, .lower, .right, .secondMolar, 25, 33),
    ]

    static let all = upper + lower

    private static func tooth(
        _ fdi: Int,
        _ arch: ToothArch,
        _ side: ToothSide,
        _ kind: ToothKind,
        _ minMonths: Int,
        _ maxMonths: Int
    ) -> ToothDefinition {
        ToothDefinition(
            id: "tooth-\(fdi)",
            fdi: fdi,
            arch: arch,
            side: side,
            kind: kind,
            minMonths: minMonths,
            maxMonths: maxMonths
        )
    }
}
