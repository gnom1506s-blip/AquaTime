// Заполните из консоли Firebase: Настройки проекта → Общие
enum FirebaseConfig {
    static let projectId = ""   // например "aquatime-12345"
    static let apiKey = ""      // «Web API Key», начинается с AIza...
    static var isSet: Bool { !projectId.isEmpty && !apiKey.isEmpty }
}
