import SwiftUI
import Combine
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
        if let connection = output.connection(with: .video) {
            let portraitAngle: CGFloat = 90
            if connection.isVideoRotationAngleSupported(portraitAngle) {
                connection.videoRotationAngle = portraitAngle
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        process(pixelBuffer: pixelBuffer)
    }

    private func process(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let width = cgImage.width
        let height = cgImage.height
        let side = min(width, height)
        let xOffset = (width - side) / 2
        let yOffset = (height - side) / 2
        guard let square = cgImage.cropping(to: CGRect(x: xOffset, y: yOffset, width: side, height: side)) else { return }
        guard let data = square.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return }

        var newGrid: [String] = []
        for row in 0..<rows {
            let startY = Int(Float(row) * Float(side) / Float(rows))
            let endY = Int(Float(row + 1) * Float(side) / Float(rows))
            for col in 0..<columns {
                let startX = Int(Float(col) * Float(side) / Float(columns))
                let endX = Int(Float(col + 1) * Float(side) / Float(columns))
                var rTotal = 0
                var gTotal = 0
                var bTotal = 0
                var count = 0
                for y in startY..<endY {
                    for x in startX..<endX {
                        let offset = (y * side + x) * 4
                        let r = Int(ptr[offset])
                        let g = Int(ptr[offset + 1])
                        let b = Int(ptr[offset + 2])
                        rTotal += r
                        gTotal += g
                        bTotal += b
                        count += 1
                    }
                }
                let r = rTotal / max(count, 1)
                let g = gTotal / max(count, 1)
                let b = bTotal / max(count, 1)
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
