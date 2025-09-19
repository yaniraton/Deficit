import SwiftUI
import SwiftData
import UIKit

struct MealsListView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = MealsStore.shared
    @State private var showingAdd = false
    @AppStorage("proteinFeatureEnabled") private var proteinEnabled: Bool = true

    var body: some View {
        List {
            if store.todayMeals.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("No meals logged today").font(.headline)
                        Text("Tap + to add your first meal.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(store.todayMeals) { meal in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(meal.name).font(.headline)
                                Text(meal.date, style: .time)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(meal.kcal)) kcal").bold()
                                if proteinEnabled {
                                    Text("\(Int(meal.proteinGrams))g protein")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                try? store.deleteMeal(meal)
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Section(footer: Text(proteinEnabled ? 
                    "Total today: \(Int(store.todayIntakeKcal)) kcal • \(Int(store.todayProteinGrams))g protein" :
                    "Total today: \(Int(store.todayIntakeKcal)) kcal")) {
                    EmptyView()
                }
            }
        }
        .navigationTitle("Meals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .onAppear {
            MealsStore.shared.attach(context: context)
        }
        .sheet(isPresented: $showingAdd) {
            AddMealSheet()
        }
    }
}
