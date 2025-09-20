import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var id: UUID
    var date: Date               // normalized to startOfDay (local TZ)
    var burnedKcal: Double       // active + basal (end-of-day)
    var intakeKcal: Double       // meals total that day
    var goalKcal: Double         // snapshot of the user's goal *for that day*
    var netKcal: Double          // burned - intake
    var inDeficit: Bool          // net >= 0
    var progress: Double         // snapshot ring progress at EOD (0...1)
    var colorMode: String        // "red", "green", or "gray" for quick render
    
    // Protein data
    var proteinGrams: Double = 0     // total protein consumed that day
    var proteinGoalGrams: Double = 50 // snapshot of protein goal for that day
    var proteinProgress: Double = 0  // protein progress (0...1, can exceed 1.0)
    var proteinEnabled: Bool = true     // snapshot of protein feature state
    
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(),
         date: Date,
         burnedKcal: Double = 0,
         intakeKcal: Double = 0,
         goalKcal: Double = 500,
         netKcal: Double = 0,
         inDeficit: Bool = false,
         progress: Double = 0,
         colorMode: String = "gray",
         proteinGrams: Double = 0,
         proteinGoalGrams: Double = 50,
         proteinProgress: Double = 0,
         proteinEnabled: Bool = true) {
        self.id = id
        self.date = date
        self.burnedKcal = burnedKcal
        self.intakeKcal = intakeKcal
        self.goalKcal = goalKcal
        self.netKcal = netKcal
        self.inDeficit = inDeficit
        self.progress = progress
        self.colorMode = colorMode
        self.proteinGrams = proteinGrams
        self.proteinGoalGrams = proteinGoalGrams
        self.proteinProgress = proteinProgress
        self.proteinEnabled = proteinEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
