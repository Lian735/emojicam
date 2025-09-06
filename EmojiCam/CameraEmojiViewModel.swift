import SwiftUI
import AVFoundation
import CoreImage
import CoreGraphics

class CameraEmojiViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var emojiGrid: [String]
    let columns: Int
    let rows: Int

    private let session = AVCaptureSession()
    private let context = CIContext()
    private let queue = DispatchQueue(label: "emoji.camera.queue")

    override init() {
        self.columns = 40
        self.rows = 40
        self.emojiGrid = Array(repeating: "⬛️", count: columns * rows)
        super.init()
    }

    func startSession() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                self.setupSession()
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        session.stopRunning()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .low
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.connection(with: .video)?.videoOrientation = .portrait
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        process(pixelBuffer: pixelBuffer)
    }

    private func process(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        guard let scaled = cgImage.scaled(to: CGSize(width: columns, height: rows)) else { return }
        guard let data = scaled.dataProvider?.data else { return }
        let ptr = CFDataGetBytePtr(data)

        var newGrid: [String] = []
        for y in 0..<rows {
            for x in 0..<columns {
                let offset = (y * columns + x) * 4
                let r = Int(ptr[offset])
                let g = Int(ptr[offset + 1])
                let b = Int(ptr[offset + 2])
                newGrid.append(closestEmoji(r: r, g: g, b: b))
            }
        }
        DispatchQueue.main.async {
            self.emojiGrid = newGrid
        }
    }

    private let palette: [(emoji: String, r: Int, g: Int, b: Int)] = [
        ("⬛️", 0, 0, 0),
        ("⬜️", 255, 255, 255),
        ("🟥", 255, 0, 0),
        ("🟧", 255, 165, 0),
        ("🟨", 255, 255, 0),
        ("🟩", 0, 128, 0),
        ("🟦", 0, 0, 255),
        ("🟪", 128, 0, 128),
        ("🟫", 165, 42, 42)
    ]

    private func closestEmoji(r: Int, g: Int, b: Int) -> String {
        var best = palette[0]
        var bestDistance = Int.max
        for candidate in palette {
            let dr = r - candidate.r
            let dg = g - candidate.g
            let db = b - candidate.b
            let distance = dr * dr + dg * dg + db * db
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best.emoji
    }
}

private extension CGImage {
    func scaled(to size: CGSize) -> CGImage? {
        guard let colorSpace = self.colorSpace else { return nil }
        let width = Int(size.width)
        let height = Int(size.height)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(self, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
