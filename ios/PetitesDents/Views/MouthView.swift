import SwiftUI

struct MouthView: View {
    let snapshots: [ToothSnapshot]
    let onSelect: (ToothSnapshot) -> Void

    private var eruptedCount: Int {
        snapshots.filter { $0.status == .erupted }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("mouth.title")
                    .font(.largeTitle.bold())
                Text("mouth.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)

                Text(
                    String(
                        format: NSLocalizedString("mouth.progress", comment: "Erupted tooth count"),
                        eruptedCount
                    )
                )
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(PetitesDentsStyle.coralSoft, in: Capsule())
                .padding(.top, 16)

                MouthCard(snapshots: snapshots, onSelect: onSelect)
                    .padding(.top, 18)

                StatusLegend()
                    .padding(.top, 20)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .frame(maxWidth: .infinity)
        }
        .background(PetitesDentsStyle.cream.ignoresSafeArea())
        .accessibilityIdentifier("screen.mouth")
    }
}

private struct MouthCard: View {
    let snapshots: [ToothSnapshot]
    let onSelect: (ToothSnapshot) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ToothArchDiagram(
                title: String(localized: "mouth.upper_arch"),
                snapshots: snapshots.filter { $0.definition.arch == .upper },
                arch: .upper,
                onSelect: onSelect
            )

            ToothArchDiagram(
                title: String(localized: "mouth.lower_arch"),
                snapshots: snapshots.filter { $0.definition.arch == .lower },
                arch: .lower,
                onSelect: onSelect
            )
        }
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}

private struct ToothArchDiagram: View {
    let title: String
    let snapshots: [ToothSnapshot]
    let arch: ToothArch
    let onSelect: (ToothSnapshot) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var visualScale: CGFloat {
        horizontalSizeClass == .regular ? 2 : 1
    }

    var body: some View {
        let placements = DentalArchGeometry.placements(for: arch)
        let snapshotsByFDI = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.definition.fdi, $0) })
        let positionedSnapshots = DentalArchGeometry.expectedFDIs(for: arch).enumerated().compactMap {
            index, fdi in
            snapshotsByFDI[fdi].map { PositionedToothSnapshot(slot: index, snapshot: $0) }
        }

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)

            ZStack {
                ArchGumShape(arch: arch)
                    .stroke(
                        PetitesDentsStyle.coralSoft.opacity(0.72),
                        style: StrokeStyle(
                            lineWidth: 42 * visualScale,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .allowsHitTesting(false)

                DentalArchLayout(arch: arch) {
                    ForEach(positionedSnapshots) { positioned in
                        ToothButton(
                            snapshot: positioned.snapshot,
                            toothRotation: placements[positioned.slot].rotationDegrees,
                            visualScale: visualScale
                        ) {
                            onSelect(positioned.snapshot)
                        }
                        .layoutValue(key: DentalArchSlotKey.self, value: positioned.slot)
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct PositionedToothSnapshot: Identifiable {
    let slot: Int
    let snapshot: ToothSnapshot

    var id: String { snapshot.id }
}

private struct DentalArchSlotKey: LayoutValueKey {
    static let defaultValue = 0
}

private struct DentalArchLayout: Layout {
    let arch: ToothArch

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let proposedWidth = proposal.width ?? 350
        let width = proposedWidth.isFinite ? proposedWidth : 350
        return CGSize(width: width, height: DentalArchGeometry.height(forWidth: width))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let placements = DentalArchGeometry.placements(for: arch)
        for subview in subviews {
            let index = subview[DentalArchSlotKey.self]
            guard placements.indices.contains(index) else { continue }
            let placement = placements[index]
            subview.place(
                at: CGPoint(
                    x: bounds.minX + bounds.width * placement.xFraction,
                    y: bounds.minY + bounds.height * placement.yFraction
                ),
                anchor: .center,
                proposal: .unspecified
            )
        }
    }
}

private struct ArchGumShape: Shape {
    let arch: ToothArch

    func path(in rect: CGRect) -> Path {
        let outerY = arch == .upper ? rect.height * 0.76 : rect.height * 0.24
        let shoulderY = arch == .upper ? rect.height * 0.43 : rect.height * 0.57
        let centerY = arch == .upper ? rect.height * 0.235 : rect.height * 0.765
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.090, y: outerY))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.50, y: centerY),
            control1: CGPoint(x: rect.width * 0.12, y: shoulderY),
            control2: CGPoint(x: rect.width * 0.28, y: centerY)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.910, y: outerY),
            control1: CGPoint(x: rect.width * 0.72, y: centerY),
            control2: CGPoint(x: rect.width * 0.88, y: shoulderY)
        )
        return path
    }
}

private struct ToothButton: View {
    let snapshot: ToothSnapshot
    let toothRotation: CGFloat
    let visualScale: CGFloat
    let action: () -> Void

    private var fill: Color {
        switch snapshot.status {
        case .ghost: Color.secondary.opacity(0.07)
        case .teething: PetitesDentsStyle.apricot
        case .erupted: PetitesDentsStyle.sage.opacity(0.30)
        }
    }

    private var strokeColor: Color {
        switch snapshot.status {
        case .ghost: Color.secondary
        case .teething: PetitesDentsStyle.coral
        case .erupted: PetitesDentsStyle.sage
        }
    }

