import Foundation
import WatchConnectivity
import SwiftUI

// MARK: - Shared Data Models (same as watch)

struct TodaySummary: Codable {
    let dateStart: String        // ISO8601 startOfDay in local tz
    let burnedKcal: Double
    let intakeKcal: Double
    let netKcal: Double
    let goalKcal: Double
    let proteinEnabled: Bool
    let proteinConsumed: Double
    let proteinGoal: Double
}

struct QuickAddMealPayload: Codable {
    let name: String
    let kcal: Double
    let protein: Double
    let date: String  // ISO8601
}

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

// MARK: - iOS WatchConnectivityManager

@MainActor
final class iOSWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = iOSWatchConnectivityManager()
    
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    
    private let session = WCSession.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Dependencies - will be injected
    private var deficitViewModel: DeficitViewModel?
    private var mealsStore: MealsStore?
    
    override init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func setup(deficitViewModel: DeficitViewModel, mealsStore: MealsStore) {
        self.deficitViewModel = deficitViewModel
        self.mealsStore = mealsStore
        activate()
    }
    
    private func activate() {
        guard WCSession.isSupported() else { return }
        
        session.delegate = self
        session.activate()
    }
    
    func sendTodaySummary() {
        guard session.isReachable,
              let vm = deficitViewModel else { return }
        
        let formatter = ISO8601DateFormatter()
        let summary = TodaySummary(
            dateStart: formatter.string(from: Calendar.current.startOfDay(for: Date())),
            burnedKcal: vm.burned,
            intakeKcal: vm.intake,
            netKcal: vm.net,
            goalKcal: vm.goal,
            proteinEnabled: vm.proteinEnabled,
            proteinConsumed: vm.todayProteinGrams,
            proteinGoal: vm.proteinGoalGrams
        )
        
        do {
            let summaryData = try encoder.encode(summary)
            let message = WCMessage(type: .todaySummary, payload: summaryData)
            let messageData = try encoder.encode(message)
            
            session.sendMessage(["data": messageData]) { _ in
                print("TodaySummary sent successfully")
            } errorHandler: { error in
                print("Failed to send TodaySummary: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to encode TodaySummary: \(error)")
        }
    }
    
    private func sendAck(for messageType: String) {
        guard session.isReachable else { return }
        
        let ack = AckPayload(for: messageType)
        
        do {
            let ackData = try encoder.encode(ack)
            let message = WCMessage(type: .ack, payload: ackData)
            let messageData = try encoder.encode(message)
            
            session.sendMessage(["data": messageData]) { _ in
                print("Ack sent for \(messageType)")
            } errorHandler: { error in
                print("Failed to send ack: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to encode ack: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension iOSWatchConnectivityManager: WCSessionDelegate {
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            
            if activationState == .activated {
                print("iOS WC activated")
                // Send initial summary when activated
                self.sendTodaySummary()
            }
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let messageData = message["data"] as? Data else { return }
        
        do {
            let wcMessage = try self.decoder.decode(WCMessage.self, from: messageData)
            
            DispatchQueue.main.async {
                self.handleMessage(wcMessage)
            }
        } catch {
            print("Failed to decode WC message: \(error)")
        }
    }
    
    private func handleMessage(_ message: WCMessage) {
        switch message.type {
        case .quickAddMeal:
            handleQuickAddMeal(message.payload)
            
        case .todaySummary:
            // Shouldn't receive this on iOS, but handle gracefully
            print("Received unexpected todaySummary on iOS")
            
        case .ack:
            // Handle acks if needed
            print("Received ack from watch")
        }
    }
    
    private func handleQuickAddMeal(_ payloadData: Data) {
        guard let mealsStore = mealsStore else { return }
        
        do {
            let payload = try decoder.decode(QuickAddMealPayload.self, from: payloadData)
            let date = ISO8601DateFormatter().date(from: payload.date) ?? Date()
            
            Task {
                try await mealsStore.addMeal(
                    name: payload.name,
                    kcal: payload.kcal,
                    proteinGrams: payload.protein,
                    date: date
                )
                
                // Send ack
                self.sendAck(for: "quickAddMeal")
                
                // Send updated summary
                self.sendTodaySummary()
                
                print("QuickAdd meal added: \(payload.kcal) kcal, \(payload.protein)g protein")
            }
        } catch {
            print("Failed to decode QuickAddMeal payload: \(error)")
        }
    }
}