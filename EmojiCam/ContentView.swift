import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraEmojiViewModel()

    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width / CGFloat(viewModel.columns),
                               geometry.size.height / CGFloat(viewModel.rows))
            let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: viewModel.columns)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<viewModel.emojiGrid.count, id: \.self) { index in
                    Text(viewModel.emojiGrid[index])
                        .frame(width: cellSize, height: cellSize)
                        .font(.system(size: cellSize))
                }
            }
            .frame(width: cellSize * CGFloat(viewModel.columns),
                   height: cellSize * CGFloat(viewModel.rows))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
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
