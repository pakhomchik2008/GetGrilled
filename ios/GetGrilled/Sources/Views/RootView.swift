import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 48))
                Text("GetGrilled")
                    .font(.largeTitle.bold())
                Text("AI-тренажёр технических собеседований")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("GetGrilled")
        }
    }
}

#Preview {
    RootView()
}
