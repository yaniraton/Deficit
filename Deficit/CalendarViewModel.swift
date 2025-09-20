import Foundation
import SwiftUI
import SwiftData
import Combine
import UIKit

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var monthDays: [Date] = []
    @Published var summariesByDay: [Date: DailySummary] = [:]
    @Published var isLoading: Bool = false
    @Published var currentMonth: Date = Date()
    
    private var modelContext: ModelContext?
    private let calendar = Calendar.current
    private let mealsStore = MealsStore.shared
    private let healthStore = HealthStore.shared
    
    // Protein settings
    @AppStorage("proteinFeatureEnabled") private var proteinEnabled: Bool = true
    @AppStorage("dailyProteinGoalGrams") private var proteinGoalGrams: Double = 50
    
    // 12 months limit
    private let maxMonthsBack = 12
    private var earliestAllowedDate: Date {
        calendar.date(byAdding: .month, value: -maxMonthsBack, to: Date()) ?? Date()
    }
    
    func attach(context: ModelContext) {
        self.modelContext = context
        updateMonthDays()
        Task { await prefetchMonthCentered(on: currentMonth) }
    }
    
    // MARK: - Date Math
    
    func monthRange(for date: Date) -> (start: Date, end: Date) {
        let startOfMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let endOfMonth = calendar.dateInterval(of: .month, for: date)?.end ?? date
        return (start: startOfMonth, end: endOfMonth)
    }
    
    func updateMonthDays() {
        let (start, end) = monthRange(for: currentMonth)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        
        var days: [Date] = []
        var currentDate = startOfWeek
        
        // Generate 6 weeks worth of days (42 days total)
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        monthDays = days
    }
    
    // MARK: - Navigation
    
    func previousMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
              newMonth >= earliestAllowedDate else { return }
        
        currentMonth = newMonth
        updateMonthDays()
        Task { await prefetchMonthCentered(on: currentMonth) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func nextMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth),
              newMonth <= Date() else { return }
        
        currentMonth = newMonth
        updateMonthDays()
        Task { await prefetchMonthCentered(on: currentMonth) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Data Prefetching
    
    func prefetchMonthCentered(on monthStart: Date) async {
        guard let ctx = modelContext else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Prefetch visible month ±1 month
        let (start, end) = monthRange(for: monthStart)
        let prefetchStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        let prefetchEnd = calendar.date(byAdding: .month, value: 1, to: end) ?? end
        
        do {
            // Fetch health data for the range
            let dailyEnergies = try await healthStore.dailyEnergy(from: prefetchStart, to: prefetchEnd)
            let energyByDate = Dictionary(uniqueKeysWithValues: dailyEnergies.map { ($0.date, $0) })
            
            // Process each day in the range
            var currentDate = prefetchStart
            while currentDate < prefetchEnd {
                let dayStart = calendar.startOfDay(for: currentDate)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                // Get or create summary for this day
                let summary = await getOrCreateSummary(for: dayStart, in: ctx)
                
                // Update with fresh data
                let energy = energyByDate[dayStart]
                let intake = try mealsStore.intake(forDay: dayStart, dayEnd: dayEnd)
                let protein = try mealsStore.protein(forDay: dayStart, dayEnd: dayEnd)
                let goal = getGoalForDate(dayStart) // Use current goal for now
                
                updateSummary(summary, 
                            burned: energy?.burnedKcal ?? 0,
                            intake: intake,
                            goal: goal,
                            protein: protein)
                
                summariesByDay[dayStart] = summary
                
                currentDate = dayEnd
            }
            
            try ctx.save()
        } catch {
            print("Error prefetching calendar data: \(error)")
        }
    }
    
    // MARK: - Summary Management
    
    private func getOrCreateSummary(for dayStart: Date, in context: ModelContext) async -> DailySummary {
        // Try to find existing summary
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date == dayStart }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Create new summary
        let summary = DailySummary(date: dayStart)
        context.insert(summary)
        return summary
    }
    
    private func updateSummary(_ summary: DailySummary, burned: Double, intake: Double, goal: Double, protein: Double) {
        summary.burnedKcal = burned
        summary.intakeKcal = intake
        summary.goalKcal = goal
        summary.netKcal = burned - intake
        summary.inDeficit = summary.netKcal >= 0
        
        // Calculate progress and color mode
        if summary.inDeficit {
            // Deficit mode: progress = net / goal
            summary.progress = goal > 0 ? min(max(summary.netKcal / goal, 0), 1) : 0
            summary.colorMode = "green"
        } else {
            // Surplus mode: progress = burned / intake
            summary.progress = intake > 0 ? min(max(burned / intake, 0), 1) : 0
            summary.colorMode = "red"
        }
        
        // Update protein data
        summary.proteinGrams = protein
        summary.proteinGoalGrams = proteinGoalGrams
        summary.proteinEnabled = proteinEnabled
        summary.proteinProgress = proteinEnabled && proteinGoalGrams > 0 ? 
            min(max(protein / proteinGoalGrams, 0), 1) : 0
        
        summary.updatedAt = Date()
    }
    
    private func getGoalForDate(_ date: Date) -> Double {
        // For now, use current goal. In the future, we could store goal history
        return 500 // This should come from DeficitViewModel or UserDefaults
    }
    
    // MARK: - Public Helpers
    
    func summary(forDay dayStart: Date) -> DailySummary? {
        return summariesByDay[dayStart]
    }
    
    func isDateInRange(_ date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return dayStart >= earliestAllowedDate && dayStart <= Date()
    }
    
    func isDateInCurrentMonth(_ date: Date) -> Bool {
        return calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
}
