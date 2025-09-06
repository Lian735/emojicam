import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraEmojiViewModel()

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(viewModel.columns)
            let cellHeight = geometry.size.height / CGFloat(viewModel.rows)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: viewModel.columns)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<viewModel.emojiGrid.count, id: \.self) { index in
                    Text(viewModel.emojiGrid[index])
                        .frame(width: cellWidth, height: cellHeight)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black)
            .onAppear { viewModel.startSession() }
            .onDisappear { viewModel.stopSession() }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