    private var visualSize: CGSize {
        let baseSize: CGSize
        switch snapshot.definition.kind {
        case .centralIncisor:
            baseSize = CGSize(width: 27, height: 39)
        case .lateralIncisor:
            baseSize = CGSize(width: 24, height: 37)
        case .canine:
            baseSize = CGSize(width: 26, height: 41)
        case .firstMolar:
            baseSize = CGSize(width: 31, height: 40)
        case .secondMolar:
            baseSize = CGSize(width: 34, height: 43)
        }
        return CGSize(width: baseSize.width * visualScale, height: baseSize.height * visualScale)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                ZStack {
                    ToothShape(kind: snapshot.definition.kind)
                        .fill(fill)
                    ToothShape(kind: snapshot.definition.kind)
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(
                                lineWidth: snapshot.status == .erupted ? 2.5 : 2,
                                dash: snapshot.status == .ghost ? [5, 4] : []
                            )
                        )
                }
                .frame(width: visualSize.width, height: visualSize.height)
                .rotationEffect(.degrees(toothRotation))

                if snapshot.status == .erupted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(PetitesDentsStyle.sage)
                }
            }
            .frame(
                width: 44 * visualScale,
                height: 52 * visualScale
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tooth-\(snapshot.definition.fdi)")
        .accessibilityLabel(
            String(
                format: NSLocalizedString("tooth.accessibility", comment: "Accessible tooth label"),
                snapshot.definition.localizedName,
                snapshot.definition.fdi,
                snapshot.status.localizedName
            )
        )
        .accessibilityValue(snapshot.status.localizedName)
    }
}

private struct ToothShape: Shape {
    let kind: ToothKind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .centralIncisor, .lateralIncisor:
            incisorPath(in: rect)
        case .canine:
            caninePath(in: rect)
        case .firstMolar, .secondMolar:
            molarPath(in: rect)
        }
    }

    private func incisorPath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.04))
        path.addCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.29),
            control1: CGPoint(x: w * 0.28, y: -h * 0.01),
            control2: CGPoint(x: w * 0.10, y: h * 0.11)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.40, y: h * 0.94),
            control1: CGPoint(x: w * 0.17, y: h * 0.49),
            control2: CGPoint(x: w * 0.28, y: h * 0.70)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.60, y: h * 0.94),
            control1: CGPoint(x: w * 0.44, y: h * 1.01),
            control2: CGPoint(x: w * 0.56, y: h * 1.01)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.29),
            control1: CGPoint(x: w * 0.72, y: h * 0.70),
            control2: CGPoint(x: w * 0.83, y: h * 0.49)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.04),
            control1: CGPoint(x: w * 0.90, y: h * 0.11),
            control2: CGPoint(x: w * 0.72, y: -h * 0.01)
        )
        path.closeSubpath()
        return path
    }

    private func caninePath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.01))
        path.addCurve(
            to: CGPoint(x: w * 0.13, y: h * 0.34),
            control1: CGPoint(x: w * 0.40, y: h * 0.10),
            control2: CGPoint(x: w * 0.10, y: h * 0.13)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.43, y: h * 0.96),
            control1: CGPoint(x: w * 0.17, y: h * 0.56),
            control2: CGPoint(x: w * 0.31, y: h * 0.77)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.57, y: h * 0.96),
            control1: CGPoint(x: w * 0.46, y: h * 1.01),
            control2: CGPoint(x: w * 0.54, y: h * 1.01)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.87, y: h * 0.34),
            control1: CGPoint(x: w * 0.69, y: h * 0.77),
            control2: CGPoint(x: w * 0.83, y: h * 0.56)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.01),
            control1: CGPoint(x: w * 0.90, y: h * 0.13),
            control2: CGPoint(x: w * 0.60, y: h * 0.10)
        )
        path.closeSubpath()
        return path
    }

    private func molarPath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.08))
        path.addCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.35),
            control1: CGPoint(x: w * 0.28, y: -h * 0.02),
            control2: CGPoint(x: w * 0.10, y: h * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.93),
            control1: CGPoint(x: w * 0.18, y: h * 0.58),
            control2: CGPoint(x: w * 0.26, y: h * 0.88)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.70),
            control1: CGPoint(x: w * 0.46, y: h * 0.96),
            control2: CGPoint(x: w * 0.44, y: h * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.93),
            control1: CGPoint(x: w * 0.56, y: h * 0.72),
            control2: CGPoint(x: w * 0.54, y: h * 0.96)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.35),
            control1: CGPoint(x: w * 0.74, y: h * 0.88),
            control2: CGPoint(x: w * 0.82, y: h * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.08),
            control1: CGPoint(x: w * 0.90, y: h * 0.12),
            control2: CGPoint(x: w * 0.72, y: -h * 0.02)
        )
        path.closeSubpath()
        return path
    }
}

private struct StatusLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("legend.title")
                .font(.headline)
            HStack(spacing: 16) {
                ForEach(ToothStatus.allCases, id: \.self) { status in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(color(for: status))
                            .frame(width: 12, height: 12)
                        Text(status.localizedName)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func color(for status: ToothStatus) -> Color {
        switch status {
        case .ghost: Color.secondary.opacity(0.35)
        case .teething: PetitesDentsStyle.apricot
        case .erupted: PetitesDentsStyle.sage
        }
    }
}
