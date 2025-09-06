import Foundation
import SwiftData
import HealthKit
import Combine

@MainActor
final class MealsStore: ObservableObject {
    static let shared = MealsStore()

    @Published private(set) var todayMeals: [Meal] = []
    @Published private(set) var todayIntakeKcal: Double = 0

    private var modelContext: ModelContext?
    private let calendar = Calendar.current

    func attach(context: ModelContext) {
        self.modelContext = context
        Task { await reloadToday() }
    }

    func reloadToday() async {
        guard let ctx = modelContext else { return }
        let start = calendar.startOfDay(for: Date())
        let end = Date()

        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let meals = (try? ctx.fetch(descriptor)) ?? []
        todayMeals = meals
        todayIntakeKcal = meals.reduce(0) { $0 + $1.kcal }
    }

    func addMeal(name: String, kcal: Double, date: Date = Date()) async throws {
        guard let ctx = modelContext else { return }
        let meal = Meal(name: name, kcal: kcal, date: date)
        ctx.insert(meal)
        try ctx.save()
        await reloadToday()
    }

    func updateMeal(_ meal: Meal, name: String, kcal: Double, date: Date) throws {
        guard let ctx = modelContext else { return }
        meal.name = name.isEmpty ? "Meal" : name
        meal.kcal = max(0, kcal)
        meal.date = date
        meal.updatedAt = Date()
        try ctx.save()
        Task { await self.reloadToday() }
    }

    func deleteMeal(_ meal: Meal) throws {
        guard let ctx = modelContext else { return }
        ctx.delete(meal)
        try ctx.save()
        Task { await self.reloadToday() }
    }
}
