import SwiftUI

struct FriendStat: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let name: String
    let today: Int
    let goal: Int
    let streak: Int
    let total: Int
    let badges: Int
    var isMe = false
    var progress: Double { min(Double(today) / Double(max(goal, 1)), 1.5) }
}

/// Обмен статистикой через Firebase (анонимный вход + Firestore REST API)
@MainActor
final class FriendsService: ObservableObject {
    static let shared = FriendsService()
    private let d = sharedDefaults

    @Published var friends: [FriendStat] = []
    @Published var loading = false
    @Published var error: String?
    @Published var name: String { didSet { d.set(name, forKey: "fr_name") } }

    var myCode: String {
        if let c = d.string(forKey: "fr_code") { return c }
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let c = String((0..<6).map { _ in chars.randomElement()! })
        d.set(c, forKey: "fr_code"); return c
    }
    var friendCodes: [String] {
        get { d.stringArray(forKey: "fr_list") ?? [] }
        set { d.set(newValue, forKey: "fr_list") }
    }

    private init() { name = sharedDefaults.string(forKey: "fr_name") ?? "" }

    // MARK: Вход
    private func token() async throws -> (String, String) {
        let key = FirebaseConfig.apiKey
        if let refresh = d.string(forKey: "fr_refresh"), let uid = d.string(forKey: "fr_uid") {
            var r = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(key)")!)
            r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            r.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)
            let (data, resp) = try await URLSession.shared.data(for: r)
            if (resp as? HTTPURLResponse)?.statusCode == 200,
               let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let t = j["id_token"] as? String {
                return (t, uid)
            }
        }
        var r = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(key)")!)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["returnSecureToken": true])
        let (data, _) = try await URLSession.shared.data(for: r)
        guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = j["idToken"] as? String, let refresh = j["refreshToken"] as? String, let uid = j["localId"] as? String
        else { throw NSError(domain: "AquaTime", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось войти в Firebase. Проверьте, что включён анонимный вход."]) }
        d.set(refresh, forKey: "fr_refresh"); d.set(uid, forKey: "fr_uid")
        return (t, uid)
    }

    private func docURL(_ code: String) -> URL {
        URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/users/\(code)")!
    }

    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()

    // MARK: Отправка своей статистики
    func push() {
        guard FirebaseConfig.isSet else { return }
        let s = WaterStore.shared
        let myName = name.isEmpty ? "Я" : name
        let fields: [String: Any] = [
            "owner": "", "name": myName, "today": s.drunk, "goal": s.goal, "streak": s.streak,
            "total": s.totalML, "badges": s.unlocked.count, "day": Self.dayFmt.string(from: Date()),
        ]
        Task {
            do {
                let (t, uid) = try await token()
                var f = fields; f["owner"] = uid
                var body: [String: Any] = [:]
                for (k, v) in f {
                    if let i = v as? Int { body[k] = ["integerValue": String(i)] } else { body[k] = ["stringValue": "\(v)"] }
                }
                var r = URLRequest(url: docURL(myCode))
                r.httpMethod = "PATCH"
                r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
                r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                r.httpBody = try JSONSerialization.data(withJSONObject: ["fields": body])
                let (_, resp) = try await URLSession.shared.data(for: r)
                if let code = (resp as? HTTPURLResponse)?.statusCode, code >= 300 { error = "Сервер ответил \(code) при сохранении" }
            } catch { self.error = error.localizedDescription }
        }
    }

    // MARK: Загрузка друзей
    private func fetch(_ code: String, token t: String) async -> FriendStat? {
        var r = URLRequest(url: docURL(code))
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: r),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let f = j["fields"] as? [String: [String: Any]] else { return nil }
        func i(_ k: String) -> Int { Int(f[k]?["integerValue"] as? String ?? "") ?? 0 }
        func s(_ k: String) -> String { f[k]?["stringValue"] as? String ?? "" }
        let isToday = s("day") == Self.dayFmt.string(from: Date())
        return FriendStat(code: code, name: s("name"), today: isToday ? i("today") : 0, goal: i("goal"),
                          streak: i("streak"), total: i("total"), badges: i("badges"))
    }

