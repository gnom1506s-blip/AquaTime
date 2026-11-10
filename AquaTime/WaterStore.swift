import SwiftUI
import WidgetKit

let appGroup = "group.com.example.aquatime"
let sharedDefaults = UserDefaults(suiteName: appGroup) ?? .standard

struct Reminder: Identifiable {
    let id = UUID()
    let time: Date
    let amount: Int
}

final class WaterStore: ObservableObject {
    static let shared = WaterStore()
    @Published var iconError: String?
    @AppStorage("healthOn", store: sharedDefaults) var healthOn = false { willSet { objectWillChange.send() } }

    @AppStorage("onboarded", store: sharedDefaults) var onboarded = false { willSet { objectWillChange.send() } }
    @AppStorage("goal", store: sharedDefaults) var goal = 2000 { willSet { objectWillChange.send() } }
    @AppStorage("wakeMinutes", store: sharedDefaults) var wakeMinutes = 8 * 60 { willSet { objectWillChange.send() } }
    @AppStorage("sleepMinutes", store: sharedDefaults) var sleepMinutes = 22 * 60 { willSet { objectWillChange.send() } }
    @AppStorage("intervalMinutes", store: sharedDefaults) var intervalMinutes = 90 { willSet { objectWillChange.send() } }
    @AppStorage("notificationsOn", store: sharedDefaults) var notificationsOn = true { willSet { objectWillChange.send() } }
    @AppStorage("drunkToday", store: sharedDefaults) private var drunkStored = 0
    @AppStorage("lastDay", store: sharedDefaults) private var lastDay = ""
    @AppStorage("streak", store: sharedDefaults) var streak = 0 { willSet { objectWillChange.send() } }
    @AppStorage("historyJSON", store: sharedDefaults) private var historyJSON = "{}"

    private init() { rolloverIfNeeded() }

    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    private var todayKey: String { Self.dayFmt.string(from: Date()) }

    var drunk: Int { rolloverIfNeeded(); return drunkStored }
    var progress: Double { min(Double(drunk) / Double(max(goal, 1)), 1) }

    /// История за последние дни: дата -> мл
    var history: [String: Int] {
        (try? JSONDecoder().decode([String: Int].self, from: Data(historyJSON.utf8))) ?? [:]
    }

    @discardableResult
    func rolloverIfNeeded() -> Bool {
        guard lastDay != todayKey else { return false }
        if !lastDay.isEmpty {
            var h = history; h[lastDay] = drunkStored
            if let d = try? JSONEncoder().encode(h) { historyJSON = String(decoding: d, as: UTF8.self) }
            // серия: была ли вчера выполнена цель
            let yesterday = Self.dayFmt.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
            if !(lastDay == yesterday && drunkStored >= goal) { streak = 0 }
        }
        lastDay = todayKey
        drunkStored = 0
        return true
    }

    func add(_ ml: Int) {
        rolloverIfNeeded()
        objectWillChange.send()
        let wasDone = drunkStored >= goal
        drunkStored = max(0, drunkStored + ml)
        if !wasDone && drunkStored >= goal { streak += 1 }
        if wasDone && drunkStored < goal { streak = max(0, streak - 1) }
        if ml > 0 && healthOn { HealthManager.shared.saveWater(ml) }
        WidgetCenter.shared.reloadAllTimelines()
        updateIcon()
        DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    /// Разбивает дневную цель на равные порции по времени бодрствования
    var reminders: [Reminder] {
        let start = wakeMinutes
        var end = sleepMinutes
        if end <= start { end += 24 * 60 }
        var times: [Int] = []
        var t = start
        while t <= end { times.append(t); t += intervalMinutes }
        guard !times.isEmpty else { return [] }
        let portion = Int((Double(goal) / Double(times.count) / 10).rounded()) * 10
        let today = Calendar.current.startOfDay(for: Date())
        return times.map { Reminder(time: today.addingTimeInterval(Double($0 % (24*60)) * 60), amount: portion) }
    }

    func reschedule() {
        NotificationManager.shared.schedule(reminders: notificationsOn ? reminders : [], goal: goal)
    }

    /// Стадия растения: 0 — грустное, 1 — росток, 2 — растение, 3 — цветёт
    var stage: Int { Self.stage(for: progress) }
    static func stage(for p: Double) -> Int { p >= 1 ? 3 : p >= 0.6 ? 2 : p >= 0.25 ? 1 : 0 }

    /// Меняет иконку на домашнем экране (только когда приложение открыто)
    func updateIcon() {
        DispatchQueue.main.async {
            let app = UIApplication.shared
            guard app.applicationState == .active else { return }
            guard app.supportsAlternateIcons else { self.iconError = "iOS сообщает: смена иконки не поддерживается этой установкой"; return }
            let name: String? = self.stage == 1 ? nil : "Icon\(self.stage)"
            if app.alternateIconName != name {
                app.setAlternateIconName(name) { err in
                    if let err { DispatchQueue.main.async { self.iconError = err.localizedDescription } }
                }
            }
        }
    }

    var mood: (emoji: String, text: String) {
        switch progress {
        case 0: return ("🥀", "Я засыхаю... Налей мне воды!")
        case ..<0.25: return ("🌱", "Хорошее начало! Продолжай")
        case ..<0.5: return ("🌿", "Растём! Ещё пара стаканов")
        case ..<0.75: return ("🪴", "Больше половины — ты молодец!")
        case ..<1: return ("🌳", "Почти у цели! Финишная прямая")
        default: return ("🏆", "Цель выполнена! Ты — чемпион гидратации")
        }
    }
}

extension Int {
    var clockString: String { String(format: "%02d:%02d", (self / 60) % 24, self % 60) }
}
