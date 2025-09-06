import SwiftUI

struct RingView: View {
    var progress: Double         // 0...1
    var lineWidth: CGFloat = 22
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // start at 12 o'clock
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}
