import Foundation

/// The second dentition Petites Dents follows: twelve slots per jaw — the four
/// incisors, the canine, both premolars and the six-year molar of each
/// quadrant. Second permanent molars (17/27/37/47) and wisdom teeth erupt well
/// after twelve years and are deliberately not tracked; the paywall and the
/// App Store listing state that scope explicitly.
enum PermanentToothCatalog {
    static let upper: [ToothDefinition] = [
        permanentTooth(26, .upper, .left, .firstMolar, nil, 6, 7),
        permanentTooth(25, .upper, .left, .secondPremolar, 65, 10, 12),
        permanentTooth(24, .upper, .left, .firstPremolar, 64, 10, 11),
        permanentTooth(23, .upper, .left, .canine, 63, 11, 12),
        permanentTooth(22, .upper, .left, .lateralIncisor, 62, 8, 9),
        permanentTooth(21, .upper, .left, .centralIncisor, 61, 7, 8),
        permanentTooth(11, .upper, .right, .centralIncisor, 51, 7, 8),
        permanentTooth(12, .upper, .right, .lateralIncisor, 52, 8, 9),
        permanentTooth(13, .upper, .right, .canine, 53, 11, 12),
        permanentTooth(14, .upper, .right, .firstPremolar, 54, 10, 11),
        permanentTooth(15, .upper, .right, .secondPremolar, 55, 10, 12),
        permanentTooth(16, .upper, .right, .firstMolar, nil, 6, 7),
    ]

    static let lower: [ToothDefinition] = [
        permanentTooth(36, .lower, .left, .firstMolar, nil, 6, 7),
        permanentTooth(35, .lower, .left, .secondPremolar, 75, 11, 12),
        permanentTooth(34, .lower, .left, .firstPremolar, 74, 10, 12),
        permanentTooth(33, .lower, .left, .canine, 73, 9, 11),
        permanentTooth(32, .lower, .left, .lateralIncisor, 72, 7, 8),
        permanentTooth(31, .lower, .left, .centralIncisor, 71, 6, 7),
        permanentTooth(41, .lower, .right, .centralIncisor, 81, 6, 7),
        permanentTooth(42, .lower, .right, .lateralIncisor, 82, 7, 8),
        permanentTooth(43, .lower, .right, .canine, 83, 9, 11),
        permanentTooth(44, .lower, .right, .firstPremolar, 84, 10, 12),
        permanentTooth(45, .lower, .right, .secondPremolar, 85, 11, 12),
        permanentTooth(46, .lower, .right, .firstMolar, nil, 6, 7),
    ]

    static let all = upper + lower

    static func expectedFDIs(for arch: ToothArch) -> [Int] {
        (arch == .upper ? upper : lower).map(\.fdi)
    }

    static func definition(forFDI fdi: Int) -> ToothDefinition? {
        all.first { $0.fdi == fdi }
    }

    /// The permanent tooth that replaces `primaryFDI`, when the app tracks it.
    static func successor(ofPrimaryFDI primaryFDI: Int) -> ToothDefinition? {
        all.first { $0.predecessorFDI == primaryFDI }
    }

    /// Teeth that erupt without a baby tooth falling first: the four six-year
    /// molars, which are usually the very first permanent teeth to arrive.
    static var withoutPredecessor: [ToothDefinition] {
        all.filter { $0.predecessorFDI == nil }
    }

    private static func permanentTooth(
        _ fdi: Int,
        _ arch: ToothArch,
        _ side: ToothSide,
        _ kind: ToothKind,
        _ predecessorFDI: Int?,
        _ minYears: Int,
        _ maxYears: Int
    ) -> ToothDefinition {
        ToothDefinition(
            id: "tooth-\(fdi)",
            fdi: fdi,
            arch: arch,
            side: side,
            kind: kind,
            phase: .permanent,
            predecessorFDI: predecessorFDI,
            minMonths: minYears * 12,
            maxMonths: maxYears * 12
        )
    }
}