    func refresh() async {
        guard FirebaseConfig.isSet else { return }
        loading = true; defer { loading = false }
        push()
        do {
            let (t, _) = try await token()
            var list: [FriendStat] = []
            for c in friendCodes { if let f = await fetch(c, token: t) { list.append(f) } }
            let s = WaterStore.shared
            list.append(FriendStat(code: myCode, name: name.isEmpty ? "Я" : name, today: s.drunk, goal: s.goal,
                                   streak: s.streak, total: s.totalML, badges: s.unlocked.count, isMe: true))
            friends = list.sorted { $0.progress != $1.progress ? $0.progress > $1.progress : $0.today > $1.today }
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func addFriend(_ raw: String) async -> Bool {
        let code = raw.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count == 6, code != myCode, !friendCodes.contains(code) else { error = "Неверный код"; return false }
        do {
            let (t, _) = try await token()
            guard await fetch(code, token: t) != nil else { error = "Друг с кодом \(code) не найден"; return false }
            friendCodes.append(code)
            await refresh()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func remove(_ code: String) {
        friendCodes.removeAll { $0 == code }
        friends.removeAll { $0.code == code }
    }
}

// MARK: - Экран друзей
struct FriendsView: View {
    @StateObject private var fs = FriendsService.shared
    @State private var newCode = ""
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if !FirebaseConfig.isSet {
                    ContentUnavailableView("Друзья пока не подключены", systemImage: "person.2.slash",
                        description: Text("Нужно указать проект Firebase в файле FirebaseConfig.swift"))
                } else {
                    List {
                        Section("Твой профиль") {
                            TextField("Твоё имя", text: $fs.name).onSubmit { fs.push() }
                            HStack {
                                Text("Твой код:")
                                Text(fs.myCode).font(.title3.monospaced().bold()).foregroundStyle(.cyan)
                                Spacer()
                                Button { UIPasteboard.general.string = fs.myCode; copied = true } label: {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                }.buttonStyle(.borderless)
                                ShareLink(item: "Пей воду вместе со мной в AquaTime 💧 Мой код друга: \(fs.myCode)") {
                                    Image(systemName: "square.and.arrow.up")
                                }.buttonStyle(.borderless)
                            }
                        }
                        Section("Добавить друга") {
                            HStack {
                                TextField("Код друга, например K7PX2M", text: $newCode)
                                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                                Button("Добавить") {
                                    Task { if await fs.addFriend(newCode) { newCode = "" } }
                                }.disabled(newCode.count < 6)
                            }
                        }
                        if let e = fs.error { Section { Label(e, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
                        Section("Рейтинг за сегодня") {
                            if fs.friends.isEmpty && !fs.loading {
                                Text("Добавь друзей по коду — и соревнуйтесь, кто лучше пьёт воду 💪").foregroundStyle(.secondary)
                            }
                            ForEach(Array(fs.friends.enumerated()), id: \.element.id) { i, f in
                                FriendRow(rank: i + 1, f: f)
                                    .swipeActions { if !f.isMe { Button("Удалить", role: .destructive) { fs.remove(f.code) } } }
                            }
                        }
                    }
                    .refreshable { await fs.refresh() }
                    .overlay { if fs.loading && fs.friends.isEmpty { ProgressView() } }
                }
            }
            .navigationTitle("Друзья")
            .task { await fs.refresh() }
        }
    }
}

struct FriendRow: View {
    let rank: Int
    let f: FriendStat
    var body: some View {
        HStack(spacing: 12) {
            Text(rank <= 3 ? ["🥇", "🥈", "🥉"][rank - 1] : "\(rank)").font(.title2).frame(width: 36)
            Image("Plant\(WaterStore.stage(for: f.progress))").resizable().frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(f.isMe ? "\(f.name) (ты)" : f.name).font(.headline)
                ProgressView(value: min(f.progress, 1)).tint(f.progress >= 1 ? .green : .cyan)
                HStack(spacing: 10) {
                    Text("\(f.today)/\(f.goal) мл")
                    Text("🔥 \(f.streak)")
                    Text("🏆 \(f.badges)")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(f.isMe ? Color.cyan.opacity(0.12) : nil)
    }
}
