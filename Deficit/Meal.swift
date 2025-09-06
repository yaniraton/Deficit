import Foundation
import SwiftData

@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var name: String
    var kcal: Double
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    // future-proof fields (optional now)
    var source: String
    var externalIdentifier: String?

    init(id: UUID = UUID(),
         name: String = "Meal",
         kcal: Double,
         date: Date = Date(),
         source: String = "local") {
        self.id = id
        self.name = name.isEmpty ? "Meal" : name
        self.kcal = max(0, kcal)
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
        self.source = source
    }
}
