import SwiftUI
import SwiftData
import UIKit

struct TopView: View {
    @StateObject private var vm = DeficitViewModel()
    @Environment(\.modelContext) private var context
    @StateObject private var meals = MealsStore.shared
    @State private var showMeals = false
    @State private var showAddMeal = false
    @State private var lastInDeficit: Bool = false
    @State private var showBurnedDetails = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Ring + labels
                    ZStack {
                        // Protein ring (outer) when enabled
                        if vm.proteinEnabled {
                            RingView(progress: vm.proteinProgress, lineWidth: 12, color: .blue)
                                .frame(width: 250, height: 250)
                        }

                        // Deficit ring (inner)
                        RingView(progress: vm.ringProgress, color: vm.ringColor)
                            .frame(width: 220, height: 220)

                        VStack(spacing: 6) {
                            Text(vm.headline)
                                .font(.headline)
                                .foregroundStyle(vm.ringColor)
                            Text("\(Int(vm.net.rounded())) kcal")
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: vm.net))
                            Text(vm.sublabel)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.vertical, 16)
                    .onChange(of: vm.inDeficit) { newValue in
                        if newValue {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }

                    // Stats
                    VStack(spacing: 12) {
                        // Main stats row
                        HStack {
                            // Burned card with long press
                            stat("Burned", vm.burned)
                                .onLongPressGesture(minimumDuration: 0.1) {
                                    // Empty completion handler - we handle everything in onPressingChanged
                                } onPressingChanged: { pressing in
                                    if pressing {
                                        // User started pressing - show details
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showBurnedDetails = true
                                        }
                                    } else {
                                        // User lifted finger - hide details
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showBurnedDetails = false
                                        }
                                    }
                                }
                            
                            // Protein card (when enabled)
                            if vm.proteinEnabled {
                                proteinStat()
                            }
                        }
                        
                        // Expanded burned details
                        if showBurnedDetails {
                            HStack {
                                stat("Active", vm.activeKcal)
                                stat("Basal", vm.basalKcal)
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                        }
                    }
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
                                .onChange(of: vm.goal) { _ in
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                }
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

                    Button {
                        Task {
                            do {
                                try await vm.reloadToday()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } catch {
                                // no haptic on failure for now
                            }
                        }
                    } label: {
                        Label("Refresh Today", systemImage: "arrow.clockwise")
                    }
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .safeAreaPadding(.bottom, 16)
            .navigationTitle("Deficit Overview")
            .task {
                await vm.requestAuthAndLoadToday()
                meals.attach(context: context)
                vm.bindMeals(meals)
            }
            .sheet(isPresented: $showMeals) {
                NavigationView { MealsListView() }
            }
            .sheet(isPresented: $showAddMeal) {
                AddMealSheet()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddMeal = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
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
    
    private func proteinStat() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Protein").font(.caption).foregroundColor(.secondary)
            Text("\(Int(vm.todayProteinGrams))g / \(Int(vm.proteinGoalGrams))g")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
