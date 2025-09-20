import SwiftUI
import SwiftData
import UIKit

struct DayDetailView: View {
    let dayStart: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mealsStore = MealsStore.shared
    @State private var meals: [Meal] = []
    @State private var showingAddMeal = false
    @State private var showingEditMeal: Meal?
    @AppStorage("proteinFeatureEnabled") private var proteinEnabled: Bool = true
    @AppStorage("dailyDeficitGoal") private var goal: Double = 500
    @AppStorage("dailyProteinGoalGrams") private var proteinGoal: Double = 50
    
    // Health data
    @State private var burnedKcal: Double = 0
    @State private var activeKcal: Double = 0
    @State private var basalKcal: Double = 0
    @State private var isLoadingHealth: Bool = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    // Computed properties for the day
    private var dayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }
    
    private var intake: Double {
        meals.reduce(0) { $0 + $1.kcal }
    }
    
    private var protein: Double {
        meals.reduce(0) { $0 + $1.proteinGrams }
    }
    
    // Computed properties using real data
    private var burned: Double { burnedKcal }
    
    private var net: Double { burned - intake }
    private var inDeficit: Bool { net >= 0 }
    
    private var ringProgress: Double {
        if inDeficit {
            return goal > 0 ? min(max(net / goal, 0), 1) : 0
        } else {
            return intake > 0 ? min(max(burned / intake, 0), 1) : 0
        }
    }
    
    private var proteinProgress: Double {
        guard proteinEnabled && proteinGoal > 0 else { return 0 }
        return min(max(protein / proteinGoal, 0), 1)
    }
    
    private var ringColor: Color {
        inDeficit ? .green : .red
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Date header
                    VStack(spacing: 8) {
                        Text(dateFormatter.string(from: dayStart))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if calendar.isDateInToday(dayStart) {
                            Text("Today")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Big rings
                    ZStack {
                        // Protein ring (outer) when enabled
                        if proteinEnabled {
                            RingView(progress: proteinProgress, lineWidth: 12, color: .blue)
                                .frame(width: 250, height: 250)
                        }
                        
                        // Deficit ring (inner)
                        RingView(progress: ringProgress, color: ringColor)
                            .frame(width: 220, height: 220)
                        
                        VStack(spacing: 6) {
                            Text(inDeficit ? "In Deficit" : "Not in Deficit")
                                .font(.headline)
                                .foregroundStyle(ringColor)
                            Text("\(Int(net.rounded())) kcal")
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: net))
                            Text(inDeficit ? 
                                "Deficit \(Int(net.rounded())) / \(Int(goal)) kcal" :
                                "To break even: \(Int(max(0, intake - burned))) kcal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Protein progress text when enabled
                            if proteinEnabled {
                                Text("\(Int(protein))g / \(Int(proteinGoal))g protein")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    
                    // Summary row
                    HStack {
                        summaryCard("Burned", burned, "kcal", isLoading: isLoadingHealth)
                        summaryCard("Intake", intake, "kcal")
                        summaryCard("Net", net, "kcal")
                        if proteinEnabled {
                            summaryCard("Protein", protein, "g")
                        } else {
                            summaryCard("Goal", goal, "kcal")
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Meals list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Meals")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingAddMeal = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if meals.isEmpty {
                            VStack(spacing: 8) {
                                Text("No meals logged")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Tap + to add a meal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(meals) { meal in
                                    MealRowView(meal: meal, proteinEnabled: proteinEnabled) {
                                        showingEditMeal = meal
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Day Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadMealsForDay()
                Task {
                    await loadHealthDataForDay()
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                AddMealSheet(initialDate: dayStart)
            }
            .sheet(item: $showingEditMeal) { meal in
                EditMealSheet(meal: meal)
            }
        }
    }
    
    private func summaryCard(_ title: String, _ value: Double, _ unit: String, isLoading: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text("\(Int(value.rounded()))")
                    .font(.headline)
                    .monospacedDigit()
            }
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadMealsForDay() {
        do {
            meals = try mealsStore.meals(forDay: dayStart, dayEnd: dayEnd)
        } catch {
            print("Error loading meals: \(error)")
            meals = []
        }
    }
    
    private func loadHealthDataForDay() async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }
        
        do {
            let healthData = try await HealthStore.shared.calories(from: dayStart, to: dayEnd)
            activeKcal = healthData.activeKcal
            basalKcal = healthData.basalKcal
            burnedKcal = healthData.totalKcal
        } catch {
            print("Error loading health data: \(error)")
            // Keep default values (0) if health data fails to load
        }
    }
}

struct MealRowView: View {
    let meal: Meal
    let proteinEnabled: Bool
    let onEdit: () -> Void
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.headline)
                Text(timeFormatter.string(from: meal.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.kcal)) kcal")
                    .font(.headline)
                if proteinEnabled {
                    Text("\(Int(meal.proteinGrams))g protein")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing) {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                try? MealsStore.shared.deleteMeal(meal)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    DayDetailView(dayStart: Date())
}
