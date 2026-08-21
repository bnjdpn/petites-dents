import SwiftUI

struct MouthView: View {
    let snapshots: [ToothSnapshot]
    let permanentSnapshots: [ToothSnapshot]
    let canTrackPermanentTeeth: Bool
    @Binding var phase: ToothPhase
    let onSelect: (ToothSnapshot) -> Void
    let onRequestUnlock: () -> Void

    private var eruptedCount: Int {
        snapshots.filter(\.hasErupted).count
    }

    private var shedCount: Int {
        snapshots.filter { $0.status == .shed }.count
    }

    private var permanentCount: Int {
        permanentSnapshots.filter { $0.status == .erupted }.count
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

                Picker("mouth.phase_picker", selection: $phase) {
                    Text("phase.primary").tag(ToothPhase.primary)
                    Text("phase.permanent").tag(ToothPhase.permanent)
                }
                .pickerStyle(.segmented)
                .padding(.top, 16)
                .accessibilityIdentifier("mouth.phase")

                Text(progressText)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PetitesDentsStyle.coralSoft, in: Capsule())
                    .padding(.top, 16)
                    .accessibilityIdentifier("mouth.progress")

                if phase == .permanent && !canTrackPermanentTeeth {
                    LockedPhaseBanner(onRequestUnlock: onRequestUnlock)
                        .padding(.top, 16)
                }

                MouthCard(
                    snapshots: phase == .primary ? snapshots : permanentSnapshots,
                    phase: phase,
                    isLocked: phase == .permanent && !canTrackPermanentTeeth,
                    onSelect: onSelect,
                    onRequestUnlock: onRequestUnlock
                )
                .padding(.top, 18)

                StatusLegend(phase: phase)
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

    private var progressText: String {
        switch phase {
        case .primary:
            String(
                format: NSLocalizedString("mouth.progress", comment: "Erupted tooth count"),
                eruptedCount,
                shedCount
            )
        case .permanent:
            String(
                format: NSLocalizedString(
                    "mouth.progress_permanent",
                    comment: "Permanent tooth count"
                ),
                permanentCount
            )
        }
    }
}

