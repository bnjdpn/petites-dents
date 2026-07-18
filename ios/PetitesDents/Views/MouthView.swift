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
                            lineWidth: 44 * visualScale,
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
        let outerYFraction = arch == .upper
            ? DentalArchGeometry.gumOuterY
            : 1 - DentalArchGeometry.gumOuterY
        let shoulderYFraction = arch == .upper
            ? DentalArchGeometry.gumShoulderY
            : 1 - DentalArchGeometry.gumShoulderY
        let centerYFraction = arch == .upper
            ? DentalArchGeometry.gumCenterY
            : 1 - DentalArchGeometry.gumCenterY
        let outerY = rect.height * outerYFraction
        let shoulderY = rect.height * shoulderYFraction
        let centerY = rect.height * centerYFraction
        var path = Path()
        path.move(to: CGPoint(x: rect.width * DentalArchGeometry.gumOuterX, y: outerY))
        path.addCurve(
            to: CGPoint(x: rect.width * DentalArchGeometry.gumCenterX, y: centerY),
            control1: CGPoint(x: rect.width * DentalArchGeometry.gumControl1X, y: shoulderY),
            control2: CGPoint(x: rect.width * DentalArchGeometry.gumControl2X, y: centerY)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * (1 - DentalArchGeometry.gumOuterX), y: outerY),
            control1: CGPoint(
                x: rect.width * (1 - DentalArchGeometry.gumControl2X),
                y: centerY
            ),
            control2: CGPoint(
                x: rect.width * (1 - DentalArchGeometry.gumControl1X),
                y: shoulderY
            )
        )
        return path
    }
}

private struct ToothButton: View {
    let snapshot: ToothSnapshot
    let toothRotation: CGFloat
    let visualScale: CGFloat
    let action: () -> Void

    private var visualSize: CGSize {
        let baseSize: CGSize
        switch snapshot.definition.kind {
        case .centralIncisor:
            baseSize = CGSize(width: 32, height: 44)
        case .lateralIncisor:
            baseSize = CGSize(width: 30, height: 43)
        case .canine:
            baseSize = CGSize(width: 31, height: 45)
        case .firstMolar:
            baseSize = CGSize(width: 34, height: 46)
        case .secondMolar:
            baseSize = CGSize(width: 36, height: 48)
        }
        return CGSize(width: baseSize.width * visualScale, height: baseSize.height * visualScale)
    }

    var body: some View {
        Button(action: action) {
            Group {
                if snapshot.status == .erupted {
                    Image(
                        snapshot.definition.arch == .upper
                            ? "EruptedToothCharacterUpper"
                            : "EruptedToothCharacter"
                    )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34 * visualScale, height: 40 * visualScale)
                } else {
                    schematicTooth
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

    private var schematicTooth: some View {
        ZStack {
            if snapshot.status == .teething {
                DetailedToothShape()
                    .fill(PetitesDentsStyle.apricot)
            }
            DetailedToothShape()
                .stroke(
                    snapshot.definition.kind.familyOutline.color.opacity(
                        snapshot.status == .ghost ? 0.55 : 1
                    ),
                    style: StrokeStyle(
                        lineWidth: 2.5,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: snapshot.status == .ghost ? [2.5, 2] : []
                    )
                )
        }
        .frame(width: visualSize.width, height: visualSize.height)
        .rotationEffect(.degrees(toothRotation))
    }
}

private struct DetailedToothShape: Shape {
    func path(in rect: CGRect) -> Path {
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
                        marker(for: status)
                        Text(status.localizedName)
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func marker(for status: ToothStatus) -> some View {
        switch status {
        case .ghost:
            Circle()
                .stroke(
                    PetitesDentsStyle.ink.opacity(0.40),
                    style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])
                )
                .frame(width: 12, height: 12)
        case .teething:
            Circle()
                .fill(PetitesDentsStyle.apricot)
                .frame(width: 12, height: 12)
        case .erupted:
            Image("EruptedToothCharacter")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}
