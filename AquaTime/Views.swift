import SwiftUI

// MARK: - Волна
struct Wave: Shape {
    var progress: Double
    var phase: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { .init(progress, phase) } set { progress = newValue.first; phase = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y0 = rect.height * (1 - progress)
        p.move(to: CGPoint(x: 0, y: y0))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let rel = x / rect.width
            let y = y0 + sin(rel * 2 * .pi * 1.5 + phase) * 8
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

struct WaterBottle: View {
    let progress: Double
    @State private var phase = 0.0
    var body: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.08))
            Wave(progress: progress, phase: phase)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .clipShape(Circle())
            Wave(progress: progress, phase: phase + .pi)
                .fill(Color.white.opacity(0.18))
                .clipShape(Circle())
            Circle().stroke(Color.cyan.opacity(0.4), lineWidth: 4)
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
        .onAppear { withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { phase = 2 * .pi } }
    }
}

// MARK: - Главный экран
struct HomeView: View {
    @EnvironmentObject var store: WaterStore
    @State private var showCelebration = false
    @State private var custom = 300.0
    private let glasses: [(String, Int)] = [("🥃", 150), ("🥛", 250), ("🧴", 500)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Label("\(store.streak) дн. подряд", systemImage: "flame.fill")
                            .foregroundStyle(.orange).font(.headline)
                        Spacer()
                        if let next = nextReminder {
                            Label(next, systemImage: "bell.fill").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    ZStack {
                        WaterBottle(progress: store.progress).frame(width: 250, height: 250)
                        VStack(spacing: 4) {
                            Text(store.mood.emoji).font(.system(size: 44))
                            Text("\(store.drunk)").font(.system(size: 44, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text("из \(store.goal) мл").font(.headline).opacity(0.8)
                        }.foregroundStyle(store.progress > 0.45 ? .white : .primary)
                    }
                    Text(store.mood.text).font(.title3.weight(.semibold)).multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        ForEach(glasses, id: \.1) { g in
                            Button { drink(g.1) } label: {
                                VStack { Text(g.0).font(.largeTitle); Text("+\(g.1) мл").font(.caption.bold()) }
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Своё количество: \(Int(custom)) мл").font(.subheadline)
                        HStack {
                            Slider(value: $custom, in: 50...1000, step: 50).tint(.cyan)
                            Button("Добавить") { drink(Int(custom)) }.buttonStyle(.borderedProminent).tint(.cyan)
                        }
                    }
                    Button(role: .destructive) { store.add(-250) } label: { Label("Отменить 250 мл", systemImage: "arrow.uturn.backward") }
                        .font(.footnote).disabled(store.drunk == 0)

                    WeekChart().environmentObject(store)
                }.padding()
            }
            .navigationTitle("💧 AquaTime")
            .overlay { if showCelebration { CelebrationView().transition(.scale.combined(with: .opacity)) } }
        }
    }

    private var nextReminder: String? {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let m = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let times = store.reminders.map { Calendar.current.component(.hour, from: $0.time) * 60 + Calendar.current.component(.minute, from: $0.time) }
        return (times.first { $0 > m } ?? times.first)?.clockString
    }

    private func drink(_ ml: Int) {
        let before = store.drunk
        withAnimation { store.add(ml) }
        if before < store.goal && store.drunk >= store.goal {
            withAnimation(.spring) { showCelebration = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { showCelebration = false } }
        }
    }
}

struct CelebrationView: View {
    @State private var pop = false
    var body: some View {
        VStack(spacing: 10) {
            Text("🎉🏆🎉").font(.system(size: 70)).scaleEffect(pop ? 1.2 : 0.6)
            Text("Норма выполнена!").font(.title.bold())
        }
        .padding(40).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30))
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.4).repeatCount(3)) { pop = true } }
    }
}

