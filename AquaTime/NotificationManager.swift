import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    static let category = "WATER"
    static let drinkAction = "DRINK"
    static let snoozeAction = "SNOOZE"

    func registerCategories() {
        let drink = UNNotificationAction(identifier: Self.drinkAction, title: "💧 Выпил!", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "⏰ Через 15 минут", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [drink, snooze], intentIdentifiers: [])])
    }

    func snooze(amount: Int) {
        let c = UNMutableNotificationContent()
        c.title = "AquaTime"; c.body = "⏰ Напоминаю ещё раз: выпей \(amount) мл"
        c.sound = .default; c.categoryIdentifier = Self.category; c.userInfo = ["amount": amount]
        center.add(UNNotificationRequest(identifier: "snooze", content: c,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)))
    }
    private let center = UNUserNotificationCenter.current()

    private let phrases = [
        "💧 Время пить воду! Выпей %d мл",
        "🐳 Даже кит пьёт воду. Твоя порция: %d мл",
        "🌊 Глоток бодрости! %d мл ждут тебя",
        "🧠 Мозг на 75%% состоит из воды. Подзаряди его: %d мл",
        "🌵 Не будь кактусом! Выпей %d мл",
        "⚡️ Усталость? Возможно, это жажда. %d мл — и вперёд!",
        "🥤 Стаканчик воды — %d мл — и ты на шаг ближе к цели",
    ]

    func requestPermission(then: @escaping () -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async(execute: then)
        }
    }

    func schedule(reminders: [Reminder], goal: Int) {
        center.removePendingNotificationRequests(withIdentifiers: (0..<64).map { "water-\($0)" })
        for (i, r) in reminders.prefix(60).enumerated() {   // лимит iOS — 64 уведомления
            let content = UNMutableNotificationContent()
            content.title = "AquaTime"
            content.body = String(format: phrases[i % phrases.count], r.amount)
            content.subtitle = "Порция \(i + 1) из \(reminders.count) • цель \(goal) мл"
            content.sound = .default
            content.categoryIdentifier = Self.category
            content.userInfo = ["amount": r.amount]
            let comps = Calendar.current.dateComponents([.hour, .minute], from: r.time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: "water-\(i)", content: content, trigger: trigger))
        }
    }
}
