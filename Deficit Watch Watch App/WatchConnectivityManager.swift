import Foundation
import WatchConnectivity
import SwiftUI

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var summary: TodaySummary?
    @Published var isConnected: Bool = false
    @Published var isWaitingForResponse: Bool = false
    
    private let session = WCSession.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    override init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func activate() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported")
            return
        }
        
        session.delegate = self
        session.activate()
    }
    
    func sendQuickAdd(kcal: Double, protein: Double) {
        guard session.isReachable else {
            print("iPhone not reachable")
            return
        }
        
        let payload = QuickAddMealPayload(
            name: "Quick Add",
            kcal: kcal,
            protein: protein,
            date: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            let payloadData = try encoder.encode(payload)
            let message = WCMessage(type: .quickAddMeal, payload: payloadData)
            let messageData = try encoder.encode(message)
            
            isWaitingForResponse = true
            
            session.sendMessage(["data": messageData]) { [weak self] _ in
                DispatchQueue.main.async {
                    // Response handled in delegate
                    print("QuickAdd message sent successfully")
                }
            } errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isWaitingForResponse = false
                    print("Failed to send QuickAdd: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Failed to encode QuickAdd message: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = (activationState == .activated)
            
            if let error = error {
                print("WC activation error: \(error.localizedDescription)")
            } else {
                print("WC activated with state: \(activationState.rawValue)")
            }
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
        case .todaySummary:
            do {
                let summary = try decoder.decode(TodaySummary.self, from: message.payload)
                self.summary = summary
                print("Received today summary: \(summary.netKcal) kcal net")
            } catch {
                print("Failed to decode TodaySummary: \(error)")
            }
            
        case .ack:
            do {
                let ack = try decoder.decode(AckPayload.self, from: message.payload)
                if ack.for == "quickAddMeal" {
                    self.isWaitingForResponse = false
                    // Success haptic
                    WKInterfaceDevice.current().play(.success)
                    print("QuickAdd acknowledged")
                }
            } catch {
                print("Failed to decode Ack: \(error)")
            }
            
        case .quickAddMeal:
            // This shouldn't happen on watch, but handle gracefully
            print("Received unexpected quickAddMeal on watch")
        }
    }
}