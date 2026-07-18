import SwiftUI

enum PetitesDentsStyle {
    static let coral = Color(red: 1.00, green: 0.45, blue: 0.40)
    static let coralSoft = Color(red: 1.00, green: 0.85, blue: 0.82)
    static let apricot = Color(red: 1.00, green: 0.90, blue: 0.78)
    static let sage = Color(red: 0.51, green: 0.61, blue: 0.48)
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
            Color(red: 176.0 / 255.0, green: 110.0 / 255.0, blue: 97.0 / 255.0)
        case .lateralIncisor:
            Color(red: 99.0 / 255.0, green: 135.0 / 255.0, blue: 125.0 / 255.0)
        case .canine:
            Color(red: 102.0 / 255.0, green: 131.0 / 255.0, blue: 158.0 / 255.0)
        case .firstMolar:
            Color(red: 86.0 / 255.0, green: 108.0 / 255.0, blue: 122.0 / 255.0)
        case .secondMolar:
            Color(red: 123.0 / 255.0, green: 105.0 / 255.0, blue: 96.0 / 255.0)
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
