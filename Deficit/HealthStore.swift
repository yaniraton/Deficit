import Foundation
import HealthKit

// MARK: - HealthStore (global HealthKit facade)

@MainActor
final class HealthStore: NSObject {
    static let shared = HealthStore()
    private let healthStore = HKHealthStore()

    // Quantity types
    private let activeType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let basalType  = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!

    // Units
    private let kcal = HKUnit.kilocalorie()

    // Simple availability check
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Public model for results
    struct CaloriesBreakdown {
        let activeKcal: Double
        let basalKcal: Double
        var totalKcal: Double { activeKcal + basalKcal }
    }
    
    struct DailyEnergy {
        let date: Date         // startOfDay
        let activeKcal: Double
        let basalKcal: Double
        var burnedKcal: Double { activeKcal + basalKcal }
    }

    // Errors
    enum HKError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Health data isn’t available on this device."
            }
        }
    }

    // MARK: - Authorization

    /// Requests read access for Active + Basal energy.
    func requestAuthorization() async throws {
        guard isAvailable else { throw HKError.unavailable }
        let toRead: Set<HKObjectType> = [activeType, basalType]
        try await healthStore.requestAuthorization(toShare: [], read: toRead)
    }

    // MARK: - Refresh hook

    /// Placeholder for any on-demand data refresh logic you’ll add later
    /// (e.g., invalidate caches, requery, fire observers, etc.)
    func refresh() async {
        // no-op for MVP; keep for future background delivery / observers.
    }

    // MARK: - Calories API
    
    /// Returns calories burned (active + basal) between start and end (inclusive of start, exclusive of end).
    func calories(from start: Date, to end: Date) async throws -> CaloriesBreakdown {
        async let active = sum(type: activeType, unit: kcal, start: start, end: end)
        async let basal  = sum(type: basalType,  unit: kcal, start: start, end: end)
        let (a, b) = try await (active, basal)
        return .init(activeKcal: max(0, a), basalKcal: max(0, b))
    }

    /// Convenience: today's range in current calendar/locale.
    func todayCalories() async throws -> CaloriesBreakdown {
        let start = Calendar.current.startOfDay(for: Date())
        return try await calories(from: start, to: Date())
    }
    
    /// Returns daily energy breakdown for a date range using HKStatisticsCollectionQuery
    func dailyEnergy(from start: Date, to end: Date) async throws -> [DailyEnergy] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.startOfDay(for: end)
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            
            // Create collection query for active energy
            let activeQuery = HKStatisticsCollectionQuery(
                quantityType: activeType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: DateComponents(day: 1)
            )
            
            // Create collection query for basal energy
            let basalQuery = HKStatisticsCollectionQuery(
                quantityType: basalType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: DateComponents(day: 1)
            )
            
            var activeResults: [Date: Double] = [:]
            var basalResults: [Date: Double] = [:]
            var completedQueries = 0
            
            let processResults = {
                completedQueries += 1
                if completedQueries == 2 {
                    // Combine results
                    var dailyEnergies: [DailyEnergy] = []
                    var currentDate = startOfDay
                    
                    while currentDate < endOfDay {
                        let active = activeResults[currentDate] ?? 0
                        let basal = basalResults[currentDate] ?? 0
                        dailyEnergies.append(DailyEnergy(
                            date: currentDate,
                            activeKcal: max(0, active),
                            basalKcal: max(0, basal)
                        ))
                        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                    }
                    
                    continuation.resume(returning: dailyEnergies)
                }
            }
            
            activeQuery.initialResultsHandler = { _, collection, _ in
                collection?.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: self.kcal) ?? 0
                    activeResults[statistics.startDate] = value
                }
                processResults()
            }
            
            basalQuery.initialResultsHandler = { _, collection, _ in
                collection?.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: self.kcal) ?? 0
                    basalResults[statistics.startDate] = value
                }
                processResults()
            }
            
            healthStore.execute(activeQuery)
            healthStore.execute(basalQuery)
        }
    }

    // MARK: - Private helpers

    private func sum(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, error in
                if let error = error { cont.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }
}
