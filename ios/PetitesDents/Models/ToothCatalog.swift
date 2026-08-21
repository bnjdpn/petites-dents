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

/// The two dentitions the app follows. Second permanent molars (17/27/37/47)
/// and wisdom teeth erupt after twelve and are deliberately out of scope.
enum ToothPhase: String, Codable, CaseIterable, Sendable {
    case primary
    case permanent

    var localizedName: String {
        NSLocalizedString("phase.\(rawValue)", comment: "Dentition phase")
    }
}

enum ToothKind: String, Codable, CaseIterable, Sendable {
    case centralIncisor = "central_incisor"
    case lateralIncisor = "lateral_incisor"
    case canine
    case firstPremolar = "first_premolar"
    case secondPremolar = "second_premolar"
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
    case shed

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
    let phase: ToothPhase
    /// FDI number of the baby tooth this permanent tooth replaces, when there
    /// is one. Six-year molars have no predecessor.
    let predecessorFDI: Int?
    let minMonths: Int
    let maxMonths: Int

    init(
        id: String,
        fdi: Int,
        arch: ToothArch,
        side: ToothSide,
        kind: ToothKind,
        phase: ToothPhase = .primary,
        predecessorFDI: Int? = nil,
        minMonths: Int,
        maxMonths: Int
    ) {
        self.id = id
        self.fdi = fdi
        self.arch = arch
        self.side = side
        self.kind = kind
        self.phase = phase
        self.predecessorFDI = predecessorFDI
        self.minMonths = minMonths
        self.maxMonths = maxMonths
    }

    var localizedName: String {
        String(
            format: NSLocalizedString("tooth.full_name", comment: "Full tooth name"),
            arch.localizedName,
            side.localizedName,
            kind.localizedName
        )
    }

    var typicalAge: String {
        switch phase {
        case .primary:
            String(
                format: NSLocalizedString("tooth.typical_age", comment: "Typical eruption age"),
                minMonths,
                maxMonths
            )
        case .permanent:
            String(
                format: NSLocalizedString(
                    "tooth.typical_age_years",
                    comment: "Typical permanent eruption age"
                ),
                minMonths / 12,
                maxMonths / 12
            )
        }
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

    static func definition(forFDI fdi: Int) -> ToothDefinition? {
        all.first { $0.fdi == fdi }
    }

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
            phase: .primary,
            predecessorFDI: nil,
            minMonths: minMonths,
            maxMonths: maxMonths
        )
    }
}
