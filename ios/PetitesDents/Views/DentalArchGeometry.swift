import CoreGraphics

struct DentalArchPlacement: Equatable {
    let xFraction: CGFloat
    let yFraction: CGFloat
    let rotationDegrees: CGFloat
}

enum DentalArchGeometry {
    static let gumOuterX: CGFloat = 0.090
    static let gumOuterY: CGFloat = 0.760
    static let gumControl1X: CGFloat = 0.120
    static let gumShoulderY: CGFloat = 0.430
    static let gumControl2X: CGFloat = 0.280
    static let gumCenterX: CGFloat = 0.500
    static let gumCenterY: CGFloat = 0.235

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

    private static let upperYFractions = xFractions.map { upperGumYFraction(atX: $0) }

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

    private static func upperGumYFraction(atX xFraction: CGFloat) -> CGFloat {
        let leftX = min(xFraction, 1 - xFraction)
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<32 {
            let middle = (low + high) / 2
            if cubic(gumOuterX, gumControl1X, gumControl2X, gumCenterX, middle) < leftX {
                low = middle
            } else {
                high = middle
            }
        }
        return cubic(gumOuterY, gumShoulderY, gumCenterY, gumCenterY, (low + high) / 2)
    }

    private static func cubic(
        _ start: CGFloat,
        _ control1: CGFloat,
        _ control2: CGFloat,
        _ end: CGFloat,
        _ t: CGFloat
    ) -> CGFloat {
        let inverse = 1 - t
        return inverse * inverse * inverse * start
            + 3 * inverse * inverse * t * control1
            + 3 * inverse * t * t * control2
            + t * t * t * end
    }
}
