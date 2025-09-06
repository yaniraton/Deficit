//
//  DeficitApp.swift
//  Deficit
//
//  Created by Yanir Aton on 06/09/2025.
//

import SwiftUI

@main
struct DeficitApp: App {
    var body: some Scene {
        WindowGroup {
            TopView()
        }
        .modelContainer(for: [Meal.self])   // <-- SwiftData container
    }
}
