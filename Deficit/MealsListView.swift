import SwiftUI
import SwiftData

struct MealsListView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store = MealsStore.shared
    @State private var showingAdd = false

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
                            Text("\(Int(meal.kcal)) kcal").bold()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                try? store.deleteMeal(meal)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Section(footer: Text("Total today: \(Int(store.todayIntakeKcal)) kcal")) {
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

