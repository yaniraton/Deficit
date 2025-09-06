import SwiftUI

struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var kcal: Double = 0
    @State private var date: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                TextField("Name (optional)", text: $name)
                HStack {
                    Text("Calories")
                    Spacer()
                    TextField("kcal", value: $kcal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                DatePicker("Time", selection: $date, displayedComponents: [.date, .hourAndMinute])

                HStack {
                    ForEach([100, 250, 500], id: \.self) { v in
                        Button("+\(v)") { kcal += Double(v) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            try? await MealsStore.shared.addMeal(name: name, kcal: kcal, date: date)
                            dismiss()
                        }
                    }
                    .disabled(kcal <= 0)
                }
            }
        }
    }
}
