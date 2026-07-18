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
        VStack(spacing: 8) {
            ToothArchRow(
                title: String(localized: "mouth.upper_arch"),
                snapshots: snapshots.filter { $0.definition.arch == .upper },
                isUpper: true,
                onSelect: onSelect
            )

            Capsule()
                .fill(PetitesDentsStyle.coralSoft.opacity(0.65))
                .frame(height: 42)
                .padding(.horizontal, 28)

            ToothArchRow(
                title: String(localized: "mouth.lower_arch"),
                snapshots: snapshots.filter { $0.definition.arch == .lower },
                isUpper: false,
                onSelect: onSelect
            )

            Text("mouth.scroll_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}

private struct ToothArchRow: View {
    let title: String
    let snapshots: [ToothSnapshot]
    let isUpper: Bool
    let onSelect: (ToothSnapshot) -> Void

    private var offsets: [CGFloat] {
        isUpper ? [11, 7, 4, 2, 0, 0, 2, 4, 7, 11] : [0, 2, 4, 7, 11, 11, 7, 4, 2, 0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                        ToothButton(snapshot: snapshot) {
                            onSelect(snapshot)
                        }
                        .padding(.top, offsets[index])
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }
}

private struct ToothButton: View {
    let snapshot: ToothSnapshot
    let action: () -> Void

    private var fill: Color {
        switch snapshot.status {
        case .ghost: Color.secondary.opacity(0.08)
        case .teething: PetitesDentsStyle.apricot
        case .erupted: Color(red: 1, green: 0.995, blue: 0.97)
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                ToothShape()
                    .fill(fill)
                ToothShape()
                    .stroke(
                        snapshot.status == .teething ? PetitesDentsStyle.coral : Color.secondary,
                        style: StrokeStyle(
                            lineWidth: snapshot.status == .erupted ? 2.5 : 2,
                            dash: snapshot.status == .ghost ? [5, 4] : []
                        )
                    )
                if snapshot.status == .erupted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(PetitesDentsStyle.sage)
                }
            }
            .frame(width: 36, height: 46)
            .frame(width: 48, height: 58)
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
    func path(in rect: CGRect) -> Path {
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
