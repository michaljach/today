import SwiftUI

struct CountdownTimerView: View {
    let lastPostDate: Date
    var style: Style = .banner
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    
    enum Style {
        case banner
        case compact
        case floating
    }
    
    var body: some View {
        Group {
            switch style {
            case .banner:
                bannerView
            case .compact:
                compactView
            case .floating:
                floatingView
            }
        }
        .onAppear {
            updateTimeRemaining()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var bannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
            
            Text("Next post available in ")
                .foregroundStyle(.secondary)
            +
            Text(formattedTime)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
    }
    
    private var compactView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.caption)
            Text(formattedTime)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .foregroundStyle(.orange)
    }
    
    private var floatingView: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.caption)
            Text("Post again in \(formattedTime)")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.orange)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        )
        .padding(.top, 8)
    }
    
    private var formattedTime: String {
        guard timeRemaining > 0 else { return "now" }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var nextPostDate: Date {
        Calendar.current.startOfDay(for: lastPostDate).addingTimeInterval(24 * 60 * 60)
    }
    
    private func updateTimeRemaining() {
        timeRemaining = max(0, nextPostDate.timeIntervalSince(Date()))
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Helper to check if user can post today

extension Date {
    /// Returns true if this date is from a previous calendar day
    var canPostToday: Bool {
        !Calendar.current.isDateInToday(self)
    }
    
    /// Returns the time remaining until the next calendar day
    var timeUntilNextDay: TimeInterval {
        let tomorrow = Calendar.current.startOfDay(for: self).addingTimeInterval(24 * 60 * 60)
        return max(0, tomorrow.timeIntervalSince(Date()))
    }
}

#Preview("Banner - Hours remaining") {
    CountdownTimerView(lastPostDate: Date().addingTimeInterval(-3600), style: .banner)
}

#Preview("Compact - Hours remaining") {
    CountdownTimerView(lastPostDate: Date().addingTimeInterval(-3600), style: .compact)
}

#Preview("Compact - Minutes remaining") {
    CountdownTimerView(lastPostDate: Date().addingTimeInterval(-23 * 3600), style: .compact)
}
