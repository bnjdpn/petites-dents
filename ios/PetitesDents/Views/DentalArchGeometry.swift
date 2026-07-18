import CoreGraphics

struct DentalArchPlacement: Equatable {
    let xFraction: CGFloat
    let yFraction: CGFloat
    let rotationDegrees: CGFloat
}

enum DentalArchGeometry {
    private static let upperFDIs = [65, 64, 63, 62, 61, 51, 52, 53, 54, 55]
    private static let lowerFDIs = [75, 74, 73, 72, 71, 81, 82, 83, 84, 85]

    private static let xFractions: [CGFloat] = [
        0.090,
        0.180,
        0.270,
        0.360,
        0.450,
        0.550,
        0.640,
        0.730,
        0.820,
        0.910,
    ]

    private static let upperYFractions: [CGFloat] = [
        0.760,
        0.590,
        0.430,
        0.310,
        0.235,
        0.235,
        0.310,
        0.430,
        0.590,
        0.760,
    ]

    private static let tangentRotations: [CGFloat] = [
        -17,
        -14,
        -10,
        -6,
        -2,
        2,
        6,
        10,
        14,
        17,
    ]

    static func placements(for arch: ToothArch) -> [DentalArchPlacement] {
        xFractions.indices.map { index in
            let upperY = upperYFractions[index]
            return DentalArchPlacement(
                xFraction: xFractions[index],
                yFraction: arch == .upper ? upperY : 1 - upperY,
                rotationDegrees: arch == .upper
                    ? 180 + tangentRotations[index]
                    : -tangentRotations[index]
            )
        }
    }

    static func height(forWidth width: CGFloat) -> CGFloat {
        max(width * 0.52, 164)
    }

    static func expectedFDIs(for arch: ToothArch) -> [Int] {
        arch == .upper ? upperFDIs : lowerFDIs
    }
}
