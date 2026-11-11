import SwiftUI

// MARK: - Напитки
enum Drink: String, CaseIterable, Identifiable {
    case water, tea, coffee, juice, milk, soda
    var id: String { rawValue }
    var emoji: String {
        switch self { case .water: "💧"; case .tea: "🍵"; case .coffee: "☕️"; case .juice: "🧃"; case .milk: "🥛"; case .soda: "🥤" }
    }
    var title: String {
        switch self { case .water: "Вода"; case .tea: "Чай"; case .coffee: "Кофе"; case .juice: "Сок"; case .milk: "Молоко"; case .soda: "Газировка" }
    }
    var color: Color {
        switch self { case .water: .cyan; case .tea: .green; case .coffee: .brown; case .juice: .orange; case .milk: .gray; case .soda: .pink }
    }
}

// MARK: - Достижения
struct Achievement: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let desc: String
    var anti = false
    let check: (WaterStore) -> Bool

    static let all: [Achievement] = [
        .init(id: "first", emoji: "💧", title: "Первый глоток", desc: "Отметить первый напиток") { $0.totalML > 0 },
        .init(id: "goal1", emoji: "🎯", title: "В яблочко", desc: "Впервые выполнить дневную норму") { $0.goalsDone >= 1 },
        .init(id: "streak3", emoji: "🔥", title: "Разогрев", desc: "3 дня подряд выполнять норму") { $0.streak >= 3 },
        .init(id: "streak7", emoji: "🏅", title: "Неделя силы", desc: "7 дней подряд выполнять норму") { $0.streak >= 7 },
        .init(id: "streak30", emoji: "👑", title: "Король воды", desc: "30 дней подряд выполнять норму") { $0.streak >= 30 },
        .init(id: "early", emoji: "🌅", title: "Ранняя пташка", desc: "Выпить воду до 9:00") { $0.unlockedEarly },
        .init(id: "pure", emoji: "🫧", title: "Чистый день", desc: "Выполнить норму без кофе и газировки") { $0.progress >= 1 && $0.todayDrinks[Drink.coffee.rawValue] == nil && $0.todayDrinks[Drink.soda.rawValue] == nil },
        .init(id: "taster", emoji: "🍹", title: "Дегустатор", desc: "4 разных напитка за день") { $0.todayDrinks.count >= 4 },
        .init(id: "over", emoji: "🚀", title: "Перевыполнение", desc: "Выпить 150% нормы за день") { $0.drunk >= $0.goal * 3 / 2 },
        .init(id: "l10", emoji: "🪣", title: "Ведро", desc: "Всего 10 литров") { $0.totalML >= 10_000 },
        .init(id: "l100", emoji: "🛁", title: "Ванна", desc: "Всего 100 литров") { $0.totalML >= 100_000 },
        .init(id: "l500", emoji: "🌊", title: "Океан", desc: "Всего 500 литров") { $0.totalML >= 500_000 },
        // Антинаграды 😈
        .init(id: "x_cactus", emoji: "🌵", title: "Кактус", desc: "Пропустить 3 напоминания за день", anti: true) { $0.missedToday >= 3 },
        .init(id: "x_sloth", emoji: "🦥", title: "Ленивец", desc: "10 пропущенных напоминаний всего", anti: true) { $0.totalMissed >= 10 },
        .init(id: "x_sahara", emoji: "🏜️", title: "Сахара", desc: "50 пропущенных напоминаний всего", anti: true) { $0.totalMissed >= 50 },
        .init(id: "x_camel", emoji: "🐪", title: "Верблюд", desc: "Выпить меньше 25% нормы за день", anti: true) { $0.camelDays >= 1 },
        .init(id: "x_dry", emoji: "🥀", title: "Засушил растение", desc: "Целый день без воды", anti: true) { $0.zeroDays >= 1 },
        .init(id: "x_mummy", emoji: "🧟", title: "Мумия", desc: "3 дня подряд не выполнить норму", anti: true) { $0.failStreak >= 3 },
        .init(id: "x_sleepy", emoji: "😴", title: "Соня", desc: "Первый стакан воды только после 12:00", anti: true) { $0.unlockedLate },
        .init(id: "x_almost", emoji: "🫠", title: "Чуть-чуть не считается", desc: "Закончить день на 90–99% нормы", anti: true) { $0.almostDays >= 1 },
    ]
}

struct AchievementsView: View {
    @EnvironmentObject var store: WaterStore
    private let cols = [GridItem(.adaptive(minimum: 150), spacing: 12)]
    var body: some View {
        NavigationStack {
            ScrollView {
                let good = Achievement.all.filter { !$0.anti }
                let got = good.filter { store.unlocked[$0.id] != nil }.count
                VStack(spacing: 6) {
                    Text("\(got) из \(good.count)").font(.system(size: 36, weight: .bold, design: .rounded))
                    ProgressView(value: Double(got), total: Double(good.count)).tint(.orange)
                    Text("Всего выпито: \(String(format: "%.1f", Double(store.totalML) / 1000)) л").font(.subheadline).foregroundStyle(.secondary)
                }.padding()
                grid(good, accent: .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("😈 Антинаграды").font(.title2.bold())
                    Text("Ими не хвастаются. Пропущено напоминаний всего: \(store.totalMissed)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding([.horizontal, .top])
                grid(Achievement.all.filter(\.anti), accent: .purple)
            }.navigationTitle("Награды")
        }
    }

    private func grid(_ items: [Achievement], accent: Color) -> some View {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(items) { a in
                        let date = store.unlocked[a.id]
                        VStack(spacing: 6) {
                            Text(a.emoji).font(.system(size: 44)).grayscale(date == nil ? 1 : 0).opacity(date == nil ? 0.35 : 1)
                            Text(a.title).font(.headline).multilineTextAlignment(.center)
                            Text(a.desc).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            if let date {
                                Text(Date(timeIntervalSince1970: date).formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2.bold()).foregroundStyle(accent)
                            } else {
                                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 170).padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(date == nil ? .clear : accent.opacity(0.6), lineWidth: 2))
                    }
                }.padding(.horizontal)
    }
}

struct AchievementToast: View {
    let a: Achievement
    var body: some View {
        HStack(spacing: 12) {
            Text(a.emoji).font(.system(size: 40))
            VStack(alignment: .leading) {
                Text(a.anti ? "Антинаграда 😈" : "Новая награда!").font(.caption.bold()).foregroundStyle(a.anti ? .purple : .orange)
                Text(a.title).font(.headline)
                Text(a.desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 10).padding(.horizontal)
    }
}
