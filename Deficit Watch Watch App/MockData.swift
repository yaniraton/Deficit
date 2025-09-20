import Foundation

#if targetEnvironment(simulator)
extension WatchConnectivityManager {
    func setupMockDataForSimulator() {
        // Create mock summary for simulator testing
        let mockSummary = TodaySummary(
            dateStart: ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date())),
            burnedKcal: 2200,
            intakeKcal: 1800,
            netKcal: 400,
            goalKcal: 500,
            proteinEnabled: true,
            proteinConsumed: 75,
            proteinGoal: 100
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.summary = mockSummary
            self.isConnected = true
        }
    }
}
#endif