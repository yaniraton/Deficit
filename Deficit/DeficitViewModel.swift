import Foundation
import SwiftUI
import Combine

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
    /// Bind intake and protein to MealsStore's published values
    func bindMeals(_ store: MealsStore = .shared) {
        store.$todayIntakeKcal
            .receive(on: DispatchQueue.main)
            .assign(to: \.intake, on: self)
            .store(in: &cancellables)

        store.$todayProteinGrams
            .receive(on: DispatchQueue.main)
            .assign(to: \.todayProteinGrams, on: self)
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
    }
}
