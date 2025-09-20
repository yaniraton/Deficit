import SwiftUI
import UIKit

struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.modelContext) private var context
    @State private var selectedDate: Date?
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month header with navigation
                monthHeader
                
                // Weekday headers
                weekdayHeaders
                
                // Calendar grid
                calendarGrid
                
                Spacer()
            }
            .navigationTitle("History")
            .onAppear {
                viewModel.attach(context: context)
            }
            .sheet(item: Binding<IdentifiableDate?>(
                get: { selectedDate.map(IdentifiableDate.init) },
                set: { selectedDate = $0?.date }
            )) { identifiableDate in
                DayDetailView(dayStart: identifiableDate.date)
            }
        }
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .disabled(!canNavigateToPreviousMonth)
            
            Spacer()
            
            Text(dateFormatter.string(from: viewModel.currentMonth))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .disabled(!canNavigateToNextMonth)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var weekdayHeaders: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(viewModel.monthDays, id: \.self) { date in
                CalendarDayCell(
                    date: date,
                    summary: viewModel.summary(forDay: date),
                    isInCurrentMonth: viewModel.isDateInCurrentMonth(date),
                    isInRange: viewModel.isDateInRange(date),
                    isToday: calendar.isDateInToday(date)
                ) {
                    if viewModel.isDateInRange(date) {
                        selectedDate = date
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
    
    private var canNavigateToPreviousMonth: Bool {
        let earliestDate = calendar.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        return viewModel.currentMonth > earliestDate
    }
    
    private var canNavigateToNextMonth: Bool {
        return viewModel.currentMonth < Date()
    }
}

struct CalendarDayCell: View {
    let date: Date
    let summary: DailySummary?
    let isInCurrentMonth: Bool
    let isInRange: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Date number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                
                // Rings
                if summary?.proteinEnabled == true {
                    // Show both rings when protein is enabled
                    ZStack {
                        // Protein ring (outer, blue)
                        TinyRingView(
                            progress: summary?.proteinProgress ?? 0,
                            color: .blue,
                            size: 24
                        )
                        // Deficit ring (inner)
                        TinyRingView(
                            progress: summary?.progress ?? 0,
                            color: ringColor,
                            size: 16
                        )
                    }
                } else {
                    // Show only deficit ring when protein is disabled
                    TinyRingView(
                        progress: summary?.progress ?? 0,
                        color: ringColor,
                        size: 20
                    )
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isInRange)
    }
    
    private var textColor: Color {
        if !isInCurrentMonth {
            return .secondary.opacity(0.5)
        } else if !isInRange {
            return .secondary.opacity(0.3)
        } else if isToday {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return .blue.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    private var ringColor: Color {
        guard let summary = summary else { return .gray }
        
        switch summary.colorMode {
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
}

struct TinyRingView: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 2)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    CalendarView()
}
