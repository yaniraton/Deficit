import SwiftUI
import UIKit

struct EditMealSheet: View {
    let meal: Meal
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        AddMealSheet(
            initialName: meal.name,
            initialKcal: meal.kcal,
            initialProteinGrams: meal.proteinGrams,
            initialDate: meal.date,
            isEditMode: true,
            mealToUpdate: meal,
            onDismiss: { dismiss() }
        )
    }
}
