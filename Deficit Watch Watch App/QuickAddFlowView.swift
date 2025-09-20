import SwiftUI

struct QuickAddFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    enum Step {
        case calories
        case protein
    }
    
    @State private var step: Step = .calories
    @State private var rawCalories: Double = 0
    @State private var rawProtein: Double = 0
    
    // Computed values with rounding
    private var calories: Double {
        (rawCalories / 5.0).rounded() * 5.0 // Round to nearest 5
    }
    
    private var protein: Double {
        rawProtein.rounded() // Round to nearest 1
    }
    
    private var proteinEnabled: Bool {
        connectivityManager.summary?.proteinEnabled ?? false
    }
    
    private var showProteinStep: Bool {
        proteinEnabled && step == .protein
    }
    
    private var showNextButton: Bool {
        proteinEnabled && step == .calories
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Step indicator
                if proteinEnabled {
                    HStack {
                        Circle()
                            .fill(step == .calories ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Circle()
                            .fill(step == .protein ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    .frame(maxWidth: 60)
                }
                
                // Main input area
                VStack(spacing: 4) {
                    Text(step == .calories ? "Calories" : "Protein")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 2) {
                        Text("\(Int(step == .calories ? calories : protein))")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        
                        Text(step == .calories ? "kcal" : "g")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .digitalCrownRotation(
                    step == .calories ? $rawCalories : $rawProtein,
                    from: 0,
                    through: step == .calories ? 2000 : 200, // Max values
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: true,
                    isHapticFeedbackEnabled: true
                )
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    if showNextButton {
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step = .protein
                            }
                            WKInterfaceDevice.current().play(.click)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityRespondsToUserInteraction(true)
                    }
                    
                    Button {
                        addMeal()
                    } label: {
                        if connectivityManager.isWaitingForResponse {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Adding...")
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Add")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(calories <= 0 || connectivityManager.isWaitingForResponse)
                    .accessibilityLabel("Add meal")
                    .accessibilityRespondsToUserInteraction(true)
                }
            }
            .padding()
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onReceive(connectivityManager.$isWaitingForResponse) { isWaiting in
                // Dismiss when meal is successfully added
                if !isWaiting && connectivityManager.summary != nil {
                    dismiss()
                }
            }
        }
    }
    
    private func addMeal() {
        guard calories > 0 else { return }
        
        let proteinToAdd = proteinEnabled ? protein : 0
        connectivityManager.sendQuickAdd(kcal: calories, protein: proteinToAdd)
    }
}

#Preview {
    QuickAddFlowView()
}