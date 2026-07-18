import SwiftUI

enum PetitesDentsStyle {
    static let coral = Color(red: 1.00, green: 0.45, blue: 0.40)
    static let coralSoft = Color(red: 1.00, green: 0.85, blue: 0.82)
    static let apricot = Color(red: 1.00, green: 0.90, blue: 0.78)
    static let sage = Color(red: 0.51, green: 0.61, blue: 0.48)
    static let ghostFill = Color(red: 0.89, green: 0.88, blue: 0.88)
    static let cream = Color(red: 1.00, green: 0.98, blue: 0.95)
    static let ink = Color(red: 0.20, green: 0.17, blue: 0.16)
}

enum ToothFamilyOutline: String, CaseIterable {
    case centralIncisor
    case lateralIncisor
    case canine
    case firstMolar
    case secondMolar

    var color: Color {
        switch self {
        case .centralIncisor:
            Color(red: 0.85, green: 0.25, blue: 0.51)
        case .lateralIncisor:
            Color(red: 0.08, green: 0.62, blue: 0.65)
        case .canine:
            Color(red: 0.23, green: 0.51, blue: 0.96)
        case .firstMolar:
            Color(red: 0.03, green: 0.35, blue: 0.52)
        case .secondMolar:
            Color(red: 0.21, green: 0.21, blue: 0.21)
        }
    }
}

extension ToothKind {
    var familyOutline: ToothFamilyOutline {
        switch self {
        case .centralIncisor: .centralIncisor
        case .lateralIncisor: .lateralIncisor
        case .canine: .canine
        case .firstMolar: .firstMolar
        case .secondMolar: .secondMolar
        }
    }
}
