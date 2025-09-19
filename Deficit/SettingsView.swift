import SwiftUI

struct SettingsView: View {
    @AppStorage("proteinFeatureEnabled") private var proteinEnabled: Bool = true
    @AppStorage("dailyProteinGoalGrams") private var proteinGoalGrams: Double = 50

    var body: some View {
        Form {
            Section(header: Text("Protein")) {
                Toggle(isOn: $proteinEnabled) {
                    Text("Protein Ring")
                }
                HStack {
                    Text("Daily Protein Goal")
                    Spacer()
                    Text("\(Int(proteinGoalGrams)) g")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                HStack {
                    Text("Adjust Goal")
                    Spacer()
                    Stepper("\(Int(proteinGoalGrams)) g",
                            value: $proteinGoalGrams,
                            in: 20...200,
                            step: 5)
                        .labelsHidden()
                }
                .disabled(!proteinEnabled)
            }
        }
        .navigationTitle("Settings")
    }
}


