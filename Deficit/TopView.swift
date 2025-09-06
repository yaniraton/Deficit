import SwiftUI

struct TopView: View {
    @StateObject private var vm = DeficitViewModel()
    @FocusState private var intakeFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 22) {
                // Ring + labels
                ZStack {
                    RingView(progress: vm.ringProgress, color: vm.ringColor)
                        .frame(width: 220, height: 220)

                    VStack(spacing: 6) {
                        Text(vm.headline)
                            .font(.headline)
                            .foregroundStyle(vm.ringColor)
                        Text("\(Int(vm.net.rounded())) kcal")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text(vm.sublabel)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)

                // Stats
                HStack {
                    stat("Active", vm.activeKcal)
                    stat("Basal",  vm.basalKcal)
                    stat("Burned", vm.burned)
                }
                .padding(.horizontal)

                // Goal + Intake
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Daily Deficit Goal")
                        Spacer()
                        Stepper("\(Int(vm.goal)) kcal",
                                value: $vm.goal,
                                in: 100...1500, step: 50)
                            .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Intake today (kcal)")
                        HStack {
                            TextField("e.g. 1800", value: $vm.intake, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($intakeFocused)
                            Button("Clear") { vm.intake = 0 }
                                .buttonStyle(.borderless)
                        }
                        Text("Red fills to break-even; green fills to your goal.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                Button {
                    Task { try? await vm.reloadToday() }
                } label: {
                    Label("Refresh Today", systemImage: "arrow.clockwise")
                }

                Spacer()
            }
            .navigationTitle("Deficit Overview")
            .task { await vm.requestAuthAndLoadToday() }
        }
    }

    private func stat(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("\(Int(value.rounded())) kcal").font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