struct WeekChart: View {
    @EnvironmentObject var store: WaterStore
    private static let f: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    private static let wd: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "EE"; return f }()
    var body: some View {
        let cal = Calendar.current
        let f = Self.f, wd = Self.wd
        let days = (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: Date())! }
        VStack(alignment: .leading, spacing: 8) {
            Text("Последние 7 дней").font(.headline)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.self) { d in
                    let isToday = cal.isDateInToday(d)
                    let v = isToday ? store.drunk : (store.history[f.string(from: d)] ?? 0)
                    let ratio = min(Double(v) / Double(store.goal), 1)
                    VStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ratio >= 1 ? Color.green : Color.cyan.opacity(0.4 + ratio * 0.6))
                            .frame(height: max(6, 90 * ratio))
                        Text(wd.string(from: d)).font(.caption2).fontWeight(isToday ? .bold : .regular)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 115, alignment: .bottom)
        }.padding().background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - График
struct ScheduleView: View {
    @EnvironmentObject var store: WaterStore
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Твоя норма \(store.goal) мл разбита на \(store.reminders.count) порций. В каждое время придёт уведомление 🔔")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(Array(store.reminders.enumerated()), id: \.element.id) { i, r in
                    let mins = Calendar.current.component(.hour, from: r.time) * 60 + Calendar.current.component(.minute, from: r.time)
                    HStack {
                        Text(mins.clockString).font(.title3.monospacedDigit().bold())
                        Spacer()
                        Text("\(r.amount) мл").foregroundStyle(.cyan).bold()
                        Image(systemName: store.drunk >= r.amount * (i + 1) ? "checkmark.circle.fill" : "drop")
                            .foregroundStyle(store.drunk >= r.amount * (i + 1) ? .green : .cyan)
                    }
                }
            }.navigationTitle("График")
        }
    }
}

// MARK: - Настройки
struct GoalSettings: View {
    @EnvironmentObject var store: WaterStore
    @State private var weight = 70.0
    var body: some View {
        Section("Дневная цель") {
            Stepper("\(store.goal) мл", value: $store.goal, in: 500...5000, step: 100)
            HStack {
                Text("Вес: \(Int(weight)) кг")
                Slider(value: $weight, in: 30...150, step: 1)
            }
            Button("Рассчитать по весу (30 мл/кг)") { store.goal = Int(weight * 30 / 50) * 50 }
        }
        Section("Режим дня") {
            minutesPicker("Подъём", $store.wakeMinutes)
            minutesPicker("Отбой", $store.sleepMinutes)
            Picker("Напоминать каждые", selection: $store.intervalMinutes) {
                ForEach([30, 45, 60, 90, 120, 180], id: \.self) { Text($0 < 60 ? "\($0) мин" : String(format: "%g ч", Double($0) / 60)).tag($0) }
            }
        }
    }
    private func minutesPicker(_ title: String, _ value: Binding<Int>) -> some View {
        DatePicker(title, selection: Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(value.wrappedValue) * 60) },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); value.wrappedValue = c.hour! * 60 + c.minute! }
        ), displayedComponents: .hourAndMinute)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: WaterStore
    var body: some View {
        NavigationStack {
            Form {
                GoalSettings()
                Section("Уведомления") { Toggle("Напоминания", isOn: $store.notificationsOn) }
                Section(footer: Text("Каждый выпитый стакан будет записываться в приложение «Здоровье»")) {
                    Toggle(isOn: Binding(get: { store.healthOn }, set: { on in
                        if on { HealthManager.shared.requestAuth { ok in store.healthOn = ok } } else { store.healthOn = false }
                    })) { Label("Apple Здоровье", systemImage: "heart.fill").foregroundStyle(.pink) }
                }
            }
            .navigationTitle("Настройки")
            .onChange(of: store.goal) { store.reschedule() }
            .onChange(of: store.wakeMinutes) { store.reschedule() }
            .onChange(of: store.sleepMinutes) { store.reschedule() }
            .onChange(of: store.intervalMinutes) { store.reschedule() }
            .onChange(of: store.notificationsOn) { store.reschedule() }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: WaterStore
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Text("💧").font(.system(size: 70))
                        Text("Привет! Я AquaTime").font(.title.bold())
                        Text("Настрой свою норму, и я буду напоминать пить воду в течение дня").multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical)
                }
                GoalSettings()
                Button("Начать 🚀") {
                    store.onboarded = true
                    NotificationManager.shared.requestPermission { store.reschedule() }
                }.frame(maxWidth: .infinity).font(.headline)
            }
        }
    }
}
