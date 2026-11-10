import HealthKit

final class HealthManager {
    static let shared = HealthManager()
    private let store = HKHealthStore()
    private let water = HKQuantityType(.dietaryWater)

    func requestAuth(_ done: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { return done(false) }
        store.requestAuthorization(toShare: [water], read: [water]) { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    func saveWater(_ ml: Int) {
        let q = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        store.save(HKQuantitySample(type: water, quantity: q, start: Date(), end: Date())) { _, _ in }
    }
}
