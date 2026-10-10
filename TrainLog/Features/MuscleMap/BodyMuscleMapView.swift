import SwiftUI
import TrainLogCore

struct MuscleHeatmapViewModel {
    let statistics: [MuscleStatistics]
    let metric: HeatMetric
    var levels: [MuscleGroup: Int] { Dictionary(uniqueKeysWithValues: statistics.map { ($0.muscle, MuscleHeatmapService.level($0, metric: metric)) }) }
    init(sessions: [Session], interval: DateInterval, metric: HeatMetric) {
        statistics = MuscleHeatmapService.statistics(sessions, interval: interval); self.metric = metric
    }
}
struct BodyMuscleMapView: View {
    var view: BodyView
    var levels: [MuscleGroup: Int]
    var selected: Set<MuscleGroup> = []
    var onSelect: (MuscleGroup) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            ZStack {
                MuscleVectorData.contour(MuscleVectorData.outline, in: rect, rounding: 0.5)
                    .fill(Color(uiColor: .tertiarySystemFill))
                Ellipse().fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: proxy.size.width * 0.18, height: proxy.size.height * (54 / 440.0))
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * (30 / 440.0))
                ForEach(MuscleVectorData.regions(for: view)) { region in
                    MuscleRegionShape(region: region)
                        .fill(AppTheme.heat(levels[region.muscleGroup, default: 0], dark: colorScheme == .dark))
                        .overlay { MuscleRegionShape(region: region).strokeBorderCompat(selected.contains(region.muscleGroup) ? Color.primary.opacity(0.65) : AppTheme.card, lineWidth: selected.contains(region.muscleGroup) ? 1.5 : 0.9) }
                        .allowsHitTesting(false)
                }
                // Neutral joint and abdominal separators do not add any training values.
                if view == .front {
                    Path { path in
                        for y in [0.327, 0.36, 0.393] { path.move(to: CGPoint(x: rect.width * 0.397, y: rect.height * y)); path.addLine(to: CGPoint(x: rect.width * 0.603, y: rect.height * y)) }
                    }.stroke(AppTheme.card, lineWidth: 1.1).allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in
                if let muscle = MuscleRegionInteraction.hit(at: tap.location, size: proxy.size, view: view) { onSelect(muscle) }
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("人体\(view.name)肌群图")
            .accessibilityChildren {
                ForEach(Array(Set(MuscleVectorData.regions(for: view).map(\.muscleGroup))).sorted { $0.rawValue < $1.rawValue }) { muscle in
                    Button("\(muscle.name)，\(levels[muscle, default: 0] > 0 ? "已有记录或已选择" : "当前指标无记录")") { onSelect(muscle) }
                        .accessibilityAddTraits(selected.contains(muscle) ? [.isSelected] : [])
                }
            }
        }
        .aspectRatio(200.0 / 440, contentMode: .fit)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: levels)
    }
}
private extension Shape {
    func strokeBorderCompat(_ color: Color, lineWidth: CGFloat) -> some View { stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round)) }
}
struct BodyMuscleFrontView: View {
    var levels: [MuscleGroup: Int]; var onSelect: (MuscleGroup) -> Void
    var body: some View { BodyMuscleMapView(view: .front, levels: levels, onSelect: onSelect) }
}
struct BodyMuscleBackView: View {
    var levels: [MuscleGroup: Int]; var onSelect: (MuscleGroup) -> Void
    var body: some View { BodyMuscleMapView(view: .back, levels: levels, onSelect: onSelect) }
}
struct MuscleMapCard: View {
    var title: String
    var model: MuscleHeatmapViewModel
    var onSelect: (MuscleGroup) -> Void
    var body: some View {
        AppCard {
            SectionHeader(title: title, subtitle: model.metric.name)
            HStack(spacing: 24) {
                VStack { BodyMuscleFrontView(levels: model.levels, onSelect: onSelect); Text("正面").font(.caption).foregroundStyle(.secondary) }
                VStack { BodyMuscleBackView(levels: model.levels, onSelect: onSelect); Text("背面").font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: 360).frame(maxWidth: .infinity)
            HeatLegend(metric: model.metric)
        }
    }
}
struct HeatLegend: View {
    var metric: HeatMetric
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { items }
            VStack(alignment: .leading, spacing: 6) { items }
        }.frame(maxWidth: .infinity, alignment: .center)
    }
    @ViewBuilder private var items: some View {
        ForEach(Array(metric.legend.enumerated()), id: \.offset) { i, text in
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(AppTheme.heat(metric == .coverage && i == 1 ? 3 : i, dark: scheme == .dark)).frame(width: 12, height: 12)
                Text(text).font(.caption2).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine)
        }
    }
}
struct MuscleSelectionList: View {
    @Binding var selection: Set<MuscleGroup>
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            ForEach(MuscleGroup.allCases) { muscle in
                Button { if selection.contains(muscle) { selection.remove(muscle) } else { selection.insert(muscle) } } label: {
                    Label(muscle.name, systemImage: selection.contains(muscle) ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                        .background(selection.contains(muscle) ? Color.blue.opacity(0.12) : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).foregroundStyle(selection.contains(muscle) ? .blue : .primary)
                    .accessibilityAddTraits(selection.contains(muscle) ? [.isSelected] : [])
                    .accessibilityIdentifier("muscle.\(muscle.rawValue)")
            }
        }
    }
}

