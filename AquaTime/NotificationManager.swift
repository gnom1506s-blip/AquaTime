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

    private let teases = [
        "Эй, %@, ты где? Вода сама себя не выпьет 😏",
        "Так-так, %@... Напоминание было полчаса назад 👀",
        "Растение смотрит на тебя с укором, %@ 🥀",
        "%@, приём! Стакан воды ждёт уже 30 минут",
        "Ну что, %@, опять игнорируем воду? 🙄",
        "Даже рыбка в аквариуме пьёт больше, чем ты, %@ 🐠",
        "Внимание! Обнаружен %@. Срочно полить! 🚿",
    ]

    /// Подколы через 30 минут после напоминания, если вода не отмечена.
    /// Пересоздаются на сегодня и завтра при каждом открытии приложения и каждом стакане.
    func scheduleTeases(reminders: [Reminder], drunk: Int) {
        center.getPendingNotificationRequests { reqs in
            self.center.removePendingNotificationRequests(withIdentifiers: reqs.map(\.identifier).filter { $0.hasPrefix("tease-") })
            let now = Date()
            var n = 0
            for day in 0...1 {
                for (i, r) in reminders.enumerated() {
                    let fire = r.time.addingTimeInterval(Double(day) * 86400 + 30 * 60)
                    guard fire > now, n < 20 else { continue }
                    if day == 0 && drunk >= r.amount * (i + 1) { continue }   // уже выпито — не дразним
                    let c = UNMutableNotificationContent()
                    c.title = "AquaTime 😜"
                    let name = WaterStore.teaseNames.randomElement()!
                    c.body = String(format: self.teases[(i + day) % self.teases.count], name)
                    c.sound = .default
                    c.categoryIdentifier = Self.category
                    c.userInfo = ["amount": r.amount]
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    self.center.add(UNNotificationRequest(identifier: "tease-\(day)-\(i)", content: c,
                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                    n += 1
                }
            }
        }
    }

    func requestPermission(then: @escaping () -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async(execute: then)
        }
    }

    func schedule(reminders: [Reminder], goal: Int) {
        center.removePendingNotificationRequests(withIdentifiers: (0..<64).map { "water-\($0)" })
        for (i, r) in reminders.prefix(40).enumerated() {   // лимит iOS — 64 уведомления
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
