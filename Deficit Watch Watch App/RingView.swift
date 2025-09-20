import SwiftUI

struct RingView: View {
    var progress: Double         // 0...1+
    var lineWidth: CGFloat = 10  // Thinner for watch
    var color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0)) // Cap visual progress at 100%
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // start at 12 o'clock
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}

struct DualRingsView: View {
    let deficitProgress: Double
    let deficitColor: Color
    let proteinProgress: Double
    let proteinColor: Color = .blue
    
    var body: some View {
        ZStack {
            // Outer ring (deficit)
            RingView(
                progress: deficitProgress,
                lineWidth: 8,
                color: deficitColor
            )
            .frame(width: 120, height: 120)
            
            // Inner ring (protein)
            RingView(
                progress: proteinProgress,
                lineWidth: 6,
                color: proteinColor
            )
            .frame(width: 90, height: 90)
        }
    }
}

struct SingleRingView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        RingView(
            progress: progress,
            lineWidth: 12,
            color: color
        )
        .frame(width: 120, height: 120)
    }
}