private struct LockedPhaseBanner: View {
    let onRequestUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("mouth.locked_title", systemImage: "lock")
                .font(.headline)
                .foregroundStyle(PetitesDentsStyle.coral)
            Text("mouth.locked_body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("mouth.locked_button", action: onRequestUnlock)
                .buttonStyle(.borderedProminent)
                .tint(PetitesDentsStyle.coral)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("mouth.unlock")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MouthCard: View {
    let snapshots: [ToothSnapshot]
    let phase: ToothPhase
    let isLocked: Bool
    let onSelect: (ToothSnapshot) -> Void
    let onRequestUnlock: () -> Void

    private var slots: Int {
        phase == .primary ? DentalArchGeometry.primarySlots : DentalArchGeometry.permanentSlots
    }

    private func orderedFDIs(for arch: ToothArch) -> [Int] {
        phase == .primary
            ? DentalArchGeometry.expectedFDIs(for: arch)
            : PermanentToothCatalog.expectedFDIs(for: arch)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToothArchDiagram(
                title: String(localized: "mouth.upper_arch"),
                snapshots: snapshots.filter { $0.definition.arch == .upper },
                arch: .upper,
                slots: slots,
                orderedFDIs: orderedFDIs(for: .upper),
                isLocked: isLocked,
                onSelect: onSelect,
                onRequestUnlock: onRequestUnlock
            )

            ToothArchDiagram(
                title: String(localized: "mouth.lower_arch"),
                snapshots: snapshots.filter { $0.definition.arch == .lower },
                arch: .lower,
                slots: slots,
                orderedFDIs: orderedFDIs(for: .lower),
                isLocked: isLocked,
                onSelect: onSelect,
                onRequestUnlock: onRequestUnlock
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
    let slots: Int
    let orderedFDIs: [Int]
    let isLocked: Bool
    let onSelect: (ToothSnapshot) -> Void
    let onRequestUnlock: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var visualScale: CGFloat {
        horizontalSizeClass == .regular ? 2 : 1
    }

    /// Longer arches keep the same box; only the drawn tooth shrinks with the
    /// slot pitch, so the touch frames stay exactly the size the shipped baby
    /// arch already uses.
    private var archScale: CGFloat {
        DentalArchGeometry.slotPitch(slots: slots)
            / DentalArchGeometry.slotPitch(slots: DentalArchGeometry.primarySlots)
    }

    var body: some View {
        let placements = DentalArchGeometry.placements(for: arch, slots: slots)
        let snapshotsByFDI = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.definition.fdi, $0) }
        )
        let positionedSnapshots = orderedFDIs.enumerated().compactMap { index, fdi in
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

                DentalArchLayout(arch: arch, slots: slots) {
                    ForEach(positionedSnapshots) { positioned in
                        ToothButton(
                            snapshot: positioned.snapshot,
                            toothRotation: placements[positioned.slot].rotationDegrees,
                            visualScale: visualScale,
                            archScale: archScale,
                            isLocked: isLocked
                        ) {
                            if isLocked {
                                onRequestUnlock()
                            } else {
                                onSelect(positioned.snapshot)
                            }
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
    let slots: Int

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
        let placements = DentalArchGeometry.placements(for: arch, slots: slots)
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
        GumOutline.path(in: rect, arch: arch)
    }
}

private struct ToothButton: View {
    let snapshot: ToothSnapshot
    let toothRotation: CGFloat
    let visualScale: CGFloat
    let archScale: CGFloat
    let isLocked: Bool
    let action: () -> Void

    private var visualSize: CGSize {
        let baseSize = snapshot.definition.kind.glyphSize
        return CGSize(
            width: baseSize.width * visualScale * archScale,
            height: baseSize.height * visualScale * archScale
        )
    }

    var body: some View {
        Button(action: action) {
            Group {
                if snapshot.status == .erupted && snapshot.definition.phase == .primary {
                    Image(
                        snapshot.definition.arch == .upper
                            ? "EruptedToothCharacterUpper"
                            : "EruptedToothCharacter"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34 * visualScale * archScale, height: 40 * visualScale * archScale)
                } else {
                    schematicTooth
                }
            }
            .frame(
                width: 44 * visualScale,
                height: 52 * visualScale
            )
            .contentShape(Rectangle())
            .opacity(isLocked ? 0.5 : 1)
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
                ToothOutlineShape()
                    .fill(PetitesDentsStyle.apricot)
            }
            if snapshot.status == .erupted {
                ToothOutlineShape()
                    .fill(Color.white)
            }
            ToothOutlineShape()
                .stroke(
                    strokeColor,
                    style: StrokeStyle(
                        lineWidth: 2.5,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dashPattern
                    )
                )
        }
        .frame(width: visualSize.width, height: visualSize.height)
        .rotationEffect(.degrees(toothRotation))
    }

    private var strokeColor: Color {
        switch snapshot.status {
        case .ghost:
            snapshot.definition.kind.familyOutline.color.opacity(0.55)
        case .shed:
            PetitesDentsStyle.coral
        case .teething, .erupted:
            snapshot.definition.kind.familyOutline.color
        }
    }

    private var dashPattern: [CGFloat] {
        switch snapshot.status {
        case .ghost: [2.5, 2]
        case .shed: [4, 3]
        case .teething, .erupted: []
        }
    }
}

private struct ToothOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        ToothOutline.path(in: rect)
    }
}

private struct StatusLegend: View {
    let phase: ToothPhase

    private var statuses: [ToothStatus] {
        phase == .primary
            ? [.ghost, .teething, .erupted, .shed]
            : [.ghost, .teething, .erupted]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("legend.title")
                .font(.headline)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(statuses, id: \.self) { status in
                    HStack(spacing: 6) {
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
        case .shed:
            Circle()
                .stroke(PetitesDentsStyle.coral, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 12, height: 12)
        }
    }
}
