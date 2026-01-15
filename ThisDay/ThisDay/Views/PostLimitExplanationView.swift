import SwiftUI

struct PostLimitExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange.gradient)
                    
                    // Title
                    Text("One Post Per Day")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 16) {
                        ExplanationRow(
                            icon: "heart.fill",
                            color: .pink,
                            title: "Quality Over Quantity",
                            description: "By limiting posts to one per day, we encourage you to share your most meaningful moment."
                        )
                        
                        ExplanationRow(
                            icon: "moon.stars.fill",
                            color: .indigo,
                            title: "Daily Reset",
                            description: "Your posting ability resets at midnight. Plan your post for when the moment feels right."
                        )
                        
                        ExplanationRow(
                            icon: "person.2.fill",
                            color: .blue,
                            title: "Mindful Sharing",
                            description: "This creates a more intentional feed where every post matters, both for you and your followers."
                        )
                        
                        ExplanationRow(
                            icon: "clock.fill",
                            color: .orange,
                            title: "Take Your Time",
                            description: "No rush, no pressure. When your timer resets, you'll be ready to share another special moment."
                        )
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ExplanationRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PostLimitExplanationView()
}
