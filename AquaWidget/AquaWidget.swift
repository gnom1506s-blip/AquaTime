import WidgetKit
import SwiftUI

private let defaults = UserDefaults(suiteName: "group.com.example.aquatime") ?? .standard

struct WaterEntry: TimelineEntry {
    let date: Date
    let drunk: Int
    let goal: Int
    let streak: Int
    var progress: Double { min(Double(drunk) / Double(max(goal, 1)), 1) }
}

struct Provider: TimelineProvider {
    func current() -> WaterEntry {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let isToday = defaults.string(forKey: "lastDay") == f.string(from: Date())
        let goal = defaults.integer(forKey: "goal")
        return WaterEntry(date: Date(), drunk: isToday ? defaults.integer(forKey: "drunkToday") : 0,
                          goal: goal == 0 ? 2000 : goal, streak: defaults.integer(forKey: "streak"))
    }
    func placeholder(in context: Context) -> WaterEntry { WaterEntry(date: Date(), drunk: 1200, goal: 2000, streak: 3) }
    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        // обновление каждые 30 минут + сразу после каждого стакана из приложения
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct AquaWidgetView: View {
    let entry: WaterEntry
    @Environment(\.widgetFamily) var family
    var body: some View {
        let ring = ZStack {
            Circle().stroke(Color.cyan.opacity(0.2), lineWidth: 10)
            Circle().trim(from: 0, to: entry.progress)
                .stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(entry.progress >= 1 ? "🏆" : "💧").font(.title)
        }
        Group {
            if family == .systemMedium {
                HStack(spacing: 16) {
                    ring.frame(width: 100, height: 100)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(entry.drunk) / \(entry.goal) мл").font(.headline)
                        Text("🔥 \(entry.streak) дн. подряд").font(.subheadline).foregroundStyle(.orange)
                        Link(destination: URL(string: "aquatime://add")!) {
                            Text("+250 мл").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6)
                                .background(.cyan, in: Capsule()).foregroundStyle(.white)
                        }
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 6) {
                    ring.frame(width: 80, height: 80)
                    Text("\(entry.drunk) / \(entry.goal)").font(.caption.bold())
                }
            }
        }
        .containerBackground(for: .widget) { Color.cyan.opacity(0.08) }
    }
}

@main
struct AquaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AquaWidget", provider: Provider()) { AquaWidgetView(entry: $0) }
            .configurationDisplayName("AquaTime")
            .description("Сколько воды ты выпил сегодня")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
