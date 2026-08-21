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

    /// Slot count of the primary (baby) arch. It is the default everywhere so
    /// the shipped arch keeps its exact geometry.
    static let primarySlots = 10
    /// Slot count of the permanent arch: incisors, canine, both premolars and
    /// the six-year molar, per quadrant.
    static let permanentSlots = 12

    private static let upperFDIs = [65, 64, 63, 62, 61, 51, 52, 53, 54, 55]
    private static let lowerFDIs = [75, 74, 73, 72, 71, 81, 82, 83, 84, 85]

    /// Outermost and innermost tooth centre, as a fraction of the layout
    /// width. Every slot count spreads its half-arch between these two, on the
    /// same gum curve, so arches of different lengths stay concentric.
    private static let outerXFraction: CGFloat = 0.090
    private static let innerXFraction: CGFloat = 0.450

    /// Tangent of the gum curve sampled at the five primary half-arch slots.
    /// Longer arches interpolate along this profile, which reproduces the
    /// original table exactly when the sample points line up (10 slots).
    private static let halfTangentRotations: [CGFloat] = [-17, -14, -10, -6, -2]

    static func xFractions(slots: Int = primarySlots) -> [CGFloat] {
        let half = halfCount(for: slots)
        let left = (0..<half).map { index -> CGFloat in
            outerXFraction
                + (innerXFraction - outerXFraction) * CGFloat(index) / CGFloat(half - 1)
        }
        return left + left.reversed().map { 1 - $0 }
    }

    static func tangentRotations(slots: Int = primarySlots) -> [CGFloat] {
        let half = halfCount(for: slots)
        let left = (0..<half).map { index -> CGFloat in
            interpolatedTangent(atHalfPosition: CGFloat(index) / CGFloat(half - 1))
        }
        return left + left.reversed().map { -$0 }
    }

    static func placements(
        for arch: ToothArch,
        slots: Int = primarySlots
    ) -> [DentalArchPlacement] {
        let xFractions = xFractions(slots: slots)
        let rotations = tangentRotations(slots: slots)
        return xFractions.indices.map { index in
            let upperY = upperGumYFraction(atX: xFractions[index])
            return DentalArchPlacement(
                xFraction: xFractions[index],
                yFraction: arch == .upper ? upperY : 1 - upperY,
                rotationDegrees: arch == .upper
                    ? 180 + rotations[index]
                    : -rotations[index]
            )
        }
    }

    static func height(forWidth width: CGFloat) -> CGFloat {
        max(width * 0.52, 164)
    }

    static func expectedFDIs(for arch: ToothArch) -> [Int] {
        arch == .upper ? upperFDIs : lowerFDIs
    }

    /// Horizontal distance between two neighbouring slots, as a fraction of
    /// the layout width.
    static func slotPitch(slots: Int = primarySlots) -> CGFloat {
        (innerXFraction - outerXFraction) / CGFloat(halfCount(for: slots) - 1)
    }

    /// Width an arch of `slots` teeth needs so its touch targets stay as wide
    /// as the shipped primary arch gets at `availableWidth`. Arches longer
    /// than the primary one are meant to be scrolled horizontally rather than
    /// squeezed into targets nobody can hit.
    static func layoutWidth(slots: Int, availableWidth: CGFloat) -> CGFloat {
        guard availableWidth.isFinite, availableWidth > 0 else { return availableWidth }
        let ratio = slotPitch(slots: primarySlots) / slotPitch(slots: slots)
        return availableWidth * max(ratio, 1)
    }

    private static func halfCount(for slots: Int) -> Int {
        max(slots / 2, 2)
    }

    private static func interpolatedTangent(atHalfPosition position: CGFloat) -> CGFloat {
        let lastIndex = halfTangentRotations.count - 1
        let scaled = min(max(position, 0), 1) * CGFloat(lastIndex)
        let lowerIndex = min(Int(scaled), lastIndex - 1)
        let fraction = scaled - CGFloat(lowerIndex)
        let start = halfTangentRotations[lowerIndex]
        let end = halfTangentRotations[lowerIndex + 1]
        return start + (end - start) * fraction
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
