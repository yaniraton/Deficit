import Foundation

// MARK: - Data Models for WatchConnectivity

struct TodaySummary: Codable {
    let dateStart: String        // ISO8601 startOfDay in local tz
    let burnedKcal: Double
    let intakeKcal: Double
    let netKcal: Double
    let goalKcal: Double
    let proteinEnabled: Bool
    let proteinConsumed: Double
    let proteinGoal: Double
    
    var inDeficit: Bool { netKcal >= 0 }
    
    // Ring calculations (matches iOS DeficitViewModel logic)
    var deficitProgress: Double {
        guard goalKcal > 0 else { return 0 }
        return min(max(netKcal / goalKcal, 0), 1)
    }
    
    var surplusProgress: Double {
        guard intakeKcal > 0 else { return 0 }
        return min(max(burnedKcal / intakeKcal, 0), 1)
    }
    
    var ringProgress: Double { inDeficit ? deficitProgress : surplusProgress }
    
    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return max(proteinConsumed / proteinGoal, 0) // Can exceed 1.0
    }
}

struct QuickAddMealPayload: Codable {
    let name: String
    let kcal: Double
    let protein: Double
    let date: String  // ISO8601
}

// MARK: - WatchConnectivity Message Types

enum WCMessageType: String, Codable {
    case todaySummary = "todaySummary"
    case quickAddMeal = "quickAddMeal" 
    case ack = "ack"
}

struct WCMessage: Codable {
    let type: WCMessageType
    let payload: Data
}

struct AckPayload: Codable {
    let for: String
}