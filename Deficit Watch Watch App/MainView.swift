import SwiftUI

struct MainView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @State private var showQuickAdd = false
    
    var body: some View {
        VStack(spacing: 12) {
            if let summary = connectivityManager.summary {
                // Rings
                Group {
                    if summary.proteinEnabled {
                        DualRingsView(
                            deficitProgress: summary.ringProgress,
                            deficitColor: summary.inDeficit ? .green : .red,
                            proteinProgress: summary.proteinProgress
                        )
                    } else {
                        SingleRingView(
                            progress: summary.ringProgress,
                            color: summary.inDeficit ? .green : .red
                        )
                    }
                }
                .accessibilityLabel("Deficit ring")
                .accessibilityValue("\(Int(summary.ringProgress * 100))% complete")
                
                // Stats
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        statView(
                            label: "Burned",
                            value: "\(Int(summary.burnedKcal.rounded()))",
                            unit: "kcal"
                        )
                        
                        statView(
                            label: "Intake", 
                            value: "\(Int(summary.intakeKcal.rounded()))",
                            unit: "kcal"
                        )
                        
                        statView(
                            label: "Net",
                            value: "\(Int(summary.netKcal.rounded()))",
                            unit: "kcal"
                        )
                    }
                    
                    if summary.proteinEnabled {
                        HStack {
                            Spacer()
                            statView(
                                label: "Protein",
                                value: "\(Int(summary.proteinConsumed.rounded()))",
                                unit: "g"
                            )
                            Spacer()
                        }
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                // Status
                Text(summary.inDeficit ? "In Deficit" : "Not in Deficit")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(summary.inDeficit ? .green : .red)
                
            } else if connectivityManager.isConnected {
                // Waiting for data
                VStack(spacing: 8) {
                    RingView(progress: 0, color: .gray)
                        .frame(width: 120, height: 120)
                    
                    Text("Waiting for phone...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Not connected
                VStack(spacing: 8) {
                    RingView(progress: 0, color: .gray)
                        .frame(width: 120, height: 120)
                    
                    Text("iPhone not connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Deficit")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQuickAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .accessibilityLabel("Add meal")
                .accessibilityRespondsToUserInteraction(true)
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddFlowView()
        }
        .onAppear {
            connectivityManager.activate()
            
            #if targetEnvironment(simulator)
            connectivityManager.setupMockDataForSimulator()
            #endif
        }
    }
    
    @ViewBuilder
    private func statView(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}