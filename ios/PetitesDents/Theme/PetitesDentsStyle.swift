import SwiftUI
import UIKit

enum PetitesDentsStyle {
    static let coral = Color(red: 1.00, green: 0.45, blue: 0.40)
    static let coralSoft = Color(red: 1.00, green: 0.85, blue: 0.82)
    static let apricot = Color(red: 1.00, green: 0.90, blue: 0.78)
    static let sage = Color(red: 0.51, green: 0.61, blue: 0.48)
    static let cream = Color(red: 1.00, green: 0.98, blue: 0.95)
    static let ink = Color(red: 0.20, green: 0.17, blue: 0.16)

    // Print-side equivalents. The keepsake sheet is drawn with Core Graphics,
    // so it needs the very same palette as the screen.
    static let uiCoral = UIColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1)
    static let uiCoralSoft = UIColor(red: 1.00, green: 0.85, blue: 0.82, alpha: 1)
    static let uiApricot = UIColor(red: 1.00, green: 0.90, blue: 0.78, alpha: 1)
    static let uiSage = UIColor(red: 0.51, green: 0.61, blue: 0.48, alpha: 1)
    static let uiCream = UIColor(red: 1.00, green: 0.98, blue: 0.95, alpha: 1)
    static let uiInk = UIColor(red: 0.20, green: 0.17, blue: 0.16, alpha: 1)
    static let uiInkSoft = UIColor(red: 0.42, green: 0.38, blue: 0.36, alpha: 1)
}

enum ToothFamilyOutline: String, CaseIterable {
    case centralIncisor
    case lateralIncisor
    case canine
    case firstPremolar
    case secondPremolar
    case firstMolar
    case secondMolar

    var color: Color {
        Color(uiColor: uiColor)
    }

    var uiColor: UIColor {
        switch self {
        case .centralIncisor:
            UIColor(red: 176.0 / 255.0, green: 110.0 / 255.0, blue: 97.0 / 255.0, alpha: 1)
        case .lateralIncisor:
            UIColor(red: 99.0 / 255.0, green: 135.0 / 255.0, blue: 125.0 / 255.0, alpha: 1)
        case .canine:
            UIColor(red: 102.0 / 255.0, green: 131.0 / 255.0, blue: 158.0 / 255.0, alpha: 1)
        case .firstPremolar:
            UIColor(red: 140.0 / 255.0, green: 122.0 / 255.0, blue: 158.0 / 255.0, alpha: 1)
        case .secondPremolar:
            UIColor(red: 108.0 / 255.0, green: 141.0 / 255.0, blue: 106.0 / 255.0, alpha: 1)
        case .firstMolar:
            UIColor(red: 86.0 / 255.0, green: 108.0 / 255.0, blue: 122.0 / 255.0, alpha: 1)
        case .secondMolar:
            UIColor(red: 123.0 / 255.0, green: 105.0 / 255.0, blue: 96.0 / 255.0, alpha: 1)
        }
    }
}

extension ToothKind {
    var familyOutline: ToothFamilyOutline {
        switch self {
        case .centralIncisor: .centralIncisor
        case .lateralIncisor: .lateralIncisor
        case .canine: .canine
        case .firstPremolar: .firstPremolar
        case .secondPremolar: .secondPremolar
        case .firstMolar: .firstMolar
        case .secondMolar: .secondMolar
        }
    }

    /// Drawn size of the tooth glyph, before any arch scaling.
    var glyphSize: CGSize {
        switch self {
        case .centralIncisor: CGSize(width: 32, height: 44)
        case .lateralIncisor: CGSize(width: 30, height: 43)
        case .canine: CGSize(width: 31, height: 45)
        case .firstPremolar: CGSize(width: 32, height: 45)
        case .secondPremolar: CGSize(width: 33, height: 46)
        case .firstMolar: CGSize(width: 34, height: 46)
        case .secondMolar: CGSize(width: 36, height: 48)
        }
    }
}

/// The single tooth silhouette of the app, shared by the interactive arch and
/// by the printed keepsake so the sheet is recognisably the same drawing.
enum ToothOutline {
    static func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.06))
        path.addCurve(
            to: CGPoint(x: w * 0.13, y: h * 0.36),
            control1: CGPoint(x: w * 0.25, y: -h * 0.03),
            control2: CGPoint(x: w * 0.08, y: h * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.32, y: h * 0.96),
            control1: CGPoint(x: w * 0.18, y: h * 0.62),
            control2: CGPoint(x: w * 0.22, y: h * 0.90)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.60),
            control1: CGPoint(x: w * 0.40, y: h),
            control2: CGPoint(x: w * 0.41, y: h * 0.64)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.68, y: h * 0.96),
            control1: CGPoint(x: w * 0.59, y: h * 0.64),
            control2: CGPoint(x: w * 0.60, y: h)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.87, y: h * 0.36),
            control1: CGPoint(x: w * 0.78, y: h * 0.90),
            control2: CGPoint(x: w * 0.82, y: h * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.06),
            control1: CGPoint(x: w * 0.92, y: h * 0.12),
            control2: CGPoint(x: w * 0.75, y: -h * 0.03)
        )
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }

    static func cgPath(in rect: CGRect) -> CGPath {
        path(in: rect).cgPath
    }
}

/// The gum horseshoe, shared by the arch view and the keepsake sheet.
enum GumOutline {
    static func path(in rect: CGRect, arch: ToothArch) -> Path {
        let outerYFraction = arch == .upper
            ? DentalArchGeometry.gumOuterY
            : 1 - DentalArchGeometry.gumOuterY
        let shoulderYFraction = arch == .upper
            ? DentalArchGeometry.gumShoulderY
            : 1 - DentalArchGeometry.gumShoulderY
        let centerYFraction = arch == .upper
            ? DentalArchGeometry.gumCenterY
            : 1 - DentalArchGeometry.gumCenterY
        let outerY = rect.minY + rect.height * outerYFraction
        let shoulderY = rect.minY + rect.height * shoulderYFraction
        let centerY = rect.minY + rect.height * centerYFraction
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * DentalArchGeometry.gumOuterX, y: outerY))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * DentalArchGeometry.gumCenterX, y: centerY),
            control1: CGPoint(
                x: rect.minX + rect.width * DentalArchGeometry.gumControl1X,
                y: shoulderY
            ),
            control2: CGPoint(
                x: rect.minX + rect.width * DentalArchGeometry.gumControl2X,
                y: centerY
            )
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * (1 - DentalArchGeometry.gumOuterX), y: outerY),
            control1: CGPoint(
                x: rect.minX + rect.width * (1 - DentalArchGeometry.gumControl2X),
                y: centerY
            ),
            control2: CGPoint(
                x: rect.minX + rect.width * (1 - DentalArchGeometry.gumControl1X),
                y: shoulderY
            )
        )
        return path
    }

    static func cgPath(in rect: CGRect, arch: ToothArch) -> CGPath {
        path(in: rect, arch: arch).cgPath
    }
}
