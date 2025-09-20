import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
final class DeficitViewModel: ObservableObject {
    // Health inputs
    @Published var activeKcal: Double = 0
    @Published var basalKcal: Double  = 0
    var burned: Double { activeKcal + basalKcal }

    // MVP intake + goal
    @Published private(set) var intake: Double = 0
    @AppStorage("dailyDeficitGoal") var goal: Double = 500

    // Protein feature
    @Published private(set) var todayProteinGrams: Double = 0
    @AppStorage("proteinFeatureEnabled") var proteinEnabled: Bool = true
    @AppStorage("dailyProteinGoalGrams") var proteinGoalGrams: Double = 50
    @AppStorage("proteinGoalAchievedToday") private var proteinGoalAchievedToday: Bool = false
    
    var proteinProgress: Double {
        guard proteinGoalGrams > 0 else { return 0 }
        return min(max(todayProteinGrams / proteinGoalGrams, 0), 1)
    }

    // Derived
    var net: Double { burned - intake }
    var inDeficit: Bool { net >= 0 }

    // Surplus mode: progress toward break-even (burned/intake)
    var surplusProgress: Double {
        guard intake > 0 else { return 0 }
        return min(max(burned / intake, 0), 1)
    }

    // Deficit mode: progress toward the user goal (net/goal)
    var deficitProgress: Double {
        guard goal > 0 else { return 0 }
        return min(max(net / goal, 0), 1)
    }

    // Unified for UI
    var ringProgress: Double { inDeficit ? deficitProgress : surplusProgress }
    var ringColor: Color { inDeficit ? .green : .red }
    var headline: String { inDeficit ? "In Deficit" : "Not in Deficit" }
    var sublabel: String {
        if inDeficit {
            return "Deficit \(Int(net.rounded())) / \(Int(goal)) kcal"
        } else {
            let remain = max(0, intake - burned)
            return "To break even: \(Int(remain)) kcal"
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var previousProteinProgress: Double = 0
    /// Bind intake and protein to MealsStore's published values
    func bindMeals(_ store: MealsStore = .shared) {
        store.$todayIntakeKcal
            .receive(on: DispatchQueue.main)
            .assign(to: \.intake, on: self)
            .store(in: &cancellables)

        store.$todayProteinGrams
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProteinGrams in
                guard let self = self else { return }
                self.todayProteinGrams = newProteinGrams
                
                // Check for protein goal achievement
                self.checkProteinGoalAchievement()
            }
            .store(in: &cancellables)
    }

    // MARK: - Health loads
    func requestAuthAndLoadToday() async {
        do {
            try await HealthStore.shared.requestAuthorization()
            try await reloadToday()
        } catch {
            print("Health error:", error.localizedDescription)
        }
    }

    func reloadToday() async throws {
        let res = try await HealthStore.shared.todayCalories()
        self.activeKcal = res.activeKcal
        self.basalKcal  = res.basalKcal
        await HealthStore.shared.refresh()
        
        // Reset protein goal achievement for new day
        resetProteinGoalAchievementIfNeeded()
    }
    
    // MARK: - Protein Goal Achievement
    
    private func checkProteinGoalAchievement() {
        guard proteinEnabled else { return }
        
        let currentProgress = proteinProgress
        
        // Check if we just reached 100% goal
        if currentProgress >= 1.0 && previousProteinProgress < 1.0 && !proteinGoalAchievedToday {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            proteinGoalAchievedToday = true
        }
        
        // Update previous progress for next comparison
        previousProteinProgress = currentProgress
    }
    
    private func resetProteinGoalAchievementIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReset = UserDefaults.standard.object(forKey: "lastProteinGoalReset") as? Date ?? Date.distantPast
        
        if !calendar.isDate(lastReset, inSameDayAs: today) {
            proteinGoalAchievedToday = false
            previousProteinProgress = 0
            UserDefaults.standard.set(today, forKey: "lastProteinGoalReset")
        }
    }
}
