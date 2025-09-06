import SwiftUI
import SwiftData

struct TopView: View {
    @StateObject private var vm = DeficitViewModel()
    @Environment(\.modelContext) private var context
    @StateObject private var meals = MealsStore.shared
    @State private var showMeals = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
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
                .padding(.vertical, 16)

                // Stats
                HStack {
                    stat("Active", vm.activeKcal)
                    stat("Basal",  vm.basalKcal)
                    stat("Burned", vm.burned)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                // Goal + Intake summary + Log Meal
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Daily Deficit Goal")
                        Spacer()
                        Stepper("\(Int(vm.goal)) kcal",
                                value: $vm.goal,
                                in: 100...1500, step: 50)
                            .labelsHidden()
                    }

                    HStack {
                        Text("Intake today: \(Int(meals.todayIntakeKcal)) kcal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            showMeals = true
                        } label: {
                            Label("Log Meal", systemImage: "fork.knife")
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal)

                Button {
                    Task { try? await vm.reloadToday() }
                } label: {
                    Label("Refresh Today", systemImage: "arrow.clockwise")
                }
                .padding(.top, 16)

                Spacer()
            }
            .navigationTitle("Deficit Overview")
            .task {
                await vm.requestAuthAndLoadToday()
                meals.attach(context: context)
                vm.bindMeals(meals)
            }
            .sheet(isPresented: $showMeals) {
                NavigationView { MealsListView() }
            }
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
