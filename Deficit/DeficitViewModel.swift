import Foundation
import SwiftUI

@MainActor
final class DeficitViewModel: ObservableObject {
    // Health inputs
    @Published var activeKcal: Double = 0
    @Published var basalKcal: Double  = 0
    var burned: Double { activeKcal + basalKcal }

    // MVP intake + goal
    @Published var intake: Double = 0
    @AppStorage("dailyDeficitGoal") var goal: Double = 500

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
