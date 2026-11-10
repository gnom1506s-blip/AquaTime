import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ app: UIApplication, didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.registerCategories()
        return true
    }
    // Нажатие кнопки «Выпил» прямо в уведомлении
    func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse, withCompletionHandler done: @escaping () -> Void) {
        let amount = r.notification.request.content.userInfo["amount"] as? Int ?? 250
        switch r.actionIdentifier {
        case NotificationManager.drinkAction: WaterStore.shared.add(amount)
        case NotificationManager.snoozeAction: NotificationManager.shared.snooze(amount: amount)
        default: break
        }
        done()
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification, withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }
}

@main
struct AquaTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = WaterStore.shared
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .onChange(of: phase) { if phase == .active { store.objectWillChange.send(); store.updateIcon() } }
                .onOpenURL { url in if url.host == "add" { store.add(250) } }
                .onAppear { NotificationManager.shared.requestPermission { store.reschedule() } }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: WaterStore
    var body: some View {
        if store.onboarded {
            TabView {
                HomeView().tabItem { Label("Сегодня", systemImage: "drop.fill") }
                ScheduleView().tabItem { Label("График", systemImage: "clock.fill") }
                SettingsView().tabItem { Label("Настройки", systemImage: "gearshape.fill") }
            }.tint(.cyan)
        } else {
            OnboardingView()
        }
    }
}
